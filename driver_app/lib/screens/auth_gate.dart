import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../providers/firebase_providers.dart';
import '../theme/driver_theme.dart';

class AuthGate extends ConsumerWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/login');
          });
          return const _BrandedLoading(title: 'Driver');
        }

        final db = ref.watch(firestoreProvider);
        return FutureBuilder<bool>(
          future: _isAuthorizedDriver(user, db),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _BrandedLoading(title: 'Driver');
            }

            if (snap.data == true) return child;

            return const _BrandedMessage(
              title: 'Not authorized as driver',
              subtitle: 'This account does not have driver access.',
            );
          },
        );
      },
      loading: () => const _BrandedLoading(title: 'Driver'),
      error: (e, _) =>
          _BrandedMessage(title: 'Auth error', subtitle: e.toString()),
    );
  }

  Future<bool> _isAuthorizedDriver(User user, FirebaseFirestore db) async {
    try {
      final token = await user.getIdTokenResult(true);
      final role = (token.claims?['role'] ?? '').toString();
      if (role == 'driver' || role == 'admin') return true;
    } catch (_) {
      // fallback to Firestore doc check
    }

    try {
      final snap = await db.collection('drivers').doc(user.uid).get();
      if (!snap.exists) return false;
      final data = snap.data() ?? {};
      final active = (data['active'] ?? true) == true;
      return active;
    } catch (_) {
      return false;
    }
  }
}

class _BrandedLoading extends StatelessWidget {
  final String title;
  const _BrandedLoading({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LogoCard(title: '$title Portal'),
              const SizedBox(height: 14),
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              Text('Loading…', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandedMessage extends StatelessWidget {
  final String title;
  final String subtitle;
  const _BrandedMessage({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LogoCard(title: 'Pink Fleets'),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoCard extends StatelessWidget {
  final String title;
  const _LogoCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PFColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PFColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 56,
            width: 240,
            child: Image.asset(
              'assets/logo/pink_fleets_logo.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const Spacer(),
          Container(height: 28, width: 1, color: PFColors.border),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
