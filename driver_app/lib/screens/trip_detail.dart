import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../providers/firebase_providers.dart';
import '../shared/image_compress_service.dart';
import '../shared/web_camera_capture_service.dart';
import '../shared/date_time_format.dart';
import '../shared/widgets/live_trip_map.dart';
import '../services/function_media_upload_service.dart'
    show
        kDriverUploadImageEndpoint,
        kDriverPingEndpoint,
        kSaveInspectionEndpoint;
import '../services/media_capture_service.dart';
import '../services/storage_upload_service.dart';
import '../shared/open_url.dart';
import '../theme/driver_theme.dart';

// Set to true temporarily to see capture/compression/upload diagnostics.
// Always false in production builds.
const bool kDebugUploads = false;

class TripDetail extends ConsumerWidget {
  final String bookingId;
  const TripDetail({super.key, required this.bookingId});
  static const String buildStamp = 'BUILD 2026-03-03-1';

  static const int graceMinutes = 15;
  static const double overtimeRatePerMinute = 2.0;

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return PFColors.primary;
      case 'en_route':
        return PFColors.warning;
      case 'arrived':
        return const Color(0xFF0E8FAF);
      case 'in_progress':
        return PFColors.success;
      case 'completed':
        return PFColors.muted;
      case 'cancelled':
        return PFColors.danger;
      default:
        return PFColors.ink;
    }
  }

  Future<void> _setStatus(
      DocumentReference<Map<String, dynamic>> ref, String status) async {
    final snap = await ref.get();
    final currentRaw = (snap.data()?['status'] ?? '').toString();
    final current = currentRaw == 'driver_assigned' ? 'accepted' : currentRaw;

    const transitions = <String, List<String>>{
      'accepted': ['en_route'],
      'en_route': ['arrived'],
      'arrived': ['in_progress'],
      'in_progress': ['completed'],
    };

    final allowed = transitions[current] ?? const <String>[];
    if (!allowed.contains(status)) {
      throw Exception('Invalid status transition: $current -> $status');
    }

    await ref.set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'in_progress')
        'actualStartAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _completeTripWithOvertime(
    DocumentReference<Map<String, dynamic>> ref, {
    required int graceMinutes,
    required double ratePerMinute,
  }) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Booking not found');

      final d = snap.data() as Map<String, dynamic>;
      final currentRaw = (d['status'] ?? '').toString();
      final current = currentRaw == 'driver_assigned' ? 'accepted' : currentRaw;
      if (current != 'in_progress') {
        throw Exception('Trip can be completed only from in_progress');
      }

      final scheduledEndTs = d['scheduledEndAt'] as Timestamp?;
      final scheduledEnd = scheduledEndTs?.toDate();

      final actualEnd = DateTime.now();

      int overtimeMinutes = 0;
      double overtimeAmount = 0;

      if (scheduledEnd != null) {
        final diffMinutes = actualEnd.difference(scheduledEnd).inMinutes;
        final billableMinutes = diffMinutes - graceMinutes;
        if (billableMinutes > 0) {
          overtimeMinutes = billableMinutes;
          overtimeAmount = overtimeMinutes * ratePerMinute;
        }
      }

      tx.set(
          ref,
          {
            'status': 'completed',
            'actualEndAt': Timestamp.fromDate(actualEnd),
            'overtime': {
              'graceMinutes': graceMinutes,
              'ratePerMinute': ratePerMinute,
              'minutes': overtimeMinutes,
              'amount': overtimeAmount,
              'computedAt': FieldValue.serverTimestamp(),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(firestoreProvider);
    final refDoc = db.collection('bookings').doc(bookingId);
    final bookingPrivateRef = db.collection('bookings_private').doc(bookingId);
    final settingsRef = db.collection('admin_settings').doc('app');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/driver');
            }
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Trip'),
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: settingsRef.snapshots(),
          builder: (context, settingsSnap) {
            final settings = settingsSnap.data?.data() ?? {};
            final grace = (settings['overtimeGraceMinutes'] as num?)?.toInt() ??
                graceMinutes;
            final rate =
                (settings['overtimeRatePerMinute'] as num?)?.toDouble() ??
                    overtimeRatePerMinute;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: refDoc.snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error:\n${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.data!.exists) {
                  return const Center(child: Text('Trip not found'));
                }

                final d = snap.data!.data()!;
                final rawStatus = (d['status'] ?? 'unknown').toString();
                final status =
                    rawStatus == 'driver_assigned' ? 'accepted' : rawStatus;
                final c = _statusColor(status);

                final assigned = (d['assigned'] as Map<String, dynamic>?) ?? {};
                final assignedDriverId =
                    (assigned['driverId'] ?? '').toString();

                final scheduledEndTs = d['scheduledEndAt'] as Timestamp?;
                final scheduledEnd = scheduledEndTs?.toDate();

                final overtime = d['overtime'] as Map<String, dynamic>?;
                final overtimeMinutes = overtime?['minutes'] ?? 0;
                final overtimeAmount = overtime?['amount'] ?? 0;

                final steps = const [
                  'accepted',
                  'en_route',
                  'arrived',
                  'in_progress',
                  'completed'
                ];
                final currentIndex =
                    steps.indexOf(status).clamp(0, steps.length - 1);

                final disabled = status == 'completed' || status == 'cancelled';

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      // Header card
                      Container(
                        decoration: BoxDecoration(
                          color: PFColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PFColors.border),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 420;
                            final statusRow = Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                      color: c, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Status: $status',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16),
                                  ),
                                ),
                              ],
                            );

                            final idText = Text(
                              bookingId.substring(0, 8),
                              style: const TextStyle(
                                  color: PFColors.muted,
                                  fontWeight: FontWeight.w700),
                            );

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  statusRow,
                                  const SizedBox(height: 8),
                                  idText,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: statusRow),
                                idText,
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Stepper
                      _StepperRow(currentIndex: currentIndex),

                      const SizedBox(height: 14),

                      Container(
                        decoration: BoxDecoration(
                          color: PFColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PFColors.border),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Live Trip Map',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 10),
                            StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>>(
                              stream: bookingPrivateRef.snapshots(),
                              builder: (context, ps) {
                                final p = ps.data?.data() ?? {};
                                GeoPoint? pickupGeo;
                                GeoPoint? dropoffGeo;

                                final pickupRaw = p['pickupGeo'];
                                final dropoffRaw = p['dropoffGeo'];

                                if (pickupRaw is GeoPoint) {
                                  pickupGeo = pickupRaw;
                                }
                                if (dropoffRaw is GeoPoint) {
                                  dropoffGeo = dropoffRaw;
                                }

                                pickupGeo ??= (() {
                                  final lat =
                                      (d['pickupLat'] as num?)?.toDouble();
                                  final lng =
                                      (d['pickupLng'] as num?)?.toDouble();
                                  if (lat == null || lng == null) return null;
                                  return GeoPoint(lat, lng);
                                })();

                                dropoffGeo ??= (() {
                                  final lat =
                                      (d['dropoffLat'] as num?)?.toDouble();
                                  final lng =
                                      (d['dropoffLng'] as num?)?.toDouble();
                                  if (lat == null || lng == null) return null;
                                  return GeoPoint(lat, lng);
                                })();

                                final fallbackLoc = (assigned['driverLocation']
                                    as Map<String, dynamic>?);
                                final fallbackLat =
                                    (fallbackLoc?['lat'] as num?)?.toDouble();
                                final fallbackLng =
                                    (fallbackLoc?['lng'] as num?)?.toDouble();

                                final effectiveDriverId =
                                    assignedDriverId.isEmpty
                                        ? null
                                        : assignedDriverId;

                                return PFUberLiveMap(
                                  driverId: effectiveDriverId,
                                  initialDriverLatLng: !kIsWeb &&
                                          fallbackLat != null &&
                                          fallbackLng != null
                                      ? LatLng(fallbackLat, fallbackLng)
                                      : null,
                                  pickupGeo: pickupGeo,
                                  dropoffGeo: dropoffGeo,
                                  height: 220,
                                  bookingStatus: status,
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      if (scheduledEnd != null)
                        Container(
                          decoration: BoxDecoration(
                            color: PFColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: PFColors.border),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Scheduled end: ${formatDateTime(scheduledEnd)}',
                            style: const TextStyle(
                                color: PFColors.muted,
                                fontWeight: FontWeight.w600),
                          ),
                        ),

                      const SizedBox(height: 14),

                      // ── Responsive status buttons ─────────────────────────
                      LayoutBuilder(
                        builder: (context, bc) {
                          // On narrow screens: 2 buttons per row, each half-width.
                          // On wide screens: intrinsic width (all on one row).
                          final isNarrow = bc.maxWidth < 480;
                          final btnWidth = isNarrow
                              ? (bc.maxWidth / 2 - 7).clamp(110.0, 240.0)
                              : null;

                          Widget aBtn(
                            String label,
                            bool enabled,
                            bool primary,
                            VoidCallback onPressed,
                          ) {
                            final btn = _ActionButton(
                              label: label,
                              enabled: enabled,
                              primary: primary,
                              onPressed: onPressed,
                            );
                            return btnWidth == null
                                ? btn
                                : SizedBox(width: btnWidth, child: btn);
                          }

                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              aBtn(
                                'En Route',
                                !disabled && status == 'accepted',
                                false,
                                () async {
                                  try {
                                    await _setStatus(refDoc, 'en_route');
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                              SnackBar(content: Text('$e')));
                                    }
                                  }
                                },
                              ),
                              aBtn(
                                'Arrived',
                                !disabled && status == 'en_route',
                                false,
                                () async {
                                  try {
                                    await _setStatus(refDoc, 'arrived');
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                              SnackBar(content: Text('$e')));
                                    }
                                  }
                                },
                              ),
                              aBtn(
                                'Start Trip',
                                !disabled && status == 'arrived',
                                false,
                                () async {
                                  try {
                                    await _setStatus(refDoc, 'in_progress');
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                              SnackBar(content: Text('$e')));
                                    }
                                  }
                                },
                              ),
                              aBtn(
                                'Complete',
                                !disabled && status == 'in_progress',
                                true,
                                () => _completeTripWithOvertime(
                                  refDoc,
                                  graceMinutes: grace,
                                  ratePerMinute: rate,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      _InspectionSection(bookingId: bookingId),

                      const SizedBox(height: 16),

                      _AdjustmentsForm(bookingId: bookingId, role: 'driver'),

                      const SizedBox(height: 16),

                      if (status == 'completed')
                        Container(
                          decoration: BoxDecoration(
                            color: PFColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: PFColors.border),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Completion Summary',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 10),
                              Text('Overtime minutes: $overtimeMinutes'),
                              Text(
                                  'Overtime amount: \$${overtimeAmount.toString()}'),
                              const SizedBox(height: 8),
                              Text(
                                'Policy: $grace min grace, then \$${rate.toStringAsFixed(2)}/min.',
                                style: const TextStyle(
                                    color: PFColors.muted,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          buildStamp,
                          style: TextStyle(
                            color: PFColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final int currentIndex;
  const _StepperRow({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final labels = const ['Assigned', 'En Route', 'Arrived', 'In Trip', 'Done'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PFColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PFColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;

          final steps = List.generate(labels.length, (i) {
            final done = i <= currentIndex;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: done
                    ? PFColors.success.withValues(alpha: 0.14)
                    : PFColors.primarySoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: PFColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: done
                          ? PFColors.success
                          : PFColors.muted.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: done ? PFColors.ink : PFColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          });

          if (isNarrow) {
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: steps,
            );
          }

          return Row(
            children: List.generate(labels.length, (i) {
              final done = i <= currentIndex;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: done
                            ? PFColors.success
                            : PFColors.muted.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        labels[i],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: done ? PFColors.ink : PFColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (i != labels.length - 1)
                      Container(width: 14, height: 1, color: PFColors.border),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool primary;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Text(
      label,
      textAlign: TextAlign.center,
      softWrap: true,
      style: const TextStyle(fontWeight: FontWeight.w800),
    );

    if (primary) {
      return ElevatedButton(
        onPressed: enabled ? onPressed : null,
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      child: child,
    );
  }
}

class _InspectionSection extends StatelessWidget {
  final String bookingId;
  const _InspectionSection({required this.bookingId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InspectionStageCard(
          stage: 'pre',
          title: 'Pre-Trip Walk-Around',
          bookingId: bookingId,
        ),
        const SizedBox(height: 12),
        _InspectionStageCard(
          stage: 'post',
          title: 'Post-Trip Walk-Around',
          bookingId: bookingId,
        ),
      ],
    );
  }
}

class _InspectionItem {
  final String key;
  final String label;
  const _InspectionItem(this.key, this.label);
}

const List<_InspectionItem> _inspectionItems = [
  _InspectionItem('front_bumper', 'Front bumper'),
  _InspectionItem('rear_bumper', 'Rear bumper'),
  _InspectionItem('left_side', 'Left side'),
  _InspectionItem('right_side', 'Right side'),
  _InspectionItem('windshield', 'Windshield'),
  _InspectionItem('windows', 'Windows'),
  _InspectionItem('wheels_tires', 'Wheels & tires'),
  _InspectionItem('lights', 'Lights & signals'),
  _InspectionItem('interior', 'Interior condition'),
  _InspectionItem('trunk', 'Trunk/Storage'),
  _InspectionItem('fuel_level', 'Fuel level'),
  _InspectionItem('odometer', 'Odometer photo'),
  _InspectionItem('cleanliness', 'Cleanliness'),
];

class _InspectionStageCard extends ConsumerStatefulWidget {
  final String bookingId;
  final String stage;
  final String title;

  const _InspectionStageCard({
    required this.bookingId,
    required this.stage,
    required this.title,
  });

  @override
  ConsumerState<_InspectionStageCard> createState() =>
      _InspectionStageCardState();
}

class _WebUploadPayload {
  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final int originalSize;
  final int compressedSize;

  const _WebUploadPayload({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.originalSize,
    required this.compressedSize,
  });
}

class _InspectionStageCardState extends ConsumerState<_InspectionStageCard> {
  final TextEditingController _notesCtrl = TextEditingController();
  final Map<String, bool> _checks = {
    for (final item in _inspectionItems) item.key: false
  };
  final MediaCaptureService _mediaCapture = MediaCaptureService();
  final WebCameraCaptureService _webCameraCaptureService =
      WebCameraCaptureService();
  final ImageCompressService _imageCompressService = ImageCompressService();
  final StorageUploadService _uploadService = StorageUploadService();
  bool _initialized = false;
  bool _saving = false;
  int _uploadingOps = 0;
  bool _sending = false;
  bool _notesSaved = false;
  final List<Map<String, dynamic>> _localUploads = [];
  double? _uploadProgress;
  String? _uploadStatusText;
  String? _uploadError;
  CapturedMedia? _lastFailedMedia;
  String? _lastFailedType;
  _WebUploadPayload? _lastFailedWebPayload;
  int _webNullCaptureCount = 0;
  StreamSubscription<UploadProgress>? _uploadSub;

  bool get _uploading => _uploadingOps > 0;

  void _beginUpload() {
    if (!mounted) return;
    setState(() => _uploadingOps += 1);
  }

  void _endUpload() {
    if (!mounted) return;
    setState(() {
      _uploadingOps = (_uploadingOps - 1).clamp(0, 1 << 30);
    });
  }

  DocumentReference<Map<String, dynamic>> _doc(FirebaseFirestore db) {
    return db
        .collection('bookings')
        .doc(widget.bookingId)
        .collection('driver_inspections')
        .doc(widget.stage);
  }

  String _contentTypeFor(CapturedMedia media, String type) {
    final provided = media.contentType;
    if (provided != null && provided.isNotEmpty) return provided;

    if (type == 'photo') {
      switch (media.extension) {
        case 'png':
          return 'image/png';
        case 'webp':
          return 'image/webp';
        case 'heic':
          return 'image/heic';
        default:
          return 'image/jpeg';
      }
    }

    switch (media.extension) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      default:
        return 'video/mp4';
    }
  }

  @override
  void dispose() {
    _uploadSub?.cancel();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> data) {
    if (_initialized) return;
    _initialized = true;
    final notes = (data['notes'] ?? '').toString();
    final checklist = (data['checklist'] as Map<String, dynamic>?) ?? {};
    _notesCtrl.text = notes;
    for (final item in _inspectionItems) {
      _checks[item.key] = checklist[item.key] == true;
    }
    // If this stage was previously saved, enable Send without requiring a re-save.
    if (data['updatedAt'] != null || notes.isNotEmpty) {
      _notesSaved = true;
    }
  }

  /// POSTs notes + checklist to [saveInspectionHttp] server-side.
  /// On web this avoids all Firestore Web SDK crashes.
  Future<void> _postSaveInspection({bool sentToDispatcher = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('unauthenticated');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) throw Exception('unauthenticated');

    final response = await http.post(
      Uri.parse(kSaveInspectionEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'bookingId': widget.bookingId,
        'stage': widget.stage,
        'notes': _notesCtrl.text.trim(),
        'checklist': _checks,
        if (sentToDispatcher) 'sentToDispatcher': true,
      }),
    );
    final decoded = jsonDecode(response.body);
    final data = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    if (response.statusCode != 200 || data['ok'] != true) {
      throw Exception(
          data['error']?.toString() ?? 'save-failed (${response.statusCode})');
    }
  }

  Future<void> _save(FirebaseFirestore db, String? driverId) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (kIsWeb) {
        await _postSaveInspection();
      } else {
        final doc = _doc(db);
        final snap = await doc.get();
        final data = {
          'stage': widget.stage,
          if (driverId != null) 'driverId': driverId,
          'notes': _notesCtrl.text.trim(),
          'checklist': _checks,
          'updatedAt': FieldValue.serverTimestamp(),
          if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
        };
        await doc.set(data, SetOptions(merge: true));
      }
      if (mounted) {
        setState(() => _notesSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Saved ✅'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _startUpload(
    FirebaseFirestore db,
    String? driverId, {
    required CapturedMedia media,
    required String type,
  }) async {
    _beginUpload();
    _uploadSub?.cancel();

    if (!mounted) return;
    setState(() {
      _uploadProgress = 0;
      _uploadStatusText = 'Uploading…';
      _uploadError = null;
      _lastFailedMedia = null;
      _lastFailedType = null;
    });

    final stream = _uploadService.uploadInspectionMedia(
      db: db,
      bookingId: widget.bookingId,
      stage: widget.stage,
      type: type,
      bytes: media.bytes,
      fileName: media.name,
      contentType: _contentTypeFor(media, type),
      extension: media.extension,
      driverId: driverId,
    );

    _uploadSub = stream.listen((event) {
      if (!mounted) return;
      setState(() {
        _uploadProgress = event.progress;
        if (event.status == UploadStatus.completed && event.result != null) {
          _uploadStatusText = 'Uploaded';
          _uploadError = null;
          _localUploads.insert(0, event.result!.toInspectionUploadMap());
          final label = type == 'video' ? 'Video' : 'Photo';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$label uploaded ✅'),
                duration: const Duration(seconds: 2),
              ),
            );
          });
        } else if (event.status == UploadStatus.failed) {
          _uploadStatusText = 'Upload failed';
          _uploadError = event.error ?? 'Upload failed. Please try again.';
          _lastFailedMedia = media;
          _lastFailedType = type;

          final msg = event.error ?? 'Upload failed. Please try again.';
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(msg)));
          });
        }
      });

      if (event.status != UploadStatus.uploading) {
        _endUpload();
      }
    });
  }

  Future<void> _retryLastUpload(FirebaseFirestore db, String? driverId) async {
    if (kIsWeb && _lastFailedWebPayload != null) {
      await _uploadWebImage(db, driverId, payload: _lastFailedWebPayload!);
      return;
    }

    final media = _lastFailedMedia;
    final type = _lastFailedType;
    if (media == null || type == null) return;
    await _startUpload(db, driverId, media: media, type: type);
  }

  Future<void> _showErrorDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCaptureDiagnostics(WebCaptureDiagnostics diagnostics) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Capture diagnostics:\n${diagnostics.toHumanText()}')),
    );
  }

  Future<void> _uploadWebImage(
    FirebaseFirestore db,
    String? driverId, {
    required _WebUploadPayload payload,
  }) async {
    _beginUpload();
    if (!mounted) return;
    setState(() {
      _uploadProgress = null;
      _uploadStatusText = 'Uploading…';
      _uploadError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('unauthenticated');
      }
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        throw Exception('unauthenticated');
      }

      const url = kDriverUploadImageEndpoint;
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'bookingId': widget.bookingId,
          'stage': widget.stage,
          'fileName': payload.fileName,
          'contentType': payload.contentType,
          'base64': base64Encode(payload.bytes),
        }),
      );

      final decoded = jsonDecode(response.body);
      final data = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      if (response.statusCode != 200) {
        throw Exception(data['error']?.toString() ?? response.body);
      }
      if (data['ok'] != true) {
        throw Exception(data['error']?.toString() ?? 'upload-failed');
      }

      final downloadUrl = (data['downloadUrl'] ?? '').toString();
      final storagePath = (data['storagePath'] ?? '').toString();
      final sizeBytes =
          (data['sizeBytes'] as num?)?.toInt() ?? payload.bytes.lengthInBytes;

      if (downloadUrl.isEmpty || storagePath.isEmpty) {
        throw Exception(
            'uploadInspectionImageHttp returned invalid payload: $data');
      }

      // Build local-only upload map for immediate UI update.
      // Use ISO string for uploadedAt — NOT Timestamp.now() — to avoid
      // passing Timestamp inside FieldValue.arrayUnion which crashes the
      // Firestore Web SDK (INTERNAL ASSERTION FAILED: Unexpected state).
      // The server has already written the Firestore records.
      final uploadMap = {
        'url': downloadUrl,
        'name': payload.fileName,
        'contentType': payload.contentType,
        'path': storagePath,
        'uploadedAt': DateTime.now().toIso8601String(),
        'type': 'image',
        'stage': widget.stage,
        'sizeBytes': sizeBytes,
      };

      // DO NOT write to Firestore from web — the Cloud Function already wrote:
      //   bookings/{bookingId}/inspectionMedia/{mediaId}
      //   bookings/{bookingId}/driver_inspections/{stage}.uploads
      // Writing from the client would re-crash the web SDK.

      if (!mounted) return;
      setState(() {
        _uploadStatusText = 'Uploaded';
        _uploadError = null;
        _uploadProgress = 1;
        _lastFailedWebPayload = null;
        _localUploads.insert(0, uploadMap);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo uploaded ✅'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      final message = 'Upload failed: ${e.toString()}';
      if (mounted) {
        setState(() {
          _uploadStatusText = 'Upload failed';
          _uploadError = message;
          _lastFailedWebPayload = payload;
        });
      }
      await _showErrorDialog('Upload failed', message);
    } finally {
      _endUpload();
    }
  }

  Future<void> _takePictureWeb(FirebaseFirestore db, String? driverId) async {
    final preferCamera = _webNullCaptureCount < 2;
    final capture =
        await _webCameraCaptureService.capturePhoto(preferCamera: preferCamera);

    if (capture == null) {
      if (kDebugUploads && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Capture cancelled (Safari returned no file)')),
        );
      }
      return;
    }

    if (kDebugUploads) _showCaptureDiagnostics(capture.diagnostics);

    final image = capture.image;
    if (image == null || image.bytes.isEmpty) {
      _webNullCaptureCount += 1;
      if (kDebugUploads && mounted) {
        final msg = _webNullCaptureCount >= 2
            ? 'Capture cancelled (Safari returned no file). Falling back to photo library chooser.'
            : 'Capture cancelled (Safari returned no file).';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
      return;
    }

    _webNullCaptureCount = 0;

    final compressed = _imageCompressService.compressForCallable(image.bytes);
    if (kDebugUploads && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Image compressed: original=${compressed.originalSize} bytes, compressed=${compressed.compressedSize} bytes',
          ),
        ),
      );
    }

    final payload = _WebUploadPayload(
      bytes: compressed.bytes,
      fileName: image.fileName,
      contentType: 'image/jpeg',
      originalSize: compressed.originalSize,
      compressedSize: compressed.compressedSize,
    );

    await _uploadWebImage(db, driverId, payload: payload);
  }

  Future<void> _runWebCallableTestCall() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('unauthenticated');
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) throw Exception('unauthenticated');

      const url = kDriverUploadImageEndpoint;
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'bookingId': widget.bookingId,
          'stage': widget.stage,
          'fileName': 'probe.jpg',
          'contentType': 'image/jpeg',
          'base64': 'AA==',
        }),
      );

      await _showErrorDialog('Test call result', response.body);
    } catch (e) {
      await _showErrorDialog('Test call result', e.toString());
    }
  }

  Future<void> _takePicture(FirebaseFirestore db, String? driverId) async {
    if (kIsWeb) {
      await _takePictureWeb(db, driverId);
      return;
    }

    try {
      final media = await _mediaCapture.captureImage();
      if (media == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No image selected.'),
            ),
          );
        }
        return;
      }

      // Callable payloads are small on web; keep conservative for Safari reliability.
      final maxImageBytes = kIsWeb
          ? 5 * 1024 * 1024 // 5 MB (base64 expands payload)
          : 50 * 1024 * 1024; // 50 MB native
      if (media.sizeBytes > maxImageBytes) {
        throw Exception(
            'Image too large. Max ${kIsWeb ? '5MB (web)' : '50MB'}.');
      }

      await _startUpload(db, driverId, media: media, type: 'photo');
    } catch (e, st) {
      final err = e is FirebaseException
          ? '${e.code}${(e.message ?? '').isEmpty ? '' : ': ${e.message}'}'
          : e.toString();
      // ignore: avoid_print
      print('Camera upload failed: $err');
      // ignore: avoid_print
      print(st.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera upload failed: $err')),
        );
      }
    }
  }

  Future<void> _recordVideo(FirebaseFirestore db, String? driverId) async {
    try {
      final media = await _mediaCapture.captureVideo();
      if (media == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No video selected.'),
            ),
          );
        }
        return;
      }

      // Guard very large videos that can appear as "stuck" on mobile web.
      const maxVideoBytes = 300 * 1024 * 1024; // 300 MB
      if (media.sizeBytes > maxVideoBytes) {
        throw Exception('Video too large. Max 300MB.');
      }

      await _startUpload(db, driverId, media: media, type: 'video');
    } catch (e, st) {
      final err = e is FirebaseException
          ? '${e.code}${(e.message ?? '').isEmpty ? '' : ': ${e.message}'}'
          : e.toString();
      // ignore: avoid_print
      print('Video upload failed: $err');
      // ignore: avoid_print
      print(st.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video upload failed: $err')),
        );
      }
    }
  }

  Future<void> _sendToDispatcher(FirebaseFirestore db, String? driverId) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      if (kIsWeb) {
        // On web: route through HTTP to avoid Firestore Web SDK crashes.
        // saveInspectionHttp writes notes + checklist + sentToDispatcher to
        // both driver_inspections/{stage} and bookings/{bookingId}.
        await _postSaveInspection(sentToDispatcher: true);
      } else {
        final doc = _doc(db);
        final snap = await doc.get();
        if (!snap.exists) {
          await doc.set({
            'stage': widget.stage,
            if (driverId != null) 'driverId': driverId,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await doc.set({
          'notes': _notesCtrl.text.trim(),
          'checklist': _checks,
          'sentToDispatcher': true,
          'sentToDispatcherAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await db.collection('bookings').doc(widget.bookingId).set({
          'inspection': {
            widget.stage: {
              'submitted': true,
              'submittedAt': FieldValue.serverTimestamp(),
              if (driverId != null) 'submittedBy': driverId,
              'notes': _notesCtrl.text.trim(),
            },
          },
        }, SetOptions(merge: true));
      }

      // Notify dispatchers (non-fatal on all platforms).
      try {
        final fn =
            FirebaseFunctions.instance.httpsCallable('notifyDispatchers');
        await fn.call({
          'bookingId': widget.bookingId,
          'stage': widget.stage,
        });
      } catch (_) {
        // ignore notification failures
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sent to dispatcher ✅'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(firestoreProvider);
    final auth = ref.watch(firebaseAuthProvider);
    final driverId = auth.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _doc(db).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        if (!_initialized && snap.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _hydrate(data));
          });
        }

        final remoteUploads = ((data['uploads'] as List?) ?? [])
            .whereType<Map>()
            .map((u) => Map<String, dynamic>.from(u))
            .toList();

        final seen = <String>{};
        final uploads = <Map<String, dynamic>>[];
        for (final u in [..._localUploads, ...remoteUploads]) {
          final key = (u['path'] ?? u['url'] ?? u['name'] ?? '').toString();
          if (key.isEmpty || seen.contains(key)) continue;
          seen.add(key);
          uploads.add(u);
        }

        final sentToDispatcher = data['sentToDispatcher'] == true;

        final checklistOk = _checks.values.every((v) => v);
        final uploadsOk = uploads.isNotEmpty &&
            uploads.every((u) =>
                (u['url'] ?? u['downloadUrl'] ?? '').toString().isNotEmpty);
        final canSend = !_sending &&
            !sentToDispatcher &&
            checklistOk &&
            _notesSaved &&
            uploadsOk;

        return Container(
          decoration: BoxDecoration(
            color: PFColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PFColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  if (_saving || _uploading || _sending)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator()),
                ],
              ),
              if (_uploading && _uploadProgress != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 4),
                Text(
                  'Uploading… ${((_uploadProgress ?? 0) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: PFColors.muted),
                ),
              ],
              if (_uploadStatusText != null) ...[
                const SizedBox(height: 6),
                Text(
                  _uploadStatusText!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _uploadError == null
                        ? PFColors.success
                        : PFColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_uploadError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _uploadError!,
                  style: const TextStyle(fontSize: 12, color: PFColors.danger),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed:
                      _uploading ? null : () => _retryLastUpload(db, driverId),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry upload'),
                ),
              ],
              const SizedBox(height: 10),
              const Text('Checklist',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ..._inspectionItems.map((item) {
                final v = _checks[item.key] ?? false;
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: v,
                  onChanged: (val) =>
                      setState(() => _checks[item.key] = val ?? false),
                  title: Text(item.label),
                );
              }),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Notes / walk-around notes'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : () => _save(db, driverId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PFColors.primary,
                    foregroundColor: PFColors.white,
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sending || _uploading
                          ? null
                          : () => _takePicture(db, driverId),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Picture'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _sending || _uploading
                          ? null
                          : () => _recordVideo(db, driverId),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Record Video'),
                    ),
                  ),
                ],
              ),
              if (kDebugMode && kIsWeb) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _uploading ? null : _runWebCallableTestCall,
                    icon: const Icon(Icons.science_outlined),
                    label:
                        const Text('TEST CALL: uploadInspectionImage (AA==)'),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final resp =
                            await http.get(Uri.parse(kDriverPingEndpoint));
                        await _showErrorDialog(
                            'PING result (${resp.statusCode})', resp.body);
                      } catch (e) {
                        await _showErrorDialog('PING error', e.toString());
                      }
                    },
                    icon: const Icon(Icons.network_ping),
                    label: Text('PING: $kDriverPingEndpoint'),
                  ),
                ),
              ],
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Send requirements:',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 11)),
                      Text(
                        'checklistComplete: $checklistOk',
                        style: TextStyle(
                            fontSize: 11,
                            color: checklistOk ? Colors.green : Colors.red),
                      ),
                      Text(
                        'notesSaved: $_notesSaved',
                        style: TextStyle(
                            fontSize: 11,
                            color: _notesSaved ? Colors.green : Colors.red),
                      ),
                      Text(
                        'uploadsCount: ${uploads.length} (need ≥ 1)',
                        style: TextStyle(
                            fontSize: 11,
                            color: uploadsOk ? Colors.green : Colors.red),
                      ),
                      Text('alreadySent: $sentToDispatcher',
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
              // ── Always-visible send requirements panel ───────────────────
              if (!sentToDispatcher) ...[
                const SizedBox(height: 8),
                _SendRequirementsPanel(
                  checklistOk: checklistOk,
                  notesSaved: _notesSaved,
                  uploadsOk: uploadsOk,
                  uploadsCount: uploads.length,
                ),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      canSend ? () => _sendToDispatcher(db, driverId) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PFColors.primary,
                    foregroundColor: PFColors.white,
                  ),
                  icon: const Icon(Icons.send),
                  label:
                      Text(sentToDispatcher ? 'Sent ✅' : 'Send to Dispatcher'),
                ),
              ),
              if (uploads.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Uploads',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ...uploads.map((u) {
                  final name = (u['name'] ?? 'Photo').toString();
                  final url = (u['url'] ?? '').toString();
                  final contentType = (u['contentType'] ?? '').toString();
                  final sizeBytes = (u['sizeBytes'] as num?)?.toInt() ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _UploadPreviewCard(
                      name: name,
                      url: url,
                      contentType: contentType,
                      sizeBytes: sizeBytes,
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Send requirements panel ──────────────────────────────────────────────────
class _SendRequirementsPanel extends StatelessWidget {
  final bool checklistOk;
  final bool notesSaved;
  final bool uploadsOk;
  final int uploadsCount;

  const _SendRequirementsPanel({
    required this.checklistOk,
    required this.notesSaved,
    required this.uploadsOk,
    required this.uploadsCount,
  });

  @override
  Widget build(BuildContext context) {
    if (checklistOk && notesSaved && uploadsOk) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PFColors.warning.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PFColors.warning.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Required before sending:',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: PFColors.inkSoft),
          ),
          const SizedBox(height: 4),
          _Req(label: 'All checklist items checked', met: checklistOk),
          _Req(label: 'Notes saved (tap Save ↑)', met: notesSaved),
          _Req(
            label: 'Upload ≥ 1 photo or video ($uploadsCount uploaded)',
            met: uploadsOk,
          ),
        ],
      ),
    );
  }
}

