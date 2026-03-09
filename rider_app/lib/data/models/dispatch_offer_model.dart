import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_converters.dart';

enum DispatchOfferStatus { sent, delivered, accepted, declined, expired, cancelled }

class DispatchOfferModel {
  final String id;
  final String bookingId;
  final String driverId;
  final DispatchOfferStatus status;

  final int attemptNumber;
  final DateTime sentAt;
  final DateTime expiresAt;

  final DateTime? acknowledgedAt; // driver app saw it
  final DateTime? respondedAt;    // accept/decline happened

  const DispatchOfferModel({
    required this.id,
    required this.bookingId,
    required this.driverId,
    required this.status,
    required this.attemptNumber,
    required this.sentAt,
    required this.expiresAt,
    required this.acknowledgedAt,
    required this.respondedAt,
  });

  static DispatchOfferModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DispatchOfferModel(
      id: doc.id,
      bookingId: (data['bookingId'] ?? '') as String,
      driverId: (data['driverId'] ?? '') as String,
      status: enumFromString(
        data['status'] as String?,
        DispatchOfferStatus.values,
        fallback: DispatchOfferStatus.sent,
      ),
      attemptNumber: (data['attemptNumber'] ?? 0) as int,
      sentAt: dtFromTs(data['sentAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt:
          dtFromTs(data['expiresAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      acknowledgedAt: dtFromTs(data['acknowledgedAt']),
      respondedAt: dtFromTs(data['respondedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'bookingId': bookingId,
        'driverId': driverId,
        'status': enumToString(status),
        'attemptNumber': attemptNumber,
        'sentAt': tsFromDt(sentAt),
        'expiresAt': tsFromDt(expiresAt),
        'acknowledgedAt': tsFromDt(acknowledgedAt),
        'respondedAt': tsFromDt(respondedAt),
        'schemaVersion': 1,
      };
}