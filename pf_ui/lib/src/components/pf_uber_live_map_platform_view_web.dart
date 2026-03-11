// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Registers an IFrameElement as a platform view and returns it.
/// The caller can update its [src] to change the embedded map URL.
Object registerPfUberMapViewFactory(String viewType, String domId) {
  final frame = html.IFrameElement()
    ..style.border = '0'
    ..style.width = '100%'
    ..style.height = '100%'
    ..allowFullscreen = true;

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    return frame;
  });

  return frame;
}

/// Updates the iframe src to point to a new embed URL.
void updatePfUberMapViewSrc(Object frame, String url) {
  (frame as html.IFrameElement).src = url;
}
