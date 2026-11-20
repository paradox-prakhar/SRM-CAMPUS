import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../application/app_state.dart';
import '../data/geospatial.dart';
import '../domain/campus.dart';

IconData categoryIcon(String category) => switch (category) {
  'Study' => Icons.local_library_rounded,
  'Academic' => Icons.school_rounded,
  'Food' => Icons.restaurant_rounded,
  'Sports' => Icons.sports_soccer_rounded,
  'Living' => Icons.apartment_rounded,
  'Facilities' => Icons.theater_comedy_rounded,
  'Admin' => Icons.account_balance_rounded,
  'Medical' => Icons.local_hospital_rounded,
  'Gate' => Icons.door_sliding_rounded,
  _ => Icons.location_city_rounded,
};

class StatusPill extends StatelessWidget {
  final String text;
  final bool warning;
  const StatusPill(this.text, {super.key, this.warning = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFFEDCC) : lime,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: warning ? const Color(0xFF795219) : forest,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

class Notice extends StatelessWidget {
  final String text;
  final IconData icon;
  const Notice(this.text, {super.key, this.icon = Icons.info_outline});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
      ],
    ),
  );
}

class AppNavigation extends StatelessWidget {
  final int selected;
  const AppNavigation(this.selected, {super.key});
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selected,
    onDestinationSelected: (i) =>
        context.go(['/explore', '/sharing', '/friends', '/settings'][i]),
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.explore_outlined),
        selectedIcon: Icon(Icons.explore),
        label: 'Explore',
      ),
      NavigationDestination(icon: Icon(Icons.radar), label: 'Live sharing'),
      NavigationDestination(icon: Icon(Icons.people_outline), label: 'Friends'),
      NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
    ],
  );
}

class PageShell extends StatelessWidget {
  final String title, subtitle;
  final List<Widget> children;
  final int? nav;
  const PageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.nav,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'SRM AP / CAMPUS',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    ),
    bottomNavigationBar: nav == null ? null : AppNavigation(nav!),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// Fictional normalized illustration. These coordinates are never latitude/longitude.
class CampusCanvas extends StatefulWidget {
  final CampusRoute? route;
  final double progress;
  final String? selected;
  final bool friend;
  final ValueChanged<String>? onSelect;
  const CampusCanvas({
    super.key,
    this.route,
    this.progress = 0,
    this.selected,
    this.onSelect,
    this.friend = false,
  });

  @override
  State<CampusCanvas> createState() => _CampusCanvasState();
}

class _CampusCanvasState extends State<CampusCanvas> {
  bool _showLabel = true;
  Timer? _labelTimer;

