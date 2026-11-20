import 'dart:math';

const officialTour =
    'https://www.srmap.edu.in/life-at-srmap/virtual-campus-tour/';

class CampusPlace {
  final String id, name, category, description;
  final double? latitude, longitude;
  final bool verified;
  final List<String> facilities;
  const CampusPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.latitude,
    this.longitude,
    this.verified = false,
    this.facilities = const [],
  });
  bool get mappable => verified && latitude != null && longitude != null;
  factory CampusPlace.fromMap(String id, Map<String, dynamic> m) => CampusPlace(
    id: id,
    name: m['name'] as String? ?? '',
    category: m['category'] as String? ?? 'Facilities',
    description: m['description'] as String? ?? '',
    latitude: (m['latitude'] as num?)?.toDouble(),
    longitude: (m['longitude'] as num?)?.toDouble(),
    verified: m['verified'] == true,
    facilities: List<String>.from(m['facilities'] ?? []),
  );
}

const srmApCampusCenterLat = 16.46306;
const srmApCampusCenterLng = 80.50667;

const srmApRealPlaces = [
  CampusPlace(
    id: 'srm_library',
    name: 'SRM AP Central Library',
    category: 'Study',
    description: 'Central Library, SRM University AP. State-of-the-art multi-floor research & study spaces.',
    latitude: 16.46396,
    longitude: 80.50738,
    verified: true,
    facilities: ['Digital Library', 'Reading Rooms', 'Air Conditioning', 'Wi-Fi', 'Elevators'],
  ),
  CampusPlace(
    id: 'srm_academic',
    name: 'Academic Block 1',
    category: 'Academic',
    description: 'Main Academic Block with modern lecture halls, research labs, and faculty offices.',
    latitude: 16.46450,
    longitude: 80.50780,
    verified: true,
    facilities: ['Smart Classrooms', 'Computing Labs', 'Physics & Chemistry Labs', 'Restrooms'],
  ),
  CampusPlace(
    id: 'srm_auditorium',
    name: 'SRM University AP Auditorium',
    category: 'Facilities',
    description: 'World-class auditorium for university convocations, cultural events, and symposiums.',
    latitude: 16.46434,
    longitude: 80.50856,
    verified: true,
    facilities: ['1000+ Seating', 'Stage Acoustics', 'AV Facilities', 'Guest Lounge'],
  ),
  CampusPlace(
    id: 'srm_food_court',
    name: 'University Food Court & Mess',
    category: 'Food',
    description: 'Multi-cuisine campus dining, cafeterias, and student leisure hub.',
    latitude: 16.46567,
    longitude: 80.50816,
    verified: true,
    facilities: ['North & South Indian Dining', 'Cafe Coffee Day', 'Bakery', 'Seating Hall'],
  ),
  CampusPlace(
    id: 'srm_sports_ground',
    name: 'Football Ground & Sports Complex',
    category: 'Sports',
    description: 'International size football ground, running track, and outdoor athletic courts.',
    latitude: 16.46095,
    longitude: 80.50779,
    verified: true,
    facilities: ['Football Pitch', 'Running Track', 'Floodlights', 'Dressing Rooms'],
  ),
  CampusPlace(
    id: 'srm_hostel',
    name: 'Student Residences (Ganga & Vedavathi)',
    category: 'Living',
    description: 'Modern on-campus student residential hostel towers with recreational facilities.',
    latitude: 16.46410,
    longitude: 80.50665,
    verified: true,
    facilities: ['Hostel Rooms', 'Dining Mess', 'Gymnasium', '24/7 Security'],
  ),
  CampusPlace(
    id: 'srm_admin',
    name: 'Administrative Block (SR Block)',
    category: 'Admin',
    description: 'Office of the Vice Chancellor, Registrar, Admissions, and Student Affairs.',
    latitude: 16.46277,
    longitude: 80.50671,
    verified: true,
    facilities: ['Admissions Office', 'Finance Desk', 'Student Affairs', 'Conference Room'],
  ),
  CampusPlace(
    id: 'srm_cv_raman',
    name: 'CV Raman Block',
    category: 'Academic',
    description: 'Laboratories, classrooms, and research facilities at CV Raman academic building.',
    latitude: 16.46189,
    longitude: 80.50560,
    verified: true,
    facilities: ['Engineering Workshops', 'Research Labs', 'Faculty Cabins'],
  ),
  CampusPlace(
    id: 'srm_main_gate',
    name: 'Main Campus Gate (SRM University Road)',
    category: 'Gate',
    description: 'Primary security checkpoint and entrance connecting to Neerukonda & Amaravati main road.',
    latitude: 16.45988,
    longitude: 80.50701,
    verified: true,
    facilities: ['Security Checkpost', 'Visitor Registration', 'Bus Pick-up Point'],
  ),
];

