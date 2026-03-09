import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'function_media_upload_service.dart';

enum UploadStatus { uploading, completed, failed }

class UploadProgress {
  final UploadStatus status;
  final double? progress;
  final String? error;
  final UploadResult? result;

  const UploadProgress({
    required this.status,
    this.progress,
    this.error,
    this.result,
  });
}

class UploadResult {
  final String mediaId;
  final String bookingId;
  final String stage;
  final String type;
  final String fileName;
  final String contentType;
  final String storagePath;
  final String downloadUrl;
  final int sizeBytes;
  final String? driverId;

  const UploadResult({
    required this.mediaId,
    required this.bookingId,
    required this.stage,
    required this.type,
    required this.fileName,
    required this.contentType,
    required this.storagePath,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.driverId,
  });

  Map<String, dynamic> toInspectionUploadMap() {
    return {
      'url': downloadUrl,
      'name': fileName,
      'contentType': contentType,
      'path': storagePath,
      'uploadedAt': Timestamp.now(),
      'type': type,
      'stage': stage,
    };
  }
}

class StorageUploadService {
  final FunctionMediaUploadService _functionMediaUploadService;
  static bool _webCallableProbeDone = false;

  StorageUploadService({
    FunctionMediaUploadService? functionMediaUploadService,
  }) : _functionMediaUploadService = functionMediaUploadService ?? FunctionMediaUploadService();

  bool _isFirestoreInternalAssertion(Object e) {
    if (e is! FirebaseException) return false;
    final m = (e.message ?? '').toUpperCase();
    return m.contains('INTERNAL ASSERTION FAILED') || m.contains('UNEXPECTED STATE (ID:');
  }

