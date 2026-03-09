import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/dispatcher_gate.dart';
import '../screens/dispatcher_shell.dart';

final GoRouter dispatcherRouter = GoRouter(
  initialLocation: '/dispatch',
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/dispatch',
      builder: (_, __) => const DispatcherGate(child: DispatcherShell()),
    ),
  ],
);