import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/firebase_providers.dart';
import '../../shared/date_time_format.dart';
import '../../theme/pink_fleets_theme.dart';
import 'booking_detail_panel.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  String? selectedBookingId;
  String search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => search = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showRiderProfile(
    BuildContext context,
    String? riderUid,
    Map<String, dynamic>? riderInfo,
  ) {
    final db = ref.read(firestoreProvider);
    final resolvedUid = (riderUid ?? '').trim();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PFColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Rider Profile'),
        content: SizedBox(
          width: 360,
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: resolvedUid.isEmpty
                ? null
                : db.collection('riders').doc(resolvedUid).snapshots(),
            builder: (context, snap) {
              final data = snap.data?.data() ?? {};
              final merged = {
                ...?riderInfo,
                ...data,
              };
              final name = (merged['name'] ?? 'Rider').toString();
              final email = (merged['email'] ?? '').toString().trim();
              final phone = (merged['phone'] ?? '').toString().trim();
              final dob = formatTimestamp(merged['dob']);
              final address = (merged['address'] ?? '').toString();
              final photoUrl = (merged['photoUrl'] ?? '').toString();

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: PFColors.gold.withValues(alpha: 0.2),
                        backgroundImage:
                            photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'R',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Name: ${name.isEmpty ? '—' : name}'),
                  Text('Email: ${email.isEmpty ? '—' : email}'),
                  Text('Phone: ${phone.isEmpty ? '—' : phone}'),
                  Text('DOB: ${dob == '—' ? '—' : dob}'),
                  if (address.isNotEmpty) Text('Address: $address'),
                  if (resolvedUid.isNotEmpty) Text('UID: $resolvedUid'),
                  if (resolvedUid.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'No rider UID on this booking. Showing booking snapshot only.',
                        style: TextStyle(color: PFColors.muted, fontSize: 12),
                      ),
                    ),
                  if (snap.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Error: ${snap.error}'),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(firestoreProvider);
    final bookingsQ =
        db.collection('bookings').orderBy('createdAt', descending: true);
    final isNarrow = MediaQuery.of(context).size.width < 1100;

    Widget listPane() {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: bookingsQ.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error:\n${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snap.data!.docs;

          if (search.isNotEmpty) {
            final s = search.toLowerCase();
            docs = docs.where((doc) {
              final rider = doc.data()['riderInfo'] as Map<String, dynamic>?;
              final name = (rider?['name'] ?? '').toString().toLowerCase();
              return name.contains(s);
            }).toList();
          }

          if (docs.isEmpty) {
            return const Center(child: Text('No bookings found.'));
          }

          selectedBookingId ??= docs.first.id;

          return Container(
            decoration: BoxDecoration(
              color: PFColors.white,
              borderRadius: BorderRadius.circular(18),
              border: const Border.fromBorderSide(
                  BorderSide(color: PFColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: PFColors.border),
              itemBuilder: (context, i) {
                final doc = docs[i];
                final data = doc.data();
                final id = doc.id;

                final rider = data['riderInfo'] as Map<String, dynamic>?;
                final riderName = (rider?['name'] ?? 'Unknown').toString();
                final riderUid =
                    (data['riderUid'] ?? rider?['uid'] ?? rider?['id'] ?? '')
                        .toString();
                final canOpenRider =
                    riderUid.trim().isNotEmpty || rider != null;
                final status = (data['status'] ?? 'unknown').toString();

                final isSelected = selectedBookingId == id;

                return InkWell(
                  onTap: () => setState(() => selectedBookingId = id),
                  child: Container(
                    color: isSelected
                        ? PFColors.gold.withValues(alpha: 0.08)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        _StatusDot(status: status),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: canOpenRider
                                ? () =>
                                    _showRiderProfile(context, riderUid, rider)
                                : null,
                            child: Text(
                              riderName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: canOpenRider
                                    ? PFColors.pink1
                                    : PFColors.ink,
                                decoration: canOpenRider
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatusChip(status: status),
                        const SizedBox(width: 12),
                        Text(
                          id.substring(0, 8),
                          style: const TextStyle(
                            fontSize: 12,
                            color: PFColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    }

    Widget detailPane() {
      return selectedBookingId == null
          ? const SizedBox()
          : Container(
              decoration: BoxDecoration(
                color: PFColors.white,
                borderRadius: BorderRadius.circular(18),
                border: const Border.fromBorderSide(
                    BorderSide(color: PFColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: BookingDetailPanel(
                  bookingId: selectedBookingId!, embedded: true),
            );
    }

    if (isNarrow) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderRow(searchCtrl: _searchCtrl),
            const SizedBox(height: 14),
            _KpiRow(db: db, compact: true),
            const SizedBox(height: 14),
            listPane(),
            if (selectedBookingId != null) ...[
              const SizedBox(height: 16),
              detailPane(),
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 16.0;
        final leftWidth = (constraints.maxWidth - gap) * 0.6;
        final rightWidth = (constraints.maxWidth - gap) * 0.4;

        return SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: leftWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderRow(searchCtrl: _searchCtrl),
                    const SizedBox(height: 14),
                    _KpiRow(db: db, compact: false),
                    const SizedBox(height: 14),
                    listPane(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: rightWidth,
                child: detailPane(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final TextEditingController searchCtrl;
  const _HeaderRow({required this.searchCtrl});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 780;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: PFColors.white,
            borderRadius: BorderRadius.circular(18),
            border:
                const Border.fromBorderSide(BorderSide(color: PFColors.border)),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bookings',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Operational Control Center',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: PFColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search rider',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bookings',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 2),
                          Text(
                            'Operational Control Center',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: PFColors.muted),
                          ),
                        ],
                      ),
                    ),
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(minWidth: 220, maxWidth: 320),
                      child: TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search rider',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _KpiRow extends StatelessWidget {
  final FirebaseFirestore db;
  final bool compact;
  const _KpiRow({required this.db, required this.compact});

  Future<num> _sumPrivateTotals(Iterable<String> bookingIds) async {
    num sum = 0;
    for (final id in bookingIds) {
      final doc = await db.collection('bookings_private').doc(id).get();
      if (!doc.exists) continue;
      final data = doc.data();
      final snap = data?['pricingSnapshot'] as Map<String, dynamic>?;
      final total = snap?['total'];
      if (total is num) sum += total / 100.0;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfMonth = DateTime(now.year, now.month, 1);

    final todayStream = db
        .collection('bookings')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots();

    final monthStream = db
        .collection('bookings')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .snapshots();

    final activeStream = db.collection('bookings').where('status', whereIn: [
      'driver_assigned',
      'en_route',
      'arrived',
      'in_progress'
    ]).snapshots();

    final kpis = <Widget>[
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: todayStream,
        builder: (context, snap) {
          final count = snap.data?.docs.length ?? 0;
          return _KpiCard(title: 'Bookings Today', value: '$count');
        },
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: activeStream,
        builder: (context, snap) {
          final count = snap.data?.docs.length ?? 0;
          return _KpiCard(title: 'Active Trips', value: '$count');
        },
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: todayStream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const _KpiCard(title: 'Revenue Today', value: '—');
          }
          final ids = snap.data!.docs.map((d) => d.id);
          return FutureBuilder<num>(
            future: _sumPrivateTotals(ids),
            builder: (context, s) {
              final total = s.data ?? 0;
              return _KpiCard(
                  title: 'Revenue Today',
                  value: '\$${total.toStringAsFixed(0)}');
            },
          );
        },
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: monthStream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const _KpiCard(title: 'Revenue Month', value: '—');
          }
          final ids = snap.data!.docs.map((d) => d.id);
          return FutureBuilder<num>(
            future: _sumPrivateTotals(ids),
            builder: (context, s) {
              final total = s.data ?? 0;
              return _KpiCard(
                  title: 'Revenue Month',
                  value: '\$${total.toStringAsFixed(0)}');
            },
          );
        },
      ),
    ];

    if (!compact) {
      return Row(
        children: [
          Expanded(child: kpis[0]),
          const SizedBox(width: 12),
          Expanded(child: kpis[1]),
          const SizedBox(width: 12),
          Expanded(child: kpis[2]),
          const SizedBox(width: 12),
          Expanded(child: kpis[3]),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              kpis.map((w) => SizedBox(width: itemWidth, child: w)).toList(),
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  const _KpiCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PFColors.white,
        borderRadius: BorderRadius.circular(18),
        border: const Border.fromBorderSide(BorderSide(color: PFColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: PFColors.muted)),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: PFColors.ink)),
          const SizedBox(height: 6),
          Container(
            height: 4,
            width: 42,
            decoration: BoxDecoration(
              color: PFColors.gold.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  Color get c {
    switch (status) {
      case 'confirmed':
        return PFColors.pink1;
      case 'driver_assigned':
        return PFColors.pink2;
      case 'en_route':
        return PFColors.gold;
      case 'arrived':
        return PFColors.gold;
      case 'in_progress':
        return const Color(0xFF1E9E75);
      case 'completed':
        return PFColors.muted;
      case 'cancelled':
        return const Color(0xFFDE5B5B);
      default:
        return PFColors.ink;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle));
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PFColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 12, color: PFColors.ink),
      ),
    );
  }
}
