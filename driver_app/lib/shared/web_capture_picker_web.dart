import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

class WebPickedFile {
  final Uint8List bytes;
  final String name;
  final String? contentType;

  const WebPickedFile({required this.bytes, required this.name, this.contentType});
}

Future<WebPickedFile?> _pick({required String accept, required bool capture}) async {
  final input = html.FileUploadInputElement()
    ..accept = accept
    ..multiple = false;

  if (capture) {
    input.setAttribute('capture', 'environment');
  }

  final completer = Completer<WebPickedFile?>();

  input.onChange.first.then((_) async {
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final result = reader.result;
    if (result is ByteBuffer) {
      if (!completer.isCompleted) {
        completer.complete(
          WebPickedFile(
            bytes: result.asUint8List(),
            name: file.name,
            contentType: file.type.isEmpty ? null : file.type,
          ),
        );
      }
      return;
    }

    if (!completer.isCompleted) completer.complete(null);
  });

  input.click();

  return completer.future.timeout(const Duration(seconds: 30), onTimeout: () => null);
}

Future<WebPickedFile?> pickCapturedImageOnWeb() {
  return _pick(accept: 'image/*', capture: false);
}

Future<WebPickedFile?> pickCapturedVideoOnWeb() {
  return _pick(accept: 'video/*', capture: false);
}

Future<WebPickedFile?> pickImageFromLibraryOnWeb() {
  return _pick(accept: 'image/*', capture: false);
}

Future<WebPickedFile?> pickVideoFromLibraryOnWeb() {
  return _pick(accept: 'video/*', capture: false);
}