const demoPlaces = [
  CampusPlace(
    id: 'library',
    name: 'Central Library',
    category: 'Study',
    description:
        'Find your quiet corner. Explore a fictional library floor plan in this presentation demo.',
    facilities: ['Study spaces', 'Reading rooms', 'Elevator'],
  ),
  CampusPlace(
    id: 'academic',
    name: 'Academic Block',
    category: 'Academic',
    description:
        'Explore classrooms and collaborative learning spaces in the simulation.',
    facilities: ['Classrooms', 'Laboratories'],
  ),
  CampusPlace(
    id: 'auditorium',
    name: 'Auditorium',
    category: 'Facilities',
    description:
        'A destination for campus events. This schematic is illustrative, not surveyed.',
    facilities: ['Events', 'Seating'],
  ),
  CampusPlace(
    id: 'food',
    name: 'Food Court',
    category: 'Food',
    description: 'Meet up for a break in this fictional campus scenario.',
    facilities: ['Dining', 'Seating'],
  ),
  CampusPlace(
    id: 'sports',
    name: 'Sports Ground',
    category: 'Sports',
    description:
        'Explore the sports destination in the presentation simulation.',
    facilities: ['Outdoor sports'],
  ),
  CampusPlace(
    id: 'hostel',
    name: 'Student Residences',
    category: 'Living',
    description:
        'A simulated residential destination. Real hostel data awaits verification.',
    facilities: ['Residence'],
  ),
];

class RouteNode {
  final String id, label, floor;
  final double x, y;
  final double? latitude, longitude;
  const RouteNode(
    this.id,
    this.x,
    this.y, {
    this.label = '',
    this.floor = 'outdoor',
    this.latitude,
    this.longitude,
  });
  double get lat => latitude ?? y;
  double get lng => longitude ?? x;
}

class RouteEdge {
  final String from, to;
  final double meters;
  final bool accessible;
  final String instruction;
  const RouteEdge(
    this.from,
    this.to,
    this.meters, {
    this.accessible = true,
    this.instruction = 'Continue along the path',
  });
}

class CampusRoute {
  final List<RouteNode> nodes;
  final List<RouteEdge> edges;
  const CampusRoute(this.nodes, this.edges);
  double get meters => edges.fold(0, (sum, e) => sum + e.meters);
  int get minutes => max(1, (meters / 75).ceil());
}