class _Req extends StatelessWidget {
  final String label;
  final bool met;
  const _Req({required this.label, required this.met});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(
            met
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: met ? PFColors.success : PFColors.danger,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: met ? PFColors.success : PFColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadPreviewCard extends StatefulWidget {
  final String name;
  final String url;
  final String contentType;
  final int sizeBytes;

  const _UploadPreviewCard({
    required this.name,
    required this.url,
    required this.contentType,
    this.sizeBytes = 0,
  });

  @override
  State<_UploadPreviewCard> createState() => _UploadPreviewCardState();
}

class _UploadPreviewCardState extends State<_UploadPreviewCard> {
  VideoPlayerController? _video;
  bool _videoReady = false;

  bool get _isImage {
    if (widget.contentType.startsWith('image/')) return true;
    final lower = '${widget.name} ${widget.url}'.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.gif') ||
        lower.contains('.heic');
  }

  bool get _isVideo {
    if (widget.contentType.startsWith('video/')) return true;
    final lower = '${widget.name} ${widget.url}'.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.webm') ||
        lower.contains('.m4v');
  }

  // On web (especially iOS Safari) VideoPlayer stalls or spins.
  // Use a link-based preview instead.
  bool get _useInlinePlayer => !kIsWeb;

  String get _sizeLabel {
    final b = widget.sizeBytes;
    if (b <= 0) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo && widget.url.isNotEmpty && _useInlinePlayer) {
      _video = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (!mounted) return;
          setState(() => _videoReady = true);
        });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PFColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PFColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.name,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (_sizeLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(_sizeLabel,
                style: const TextStyle(fontSize: 11, color: PFColors.muted)),
          ],
          const SizedBox(height: 8),
          if (widget.url.isEmpty)
            const Text('File unavailable',
                style: TextStyle(color: PFColors.muted, fontSize: 12))
          else if (_isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                widget.url,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Unable to preview image'),
                ),
              ),
            )
          else if (_isVideo && !_useInlinePlayer)
            // Web / iOS Safari: show open/download links instead of inline player.
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed:
                      widget.url.isNotEmpty ? () => openUrl(widget.url) : null,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open video'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed:
                      widget.url.isNotEmpty ? () => openUrl(widget.url) : null,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download'),
                ),
              ],
            )
          else if (_isVideo && _useInlinePlayer)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 210,
                width: double.infinity,
                child: _videoReady && _video != null
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: _video!.value.aspectRatio <= 0
                                ? 16 / 9
                                : _video!.value.aspectRatio,
                            child: VideoPlayer(_video!),
                          ),
                          IconButton.filled(
                            onPressed: () {
                              if (_video == null) return;
                              if (_video!.value.isPlaying) {
                                _video!.pause();
                              } else {
                                _video!.play();
                              }
                              setState(() {});
                            },
                            icon: Icon(_video!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow),
                          ),
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            )
          else
            const Text(
              'Preview not available for this file type.',
              style: TextStyle(color: PFColors.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

// ── Staff Adjustments / Surcharges panel ─────────────────────────────────────
class _AdjustmentsForm extends StatefulWidget {
  final String bookingId;
  final String role;
  const _AdjustmentsForm({required this.bookingId, required this.role});

  @override
  State<_AdjustmentsForm> createState() => _AdjustmentsFormState();
}

class _AdjustmentsFormState extends State<_AdjustmentsForm> {
  final _fuelCtrl = TextEditingController();
  final _parkingCtrl = TextEditingController();
  final _tollsCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  bool _hydrated = false;

  @override
  void dispose() {
    _fuelCtrl.dispose();
    _parkingCtrl.dispose();
    _tollsCtrl.dispose();
    _venueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> adj) {
    if (_hydrated) return;
    _hydrated = true;
    _fuelCtrl.text = ((adj['fuelSurchargePct'] as num?)?.toDouble() ?? 0.0)
        .toStringAsFixed(1);
    _parkingCtrl.text = (((adj['parkingCents'] as num?)?.toInt() ?? 0) / 100)
        .toStringAsFixed(2);
    _tollsCtrl.text =
        (((adj['tollsCents'] as num?)?.toInt() ?? 0) / 100).toStringAsFixed(2);
    _venueCtrl.text =
        (((adj['venueCents'] as num?)?.toInt() ?? 0) / 100).toStringAsFixed(2);
    _notesCtrl.text = (adj['notes'] ?? '').toString();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final fuelPct = double.tryParse(_fuelCtrl.text.trim()) ?? 0.0;
      final parkingCents =
          ((double.tryParse(_parkingCtrl.text.trim()) ?? 0.0) * 100).round();
      final tollsCents =
          ((double.tryParse(_tollsCtrl.text.trim()) ?? 0.0) * 100).round();
      final venueCents =
          ((double.tryParse(_venueCtrl.text.trim()) ?? 0.0) * 100).round();
      await FirebaseFirestore.instance
          .collection('bookings_private')
          .doc(widget.bookingId)
          .set({
        'adjustments': {
          'fuelSurchargePct': fuelPct,
          'parkingCents': parkingCents,
          'tollsCents': tollsCents,
          'venueCents': venueCents,
          'notes': _notesCtrl.text.trim(),
          'addedByRole': widget.role,
          'addedByUid': uid,
          'addedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Adjustments saved ✅'),
              duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings_private')
          .doc(widget.bookingId)
          .snapshots(),
      builder: (context, snap) {
        final adj = ((snap.data?.data() ?? {})['adjustments']
                as Map<String, dynamic>?) ??
            {};
        if (!_hydrated && adj.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hydrate(adj));
          });
        }
        final byRole = (adj['addedByRole'] ?? '').toString();
        return Container(
          decoration: BoxDecoration(
            color: PFColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PFColors.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Adjustments / Surcharges',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 2),
              const Text('Staff only — saved to bookings_private',
                  style: TextStyle(color: PFColors.muted, fontSize: 12)),
              if (byRole.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Last saved by: $byRole',
                    style: const TextStyle(color: PFColors.muted, fontSize: 11))
              ],
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _fuelCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Fuel Surcharge %', hintText: '0.0'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _parkingCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Parking (\$)', hintText: '0.00'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _tollsCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Tolls (\$)', hintText: '0.00'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _venueCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Venue/Staging (\$)', hintText: '0.00'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PFColors.primary,
                    foregroundColor: PFColors.white,
                  ),
                  icon: const Icon(Icons.save),
                  label: Text(_saving ? 'Saving…' : 'Save Adjustments'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
