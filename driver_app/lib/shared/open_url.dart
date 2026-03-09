// Conditional export: on web uses dart:html window.open; on native is a no-op.
export 'open_url_stub.dart' if (dart.library.html) 'open_url_web.dart';
