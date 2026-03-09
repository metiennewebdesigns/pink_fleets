import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

// ---------------------------------------------------------------------------
// Hardcoded Cloud Run URLs for 2nd-gen Cloud Functions.
// These use the run.app domain (not cloudfunctions.net) for reliability on
// Safari / iOS. Update these if the project is re-created.
// ---------------------------------------------------------------------------
const String kDriverUploadMediaEndpoint =
    'https://uploadinspectionmediarequest-pbe56gqazq-uc.a.run.app';

const String kDriverUploadImageEndpoint =
    'https://uploadinspectionimagehttp-pbe56gqazq-uc.a.run.app';

const String kDriverPingEndpoint =
    'https://pingupload-pbe56gqazq-uc.a.run.app';

// Saves inspection notes + checklist server-side (avoids Firestore Web SDK crash).
const String kSaveInspectionEndpoint =
    'https://saveinspectionhttp-pbe56gqazq-uc.a.run.app';

class FunctionMediaUploadResponse {
  final String storagePath;
  final String downloadUrl;
  final int sizeBytes;
  final String contentType;

  const FunctionMediaUploadResponse({
    required this.storagePath,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.contentType,
  });
}

class FunctionMediaUploadService {
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final http.Client _http;

  FunctionMediaUploadService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    http.Client? httpClient,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _http = httpClient ?? http.Client();

  Future<FunctionMediaUploadResponse> uploadInspectionImageCall({
    required String bookingId,
    required String stage,
    required String type,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final preparedBytes = _prepareImageBytesForCallable(bytes);

    final callable = _functions.httpsCallable('uploadInspectionImage');

    final result = await callable.call(<String, dynamic>{
      'bookingId': bookingId,
      'stage': stage,
      'type': _normalizeType(type),
      'fileName': fileName,
      'contentType': contentType,
      'base64': base64Encode(preparedBytes),
    });

    final data = Map<String, dynamic>.from(result.data as Map);
    final storagePath = (data['storagePath'] ?? '').toString();
    final downloadUrl = (data['downloadUrl'] ?? '').toString();

    if (storagePath.isEmpty || downloadUrl.isEmpty) {
      throw Exception('Function upload returned invalid response.');
    }

    return FunctionMediaUploadResponse(
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      sizeBytes: (data['sizeBytes'] as num?)?.toInt() ?? preparedBytes.lengthInBytes,
      contentType: (data['contentType'] ?? contentType).toString(),
    );
  }

  Future<String> probeUploadInspectionImage({
    required String bookingId,
    required String stage,
  }) async {
    final callable = _functions.httpsCallable('uploadInspectionImage');
    try {
      await callable.call(<String, dynamic>{
        'bookingId': bookingId,
        'stage': stage,
        'fileName': 'probe.jpg',
        'contentType': 'image/jpeg',
        'base64': 'AA==',
      });
      return 'unexpected-success';
    } catch (e) {
      return e.toString();
    }
  }

  Uint8List _prepareImageBytesForCallable(Uint8List originalBytes) {
    if (!kIsWeb) return originalBytes;

    try {
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) return originalBytes;

      final resized = decoded.width > 1280
          ? img.copyResize(decoded, width: 1280)
          : decoded;

      final compressed = img.encodeJpg(resized, quality: 70);
      if (compressed.isEmpty) return originalBytes;

      // ignore: avoid_print
      print('Web image compression: original=${originalBytes.lengthInBytes} compressed=${compressed.length}');
      return Uint8List.fromList(compressed);
    } catch (_) {
      return originalBytes;
    }
  }

  Future<FunctionMediaUploadResponse> uploadInspectionMediaRequest({
    required String bookingId,
    required String stage,
    required String type,
    required String fileName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) throw Exception('Missing auth token');

    final uri = Uri.parse(kDriverUploadMediaEndpoint);

    // ignore: avoid_print
    print('[uploadInspectionMediaRequest] POST $uri  bookingId=$bookingId stage=$stage type=$type bytes=${bytes.lengthInBytes}');

    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['bookingId'] = bookingId
      ..fields['stage'] = stage
      ..fields['type'] = _normalizeType(type)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
      );

    final streamed = await _http.send(req);
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      var message = 'Upload failed (${streamed.statusCode})';
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['error'] != null) {
          message = decoded['error'].toString();
        }
      } catch (_) {
        // keep default message
      }
      throw Exception(message);
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw Exception('Invalid function response');
    }

    final data = Map<String, dynamic>.from(decoded);
    final storagePath = (data['storagePath'] ?? '').toString();
    final downloadUrl = (data['downloadUrl'] ?? '').toString();

    if (storagePath.isEmpty || downloadUrl.isEmpty) {
      throw Exception('Function upload returned invalid response.');
    }

    return FunctionMediaUploadResponse(
      storagePath: storagePath,
      downloadUrl: downloadUrl,
      sizeBytes: (data['sizeBytes'] as num?)?.toInt() ?? bytes.lengthInBytes,
      contentType: (data['contentType'] ?? contentType).toString(),
    );
  }

  String _normalizeType(String type) {
    final t = type.toLowerCase().trim();
    if (t == 'photo') return 'image';
    return t;
  }
}
