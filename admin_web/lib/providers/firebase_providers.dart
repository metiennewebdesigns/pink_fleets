import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

final idTokenClaimsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final auth = ref.watch(firebaseAuthProvider);
  final user = auth.currentUser;
  if (user == null) return null;
  final token = await user.getIdTokenResult(true); // force refresh
  return token.claims;
});

final isAdminProvider = FutureProvider<bool>((ref) async {
  final claims = await ref.watch(idTokenClaimsProvider.future);
  if (claims == null) return false;
  return claims['role'] == 'admin';
});