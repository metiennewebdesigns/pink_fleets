import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

class CapturedImage {
  final Uint8List bytes;
  final String contentType;
  final String fileName;
  final int sizeBytes;

  const CapturedImage({
    required this.bytes,
    required this.contentType,
    required this.fileName,
    required this.sizeBytes,
  });
}

class WebImageCaptureHelper {
  Future<CapturedImage?> captureWebPhoto() async {
    final input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.setAttribute('capture', 'environment');
    input.multiple = false;
    input.style.display = 'none';
    html.document.body?.append(input);

    final completer = Completer<CapturedImage?>();

    final sub = input.onChange.listen((_) async {
      try {
        final files = input.files;
        // ignore: avoid_print
        print('files: ${input.files?.length}');
        if (files == null || files.isEmpty) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final file = files.first;
        // ignore: avoid_print
        print('file type: ${file.type} name: ${file.name} size: ${file.size}');

        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoadEnd.first;

        final result = reader.result;
        if (result is! ByteBuffer) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final bytes = Uint8List.view(result);
        if (bytes.isEmpty) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        if (!completer.isCompleted) {
          completer.complete(CapturedImage(
            bytes: bytes,
            contentType: file.type.isNotEmpty ? file.type : 'image/jpeg',
            fileName: file.name.isNotEmpty ? file.name : 'capture.jpg',
            sizeBytes: bytes.length,
          ));
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    // Must be called directly in the button press stack.
    input.click();

    try {
      return await completer.future.timeout(const Duration(seconds: 60), onTimeout: () => null);
    } finally {
      await sub.cancel();
      input.remove();
    }
  }

  Future<CapturedImage?> captureImage() async {
    return captureWebPhoto();
  }
}
