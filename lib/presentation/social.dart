import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../application/app_state.dart';
import '../data/geospatial.dart';
import '../data/services.dart';
import 'components.dart';

final demoFriends = <String>{'Ananya'};
void resetDemoSocial() {
  demoFriends
    ..clear()
    ..add('Ananya');
}

class SharingScreen extends ConsumerStatefulWidget {
  const SharingScreen({super.key});
  @override
  ConsumerState<SharingScreen> createState() => _SharingState();
}

class _SharingState extends ConsumerState<SharingScreen>
    with WidgetsBindingObserver {
  final recipient = TextEditingController(), invite = TextEditingController();
  final repo = CampusRepository();
  late final DeviceLocation location;
  bool active = false, busy = false;
  int minutes = 15;
  String? sessionId, invitationId, message;
  DateTime? expires;
  Timer? timer;
  DateTime? lastUpload;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    location = DeviceLocation(
      onPosition: (position) async {
        if (!active || sessionId == null || ref.read(appProvider).demo) {
          return;
        }
        if (lastUpload != null &&
            DateTime.now().difference(lastUpload!).inSeconds < 5) {
          return;
        }
        lastUpload = DateTime.now();
        await repo.call('publishLocation', {
          'sessionId': sessionId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracy,
          'recordedAt': position.timestamp.millisecondsSinceEpoch,
        });
      },
    );
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (active && expires != null && !DateTime.now().isBefore(expires!)) {
        stop();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      location.stop();
    } else if (active &&
        expires != null &&
        expires!.isAfter(DateTime.now()) &&
        !ref.read(appProvider).demo) {
      location.start();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    location.dispose();
    recipient.dispose();
    invite.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> action(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        setState(
          () => message =
              'Request failed. Check sign-in, friendship, session expiry and connection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> start() => action(() async {
    final demo = ref.read(appProvider).demo;
    if (demo) {
      if (!demoFriends.contains('Ananya')) {
        setState(
          () => message = 'Add Ananya in Friends before starting the demo.',
        );
        return;
      }
      setState(() {
        active = true;
        expires = DateTime.now().add(
          Duration(minutes: minutes == 0 ? 1440 : minutes),
        );
        message =
            'SIMULATION: Ananya accepted your invitation. No real location is shared.';
      });
      return;
    }
    final result = await repo.call('createShare', {
      'viewerId': recipient.text.trim(),
      'minutes': minutes,
    });
    if (!mounted) {
      await repo.call('stopShare', {'sessionId': result['sessionId']});
      return;
    }
    sessionId = result['sessionId'];
    invitationId = result['invitationId'];
    expires = DateTime.fromMillisecondsSinceEpoch(result['expiresAt']);
    if (mounted) {
      setState(() {
        active = true;
        message =
            'Invitation created. Your friend must accept before seeing location.';
      });
    }
    await location.start();
  });
  Future<void> stop() => action(() async {
    final demo = ref.read(appProvider).demo;
    await location.stop();
    if (!demo) {
      await repo.call('stopAllSharing');
    }
    if (mounted) {
      setState(() {
        active = false;
        sessionId = null;
        invitationId = null;
        expires = null;
        message = 'Sharing stopped. Viewer access revoked.';
      });
    }
  });
  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(appProvider).demo;
    final signed = AppConfig.ready && FirebaseAuth.instance.currentUser != null;
    return PageShell(
      title: 'Together, privately.',
      subtitle: 'Meet up without the “where are you?”',
      nav: 1,
      children: [
        if (demo)
          const StatusPill(
            'SIMULATION • NO REAL LOCATION SHARING',
            warning: true,
          ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: forest,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                active ? Icons.radar : Icons.lock_outline,
                color: lime,
                size: 36,
              ),
              const SizedBox(height: 20),
              Text(
                active
                    ? 'You’re sharing on your terms.'
                    : 'Your location is yours.',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                active
                    ? 'Visible only to an invited, accepted viewer.\n${expires == null ? '' : 'Expires ${expires!.toLocal().toString().substring(11, 16)}'}'
                    : 'Nobody can see your location until you choose to share it.',
                style: const TextStyle(color: Color(0xFFD5E5DA), height: 1.5),
              ),
            ],
          ),
        ),
        if (!demo && !signed) ...[
          const Notice(
            'Sign in with your configured Firebase account to invite friends and share real location.',
          ),
          FilledButton(
            onPressed: () => context.push('/auth'),
            child: const Text('Sign in'),
          ),
        ] else ...[
          if (!active) ...[
            if (demo)
              const ListTile(
                leading: CircleAvatar(backgroundColor: lime, child: Text('A')),
                title: Text('Ananya'),
                subtitle: Text('Demo friend • invitation required'),
              )
            else
              TextField(
                controller: recipient,
                decoration: const InputDecoration(
                  labelText: 'Friend’s approved user ID',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'How long would you like to share?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [15, 30, 60, 0]
                  .map(
                    (m) => ChoiceChip(
                      label: Text(
                        m == 0
                            ? 'Until stopped*'
                            : m == 60
                            ? '1 hour'
                            : '$m minutes',
                      ),
                      selected: m == minutes,
                      onSelected: (_) => setState(() => minutes = m),
                    ),
                  )
                  .toList(),
            ),
            if (minutes == 0)
              const Notice(
                'Safety cap: this session expires after 24 hours. Start a new session to continue.',
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: busy ? null : start,
              icon: const Icon(Icons.share_location),
              label: const Text('Invite & start sharing'),
            ),
          ] else ...[
            if (demo)
              SizedBox(
                height: 230,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const CampusCanvas(friend: true),
                ),
              ),
            if (invitationId != null)
              SelectableText('Invitation ID: $invitationId'),
            if (expires != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: Color(0xFF15803D),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live sharing active • Expires in ${expires!.difference(DateTime.now()).inMinutes}m ${(expires!.difference(DateTime.now()).inSeconds % 60).toString().padLeft(2, '0')}s',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!demo)
              const Notice(
                'Tracking runs only while this sharing screen is active and the app is foregrounded. Returning here requires starting a new session to resume publishing. Existing sessions can be stopped below.',
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFAD3B39),
              ),
              onPressed: busy ? null : stop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop Sharing'),
            ),
          ],
          if (message != null) Notice(message!),
          if (!demo) ...[
            const SizedBox(height: 24),
            const Text(
              'Accept an invitation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: invite,
              decoration: const InputDecoration(labelText: 'Invitation ID'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => action(() async {
                      await repo.call('acceptShare', {
                        'invitationId': invite.text.trim(),
                      });
                      if (mounted) {
                        setState(
                          () => message =
                              'Invitation accepted. The session appears below.',
                        );
                      }
                    }),
              child: const Text('Accept location invitation'),
            ),
            const SizedBox(height: 20),
            LiveSessions(
              uid: FirebaseAuth.instance.currentUser!.uid,
              onAction: (name, data) => action(() async {
                await repo.call(name, data);
              }),
            ),
            TextButton(
              onPressed: busy ? null : stop,
              child: const Text('Stop all my sessions & cancel invitations'),
            ),
          ],
        ],
        const Notice(
          'Friendship never grants location access. You choose the viewer and duration. Stopping sharing removes the live location and revokes access.',
          icon: Icons.verified_user_outlined,
        ),
      ],
    );
  }
}

