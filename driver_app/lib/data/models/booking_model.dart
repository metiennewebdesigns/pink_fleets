import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_converters.dart';

enum BookingStatus {
  pending,
  dispatching,
  offered,
  accepted,
  enRoute,
  arrived,
  inProgress,
  completed,
  cancelled,
  declined,
}

BookingStatus bookingStatusFromString(String? s) {
  final v = (s ?? '').trim().toLowerCase().replaceAll(' ', '_');
  switch (v) {
    case 'pending':
      return BookingStatus.pending;
    case 'dispatching':
      return BookingStatus.dispatching;
    case 'offered':
      return BookingStatus.offered;
    case 'accepted':
      return BookingStatus.accepted;
    case 'en_route':
      return BookingStatus.enRoute;
    case 'arrived':
      return BookingStatus.arrived;
    case 'in_progress':
      return BookingStatus.inProgress;
    case 'completed':
      return BookingStatus.completed;
    case 'cancelled':
      return BookingStatus.cancelled;
    case 'declined':
      return BookingStatus.declined;
    default:
      return BookingStatus.pending;
  }
}

String bookingStatusToString(BookingStatus s) {
  switch (s) {
    case BookingStatus.enRoute:
      return 'en_route';
    case BookingStatus.inProgress:
      return 'in_progress';
    default:
      return enumToString(s)!;
  }
}

class AssignedInfo {
  final String? driverId;
  final String? vehicleId;
  final DateTime? assignedAt;

  const AssignedInfo({this.driverId, this.vehicleId, this.assignedAt});

  static AssignedInfo fromMap(Map<String, dynamic>? m) => AssignedInfo(
        driverId: m?['driverId'] as String?,
        vehicleId: m?['vehicleId'] as String?,
        assignedAt: dtFromTs(m?['assignedAt']),
      );

  Map<String, dynamic> toMap() => {
        'driverId': driverId,
        'vehicleId': vehicleId,
        'assignedAt': tsFromDt(assignedAt),
      }..removeWhere((k, v) => v == null);
}

class RiderInfo {
  final String name;
  final String email;
  final String phone;

  const RiderInfo({required this.name, required this.email, required this.phone});

  static RiderInfo fromMap(Map<String, dynamic>? m) => RiderInfo(
        name: (m?['name'] ?? '') as String,
        email: (m?['email'] ?? '') as String,
        phone: (m?['phone'] ?? '') as String,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
      };
}

class OvertimeInfo {
  final num amount;
  final DateTime? computedAt;
  final int graceMinutes;
  final int minutes;
  final num ratePerMinute;

  const OvertimeInfo({
    required this.amount,
    required this.computedAt,
    required this.graceMinutes,
    required this.minutes,
    required this.ratePerMinute,
  });

  static OvertimeInfo fromMap(Map<String, dynamic>? m) => OvertimeInfo(
        amount: (m?['amount'] ?? 0) as num,
        computedAt: dtFromTs(m?['computedAt']),
        graceMinutes: (m?['graceMinutes'] ?? 0) as int,
        minutes: (m?['minutes'] ?? 0) as int,
        ratePerMinute: (m?['ratePerMinute'] ?? 0) as num,
      );

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'computedAt': tsFromDt(computedAt),
        'graceMinutes': graceMinutes,
        'minutes': minutes,
        'ratePerMinute': ratePerMinute,
      };
}

class BookingModel {
  final String id;

  final BookingStatus status;
  final String? adminDecision;

  final AssignedInfo assigned;
  final RiderInfo riderInfo;
  final OvertimeInfo overtime;

  final DateTime? actualStartAt;
  final DateTime? actualEndAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  // NOTE: we’ll add pickup/dropoff + quote breakdown once you show those fields
  const BookingModel({
    required this.id,
    required this.status,
    required this.adminDecision,
    required this.assigned,
    required this.riderInfo,
    required this.overtime,
    required this.actualStartAt,
    required this.actualEndAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static BookingModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BookingModel(
      id: doc.id,
      status: bookingStatusFromString(d['status'] as String?),
      adminDecision: d['adminDecision'] as String?,
      assigned: AssignedInfo.fromMap((d['assigned'] as Map?)?.cast<String, dynamic>()),
      riderInfo: RiderInfo.fromMap((d['riderInfo'] as Map?)?.cast<String, dynamic>()),
      overtime: OvertimeInfo.fromMap((d['overtime'] as Map?)?.cast<String, dynamic>()),
      actualStartAt: dtFromTs(d['actualStartAt']),
      actualEndAt: dtFromTs(d['actualEndAt']),
      createdAt: dtFromTs(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: dtFromTs(d['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() => {
        'status': bookingStatusToString(status),
        'adminDecision': adminDecision,
        'assigned': assigned.toMap(),
        'riderInfo': riderInfo.toMap(),
        'overtime': overtime.toMap(),
        'actualStartAt': tsFromDt(actualStartAt),
        'actualEndAt': tsFromDt(actualEndAt),
        'createdAt': tsFromDt(createdAt),
        'updatedAt': tsFromDt(updatedAt),
        'schemaVersion': 1,
      }..removeWhere((k, v) => v == null);
}