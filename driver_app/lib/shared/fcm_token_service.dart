import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Background handler MUST be a top-level function.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // In background isolate. Keep it lightweight.
  debugPrint("📩 BG message: ${message.data}");
}

class FcmTokenService {
  static const String webVapidKey =
      'BJeK9QXnumeqOgwi0beScJ-G7GQgQBo4quqcYEPPJxHLFRxTBz-dZRKq2UqN-vrQWZ44fIKt6uMU06BzMiiqtPs';

  static Future<void> registerDriverToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken(
      vapidKey: (kIsWeb && webVapidKey.isNotEmpty) ? webVapidKey : null,
    );

    if (token == null || token.isEmpty) return;

    final ref = FirebaseFirestore.instance.collection('drivers').doc(user.uid);
    await ref.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Call this ONCE after login (or on app start if already logged in)
  static void initializeFCMListeners(
    BuildContext context, {
    required void Function(String bookingId, String offerId) onOfferReceived,
  }) {
    // Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _handleMessage(context, message, onOfferReceived);
    });

    // Opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await _handleMessage(context, message, onOfferReceived);
    });

    // Opened from terminated
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) async {
      if (message != null) {
        await _handleMessage(context, message, onOfferReceived);
      }
    });
  }

  static Future<void> _handleMessage(
    BuildContext context,
    RemoteMessage message,
    void Function(String bookingId, String offerId) onOfferReceived,
  ) async {
    final data = message.data;
    final type = (data['type'] ?? '').toString();

    if (type != 'booking_offer') return;

    final bookingId = (data['bookingId'] ?? '').toString();
    final offerId = (data['offerId'] ?? '').toString();

    if (bookingId.isEmpty || offerId.isEmpty) return;

    // ACK immediately
    await ackOffer(offerId);

    // Route to UI
    onOfferReceived(bookingId, offerId);
  }

  static Future<void> ackOffer(String offerId) async {
    try {
      await FirebaseFirestore.instance
          .collection('booking_offers')
          .doc(offerId)
          .set(
        {
          'acknowledgedAt': FieldValue.serverTimestamp(),
          'status': 'delivered',
        },
        SetOptions(merge: true),
      );
      debugPrint('✅ ACK sent for offerId=$offerId');
    } catch (e) {
      debugPrint('❌ ACK failed: $e');
    }
  }

  static Future<Map<String, dynamic>> respondToOffer({
    required String bookingId,
    required String offerId,
    required String decision, // "accept" | "decline"
  }) async {
    try {
      final decisionNorm = decision.trim().toLowerCase();
      if (decisionNorm != 'accept' && decisionNorm != 'decline') {
        throw ArgumentError('decision must be accept|decline');
      }

      await FirebaseFirestore.instance
          .collection('booking_offers')
          .doc(offerId)
          .set(
        {
          'status': decisionNorm == 'accept' ? 'accepted' : 'declined',
          'respondedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return {
        'ok': true,
        'decision': decisionNorm,
        'bookingId': bookingId,
        'offerId': offerId,
      };
    } catch (e) {
      debugPrint('❌ respondToOffer failed: $e');
      return {
        'ok': false,
        'error': e.toString(),
      };
    }
  }
}