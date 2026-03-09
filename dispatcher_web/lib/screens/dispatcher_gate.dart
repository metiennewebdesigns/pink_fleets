import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/firebase_providers.dart';
import '../theme/dispatcher_theme.dart';

class DispatcherGate extends ConsumerWidget {
  final Widget child;
  const DispatcherGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return auth.when(
      data: (user) {
        if (user == null) {
          Future.microtask(() => context.go('/login'));
          return const _BrandedLoading(title: 'Dispatcher');
        }

        final ok = ref.watch(isDispatcherProvider);
        return ok.when(
          data: (allowed) {
            if (!allowed) {
              return const _BrandedMessage(
                title: 'Access denied',
                subtitle: 'Not dispatcher/admin.',
              );
            }
            return child;
          },
          loading: () => const _BrandedLoading(title: 'Dispatcher'),
          error: (e, _) => _BrandedMessage(
            title: 'Gate error',
            subtitle: e.toString(),
          ),
        );
      },
      loading: () => const _BrandedLoading(title: 'Dispatcher'),
      error: (e, _) => _BrandedMessage(
        title: 'Auth error',
        subtitle: e.toString(),
      ),
    );
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