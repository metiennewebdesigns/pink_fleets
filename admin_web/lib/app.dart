import 'package:flutter/material.dart';
import 'router/admin_router.dart';
import 'theme/pink_fleets_theme.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pink Fleets Admin',
      theme: pinkFleetsTheme(),
      routerConfig: adminRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.copyWith(textScaler: const TextScaler.linear(1.0));
        return MediaQuery(data: clamped, child: child ?? const SizedBox.shrink());
      },
    );
  }
}