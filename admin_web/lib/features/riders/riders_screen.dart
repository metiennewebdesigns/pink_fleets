import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/firebase_providers.dart';
import '../../theme/pink_fleets_theme.dart';
import '../../shared/date_time_format.dart';

class RidersScreen extends ConsumerStatefulWidget {
  const RidersScreen({super.key});

  @override
  ConsumerState<RidersScreen> createState() => _RidersScreenState();
}

class _RidersScreenState extends ConsumerState<RidersScreen> {
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

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(firestoreProvider);
    final ridersQ =
        db.collection('riders').orderBy('createdAt', descending: true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: PFColors.white,
            borderRadius: BorderRadius.circular(18),
            border:
                const Border.fromBorderSide(BorderSide(color: PFColors.border)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 720;
              final searchField = TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search riders',
                  prefixIcon: Icon(Icons.search),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Riders',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Customer directory',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: PFColors.muted),
                    ),
                    const SizedBox(height: 12),
                    searchField,
                  ],
                );
              }

              return Row(
                children: [
                  Text('Riders',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(width: 12),
                  Text(
                    'Customer directory',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: PFColors.muted),
                  ),
                  const Spacer(),
                  SizedBox(width: 320, child: searchField),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: ridersQ.snapshots(),
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
                  final d = doc.data();
                  final name = (d['name'] ?? '').toString().toLowerCase();
                  final email = (d['email'] ?? '').toString().toLowerCase();
                  final phone = (d['phone'] ?? '').toString().toLowerCase();
                  final dob = formatTimestamp(d['dob']).toLowerCase();
                  return name.contains(s) ||
                      email.contains(s) ||
                      phone.contains(s) ||
                      dob.contains(s);
                }).toList();
              }

              if (docs.isEmpty) {
                return const _RiderFallbackFromBookings();
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final d = doc.data();

                  final name = (d['name'] ?? 'Rider').toString();
                  final email = (d['email'] ?? '—').toString();
                  final phone = (d['phone'] ?? '—').toString();
                  final dob = formatTimestamp(d['dob']);
                  final createdAt = d['createdAt'];

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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 560;
                        final createdBlock = Column(
                          crossAxisAlignment: narrow
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Created',
                              style: TextStyle(
                                  color: PFColors.muted.withValues(alpha: 0.9),
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatTimestamp(createdAt),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ],
                        );

                        final mainInfo = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(email,
                                style: const TextStyle(color: PFColors.muted)),
                            const SizedBox(height: 2),
                            Text(phone,
                                style: const TextStyle(color: PFColors.muted)),
                            const SizedBox(height: 2),
                            Text('DOB: $dob',
                                style: const TextStyle(color: PFColors.muted)),
                          ],
                        );

                        if (narrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        PFColors.gold.withValues(alpha: 0.15),
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'R',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: PFColors.ink),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: mainInfo),
                                ],
                              ),
                              const SizedBox(height: 10),
                              createdBlock,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  PFColors.gold.withValues(alpha: 0.15),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'R',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: PFColors.ink),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: mainInfo),
                            createdBlock,
                          ],
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RiderFallbackFromBookings extends ConsumerWidget {
  const _RiderFallbackFromBookings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(firestoreProvider);
    final bookingsQ =
        db.collection('bookings').orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: bookingsQ.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error:\n${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No riders found.'));

        final riders = <String, Map<String, dynamic>>{};
        for (final doc in docs) {
          final d = doc.data();
          final riderUid = (d['riderUid'] ?? '').toString();
          final rider = d['riderInfo'] as Map<String, dynamic>?;
          if (riderUid.isEmpty && rider == null) continue;
          riders[riderUid.isEmpty ? doc.id : riderUid] = {
            'name': (rider?['name'] ?? 'Rider').toString(),
            'email': (rider?['email'] ?? '—').toString(),
            'phone': (rider?['phone'] ?? '—').toString(),
            'dob': rider?['dob'],
            'createdAt': d['createdAt'],
          };
        }

        if (riders.isEmpty) {
          return const Center(child: Text('No riders found.'));
        }

        final items = riders.values.toList();

        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final d = items[i];
            final name = (d['name'] ?? 'Rider').toString();
            final email = (d['email'] ?? '—').toString();
            final phone = (d['phone'] ?? '—').toString();
            final dob = formatTimestamp(d['dob']);
            final createdAt = d['createdAt'];

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: PFColors.gold.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'R',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, color: PFColors.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(email,
                            style: const TextStyle(color: PFColors.muted)),
                        const SizedBox(height: 2),
                        Text(phone,
                            style: const TextStyle(color: PFColors.muted)),
                        const SizedBox(height: 2),
                        Text('DOB: $dob',
                            style: const TextStyle(color: PFColors.muted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Created',
                        style: TextStyle(
                            color: PFColors.muted.withValues(alpha: 0.9),
                            fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatTimestamp(createdAt),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12),
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
