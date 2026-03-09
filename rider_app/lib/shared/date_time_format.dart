import 'package:intl/intl.dart';

String formatDateTime(DateTime? dt) {
  if (dt == null) return '—';
  return DateFormat('M/d/yyyy h:mm a').format(dt);
}
