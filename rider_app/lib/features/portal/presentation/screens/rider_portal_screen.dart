import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/date_time_format.dart';
import '../../../../theme/pink_fleets_theme.dart';

class RiderPortalScreen extends ConsumerStatefulWidget {
  const RiderPortalScreen({super.key});

  @override
  ConsumerState<RiderPortalScreen> createState() => _RiderPortalScreenState();
}

class _RiderPortalScreenState extends ConsumerState<RiderPortalScreen> with TickerProviderStateMixin {
  late final TabController _tabs;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  static const List<String> _activeStatuses = [
    'pending',
    'dispatching',
    'offered',
    'accepted',
    'en_route',
    'en route',
    'arrived',
    'in_progress',
    'in progress',
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer Portal')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please log in to access your customer portal.'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Log in / Sign up'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final db = FirebaseFirestore.instance;
    final riderRef = db.collection('riders').doc(uid);
    final bookingsQ = db.collection('bookings').where('riderUid', isEqualTo: uid);

    return Scaffold(
      backgroundColor: PFColors.page,
      body: SafeArea(
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: _PortalHeader(
                user: user,
                onBack: () {
                  if (_tabs.index > 0) {
                    _tabs.animateTo(_tabs.index - 1);
                    return;
                  }
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                    return;
                  }
                  context.go('/booking');
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),
            SliverToBoxAdapter(
              child: PFPortalTabsGrid(controller: _tabs),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
          ],
          body: TabBarView(
            controller: _tabs,
            children: [
              _OverviewTab(bookingsQ: bookingsQ, activeStatuses: _activeStatuses),
              _TripsTab(bookingsQ: bookingsQ),
              _LiveTab(bookingsQ: bookingsQ, activeStatuses: _activeStatuses),
              _InvoicesTab(bookingsQ: bookingsQ),
              _PaymentsTab(),
              _ProfileTab(
                riderRef: riderRef,
                uid: uid,
                nameCtrl: _nameCtrl,
                phoneCtrl: _phoneCtrl,
                emailCtrl: _emailCtrl,
                dobCtrl: _dobCtrl,
                addressCtrl: _addressCtrl,
                firstNameCtrl: _firstNameCtrl,
                lastNameCtrl: _lastNameCtrl,
              ),
              const _SettingsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalHeader extends StatelessWidget {
  final User? user;
  final VoidCallback onBack;
  const _PortalHeader({required this.user, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final name = (user?.displayName ?? 'Pink Fleets Client').toString();
    final email = (user?.email ?? '').toString();
    final initials = name.trim().isEmpty ? 'PF' : name.trim().substring(0, 1).toUpperCase();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PFColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PFColors.border),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 720;
          final logo = SizedBox(
            height: 86,
            width: 270,
            child: Image.asset(
              'assets/logo/pink_fleets_logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PINK FLEETS',
                  style: TextStyle(
                    color: PFColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          );

          final greeting = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Portal',
                style: TextStyle(
                  color: PFColors.ink.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Welcome back, $name',
                style: const TextStyle(
                  color: PFColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              if (email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    email,
                    style: TextStyle(
                      color: PFColors.ink.withValues(alpha: 0.65),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Manage bookings, track live trips, and update your preferences in one place.',
                style: TextStyle(
                  color: PFColors.ink.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/booking'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PFColors.pink1,
                      foregroundColor: PFColors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Book a Ride'),
                  ),
                  TextButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    style: TextButton.styleFrom(foregroundColor: PFColors.ink),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ],
          );

          final accountCard = Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [PFColors.page, PFColors.pink2.withValues(alpha: 0.12)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: PFColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: PFColors.ink,
                      child: Text(
                        initials,
                        style: const TextStyle(color: PFColors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'Signed in',
                            style: TextStyle(color: PFColors.ink.withValues(alpha: 0.6), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.shield_rounded, color: PFColors.ink.withValues(alpha: 0.6), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Secure customer access',
                        style: TextStyle(color: PFColors.ink.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                logo,
                const SizedBox(height: 12),
                greeting,
                const SizedBox(height: 14),
                accountCard,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    logo,
                    const SizedBox(height: 12),
                    greeting,
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(width: 240, child: accountCard),
            ],
          );
        },
      ),
    );
  }
}

// ── Responsive tab grid: 2 cols <600px, 3 cols 600-1024, 4 cols >1024 ──────
class PFPortalTabsGrid extends StatelessWidget {
  final TabController controller;
  const PFPortalTabsGrid({super.key, required this.controller});

  static const _items = [
    (Icons.dashboard_rounded, 'Overview'),
    (Icons.history_rounded, 'Trips'),
    (Icons.location_on_rounded, 'Live'),
    (Icons.receipt_long_rounded, 'Invoices'),
    (Icons.credit_card_rounded, 'Payments'),
    (Icons.person_rounded, 'Profile'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PFColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PFColors.border),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 7),
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, bc) {
          final cols = bc.maxWidth < 600
              ? 2
              : bc.maxWidth < 1024
                  ? 3
                  : 4;
          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  mainAxisExtent: 44,
                ),
                itemCount: _items.length,
                itemBuilder: (context, i) {
                  final selected = controller.index == i;
                  return GestureDetector(
                    onTap: () => controller.animateTo(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: selected ? PFColors.pink1 : PFColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? PFColors.pink1 : PFColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _items[i].$1,
                            size: 16,
                            color: selected ? Colors.white : PFColors.muted,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              _items[i].$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected ? Colors.white : PFColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Query<Map<String, dynamic>> bookingsQ;
  final List<String> activeStatuses;
  const _OverviewTab({required this.bookingsQ, required this.activeStatuses});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        _card(
          title: 'Welcome',
          subtitle: 'Your Pink Fleets client dashboard',
          child: const Text(
            'Track current trips, review past bookings, and manage your profile from one place.',
          ),
        ),
        const SizedBox(height: 12),
        _card(
          title: 'Active Trips',
          subtitle: 'Live tracking and real-time updates',
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: bookingsQ.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Error: ${snap.error}');
              }
              if (!snap.hasData) return const LinearProgressIndicator();
              final docs = snap.data!.docs.toList();
              docs.sort((a, b) {
                final at = _asDateTime(a.data()['updatedAt']);
                final bt = _asDateTime(b.data()['updatedAt']);
                return (bt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(at ?? DateTime.fromMillisecondsSinceEpoch(0));
              });

              final activeDocs = docs.where((doc) {
                final status = (doc.data()['status'] ?? 'unknown').toString();
                return activeStatuses.contains(status);
              }).toList();

              if (activeDocs.isEmpty) return const Text('No active trips.');
              return Column(
                children: activeDocs.map((doc) {
                  final d = doc.data();
                  final status = (d['status'] ?? 'unknown').toString();
                  final start = _asDateTime(d['scheduledStartAt']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PFColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: PFColors.pink1.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: PFColors.goldBase, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trip ${doc.id.substring(0, 8)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text('Status: $status${start == null ? '' : ' • ${formatDateTime(start)}'}'),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/booking/live/${doc.id}'),
                          child: const Text('Open Live'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TripsTab extends StatelessWidget {
  final Query<Map<String, dynamic>> bookingsQ;
  const _TripsTab({required this.bookingsQ});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: bookingsQ.limit(100).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs.toList();
        docs.sort((a, b) {
          final at = _asDateTime(a.data()['updatedAt']);
          final bt = _asDateTime(b.data()['updatedAt']);
          return (bt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(at ?? DateTime.fromMillisecondsSinceEpoch(0));
        });
        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              _card(
                title: 'Trips',
                subtitle: 'Your full trip history',
                child: const Text('No trips yet. Book your first ride to get started.'),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          itemCount: docs.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Column(
                children: [
                  _card(
                    title: 'Trips',
                    subtitle: 'Your full trip history',
                    child: const Text('Review past bookings, receipts, and trip details.'),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }

            final d = docs[i - 1].data();
            final status = (d['status'] ?? 'unknown').toString();
            final start = _asDateTime(d['scheduledStartAt']);
            final pickup = (d['pickup'] ?? '--').toString();
            final dropoff = (d['dropoff'] ?? '--').toString();
            return _card(
              title: 'Trip ${docs[i - 1].id.substring(0, 8)}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: $status', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (start != null) Text('Start: ${formatDateTime(start)}'),
                  Text('Pickup: $pickup'),
                  Text('Dropoff: $dropoff'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => context.go('/booking/live/${docs[i - 1].id}'),
                        child: const Text('View Live'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => context.go('/booking'),
                        child: const Text('Book Again'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LiveTab extends StatelessWidget {
  final Query<Map<String, dynamic>> bookingsQ;
  final List<String> activeStatuses;
  const _LiveTab({required this.bookingsQ, required this.activeStatuses});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: bookingsQ.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs.toList();
        docs.sort((a, b) {
          final at = _asDateTime(a.data()['updatedAt']);
          final bt = _asDateTime(b.data()['updatedAt']);
          return (bt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(at ?? DateTime.fromMillisecondsSinceEpoch(0));
        });

        final activeDocs = docs.where((doc) {
          final status = (doc.data()['status'] ?? 'unknown').toString();
          return activeStatuses.contains(status);
        }).toList();

        if (activeDocs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              _card(
                title: 'Live Tracking',
                subtitle: 'Real-time location and status',
                child: const Text('No active trips to track right now.'),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          children: [
            _card(
              title: 'Live Tracking',
              subtitle: 'Real-time location and status',
              child: const Text('Open a live trip to view your driver and updates.'),
            ),
            const SizedBox(height: 12),
            ...activeDocs.map((doc) {
              final d = doc.data();
              final status = (d['status'] ?? 'unknown').toString();
              final pickup = (d['pickup'] ?? '--').toString();
              final dropoff = (d['dropoff'] ?? '--').toString();
              return _card(
                title: 'Live Trip ${doc.id.substring(0, 8)}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $status', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('Pickup: $pickup'),
                    Text('Dropoff: $dropoff'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => context.go('/booking/live/${doc.id}'),
                      child: const Text('Open Live Tracking'),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _InvoicesTab extends StatelessWidget {
  final Query<Map<String, dynamic>> bookingsQ;
  const _InvoicesTab({required this.bookingsQ});

  String _money(num? v) {
    if (v == null) return '--';
    return '\$${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: bookingsQ.limit(100).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs.toList();
        docs.sort((a, b) {
          final at = _asDateTime(a.data()['updatedAt']);
          final bt = _asDateTime(b.data()['updatedAt']);
          return (bt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(at ?? DateTime.fromMillisecondsSinceEpoch(0));
        });
        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            children: [
              _card(
                title: 'Invoices',
                subtitle: 'Receipts and payment history',
                child: const Text('No invoices yet.'),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          itemCount: docs.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Column(
                children: [
                  _card(
                    title: 'Invoices',
                    subtitle: 'Receipts and payment history',
                    child: const Text('Download receipts for completed trips.'),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }

            final bookingId = docs[i - 1].id;
            final d = docs[i - 1].data();
            final status = (d['status'] ?? 'unknown').toString();
            final start = _asDateTime(d['scheduledStartAt']);

            return _card(
              title: 'Invoice ${bookingId.substring(0, 8)}',
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: db.collection('bookings_private').doc(bookingId).get(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Text('Error: ${snap.error}');
                  }
                  if (!snap.hasData) return const LinearProgressIndicator();
                  if (!snap.data!.exists) {
                    return Text('Status: $status${start == null ? '' : ' • ${formatDateTime(start)}'}');
                  }
                  final p = snap.data!.data() ?? {};
                  final paymentStatus = (p['paymentStatus'] ?? '--').toString();
                  final pricingSnapshot = _asStringDynamicMap(p['pricingSnapshot']);
                  final total = pricingSnapshot?['total'] as num?;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: $status${start == null ? '' : ' • ${formatDateTime(start)}'}'),
                      Text('Payment: $paymentStatus'),
                      Text('Total: ${_money(total)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invoice download will be available soon.')),
                          );
                        },
                        child: const Text('Download Invoice'),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        _card(
          title: 'Payments',
          subtitle: 'Cards and billing preferences',
          child: const Text('Manage payment methods and billing preferences.'),
        ),
        const SizedBox(height: 12),
        _card(
          title: 'Payment Methods',
          subtitle: 'Secure checkout will return soon',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Secure payments are coming soon.'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Stripe integration is paused for now.')),
                  );
                },
                child: const Text('Add Payment Method'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          title: 'Saved Riders',
          subtitle: 'Manage saved riders from Profile',
          child: const Text('Manage saved riders from Profile.'),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> riderRef;
  final String uid;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController dobCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;

  const _ProfileTab({
    required this.riderRef,
    required this.uid,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.dobCtrl,
    required this.addressCtrl,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _initialized = false;
  bool _uploading = false;
  String? _photoUrl;

  void _seed(Map<String, dynamic> d) {
    if (_initialized) return;
    widget.firstNameCtrl.text = (d['firstName'] ?? '').toString();
    widget.lastNameCtrl.text = (d['lastName'] ?? '').toString();
    widget.nameCtrl.text = (d['name'] ?? '').toString();
    widget.emailCtrl.text = (d['email'] ?? '').toString();
    widget.phoneCtrl.text = (d['phone'] ?? '').toString();
    widget.dobCtrl.text = (d['dob'] ?? '').toString();
    widget.addressCtrl.text = (d['address'] ?? '').toString();
    _photoUrl = (d['photoUrl'] ?? '').toString().isEmpty ? null : (d['photoUrl'] ?? '').toString();
    _initialized = true;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 25, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 100, 1, 1),
      lastDate: DateTime(now.year - 16, now.month, now.day),
      initialDate: initial,
    );
    if (date == null) return;
    widget.dobCtrl.text = '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _uploadPhoto() async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
        // Do NOT request readStream — accessing it as a late field crashes on iOS Safari.
      );
      if (picked == null || picked.files.isEmpty) return;

      final file = picked.files.single;

      // Guard file.bytes — it can be a late field on some platforms.
      Uint8List? bytes;
      try {
        bytes = file.bytes;
      } catch (_) {
        bytes = null;
      }

      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No image data. Please select a different file.')),
          );
        }
        return;
      }

      // Guard file.extension — also potentially a late field.
      String? ext;
      try {
        ext = file.extension;
      } catch (_) {
        ext = null;
      }

      final contentType = _guessContentType(ext);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.${ext ?? 'jpg'}';

      // Use Firebase Storage REST API directly — Firebase Storage SDK has a
      // LateInitializationError on Safari/iOS web. REST API is reliable.
      final storagePath = 'riders/${widget.uid}/profile/$fileName';
      final encodedPath = Uri.encodeComponent(storagePath);
      const bucket = 'pink-fleets.firebasestorage.app';

      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) throw Exception('Not authenticated');

      final uploadUri = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
        '?uploadType=media&name=$encodedPath',
      );
      final uploadResp = await http.post(
        uploadUri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': contentType,
        },
        body: bytes,
      );
      if (uploadResp.statusCode != 200) {
        throw Exception(
            'Storage upload failed (${uploadResp.statusCode}): ${uploadResp.body}');
      }
      final uploadJson =
          jsonDecode(uploadResp.body) as Map<String, dynamic>;
      final token = (uploadJson['downloadTokens'] as String?) ?? '';
      final url =
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o'
          '/$encodedPath?alt=media&token=$token';

      await widget.riderRef.set({
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _photoUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _guessContentType(String? ext) {
    final e = (ext ?? '').toLowerCase();
    switch (e) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedRidersRef = widget.riderRef.collection('saved_riders');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        _card(
          title: 'Profile',
          subtitle: 'Personal details and saved riders',
          child: const Text('Update your contact information and manage saved riders.'),
        ),
        const SizedBox(height: 12),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: widget.riderRef.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _card(
                title: 'Profile',
                subtitle: 'Keep your contact info updated',
                child: Text('Error: ${snap.error}'),
              );
            }
            if (!snap.hasData) return const LinearProgressIndicator();
            final d = snap.data?.data() ?? {};
            _seed(d);

            final initials = (widget.nameCtrl.text.trim().isNotEmpty
                    ? widget.nameCtrl.text.trim()
                    : '${widget.firstNameCtrl.text} ${widget.lastNameCtrl.text}'.trim())
                .split(' ')
                .where((s) => s.isNotEmpty)
                .take(2)
                .map((s) => s[0].toUpperCase())
                .join();

            return _card(
              title: 'Profile',
              subtitle: 'Keep your contact info updated',
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: PFColors.pink1.withValues(alpha: 0.15),
                        backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                        child: _photoUrl == null
                            ? Text(
                                initials.isEmpty ? 'R' : initials,
                                style: const TextStyle(fontWeight: FontWeight.w900, color: PFColors.ink),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _uploading ? null : _uploadPhoto,
                            icon: const Icon(Icons.upload),
                            label: Text(_uploading ? 'Uploading…' : 'Upload Profile Photo'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: widget.firstNameCtrl,
                    decoration: const InputDecoration(labelText: 'First name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.lastNameCtrl,
                    decoration: const InputDecoration(labelText: 'Last name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.dobCtrl,
                    readOnly: true,
                    onTap: _pickDob,
                    decoration: const InputDecoration(labelText: 'Date of birth'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.addressCtrl,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final first = widget.firstNameCtrl.text.trim();
                        final last = widget.lastNameCtrl.text.trim();
                        final full = widget.nameCtrl.text.trim().isNotEmpty
                            ? widget.nameCtrl.text.trim()
                            : '${first.isEmpty ? '' : first}${last.isEmpty ? '' : ' $last'}'.trim();
                        await widget.riderRef.set({
                          'firstName': first,
                          'lastName': last,
                          'name': full,
                          'email': widget.emailCtrl.text.trim().toLowerCase(),
                          'phone': widget.phoneCtrl.text.trim(),
                          'dob': widget.dobCtrl.text.trim(),
                          'address': widget.addressCtrl.text.trim(),
                          'photoUrl': _photoUrl,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated')),
                          );
                        }
                      },
                      child: const Text('Save Profile'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _card(
          title: 'Saved Riders',
          subtitle: 'Frequent riders for quick booking',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Save frequent riders for quick booking.'),
              const SizedBox(height: 8),
              _SavedRiderForm(savedRidersRef: savedRidersRef),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: savedRidersRef.orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const LinearProgressIndicator();
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) return const Text('No saved riders yet.');

                  return Column(
                    children: docs.map((doc) {
                      final d = doc.data();
                      final name = (d['name'] ?? '--').toString();
                      final phone = (d['phone'] ?? '--').toString();
                      final email = (d['email'] ?? '--').toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(name),
                        subtitle: Text('$phone • $email'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => doc.reference.delete(),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SavedRiderForm extends StatefulWidget {
  final CollectionReference<Map<String, dynamic>> savedRidersRef;
  const _SavedRiderForm({required this.savedRidersRef});

  @override
  State<_SavedRiderForm> createState() => _SavedRiderFormState();
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        children: [
          _card(
            title: 'Settings',
            subtitle: 'Notifications and preferences',
            child: const Text('Please log in to edit settings.'),
          ),
        ],
      );
    }

    final riderRef = FirebaseFirestore.instance.collection('riders').doc(uid);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        _card(
          title: 'Settings',
          subtitle: 'Notifications and preferences',
          child: const Text('Adjust alerts, communications, and app preferences.'),
        ),
        const SizedBox(height: 12),
        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: riderRef.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Error: ${snap.error}');
            }
            if (!snap.hasData) return const LinearProgressIndicator();
            final data = snap.data?.data() ?? {};
            final prefs = (data['preferences'] as Map<String, dynamic>?) ?? {};

            bool b(String key, {bool fallback = true}) => (prefs[key] as bool?) ?? fallback;

            return Column(
              children: [
                _card(
                  title: 'Notifications',
                  subtitle: 'Trip updates and promotions',
                  child: Column(
                    children: [
                      _switchRow(
                        label: 'Trip status alerts',
                        value: b('tripStatusAlerts', fallback: true),
                        onChanged: (v) => riderRef.set({
                          'preferences': {'tripStatusAlerts': v},
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true)),
                      ),
                      _switchRow(
                        label: 'Driver arrival notifications',
                        value: b('driverArrivalAlerts', fallback: true),
                        onChanged: (v) => riderRef.set({
                          'preferences': {'driverArrivalAlerts': v},
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true)),
                      ),
                      _switchRow(
                        label: 'Promotions and offers',
                        value: b('promotions', fallback: false),
                        onChanged: (v) => riderRef.set({
                          'preferences': {'promotions': v},
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Communication',
                  subtitle: 'Email and SMS preferences',
                  child: Column(
                    children: [
                      _switchRow(
                        label: 'Email receipts',
                        value: b('emailReceipts', fallback: true),
                        onChanged: (v) => riderRef.set({
                          'preferences': {'emailReceipts': v},
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true)),
                      ),
                      _switchRow(
                        label: 'SMS trip updates',
                        value: b('smsTripUpdates', fallback: true),
                        onChanged: (v) => riderRef.set({
                          'preferences': {'smsTripUpdates': v},
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true)),
                      ),
                      _switchRow(
                        label: 'Account announcements',
                        value: b('accountAnnouncements', fallback: true),
                        onChanged: (v) => riderRef.set({
                          'preferences': {'accountAnnouncements': v},
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

Widget _switchRow({
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _SavedRiderFormState extends State<_SavedRiderForm> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Rider name'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              if (name.isEmpty) return;

              await widget.savedRidersRef.add({
                'name': name,
                'phone': _phoneCtrl.text.trim(),
                'email': _emailCtrl.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });

              _nameCtrl.clear();
              _phoneCtrl.clear();
              _emailCtrl.clear();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved rider added')),
                );
              }
            },
            child: const Text('Add Saved Rider'),
          ),
        ),
      ],
    );
  }
}

Widget _card({required String title, String? subtitle, required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: PFColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: PFColors.border),
      boxShadow: [
        BoxShadow(
          blurRadius: 14,
          offset: const Offset(0, 6),
          color: Colors.black.withValues(alpha: 0.05),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: PFColors.pink1, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: PFColors.muted, fontSize: 12)),
        ],
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

DateTime? _asDateTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is int) {
    final ms = raw > 1000000000000 ? raw : raw * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  if (raw is String) {
    return DateTime.tryParse(raw);
  }
  return null;
}

Map<String, dynamic>? _asStringDynamicMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}
