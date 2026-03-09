import 'package:go_router/go_router.dart';
import '../screens/admin_gate.dart';
import '../screens/login_screen.dart';
import '../screens/admin_shell.dart';

final GoRouter adminRouter = GoRouter(
  initialLocation: '/admin',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminGate(child: AdminShell()),
    ),
  ],
);