import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/campus.dart';

class AppConfig {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const mapsEnabled = bool.fromEnvironment('MAPS_ENABLED');
  static const emulatorHost = String.fromEnvironment('EMULATOR_HOST');
  static bool ready = false;
  static String? error;
  static Future<void> initialize() async {
    if ([apiKey, projectId, appId, senderId].any((v) => v.isEmpty)) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: appId,
          messagingSenderId: senderId,
          projectId: projectId,
        ),
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
      if (emulatorHost.isNotEmpty) {
        await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
        FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001);
      }
      ready = true;
    } catch (_) {
      error =
          'Firebase could not initialize. Check your project configuration.';
    }
  }
}

class CampusRepository {
  FirebaseFirestore get db => FirebaseFirestore.instance;
  Stream<List<CampusPlace>> places() => db
      .collection('buildings')
      .where('published', isEqualTo: true)
      .snapshots()
      .map(
        (s) => s.docs.map((d) => CampusPlace.fromMap(d.id, d.data())).toList(),
      );
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable(name)
        .call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> register(String name, String email, String password) async {
    final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await result.user!.updateDisplayName(name);
    await result.user!.sendEmailVerification();
    await db.collection('users').doc(result.user!.uid).set({
      'displayName': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<RoutingGraph?> campusGraph() async {
    final doc = await db.collection('campusPaths').doc('walking').get();
    final data = doc.data();
    if (data == null || data['verified'] != true) return null;
    return graphFromMap(data);
  }
}

RoutingGraph graphFromMap(Map<String, dynamic> data) => RoutingGraph(
  (data['nodes'] as List)
      .map(
        (n) => RouteNode(
          n['id'],
          (n['x'] as num).toDouble(),
          (n['y'] as num).toDouble(),
          latitude: n['floor'] == null || n['floor'] == 'outdoor'
              ? (n['x'] as num).toDouble()
              : null,
          longitude: n['floor'] == null || n['floor'] == 'outdoor'
              ? (n['y'] as num).toDouble()
              : null,
          label: n['label'] ?? '',
          floor: n['floor'] ?? 'outdoor',
        ),
      )
      .toList(),
  (data['edges'] as List)
      .map(
        (e) => RouteEdge(
          e['from'],
          e['to'],
          (e['meters'] as num).toDouble(),
          accessible: e['accessible'] == true,
          instruction: e['instruction'] ?? 'Continue along the verified path',
        ),
      )
      .toList(),
);

class DeviceLocation extends ChangeNotifier {
  StreamSubscription<Position>? _subscription;
  Position? position;
  String? message;
  bool active = false;
  bool _disposed = false;
  int _generation = 0;
  final Future<void> Function(Position)? onPosition;
  final Future<bool> Function() serviceEnabled;
  final Future<LocationPermission> Function() checkPermission;
  final Future<LocationPermission> Function() requestPermission;
  final Stream<Position> Function() positions;
  DeviceLocation({
    this.onPosition,
    Future<bool> Function()? serviceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Stream<Position> Function()? positions,
  }) : serviceEnabled = serviceEnabled ?? Geolocator.isLocationServiceEnabled,
       checkPermission = checkPermission ?? Geolocator.checkPermission,
       requestPermission = requestPermission ?? Geolocator.requestPermission,
       positions =
           positions ??
           (() => Geolocator.getPositionStream(
             locationSettings: const LocationSettings(
               accuracy: LocationAccuracy.high,
               distanceFilter: 5,
             ),
           ));

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_disposed) return;
    final generation = ++_generation;
    final old = _subscription;
    _subscription = null;
    active = false;
    await old?.cancel();
    bool current() => !_disposed && generation == _generation;
    try {
      if (!await serviceEnabled()) {
        if (!current()) return;
        message =
            'Device location is turned off. Enable it in Settings and retry.';
        _emit();
        return;
      }
      if (!current()) return;
      var permission = await checkPermission();
      if (!current()) return;
      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
      }
      if (!current()) return;
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        message = permission == LocationPermission.deniedForever
            ? 'Location permission is blocked. Open app settings to enable it.'
            : 'Location access was denied. You can still explore campus destinations.';
        _emit();
        return;
      }
      active = true;
      message = 'Waiting for a device location…';
      _emit();
      _subscription = positions().listen(
        (fix) async {
          if (!current() || !active) return;
          final age = DateTime.now().difference(fix.timestamp);
          if (!fix.latitude.isFinite ||
              fix.latitude.abs() > 90 ||
              !fix.longitude.isFinite ||
              fix.longitude.abs() > 180 ||
              !fix.accuracy.isFinite ||
              fix.accuracy < 0 ||
              age < const Duration(seconds: -5)) {
            return;
          }
          if (position != null && !fix.timestamp.isAfter(position!.timestamp)) {
            return;
          }
          position = fix;
          message = fix.accuracy > 40 ? 'Location accuracy is low.' : null;
          _emit();
          if (age <= const Duration(seconds: 30)) {
            try {
              await onPosition?.call(fix);
            } catch (_) {
              if (current()) {
                message =
                    'Location upload failed. Your shared position may be stale.';
                _emit();
              }
            }
          }
        },
        onError: (_) {
          if (!current()) return;
          active = false;
          message = 'Location is unavailable. Check permissions and retry.';
          _emit();
        },
        onDone: () {
          if (current()) {
            active = false;
            _emit();
          }
        },
      );
    } catch (_) {
      if (current()) {
        active = false;
        message = 'Location is unavailable. Check permissions and retry.';
        _emit();
      }
    }
  }

  bool get stale =>
      position == null ||
      DateTime.now().difference(position!.timestamp) >
          const Duration(seconds: 30);
  Future<void> stop() async {
    ++_generation;
    active = false;
    final old = _subscription;
    _subscription = null;
    await old?.cancel();
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    active = false;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
