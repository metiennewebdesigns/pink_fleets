import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../theme/pink_fleets_theme.dart';

class DriversScreen extends StatelessWidget {
  const DriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driversRef = FirebaseFirestore.instance.collection('drivers');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1120;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: driversRef.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) return Center(child: Text('Error:\n${snap.error}'));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());

            final docs = snap.data!.docs;
            docs.sort((a, b) {
              final ad = a.data();
              final bd = b.data();
              final aScore = ((ad['approved'] == true) ? 2 : 0) + ((ad['active'] != false) ? 1 : 0);
              final bScore = ((bd['approved'] == true) ? 2 : 0) + ((bd['active'] != false) ? 1 : 0);
              if (aScore != bScore) return bScore.compareTo(aScore);
              final an = (ad['name'] ?? a.id).toString();
              final bn = (bd['name'] ?? b.id).toString();
              return an.compareTo(bn);
            });

            return Scrollbar(
              thumbVisibility: true,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: PFColors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: const Border.fromBorderSide(BorderSide(color: PFColors.border)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Drivers', style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        Text(
                          'Fleet management',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: PFColors.muted),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => const _CreateDriverUserDialog(),
                              ),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Create Driver Login'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => _DriverProfileDialog(
                                  title: 'Add Profile (UID)',
                                  onSave: (uid, data) async {
                                    if (uid.trim().isEmpty) return;
                                    await driversRef.doc(uid.trim()).set({
                                      ...data,
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    }, SetOptions(merge: true));
                                  },
                                ),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Profile (UID)'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (docs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: PFColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: const Border.fromBorderSide(BorderSide(color: PFColors.border)),
                      ),
                      child: const Text('No drivers yet.'),
                    )
                  else
                    ...docs.map(
                      (doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DriverListCard(
                          doc: doc,
                          isCompact: isCompact,
                          onEdit: (uid, name, approved, active, status) {
                            showDialog(
                              context: context,
                              builder: (_) => _DriverProfileDialog(
                                title: 'Edit Driver',
                                initialUid: uid,
                                initialName: name,
                                initialApproved: approved,
                                initialActive: active,
                                initialStatus: status,
                                onSave: (uid, data) async {
                                  await driversRef.doc(uid).set({
                                    ...data,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                                },
                              ),
                            );
                          },
                          onDelete: (uid) async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete driver profile doc?'),
                                content: Text(
                                  'This deletes only the Firestore driver doc:\n\n$uid\n\n'
                                  'It does NOT delete the Auth login account.',
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (ok == true) await driversRef.doc(uid).delete();
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'Create Driver Login creates a Firebase Auth account + role=driver + driver profile doc.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _pill({required String text, required bool good}) {
    final c = good ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: c)),
    );
  }
}

class _DriverListCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool isCompact;
  final void Function(String uid, String name, bool approved, bool active, String status) onEdit;
  final Future<void> Function(String uid) onDelete;

  const _DriverListCard({
    required this.doc,
    required this.isCompact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final uid = doc.id;
    final name = (d['name'] ?? 'Driver').toString();
    final approved = d['approved'] == true;
    final active = d['active'] != false;
    final status = (d['status'] ?? 'offline').toString();
    final shortUid = uid.length <= 10 ? uid : '${uid.substring(0, 10)}…';

    final badges = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        DriversScreen._pill(text: approved ? 'APPROVED' : 'PENDING', good: approved),
        DriversScreen._pill(text: active ? 'ACTIVE' : 'INACTIVE', good: active),
      ],
    );

    final actions = Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        IconButton(
          tooltip: 'Edit',
          icon: const Icon(Icons.edit),
          onPressed: () => onEdit(uid, name, approved, active, status),
        ),
        IconButton(
          tooltip: 'Delete profile doc',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => onDelete(uid),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PFColors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(BorderSide(color: PFColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text('UID: $shortUid • status: $status', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                badges,
                const SizedBox(height: 8),
                actions,
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('UID: $shortUid • status: $status', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                badges,
                const SizedBox(width: 8),
                actions,
              ],
            ),
    );
  }
}

class _CreateDriverUserDialog extends StatefulWidget {
  const _CreateDriverUserDialog();

  @override
  State<_CreateDriverUserDialog> createState() => _CreateDriverUserDialogState();
}

class _CreateDriverUserDialogState extends State<_CreateDriverUserDialog> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  String? error;
  bool loading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> create() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final fn = FirebaseFunctions.instance.httpsCallable('createDriverUser');
      final res = await fn.call({
        'email': emailCtrl.text.trim(),
        'password': passCtrl.text,
        'name': nameCtrl.text.trim(),
      });

      final uid = (res.data as Map)['uid'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Driver login created. UID: $uid')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Driver Login'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Driver Name')),
            const SizedBox(height: 12),
            TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: loading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: loading ? null : create, child: Text(loading ? 'Creating…' : 'Create')),
      ],
    );
  }
}

class _DriverProfileDialog extends StatefulWidget {
  final String title;
  final String? initialUid;
  final String? initialName;
  final bool? initialApproved;
  final bool? initialActive;
  final String? initialStatus;
  final Future<void> Function(String uid, Map<String, dynamic> data) onSave;

  const _DriverProfileDialog({
    required this.title,
    required this.onSave,
    this.initialUid,
    this.initialName,
    this.initialApproved,
    this.initialActive,
    this.initialStatus,
  });

  @override
  State<_DriverProfileDialog> createState() => _DriverProfileDialogState();
}

class _DriverProfileDialogState extends State<_DriverProfileDialog> {
  late final TextEditingController uidCtrl;
  late final TextEditingController nameCtrl;
  bool approved = false;
  bool active = true;
  String status = 'offline';

  @override
  void initState() {
    super.initState();
    uidCtrl = TextEditingController(text: widget.initialUid ?? '');
    nameCtrl = TextEditingController(text: widget.initialName ?? '');
    approved = widget.initialApproved ?? false;
    active = widget.initialActive ?? true;
    status = widget.initialStatus ?? 'offline';
  }

  @override
  void dispose() {
    uidCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialUid != null;

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!editing)
              TextField(
                controller: uidCtrl,
                decoration: const InputDecoration(labelText: 'Driver UID (from Firebase Auth)'),
              ),
            if (!editing) const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Approved'),
                    value: approved,
                    onChanged: (v) => setState(() => approved = v),
                  ),
                ),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: active,
                    onChanged: (v) => setState(() => active = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'offline', child: Text('offline')),
                DropdownMenuItem(value: 'online', child: Text('online')),
              ],
              onChanged: (v) => setState(() => status = v ?? 'offline'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final uid = editing ? widget.initialUid! : uidCtrl.text.trim();
            if (uid.isEmpty) return;

            await widget.onSave(uid, {
              'name': nameCtrl.text.trim().isEmpty ? 'Driver' : nameCtrl.text.trim(),
              'approved': approved,
              'active': active,
              'status': status,
            });

            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}