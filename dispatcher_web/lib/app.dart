import 'package:flutter/material.dart';
import 'router/dispatcher_router.dart';
import 'theme/dispatcher_theme.dart';

class DispatcherApp extends StatelessWidget {
  const DispatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pink Fleets Dispatcher',
      theme: dispatcherTheme(),
      routerConfig: dispatcherRouter,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.copyWith(textScaler: const TextScaler.linear(1.0));
        return MediaQuery(data: clamped, child: child ?? const SizedBox.shrink());
      },
    );
  }
}