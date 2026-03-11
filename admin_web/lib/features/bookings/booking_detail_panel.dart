import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// import 'package:google_maps_flutter/google_maps_flutter.dart'; // Removed unused import
import 'package:pf_ui/pf_ui.dart' show PFUberLiveMap;

import '../../providers/firebase_providers.dart';
import '../../shared/date_time_format.dart';
import '../../theme/pink_fleets_theme.dart';

class BookingDetailPanel extends ConsumerStatefulWidget {
  final String bookingId;
  final bool embedded;
  const BookingDetailPanel(
      {super.key, required this.bookingId, this.embedded = false});

  @override
  ConsumerState<BookingDetailPanel> createState() => _BookingDetailPanelState();
}

class _BookingDetailPanelState extends ConsumerState<BookingDetailPanel> {
  final noteCtrl = TextEditingController();
  String? selectedDriverId;
  String? selectedVehicleId;

  String _money(num? v) {
    if (v == null) return '--';
    return '\$${v.toStringAsFixed(2)}';
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _vehicleLabel(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty) return '—';
    final spaced = value.replaceAll('_', ' ').replaceAll('-', ' ');
    return spaced
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _notifyDriver({
    required String driverUid,
    required String bookingId,
    required String status,
  }) async {
    final fn = FirebaseFunctions.instance.httpsCallable('notifyDriver');
    await fn.call({
      'driverUid': driverUid,
      'title': 'New update • Pink Fleets',
      'body': 'Booking $bookingId • Status: $status',
      'data': {'bookingId': bookingId, 'status': status},
    });
  }

  Future<void> _notifyRider({
    required String riderUid,
    required String bookingId,
    required String status,
  }) async {
    final fn = FirebaseFunctions.instance.httpsCallable('notifyRider');
    await fn.call({
      'riderUid': riderUid,
      'title': 'Trip update • Pink Fleets',
      'body': 'Your booking $bookingId is now: $status',
      'data': {'bookingId': bookingId, 'status': status},
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(firestoreProvider);

    final bookingRef = db.collection('bookings').doc(widget.bookingId);
    final privateRef = db.collection('bookings_private').doc(widget.bookingId);

    final driversQ = db.collection('drivers').where('active', isEqualTo: true);
    final vehiclesQ =
        db.collection('vehicles').where('active', isEqualTo: true);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: bookingRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.data!.exists) {
          return const Center(child: Text('Booking not found.'));
        }

        final b = snap.data!.data()!;
        final status = (b['status'] ?? 'unknown').toString();
        final riderUid = (b['riderUid'] ?? '').toString();

        final rider = b['riderInfo'] as Map<String, dynamic>?;
        final riderName = (rider?['name'] ?? '').toString();
        final riderEmail = (rider?['email'] ?? '').toString();
        final riderPhone = (rider?['phone'] ?? '').toString();
        final riderDob = (rider?['dob'] ?? '').toString();
        final riderAddress = (rider?['address'] ?? '').toString();

        final assigned = b['assigned'] as Map<String, dynamic>?;
        final currentDriverId = _firstText([
          assigned?['driverId'],
          b['driverId'],
        ]);
        final currentVehicleId =
            (assigned?['vehicleId'] as String?)?.toString();
        final requestedVehicle = _vehicleLabel(_firstText([
          b['requestedVehicle'],
          b['requested_vehicle'],
          b['vehicle_type'],
          b['vehicleType'],
          b['selectedVehicle'],
          b['vehicle'],
        ]));

        selectedDriverId ??= currentDriverId;
        selectedVehicleId ??= currentVehicleId;

        final settingsRef = db.collection('admin_settings').doc('app');

        return ListView(
          shrinkWrap: widget.embedded,
          physics:
              widget.embedded ? const NeverScrollableScrollPhysics() : null,
          children: [
            _header(context,
                bookingId: widget.bookingId,
                status: status,
                riderName: riderName),
            const SizedBox(height: 12),
            _section(
              title: 'Rider',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (riderName.isNotEmpty) _kv('Name', riderName),
                  if (riderEmail.isNotEmpty) _kv('Email', riderEmail),
                  if (riderPhone.isNotEmpty) _kv('Phone', riderPhone),
                  if (riderDob.isNotEmpty) _kv('DOB', riderDob),
                  if (riderAddress.isNotEmpty) _kv('Address', riderAddress),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Dispatch',
              child: Column(
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: driversQ.snapshots(),
                    builder: (context, ds) {
                      if (!ds.hasData) return const LinearProgressIndicator();
                      final drivers = ds.data!.docs;

                      return DropdownButtonFormField<String?>(
                        initialValue: selectedDriverId,
                        decoration: const InputDecoration(labelText: 'Driver'),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null, child: Text('Unassigned')),
                          ...drivers.map((doc) {
                            final name =
                                (doc.data()['name'] ?? doc.id).toString();
                            return DropdownMenuItem<String?>(
                                value: doc.id, child: Text(name));
                          }),
                        ],
                        onChanged: (v) => setState(() => selectedDriverId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: vehiclesQ.snapshots(),
                    builder: (context, vs) {
                      if (!vs.hasData) return const LinearProgressIndicator();
                      final vehicles = vs.data!.docs;
                      final effectiveVehicleId =
                          selectedVehicleId ?? currentVehicleId;
                      final assignedVehicleName = effectiveVehicleId == null ||
                              effectiveVehicleId.isEmpty
                          ? 'Unassigned'
                          : vehicles
                                  .where((doc) => doc.id == effectiveVehicleId)
                                  .map((doc) =>
                                      (doc.data()['name'] ?? doc.id).toString())
                                  .cast<String?>()
                                  .firstWhere(
                                      (name) => name != null && name.isNotEmpty,
                                      orElse: () => effectiveVehicleId) ??
                              effectiveVehicleId;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kv('Requested Vehicle', requestedVehicle),
                          _kv('Assigned Vehicle', assignedVehicleName),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: selectedVehicleId,
                            decoration:
                                const InputDecoration(labelText: 'Vehicle'),
                            items: [
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('Unassigned')),
                              ...vehicles.map((doc) {
                                final name =
                                    (doc.data()['name'] ?? doc.id).toString();
                                return DropdownMenuItem<String?>(
                                    value: doc.id, child: Text(name));
                              }),
                            ],
                            onChanged: (v) =>
                                setState(() => selectedVehicleId = v),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await bookingRef.set({
                          'driverId': selectedDriverId,
                          'assigned': {
                            'driverId': selectedDriverId,
                            'vehicleId': selectedVehicleId,
                            'assignedAt': FieldValue.serverTimestamp(),
                          },
                          'status': 'driver_assigned',
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));

                        if (selectedDriverId != null &&
                            selectedDriverId!.isNotEmpty) {
                          await _notifyDriver(
                            driverUid: selectedDriverId!,
                            bookingId: widget.bookingId,
                            status: 'driver_assigned',
                          );
                        }

                        if (riderUid.isNotEmpty) {
                          await _notifyRider(
                            riderUid: riderUid,
                            bookingId: widget.bookingId,
                            status: 'driver_assigned',
                          );
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Assigned + notified')),
                          );
                        }
                      },
                      child: const Text('Assign + Notify'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Locations',
              subtitle: 'Pickup + dropoff addresses',
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: privateRef.snapshots(),
                builder: (context, ps) {
                  final p = ps.data?.data() ?? {};
                  final pickupAddress = (p['pickupAddress'] ?? '').toString();
                  final dropoffAddress = (p['dropoffAddress'] ?? '').toString();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('Pickup Address',
                          pickupAddress.isEmpty ? '—' : pickupAddress),
                      _kv('Dropoff Address',
                          dropoffAddress.isEmpty ? '—' : dropoffAddress),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Live Map',
              subtitle: 'Real-time driver location',
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: privateRef.snapshots(),
                builder: (context, ps) {
                  final p = ps.data?.data() ?? {};
                  final rawPickup = p['pickupGeo'];
                  final rawDropoff = p['dropoffGeo'];
                  final pickupGeo = rawPickup is GeoPoint ? rawPickup : null;
                  final dropoffGeo = rawDropoff is GeoPoint ? rawDropoff : null;
                  final driverId =
                      currentDriverId.isNotEmpty ? currentDriverId : null;
                  return PFUberLiveMap(
                    driverId: driverId,
                    pickupGeo: pickupGeo,
                    dropoffGeo: dropoffGeo,
                    height: 260,
                    bookingStatus: status,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Financial',
              subtitle: 'Admin only • bookings_private',
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: privateRef.snapshots(),
                builder: (context, ps) {
                  if (!ps.hasData) return const LinearProgressIndicator();
                  if (!ps.data!.exists) {
                    return const Text('No private financial record yet.');
                  }
                  final p = ps.data!.data()!;
                  final payStatus = (p['paymentStatus'] ?? '--').toString();
                  final snapMap = p['pricingSnapshot'] as Map<String, dynamic>?;
                  final total = snapMap?['total'];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('paymentStatus', payStatus),
                      _kv(
                          'total',
                          total == null
                              ? '--'
                              : _money((total as num) / 100.0)),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Driver Inspection',
              subtitle: 'Pre + post trip walk-around',
              child: Column(
                children: [
                  _inspectionStage(bookingRef, 'pre', 'Pre-Trip'),
                  const SizedBox(height: 12),
                  _inspectionStage(bookingRef, 'post', 'Post-Trip'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Policies (Admin Settings)',
              subtitle: 'Live from admin_settings/app',
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: settingsRef.snapshots(),
                builder: (context, ss) {
                  if (ss.hasError) {
                    return Text('Failed to load settings: ${ss.error}');
                  }
                  if (!ss.hasData) return const LinearProgressIndicator();
                  if (ss.data != null && ss.data!.exists == false) {
                    return const Text(
                        'No admin settings found. Open Settings to create defaults.');
                  }
                  final s = ss.data?.data() ?? {};

                  final minBookingHours =
                      (s['minBookingHours'] as num?)?.toDouble();
                  final minNoticeHours =
                      (s['minNoticeHours'] as num?)?.toDouble();
                  final serviceAreaMiles =
                      (s['serviceAreaMiles'] as num?)?.toDouble();
                  final defaultCity = (s['defaultCity'] ?? '--').toString();

                  final gratuityPct = (s['gratuityPct'] as num?)?.toDouble();
                  final taxRatePct = (s['taxRatePct'] as num?)?.toDouble();
                  final bookingFee = (s['bookingFee'] as num?)?.toDouble();
                  final fuelSurchargePct =
                      (s['fuelSurchargePct'] as num?)?.toDouble();

                  final cancelWindowHours =
                      (s['cancelWindowHours'] as num?)?.toDouble();
                  final lateCancelFee =
                      (s['lateCancelFee'] as num?)?.toDouble();

                  final overtimeGrace =
                      (s['overtimeGraceMinutes'] as num?)?.toInt();
                  final overtimeRate =
                      (s['overtimeRatePerMinute'] as num?)?.toDouble();

                  final serviceStart = (s['serviceStartHour'] as num?)?.toInt();
                  final serviceEnd = (s['serviceEndHour'] as num?)?.toInt();

                  final requirePayment =
                      (s['requirePaymentBeforeDispatch'] as bool?) ?? false;

                  if (s.isEmpty) {
                    return const Text('No admin settings values available.');
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (minBookingHours != null)
                        _kv('minBookingHours',
                            minBookingHours.toStringAsFixed(0)),
                      if (minNoticeHours != null)
                        _kv('minNoticeHours',
                            minNoticeHours.toStringAsFixed(0)),
                      if (serviceAreaMiles != null)
                        _kv('serviceAreaMiles',
                            '${serviceAreaMiles.toStringAsFixed(0)} miles from $defaultCity'),
                      if (gratuityPct != null)
                        _kv('gratuityPct',
                            '${gratuityPct.toStringAsFixed(0)}%'),
                      if (taxRatePct != null)
                        _kv('taxRatePct', '${taxRatePct.toStringAsFixed(2)}%'),
                      if (bookingFee != null)
                        _kv('bookingFee', _money(bookingFee)),
                      if (fuelSurchargePct != null)
                        _kv('fuelSurchargePct',
                            '${fuelSurchargePct.toStringAsFixed(2)}%'),
                      if (cancelWindowHours != null)
                        _kv('cancelWindowHours',
                            '${cancelWindowHours.toStringAsFixed(0)} hrs'),
                      if (lateCancelFee != null)
                        _kv('lateCancelFee', _money(lateCancelFee)),
                      if (overtimeGrace != null)
                        _kv('overtimeGraceMinutes', overtimeGrace.toString()),
                      if (overtimeRate != null)
                        _kv('overtimeRatePerMinute', _money(overtimeRate)),
                      if (serviceStart != null && serviceEnd != null)
                        _kv('serviceHours',
                            '${serviceStart.toString().padLeft(2, '0')}:00 - ${serviceEnd.toString().padLeft(2, '0')}:00'),
                      _kv('requirePaymentBeforeDispatch',
                          requirePayment ? 'Yes' : 'No'),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Internal Notes',
              child: Column(
                children: [
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Add a note'),
                    minLines: 1,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final txt = noteCtrl.text.trim();
                        if (txt.isEmpty) return;
                        await bookingRef.collection('notes').add({
                          'text': txt,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        noteCtrl.clear();
                      },
                      child: const Text('Save Note'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _section(
              title: 'Adjustments / Surcharges',
              subtitle: 'Staff only • bookings_private',
              child: _AdjustmentsForm(
                bookingId: widget.bookingId,
                role: 'admin',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context,
      {required String bookingId,
      required String status,
      required String riderName}) {
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
      child: Row(
        children: [
          _StatusDot(status: status),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  riderName.isEmpty ? 'Booking' : riderName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  bookingId.substring(0, 8),
                  style: const TextStyle(
                      color: PFColors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          _StatusChip(status: status),
        ],
      ),
    );
  }

  Widget _inspectionStage(
    DocumentReference<Map<String, dynamic>> bookingRef,
    String stage,
    String title,
  ) {
    final docRef = bookingRef.collection('driver_inspections').doc(stage);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        if (!snap.data!.exists) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text('$title: No inspection yet.',
                style: const TextStyle(color: PFColors.muted)),
          );
        }

        final data = snap.data!.data() ?? {};
        final notes = (data['notes'] ?? '').toString();
        final checklist = (data['checklist'] as Map<String, dynamic>?) ?? {};
        final uploads = (data['uploads'] as List?)?.cast<Map>() ?? [];
        final updatedAt = formatTimestamp(data['updatedAt']);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Updated: $updatedAt',
                style: const TextStyle(color: PFColors.muted, fontSize: 12)),
            const SizedBox(height: 8),
            const Text('Checklist',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ..._inspectionItems.map((item) {
              final ok = checklist[item.key] == true;
              return Text('${item.label}: ${ok ? 'Yes' : 'No'}');
            }),
            const SizedBox(height: 8),
            const Text('Notes', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(notes.isEmpty ? '—' : notes),
            if (uploads.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Uploads',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              ...uploads.map((u) {
                final name = (u['name'] ?? 'Photo').toString();
                final url = (u['url'] ?? '').toString();
                final path = (u['path'] ?? '').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (url.isNotEmpty || path.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<Uint8List?>(
                            future: _fetchUploadBytes(u),
                            builder: (context, imgSnap) {
                              if (imgSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  height: 140,
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                );
                              }
                              final bytes = imgSnap.data;
                              if (bytes != null) {
                                return Image.memory(
                                  bytes,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) {
                                    if (url.isNotEmpty) {
                                      return Image.network(
                                        url,
                                        height: 140,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox(
                                          height: 140,
                                          child: Center(
                                              child: Text('Image unsupported')),
                                        ),
                                      );
                                    }
                                    return const SizedBox(
                                      height: 140,
                                      child: Center(
                                          child: Text('Image unsupported')),
                                    );
                                  },
                                );
                              }
                              if (url.isNotEmpty) {
                                return Image.network(
                                  url,
                                  height: 140,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    height: 140,
                                    child: Center(
                                        child: Text('Image unsupported')),
                                  ),
                                );
                              }
                              return const SizedBox(
                                height: 140,
                                child: Center(child: Text('Image unavailable')),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (url.isNotEmpty)
                          SelectableText(
                            url,
                            style: const TextStyle(
                                color: PFColors.muted, fontSize: 12),
                          ),
                      ],
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final bytes = await _buildInspectionPdf(
                      bookingId: bookingRef.id,
                      title: title,
                      updatedAt: updatedAt,
                      notes: notes,
                      checklist: checklist,
                      uploads: uploads,
                    );
                    await Printing.layoutPdf(onLayout: (_) async => bytes);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF failed: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text('Download PDF'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List> _buildInspectionPdf({
    required String bookingId,
    required String title,
    required String updatedAt,
    required String notes,
    required Map<String, dynamic> checklist,
    required List<Map> uploads,
  }) async {
    final doc = pw.Document();

    final uploadWidgets = <pw.Widget>[];
    for (final u in uploads) {
      final name = (u['name'] ?? 'Photo').toString();
      try {
        final bytes = await _fetchUploadBytes(u);
        if (bytes == null) continue;
        uploadWidgets.addAll([
          pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Image(pw.MemoryImage(bytes), height: 240, fit: pw.BoxFit.cover),
          pw.SizedBox(height: 12),
        ]);
      } catch (_) {
        uploadWidgets.addAll([
          pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Unsupported image format'),
          pw.SizedBox(height: 12),
        ]);
      }
    }

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Pink Fleets • Driver Inspection',
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Booking: ${bookingId.substring(0, 8)}'),
          pw.Text('Stage: $title'),
          pw.Text('Updated: $updatedAt'),
          pw.SizedBox(height: 12),
          pw.Text('Checklist',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          ..._inspectionItems.map((item) {
            final ok = checklist[item.key] == true;
            return pw.Text('${item.label}: ${ok ? 'Yes' : 'No'}');
          }),
          pw.SizedBox(height: 12),
          pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(notes.isEmpty ? '—' : notes),
          if (uploadWidgets.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('Uploads',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...uploadWidgets,
          ],
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List?> _fetchUploadBytes(Map upload) async {
    final path = (upload['path'] ?? '').toString();
    final url = (upload['url'] ?? '').toString();
    try {
      if (path.isNotEmpty) {
        return await FirebaseStorage.instance
            .ref(path)
            .getData(10 * 1024 * 1024);
      }
      if (url.isNotEmpty) {
        return await FirebaseStorage.instance
            .refFromURL(url)
            .getData(10 * 1024 * 1024);
      }
    } catch (_) {
      // fall back to raw url
    }
    try {
      if (url.isEmpty) return null;
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) return null;
      return resp.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Widget _section(
      {required String title, String? subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(
                    color: PFColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              k,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: PFColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
  Widget build(BuildContext context) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
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
      child: Text(status,
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 12, color: PFColors.ink)),
    );
  }
}

// ── Staff Adjustments / Surcharges form ─────────────────────────────────
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (byRole.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Last saved by: $byRole',
                  style: const TextStyle(color: PFColors.muted, fontSize: 11))
            ],
            const SizedBox(height: 10),
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
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save Adjustments'),
              ),
            ),
          ],
        );
      },
    );
  }
}
