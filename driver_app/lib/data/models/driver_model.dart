import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_converters.dart';

enum DriverStatus { offline, online, onTrip }

class DriverModel {
  final String id; // same as auth uid
  final String firstName;
  final String lastName;
  final String phone;
  final DriverStatus status;

  final GeoPoint? lastLocation;
  final DateTime? lastLocationAt;

  final String? activeVehicleId;

  // Notifications
  final String? fcmToken;
  final DateTime? fcmUpdatedAt;

  // Ops
  final DateTime createdAt;
  final DateTime updatedAt;

  const DriverModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.status,
    required this.lastLocation,
    required this.lastLocationAt,
    required this.activeVehicleId,
    required this.fcmToken,
    required this.fcmUpdatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static DriverModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DriverModel(
      id: doc.id,
      firstName: (d['firstName'] ?? '') as String,
      lastName: (d['lastName'] ?? '') as String,
      phone: (d['phone'] ?? '') as String,
      status: enumFromString(
        d['status'] as String?,
        DriverStatus.values,
        fallback: DriverStatus.offline,
      ),
      lastLocation: d['lastLocation'] as GeoPoint? ?? geoFrom(d['lastLocation']),
      lastLocationAt: dtFromTs(d['lastLocationAt']),
      activeVehicleId: d['activeVehicleId'] as String?,
      fcmToken: d['fcmToken'] as String?,
      fcmUpdatedAt: dtFromTs(d['fcmUpdatedAt']),
      createdAt: dtFromTs(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: dtFromTs(d['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() => {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'status': enumToString(status),
        'lastLocation': lastLocation,
        'lastLocationAt': tsFromDt(lastLocationAt),
        'activeVehicleId': activeVehicleId,
        'fcmToken': fcmToken,
        'fcmUpdatedAt': tsFromDt(fcmUpdatedAt),
        'createdAt': tsFromDt(createdAt),
        'updatedAt': tsFromDt(updatedAt),
        'schemaVersion': 1,
      };
}