  Stream<UploadProgress> uploadInspectionMedia({
    required FirebaseFirestore db,
    required String bookingId,
    required String stage,
    required String type,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String extension,
    required String? driverId,
  }) {
    final controller = StreamController<UploadProgress>();

    final normalizedType = _normalizeType(type);
    final normalizedFileName = _ensureFileNameHasExtension(fileName, extension, normalizedType);

    final mediaRef = db.collection('bookings').doc(bookingId).collection('inspectionMedia').doc();

    Future<void>(() async {
      StreamSubscription<TaskSnapshot>? sub;
      try {
        // On web the Cloud Function writes all Firestore records server-side.
        // Calling _safeSetMediaUploading from the web SDK triggers a
        // Timestamp-in-arrayUnion crash (INTERNAL ASSERTION FAILED).
        if (!kIsWeb) {
          await _safeSetMediaUploading(
            mediaRef: mediaRef,
            bookingId: bookingId,
            driverId: driverId,
            stage: stage,
            type: normalizedType,
            fileName: normalizedFileName,
            contentType: contentType,
          );
        }

        controller.add(const UploadProgress(status: UploadStatus.uploading));

        if (kIsWeb) {
          if (normalizedType == 'image' && !_webCallableProbeDone) {
            _webCallableProbeDone = true;
            final probe = await _functionMediaUploadService.probeUploadInspectionImage(
              bookingId: bookingId,
              stage: stage,
            );
            if (!probe.toLowerCase().contains('empty-file')) {
              throw Exception('Callable probe failed: $probe');
            }
          }

          final functionResult = normalizedType == 'image'
              ? await _functionMediaUploadService.uploadInspectionImageCall(
                  bookingId: bookingId,
                  stage: stage,
                  type: normalizedType,
                  fileName: normalizedFileName,
                  contentType: contentType,
                  bytes: bytes,
                )
              : await _functionMediaUploadService.uploadInspectionMediaRequest(
                  bookingId: bookingId,
                  stage: stage,
                  type: normalizedType,
                  fileName: normalizedFileName,
                  contentType: contentType,
                  bytes: bytes,
                );

          final result = UploadResult(
            mediaId: mediaRef.id,
            bookingId: bookingId,
            stage: stage,
            type: normalizedType,
            fileName: normalizedFileName,
            contentType: functionResult.contentType,
            storagePath: functionResult.storagePath,
            downloadUrl: functionResult.downloadUrl,
            sizeBytes: functionResult.sizeBytes,
            driverId: driverId,
          );

          // On web the Cloud Function has already written the Firestore records.
          // Skip client-side writes to avoid Timestamp-in-arrayUnion crash.
          if (!kIsWeb) {
            await _safeSetMediaUploaded(mediaRef, result);
            await _safeSetDriverInspection(db, bookingId, stage, driverId, result);
          }

          controller.add(const UploadProgress(status: UploadStatus.uploading, progress: 1));
          controller.add(UploadProgress(status: UploadStatus.completed, progress: 1, result: result));
          return;
        }

        if (kIsWeb) {
          throw Exception('BUG: firebase_storage must NOT be called on web');
        }

        final storage = FirebaseStorage.instance;
        storage.setMaxUploadRetryTime(const Duration(seconds: 30));
        storage.setMaxOperationRetryTime(const Duration(seconds: 30));
        storage.setMaxDownloadRetryTime(const Duration(seconds: 30));

        final ts = DateTime.now().millisecondsSinceEpoch;
        final ext = extension.isEmpty
            ? _extensionFromName(normalizedFileName, normalizedType == 'image' ? 'jpg' : 'mp4')
            : extension;
        final storagePath = 'bookings/$bookingId/inspections/$stage/${ts}_$normalizedType.$ext';
        final ref = storage.ref().child(storagePath);

        final meta = SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'bookingId': bookingId,
            if (driverId != null) 'driverId': driverId,
            'stage': stage,
            'type': normalizedType,
            'createdAt': DateTime.now().toIso8601String(),
          },
        );

        final payload = Uint8List.fromList(bytes);
        final UploadTask task = ref.putData(payload, meta);

        sub = task.snapshotEvents.listen((snap) {
          final total = snap.totalBytes;
          final transferred = snap.bytesTransferred;
          final progress = total > 0 ? transferred / total : null;
          controller.add(UploadProgress(status: UploadStatus.uploading, progress: progress));
        });

        final done = await task.timeout(
          const Duration(minutes: 10),
          onTimeout: () async {
            await task.cancel();
            throw Exception('Upload timed out. Please try again.');
          },
        );

        final url = await done.ref
            .getDownloadURL()
            .timeout(const Duration(seconds: 30), onTimeout: () => throw Exception('Upload completed but URL fetch timed out.'));

        final result = UploadResult(
          mediaId: mediaRef.id,
          bookingId: bookingId,
          stage: stage,
          type: normalizedType,
          fileName: normalizedFileName,
          contentType: contentType,
          storagePath: storagePath,
          downloadUrl: url,
          sizeBytes: done.totalBytes,
          driverId: driverId,
        );

        if (!kIsWeb) {
          await _safeSetMediaUploaded(mediaRef, result);
          await _safeSetDriverInspection(db, bookingId, stage, driverId, result);
        }

        controller.add(UploadProgress(status: UploadStatus.completed, progress: 1, result: result));
      } catch (e) {
        final message = e is FirebaseException
            ? '${e.plugin.isNotEmpty ? '${e.plugin}: ' : ''}${e.code}${(e.message ?? '').isEmpty ? '' : ': ${e.message}'}'
            : e.toString();

        try {
          if (!kIsWeb) {
            await mediaRef.set({
              'status': 'failed',
              'error': message,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        } catch (_) {
          // ignore logging failures
        }

        controller.add(UploadProgress(status: UploadStatus.failed, error: message));
      } finally {
        await sub?.cancel();
        await controller.close();
      }
    });

    return controller.stream;
  }

  Future<void> _safeSetMediaUploading({
    required DocumentReference<Map<String, dynamic>> mediaRef,
    required String bookingId,
    required String? driverId,
    required String stage,
    required String type,
    required String fileName,
    required String contentType,
  }) async {
    final initialStoragePath = 'bookings/$bookingId/inspections/$stage/pending_$type/$fileName';
    try {
      await mediaRef.set({
        'bookingId': bookingId,
        if (driverId != null) 'driverId': driverId,
        'stage': stage,
        'type': type,
        'fileName': fileName,
        'contentType': contentType,
        'storagePath': initialStoragePath,
        'status': 'uploading',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!kIsWeb || !_isFirestoreInternalAssertion(e)) rethrow;
    }
  }

  Future<void> _safeSetMediaUploaded(
    DocumentReference<Map<String, dynamic>> mediaRef,
    UploadResult result,
  ) async {
    try {
      await mediaRef.set({
        'bookingId': result.bookingId,
        if (result.driverId != null) 'driverId': result.driverId,
        'stage': result.stage,
        'type': result.type,
        'fileName': result.fileName,
        'contentType': result.contentType,
        'storagePath': result.storagePath,
        'downloadUrl': result.downloadUrl,
        'sizeBytes': result.sizeBytes,
        'status': 'uploaded',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!kIsWeb || !_isFirestoreInternalAssertion(e)) rethrow;
    }
  }

  Future<void> _safeSetDriverInspection(
    FirebaseFirestore db,
    String bookingId,
    String stage,
    String? driverId,
    UploadResult result,
  ) async {
    try {
      await db
          .collection('bookings')
          .doc(bookingId)
          .collection('driver_inspections')
          .doc(stage)
          .set({
        'stage': stage,
        if (driverId != null) 'driverId': driverId,
        'updatedAt': FieldValue.serverTimestamp(),
        'uploads': FieldValue.arrayUnion([result.toInspectionUploadMap()]),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!kIsWeb || !_isFirestoreInternalAssertion(e)) rethrow;
    }
  }

  String _normalizeType(String type) {
    final t = type.toLowerCase().trim();
    if (t == 'photo') return 'image';
    return t;
  }

  String _ensureFileNameHasExtension(String fileName, String extension, String type) {
    final safe = fileName.trim().isEmpty
        ? '${type == 'image' ? 'capture' : 'video'}_${DateTime.now().millisecondsSinceEpoch}'
        : fileName.trim();
    if (safe.contains('.')) return safe;

    final ext = extension.trim().isNotEmpty
        ? extension.trim().replaceFirst('.', '')
        : (type == 'image' ? 'jpg' : 'mp4');
    return '$safe.$ext';
  }

  String _extensionFromName(String name, String fallback) {
    final lower = name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot == -1 || dot == lower.length - 1) return fallback;
    return lower.substring(dot + 1);
  }
}
