import 'package:go_router/go_router.dart';

import '../features/auth/presentation/screens/login_screen.dart';
import '../features/booking/presentation/screens/booking_wizard_screen.dart';
import '../features/booking/presentation/screens/quote_screen.dart';
import '../features/portal/presentation/screens/rider_portal_screen.dart';

// ✅ Your path (A)
import '../features/booking/booking_live_screen.dart';

final GoRouter riderRouter = GoRouter(
  initialLocation: '/booking',
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, _) => const LoginScreen(),
    ),
    GoRoute(
      path: '/booking',
      builder: (_, _) => const BookingWizardScreen(embedMode: false),
    ),
    GoRoute(
      path: '/booking/quote',
      builder: (_, _) => const QuoteScreen(),
    ),
    GoRoute(
      path: '/portal',
      builder: (_, _) => const RiderPortalScreen(),
    ),

    /// ✅ Live booking (best)
    /// context.go('/booking/live/$bookingId');
    GoRoute(
      path: '/booking/live/:bookingId',
      builder: (context, state) {
        final bookingId = state.pathParameters['bookingId']!;
        return BookingLiveScreen(bookingId: bookingId);
      },
    ),

    /// ✅ Live booking (fallback)
    /// context.go('/booking/live?bookingId=$bookingId');
    GoRoute(
      path: '/booking/live',
      builder: (context, state) {
        final bookingId = state.uri.queryParameters['bookingId'];
        return BookingLiveScreen(bookingId: bookingId);
      },
    ),

    // keeping your existing route
    GoRoute(
      path: '/app',
      builder: (_, _) => const BookingWizardScreen(embedMode: false),
    ),
  ],
);