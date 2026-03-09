import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/firebase_providers.dart';
import '../shared/fcm_token_service.dart';
import '../features/offers/incoming_offer_screen.dart';
import '../shared/date_time_format.dart';
import '../theme/driver_theme.dart';

class DriverHome extends ConsumerStatefulWidget {
  const DriverHome({super.key});

  @override
  ConsumerState<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends ConsumerState<DriverHome>
    with TickerProviderStateMixin {
  static const String _buildStamp = String.fromEnvironment(
    'APP_BUILD',
    defaultValue: '2026-03-03.3',
  );

  Timer? _heartbeat;
  bool _sending = false;
  bool _suppressedLocationErrorShown = false;
  late AnimationController _heroCtrl;
  late Animation<double> _heroFade;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: PFAnimations.verySlow,
    );
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: PFAnimations.curve);
    _heroCtrl.forward();

    FcmTokenService.registerDriverToken();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmTokenService.initializeFCMListeners(
        context,
        onOfferReceived: (bookingId, offerId) {
          Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => IncomingOfferScreen(
                bookingId: bookingId,
                offerId: offerId,
              ),
            ),
          );
        },
      );
    });
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _heroCtrl.dispose();
    super.dispose();
  }

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _ensurePermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
      throw Exception('Location permission not granted');
    }
  }

  Future<void> _sendLocation(BuildContext context, FirebaseFirestore db) async {
    if (_sending) return;
    _sending = true;

    try {
      await _ensurePermission();

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      await db.collection('drivers').doc(uid).set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'lastLocation': {
          'lat': pos.latitude,
          'lng': pos.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location sent')));
      }
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString();
        final isFirestoreInternal = msg.contains('FIRESTORE') && msg.contains('INTERNAL ASSERTION FAILED');

        if (isFirestoreInternal) {
          if (!_suppressedLocationErrorShown) {
            _suppressedLocationErrorShown = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location temporarily unavailable on mobile web. Please retry.')),
            );
          }
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    } finally {
      _sending = false;
    }
  }

  void _startHeartbeat(FirebaseFirestore db) {
    if (kIsWeb) return;
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _sendLocation(context, db);
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(firestoreProvider);
    final auth = ref.watch(firebaseAuthProvider);

    final driverDoc = db.collection('drivers').doc(uid);
    final bookingsQ = db
        .collection('bookings')
        .where('assigned.driverId', isEqualTo: uid);

    return Scaffold(
      backgroundColor: PFColors.canvas,
      body: FadeTransition(
        opacity: _heroFade,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: PFColors.canvas,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              expandedHeight: 0,
              titleSpacing: PFSpacing.base,
              title: Row(
                children: [
                  SizedBox(
                    height: 34,
                    width: 140,
                    child: Image.asset(
                      'assets/logo/pink_fleets_logo.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const Spacer(),
                  _SignOutButton(auth: auth),
                  const SizedBox(width: PFSpacing.sm),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    PFSpacing.base, PFSpacing.sm, PFSpacing.base, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroBanner(),
                    const SizedBox(height: PFSpacing.base),

                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: driverDoc.snapshots(),
                      builder: (context, snap) {
                        final data = snap.data?.data() ?? {};
                        final name = (data['name'] ?? 'Driver').toString();
                        final status =
                            (data['status'] ?? 'offline').toString();
                        final online = status == 'online';

                        if (online && _heartbeat == null) _startHeartbeat(db);
                        if (!online && _heartbeat != null) _stopHeartbeat();

                        final loc =
                            data['lastLocation'] as Map<String, dynamic>?;
                        final lastUpdate = loc?['updatedAt'];

                        return _DriverStatusCard(
                          name: name,
                          online: online,
                          lastUpdate: lastUpdate,
                          driverDoc: driverDoc,
                          onSendLocation: () => _sendLocation(context, db),
                          onToggle: (v) async {
                            await driverDoc.set({
                              'status': v ? 'online' : 'offline',
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                            if (v) _sendLocation(context, db);
                          },
                        );
                      },
                    ),

                    const SizedBox(height: PFSpacing.xl),
                    const PFSectionHeader(title: 'Assigned Trips'),
                    const SizedBox(height: PFSpacing.md),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: bookingsQ.snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return PFCard(
                            child: Text(
                              'Error: ${snap.error}',
                              style: const TextStyle(color: PFColors.danger),
                            ),
                          );
                        }
                        if (!snap.hasData) {
                          return Column(
                            children: List.generate(
                              3,
                              (_) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: PFSpacing.sm),
                                child: PFSkeleton.card(height: 80),
                              ),
                            ),
                          );
                        }

                        final docs = snap.data!.docs;
                        if (docs.isEmpty) {
                          return const PFEmptyState(
                            icon: Icons.directions_car_outlined,
                            title: 'No trips assigned yet',
                            body:
                                'Go online to start receiving ride requests.',
                          );
                        }

                        docs.sort((a, b) {
                          final at =
                              (a.data()['createdAt'] as Timestamp?)
                                  ?.millisecondsSinceEpoch ??
                              0;
                          final bt =
                              (b.data()['createdAt'] as Timestamp?)
                                  ?.millisecondsSinceEpoch ??
                              0;
                          return bt.compareTo(at);
                        });

                        return Column(
                          children: docs.asMap().entries.map((e) {
                            return _TripCard(
                              doc: e.value,
                              index: e.key,
                              onTap: () =>
                                  context.push('/driver/trip/${e.value.id}'),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: PFSpacing.xl),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Opacity(
                        opacity: 0.3,
                        child: Text(
                          'Build $_buildStamp',
                          style: PFTypography.labelSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: PFSpacing.xxxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero banner ─────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: PFColors.surface,
        borderRadius: BorderRadius.circular(PFSpacing.radiusLg),
        border: Border.all(color: PFColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pink → gold → pink top accent stripe
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [PFColors.pink2, PFColors.goldBase, PFColors.pink1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: PFSpacing.base, vertical: PFSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(PFSpacing.sm),
                  decoration: BoxDecoration(
                    color: PFColors.pink1.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(PFSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: PFColors.pink1, size: 20),
                ),
                const SizedBox(width: PFSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium Driver Console',
                        style: PFTypography.titleLarge
                            .copyWith(letterSpacing: -0.3, color: PFColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text('Pink Fleets — Luxury Transport',
                          style: PFTypography.bodySmall
                              .copyWith(color: PFColors.muted)),
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

// ── Driver status card ──────────────────────────────────────────────────────
class _DriverStatusCard extends StatelessWidget {
  final String name;
  final bool online;
  final dynamic lastUpdate;
  final DocumentReference<Map<String, dynamic>> driverDoc;
  final VoidCallback onSendLocation;
  final void Function(bool) onToggle;

  const _DriverStatusCard({
    required this.name,
    required this.online,
    required this.lastUpdate,
    required this.driverDoc,
    required this.onSendLocation,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return PFCard(
      padding: const EdgeInsets.all(PFSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PFAvatar(
                  name: name, radius: 22, online: online, showStatus: true),
              const SizedBox(width: PFSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: PFTypography.titleLarge),
                    Text(
                      online ? 'Available for trips' : 'Currently offline',
                      style: PFTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              PFChipStatus(
                status: online ? 'online' : 'offline',
                label: online ? 'ONLINE' : 'OFFLINE',
              ),
            ],
          ),
          const SizedBox(height: PFSpacing.base),
          const Divider(color: PFColors.border, height: 1),
          const SizedBox(height: PFSpacing.base),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Availability',
                style: PFTypography.titleSmall
                    .copyWith(color: PFColors.ink),
              ),
              subtitle: Text(
                online ? 'Receiving trip requests' : 'Not receiving trips',
                style: PFTypography.bodySmall,
              ),
              value: online,
              onChanged: onToggle,
            ),
          ),
          const SizedBox(height: PFSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSendLocation,
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('Send Location'),
                ),
              ),
              const SizedBox(width: PFSpacing.sm),
              Expanded(child: _LastUpdateBadge(lastUpdate: lastUpdate)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LastUpdateBadge extends StatelessWidget {
  final dynamic lastUpdate;

  const _LastUpdateBadge({required this.lastUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: PFSpacing.sm, vertical: PFSpacing.sm + 2),
      decoration: BoxDecoration(
        color: PFColors.surfaceHigh,
        borderRadius: BorderRadius.circular(PFSpacing.radiusSm),
        border: Border.all(color: PFColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded,
              size: 14, color: PFColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              lastUpdate == null
                  ? 'Not updated yet'
                  : formatTimestamp(lastUpdate),
              style: PFTypography.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stagger-animated trip card ───────────────────────────────────────────────
class _TripCard extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final int index;
  final VoidCallback onTap;

  const _TripCard({
    required this.doc,
    required this.index,
    required this.onTap,
  });

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: PFAnimations.slow);
    _fade = CurvedAnimation(parent: _ctrl, curve: PFAnimations.curve);
    _slide =
        Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: PFAnimations.curve),
    );
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc.data();
    final status = (d['status'] ?? 'unknown').toString();
    final rider = d['riderInfo'] as Map<String, dynamic>?;
    final riderName = (rider?['name'] ?? 'Rider').toString();
    final when = d['scheduledStartAt'] ?? d['createdAt'];
    final whenText = formatTimestamp(when);
    final statusColor = PFColors.statusColor(status);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: PFSpacing.sm),
          child: PFCard(
            onTap: widget.onTap,
            padding: const EdgeInsets.symmetric(
                horizontal: PFSpacing.base, vertical: PFSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(PFSpacing.radiusSm),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.directions_car_rounded,
                      color: statusColor, size: 18),
                ),
                const SizedBox(width: PFSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(riderName, style: PFTypography.titleSmall),
                      const SizedBox(height: 2),
                      Text(whenText, style: PFTypography.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: PFSpacing.sm),
                PFChipStatus(status: status),
                const SizedBox(width: PFSpacing.sm),
                const Icon(Icons.chevron_right_rounded,
                    color: PFColors.muted, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sign-out button ──────────────────────────────────────────────────────────
class _SignOutButton extends StatelessWidget {
  final dynamic auth;

  const _SignOutButton({required this.auth});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        await auth.signOut();
        if (context.mounted) context.go('/login');
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: PFColors.muted,
        side: const BorderSide(color: PFColors.border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PFSpacing.radiusFull)),
        padding: const EdgeInsets.symmetric(
            horizontal: PFSpacing.md, vertical: PFSpacing.xs + 2),
      ),
      icon: const Icon(Icons.account_circle_outlined, size: 16),
      label: const Text(
        'Sign out',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
