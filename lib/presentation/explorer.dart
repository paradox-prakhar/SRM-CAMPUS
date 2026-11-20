import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../application/app_state.dart';
import '../data/services.dart';
import '../data/geospatial.dart';
import '../domain/campus.dart';
import 'components.dart';

class ExplorerScreen extends ConsumerStatefulWidget {
  const ExplorerScreen({super.key});
  @override
  ConsumerState<ExplorerScreen> createState() => _ExplorerState();
}

class _ExplorerState extends ConsumerState<ExplorerScreen>
    with WidgetsBindingObserver {
  CampusPlace? selected;
  CampusRoute? route;
  CampusRoute? liveRoute;
  double progress = 0;
  Timer? timer;
  final location = DeviceLocation();
  final fmMap = fm.MapController();
  GoogleMapController? map;
  MapType mapType = MapType.normal;
  bool follow = true;
  bool playing = false;
  bool viewRealMap = false;
  List<CampusPlace> livePlaces = [];
  StreamSubscription<List<CampusPlace>>? placesSubscription;
  String? dataError;
  List<GeoVertex> boundary = [];
  String? confirmedBuilding;
  Timer? freshness;
  bool showLocationBanner = true;
  Timer? locationBannerTimer;

  void _triggerLocationBanner() {
    locationBannerTimer?.cancel();
    if (!showLocationBanner) {
      setState(() => showLocationBanner = true);
    }
    locationBannerTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => showLocationBanner = false);
      }
    });
  }

  BoundaryStatus get boundaryStatus => location.position == null
      ? BoundaryStatus.unavailable
      : classifyGeoBoundary(
          GeoVertex(location.position!.latitude, location.position!.longitude),
          boundary,
          location.position!.accuracy,
        );
  String get boundaryLabel => switch (boundaryStatus) {
    BoundaryStatus.inside => 'Likely Inside SRM AP Campus',
    BoundaryStatus.outside => 'Outside SRM AP Campus',
    BoundaryStatus.uncertain => 'Campus boundary uncertain at this accuracy',
    BoundaryStatus.unavailable =>
      'Campus boundary unavailable until verified geometry is published.',
  };
  CampusPlace? get nearbyBuilding {
    final fix = location.position;
    if (fix == null || location.stale || fix.accuracy > 50) return null;
    final allPlaces = livePlaces;
    final nearby = allPlaces
        .where(
          (p) =>
              p.mappable &&
              Geolocator.distanceBetween(
                    fix.latitude,
                    fix.longitude,
                    p.latitude!,
                    p.longitude!,
                  ) <
                  60,
        )
        .toList();
    return nearby.length == 1 ? nearby.single : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    location.addListener(_locationChanged);
    _triggerLocationBanner();
    freshness = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    if (AppConfig.ready && FirebaseAuth.instance.currentUser != null) {
      FirebaseFirestore.instance
          .collection('campusBoundaries')
          .where('verified', isEqualTo: true)
          .limit(1)
          .get()
          .then((s) {
            if (mounted && s.docs.isNotEmpty) {
              setState(
                () => boundary = (s.docs.first.data()['vertices'] as List)
                    .map((v) => GeoVertex.fromMap(Map<String, dynamic>.from(v)))
                    .toList(),
              );
            }
          })
          .catchError((_) {});
      placesSubscription = CampusRepository().places().listen(
        (v) {
          if (mounted) {
            setState(() => livePlaces = v);
          }
        },
        onError: (_) {
          if (mounted) {
            setState(
              () => dataError =
                  'Campus data could not load. Check your connection and sign-in.',
            );
          }
        },
      );
    }
  }

  void _locationChanged() {
    if (!mounted) return;
    final p = location.position;
    if (follow && p != null) {
      try {
        fmMap.move(ll.LatLng(p.latitude, p.longitude), fmMap.camera.zoom);
      } catch (_) {}
      map?.animateCamera(
        CameraUpdate.newLatLng(LatLng(p.latitude, p.longitude)),
      );
    }
    setState(() {});
    _updateGpsProgress();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _resumeLocation = _resumeLocation || location.active;
      location.stop();
      timer?.cancel();
      if (mounted && playing) setState(() => playing = false);
    } else if (state == AppLifecycleState.resumed && _resumeLocation) {
      // Restart tracking the user had turned on before the app was backgrounded.
      _resumeLocation = false;
      location.start();
    }
  }

  bool _resumeLocation = false;

  @override
  void dispose() {
    timer?.cancel();
    freshness?.cancel();
    locationBannerTimer?.cancel();
    placesSubscription?.cancel();
    location.removeListener(_locationChanged);
    location.dispose();
    map?.dispose();
    fmMap.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Buildings shown on the real map: published Firestore buildings when
  /// available, otherwise the bundled SRM AP building coordinates.
  List<CampusPlace> get mapPlaces {
    final live = livePlaces.where((p) => p.mappable).toList();
    if (live.isNotEmpty) return live;
    return srmApRealPlaces
        .where((p) => p.latitude != null && p.longitude != null)
        .toList();
  }

  /// Point along [liveRoute] at the current [progress] (distance-weighted).
  ll.LatLng? get walkerPosition {
    final r = liveRoute;
    if (r == null || r.nodes.length < 2 || r.meters <= 0) return null;
    var remaining = progress.clamp(0.0, 1.0) * r.meters;
    for (var i = 0; i < r.edges.length; i++) {
      final a = r.nodes[i], b = r.nodes[i + 1], m = r.edges[i].meters;
      if (remaining <= m || i == r.edges.length - 1) {
        final t = m <= 0 ? 1.0 : (remaining / m).clamp(0.0, 1.0);
        return ll.LatLng(
          a.lat + (b.lat - a.lat) * t,
          a.lng + (b.lng - a.lng) * t,
        );
      }
      remaining -= m;
    }
    return null;
  }

  /// True while directions are driven by the device's real GPS position.
  bool gpsNavigation = false;

  /// Max distance from campus paths for a GPS-started route. Farther away,
  /// directions start at the Main Gate instead.
  static const _maxApproachMeters = 2000.0;

  /// Waits (up to [timeout]) for a fresh GPS fix, starting location if needed.
  Future<Position?> _awaitFix({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (location.position != null && !location.stale) return location.position;
    if (!location.active) await location.start();
    if (!location.active) return null; // permission denied / service off
    final done = Completer<Position?>();
    void check() {
      if (!done.isCompleted && location.position != null && !location.stale) {
        done.complete(location.position);
      }
    }

    location.addListener(check);
    check();
    final fix = await done.future.timeout(timeout, onTimeout: () => null);
    location.removeListener(check);
    return fix;
  }

  /// Tap on a building: fetch the user's live location, route from there
  /// along the SRM AP walking paths, and start turn-by-turn navigation.
  Future<void> startNavigation(CampusPlace p) async {
    timer?.cancel();
    final graph = srmApRealGraph;
    if (!graph.nodes.any((n) => n.id == p.id)) {
      notify('No walking path to ${p.name} is mapped yet.');
      return;
    }
    setState(() {
      selected = p;
      route = null;
      liveRoute = null;
      progress = 0;
      playing = false;
      gpsNavigation = false;
    });
    notify('Getting your live location…');
    final fix = await _awaitFix();
    if (!mounted) return;

    CampusRoute? result;
    var fromGps = false;
    if (fix != null) {
      double dist(RouteNode n) =>
          Geolocator.distanceBetween(fix.latitude, fix.longitude, n.lat, n.lng);
      final nearest = graph.nodes.reduce((a, b) => dist(a) <= dist(b) ? a : b);
      final approach = dist(nearest);
      if (approach <= _maxApproachMeters) {
        // Add the user's position as a node joined to the nearest path point.
        final withUser = RoutingGraph(
          [
            RouteNode(
              'you',
              fix.longitude,
              fix.latitude,
              label: 'Your location',
              latitude: fix.latitude,
              longitude: fix.longitude,
            ),
            ...graph.nodes,
          ],
          [
            if (approach > 0)
              RouteEdge(
                'you',
                nearest.id,
                approach,
                instruction:
                    'Walk ${formatDistance(approach)} to ${nearest.label}',
              ),
            ...graph.edges,
          ],
        );
        if (approach < 25 && nearest.id == p.id) {
          notify('You are already at ${p.name}.');
          return;
        }
        result = withUser.route(approach > 0 ? 'you' : nearest.id, p.id);
        fromGps = result != null;
      } else {
        notify(
          'You are ${formatDistance(approach)} from SRM AP. Showing the route from the Main Gate.',
        );
      }
    } else {
      notify(
        'Live location unavailable. Allow location access; showing the route from the Main Gate.',
      );
    }
    result ??= graph.route('srm_main_gate', p.id);
    if (result == null) {
      notify('No walking route connects to ${p.name}.');
      return;
    }
    setState(() {
      route = result;
      liveRoute = result;
      progress = 0;
      gpsNavigation = fromGps;
      follow = fromGps;
    });
    try {
      if (fromGps) {
        fmMap.move(ll.LatLng(fix!.latitude, fix.longitude), 18);
      } else {
        final lats = result.nodes.map((n) => n.lat);
        final lngs = result.nodes.map((n) => n.lng);
        fmMap.move(
          ll.LatLng(
            (lats.reduce(min) + lats.reduce(max)) / 2,
            (lngs.reduce(min) + lngs.reduce(max)) / 2,
          ),
          17,
        );
      }
    } catch (_) {}
    if (fromGps) {
      notify(
        'Navigating from your location to ${p.name} • ${result.minutes} min',
      );
      _updateGpsProgress();
    } else {
      // No usable GPS: preview the walk with the simulated walker.
      play();
    }
  }

  /// Projects the live GPS fix onto the active route to update progress.
  void _updateGpsProgress() {
    final r = liveRoute, fix = location.position;
    if (!gpsNavigation || r == null || fix == null || r.meters <= 0) return;
    final cosLat = cos(fix.latitude * pi / 180);
    // Local planar meters relative to the fix.
    Point<double> local(RouteNode n) => Point(
      (n.lng - fix.longitude) * 111320 * cosLat,
      (n.lat - fix.latitude) * 110540,
    );
    var best = double.infinity, along = 0.0, walked = 0.0;
    for (var i = 0; i < r.edges.length; i++) {
      final a = local(r.nodes[i]), b = local(r.nodes[i + 1]);
      final d = b - a;
      final len2 = d.x * d.x + d.y * d.y;
      final t = len2 == 0
          ? 0.0
          : ((-a.x * d.x - a.y * d.y) / len2).clamp(0.0, 1.0);
      final px = a.x + d.x * t, py = a.y + d.y * t;
      final dist = sqrt(px * px + py * py);
      if (dist < best) {
        best = dist;
        along = walked + r.edges[i].meters * t;
      }
      walked += r.edges[i].meters;
    }
    final last = r.nodes.last;
    final toGoal = Geolocator.distanceBetween(
      fix.latitude,
      fix.longitude,
      last.lat,
      last.lng,
    );
    setState(() {
      progress = toGoal < 20 ? 1.0 : (along / r.meters).clamp(0.0, 1.0);
    });
    if (progress >= 1) {
      gpsNavigation = false;
      notify('You have arrived at ${last.label}.');
    }
  }

  void selectPlace(CampusPlace p) {
    setState(() {
      selected = p;
      route = null;
      progress = 0;
      playing = false;
    });
    timer?.cancel();
    if (p.mappable) {
      map?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(p.latitude!, p.longitude!), 18),
      );
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: lime,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        categoryIcon(p.category),
                        color: forest,
                        size: 30,
                      ),
                    ),
                    const Spacer(),
                    StatusPill(
                      ref.read(appProvider).demo
                          ? 'SIMULATION'
                          : p.verified
                          ? 'VERIFIED'
                          : 'PROVISIONAL',
                      warning: !p.verified,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(p.description, style: const TextStyle(height: 1.6)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: p.facilities
                      .map((f) => Chip(label: Text(f)))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(sheet);
                          navigate(p);
                        },
                        icon: const Icon(Icons.directions_walk),
                        label: const Text('Get directions'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      onPressed: () {
                        Navigator.pop(sheet);
                        context.push('/indoor/${p.id}');
                      },
                      icon: const Icon(Icons.layers_outlined),
                      tooltip: 'Indoor floors',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await launchUrl(
                      Uri.parse(officialTour),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!ok && mounted) {
                      notify('Could not open the official tour.');
                    }
                  },
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('Explore official 360° tour'),
                ),
                if (!ref.read(appProvider).demo)
                  const Notice(
                    'Building presence and floors require your confirmation. GPS alone cannot establish which building or floor you are in.',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void notify(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
  Future<void> navigate(CampusPlace p) async {
    timer?.cancel();
    setState(() {
      playing = false;
      progress = 0;
      route = null;
      liveRoute = null;
    });
    if (ref.read(appProvider).demo && !viewRealMap) {
      final result = demoGraph.route('start', p.id);
      if (result == null) {
        notify('No demo route connects this destination.');
        return;
      }
      setState(() => route = result);
      return;
    }
    if (!AppConfig.ready || FirebaseAuth.instance.currentUser == null) {
      // No live backend: use the bundled SRM AP walking graph.
      startNavigation(p);
      return;
    }
    try {
      final graph = await CampusRepository().campusGraph();
      if (!mounted) return;
      if (graph == null || graph.nodes.isEmpty) {
        notify('No validated campus route is loaded. No directions invented.');
        return;
      }
      final destination = graph.nodes
          .where((n) => n.label == p.id || n.id == p.id)
          .firstOrNull;
      if (destination == null) {
        notify('No verified entrance connects this destination.');
        return;
      }
      final start = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Confirm your starting checkpoint'),
          children: graph.nodes
              .map(
                (n) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(c, n.id),
                  child: Text(n.label.isEmpty ? n.id : n.label),
                ),
              )
              .toList(),
        ),
      );
      if (start == null || !mounted) return;
      final result = graph.route(start, destination.id);
      if (result == null) {
        notify('No validated route connects these checkpoints.');
        return;
      }
      setState(() {
        liveRoute = result;
        follow = false;
      });
      showModalBottomSheet(
        context: context,
        showDragHandle: true,
        builder: (_) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${result.minutes} min • ${result.meters.round()} m',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const Notice(
              'Route starts at your manually confirmed checkpoint, not an inferred GPS position.',
            ),
            ...result.edges.map(
              (e) => ListTile(
                leading: const Icon(Icons.directions_walk),
                title: Text(e.instruction),
                subtitle: Text('${e.meters.round()} m'),
              ),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        notify('Verified routing data could not load.');
      }
    }
  }

  void play() {
    timer?.cancel();
    if (gpsNavigation) {
      notify('Following your live location.');
      return;
    }
    if (playing) {
      setState(() => playing = false);
      return;
    }
    setState(() {
      playing = true;
      if (progress >= 1) {
        progress = 0;
      }
    });
    timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final speed = ref.read(appProvider).simSpeed;
      setState(() {
        progress = (progress + (.008 * speed)).clamp(0, 1);
        if (progress >= 1) {
          playing = false;
          t.cancel();
        }
      });
    });
  }

  Widget mapArea(bool demo) {
    if (demo && !viewRealMap) {
      return CampusCanvas(
        route: route,
        progress: progress,
        selected: selected?.id,
        onSelect: (id) => selectPlace(demoPlaces.firstWhere((p) => p.id == id)),
      );
    }
    final verified = mapPlaces;
    final fix = location.position;
    if (verified.isEmpty && fix == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Notice(
            'Enable device location or publish verified campus coordinates to display the live map.',
          ),
        ),
      );
    }
    final center = (follow || verified.isEmpty) && fix != null
        ? ll.LatLng(fix.latitude, fix.longitude)
        : ll.LatLng(verified.first.latitude!, verified.first.longitude!);

    final tileUrl = mapType == MapType.satellite
        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    if (AppConfig.mapsEnabled && !kIsWeb) {
      return GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(center.latitude, center.longitude),
          zoom: 17,
        ),
        onMapCreated: (controller) => map = controller,
        mapType: mapType,
        compassEnabled: true,
        myLocationButtonEnabled: false,
        markers: {
          for (final p in verified)
            Marker(
              markerId: MarkerId(p.id),
              position: LatLng(p.latitude!, p.longitude!),
              onTap: () => startNavigation(p),
              infoWindow: InfoWindow(title: p.name),
            ),
          if (fix != null)
            Marker(
              markerId: const MarkerId('me'),
              position: LatLng(fix.latitude, fix.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
              infoWindow: InfoWindow(
                title: location.stale
                    ? 'Last known position'
                    : 'Your device location',
              ),
            ),
        },
        circles: {
          if (fix != null)
            Circle(
              circleId: const CircleId('accuracy'),
              center: LatLng(fix.latitude, fix.longitude),
              radius: fix.accuracy,
              fillColor: Colors.blue.withValues(alpha: .15),
              strokeWidth: 1,
            ),
        },
        polygons: {
          if (boundary.length >= 3)
            Polygon(
              polygonId: const PolygonId('campus'),
              points: boundary
                  .map((v) => LatLng(v.latitude, v.longitude))
                  .toList(),
              fillColor: forest.withValues(alpha: .08),
              strokeWidth: 2,
            ),
        },
        polylines: {
          if (liveRoute != null)
            Polyline(
              polylineId: const PolylineId('route'),
              points: liveRoute!.nodes
                  .map((n) => LatLng(n.lat, n.lng))
                  .toList(),
              color: forest,
              width: 5,
            ),
        },
      );
    }

    return fm.FlutterMap(
      mapController: fmMap,
      options: fm.MapOptions(
        initialCenter: center,
        initialZoom: 16.5,
        minZoom: 3,
        maxZoom: 19,
        onPositionChanged: (pos, hasGesture) {
          if (hasGesture) {
            follow = false;
          }
        },
      ),
      children: [
        fm.TileLayer(
          urlTemplate: tileUrl,
          userAgentPackageName: 'edu.srmap.campus_navigator',
        ),
        fm.RichAttributionWidget(
          attributions: [
            fm.TextSourceAttribution(
              mapType == MapType.satellite
                  ? 'Esri World Imagery'
                  : 'OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse(
                  mapType == MapType.satellite
                      ? 'https://www.esri.com/en-us/legal/terms/full-master-agreement'
                      : 'https://www.openstreetmap.org/copyright',
                ),
              ),
            ),
          ],
        ),
        if (boundary.length >= 3)
          fm.PolygonLayer(
            polygons: [
              fm.Polygon(
                points: boundary
                    .map((v) => ll.LatLng(v.latitude, v.longitude))
                    .toList(),
                color: forest.withValues(alpha: 0.12),
                borderColor: forest,
                borderStrokeWidth: 2.5,
              ),
            ],
          ),
        if (liveRoute != null && liveRoute!.nodes.isNotEmpty)
          fm.PolylineLayer(
            polylines: [
              fm.Polyline(
                points: liveRoute!.nodes
                    .map((n) => ll.LatLng(n.lat, n.lng))
                    .toList(),
                strokeWidth: 8,
                color: const Color(0x601D4ED8),
              ),
              fm.Polyline(
                points: liveRoute!.nodes
                    .map((n) => ll.LatLng(n.lat, n.lng))
                    .toList(),
                strokeWidth: 4.5,
                color: const Color(0xFF2563EB),
              ),
            ],
          ),
        fm.MarkerLayer(
          markers: [
            for (final p in verified)
              fm.Marker(
                point: ll.LatLng(p.latitude!, p.longitude!),
                width: 140,
                height: 64,
                child: GestureDetector(
                  onTap: () => startNavigation(p),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: selected?.id == p.id ? forest : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected?.id == p.id
                                ? lime
                                : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          categoryIcon(p.category),
                          color: selected?.id == p.id ? lime : forest,
                          size: 19,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                            width: 0.8,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x15000000), blurRadius: 3),
                          ],
                        ),
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: forest,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (liveRoute != null && liveRoute!.nodes.isNotEmpty)
              fm.Marker(
                point: ll.LatLng(
                  liveRoute!.nodes.last.lat,
                  liveRoute!.nodes.last.lng,
                ),
                width: 38,
                height: 38,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            if (!gpsNavigation && walkerPosition != null && progress > 0)
              fm.Marker(
                point: walkerPosition!,
                width: 30,
                height: 30,
                child: Container(
                  decoration: BoxDecoration(
                    color: forest,
                    shape: BoxShape.circle,
                    border: Border.all(color: lime, width: 3),
                  ),
                  child: const Icon(
                    Icons.directions_walk,
                    size: 16,
                    color: lime,
                  ),
                ),
              ),
            // Big, clear, easy-to-understand User Marker
            if (fix != null)
              fm.Marker(
                point: ll.LatLng(fix.latitude, fix.longitude),
                width: 110,
                height: 80,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x35000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_pin_circle,
                            size: 11,
                            color: Colors.white,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'YOU ARE HERE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(
                              0xFF3B82F6,
                            ).withValues(alpha: 0.22),
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1D4ED8),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x401D4ED8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.my_location,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProvider);
    // demoSearchProvider already filters by category, name, category text
    // and facilities; only live places need filtering here.
    final places = state.demo && !viewRealMap
        ? ref.watch(demoSearchProvider)
        : mapPlaces
              .where(
                (p) =>
                    (state.category == 'All' || p.category == state.category) &&
                    '${p.name} ${p.category} ${p.facilities.join(' ')}'
                        .toLowerCase()
                        .contains(state.query.toLowerCase()),
              )
              .toList();
    return Scaffold(
      bottomNavigationBar: const AppNavigation(0),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 850;
            final panel = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 24 : 16,
                    wide ? 24 : 12,
                    wide ? 24 : 16,
                    wide ? 14 : 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.explore, color: forest),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'SRM AP / CAMPUS',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          StatusPill(
                            state.demo ? 'SIMULATION' : 'LIVE MODE',
                            warning: state.demo,
                          ),
                        ],
                      ),
                      if (wide) ...[
                        const SizedBox(height: 22),
                        const Text(
                          'Your campus.\nA little closer.',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Find a place. Meet a friend. Explore more.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                      ] else
                        const SizedBox(height: 10),
                      TextField(
                        onChanged: (v) => ref
                            .read(appProvider.notifier)
                            .update(state.copy(query: v)),
                        decoration: const InputDecoration(
                          hintText: 'Where would you like to go?',
                          prefixIcon: Icon(Icons.search),
                          contentPadding: EdgeInsets.all(14),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16),
                    children:
                        [
                              'All',
                              'Study',
                              'Academic',
                              'Facilities',
                              'Food',
                              'Sports',
                              'Living',
                            ]
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    c,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  selected: state.category == c,
                                  onSelected: (_) => ref
                                      .read(appProvider.notifier)
                                      .update(state.copy(category: c)),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                if (wide)
                  Expanded(child: destinationList(places, state.demo))
                else
                  const SizedBox(height: 6),
              ],
            );
            final mapPanel = Stack(
              children: [
                Positioned.fill(child: mapArea(state.demo)),
                Positioned(
                  top: 18,
                  left: 18,
                  child: Row(
                    children: [
                      StatusPill(
                        state.demo && !viewRealMap
                            ? 'EXPLORE THE DEMO'
                            : 'SRM AP LIVE MAP',
                        warning: state.demo && !viewRealMap,
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: Icon(
                          viewRealMap
                              ? Icons.brush_outlined
                              : Icons.map_outlined,
                          size: 15,
                          color: forest,
                        ),
                        label: Text(
                          viewRealMap ? 'Canvas' : 'Live map',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            viewRealMap = !viewRealMap;
                            route = null;
                            liveRoute = null;
                            timer?.cancel();
                            playing = false;
                            if (!viewRealMap) {
                              location.stop();
                            }
                            _triggerLocationBanner();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 18,
                  right: 16,
                  child: Column(
                    children: [
                      CampusCompass(
                        onTap: () {
                          notify('Campus compass oriented to North');
                        },
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton.small(
                        heroTag: 'srm_center',
                        backgroundColor: Colors.white,
                        foregroundColor: forest,
                        tooltip: 'Center on SRM AP Campus',
                        onPressed: () {
                          follow = false;
                          try {
                            fmMap.move(
                              const ll.LatLng(
                                srmApCampusCenterLat,
                                srmApCampusCenterLng,
                              ),
                              16.8,
                            );
                          } catch (_) {}
                          map?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              const LatLng(
                                srmApCampusCenterLat,
                                srmApCampusCenterLng,
                              ),
                              17,
                            ),
                          );
                          notify(
                            'Centered on SRM University AP, Andhra Pradesh',
                          );
                        },
                        child: const Icon(Icons.school_outlined),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton.small(
                        heroTag: 'layers',
                        backgroundColor: Colors.white,
                        foregroundColor: forest,
                        tooltip: 'Map layers',
                        onPressed: () {
                          if (state.demo && !viewRealMap) {
                            notify(
                              'Simulation uses an illustrative schematic. Tap "Live map" or use Live Mode for normal, satellite and hybrid maps.',
                            );
                          } else {
                            setState(
                              () => mapType = mapType == MapType.normal
                                  ? MapType.satellite
                                  : mapType == MapType.satellite
                                  ? MapType.hybrid
                                  : MapType.normal,
                            );
                          }
                        },
                        child: const Icon(Icons.layers_outlined),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton.small(
                        heroTag: 'location',
                        backgroundColor: forest,
                        foregroundColor: Colors.white,
                        tooltip: 'Follow my location',
                        onPressed: () async {
                          if (state.demo && !viewRealMap) {
                            timer?.cancel();
                            setState(() {
                              progress = 0;
                              playing = false;
                            });
                            notify(
                              'Simulated position reset. No device location is used.',
                            );
                            return;
                          }
                          follow = true;
                          await location.start();
                          if (!mounted) return;
                          _triggerLocationBanner();
                          final p = location.position;
                          if (p != null) {
                            try {
                              fmMap.move(
                                ll.LatLng(p.latitude, p.longitude),
                                17.5,
                              );
                            } catch (_) {}
                            if (map != null) {
                              map?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  LatLng(p.latitude, p.longitude),
                                  18,
                                ),
                              );
                            }
                            notify(
                              'Tracking device live location (±${p.accuracy.round()}m)',
                            );
                          } else if (state.demo && !viewRealMap) {
                            setState(() {
                              progress = 0;
                            });
                            notify('Reset simulated position.');
                          } else {
                            notify('Acquiring device GPS fix...');
                          }
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
                if (route != null)
                  Positioned(
                    bottom: 38,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: lime,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.directions_walk,
                                    color: forest,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    progress >= 1
                                        ? 'You’ve arrived · simulated'
                                        : '${route!.minutes} min • ${route!.meters.round()} m',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    timer?.cancel();
                                    setState(() {
                                      route = null;
                                      liveRoute = null;
                                      playing = false;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Current Step Instruction
                            Builder(
                              builder: (context) {
                                final edgeCount = route!.edges.length;
                                var stepIdx = 0;
                                if (edgeCount > 0) {
                                  // Pick the step by distance walked, not step count.
                                  var walked = progress * route!.meters;
                                  while (stepIdx < edgeCount - 1 &&
                                      walked >= route!.edges[stepIdx].meters) {
                                    walked -= route!.edges[stepIdx].meters;
                                    stepIdx++;
                                  }
                                }
                                final instruction = edgeCount > 0
                                    ? route!.edges[stepIdx].instruction
                                    : 'Demo route to ${selected?.name ?? 'destination'}';
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.turn_right_rounded,
                                        size: 18,
                                        color: forest,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          instruction,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: forest,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: progress,
                              color: forest,
                              backgroundColor: lime,
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 6,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Speed Selector Pills
                                Row(
                                  children: [1.0, 2.0, 4.0]
                                      .map(
                                        (s) => Padding(
                                          padding: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          child: InkWell(
                                            onTap: () => ref
                                                .read(appProvider.notifier)
                                                .update(
                                                  state.copy(simSpeed: s),
                                                ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: state.simSpeed == s
                                                    ? forest
                                                    : const Color(0xFFE2E8F0),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${s.toInt()}x',
                                                style: TextStyle(
                                                  color: state.simSpeed == s
                                                      ? lime
                                                      : forest,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const Spacer(),
                                FilledButton.tonalIcon(
                                  onPressed: play,
                                  icon: Icon(
                                    playing ? Icons.pause : Icons.play_arrow,
                                  ),
                                  label: Text(playing ? 'Pause' : 'Walk'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if ((!state.demo || viewRealMap) && showLocationBanner)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 18,
                    child: AnimatedOpacity(
                      opacity: showLocationBanner ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 350),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.my_location,
                                    size: 16,
                                    color: Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      location.message ??
                                          (location.position == null
                                              ? 'Acquiring live device GPS...'
                                              : '${location.stale ? 'STALE • ' : ''}Live GPS: ${location.position!.latitude.toStringAsFixed(5)}, ${location.position!.longitude.toStringAsFixed(5)} (±${location.position!.accuracy.round()}m)'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      locationBannerTimer?.cancel();
                                      setState(
                                        () => showLocationBanner = false,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                boundaryLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              if (nearbyBuilding != null) ...[
                                const SizedBox(height: 4),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 24),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () async {
                                    final p = nearbyBuilding!;
                                    final yes = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        title: Text(
                                          'Are you inside ${p.name}?',
                                        ),
                                        content: const Text(
                                          'Nearby GPS is not proof of building presence. Confirm your building manually.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('Not here'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('Yes'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (!context.mounted) return;
                                    if (yes == true) {
                                      setState(() => confirmedBuilding = p.id);
                                      context.push('/indoor/${p.id}');
                                    }
                                  },
                                  child: Text(
                                    'Confirm building: ${nearbyBuilding!.name}',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
            if (wide) {
              return Row(
                children: [
                  SizedBox(width: 370, child: panel),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: mapPanel,
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                panel,
                Expanded(child: mapPanel),
                SizedBox(
                  height: route == null ? 96 : 0,
                  child: route == null
                      ? destinationList(places, state.demo, horizontal: true)
                      : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget destinationList(
    List<CampusPlace> places,
    bool demo, {
    bool horizontal = false,
  }) {
    if (places.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          dataError ??
              (demo
                  ? 'No places match your search.'
                  : 'No published campus data yet. Add verified locations in Campus Data.'),
        ),
      );
    }
    return ListView(
      scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: horizontal ? 6 : 16,
      ),
      children: [
        if (!horizontal) ...[
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 12, top: 10),
            child: Text(
              'DISCOVER YOUR CAMPUS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!demo)
            Notice(
              location.message ??
                  (location.position == null
                      ? 'Location sharing is off. Enable device location using the map button.'
                      : 'Accuracy ±${location.position!.accuracy.round()} m • ${location.stale ? 'STALE' : 'Last fix'} ${location.position!.timestamp.toLocal()}'),
            ),
          if (!demo) Notice(boundaryLabel),
        ],
        for (final p in places)
          SizedBox(
            width: horizontal ? 240 : null,
            child: Card(
              margin: EdgeInsets.symmetric(
                horizontal: horizontal ? 5 : 0,
                vertical: horizontal ? 2 : 4,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => viewRealMap ? startNavigation(p) : selectPlace(p),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: horizontal ? 8 : 15,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(horizontal ? 8 : 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDF1E5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          categoryIcon(p.category),
                          color: forest,
                          size: horizontal ? 20 : 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: horizontal ? 13 : 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${p.category} • ${demo
                                  ? 'Demo'
                                  : p.verified
                                  ? 'Verified'
                                  : 'Provisional'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: horizontal ? 10 : 11),
                            ),
                          ],
                        ),
                      ),
                      if (!horizontal) const Icon(Icons.north_east, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
