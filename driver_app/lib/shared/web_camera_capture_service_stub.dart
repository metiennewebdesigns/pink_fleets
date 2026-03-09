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
  Future<WebCaptureResult?> capturePhoto({required bool preferCamera}) async {
    throw UnsupportedError('Web camera capture is only available on web.');
  }
}
