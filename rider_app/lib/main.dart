import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'app.dart';
import 'shared/fcm_token_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Anonymous auth for riders (no signup friction)
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }

  // ✅ Do NOT block app startup on web notifications
  runApp(const ProviderScope(child: RiderApp()));

  // ✅ Register token after UI is up (safe)
  Future.microtask(() async {
    try {
      await FcmTokenService.registerRiderToken();
    } catch (e) {
      // Ignore in production; you can print for debugging
      // ignore: avoid_print
      print('FCM token register failed: $e');
    }
  });
}