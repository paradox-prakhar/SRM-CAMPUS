import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:campus_navigator/domain/campus.dart';

void main() {
  test('Dijkstra chooses shortest route and returns real graph edges', () {
    final route = demoGraph.route('start', 'library')!;
    expect(route.meters, 240);
    expect(route.nodes.map((n) => n.id), [
      'start',
      'junction',
      'north',
      'library',
    ]);
    expect(demoGraph.route('start', 'missing'), isNull);
  });
  test(
    'accessible routing avoids stairs, disconnected nodes have no route',
    () {
      const graph = RoutingGraph(
        [
          RouteNode('a', 0, 0),
          RouteNode('b', 0, 1),
          RouteNode('c', 1, 1),
          RouteNode('d', 2, 2),
        ],
        [
          RouteEdge('a', 'b', 5, accessible: false),
          RouteEdge('a', 'c', 10),
          RouteEdge('c', 'b', 10),
        ],
      );
      expect(graph.route('a', 'b')!.meters, 5);
      expect(graph.route('a', 'b', accessible: true)!.meters, 20);
      expect(graph.route('a', 'd'), isNull);
    },
  );
  test('floor QR rejects wrong namespace, arbitrary URLs and unknown IDs', () {
    final now = DateTime.utc(2026);
    const checkpoints = {
      'c1': Checkpoint('c1', 'library', 'first', verified: true),
      'draft': Checkpoint('draft', 'library', 'ground', verified: false),
    };
    expect(
      validateCheckpoint(
        'srm-campus://checkpoint/c1',
        checkpoints,
        now,
      )!.floorId,
      'first',
    );
    for (final payload in [
      'https://checkpoint/c1',
      'srm-demo://checkpoint/c1',
      'srm-campus://checkpoint/missing',
      'srm-campus://checkpoint/draft',
      'srm-campus://checkpoint/c1?override=1',
    ]) {
      expect(validateCheckpoint(payload, checkpoints, now), isNull);
    }
  });
  test('confirmation expires at exact TTL and rejects backwards time', () {
    final now = DateTime.utc(2026);
    final c = FloorConfirmation('b', 'f', 'qr', now);
    expect(c.staleAt(now.add(const Duration(minutes: 9))), false);
    expect(c.staleAt(now.add(const Duration(minutes: 10))), true);
    expect(c.staleAt(now.subtract(const Duration(seconds: 1))), true);
  });
  test('floor coordinate transformation round trips', () {
    const t = FloorTransform(600, 400);
    const p = Point(.25, .75);
    expect(t.toPixels(p), const Point(150.0, 300.0));
    expect(t.toNormalized(t.toPixels(p)), p);
  });
  test('boundary distinguishes inside, outside, uncertain and missing', () {
    const polygon = [
      Point(0.0, 0.0),
      Point(100.0, 0.0),
      Point(100.0, 100.0),
      Point(0.0, 100.0),
    ];
    expect(
      classifyBoundary(const Point(50, 50), polygon, 5),
      BoundaryStatus.inside,
    );
    expect(
      classifyBoundary(const Point(120, 50), polygon, 5),
      BoundaryStatus.outside,
    );
    expect(
      classifyBoundary(const Point(2, 50), polygon, 5),
      BoundaryStatus.uncertain,
    );
    expect(
      classifyBoundary(const Point(2, 50), [], 5),
      BoundaryStatus.unavailable,
    );
  });
  test('unverified places never become map markers', () {
    expect(demoPlaces.every((p) => !p.mappable), true);
    expect(
      const CampusPlace(
        id: 'p',
        name: 'P',
        category: 'Study',
        description: '',
        latitude: 1,
        longitude: 2,
      ).mappable,
      false,
    );
  });
  test(
    'legacy sample graph routing is internally consistent, not survey-verified',
    () {
      final toSports = srmApRealGraph.route(
        'srm_main_gate',
        'srm_sports_ground',
      )!;
      expect(toSports.meters, 209);
      expect(toSports.nodes.map((n) => n.id), [
        'srm_main_gate',
        'srm_promenade_south',
        'srm_sports_ground',
      ]);
      expect(toSports.edges.first.instruction, contains('Main Promenade'));

      final toLibrary = srmApRealGraph.route('srm_main_gate', 'srm_library')!;
      expect(toLibrary.nodes.last.id, 'srm_library');
      expect(toLibrary.meters > 0, true);
    },
  );
}
