abstract class BookingRepository {
  Stream<Map<String, dynamic>> watchBooking(String id);
  Future<Map<String, dynamic>?> getBooking(String id);
  Future<void> updateBooking(String id, Map<String, dynamic> data);
}