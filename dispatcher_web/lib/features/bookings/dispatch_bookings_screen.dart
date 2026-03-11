// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../providers/firebase_providers.dart';
import '../../shared/widgets/live_trip_map.dart';
import '../../theme/dispatcher_theme.dart';
import 'inspection_viewer_screen.dart';

class DispatchBookingsScreen extends ConsumerStatefulWidget {
  const DispatchBookingsScreen({super.key});

  @override
  ConsumerState<DispatchBookingsScreen> createState() =>
      _DispatchBookingsScreenState();
}

class _DispatchBookingsScreenState
    extends ConsumerState<DispatchBookingsScreen> {
  String filter = 'all';

  String _normStatus(dynamic raw) {
    final s = (raw ?? '').toString().trim().toLowerCase();
    if (s == 'driver_assigned' || s == 'confirmed') return 'accepted';
    return s.replaceAll(' ', '_');
  }

  void _showRiderProfile(
    BuildContext context,
    String? riderUid,
    Map<String, dynamic>? riderInfo,
    Map<String, dynamic>? bookingInfo,
  ) {
    final db = ref.read(firestoreProvider);
    final resolvedUid = (riderUid ?? '').trim();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
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
              final dob = (merged['dob'] ?? '').toString().trim();
              final address = (merged['address'] ?? '').toString().trim();
              final photoUrl = (merged['photoUrl'] ?? '').toString();

              final b = bookingInfo ?? const <String, dynamic>{};
              String asText(dynamic v) {
                if (v == null) return '';
                if (v is String) return v.trim();
                if (v is Map) {
                  for (final key in const [
                    'address',
                    'label',
                    'name',
                    'formattedAddress',
                    'text'
                  ]) {
                    final nested = v[key];
                    if (nested is String && nested.trim().isNotEmpty)
                      return nested.trim();
                  }
                }
                return v.toString().trim();
              }

              String firstNonEmpty(List<dynamic> values) {
                for (final value in values) {
                  final text = asText(value);
                  if (text.isNotEmpty) return text;
                }
                return '—';
              }

              final pickupAddress = firstNonEmpty([
                b['pickupAddress'],
                b['pickup'],
                b['pickupLocation'],
                b['originAddress'],
                b['fromAddress'],
              ]);
              final dropoffAddress = firstNonEmpty([
                b['dropoffAddress'],
                b['dropoff'],
                b['dropoffLocation'],
                b['destinationAddress'],
                b['toAddress'],
              ]);

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
                  Text('Address: ${address.isEmpty ? '—' : address}'),
                  Text('DOB: ${dob.isEmpty ? '—' : dob}'),
                  const SizedBox(height: 6),
                  Text('Pickup: $pickupAddress'),
                  Text('Dropoff: $dropoffAddress'),
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
    final q = db.collection('bookings').orderBy('createdAt', descending: true);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: PFColors.white,
              borderRadius: BorderRadius.circular(18),
              border: const Border.fromBorderSide(
                  BorderSide(color: PFColors.border)),
            ),
            child: Row(
              children: [
                Text('Dispatch',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                Text('Live ops queue',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: PFColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: PFColors.white,
              borderRadius: BorderRadius.circular(18),
              border: const Border.fromBorderSide(
                  BorderSide(color: PFColors.border)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 520;
                final chips = [
                  _chip('all', 'All'),
                  _chip('accepted', 'Accepted'),
                  _chip('en_route', 'En Route'),
                  _chip('arrived', 'Arrived'),
                  _chip('in_progress', 'In Progress'),
                  _chip('completed', 'Completed'),
                  _chip('cancelled', 'Cancelled'),
                ];

                if (isNarrow) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < chips.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          chips[i],
                        ],
                      ],
                    ),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, snap) {
                if (snap.hasError)
                  return Center(child: Text('Error:\n${snap.error}'));
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());

                final allDocs = snap.data!.docs;
                final docs = filter == 'all'
                    ? allDocs
                    : allDocs
                        .where((doc) =>
                            _normStatus(doc.data()['status']) == filter)
                        .toList();
                if (docs.isEmpty)
                  return const Center(child: Text('No bookings found.'));

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final d = doc.data();
                    final status = _normStatus(d['status']);
                    final rider = d['riderInfo'] as Map<String, dynamic>?;
                    final riderName = (rider?['name'] ?? 'Rider').toString();
                    final riderUid =
                        (d['riderUid'] ?? rider?['uid'] ?? rider?['id'] ?? '')
                            .toString();
                    final canOpenRider =
                        riderUid.trim().isNotEmpty || rider != null;
                    final scheduledStart =
                        d['scheduledStartAt'] ?? d['createdAt'];
                    final whenText = _shortDateTime(scheduledStart);

                    return InkWell(
                      onTap: () => _openDispatchDetail(context, doc.id),
                      child: Container(
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
                        child: Row(
                          children: [
                            _StatusDot(status: status),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: canOpenRider
                                        ? () => _showRiderProfile(
                                            context, riderUid, rider, d)
                                        : null,
                                    child: Text(
                                      riderName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: canOpenRider
                                            ? PFColors.pink1
                                            : PFColors.ink,
                                        decoration: canOpenRider
                                            ? TextDecoration.underline
                                            : TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Booking: ${doc.id.substring(0, 8)} • $whenText',
                                    style:
                                        const TextStyle(color: PFColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            _StatusChip(status: status),
                            const SizedBox(width: 10),
                            const Icon(Icons.chevron_right),
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
      ),
    );
  }

  Widget _chip(String value, String label) {
    final selected = filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: PFColors.gold.withValues(alpha: 0.16),
      onSelected: (_) => setState(() => filter = value),
    );
  }

  void _openDispatchDetail(BuildContext context, String bookingId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DispatchBookingDetail(bookingId: bookingId),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  Color get c {
    final normalized = (status == 'driver_assigned' || status == 'confirmed')
        ? 'accepted'
        : status.replaceAll(' ', '_');
    switch (normalized) {
      case 'accepted':
        return PFColors.primary;
      case 'en_route':
        return PFColors.gold;
      case 'arrived':
        return PFColors.gold;
      case 'in_progress':
        return PFColors.success;
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
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = (status == 'driver_assigned' || status == 'confirmed')
        ? 'accepted'
        : status.replaceAll(' ', '_');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: PFColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 12, color: PFColors.ink),
      ),
    );
  }
}

class _DispatchBookingDetail extends ConsumerStatefulWidget {
  final String bookingId;
  const _DispatchBookingDetail({required this.bookingId});

  @override
  ConsumerState<_DispatchBookingDetail> createState() =>
      _DispatchBookingDetailState();
}

class _DispatchBookingDetailState
    extends ConsumerState<_DispatchBookingDetail> {
  String? driverId;
  String? vehicleId;

  String _money(num? v) {
    if (v == null) return '--';
    return '\$${v.toStringAsFixed(2)}';
  }

  Future<void> _notifyDriver(
      String driverUid, String bookingId, String status) async {
    final fn = FirebaseFunctions.instance.httpsCallable('notifyDriver');
    await fn.call({
      'driverUid': driverUid,
      'title': 'Dispatch update • Pink Fleets',
      'body': 'Booking $bookingId • Status: $status',
      'data': {'bookingId': bookingId, 'status': status},
    });
  }

  double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  String _asText(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    if (v is Map) {
      for (final key in const [
        'address',
        'label',
        'name',
        'formattedAddress',
        'text'
      ]) {
        final nested = v[key];
        if (nested is String && nested.trim().isNotEmpty) return nested.trim();
      }
    }
    return v.toString().trim();
  }

  String _firstText(List<dynamic> values) {
    for (final v in values) {
      final t = _asText(v);
      if (t.isNotEmpty) return t;
    }
    return '—';
  }

  String _vehicleLabel(dynamic raw) {
    final value = (raw ?? '').toString().trim();
    if (value.isEmpty || value == '—') return '—';
    final spaced = value.replaceAll('_', ' ').replaceAll('-', ' ');
    return spaced
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  void _openMapUrl(String url) {
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(firestoreProvider);
    final bookingRef = db.collection('bookings').doc(widget.bookingId);
    final bookingPrivateRef =
        db.collection('bookings_private').doc(widget.bookingId);
    final settingsRef = db.collection('admin_settings').doc('app');

    final driversQ = db.collection('drivers').where('active', isEqualTo: true);
    final vehiclesQ =
        db.collection('vehicles').where('active', isEqualTo: true);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: bookingRef.snapshots(),
          builder: (context, snap) {
            if (!snap.hasData)
              return const Center(child: CircularProgressIndicator());
            if (!snap.data!.exists)
              return const Center(child: Text('Booking not found'));

            final d = snap.data!.data()!;
            final rawStatus = (d['status'] ?? 'unknown').toString();
            final status =
                (rawStatus == 'driver_assigned' || rawStatus == 'confirmed')
                    ? 'accepted'
                    : rawStatus.replaceAll(' ', '_');

            final rider = d['riderInfo'] as Map<String, dynamic>?;
            final riderName = _firstText([rider?['name']]);
            final riderEmail = _firstText([rider?['email']]);
            final riderPhone = _firstText([rider?['phone']]);
            final riderAddress =
                _firstText([rider?['address'], d['riderAddress']]);

            final pickupAddress = _firstText([
              d['pickupAddress'],
              d['pickup'],
              d['pickupLocation'],
              d['originAddress'],
              d['fromAddress'],
            ]);
            final dropoffAddress = _firstText([
              d['dropoffAddress'],
              d['dropoff'],
              d['dropoffLocation'],
              d['destinationAddress'],
              d['toAddress'],
            ]);

            final pickupLat = _asDouble(d['pickupLat']);
            final pickupLng = _asDouble(d['pickupLng']);
            final dropoffLat = _asDouble(d['dropoffLat']);
            final dropoffLng = _asDouble(d['dropoffLng']);

            final assigned = d['assigned'] as Map<String, dynamic>?;
            final currentDriverId = _firstText([
              assigned?['driverId'],
              d['driverId'],
            ]);
            if ((driverId ?? '').isEmpty && currentDriverId.isNotEmpty) {
              driverId = currentDriverId;
            }
            vehicleId ??= assigned?['vehicleId'] as String?;
            final requestedVehicle = _vehicleLabel(_firstText([
              d['requestedVehicle'],
              d['requested_vehicle'],
              d['vehicle_type'],
              d['vehicleType'],
              d['selectedVehicle'],
              d['vehicle'],
            ]));
            final assignedVehicle = _firstText([
              assigned?['vehicleName'],
              assigned?['vehicleLabel'],
              assigned?['vehicleId'],
            ]);

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PFColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: const Border.fromBorderSide(
                            BorderSide(color: PFColors.border)),
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
                                    'Booking ${widget.bookingId.substring(0, 8)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 2),
                                Text('Status: $status',
                                    style: const TextStyle(
                                        color: PFColors.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                          _StatusChip(status: status),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PFColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: const Border.fromBorderSide(
                            BorderSide(color: PFColors.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rider & Trip Details',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Text('Name: $riderName'),
                          Text('Email: $riderEmail'),
                          Text('Phone: $riderPhone'),
                          Text('Address: $riderAddress'),
                          const SizedBox(height: 6),
                          Text('Pickup: $pickupAddress'),
                          Text('Dropoff: $dropoffAddress'),
                          Text('Requested Vehicle: $requestedVehicle'),
                          Text(
                              'Assigned Vehicle: ${assignedVehicle == '—' ? 'Unassigned' : assignedVehicle}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PFColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: const Border.fromBorderSide(
                            BorderSide(color: PFColors.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Live GPS Safety Tracking',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          if (driverId == null || driverId!.isEmpty)
                            const Text(
                                'Assign a driver to start live GPS tracking.')
                          else
                            StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>>(
                              stream: db
                                  .collection('drivers')
                                  .doc(driverId!)
                                  .snapshots(),
                              builder: (context, ds) {
                                if (!ds.hasData)
                                  return const LinearProgressIndicator();
                                final driver = ds.data!.data() ?? {};
                                final loc = (driver['lastLocation']
                                        as Map<String, dynamic>?) ??
                                    {};
                                final dLat = _asDouble(driver['lat']) ??
                                    _asDouble(loc['lat']);
                                final dLng = _asDouble(driver['lng']) ??
                                    _asDouble(loc['lng']);
                                final updatedAt = _formatTimestamp(
                                    driver['updatedAt'] ?? loc['updatedAt']);

                                final hasDriver = dLat != null && dLng != null;
                                final toPickup = hasDriver &&
                                        pickupLat != null &&
                                        pickupLng != null
                                    ? _haversineMiles(
                                        dLat, dLng, pickupLat, pickupLng)
                                    : null;
                                final toDropoff = hasDriver &&
                                        dropoffLat != null &&
                                        dropoffLng != null
                                    ? _haversineMiles(
                                        dLat, dLng, dropoffLat, dropoffLng)
                                    : null;

                                final driverPointUrl = hasDriver
                                    ? 'https://www.google.com/maps/search/?api=1&query=$dLat,$dLng'
                                    : null;

                                String? routeUrl;
                                if (hasDriver &&
                                    pickupLat != null &&
                                    pickupLng != null &&
                                    dropoffLat != null &&
                                    dropoffLng != null) {
                                  routeUrl =
                                      'https://www.google.com/maps/dir/?api=1&origin=$dLat,$dLng&destination=$dropoffLat,$dropoffLng&waypoints=$pickupLat,$pickupLng&travelmode=driving';
                                } else if (hasDriver &&
                                    pickupLat != null &&
                                    pickupLng != null) {
                                  routeUrl =
                                      'https://www.google.com/maps/dir/?api=1&origin=$dLat,$dLng&destination=$pickupLat,$pickupLng&travelmode=driving';
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Driver: ${_firstText([
                                          driver['name']
                                        ])}'),
                                    Text('GPS updated: $updatedAt'),
                                    Text(
                                        'Driver coordinates: ${hasDriver ? '$dLat, $dLng' : 'Waiting for live location…'}'),
                                    if (toPickup != null)
                                      Text(
                                          'Distance to pickup: ${toPickup.toStringAsFixed(2)} mi'),
                                    if (toDropoff != null)
                                      Text(
                                          'Distance to dropoff: ${toDropoff.toStringAsFixed(2)} mi'),
                                    const SizedBox(height: 10),
                                    StreamBuilder<
                                        DocumentSnapshot<Map<String, dynamic>>>(
                                      stream: bookingPrivateRef.snapshots(),
                                      builder: (context, ps) {
                                        final priv = ps.data?.data() ?? {};
                                        final pickupRaw = priv['pickupGeo'];
                                        final dropoffRaw = priv['dropoffGeo'];

                                        GeoPoint? pickupGeo;
                                        GeoPoint? dropoffGeo;

                                        if (pickupRaw is GeoPoint)
                                          pickupGeo = pickupRaw;
                                        if (dropoffRaw is GeoPoint)
                                          dropoffGeo = dropoffRaw;

                                        pickupGeo ??= (pickupLat != null &&
                                                pickupLng != null)
                                            ? GeoPoint(pickupLat, pickupLng)
                                            : null;
                                        dropoffGeo ??= (dropoffLat != null &&
                                                dropoffLng != null)
                                            ? GeoPoint(dropoffLat, dropoffLng)
                                            : null;

                                        final driverLatLng = !kIsWeb &&
                                                dLat != null &&
                                                dLng != null
                                            ? LatLng(dLat, dLng)
                                            : null;

                                        return PFUberLiveMap(
                                          driverId: driverId,
                                          initialDriverLatLng: driverLatLng,
                                          pickupGeo: pickupGeo,
                                          dropoffGeo: dropoffGeo,
                                          height: 220,
                                          driverName:
                                              _firstText([driver['name']]),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: driverPointUrl == null
                                              ? null
                                              : () =>
                                                  _openMapUrl(driverPointUrl),
                                          icon: const Icon(
                                              Icons.my_location_outlined),
                                          label:
                                              const Text('Open Driver GPS Map'),
                                        ),
                                        OutlinedButton.icon(
                                          onPressed: routeUrl == null
                                              ? null
                                              : () => _openMapUrl(routeUrl!),
                                          icon: const Icon(
                                              Icons.alt_route_rounded),
                                          label: const Text('Open Route Map'),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PFColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: const Border.fromBorderSide(
                            BorderSide(color: PFColors.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Assign',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: driversQ.snapshots(),
                            builder: (context, ds) {
                              if (!ds.hasData)
                                return const LinearProgressIndicator();
                              final docs = ds.data!.docs;
                              return DropdownButtonFormField<String?>(
                                initialValue: driverId,
                                decoration:
                                    const InputDecoration(labelText: 'Driver'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                      value: null, child: Text('Unassigned')),
                                  ...docs.map((doc) {
                                    final name = (doc.data()['name'] ?? doc.id)
                                        .toString();
                                    return DropdownMenuItem<String?>(
                                        value: doc.id, child: Text(name));
                                  }),
                                ],
                                onChanged: (v) => setState(() => driverId = v),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: vehiclesQ.snapshots(),
                            builder: (context, vs) {
                              if (!vs.hasData)
                                return const LinearProgressIndicator();
                              final docs = vs.data!.docs;
                              return DropdownButtonFormField<String?>(
                                initialValue: vehicleId,
                                decoration:
                                    const InputDecoration(labelText: 'Vehicle'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                      value: null, child: Text('Unassigned')),
                                  ...docs.map((doc) {
                                    final name = (doc.data()['name'] ?? doc.id)
                                        .toString();
                                    return DropdownMenuItem<String?>(
                                        value: doc.id, child: Text(name));
                                  }),
                                ],
                                onChanged: (v) => setState(() => vehicleId = v),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                await bookingRef.set({
                                  'driverId': driverId,
                                  'assigned': {
                                    'driverId': driverId,
                                    'vehicleId': vehicleId,
                                    'assignedAt': FieldValue.serverTimestamp(),
                                  },
                                  'status': 'accepted',
                                  'updatedAt': FieldValue.serverTimestamp(),
                                }, SetOptions(merge: true));

                                if (driverId != null && driverId!.isNotEmpty) {
                                  await _notifyDriver(
                                      driverId!, widget.bookingId, 'accepted');
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Assigned + notified driver ✅')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Assign failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            child: const Text('Assign + Notify Driver'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PFColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: const Border.fromBorderSide(
                            BorderSide(color: PFColors.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Driver Inspection',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          _inspectionStage(bookingRef, 'pre', 'Pre-Trip'),
                          const SizedBox(height: 12),
                          _inspectionStage(bookingRef, 'post', 'Post-Trip'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PFColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: const Border.fromBorderSide(
                            BorderSide(color: PFColors.border)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Adjustments / Surcharges',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          const Text('Dispatcher — saved to bookings_private',
                              style: TextStyle(
                                  color: PFColors.muted, fontSize: 12)),
                          const SizedBox(height: 12),
                          _AdjustmentsForm(
                              bookingId: widget.bookingId, role: 'dispatcher'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: PFColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: const Border.fromBorderSide(
                            BorderSide(color: PFColors.border)),
                      ),
                      child:
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: settingsRef.snapshots(),
                        builder: (context, ss) {
                          if (!ss.hasData)
                            return const LinearProgressIndicator();
                          final s = ss.data?.data() ?? {};

                          final minBookingHours =
                              (s['minBookingHours'] as num?)?.toDouble();
                          final minNoticeHours =
                              (s['minNoticeHours'] as num?)?.toDouble();
                          final serviceAreaMiles =
                              (s['serviceAreaMiles'] as num?)?.toDouble();
                          final defaultCity =
                              (s['defaultCity'] ?? '--').toString();

                          final gratuityPct =
                              (s['gratuityPct'] as num?)?.toDouble();
                          final taxRatePct =
                              (s['taxRatePct'] as num?)?.toDouble();
                          final bookingFee =
                              (s['bookingFee'] as num?)?.toDouble();
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

                          final requirePayment =
                              (s['requirePaymentBeforeDispatch'] as bool?) ??
                                  false;

                          Widget line(String label, String value) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('• $label: $value'));

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Policies',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 8),
                              if (minBookingHours != null)
                                line('Min booking',
                                    '${minBookingHours.toStringAsFixed(0)} hrs'),
                              if (minNoticeHours != null)
                                line('Min notice',
                                    '${minNoticeHours.toStringAsFixed(0)} hrs'),
                              if (serviceAreaMiles != null)
                                line('Service area',
                                    '${serviceAreaMiles.toStringAsFixed(0)} mi from $defaultCity'),
                              if (gratuityPct != null)
                                line('Gratuity',
                                    '${gratuityPct.toStringAsFixed(0)}%'),
                              if (taxRatePct != null)
                                line(
                                    'Tax', '${taxRatePct.toStringAsFixed(2)}%'),
                              if (bookingFee != null)
                                line('Booking fee', _money(bookingFee)),
                              if (fuelSurchargePct != null)
                                line('Fuel surcharge',
                                    '${fuelSurchargePct.toStringAsFixed(2)}%'),
                              if (cancelWindowHours != null)
                                line('Cancel window',
                                    '${cancelWindowHours.toStringAsFixed(0)} hrs'),
                              if (lateCancelFee != null)
                                line('Late cancel fee', _money(lateCancelFee)),
                              if (overtimeGrace != null && overtimeRate != null)
                                line('Overtime',
                                    '$overtimeGrace min grace, then ${_money(overtimeRate)}/min'),
                              line('Require payment before dispatch',
                                  requirePayment ? 'Yes' : 'No'),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _formatTimestamp(dynamic v) {
  if (v is Timestamp) return v.toDate().toString();
  if (v is DateTime) return v.toString();
  return v?.toString() ?? '—';
}

String _shortDateTime(dynamic v) {
  DateTime? dt;
  if (v is Timestamp) dt = v.toDate();
  if (v is DateTime) dt = v;
  if (dt == null) return '—';

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final mm = months[dt.month - 1];
  final dd = dt.day.toString().padLeft(2, '0');
  var hour = dt.hour;
  final min = dt.minute.toString().padLeft(2, '0');
  final ampm = hour >= 12 ? 'PM' : 'AM';
  hour = hour % 12;
  if (hour == 0) hour = 12;
  return '$mm $dd • $hour:$min $ampm';
}

double _haversineMiles(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusMiles = 3958.8;
  final dLat = (lat2 - lat1) * (math.pi / 180.0);
  final dLng = (lng2 - lng1) * (math.pi / 180.0);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * (math.pi / 180.0)) *
          math.cos(lat2 * (math.pi / 180.0)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMiles * c;
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
      final updatedAt = _formatTimestamp(data['updatedAt']);

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
                                  child:
                                      Center(child: Text('Image unsupported')),
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
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => InspectionViewerScreen(
                    bookingId: bookingRef.id,
                    stage: stage,
                  ),
                ),
              ),
              icon: const Icon(Icons.visibility_rounded, size: 16),
              label: Text('View Full $title'),
            ),
          ),
          const SizedBox(height: 8),
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
                  final fileName =
                      'inspection_${bookingRef.id.substring(0, 8)}_$stage.pdf';
                  if (kIsWeb) {
                    _downloadPdfWeb(bytes, fileName);
                  } else {
                    await Printing.layoutPdf(onLayout: (_) async => bytes);
                  }
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
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
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

void _downloadPdfWeb(Uint8List bytes, String fileName) {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<Uint8List?> _fetchUploadBytes(Map upload) async {
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
      final fuelPct = double.tryParse(_fuelCtrl.text.trim()) ?? 0.0;
      final parkingCents =
          ((double.tryParse(_parkingCtrl.text.trim()) ?? 0.0) * 100).round();
      final tollsCents =
          ((double.tryParse(_tollsCtrl.text.trim()) ?? 0.0) * 100).round();
      final venueCents =
          ((double.tryParse(_venueCtrl.text.trim()) ?? 0.0) * 100).round();

      // Call server-side function (Stripe-ready stub) instead of direct
      // Firestore write — server computes final totals + audit-logs.
      final callable =
          FirebaseFunctions.instance.httpsCallable('chargeBookingAdjustments');
      await callable.call({
        'bookingId': widget.bookingId,
        'fuelSurchargePct': fuelPct,
        'parkingCents': parkingCents,
        'tollsCents': tollsCents,
        'venueCents': venueCents,
        'notes': _notesCtrl.text.trim(),
      });

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
