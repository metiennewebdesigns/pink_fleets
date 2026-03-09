import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

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
  final ImagePicker _picker = ImagePicker();

  Future<CapturedMedia?> captureImage() async {
    XFile? picked;
    try {
      picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    } catch (_) {
      picked = null;
    }

    if (picked == null) {
      try {
        picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      } catch (_) {
        picked = null;
      }
    }

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final name = _safeXFileName(picked, 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final ext = _extensionFromName(name, 'jpg');
      return CapturedMedia(
        bytes: bytes,
        name: name,
        contentType: _contentTypeForImage(ext, picked.mimeType),
        extension: ext,
        type: MediaCaptureType.image,
      );
    }

    final pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    final f = (pickedFile != null && pickedFile.files.isNotEmpty) ? pickedFile.files.first : null;
    if (f?.bytes == null) return null;

    final ext = _extensionFromName(f!.name, 'jpg');
    return CapturedMedia(
      bytes: f.bytes!,
      name: f.name,
      contentType: _contentTypeForImage(ext, null),
      extension: ext,
      type: MediaCaptureType.image,
    );
  }

  Future<CapturedMedia?> captureVideo() async {
    XFile? picked;
    try {
      picked = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 2));
    } catch (_) {
      picked = null;
    }

    if (picked == null) {
      try {
        picked = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
      } catch (_) {
        picked = null;
      }
    }

    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final name = _safeXFileName(picked, 'video_${DateTime.now().millisecondsSinceEpoch}.mp4');
      final ext = _extensionFromName(name, 'mp4');
      return CapturedMedia(
        bytes: bytes,
        name: name,
        contentType: _contentTypeForVideo(ext, picked.mimeType),
        extension: ext,
        type: MediaCaptureType.video,
      );
    }

    final pickedFile = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
    );
    final f = (pickedFile != null && pickedFile.files.isNotEmpty) ? pickedFile.files.first : null;
    if (f?.bytes == null) return null;

    final ext = _extensionFromName(f!.name, 'mp4');
    return CapturedMedia(
      bytes: f.bytes!,
      name: f.name,
      contentType: _contentTypeForVideo(ext, null),
      extension: ext,
      type: MediaCaptureType.video,
    );
  }

  String _safeXFileName(XFile file, String fallback) {
    try {
      final n = file.name;
      if (n.trim().isNotEmpty) return n.trim();
    } catch (_) {
      // ignore
    }

    final p = file.path;
    if (p.trim().isNotEmpty) {
      final normalized = p.replaceAll('\\', '/');
      final parts = normalized.split('/');
      if (parts.isNotEmpty && parts.last.trim().isNotEmpty) {
        return parts.last.trim();
      }
    }

    return fallback;
  }

  String _extensionFromName(String name, String fallback) {
    final lower = name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot == -1 || dot == lower.length - 1) return fallback;
    return lower.substring(dot + 1);
  }

  String _contentTypeForImage(String ext, String? pickedMime) {
    if (pickedMime != null && pickedMime.startsWith('image/')) return pickedMime;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  String _contentTypeForVideo(String ext, String? pickedMime) {
    if (pickedMime != null && pickedMime.startsWith('video/')) return pickedMime;
    switch (ext) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      default:
        return 'video/mp4';
    }
  }
}