class LiveSessions extends StatelessWidget {
  final String uid;
  final void Function(String, Map<String, dynamic>) onAction;
  const LiveSessions({super.key, required this.uid, required this.onAction});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Your sharing sessions',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('locationShareSessions')
            .where('ownerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Notice(
              'Sessions unavailable. Reconnect to manage access.',
            );
          }
          return Column(
            children: (snap.data?.docs ?? []).map((d) {
              final m = d.data();
              return ListTile(
                title: Text(m['status'] ?? 'Unknown'),
                subtitle: Text(
                  'Viewers: ${(m['viewerIds'] as List? ?? []).join(', ')}',
                ),
                trailing: IconButton(
                  tooltip: 'Revoke session',
                  icon: const Icon(Icons.cancel_outlined),
                  onPressed: () => onAction('stopShare', {'sessionId': d.id}),
                ),
              );
            }).toList(),
          );
        },
      ),
      const SizedBox(height: 12),
      const Text(
        'Shared with you',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('receivedShares')
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Notice('Shared sessions unavailable.');
          }
          return Column(
            children: (snap.data?.docs ?? [])
                .map((d) => SharedLocationCard(sessionId: d.id))
                .toList(),
          );
        },
      ),
    ],
  );
}

class SharedLocationCard extends StatelessWidget {
  final String sessionId;
  const SharedLocationCard({super.key, required this.sessionId});
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .collection('locationUpdates')
        .doc(sessionId)
        .snapshots(),
    builder: (context, snap) {
      if (snap.hasError) {
        return const ListTile(
          leading: Icon(Icons.lock),
          title: Text('Sharing ended, expired or revoked'),
        );
      }
      final m = snap.data?.data();
      if (m == null) {
        return const ListTile(title: Text('Waiting for a shared location'));
      }
      if (m['expiresAt'] is! Timestamp ||
          !(m['expiresAt'] as Timestamp).toDate().isAfter(DateTime.now())) {
        return const ListTile(
          leading: Icon(Icons.lock),
          title: Text('Sharing expired'),
        );
      }
      final timestamp = (m['recordedAt'] as Timestamp).toDate();
      final stale = DateTime.now().difference(timestamp).inSeconds > 30;
      final point = LatLng(
        (m['latitude'] as num).toDouble(),
        (m['longitude'] as num).toDouble(),
      );
      return Card(
        child: Column(
          children: [
            ListTile(
              leading: Icon(stale ? Icons.history : Icons.person_pin_circle),
              title: Text(
                stale ? 'Stale shared location' : 'Friend’s latest location',
              ),
              subtitle: Text(
                '${formatCoordinatesDD(point.latitude, point.longitude)}\n${formatAccuracy((m['accuracyMeters'] as num).toDouble())}\nUpdated ${timestamp.toLocal()}',
              ),
            ),
            if (AppConfig.mapsEnabled && !kIsWeb)
              SizedBox(
                height: 220,
                child: GoogleMap(
                  key: ValueKey(
                    '$sessionId-${point.latitude}-${point.longitude}',
                  ),
                  initialCameraPosition: CameraPosition(
                    target: point,
                    zoom: 17,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId(sessionId),
                      position: point,
                      infoWindow: InfoWindow(
                        title: stale
                            ? 'Stale friend position'
                            : 'Shared friend position',
                      ),
                    ),
                  },
                  circles: {
                    Circle(
                      circleId: CircleId(sessionId),
                      center: point,
                      radius: (m['accuracyMeters'] as num).toDouble(),
                      fillColor: Colors.blue.withValues(alpha: .12),
                      strokeWidth: 1,
                    ),
                  },
                  myLocationButtonEnabled: false,
                ),
              ),
          ],
        ),
      );
    },
  );
}

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});
  @override
  ConsumerState<FriendsScreen> createState() => _FriendsState();
}

