// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../theme/dispatcher_theme.dart';

// ── Checklist items ──────────────────────────────────────────────────────────
const _kItems = [
  ('front_bumper', 'Front bumper'),
  ('rear_bumper', 'Rear bumper'),
  ('left_side', 'Left side'),
  ('right_side', 'Right side'),
  ('windshield', 'Windshield'),
  ('windows', 'Windows'),
  ('wheels_tires', 'Wheels & tires'),
  ('lights', 'Lights & signals'),
  ('interior', 'Interior condition'),
  ('trunk', 'Trunk/Storage'),
  ('fuel_level', 'Fuel level'),
  ('odometer', 'Odometer photo'),
  ('cleanliness', 'Cleanliness'),
];

// ── Screen ───────────────────────────────────────────────────────────────────
class InspectionViewerScreen extends StatefulWidget {
  final String bookingId;
  final String stage;

  const InspectionViewerScreen({
    super.key,
    required this.bookingId,
    required this.stage,
  });

  @override
  State<InspectionViewerScreen> createState() => _InspectionViewerScreenState();
}

class _InspectionViewerScreenState extends State<InspectionViewerScreen> {
  bool _exportBusy = false;
  String get _stageTitle =>
      widget.stage == 'pre' ? 'Pre-Trip Inspection' : 'Post-Trip Inspection';

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .collection('driver_inspections')
        .doc(widget.stage);

