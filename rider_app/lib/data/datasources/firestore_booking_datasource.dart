import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreBookingDataSource {
  final FirebaseFirestore _firestore;

  FirestoreBookingDataSource(this._firestore);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchBooking(String id) {
    return _firestore.collection('bookings').doc(id).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getBooking(String id) {
    return _firestore.collection('bookings').doc(id).get();
  }

  Future<void> updateBooking(String id, Map<String, dynamic> data) {
    return _firestore.collection('bookings').doc(id).update(data);
  }

  Future<T> runTransaction<T>(
      Future<T> Function(Transaction tx) handler) {
    return _firestore.runTransaction(handler);
  }
}