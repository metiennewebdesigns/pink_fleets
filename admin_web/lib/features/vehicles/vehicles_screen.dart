import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/firebase_providers.dart';
import '../../theme/pink_fleets_theme.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(firestoreProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: PFColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: const Border.fromBorderSide(BorderSide(color: PFColors.border)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 720;
              final addButton = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PFColors.primary,
                  foregroundColor: PFColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Vehicle'),
                onPressed: () => _addVehicle(context, db),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicles',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Garage inventory',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: PFColors.muted),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: addButton),
                  ],
                );
              }

              return Row(
                children: [
                  Text(
                    'Vehicles',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Garage inventory',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: PFColors.muted),
                  ),
                  const Spacer(),
                  addButton,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('vehicles').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final raw = (snapshot.error ?? '').toString().toLowerCase();
                final msg = (raw.contains('permission-denied') ||
                        raw.contains('insufficient permissions'))
                    ? 'Vehicle list is read-protected for this account.'
                    : 'Could not load vehicles right now.';

                return Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 560),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: PFColors.dangerSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: PFColors.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: PFColors.danger),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text('No vehicles added yet.'));
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final data = docs[index];
                  final map = (data.data() as Map<String, dynamic>? ??
                      const <String, dynamic>{});
                  final name = (map['name'] ??
                          map['label'] ??
                          map['unitNumber'] ??
                          'Vehicle')
                      .toString();
                  final typeRaw =
                      (map['type'] ?? map['category'] ?? map['model'] ?? '')
                          .toString()
                          .trim();
                  final plate =
                      (map['licensePlate'] ?? map['plate'] ?? '')
                          .toString()
                          .trim();

                  return Container(
                    decoration: BoxDecoration(
                      color: PFColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: const Border.fromBorderSide(
                        BorderSide(color: PFColors.border),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  typeRaw.isEmpty ? 'Type: —' : typeRaw,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: PFColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (plate.isNotEmpty) ...[
                            PFPlateBadge(plate: plate),
                            const SizedBox(width: 10),
                          ],
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18),
                            color: PFColors.muted,
                            tooltip: 'Delete',
                            onPressed: () =>
                                db.collection('vehicles').doc(data.id).delete(),
                          ),
                        ],
                      ),
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

  void _addVehicle(BuildContext context, FirebaseFirestore db) {
    final nameCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final plateCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PFColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Add Vehicle',
                style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 4),
            Text(
              'Add vehicle details below.',
              style: TextStyle(color: PFColors.muted, fontSize: 12),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Vehicle Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: typeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Type (e.g. Escalade, Navigator, Sprinter)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: plateCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'License Plate (e.g. CA 123-456)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PFColors.primary,
              foregroundColor: PFColors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              await db.collection('vehicles').add({
                'name': name,
                'type': typeCtrl.text.trim(),
                'licensePlate': plateCtrl.text.trim().toUpperCase(),
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
