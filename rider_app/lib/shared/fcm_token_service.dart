import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmTokenService {
  // ✅ Paste your VAPID public key here
  static const String webVapidKey = 'BJeK9QXnumeqOgwi0beScJ-G7GQgQBo4quqcYEPPJxHLFRxTBz-dZRKq2UqN-vrQWZ44fIKt6uMU06BzMiiqtPs';

  static Future<void> registerRiderToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS + Web)
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    String? token;
    try {
      token = await messaging.getToken(
        vapidKey: kIsWeb ? webVapidKey : null,
      );
    } catch (e) {
      // If web messaging isn't fully configured yet, do not crash app
      // ignore: avoid_print
      print('getToken failed: $e');
      return;
    }

    if (token == null || token.isEmpty) return;

    final ref = FirebaseFirestore.instance.collection('riders').doc(user.uid);

    await ref.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}