    return Scaffold(
      backgroundColor: PFColors.canvas,
      appBar: AppBar(
        backgroundColor: PFColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: PFColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _stageTitle,
              style: PFTypography.titleLarge,
            ),
            Text(
              'Booking ${widget.bookingId.substring(0, 8)}',
              style: PFTypography.bodySmall,
            ),
          ],
        ),
        actions: [
          _exportBusy
              ? const Padding(
                  padding: EdgeInsets.all(PFSpacing.base),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : OutlinedButton.icon(
                  onPressed: _onExportPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Export PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PFColors.gold,
                    side: const BorderSide(color: PFColors.goldSoft),
                  ),
                ),
          const SizedBox(width: PFSpacing.md),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return Center(
              child: PFEmptyState(
                icon: Icons.assignment_outlined,
                title: 'No inspection yet',
                body: 'The driver has not submitted $_stageTitle yet.',
              ),
            );
          }

          final data = snap.data!.data()!;
          final notes = (data['notes'] ?? '').toString();
          final checklist = (data['checklist'] as Map<String, dynamic>?) ?? {};
          final uploads = (data['uploads'] as List?)?.cast<Map>() ?? [];
          final updatedAt = _fmtTs(data['updatedAt']);

          final images = uploads
              .where((u) =>
                  _isImage((u['name'] ?? '').toString()) ||
                  (u['type'] ?? '').toString().startsWith('image'))
              .toList();
          final videos = uploads
              .where((u) =>
                  _isVideo((u['name'] ?? '').toString()) ||
                  (u['type'] ?? '').toString().startsWith('video'))
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                PFSpacing.base, PFSpacing.sm, PFSpacing.base, PFSpacing.xxxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Meta banner ──────────────────────────────────────
                  PFCard(
                    padding: const EdgeInsets.all(PFSpacing.base),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(PFSpacing.sm),
                          decoration: BoxDecoration(
                            color: PFColors.primarySoft,
                            borderRadius:
                                BorderRadius.circular(PFSpacing.radiusSm),
                          ),
                          child: const Icon(Icons.assignment_turned_in_rounded,
                              color: PFColors.primary, size: 20),
                        ),
                        const SizedBox(width: PFSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_stageTitle, style: PFTypography.titleLarge),
                              Text('Updated: $updatedAt',
                                  style: PFTypography.bodySmall),
                            ],
                          ),
                        ),
                        PFChipStatus(
                          status:
                              widget.stage == 'pre' ? 'submitted' : 'completed',
                          label:
                              widget.stage == 'pre' ? 'PRE-TRIP' : 'POST-TRIP',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: PFSpacing.xl),

                  // ── Checklist ─────────────────────────────────────────
                  const PFSectionHeader(title: 'Vehicle Checklist'),
                  const SizedBox(height: PFSpacing.md),
                  PFCard(
                    padding: const EdgeInsets.all(PFSpacing.base),
                    child: _ChecklistGrid(checklist: checklist, items: _kItems),
                  ),

                  const SizedBox(height: PFSpacing.xl),

                  // ── Notes ─────────────────────────────────────────────
                  const PFSectionHeader(title: 'Driver Notes'),
                  const SizedBox(height: PFSpacing.md),
                  PFCard(
                    padding: const EdgeInsets.all(PFSpacing.base),
                    child: notes.isEmpty
                        ? Text('No notes recorded.',
                            style: PFTypography.bodySmall)
                        : SelectableText(notes,
                            style: PFTypography.bodyMedium
                                .copyWith(color: PFColors.inkSoft)),
                  ),

                  // ── Photos ────────────────────────────────────────────
                  if (images.isNotEmpty) ...[
                    const SizedBox(height: PFSpacing.xl),
                    PFSectionHeader(
                      title: 'Photos',
                      trailing: Text(
                        '${images.length}',
                        style: PFTypography.labelSmall
                            .copyWith(color: PFColors.muted),
                      ),
                    ),
                    const SizedBox(height: PFSpacing.md),
                    _PhotoGrid(uploads: images),
                  ],

                  // ── Videos ────────────────────────────────────────────
                  if (videos.isNotEmpty) ...[
                    const SizedBox(height: PFSpacing.xl),
                    PFSectionHeader(
                      title: 'Videos',
                      trailing: Text('${videos.length}',
                          style: PFTypography.labelSmall),
                    ),
                    const SizedBox(height: PFSpacing.md),
                    ...videos.map((v) => _VideoTile(upload: v)),
                  ],

                  const SizedBox(height: PFSpacing.xxxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onExportPdf() async {
    if (_exportBusy) return;
    setState(() => _exportBusy = true);
    try {
      final docRef = FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .collection('driver_inspections')
          .doc(widget.stage);
      final snap = await docRef.get();
      if (!snap.exists) return;
      final data = snap.data()!;
      final bytes = await _buildPdf(data);
      _triggerDownload(bytes,
          '${widget.bookingId.substring(0, 8)}_${widget.stage}_inspection.pdf');
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<Uint8List> _buildPdf(Map<String, dynamic> data) async {
    final notes = (data['notes'] ?? '').toString();
    final checklist = (data['checklist'] as Map<String, dynamic>?) ?? {};
    final uploads = (data['uploads'] as List?)?.cast<Map>() ?? [];
    final updatedAt = _fmtTs(data['updatedAt']);

    final doc = pw.Document();

    final imgWidgets = <pw.Widget>[];
    for (final u in uploads) {
      final name = (u['name'] ?? 'Upload').toString();
      if (!_isImage(name) &&
          !(u['type'] ?? '').toString().startsWith('image')) {
        continue;
      }
      try {
        final bytes = await _fetchBytes(u);
        if (bytes == null) continue;
        imgWidgets.addAll([
          pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Image(pw.MemoryImage(bytes), height: 200, fit: pw.BoxFit.cover),
          pw.SizedBox(height: 10),
        ]);
      } catch (_) {}
    }

    doc.addPage(pw.MultiPage(
        build: (ctx) => [
              pw.Text('Pink Fleets — Driver Inspection',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text('Booking: ${widget.bookingId.substring(0, 8)}'),
              pw.Text('Stage: $_stageTitle'),
              pw.Text('Updated: $updatedAt'),
              pw.SizedBox(height: 14),
              pw.Text('Checklist',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: const pw.TableBorder(
                    horizontalInside: pw.BorderSide(color: PdfColors.grey300)),
                children: _kItems.map((item) {
                  final ok = checklist[item.$1] == true;
                  return pw.TableRow(children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(item.$2),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 3),
                      child: pw.Text(ok ? '✓' : '—',
                          style: pw.TextStyle(
                              color: ok ? PdfColors.green : PdfColors.grey)),
                    ),
                  ]);
                }).toList(),
              ),
              pw.SizedBox(height: 14),
              pw.Text('Notes',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 14)),
              pw.SizedBox(height: 6),
              pw.Text(notes.isEmpty ? '—' : notes),
              if (imgWidgets.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text('Photos',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(height: 6),
                ...imgWidgets,
              ],
            ]));
    return doc.save();
  }

  static void _triggerDownload(Uint8List bytes, String fileName) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none'
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String _fmtTs(dynamic v) {
  if (v is Timestamp) {
    final dt = v.toDate().toLocal();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  return v?.toString() ?? '—';
}

bool _isImage(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.gif');
}

bool _isVideo(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.webm');
}

Future<Uint8List?> _fetchBytes(Map upload) async {
  final path = (upload['path'] ?? '').toString();
  final url = (upload['url'] ?? '').toString();
  try {
    if (path.isNotEmpty) {
      return await FirebaseStorage.instance.ref(path).getData(10 * 1024 * 1024);
    }
    if (url.isNotEmpty) {
      return await FirebaseStorage.instance
          .refFromURL(url)
          .getData(10 * 1024 * 1024);
    }
  } catch (_) {}
  try {
    if (url.isEmpty) return null;
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode != 200) return null;
    return resp.bodyBytes;
  } catch (_) {
    return null;
  }
}

// ── Checklist grid ─────────────────────────────────────────────────────────────
class _ChecklistGrid extends StatelessWidget {
  final Map<String, dynamic> checklist;
  final List<(String, String)> items;

  const _ChecklistGrid({required this.checklist, required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: PFSpacing.md,
      runSpacing: PFSpacing.sm,
      children: items.map((item) {
        final ok = checklist[item.$1] == true;
        final color = ok ? PFColors.success : PFColors.danger;
        return Container(
          constraints: const BoxConstraints(minWidth: 160),
          padding: const EdgeInsets.symmetric(
              horizontal: PFSpacing.md, vertical: PFSpacing.sm),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(PFSpacing.radiusSm),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: PFSpacing.xs),
              Text(item.$2,
                  style: PFTypography.labelSmall.copyWith(color: color)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Photo grid ────────────────────────────────────────────────────────────────
class _PhotoGrid extends StatelessWidget {
  final List<Map> uploads;

  const _PhotoGrid({required this.uploads});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = (constraints.maxWidth ~/ 220).clamp(1, 4);
      return Wrap(
        spacing: PFSpacing.sm,
        runSpacing: PFSpacing.sm,
        children: uploads.map((u) {
          final w = (constraints.maxWidth - (cols - 1) * PFSpacing.sm) / cols;
          return SizedBox(
            width: w,
            child: _PhotoTile(upload: u),
          );
        }).toList(),
      );
    });
  }
}

class _PhotoTile extends StatefulWidget {
  final Map upload;

  const _PhotoTile({required this.upload});

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await _fetchBytes(widget.upload);
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  void _openFullscreen(BuildContext context) {
    final url = (widget.upload['url'] ?? '').toString();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: PFColors.canvas,
        insetPadding: const EdgeInsets.all(PFSpacing.base),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 6.0,
              child: _bytes != null
                  ? Image.memory(_bytes!, fit: BoxFit.contain)
                  : url.isNotEmpty
                      ? Image.network(url, fit: BoxFit.contain)
                      : const SizedBox(height: 300),
            ),
            Positioned(
              top: PFSpacing.sm,
              right: PFSpacing.sm,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: PFColors.ink),
                onPressed: () => Navigator.pop(context),
                style:
                    IconButton.styleFrom(backgroundColor: PFColors.surfaceHigh),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.upload['name'] ?? 'Photo').toString();
    final url = (widget.upload['url'] ?? '').toString();

    return GestureDetector(
      onTap: _loading || _error ? null : () => _openFullscreen(context),
      child: Container(
        decoration: BoxDecoration(
          color: PFColors.surfaceHigh,
          borderRadius: BorderRadius.circular(PFSpacing.radius),
          border: Border.all(color: PFColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(PFSpacing.radius)),
                child: _loading
                    ? Container(
                        color: PFColors.surfaceHigh,
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : _bytes != null
                        ? Image.memory(_bytes!, fit: BoxFit.cover)
                        : url.isNotEmpty
                            ? Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _errorPlaceholder(),
                              )
                            : _errorPlaceholder(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(PFSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.image_outlined,
                      size: 12, color: PFColors.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      name,
                      style: PFTypography.labelSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!_loading && _bytes != null)
                    const Icon(Icons.zoom_in_rounded,
                        size: 12, color: PFColors.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorPlaceholder() => Container(
        color: PFColors.surfaceHigh,
        child: const Center(
          child: Icon(Icons.broken_image_outlined,
              size: 32, color: PFColors.muted),
        ),
      );
}

// ── Video tile ─────────────────────────────────────────────────────────────────
class _VideoTile extends StatelessWidget {
  final Map upload;

  const _VideoTile({required this.upload});

  @override
  Widget build(BuildContext context) {
    final name = (upload['name'] ?? 'Video').toString();
    final url = (upload['url'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: PFSpacing.sm),
      child: PFCard(
        padding: const EdgeInsets.symmetric(
            horizontal: PFSpacing.base, vertical: PFSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: PFColors.primarySoft,
                borderRadius: BorderRadius.circular(PFSpacing.radiusSm),
              ),
              child: const Icon(Icons.videocam_rounded,
                  color: PFColors.primary, size: 20),
            ),
            const SizedBox(width: PFSpacing.md),
            Expanded(
              child: Text(name, style: PFTypography.titleSmall),
            ),
            if (url.isNotEmpty) ...[
              OutlinedButton.icon(
                onPressed: () => html.window.open(url, '_blank'),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                label: const Text('Open'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PFColors.primary,
                  side: BorderSide(
                      color: PFColors.primary.withValues(alpha: 0.4)),
                ),
              ),
              const SizedBox(width: PFSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => html.window.open(url, '_blank'),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: PFColors.muted,
                    side: const BorderSide(color: PFColors.border)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
