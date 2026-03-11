import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../theme/dispatcher_theme.dart';

class DriversScreen extends StatelessWidget {
  const DriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driversRef = FirebaseFirestore.instance.collection('drivers');

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
              final createLoginButton = ElevatedButton.icon(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const _CreateDriverUserDialog(),
                ),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Create Driver Login'),
              );

              final addButton = OutlinedButton.icon(
                style: ElevatedButton.styleFrom(
                  foregroundColor: PFColors.ink,
                  side: const BorderSide(color: PFColors.border),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => _DriverEditorDialog(
                    title: 'Add Driver',
                    onSave: (data) async {
                      final uid = (data['uid'] ?? '').toString().trim();
                      if (uid.isEmpty) return;

                      await driversRef.doc(uid).set({
                        'name': data['name'],
                        'approved': data['approved'],
                        'active': data['active'],
                        'status': data['status'],
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                    },
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add Driver'),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Drivers',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 6),
                    Text('Dispatcher view',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: PFColors.muted)),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: createLoginButton),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: addButton),
                  ],
                );
              }

              return Row(
                children: [
                  Text('Drivers',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(width: 12),
                  Text('Dispatcher view',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: PFColors.muted)),
                  const Spacer(),
                  createLoginButton,
                  const SizedBox(width: 8),
                  addButton,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: driversRef.snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error:\n${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No drivers yet.'));
              }

              docs.sort((a, b) {
                final ad = a.data();
                final bd = b.data();
                final aScore = ((ad['approved'] == true) ? 2 : 0) +
                    ((ad['active'] != false) ? 1 : 0);
                final bScore = ((bd['approved'] == true) ? 2 : 0) +
                    ((bd['active'] != false) ? 1 : 0);
                if (aScore != bScore) return bScore.compareTo(aScore);
                final an = (ad['name'] ?? a.id).toString();
                final bn = (bd['name'] ?? b.id).toString();
                return an.compareTo(bn);
              });

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final d = doc.data();

                  final name = (d['name'] ?? 'Driver').toString();
                  final approved = d['approved'] == true;
                  final active = d['active'] != false;
                  final status = (d['status'] ?? 'offline').toString();
                  final uid = doc.id;

                  final actions = Wrap(
                    spacing: 6,
                    children: [
                      _pill(approved ? 'APPROVED' : 'PENDING', approved),
                      _pill(active ? 'ACTIVE' : 'INACTIVE', active),
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit),
                        onPressed: () => showDialog(
                          context: context,
                          builder: (_) => _DriverEditorDialog(
                            title: 'Edit Driver',
                            initialUid: uid,
                            initialName: name,
                            initialApproved: approved,
                            initialActive: active,
                            initialStatus: status,
                            onSave: (data) async {
                              await driversRef.doc(uid).set({
                                'name': data['name'],
                                'approved': data['approved'],
                                'active': data['active'],
                                'status': data['status'],
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete driver doc?'),
                              content: Text(
                                  'This deletes driver PROFILE doc:\n$uid\n\nIt does NOT delete Auth login.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel')),
                                ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await driversRef.doc(uid).delete();
                          }
                        },
                      ),
                    ],
                  );

                  return Container(
                    decoration: BoxDecoration(
                      color: PFColors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: const Border.fromBorderSide(
                          BorderSide(color: PFColors.border)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 560;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900)),
                              subtitle: Text('status: $status'),
                              trailing: narrow ? null : actions,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              isThreeLine: narrow,
                              dense: narrow,
                            ),
                            if (narrow)
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: actions,
                              ),
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

  static Widget _pill(String text, bool good) {
    final c = good ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Text(text,
          style:
              TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: c)),
    );
  }
}

class _CreateDriverUserDialog extends StatefulWidget {
  const _CreateDriverUserDialog();

  @override
  State<_CreateDriverUserDialog> createState() =>
      _CreateDriverUserDialogState();
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
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Driver Name')),
            const SizedBox(height: 12),
            TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: loading ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: loading ? null : create,
            child: Text(loading ? 'Creating…' : 'Create')),
      ],
    );
  }
}

class _DriverEditorDialog extends StatefulWidget {
  final String title;
  final String? initialUid;
  final String? initialName;
  final bool? initialApproved;
  final bool? initialActive;
  final String? initialStatus;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  const _DriverEditorDialog({
    required this.title,
    required this.onSave,
    this.initialUid,
    this.initialName,
    this.initialApproved,
    this.initialActive,
    this.initialStatus,
  });

  @override
  State<_DriverEditorDialog> createState() => _DriverEditorDialogState();
}

class _DriverEditorDialogState extends State<_DriverEditorDialog> {
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
      backgroundColor: PFColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title,
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            editing
                ? 'Update driver profile details.'
                : 'Create a driver profile from an Auth UID.',
            style: const TextStyle(color: PFColors.muted, fontSize: 12),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!editing)
                TextField(
                  controller: uidCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Driver UID (from Firebase Auth)',
                    hintText: 'Paste UID here',
                  ),
                ),
              if (!editing) const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Display Name'),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: PFColors.page,
                  borderRadius: BorderRadius.circular(14),
                  border: const Border.fromBorderSide(
                      BorderSide(color: PFColors.border)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Approved'),
                      value: approved,
                      onChanged: (v) => setState(() => approved = v),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Active'),
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                    ),
                  ],
                ),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () async {
            final uid = uidCtrl.text.trim();
            if (!editing && uid.isEmpty) return;

            await widget.onSave({
              'uid': uid,
              'name': nameCtrl.text.trim().isEmpty
                  ? 'Driver'
                  : nameCtrl.text.trim(),
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
