import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/firebase_providers.dart';

class AdminGate extends ConsumerWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/login');
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final isAdmin = ref.watch(isAdminProvider);
        return isAdmin.when(
          data: (ok) {
            if (!ok) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Access denied.\nThis account is not an admin.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return child;
          },
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) =>
              Scaffold(body: Center(child: Text('Admin check failed: $e'))),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Auth error: $e'))),
    );
  }
}
