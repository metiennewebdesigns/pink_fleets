import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? dtFromTs(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

dynamic tsFromDt(DateTime? d) => d == null ? null : Timestamp.fromDate(d);

GeoPoint? geoFrom(dynamic v) {
  if (v == null) return null;
  if (v is GeoPoint) return v;
  if (v is Map) {
    final lat = (v['lat'] ?? v['latitude']) as num?;
    final lng = (v['lng'] ?? v['longitude']) as num?;
    if (lat == null || lng == null) return null;
    return GeoPoint(lat.toDouble(), lng.toDouble());
  }
  return null;
}

Map<String, dynamic>? geoTo(GeoPoint? g) =>
    g == null ? null : {'lat': g.latitude, 'lng': g.longitude};

String? enumToString(Object? e) => e?.toString().split('.').last;

T enumFromString<T>(
  String? value,
  List<T> values, {
  required T fallback,
}) {
  if (value == null) return fallback;
  for (final v in values) {
    if (enumToString(v) == value) return v;
  }
  return fallback;
}