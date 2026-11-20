import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:campus_navigator/data/services.dart';

void main() {
  test('dispose during a permission check never starts tracking', () async {
    final permission = Completer<LocationPermission>();
    var subscribed = false;
    final location = DeviceLocation(
      serviceEnabled: () async => true,
      checkPermission: () => permission.future,
      positions: () {
        subscribed = true;
        return const Stream.empty();
      },
    );
    final starting = location.start();
    await Future<void>.delayed(Duration.zero);
    location.dispose();
    permission.complete(LocationPermission.whileInUse);
    await starting;
    expect(subscribed, isFalse);
  });
  test('stop during permission request cancels pending start', () async {
    final permission = Completer<LocationPermission>();
    var subscribed = false;
    final location = DeviceLocation(
      serviceEnabled: () async => true,
      checkPermission: () async => LocationPermission.denied,
      requestPermission: () => permission.future,
      positions: () {
        subscribed = true;
        return const Stream.empty();
      },
    );
    final starting = location.start();
    await Future<void>.delayed(Duration.zero);
    await location.stop();
    permission.complete(LocationPermission.whileInUse);
    await starting;
    expect(subscribed, isFalse);
    expect(location.active, isFalse);
    location.dispose();
  });
  test('platform failures become actionable location messages', () async {
    final location = DeviceLocation(
      serviceEnabled: () async => throw StateError('platform unavailable'),
    );
    await location.start();
    expect(location.active, isFalse);
    expect(location.message, contains('unavailable'));
    location.dispose();
  });
}
