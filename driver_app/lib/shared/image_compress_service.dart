import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ImageCompressResult {
  final Uint8List bytes;
  final int originalSize;
  final int compressedSize;

  const ImageCompressResult({
    required this.bytes,
    required this.originalSize,
    required this.compressedSize,
  });
}

class ImageCompressService {
  ImageCompressResult compressForCallable(Uint8List originalBytes) {
    final originalSize = originalBytes.lengthInBytes;

    try {
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) {
        return ImageCompressResult(
          bytes: originalBytes,
          originalSize: originalSize,
          compressedSize: originalSize,
        );
      }

      final resized = decoded.width > 1280
          ? img.copyResize(decoded, width: 1280)
          : decoded;

      final jpg = img.encodeJpg(resized, quality: 70);
      if (jpg.isEmpty) {
        return ImageCompressResult(
          bytes: originalBytes,
          originalSize: originalSize,
          compressedSize: originalSize,
        );
      }

      final compressed = Uint8List.fromList(jpg);
      return ImageCompressResult(
        bytes: compressed,
        originalSize: originalSize,
        compressedSize: compressed.lengthInBytes,
      );
    } catch (_) {
      return ImageCompressResult(
        bytes: originalBytes,
        originalSize: originalSize,
        compressedSize: originalSize,
      );
    }
  }
}
