import 'package:cloud_firestore/cloud_firestore.dart';
import 'model_converters.dart';

enum VehicleClass { premium, suv, escalade }
enum VehicleStatus { active, inactive, maintenance }

class VehicleModel {
  final String id;
  final String make;
  final String model;
  final int year;
  final String plate;
  final VehicleClass vehicleClass;
  final VehicleStatus status;

  final String? assignedDriverId;

  final DateTime createdAt;
  final DateTime updatedAt;

  const VehicleModel({
    required this.id,
    required this.make,
    required this.model,
    required this.year,
    required this.plate,
    required this.vehicleClass,
    required this.status,
    required this.assignedDriverId,
    required this.createdAt,
    required this.updatedAt,
  });

  static VehicleModel fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return VehicleModel(
      id: doc.id,
      make: (d['make'] ?? '') as String,
      model: (d['model'] ?? '') as String,
      year: (d['year'] ?? 0) as int,
      plate: (d['plate'] ?? '') as String,
      vehicleClass: enumFromString(
        d['vehicleClass'] as String?,
        VehicleClass.values,
        fallback: VehicleClass.premium,
      ),
      status: enumFromString(
        d['status'] as String?,
        VehicleStatus.values,
        fallback: VehicleStatus.active,
      ),
      assignedDriverId: d['assignedDriverId'] as String?,
      createdAt: dtFromTs(d['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: dtFromTs(d['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() => {
        'make': make,
        'model': model,
        'year': year,
        'plate': plate,
        'vehicleClass': enumToString(vehicleClass),
        'status': enumToString(status),
        'assignedDriverId': assignedDriverId,
        'createdAt': tsFromDt(createdAt),
        'updatedAt': tsFromDt(updatedAt),
        'schemaVersion': 1,
      };
}