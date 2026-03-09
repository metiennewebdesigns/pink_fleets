import 'dart:typed_data';

class WebPickedFile {
  final Uint8List bytes;
  final String name;
  final String? contentType;

  const WebPickedFile({required this.bytes, required this.name, this.contentType});
}

Future<WebPickedFile?> pickCapturedImageOnWeb() async => null;

Future<WebPickedFile?> pickCapturedVideoOnWeb() async => null;

Future<WebPickedFile?> pickImageFromLibraryOnWeb() async => null;

Future<WebPickedFile?> pickVideoFromLibraryOnWeb() async => null;