class RoutingGraph {
  final List<RouteNode> nodes;
  final List<RouteEdge> edges;
  const RoutingGraph(this.nodes, this.edges);
  CampusRoute? route(String start, String end, {bool accessible = false}) {
    final byId = {for (final n in nodes) n.id: n};
    if (!byId.containsKey(start) || !byId.containsKey(end)) return null;
    final distance = <String, double>{start: 0};
    final previous = <String, RouteEdge>{};
    final remaining = byId.keys.toSet();
    while (remaining.isNotEmpty) {
      final current = remaining.reduce(
        (a, b) =>
            (distance[a] ?? double.infinity) <= (distance[b] ?? double.infinity)
            ? a
            : b,
      );
      if (distance[current] == null) {
        break;
      }
      remaining.remove(current);
      if (current == end) {
        break;
      }
      for (final e in edges.where(
        (e) => e.from == current && (!accessible || e.accessible),
      )) {
        if (!byId.containsKey(e.to) || e.meters < 0 || !e.meters.isFinite) {
          continue;
        }
        final candidate = distance[current]! + e.meters;
        if (candidate < (distance[e.to] ?? double.infinity)) {
          distance[e.to] = candidate;
          previous[e.to] = e;
        }
      }
    }
    if (!distance.containsKey(end)) {
      return null;
    }
    final steps = <RouteEdge>[];
    var cursor = end;
    while (cursor != start) {
      final edge = previous[cursor];
      if (edge == null) return null;
      steps.insert(0, edge);
      cursor = edge.from;
    }
    return CampusRoute([byId[start]!, ...steps.map((e) => byId[e.to]!)], steps);
  }
}

final demoGraph = RoutingGraph(
  const [
    RouteNode('start', .50, .85, label: 'You'),
    RouteNode('junction', .50, .59, label: 'Central Quad'),
    RouteNode('north', .50, .32, label: 'North Quad'),
    RouteNode('library', .25, .32, label: 'Central Library'),
    RouteNode('academic', .73, .32, label: 'Academic Block'),
    RouteNode('food', .25, .59, label: 'Food Court'),
    RouteNode('auditorium', .73, .59, label: 'Auditorium'),
    RouteNode('sports', .25, .85, label: 'Sports Ground'),
    RouteNode('hostel', .73, .85, label: 'Hostels'),
  ],
  const [
    RouteEdge('start', 'junction', 85.0, instruction: 'Proceed north along Campus Promenade toward Central Quad'),
    RouteEdge('junction', 'start', 85.0, instruction: 'Head south along Campus Promenade'),
    RouteEdge('junction', 'north', 90.0, instruction: 'Continue straight past Central Quad'),
    RouteEdge('north', 'junction', 90.0, instruction: 'Head south toward Central Quad junction'),
    RouteEdge('north', 'library', 65.0, instruction: 'Turn left toward Central Library Main Entrance'),
    RouteEdge('library', 'north', 65.0, instruction: 'Exit Central Library toward North Quad'),
    RouteEdge('north', 'academic', 60.0, instruction: 'Turn right toward Academic Block 1 Entrance'),
    RouteEdge('academic', 'north', 60.0, instruction: 'Head west toward North Quad'),
    RouteEdge('junction', 'food', 65.0, instruction: 'Turn left toward Food Court & Student Center'),
    RouteEdge('food', 'junction', 65.0, instruction: 'Walk east toward Central Quad junction'),
    RouteEdge('junction', 'auditorium', 60.0, instruction: 'Turn right toward University Auditorium'),
    RouteEdge('auditorium', 'junction', 60.0, instruction: 'Walk west toward Central Quad junction'),
    RouteEdge('start', 'sports', 65.0, instruction: 'Turn left toward Football Ground & Sports Arena'),
    RouteEdge('sports', 'start', 65.0, instruction: 'Head east toward Main Promenade'),
    RouteEdge('start', 'hostel', 60.0, instruction: 'Turn right toward Student Residences'),
    RouteEdge('hostel', 'start', 60.0, instruction: 'Head west toward Main Promenade'),
  ],
);

