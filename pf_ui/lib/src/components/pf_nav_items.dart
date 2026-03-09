/// Shared navigation item model — used by [PFBottomNav], [PFNavRail] and
/// [PFSidebar] so a single list of items drives all three layouts.
///
/// ```dart
/// const _tabs = [
///   PFNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
///   PFNavItem(icon: Icons.history_outlined, label: 'Trips'),
///   PFNavItem(icon: Icons.person_outline, label: 'Profile'),
/// ];
/// ```
class PFNavItem {
  final dynamic icon;       // IconData or Widget
  final dynamic activeIcon; // IconData or Widget — shown when selected
  final String label;
  final String? tooltip;

  const PFNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.tooltip,
  });
}
