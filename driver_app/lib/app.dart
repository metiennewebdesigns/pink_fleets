import 'package:flutter/material.dart';
import 'router/driver_router.dart';
import 'theme/driver_theme.dart';

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pink Fleets Driver',
      theme: driverTheme(),
      routerConfig: driverRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.copyWith(textScaler: const TextScaler.linear(1.0));
        return MediaQuery(data: clamped, child: child ?? const SizedBox.shrink());
      },
    );
  }
}