final srmApRealGraph = RoutingGraph(
  const [
    RouteNode(
      'srm_main_gate',
      80.50701,
      16.45988,
      label: 'Main Campus Gate',
      latitude: 16.45988,
      longitude: 80.50701,
    ),
    RouteNode(
      'srm_promenade_south',
      80.50695,
      16.46095,
      label: 'South Promenade Junction',
      latitude: 16.46095,
      longitude: 80.50695,
    ),
    RouteNode(
      'srm_sports_ground',
      80.50779,
      16.46095,
      label: 'Football Ground & Sports Complex',
      latitude: 16.46095,
      longitude: 80.50779,
    ),
    RouteNode(
      'srm_cv_raman',
      80.50560,
      16.46189,
      label: 'CV Raman Block',
      latitude: 16.46189,
      longitude: 80.50560,
    ),
    RouteNode(
      'srm_promenade_mid',
      80.50695,
      16.46277,
      label: 'Central Quad Promenade',
      latitude: 16.46277,
      longitude: 80.50695,
    ),
    RouteNode(
      'srm_admin',
      80.50671,
      16.46277,
      label: 'Administrative Block (SR Block)',
      latitude: 16.46277,
      longitude: 80.50671,
    ),
    RouteNode(
      'srm_hostel',
      80.50665,
      16.46410,
      label: 'Student Residences (Ganga & Vedavathi)',
      latitude: 16.46410,
      longitude: 80.50665,
    ),
    RouteNode(
      'srm_library',
      80.50738,
      16.46396,
      label: 'SRM AP Central Library',
      latitude: 16.46396,
      longitude: 80.50738,
    ),
    RouteNode(
      'srm_academic',
      80.50780,
      16.46450,
      label: 'Academic Block 1',
      latitude: 16.46450,
      longitude: 80.50780,
    ),
    RouteNode(
      'srm_auditorium',
      80.50856,
      16.46434,
      label: 'SRM University AP Auditorium',
      latitude: 16.46434,
      longitude: 80.50856,
    ),
    RouteNode(
      'srm_food_court',
      80.50816,
      16.46567,
      label: 'University Food Court & Mess',
      latitude: 16.46567,
      longitude: 80.50816,
    ),
  ],
  const [
    RouteEdge('srm_main_gate', 'srm_promenade_south', 119.0, instruction: 'Walk north along Main Promenade toward campus center'),
    RouteEdge('srm_promenade_south', 'srm_main_gate', 119.0, instruction: 'Walk south along Main Promenade toward Main Gate'),

    RouteEdge('srm_promenade_south', 'srm_sports_ground', 90.0, instruction: 'Turn right toward Football Ground and athletic running track'),
    RouteEdge('srm_sports_ground', 'srm_promenade_south', 90.0, instruction: 'Exit Football Ground west toward South Promenade'),

    RouteEdge('srm_promenade_south', 'srm_cv_raman', 175.0, instruction: 'Take the south-west walkway toward CV Raman Block'),
    RouteEdge('srm_cv_raman', 'srm_promenade_south', 175.0, instruction: 'Head north-east along the path toward Central Promenade'),

    RouteEdge('srm_promenade_south', 'srm_promenade_mid', 202.0, instruction: 'Proceed north through the central tree promenade'),
    RouteEdge('srm_promenade_mid', 'srm_promenade_south', 202.0, instruction: 'Proceed south along the central promenade'),

    RouteEdge('srm_promenade_mid', 'srm_admin', 30.0, instruction: 'Turn left to Administrative Block (SR Block)'),
    RouteEdge('srm_admin', 'srm_promenade_mid', 30.0, instruction: 'Exit Administrative Block to Central Promenade'),

    RouteEdge('srm_admin', 'srm_hostel', 135.0, instruction: 'Walk north toward Ganga & Vedavathi Student Residences'),
    RouteEdge('srm_hostel', 'srm_admin', 135.0, instruction: 'Walk south toward Administrative Block'),

    RouteEdge('srm_promenade_mid', 'srm_library', 95.0, instruction: 'Turn right toward Central Library & X-Lab Complex'),
    RouteEdge('srm_library', 'srm_promenade_mid', 95.0, instruction: 'Exit Central Library west toward Central Promenade'),

    RouteEdge('srm_hostel', 'srm_library', 80.0, instruction: 'Walk east across the quad to Central Library'),
    RouteEdge('srm_library', 'srm_hostel', 80.0, instruction: 'Walk west toward Hostel Towers'),

    RouteEdge('srm_library', 'srm_academic', 75.0, instruction: 'Proceed north-east to Academic Block 1 entrance'),
    RouteEdge('srm_academic', 'srm_library', 75.0, instruction: 'Walk south-west toward Central Library'),

    RouteEdge('srm_academic', 'srm_auditorium', 85.0, instruction: 'Turn right toward University Auditorium & Gate 3'),
    RouteEdge('srm_auditorium', 'srm_academic', 85.0, instruction: 'Walk west toward Academic Block 1'),

    RouteEdge('srm_academic', 'srm_food_court', 135.0, instruction: 'Proceed north toward University Food Court & Annapurna Mess'),
    RouteEdge('srm_food_court', 'srm_academic', 135.0, instruction: 'Walk south toward Academic Block 1'),

    RouteEdge('srm_auditorium', 'srm_food_court', 155.0, instruction: 'Walk north-west toward Food Court & Annapurna Mess'),
    RouteEdge('srm_food_court', 'srm_auditorium', 155.0, instruction: 'Walk south-east toward Auditorium'),
  ],
);

