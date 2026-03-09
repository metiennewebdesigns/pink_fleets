import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/dispatcher_theme.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vehiclesRef = FirebaseFirestore.instance.collection('vehicles');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _VehicleEditorDialog(
                    title: 'Add Vehicle',
                    onSave: (data) async {
                      await vehiclesRef.add({
                        'name': data['name'],
                        'type': data['type'],
                        'licensePlate': data['licensePlate'],
                        'active': data['active'],
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    },
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Vehicle'),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vehicles', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Dispatcher view',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: PFColors.muted),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: addButton),
                  ],
                );
              }

              return Row(
                children: [
                  Text('Vehicles', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(width: 12),
                  Text(
                    'Dispatcher view',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: PFColors.muted),
                  ),
                  const Spacer(),
                  addButton,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: vehiclesRef.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Error:\n${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('No vehicles yet.'));

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final d = doc.data();
                  final name = (d['name'] ?? 'Vehicle').toString();
                  final type = (d['type'] ?? '').toString();
                  final plate = (d['licensePlate'] ?? '').toString().trim();
                  final active = d['active'] != false;
                  final typeLabel = type.isEmpty
                      ? 'Uncategorized'
                      : '${type[0].toUpperCase()}${type.substring(1)}';

                  return Container(
                    decoration: BoxDecoration(
                      color: PFColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: const Border.fromBorderSide(BorderSide(color: PFColors.border)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          PFLiveDot(status: active ? 'online' : 'offline', size: 10),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  typeLabel,
                                  style: const TextStyle(fontSize: 12, color: PFColors.muted),
                                ),
                              ],
                            ),
                          ),
                          if (plate.isNotEmpty) ...[
                            PFPlateBadge(plate: plate),
                            const SizedBox(width: 10),
                          ],
                          _pill(active ? 'ACTIVE' : 'INACTIVE', active),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            color: PFColors.muted,
                            onPressed: () => showDialog(
                              context: context,
                              builder: (_) => _VehicleEditorDialog(
                                title: 'Edit Vehicle',
                                initialName: name,
                                initialType: type,
                                initialPlate: plate,
                                initialActive: active,
                                onSave: (data) async {
                                  await vehiclesRef.doc(doc.id).set({
                                    'name': data['name'],
                                    'type': data['type'],
                                    'licensePlate': data['licensePlate'],
                                    'active': data['active'],
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                                },
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            color: PFColors.muted,
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  backgroundColor: PFColors.surface,
                                  surfaceTintColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  title: const Text('Delete vehicle?'),
                                  content: Text('Delete "$name"?\n\nThis cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: PFColors.danger,
                                        foregroundColor: PFColors.white,
                                      ),
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) await vehiclesRef.doc(doc.id).delete();
                            },
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

  static Widget _pill(String text, bool good) {
    final c = good ? PFColors.success : PFColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: c, letterSpacing: 0.5),
      ),
    );
  }
}

class _VehicleEditorDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialType;
  final String? initialPlate;
  final bool? initialActive;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  const _VehicleEditorDialog({
    required this.title,
    required this.onSave,
    this.initialName,
    this.initialType,
    this.initialPlate,
    this.initialActive,
  });

  @override
  State<_VehicleEditorDialog> createState() => _VehicleEditorDialogState();
}

class _VehicleEditorDialogState extends State<_VehicleEditorDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController typeCtrl;
  late final TextEditingController plateCtrl;
  bool active = true;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.initialName ?? '');
    typeCtrl = TextEditingController(text: widget.initialType ?? '');
    plateCtrl = TextEditingController(text: widget.initialPlate ?? '');
    active = widget.initialActive ?? true;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    typeCtrl.dispose();
    plateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PFColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
            'Vehicle details and availability.',
            style: TextStyle(color: PFColors.muted, fontSize: 12),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name (display)'),
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
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: PFColors.canvas,
                  borderRadius: BorderRadius.circular(14),
                  border: const Border.fromBorderSide(BorderSide(color: PFColors.border)),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: PFColors.pink2,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () async {
            final name = nameCtrl.text.trim();
            final type = typeCtrl.text.trim();
            if (name.isEmpty) return;
            await widget.onSave({
              'name': name,
              'type': type,
              'licensePlate': plateCtrl.text.trim().toUpperCase(),
              'active': active,
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