class _FriendsState extends ConsumerState<FriendsScreen> {
  final identifier = TextEditingController();
  String? message;
  @override
  void dispose() {
    identifier.dispose();
    super.dispose();
  }

  Future<void> act(String function, Map<String, dynamic> data) async {
    try {
      await CampusRepository().call(function, data);
      if (mounted) {
        setState(() => message = 'Updated successfully.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Could not update. Check the user ID, permissions and connection.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(appProvider).demo;
    final uid = AppConfig.ready ? FirebaseAuth.instance.currentUser?.uid : null;
    return PageShell(
      title: 'Your campus circle.',
      subtitle: 'Good company. Clear boundaries.',
      nav: 2,
      children: [
        if (demo) const StatusPill('SIMULATION', warning: true),
        const Notice(
          'Add people using their approved account ID. Accepting a friend request does not share your location.',
        ),
        if (!demo && uid == null)
          FilledButton(
            onPressed: () => context.push('/auth'),
            child: const Text('Sign in to manage friends'),
          )
        else ...[
          if (uid != null && !demo) SelectableText('Your user ID: $uid'),
          const SizedBox(height: 16),
          TextField(
            controller: identifier,
            decoration: InputDecoration(
              labelText: demo ? 'Demo name' : 'Approved user ID',
              prefixIcon: const Icon(Icons.person_add_alt),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              if (demo) {
                final value = identifier.text.trim();
                if (value.isNotEmpty) {
                  setState(() {
                    demoFriends.add(value);
                    message = 'Demo request accepted locally.';
                  });
                }
              } else {
                act('friendAction', {
                  'action': 'request',
                  'targetId': identifier.text.trim(),
                });
              }
            },
            child: const Text('Send friend request'),
          ),
          if (message != null) Notice(message!),
          if (demo) ...[
            for (final name in demoFriends.toList())
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: lime,
                  child: Text(name.substring(0, 1).toUpperCase()),
                ),
                title: Text(name),
                subtitle: const Text('Demo friend • location private'),
                trailing: IconButton(
                  tooltip: 'Remove friend',
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: () => setState(() => demoFriends.remove(name)),
                ),
              ),
          ] else ...[
            const SizedBox(height: 24),
            const Text(
              'Incoming requests',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('friendRequests')
                  .where('to', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Notice('Could not load requests.');
                }
                return Column(
                  children: (snap.data?.docs ?? [])
                      .where((d) => d.data()['status'] == 'pending')
                      .map(
                        (d) => ListTile(
                          title: Text(d.data()['from']),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Accept',
                                icon: const Icon(Icons.check),
                                onPressed: () => act('friendAction', {
                                  'action': 'accept',
                                  'requestId': d.id,
                                }),
                              ),
                              IconButton(
                                tooltip: 'Reject',
                                icon: const Icon(Icons.close),
                                onPressed: () => act('friendAction', {
                                  'action': 'reject',
                                  'requestId': d.id,
                                }),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Friends',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('friendships')
                  .where('members', arrayContains: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Notice('Could not load friends.');
                }
                return Column(
                  children: (snap.data?.docs ?? []).map((d) {
                    final other = ((d.data()['members'] as List?) ?? const [])
                        .map((v) => '$v')
                        .firstWhere(
                          (v) => v != uid,
                          orElse: () => 'Unknown member',
                        );
                    return ListTile(
                      title: Text(other),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) => act('friendAction', {
                          'action': v,
                          'targetId': other,
                        }),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove friend'),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Text('Block and revoke sharing'),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ],
    );
  }
}