class FloorConfirmation {
  final String buildingId, floorId, source;
  final DateTime recordedAt;
  final Duration ttl;
  const FloorConfirmation(
    this.buildingId,
    this.floorId,
    this.source,
    this.recordedAt, {
    this.ttl = const Duration(minutes: 10),
  });
  bool staleAt(DateTime now) =>
      now.isBefore(recordedAt) || now.difference(recordedAt) >= ttl;
}

class Checkpoint {
  final String id, buildingId, floorId;
  final bool verified;
  const Checkpoint(
    this.id,
    this.buildingId,
    this.floorId, {
    required this.verified,
  });
}

FloorConfirmation? validateCheckpoint(
  String payload,
  Map<String, Checkpoint> checkpoints,
  DateTime now, {
  bool demo = false,
}) {
  final uri = Uri.tryParse(payload);
  if (uri == null ||
      uri.scheme != (demo ? 'srm-demo' : 'srm-campus') ||
      uri.host != 'checkpoint' ||
      uri.pathSegments.length != 1 ||
      uri.hasQuery ||
      uri.hasFragment) {
    return null;
  }
  final checkpoint = checkpoints[uri.pathSegments.single];
  if (checkpoint == null || !checkpoint.verified) {
    return null;
  }
  return FloorConfirmation(
    checkpoint.buildingId,
    checkpoint.floorId,
    'qr',
    now,
  );
}

class FloorTransform {
  final double width, height;
  const FloorTransform(this.width, this.height);
  Point<double> toPixels(Point<double> normalized) =>
      Point(normalized.x * width, normalized.y * height);
  Point<double> toNormalized(Point<double> pixels) =>
      Point(pixels.x / width, pixels.y / height);
}

enum BoundaryStatus { inside, outside, uncertain, unavailable }

BoundaryStatus classifyBoundary(
  Point<double> position,
  List<Point<double>> polygon,
  double accuracy,
) {
  if (polygon.length < 3) {
    return BoundaryStatus.unavailable;
  }
  if (!accuracy.isFinite || accuracy < 0) {
    return BoundaryStatus.uncertain;
  }
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final a = polygon[j], b = polygon[i];
    final dx = b.x - a.x, dy = b.y - a.y;
    final squared = dx * dx + dy * dy;
    final t = squared == 0
        ? 0.0
        : (((position.x - a.x) * dx + (position.y - a.y) * dy) / squared).clamp(
            0.0,
            1.0,
          );
    if (position.distanceTo(Point(a.x + t * dx, a.y + t * dy)) <= accuracy) {
      return BoundaryStatus.uncertain;
    }
    if ((a.y > position.y) != (b.y > position.y) &&
        position.x < (b.x - a.x) * (position.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside ? BoundaryStatus.inside : BoundaryStatus.outside;
}
