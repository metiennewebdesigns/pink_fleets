import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

import 'web_image_capture_helper.dart';

enum MediaCaptureType { image, video }

class CapturedMedia {
  final Uint8List bytes;
  final String name;
  final String? contentType;
  final String extension;
  final MediaCaptureType type;
  final Object? webFile;

  CapturedMedia({
    required this.bytes,
    required this.name,
    required this.contentType,
    required this.extension,
    required this.type,
    this.webFile,
  });

  int get sizeBytes => bytes.lengthInBytes;
}

class MediaCaptureService {
  final WebImageCaptureHelper _webImageCapture = WebImageCaptureHelper();

  Uint8List? _coerceBytes(Object? result) {
    if (result == null) return null;
    if (result is ByteBuffer) return result.asUint8List();
    if (result is Uint8List) return result;
    if (result is List) {
      final out = Uint8List(result.length);
      for (var i = 0; i < result.length; i++) {
        final v = result[i];
        if (v is int) {
          out[i] = v;
        } else if (v is num) {
          out[i] = v.toInt();
        } else {
          return null;
        }
      }
      return out;
    }
    return null;
  }

  Future<Uint8List?> _readAsDataUrlBytes(html.File file) async {
    final dataUrlReader = html.FileReader();
    dataUrlReader.readAsDataUrl(file);
    await dataUrlReader.onLoad.first;
    final data = dataUrlReader.result;
    if (data is String) {
      final comma = data.indexOf(',');
      if (comma > -1 && comma + 1 < data.length) {
        try {
          return base64Decode(data.substring(comma + 1));
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  Future<Uint8List?> _readFileBytes(html.File file, {required bool preferDataUrl}) async {
    if (preferDataUrl) {
      final d = await _readAsDataUrlBytes(file);
      if (d != null && d.isNotEmpty) return d;
    }

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;

    final bytes = _coerceBytes(reader.result);
    if (bytes != null && bytes.isNotEmpty) return bytes;

    if (!preferDataUrl) {
      final d = await _readAsDataUrlBytes(file);
      if (d != null && d.isNotEmpty) return d;
    }

    return null;
  }

  Future<CapturedMedia?> captureImage() {
    return _captureImageViaHtmlInput();
  }

  Future<CapturedMedia?> captureVideo() {
    return _pickCapture(
      accept: 'video/*',
      type: MediaCaptureType.video,
      preferDataUrl: false,
    );
  }

  Future<CapturedMedia?> _captureImageViaHtmlInput() async {
    final image = await _webImageCapture.captureImage();
    if (image == null || image.bytes.isEmpty) return null;

    final extension = _extensionFromName(image.fileName, 'jpg');
    return CapturedMedia(
      bytes: image.bytes,
      name: image.fileName,
      contentType: image.contentType,
      extension: extension,
      type: MediaCaptureType.image,
      webFile: null,
    );
  }

  Future<CapturedMedia?> _pickCapture({
    required String accept,
    required MediaCaptureType type,
    required bool preferDataUrl,
  }) async {
    final input = html.FileUploadInputElement()
      ..accept = accept
      ..multiple = false
      ..style.display = 'none';

    input.setAttribute('capture', 'environment');
    html.document.body?.append(input);

    final completer = Completer<CapturedMedia?>();
    late StreamSubscription<html.Event> changeSub;
    late StreamSubscription<html.Event> inputSub;
    late Timer filePollTimer;
    bool sawAnyFile = false;

    void completeIfNeeded(CapturedMedia? media) {
      if (completer.isCompleted) return;
      completer.complete(media);
    }

    Future<void> handleSelection() async {
      if (completer.isCompleted) return;
      final files = input.files;
      final file = (files != null && files.length > 0) ? files[0] : null;
      if (file == null) {
        return;
      }
      sawAnyFile = true;

      final bytes = await _readFileBytes(file, preferDataUrl: preferDataUrl);

      if (bytes != null && bytes.isNotEmpty) {
        final name = file.name.isNotEmpty ? file.name : _fallbackName(type);
        final contentType = file.type.isEmpty ? null : file.type;
        final extension = _extensionFromName(name, type == MediaCaptureType.image ? 'jpg' : 'mp4');

        completeIfNeeded(
          CapturedMedia(
            bytes: bytes,
            name: name,
            contentType: contentType,
            extension: extension,
            type: type,
            webFile: file,
          ),
        );
        return;
      }

      completeIfNeeded(null);
    }

    changeSub = input.onChange.listen((_) {
      handleSelection();
    });
    inputSub = input.onInput.listen((_) {
      handleSelection();
    });

    // Safari fallback: poll selected files briefly after capture/gallery returns.
    filePollTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (completer.isCompleted) return;
      final files = input.files;
      final hasFile = files != null && files.length > 0;
      if (hasFile) {
        handleSelection();
      }
    });

    html.window.onFocus.first.then((_) async {
      // User returned from camera/gallery. On iOS Safari the file may appear
      // later than focus restoration, so we DO NOT complete null here.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (completer.isCompleted) return;
      final files = input.files;
      final hasFile = files != null && files.length > 0;
      if (hasFile && !sawAnyFile) {
        handleSelection();
      }
    });

    input.click();

    try {
      return await completer.future.timeout(const Duration(seconds: 45), onTimeout: () => null);
    } finally {
      await changeSub.cancel();
      await inputSub.cancel();
      filePollTimer.cancel();
      input.remove();
    }
  }

  String _fallbackName(MediaCaptureType type) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return type == MediaCaptureType.image ? 'capture_$ts.jpg' : 'video_$ts.mp4';
  }

  String _extensionFromName(String name, String fallback) {
    final lower = name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot == -1 || dot == lower.length - 1) return fallback;
    return lower.substring(dot + 1);
  }
}
