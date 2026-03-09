import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

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

class WebCaptureDiagnostics {
  final int filesLength;
  final String fileName;
  final String fileType;
  final int fileSize;
  final int bytesLength;

  const WebCaptureDiagnostics({
    required this.filesLength,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.bytesLength,
  });

  String toHumanText() {
    return 'files=$filesLength\n'
        'name=$fileName\n'
        'type=$fileType\n'
        'fileSize=$fileSize\n'
        'bytes=$bytesLength';
  }
}

class WebCaptureResult {
  final CapturedImage? image;
  final WebCaptureDiagnostics diagnostics;

  const WebCaptureResult({required this.image, required this.diagnostics});
}

class WebCameraCaptureService {
  html.FileUploadInputElement? _activeInput;

  Future<Uint8List> readFileBytes(html.File file) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();

    reader.onLoad.listen((event) {
      final result = reader.result;
      if (result is Uint8List) {
        completer.complete(result);
      } else if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
      } else {
        completer.completeError(Exception('Unexpected FileReader result type'));
      }
    });

    reader.onError.listen((event) {
      completer.completeError(reader.error ?? Exception('FileReader error'));
    });

    reader.readAsArrayBuffer(file);

    return completer.future;
  }

  Future<WebCaptureResult?> capturePhoto({required bool preferCamera}) {
    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = false
      ..style.display = 'none';

    if (preferCamera) {
      input.setAttribute('capture', 'environment');
    } else {
      input.removeAttribute('capture');
    }

    final completer = Completer<WebCaptureResult?>();

    Future<void> finish(WebCaptureResult? result) async {
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      input.remove();
      if (identical(_activeInput, input)) {
        _activeInput = null;
      }
    }

    // 1) create input
    // 2) attach onChange listener
    input.onChange.first.then((_) async {
      final files = input.files;
      // ignore: avoid_print
      print('files: ${files?.length}');

      if (files == null || files.isEmpty) {
        await finish(
          const WebCaptureResult(
            image: null,
            diagnostics: WebCaptureDiagnostics(
              filesLength: 0,
              fileName: '',
              fileType: '',
              fileSize: 0,
              bytesLength: 0,
            ),
          ),
        );
        return;
      }

      final file = files.first;
      // ignore: avoid_print
      print('file type: ${file.type} name: ${file.name} size: ${file.size}');

      final bytes = await readFileBytes(file);
      // ignore: avoid_print
      print('bytes length: ${bytes.length}');

      if (bytes.isEmpty) {
        throw Exception('FileReader returned empty bytes');
      }

      final diagnostics = WebCaptureDiagnostics(
        filesLength: files.length,
        fileName: file.name,
        fileType: file.type,
        fileSize: file.size,
        bytesLength: bytes.length,
      );

      final captured = CapturedImage(
        bytes: bytes,
        contentType: file.type.isNotEmpty ? file.type : 'image/jpeg',
        fileName: file.name.isNotEmpty ? file.name : 'capture.jpg',
        sizeBytes: bytes.length,
      );

      await finish(WebCaptureResult(image: captured, diagnostics: diagnostics));
    }).catchError((e) async {
      await finish(
        const WebCaptureResult(
          image: null,
          diagnostics: WebCaptureDiagnostics(
            filesLength: 0,
            fileName: '',
            fileType: 'error',
            fileSize: 0,
            bytesLength: 0,
          ),
        ),
      );
    });

    // 3) append input to DOM
    html.document.body?.append(input);
    _activeInput = input;

    // Synchronous click with no await before it.
    // 4) call input.click()
    input.click();

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () async {
        input.remove();
        if (identical(_activeInput, input)) {
          _activeInput = null;
        }
        return const WebCaptureResult(
          image: null,
          diagnostics: WebCaptureDiagnostics(
            filesLength: 0,
            fileName: '',
            fileType: 'timeout',
            fileSize: 0,
            bytesLength: 0,
          ),
        );
      },
    );
  }
}
