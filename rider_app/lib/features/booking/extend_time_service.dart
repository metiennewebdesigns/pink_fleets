import 'package:cloud_firestore/cloud_firestore.dart';

class ExtendTimeService {
  static Future<void> extendBooking({
    required String bookingId,
    required int addMinutes,
  }) async {
    final ref = FirebaseFirestore.instance.collection('bookings').doc(bookingId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('Booking not found');

      final d = snap.data() as Map<String, dynamic>;
      final currentEnd = (d['scheduledEndAt'] as Timestamp?)?.toDate();

      if (currentEnd == null) {
        // If missing, create a default end time 2 hours from now
        final fallback = DateTime.now().add(const Duration(hours: 2));
        tx.update(ref, {
          'scheduledEndAt': Timestamp.fromDate(fallback),
        });
      }

      final end = currentEnd ?? DateTime.now().add(const Duration(hours: 2));
      final newEnd = end.add(Duration(minutes: addMinutes));

      tx.set(ref, {
        'scheduledEndAt': Timestamp.fromDate(newEnd),
        'extensions': FieldValue.arrayUnion([
          {
            'addedMinutes': addMinutes,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'requested', // later: paid
          }
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}