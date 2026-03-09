import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

String formatDateTime(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('M/d/yyyy h:mm a').format(dt);
}

String formatTimestamp(dynamic v) {
  if (v == null) return '—';
  if (v is Timestamp) return formatDateTime(v.toDate());
  if (v is DateTime) return formatDateTime(v);
  if (v is String) {
    final parsed = DateTime.tryParse(v);
    return formatDateTime(parsed);
  }
  return v.toString();
}
