import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_converters.dart';

class PricingSnapshot {
  final num total;

  const PricingSnapshot({required this.total});

  static PricingSnapshot fromMap(Map<String, dynamic>? m) {
    return PricingSnapshot(
      total: (m?['total'] ?? 0) as num,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total': total,
    };
  }
}

class BookingPrivateModel {
  final String id;

  final DateTime createdAt;
  final String paymentStatus;

  final PricingSnapshot pricingSnapshot;

  const BookingPrivateModel({
    required this.id,
    required this.createdAt,
    required this.paymentStatus,
    required this.pricingSnapshot,
  });

  static BookingPrivateModel fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};

    return BookingPrivateModel(
      id: doc.id,
      createdAt:
          dtFromTs(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      paymentStatus: (d['paymentStatus'] ?? 'unknown') as String,
      pricingSnapshot: PricingSnapshot.fromMap(
        (d['pricingSnapshot'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'createdAt': tsFromDt(createdAt),
      'paymentStatus': paymentStatus,
      'pricingSnapshot': pricingSnapshot.toMap(),
      'schemaVersion': 1,
    };
  }
}