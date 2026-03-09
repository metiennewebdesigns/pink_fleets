import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final claimsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return null;
  final token = await user.getIdTokenResult(true);
  return token.claims;
});

final isDispatcherProvider = FutureProvider<bool>((ref) async {
  final claims = await ref.watch(claimsProvider.future);
  final role = claims?['role'];
  // allow admin to enter dispatcher app too
  return role == 'dispatcher' || role == 'admin';
});