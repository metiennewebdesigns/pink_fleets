// Web implementation – opens URL in a new browser tab via dart:html.
// Only compiled for web targets.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void openUrl(String url) {
  html.window.open(url, '_blank');
}
