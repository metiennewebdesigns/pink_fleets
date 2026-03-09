import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class DispatcherFcmTokenService {
  static const String webVapidKey =
      'BJeK9QXnumeqOgwi0beScJ-G7GQgQBo4quqcYEPPJxHLFRxTBz-dZRKq2UqN-vrQWZ44fIKt6uMU06BzMiiqtPs';

  static Future<void> registerDispatcherToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await messaging.getToken(
      vapidKey: (kIsWeb && webVapidKey.isNotEmpty) ? webVapidKey : null,
    );

    if (token == null || token.isEmpty) return;

    final ref = FirebaseFirestore.instance.collection('dispatchers').doc(user.uid);
    await ref.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