  @override
  void initState() {
    super.initState();
    _labelTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showLabel = false);
      }
    });
  }

  @override
  void dispose() {
    _labelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      final nodes = demoGraph.nodes;
      Offset pos(RouteNode n) => Offset(n.x * w, (n.y * .79 + .02) * h);
      Offset student = pos(nodes.first);
      double angle = 0;
      if (widget.route != null && widget.route!.nodes.length > 1) {
        final step =
            widget.progress.clamp(0.0, .9999) *
            (widget.route!.nodes.length - 1);
        final fromNode = widget.route!.nodes[step.floor()];
        final toNode = widget.route!.nodes[step.floor() + 1];
        final p1 = pos(fromNode);
        final p2 = pos(toNode);
        student = Offset.lerp(p1, p2, step % 1)!;
        angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      }
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: CampusPainter(
                route: widget.route,
                progress: widget.progress,
              ),
            ),
          ),
          for (final p in demoPlaces)
            Positioned(
              left: pos(nodes.firstWhere((n) => n.id == p.id)).dx - 60,
              top: pos(nodes.firstWhere((n) => n.id == p.id)).dy - 32,
              width: 120,
              child: Semantics(
                button: true,
                label: p.name,
                child: InkWell(
                  onTap: () => widget.onSelect?.call(p.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: widget.selected == p.id
                              ? forest
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.selected == p.id
                                ? lime
                                : const Color(0xFFE2E8F0),
                            width: widget.selected == p.id ? 2.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.selected == p.id
                                  ? forest.withValues(alpha: 0.3)
                                  : const Color(0x18000000),
                              blurRadius: widget.selected == p.id ? 16 : 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          categoryIcon(p.category),
                          color: widget.selected == p.id ? lime : forest,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .96),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0F000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          p.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: widget.selected == p.id
                                ? forest
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Google Maps Style Blue Dot & Direction Cone Marker
          Positioned(
            left: student.dx - 35,
            top: student.dy - 35,
            child: GoogleMapsUserMarker(
              heading: widget.route != null ? (angle * 180 / math.pi) : 0,
              label: widget.route != null ? 'NAVIGATING' : null,
            ),
          ),
          if (widget.friend)
            Positioned(
              left: w * .53,
              top: h * .36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF9333EA).withValues(alpha: 0.18),
                    ),
                  ),
                  const CircleAvatar(
                    radius: 17,
                    backgroundColor: Color(0xFF9333EA),
                    child: Text(
                      'A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_showLabel)
            Positioned(
              left: 18,
              bottom: 18,
              child: AnimatedOpacity(
                opacity: _showLabel ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'SRM AP SIMULATION • CAMPUS PROMENADE',
                    style: TextStyle(
                      color: forest,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class CampusPainter extends CustomPainter {
  final CampusRoute? route;
  final double progress;
  CampusPainter({this.route, this.progress = 0});
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset pos(RouteNode n) => Offset(n.x * w, (n.y * .79 + .02) * h);

    // Canvas Background / Campus Grass Surface
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8EFE5),
    );

    // Subtle Garden Quads
    final quadPaint = Paint()..color = const Color(0xFFDCE8D7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.22, w * 0.72, h * 0.52),
        const Radius.circular(24),
      ),
      quadPaint,
    );

    // Football / Sports Ground Layout with Pitch Markings
    final sportsPos = pos(demoGraph.nodes.firstWhere((n) => n.id == 'sports'));
    final sportsRect = Rect.fromCenter(
      center: sportsPos.translate(0, -6),
      width: w * .24,
      height: h * .12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(sportsRect, const Radius.circular(8)),
      Paint()..color = const Color(0xFF9EC588),
    );
    final pitchLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(sportsRect.deflate(5), const Radius.circular(4)),
      pitchLine,
    );
    canvas.drawLine(
      Offset(sportsRect.left + 5, sportsRect.center.dy),
      Offset(sportsRect.right - 5, sportsRect.center.dy),
      pitchLine,
    );
    canvas.drawCircle(sportsRect.center, 12, pitchLine);

    // Tree Clusters around campus
    final random = math.Random(14);
    for (var i = 0; i < 75; i++) {
      final x = random.nextDouble() * w, y = random.nextDouble() * h;
      if ((x / w - .5).abs() < .08 || (y / h - .59).abs() < .06) continue;
      canvas.drawCircle(
        Offset(x, y),
        6 + random.nextDouble() * 6,
        Paint()..color = const Color(0xFFB5CF9B).withValues(alpha: .7),
      );
    }

    // Surveyed / Simulated Building Footprints
    for (final n in demoGraph.nodes.where(
      (n) => demoPlaces.any((p) => p.id == n.id && p.id != 'sports'),
    )) {
      final c = pos(n);
      final rect = Rect.fromCenter(
        center: c.translate(0, -6),
        width: w * .22,
        height: h * .115,
      );
      // Soft drop shadow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.translate(4, 5),
          const Radius.circular(10),
        ),
        Paint()..color = const Color(0xFFC7CDBC),
      );
      // Building base
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()..color = const Color(0xFFF9FBF8),
      );
      // Inner structural accent
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(6), const Radius.circular(6)),
        Paint()
          ..color = const Color(0xFFE2E8DD)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    // Walking Roads / Pathways
    for (final edge in demoGraph.edges) {
      final a = pos(demoGraph.nodes.firstWhere((n) => n.id == edge.from)),
          b = pos(demoGraph.nodes.firstWhere((n) => n.id == edge.to));
      // Outer path border
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFFCBD5E1)
          ..strokeWidth = 20
          ..strokeCap = StrokeCap.round,
      );
      // Main pathway surface
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFFF8FAFC)
          ..strokeWidth = 15
          ..strokeCap = StrokeCap.round,
      );
    }

    // Central Quad / Walkway Intersections
    for (final n in ['junction', 'north', 'start']) {
      final p = pos(demoGraph.nodes.firstWhere((node) => node.id == n));
      canvas.drawCircle(p, 9, Paint()..color = const Color(0xFFF8FAFC));
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFFCBD5E1));
    }

    // Active Navigation Route Polyline
    if (route != null) {
      final path = Path();
      for (var i = 0; i < route!.nodes.length; i++) {
        final p = pos(route!.nodes[i]);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      // Glowing underlayer
      canvas.drawPath(
        path,
        Paint()
          ..color = lime.withValues(alpha: 0.6)
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      // Route line
      canvas.drawPath(
        path,
        Paint()
          ..color = forest
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(CampusPainter oldDelegate) =>
      oldDelegate.route != route || oldDelegate.progress != progress;
}

class DirectionConePainter extends CustomPainter {
  final double heading; // in degrees
  final Color color;
  const DirectionConePainter({
    required this.heading,
    this.color = const Color(0x701A73E8),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final headingRad = heading * math.pi / 180;
    const sweepAngle = 60 * math.pi / 180; // 60 degree cone beam
    final startAngle = headingRad - math.pi / 2 - sweepAngle / 2;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0.0)],
        stops: const [0.15, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DirectionConePainter oldDelegate) =>
      oldDelegate.heading != heading || oldDelegate.color != color;
}

class GoogleMapsUserMarker extends StatelessWidget {
  final double heading;
  final String? label;
  final VoidCallback? onTap;
  const GoogleMapsUserMarker({
    super.key,
    this.heading = 0,
    this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x35000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Translucent Pulsing Accuracy Ring
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A73E8).withValues(alpha: 0.18),
                  ),
                ),
                // Google Maps Direction Cone Beam
                CustomPaint(
                  size: const Size(70, 70),
                  painter: DirectionConePainter(heading: heading),
                ),
                // Google Maps Signature Blue Dot with White Ring
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1A73E8),
                    border: Border.all(color: Colors.white, width: 3.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x401A73E8),
                        spreadRadius: 3,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CampusCompass extends StatelessWidget {
  final double heading;
  final VoidCallback? onTap;
  const CampusCompass({super.key, this.heading = 0, this.onTap});
  @override
  Widget build(BuildContext context) {
    final cardinal = formatCardinalDirection(heading);
    return Tooltip(
      message: 'Compass • $cardinal (${heading.round()}°)',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'N',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: (heading % 360).abs() < 15
                      ? Colors.red
                      : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 1),
              Transform.rotate(
                angle: heading * (math.pi / 180),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: const Size(8, 11),
                          painter: _CompassNeedlePainter(Colors.red),
                        ),
                        CustomPaint(
                          size: const Size(8, 11),
                          painter: _CompassNeedlePainter(
                            const Color(0xFF64748B),
                            upsideDown: true,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompassNeedlePainter extends CustomPainter {
  final Color color;
  final bool upsideDown;
  _CompassNeedlePainter(this.color, {this.upsideDown = false});
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (!upsideDown) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width / 2, size.height * 0.7);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height * 0.3);
      path.lineTo(0, 0);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CompassNeedlePainter old) =>
      old.color != color || old.upsideDown != upsideDown;
}
