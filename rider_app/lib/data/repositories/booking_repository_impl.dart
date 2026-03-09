import '../datasources/firestore_booking_datasource.dart';
import 'booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  final FirestoreBookingDataSource _ds;

  BookingRepositoryImpl(this._ds);

  @override
  Stream<Map<String, dynamic>> watchBooking(String id) {
    return _ds.watchBooking(id).map((doc) => doc.data() ?? {});
  }

  @override
  Future<Map<String, dynamic>?> getBooking(String id) async {
    final doc = await _ds.getBooking(id);
    return doc.data();
  }

  @override
  Future<void> updateBooking(String id, Map<String, dynamic> data) {
    return _ds.updateBooking(id, data);
  }
}