import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/firebase_providers.dart';
import '../shared/fcm_token_service.dart';
import '../theme/dispatcher_theme.dart';
import '../features/bookings/dispatch_bookings_screen.dart';
import '../features/drivers/drivers_screen.dart';
import '../features/vehicles/vehicles_screen.dart';

class DispatcherShell extends ConsumerStatefulWidget {
  const DispatcherShell({super.key});

  @override
  ConsumerState<DispatcherShell> createState() => _DispatcherShellState();
}

class _DispatcherShellState extends ConsumerState<DispatcherShell> {
  int index = 0;

  void _goBackOrPreviousSection(BuildContext context) {
    if (index > 0) {
      setState(() => index -= 1);
      return;
    }
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  @override
  void initState() {
    super.initState();
    DispatcherFcmTokenService.registerDispatcherToken();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(firebaseAuthProvider);
    final isNarrow = MediaQuery.of(context).size.width < 980;

    final pages = const [
      DispatchBookingsScreen(),
      DriversScreen(),
      VehiclesScreen(),
    ];

    if (isNarrow) {
      return Scaffold(
        backgroundColor: PFColors.page,
        appBar: AppBar(
          backgroundColor: PFColors.surface,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => _goBackOrPreviousSection(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          titleSpacing: 12,
          title: Row(
            children: [
              SizedBox(
                height: 36,
                width: 148,
                child: Image.asset(
                  'assets/logo/pink_fleets_logo.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Dispatcher',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: PFColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async => auth.signOut(),
              icon: const Icon(Icons.logout_rounded, size: 20),
              color: PFColors.muted,
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Container(height: 1, color: PFColors.border),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: pages[index],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
          height: 72,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge),
              label: 'Drivers',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car),
              label: 'Vehicles',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: PFColors.canvas,
      body: Column(
        children: [
          Container(
            height: 64,
            decoration: BoxDecoration(
              color: PFColors.surface,
              border: const Border(
                bottom: BorderSide(color: PFColors.border),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                SizedBox(
                  height: 40,
                  width: 180,
                  child: Image.asset(
                    'assets/logo/pink_fleets_logo.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 24,
                  color: PFColors.border,
                ),
                const SizedBox(width: 12),
                Text(
                  'Dispatcher Console',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: PFColors.muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                ),
                const SizedBox(width: 12),
                const Spacer(),
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => _goBackOrPreviousSection(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18, color: PFColors.muted),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: () async => auth.signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: PFColors.muted),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 108,
                  decoration: const BoxDecoration(
                    color: PFColors.surface,
                    border: Border(right: BorderSide(color: PFColors.border)),
                  ),
                  child: NavigationRail(
                    backgroundColor: PFColors.surface,
                    selectedIndex: index,
                    onDestinationSelected: (v) => setState(() => index = v),
                    labelType: NavigationRailLabelType.all,
                    useIndicator: true,
                    indicatorColor: PFColors.primarySoft,
                    selectedIconTheme: const IconThemeData(color: PFColors.primary),
                    unselectedIconTheme: const IconThemeData(color: PFColors.muted),
                    selectedLabelTextStyle: const TextStyle(
                      color: PFColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: PFColors.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.receipt_long_outlined),
                        selectedIcon: Icon(Icons.receipt_long),
                        label: Text('Bookings'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.badge_outlined),
                        selectedIcon: Icon(Icons.badge),
                        label: Text('Drivers'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.directions_car_outlined),
                        selectedIcon: Icon(Icons.directions_car),
                        label: Text('Vehicles'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: pages[index],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}