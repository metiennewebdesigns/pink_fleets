// Web implementation – opens URL in a new browser tab via dart:html.
// Only compiled for web targets.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void openUrl(String url) {
  html.window.open(url, '_blank');
}
