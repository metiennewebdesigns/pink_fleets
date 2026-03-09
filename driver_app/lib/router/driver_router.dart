import 'package:go_router/go_router.dart';
import '../screens/auth_gate.dart';
import '../screens/login_screen.dart';
import '../screens/driver_home.dart';
import '../screens/trip_detail.dart';

final GoRouter driverRouter = GoRouter(
  initialLocation: '/driver',
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: '/driver',
      builder: (_, __) => const AuthGate(child: DriverHome()),
    ),
    GoRoute(
      path: '/driver/trip/:id',
      builder: (_, state) => AuthGate(
        child: TripDetail(bookingId: state.pathParameters['id']!),
      ),
    ),
  ],
);