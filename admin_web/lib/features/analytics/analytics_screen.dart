import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/firebase_providers.dart';
import '../../theme/pink_fleets_theme.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  Future<num> _sumPrivateTotals(
      FirebaseFirestore db, Iterable<String> bookingIds) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(firestoreProvider);
    final isNarrow = MediaQuery.of(context).size.width < 720;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfYear = DateTime(now.year, 1, 1);

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

    final yearStream = db
        .collection('bookings')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
        .snapshots();

    final activeStream = db.collection('bookings').where('status', whereIn: [
      'driver_assigned',
      'en_route',
      'arrived',
      'in_progress'
    ]).snapshots();

    final driversOnlineStream = db
        .collection('drivers')
        .where('status', isEqualTo: 'online')
        .snapshots();

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: PFColors.white,
            borderRadius: BorderRadius.circular(18),
            border:
                const Border.fromBorderSide(BorderSide(color: PFColors.border)),
          ),
          child: Row(
            children: [
              Text('Analytics',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(width: 12),
              Text(
                'Executive overview',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: PFColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpiStream(
              title: 'Bookings Today',
              stream: todayStream,
              valueBuilder: (s) => '${s.data?.docs.length ?? 0}',
              width: isNarrow ? double.infinity : 220,
            ),
            _kpiStream(
              title: 'Bookings This Month',
              stream: monthStream,
              valueBuilder: (s) => '${s.data?.docs.length ?? 0}',
              width: isNarrow ? double.infinity : 220,
            ),
            _kpiStream(
              title: 'Bookings This Year',
              stream: yearStream,
              valueBuilder: (s) => '${s.data?.docs.length ?? 0}',
              width: isNarrow ? double.infinity : 220,
            ),
            _kpiStream(
              title: 'Active Trips',
              stream: activeStream,
              valueBuilder: (s) => '${s.data?.docs.length ?? 0}',
              width: isNarrow ? double.infinity : 220,
            ),
            _kpiStream(
              title: 'Drivers Online',
              stream: driversOnlineStream,
              valueBuilder: (s) => '${s.data?.docs.length ?? 0}',
              width: isNarrow ? double.infinity : 220,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _revenueCard(
            db, todayStream, 'Revenue Today', isNarrow ? double.infinity : 220),
        const SizedBox(height: 12),
        _revenueCard(db, monthStream, 'Revenue This Month',
            isNarrow ? double.infinity : 220),
        const SizedBox(height: 12),
        _revenueCard(db, yearStream, 'Revenue This Year',
            isNarrow ? double.infinity : 220),
      ],
    );
  }

  Widget _kpiStream({
    required String title,
    required Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    required String Function(
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap)
        valueBuilder,
    required double width,
  }) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final value = valueBuilder(snap);
        return _KpiCard(title: title, value: value, width: width);
      },
    );
  }

  Widget _revenueCard(
    FirebaseFirestore db,
    Stream<QuerySnapshot<Map<String, dynamic>>> stream,
    String title,
    double width,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (!snap.hasData)
          return _KpiCard(title: title, value: '—', width: width);
        final ids = snap.data!.docs.map((d) => d.id);
        return FutureBuilder<num>(
          future: _sumPrivateTotals(db, ids),
          builder: (context, s) {
            final total = s.data ?? 0;
            return _KpiCard(
                title: title,
                value: '\$${total.toStringAsFixed(0)}',
                width: width);
          },
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final double width;

  const _KpiCard(
      {required this.title, required this.value, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
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
                  color: PFColors.muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
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
