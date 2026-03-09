import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/firebase_providers.dart';
import '../shared/fcm_token_service.dart';
import '../theme/pink_fleets_theme.dart';

import '../features/bookings/bookings_screen.dart';
import '../features/riders/riders_screen.dart';
import '../features/drivers/drivers_screen.dart';
import '../features/vehicles/vehicles_screen.dart'; // ✅ ADD THIS
import '../features/settings/settings_screen.dart';
import '../features/analytics/analytics_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
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
    AdminFcmTokenService.registerAdminToken();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(firebaseAuthProvider);
    final isNarrow = MediaQuery.of(context).size.width < 980;

    final pages = const [
      BookingsScreen(),
      RidersScreen(),
      DriversScreen(),
      VehiclesScreen(), // ✅ USE REAL VEHICLES SCREEN
      SettingsScreen(),
      AnalyticsScreen(),
    ];

    if (isNarrow) {
      return Scaffold(
        backgroundColor: PFColors.canvas,
        appBar: AppBar(
          backgroundColor: PFColors.surface,
          elevation: 0,
          foregroundColor: PFColors.ink,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => _goBackOrPreviousSection(context),
            icon: const Icon(Icons.arrow_back_rounded, color: PFColors.muted),
          ),
          titleSpacing: 12,
          title: Row(
            children: [
              SizedBox(
                height: 32,
                width: 130,
                child: Image.asset(
                  'assets/logo/pink_fleets_logo.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Admin',
                style: TextStyle(
                  color: PFColors.muted,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () async => auth.signOut(),
              icon: const Icon(Icons.logout_rounded, size: 18, color: PFColors.muted),
              tooltip: 'Sign out',
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
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
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Riders',
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
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Analytics',
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
            decoration: const BoxDecoration(
              color: PFColors.surface,
              border: Border(
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
                Container(width: 1, height: 24, color: PFColors.border),
                const SizedBox(width: 12),
                Text(
                  'Admin Dashboard',
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
                    selectedIconTheme: const IconThemeData(color: PFColors.pink1),
                    unselectedIconTheme: const IconThemeData(color: PFColors.muted),
                    selectedLabelTextStyle: const TextStyle(
                      color: PFColors.pink1,
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
                        icon: Icon(Icons.people_outline),
                        selectedIcon: Icon(Icons.people),
                        label: Text('Riders'),
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
                      NavigationRailDestination(
                        icon: Icon(Icons.settings_outlined),
                        selectedIcon: Icon(Icons.settings),
                        label: Text('Settings'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.insights_outlined),
                        selectedIcon: Icon(Icons.insights),
                        label: Text('Analytics'),
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
