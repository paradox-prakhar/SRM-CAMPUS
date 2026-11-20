import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../application/app_state.dart';
import '../data/geospatial.dart';
import '../data/local_auth.dart';
import '../data/services.dart';
import '../domain/campus.dart';
import 'components.dart';
import 'social.dart';
export 'social.dart';

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > 800;
              final content = Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.explore, color: forest, size: 32),
                        SizedBox(width: 10),
                        Text(
                          'SRM AP\nSMART CAMPUS NAVIGATOR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    const StatusPill('A BETTER WAY TO CAMPUS'),
                    const SizedBox(height: 22),
                    Text(
                      'Less searching.\nMore discovering.',
                      style: TextStyle(
                        fontSize: wide ? 52 : 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Your next lecture, a quiet study spot, or a friend around the corner. Find your way with confidence.',
                      style: TextStyle(fontSize: 16, height: 1.65),
                    ),
                    const SizedBox(height: 24),
                    // Plain feature messages (not buttons), so nothing on the
                    // start page looks tappable without doing anything.
                    const Notice(
                      'What you can do:\n'
                      '• Tap any SRM AP building to get walking directions from your live location.\n'
                      '• Your location stays private. It is never shared unless you invite someone.\n'
                      '• Check indoor floor plans for supported buildings.',
                      icon: Icons.info_outline,
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          ref
                              .read(appProvider.notifier)
                              .update(ref.read(appProvider).copy(demo: true));
                          context.go('/explore');
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Explore interactive demo'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          ref
                              .read(appProvider.notifier)
                              .update(ref.read(appProvider).copy(demo: false));
                          if (LocalAuth.current.value != null) {
                            context.go('/explore');
                          } else {
                            context.push('/auth');
                          }
                        },
                        child: Text(
                          LocalAuth.current.value == null
                              ? 'Sign in / Create account'
                              : 'Continue as ${LocalAuth.current.value!.name}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Demo is a labelled simulation. Live location requires your permission. GPS cannot reliably identify your floor.',
                      style: TextStyle(fontSize: 12, height: 1.6),
                    ),
                  ],
                ),
              );
              final art = ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(
                  children: [
                    // Preview only: taps are ignored so its icons don't act like dead buttons.
                    const Positioned.fill(
                      child: IgnorePointer(child: CampusCanvas()),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 40,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: forest,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusPill('SIMULATION'),
                            SizedBox(height: 12),
                            Text(
                              'A whole campus.\nOne little companion.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Preview only. Tap "Explore interactive demo" to try it.',
                              style: TextStyle(
                                color: Color(0xFFD9E5D8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (wide) {
                return Row(
                  children: [
                    Expanded(child: SingleChildScrollView(child: content)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: art,
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                children: [
                  content,
                  SizedBox(
                    height: 340,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: art,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool register = false, busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit({bool reset = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!AppConfig.ready) {
        // Demo: accounts live only on this device.
        if (register) {
          await LocalAuth.signUp(name.text, email.text, password.text);
        } else {
          await LocalAuth.signIn(email.text, password.text);
        }
        if (mounted) {
          toast(context, 'Welcome, ${LocalAuth.current.value!.name}!');
          context.go('/explore');
        }
        return;
      }
      if (reset) {
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: email.text.trim(),
        );
        if (mounted) {
          toast(context, 'If an account exists, a reset email will be sent.');
        }
      } else {
        if (register) {
          await CampusRepository().register(
            name.text.trim(),
            email.text.trim(),
            password.text,
          );
        } else {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email.text.trim(),
            password: password.text,
          );
        }
        if (mounted) {
          context.go('/explore');
        }
      }
    } on LocalAuthException catch (e) {
      if (mounted) {
        setState(() => error = e.message);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => error = e.message ?? e.code);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not connect. Check configuration and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: register ? 'Make yourself at home.' : 'Welcome back.',
    subtitle: 'Your campus, connected. Your location, always your choice.',
    children: [
      if (!AppConfig.ready)
        const Notice(
          'Demo accounts are saved only on this device. Nothing is sent to a server.',
          icon: Icons.phone_android,
        ),
      if (register) ...[
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        const SizedBox(height: 14),
      ],
      TextField(
        controller: email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email address',
          prefixIcon: Icon(Icons.alternate_email),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: password,
        obscureText: true,
        onSubmitted: (_) => busy ? null : submit(),
        decoration: const InputDecoration(
          labelText: 'Password',
          prefixIcon: Icon(Icons.lock_outline),
        ),
      ),
      const SizedBox(height: 20),
      if (error != null) Notice(error!),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(
          busy
              ? 'Connecting…'
              : register
              ? 'Create account'
              : 'Sign in',
        ),
      ),
      TextButton(
        onPressed: () => setState(() {
          register = !register;
          error = null;
        }),
        child: Text(
          register
              ? 'Already have an account? Sign in'
              : 'New here? Create an account',
        ),
      ),
      TextButton(
        onPressed: AppConfig.ready && !busy ? () => submit(reset: true) : null,
        child: const Text('Forgot password?'),
      ),
      const Notice(
        'Sharing is off by default. Friends cannot see your location unless you explicitly invite them to a sharing session.',
        icon: Icons.verified_user_outlined,
      ),
    ],
  );
}

class IndoorScreen extends ConsumerStatefulWidget {
  final String buildingId;
  const IndoorScreen({super.key, required this.buildingId});
  @override
  ConsumerState<IndoorScreen> createState() => _IndoorState();
}

class _IndoorState extends ConsumerState<IndoorScreen> {
  String floor = 'ground', query = '';
  FloorConfirmation? confirmation;
  List<Map<String, dynamic>> floors = [];
  String? error;
  bool directions = false;
  CampusRoute? indoorRoute;
  List<Map<String, dynamic>> rooms = [];
  Timer? freshness;
  String? selectedRoom;

  String get qrCountdown {
    if (confirmation == null || confirmation!.source != 'qr') return '';
    final expiry = confirmation!.recordedAt.add(confirmation!.ttl);
    final remaining = expiry.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    final m = remaining.inMinutes.toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s remaining';
  }

  @override
  void initState() {
    super.initState();
    freshness = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    if (!ref.read(appProvider).demo && AppConfig.ready) {
      loadFloors();
    }
  }

  @override
  void dispose() {
    freshness?.cancel();
    super.dispose();
  }

  Future<void> loadFloors() async {
    try {
      final result = await FirebaseFirestore.instance
          .collection('floors')
          .where('buildingId', isEqualTo: widget.buildingId)
          .where('verified', isEqualTo: true)
          .get();
      if (mounted) {
        setState(() {
          floors = result.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          if (floors.isNotEmpty) {
            floor = floors.first['id'];
          }
        });
      }
      final roomResult = await FirebaseFirestore.instance
          .collection('rooms')
          .where('buildingId', isEqualTo: widget.buildingId)
          .where('verified', isEqualTo: true)
          .get();
      if (mounted) {
        setState(
          () => rooms = roomResult.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Floor data could not load.');
      }
    }
  }

  Future<void> verify(String payload) async {
    final demo = ref.read(appProvider).demo;
    Map<String, Checkpoint> checkpoints = {};
    if (demo) {
      checkpoints = {
        'library-first': const Checkpoint(
          'library-first',
          'library',
          'first',
          verified: true,
        ),
      };
    } else {
      final uri = Uri.tryParse(payload);
      if (uri == null ||
          uri.scheme != 'srm-campus' ||
          uri.host != 'checkpoint' ||
          uri.pathSegments.length != 1) {
        toast(context, 'Invalid checkpoint QR code.');
        return;
      }
      try {
        final doc = await FirebaseFirestore.instance
            .collection('qrCheckpoints')
            .doc(uri.pathSegments.single)
            .get();
        final data = doc.data();
        if (data != null) {
          checkpoints[doc.id] = Checkpoint(
            doc.id,
            data['buildingId'],
            data['floorId'],
            verified: data['verified'] == true,
          );
        }
      } catch (_) {
        if (mounted) {
          toast(context, 'Checkpoint lookup failed. Retry when connected.');
        }
        return;
      }
    }
    final result = validateCheckpoint(
      payload,
      checkpoints,
      DateTime.now(),
      demo: demo,
    );
    if (!mounted) return;
    if (result == null ||
        result.buildingId != widget.buildingId ||
        (!demo && !floors.any((f) => f['id'] == result.floorId))) {
      toast(context, 'Invalid or unverified checkpoint for this building.');
      return;
    }
    setState(() {
      confirmation = result;
      floor = result.floorId;
      directions = false;
    });
    toast(
      context,
      'Floor confirmed by QR scan. This confirms a checkpoint, not continuous tracking.',
    );
  }

  Future<void> scan() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (code != null) {
      await verify(code);
    }
  }

  Future<void> routeToRoom(Map<String, dynamic> room) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('indoorPaths')
          .doc(widget.buildingId)
          .get();
      final data = doc.data();
      if (!mounted) return;
      if (data == null || data['verified'] != true) {
        toast(context, 'No surveyed indoor graph is available.');
        return;
      }
      final graph = graphFromMap(data);
      final options = graph.nodes.where((n) => n.floor == floor).toList();
      final start = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Confirm your starting checkpoint'),
          children: options
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
      final result = graph.route(start, room['nodeId']);
      if (result == null) {
        toast(context, 'No verified indoor route connects these locations.');
        return;
      }
      setState(() => indoorRoute = result);
    } catch (_) {
      if (mounted) {
        toast(context, 'Indoor routing data could not load.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(appProvider).demo;
    final name = demo
        ? demoPlaces
              .firstWhere(
                (p) => p.id == widget.buildingId,
                orElse: () => demoPlaces.first,
              )
              .name
        : 'Building floors';
    final choices = demo
        ? [
            {'id': 'ground', 'label': 'Ground floor'},
            {'id': 'first', 'label': 'First floor'},
          ]
        : floors;
    final current = choices.where((f) => f['id'] == floor).firstOrNull;
    final plan = current?['planUrl'] as String?;
    return PageShell(
      title: name,
      subtitle: 'One floor at a time. Find your space.',
      children: [
        StatusPill(
          demo ? 'SIMULATION • FICTIONAL FLOOR PLAN' : 'VERIFIED FLOOR RECORDS',
          warning: demo,
        ),
        const Notice(
          'Confirm your building before selecting a floor. GPS does not reliably detect floors. Sensor estimation is unavailable without calibrated campus infrastructure.',
        ),
        Wrap(
          spacing: 10,
          children: choices
              .map(
                (f) => ChoiceChip(
                  label: Text(f['label'] ?? f['id']),
                  selected: floor == f['id'],
                  onSelected: (_) => setState(() {
                    floor = f['id'];
                    confirmation = FloorConfirmation(
                      widget.buildingId,
                      floor,
                      'manual',
                      DateTime.now(),
                    );
                    directions = false;
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        Text(
          confirmation == null
              ? 'Select your floor manually, or scan a checkpoint.'
              : confirmation!.staleAt(DateTime.now())
              ? 'Floor confirmation is stale. Confirm again.'
              : confirmation!.source == 'qr'
              ? 'Floor confirmed by QR scan • ${confirmation!.recordedAt.toLocal().toString().substring(11, 16)}'
              : 'Floor source: manual selection',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (confirmation != null &&
            confirmation!.source == 'qr' &&
            !confirmation!.staleAt(DateTime.now())) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: Color(0xFF15803D),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Checkpoint valid: $qrCountdown',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        if (demo) ...[
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search demo rooms, e.g. Reading room',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 340,
            child: CustomPaint(
              painter: FloorPainter(first: floor == 'first', route: directions),
              child: Center(
                child: Text(
                  floor == 'first'
                      ? 'FIRST FLOOR\nDEMO PLAN'
                      : 'GROUND FLOOR\nDEMO PLAN',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: forest,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
          for (final room
              in (floor == 'first'
                      ? ['Reading room', 'Study room 101', 'Elevator']
                      : ['Reception', 'Book collection', 'Elevator'])
                  .where((r) => r.toLowerCase().contains(query.toLowerCase())))
            ListTile(
              leading: const Icon(Icons.meeting_room_outlined),
              title: Text(room),
              trailing: const Icon(Icons.route),
              onTap: () => setState(() => directions = true),
            ),
          if (directions)
            const Notice(
              'Demo: follow the highlighted corridor from the entrance. For a floor transition, use the illustrated elevator, select the destination floor, then confirm at its checkpoint.',
            ),
        ] else if (plan != null && Uri.tryParse(plan)?.scheme == 'https')
          SizedBox(
            height: 380,
            child: InteractiveViewer(
              child: Image.network(
                plan,
                errorBuilder: (_, _, _) =>
                    const Center(child: Text('Floor plan could not load.')),
              ),
            ),
          )
        else
          Notice(error ?? 'Floor map not yet available.'),
        if (!demo) ...[
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              labelText: 'Search verified rooms',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          for (final room in rooms.where(
            (r) => '${r['name']} ${r['id']}'.toLowerCase().contains(
              query.toLowerCase(),
            ),
          ))
            ListTile(
              title: Text(room['name'] ?? room['id']),
              subtitle: Text('Floor: ${room['floorId']}'),
              trailing: const Icon(Icons.route),
              onTap: () => routeToRoom(room),
            ),
          if (indoorRoute != null) ...[
            const Notice(
              'Indoor route begins at the checkpoint you confirmed. This is not continuous indoor positioning.',
            ),
            for (final edge in indoorRoute!.edges)
              ListTile(
                leading: Icon(
                  indoorRoute!.nodes
                              .firstWhere((n) => n.id == edge.from)
                              .floor !=
                          indoorRoute!.nodes
                              .firstWhere((n) => n.id == edge.to)
                              .floor
                      ? Icons.elevator_outlined
                      : Icons.directions_walk,
                ),
                title: Text(edge.instruction),
                subtitle: Text(
                  'To floor ${indoorRoute!.nodes.firstWhere((n) => n.id == edge.to).floor} • ${edge.meters.round()} m',
                ),
              ),
          ],
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: choices.isEmpty ? null : scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan a floor checkpoint'),
        ),
        if (demo && widget.buildingId == 'library') ...[
          const SizedBox(height: 20),
          const Text(
            'PRESENTATION CHECKPOINT',
            style: TextStyle(fontSize: 11, letterSpacing: 2),
          ),
          Center(
            child: QrImageView(
              data: 'srm-demo://checkpoint/library-first',
              size: 170,
              backgroundColor: Colors.white,
            ),
          ),
          OutlinedButton(
            onPressed: () => verify('srm-demo://checkpoint/library-first'),
            child: const Text('Simulate scanning this QR'),
          ),
        ],
      ],
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerState();
}

class _ScannerState extends State<ScannerScreen> {
  bool completed = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan checkpoint')),
    body: MobileScanner(
      onDetect: (capture) {
        final value = capture.barcodes.firstOrNull?.rawValue;
        if (value != null && !completed) {
          completed = true;
          Navigator.pop(context, value);
        }
      },
    ),
  );
}

class FloorPainter extends CustomPainter {
  final bool first, route;
  FloorPainter({required this.first, required this.route});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)),
      Paint()..color = const Color(0xFFE9EDE1),
    );
    final bounds = Rect.fromLTWH(
      size.width * .08,
      30,
      size.width * .84,
      size.height - 60,
    );
    canvas.drawRect(bounds, Paint()..color = Colors.white);

    // Colored room zones
    final roomColors = [
      (
        Rect.fromLTRB(size.width * .08, 30, size.width * .35, 130),
        const Color(0xFFF1F5F9),
      ),
      (
        Rect.fromLTRB(size.width * .35, 30, size.width * .65, 130),
        const Color(0xFFF8FAFC),
      ),
      (
        Rect.fromLTRB(size.width * .65, 30, size.width * .92, 130),
        const Color(0xFFF3E8FF),
      ),
      (
        Rect.fromLTRB(
          size.width * .08,
          210,
          size.width * .35,
          size.height - 30,
        ),
        const Color(0xFFECFDF5),
      ),
      (
        Rect.fromLTRB(
          size.width * .35,
          210,
          size.width * .65,
          size.height - 30,
        ),
        const Color(0xFFF8FAFC),
      ),
      (
        Rect.fromLTRB(
          size.width * .65,
          210,
          size.width * .92,
          size.height - 30,
        ),
        const Color(0xFFFEF3C7),
      ),
    ];
    for (final (rect, color) in roomColors) {
      canvas.drawRect(rect, Paint()..color = color);
    }

    // Corridor surface
    final corridorRect = Rect.fromLTRB(
      size.width * .08,
      130,
      size.width * .92,
      210,
    );
    canvas.drawRect(corridorRect, Paint()..color = const Color(0xFFFAFBF9));

    final wall = Paint()
      ..color = forest
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(bounds, wall);

    for (final x in [.35, .65]) {
      canvas.drawLine(
        Offset(size.width * x, 30),
        Offset(size.width * x, 130),
        wall,
      );
      canvas.drawLine(
        Offset(size.width * x, 210),
        Offset(size.width * x, size.height - 30),
        wall,
      );
    }
    canvas.drawLine(
      Offset(size.width * .08, 130),
      Offset(size.width * .92, 130),
      wall,
    );
    canvas.drawLine(
      Offset(size.width * .08, 210),
      Offset(size.width * .92, 210),
      wall,
    );

    // Entrance indicator
    canvas.drawCircle(
      Offset(size.width * .08, 170),
      6,
      Paint()..color = const Color(0xFF2563EB),
    );
    final entranceText = TextPainter(
      text: const TextSpan(
        text: 'ENTRY',
        style: TextStyle(
          fontSize: 8.5,
          color: Color(0xFF2563EB),
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    entranceText.paint(canvas, Offset(size.width * .08 + 9, 164));

    for (final (label, x, y) in [
      (first ? 'READING' : 'BOOKS', .20, 80.0),
      (first ? 'STUDY 101' : 'RECEPTION', .5, 80.0),
      ('LIFT', .79, 80.0),
      ('QUIET ZONE', .21, 260.0),
      ('STAIRS', .79, 260.0),
    ]) {
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 10,
            color: forest,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(size.width * x - text.width / 2, y));
    }
    if (route) {
      final path = Path()
        ..moveTo(size.width * .08, 170)
        ..lineTo(size.width * .79, 170)
        ..lineTo(size.width * .79, 110);

      // Glowing underlayer
      canvas.drawPath(
        path,
        Paint()
          ..color = lime.withValues(alpha: 0.7)
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      // Route polyline
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF15803D)
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      // Destination marker pin
      canvas.drawCircle(
        Offset(size.width * .79, 110),
        8,
        Paint()..color = const Color(0xFF15803D),
      );
      canvas.drawCircle(
        Offset(size.width * .79, 110),
        3.5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(FloorPainter old) =>
      first != old.first || route != old.route;
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appProvider);
    return PageShell(
      title: 'Make it yours.',
      subtitle: 'A few preferences. A lot of peace of mind.',
      nav: 3,
      children: [
        SwitchListTile(
          title: const Text('Dark appearance'),
          subtitle: const Text('A softer view after sunset'),
          value: state.dark,
          onChanged: (v) =>
              ref.read(appProvider.notifier).update(state.copy(dark: v)),
        ),
        SwitchListTile(
          title: const Text('Presentation simulation'),
          subtitle: const Text('Fictional map, local data, no real tracking'),
          value: state.demo,
          onChanged: (v) {
            ref
                .read(appProvider.notifier)
                .update(state.copy(demo: v, query: '', category: 'All'));
            context.go(v ? '/explore' : '/auth');
          },
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('Location permissions'),
          trailing: const Icon(Icons.open_in_new),
          onTap: Geolocator.openAppSettings,
        ),
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined),
          title: const Text('Campus data administration'),
          subtitle: const Text('Requires a verified administrator role'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/admin'),
        ),
        const Notice(
          'Foreground only. Tracking stops when the app leaves the foreground. No continuous location history is stored. GPS accuracy varies, and floor confirmation expires after 10 minutes.',
          icon: Icons.privacy_tip_outlined,
        ),
        ListTile(
          leading: const Icon(Icons.restart_alt),
          title: const Text('Reset demo'),
          onTap: () {
            resetDemoSocial();
            ref.read(appProvider.notifier).update(AppState(dark: state.dark));
            context.go('/');
          },
        ),
        ValueListenableBuilder<LocalUser?>(
          valueListenable: LocalAuth.current,
          builder: (context, user, _) => AppConfig.ready
              ? const SizedBox.shrink()
              : user == null
              ? ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Sign in or create an account'),
                  subtitle: const Text('Saved on this device only'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/auth'),
                )
              : Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        child: Text(user.name[0].toUpperCase()),
                      ),
                      title: Text(user.name),
                      subtitle: Text('${user.email} • stored on this device'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Sign out'),
                      onTap: () async {
                        await LocalAuth.signOut();
                        if (context.mounted) context.go('/');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: const Text('Delete account from this device'),
                      onTap: () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete your account?'),
                            content: const Text(
                              'Your demo account will be removed from this device. This cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (yes != true) return;
                        await LocalAuth.deleteAccount();
                        if (context.mounted) context.go('/');
                      },
                    ),
                  ],
                ),
        ),
        if (AppConfig.ready && FirebaseAuth.instance.currentUser != null) ...[
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              try {
                await CampusRepository().call('stopAllSharing');
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  context.go('/');
                }
              } catch (_) {
                if (context.mounted) {
                  toast(
                    context,
                    'Could not revoke sharing. Reconnect and retry sign-out.',
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Delete account'),
            subtitle: const Text(
              'Permanently remove your profile and sharing data',
            ),
            onTap: () async {
              final yes = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Delete your account?'),
                  content: const Text(
                    'Your profile, friendships, invitations and live sharing will be removed. This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Delete account'),
                    ),
                  ],
                ),
              );
              if (yes != true) return;
              try {
                await CampusRepository().call('deleteAccount');
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  context.go('/');
                }
              } catch (_) {
                if (context.mounted) {
                  toast(context, 'Deletion failed. Sign in again and retry.');
                }
              }
            },
          ),
        ],
      ],
    );
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminState();
}

class _AdminState extends State<AdminScreen> {
  bool authorized = false, loading = true, verified = false, published = false;
  String category = 'Study';
  final id = TextEditingController(),
      name = TextEditingController(),
      lat = TextEditingController(),
      lng = TextEditingController(),
      description = TextEditingController();
  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    try {
      final claims = AppConfig.ready
          ? await FirebaseAuth.instance.currentUser?.getIdTokenResult()
          : null;
      if (mounted) {
        setState(() {
          authorized = claims?.claims?['admin'] == true;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [id, name, lat, lng, description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    final latitude = double.tryParse(lat.text),
        longitude = double.tryParse(lng.text);
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(id.text) ||
        name.text.trim().isEmpty ||
        (verified && (latitude == null || longitude == null)) ||
        (latitude != null && (!latitude.isFinite || latitude.abs() > 90)) ||
        (longitude != null && (!longitude.isFinite || longitude.abs() > 180))) {
      toast(
        context,
        'Enter a valid ID, name and surveyed coordinates for verified records.',
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('buildings')
          .doc(id.text)
          .set({
            'name': name.text.trim(),
            'category': category,
            'description': description.text.trim(),
            'latitude': latitude,
            'longitude': longitude,
            'verified': verified,
            'published': published,
            'facilities': <String>[],
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': FirebaseAuth.instance.currentUser!.uid,
          }, SetOptions(merge: true));
      if (mounted) {
        toast(context, 'Campus record saved.');
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Save failed. Check admin authorization and connection.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageShell(
    title: 'Campus data.',
    subtitle: 'Survey first. Verify carefully. Publish with confidence.',
    children: [
      if (loading)
        const LinearProgressIndicator()
      else if (!authorized)
        const Notice(
          'Administrator access required. A server-managed admin claim authorizes map editing; ordinary student accounts cannot edit campus geometry.',
        )
      else ...[
        TextField(
          controller: id,
          decoration: const InputDecoration(labelText: 'Record ID'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Building name'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: category,
          items: [
            'Study',
            'Academic',
            'Food',
            'Sports',
            'Living',
            'Facilities',
          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => setState(() => category = v!),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: lat,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Surveyed latitude',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: lng,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Surveyed longitude',
                ),
              ),
            ),
          ],
        ),
        if (double.tryParse(lat.text) != null &&
            double.tryParse(lng.text) != null) ...[
          const SizedBox(height: 6),
          Text(
            'Notation: ${formatCoordinatesDD(double.parse(lat.text), double.parse(lng.text))} (${formatCoordinatesDMS(double.parse(lat.text), double.parse(lng.text))})',
            style: const TextStyle(
              fontSize: 11.5,
              color: forest,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: description,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description / source notes',
          ),
        ),
        SwitchListTile(
          title: const Text('Coordinates independently verified'),
          value: verified,
          onChanged: (v) => setState(() => verified = v),
        ),
        SwitchListTile(
          title: const Text('Publish record'),
          value: published,
          onChanged: (v) => setState(() => published = v),
        ),
        FilledButton(onPressed: save, child: const Text('Save campus record')),
        const SizedBox(height: 28),
        const AdminRecordEditor(),
      ],
    ],
  );
}

class AdminRecordEditor extends StatefulWidget {
  const AdminRecordEditor({super.key});
  @override
  State<AdminRecordEditor> createState() => _AdminRecordEditorState();
}

class _AdminRecordEditorState extends State<AdminRecordEditor> {
  String collection = 'floors';
  final recordId = TextEditingController(),
      payload = TextEditingController(text: '{\n  "verified": false\n}');
  @override
  void dispose() {
    recordId.dispose();
    payload.dispose();
    super.dispose();
  }

  Future<void> edit(bool save) async {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,80}$').hasMatch(recordId.text)) {
      toast(context, 'Enter a valid record ID.');
      return;
    }
    try {
      final doc = FirebaseFirestore.instance
          .collection(collection)
          .doc(recordId.text);
      if (save) {
        final data = Map<String, dynamic>.from(jsonDecode(payload.text));
        if (data['verified'] is! bool) {
          throw const FormatException('Verification flag required');
        }
        if (['campusPaths', 'indoorPaths'].contains(collection)) {
          graphFromMap(data);
        }
        await doc.set({
          ...data,
          'updatedBy': FirebaseAuth.instance.currentUser!.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          toast(context, 'Record saved.');
        }
      } else {
        final result = await doc.get();
        final data = result.data();
        if (data == null) {
          if (mounted) {
            toast(context, 'No record with this ID.');
          }
          return;
        }
        data.remove('updatedAt');
        data.remove('updatedBy');
        payload.text = const JsonEncoder.withIndent('  ').convert(data);
      }
    } catch (_) {
      if (mounted) {
        toast(
          context,
          'Invalid record or request denied. Check the schema and admin permissions.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Surveyed campus records',
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
      const Notice(
        'Advanced editor: add authorized plan URLs, rooms, entrances, floor connections, checkpoints and surveyed graphs using DATABASE_SCHEMA.md. Never mark illustrative data verified.',
      ),
      DropdownButtonFormField<String>(
        initialValue: collection,
        items: [
          'floors',
          'floorPlans',
          'rooms',
          'buildingEntrances',
          'qrCheckpoints',
          'campusPaths',
          'indoorPaths',
          'campusBoundaries',
        ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => collection = v!),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: recordId,
        decoration: const InputDecoration(labelText: 'Record ID'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: payload,
        maxLines: 12,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: const InputDecoration(labelText: 'Record JSON'),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          OutlinedButton(
            onPressed: () => edit(false),
            child: const Text('Load record'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: () => edit(true),
            child: const Text('Save record'),
          ),
        ],
      ),
    ],
  );
}
