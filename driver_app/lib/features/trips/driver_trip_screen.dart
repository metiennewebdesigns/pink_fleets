import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/driver_theme.dart';

class DriverTripScreen extends StatelessWidget {
  final String bookingId;
  const DriverTripScreen({super.key, required this.bookingId});

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('bookings').doc(bookingId);

  Future<void> _setStatus(String status) async {
    await _ref.set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      if (status == 'in_progress')
        'actualStartAt': FieldValue.serverTimestamp(),
      if (status == 'completed') 'actualEndAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildContent(context);
    } catch (e, st) {
      debugPrint('[DRIVER TRIP] build crash: $e');
      debugPrint('[DRIVER TRIP] stack: $st');
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Something went wrong loading this trip.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildContent(BuildContext context) {
    Color statusColor(String status) {
      switch (status) {
        case 'in_progress':
          return PFColors.success;
        case 'completed':
          return PFColors.muted;
        case 'arrived':
          return const Color(0xFF0E8FAF);
        case 'accepted':
        case 'en_route':
          return PFColors.warning;
        case 'cancelled':
          return PFColors.danger;
        default:
          return PFColors.ink;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trip')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load trip: ${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!(snap.data?.exists ?? false)) {
            return const Center(child: Text('Trip not found'));
          }
          final d = snap.data?.data() ?? {};
          final status = (d['status'] ?? 'unknown').toString();
          final statusC = statusColor(status);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Booking: $bookingId',
                            style: const TextStyle(
                                color: PFColors.muted,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Status',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusC.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                    color: statusC.withValues(alpha: 0.28)),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                    color: statusC,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed:
                              (status == 'accepted' || status == 'en_route')
                                  ? () => _setStatus('arrived')
                                  : null,
                          icon: const Icon(Icons.location_on),
                          label: const Text('Mark Arrived'),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: (status == 'arrived')
                              ? () => _setStatus('in_progress')
                              : null,
                          icon: const Icon(Icons.play_circle_fill),
                          label: const Text('Start Trip'),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: (status == 'in_progress')
                              ? () => _setStatus('completed')
                              : null,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Complete Trip'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
