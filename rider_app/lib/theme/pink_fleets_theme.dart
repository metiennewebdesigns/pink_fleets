import 'package:flutter/material.dart';
import 'package:pf_ui/pf_ui.dart';

export 'package:pf_ui/pf_ui.dart'
    show
        PFColors,
        PFSpacing,
        PFTypography,
        PFAnimations,
        PFCard,
        PFAccentCard,
        PFGlassCard,
        PFButtonPrimary,
        PFGoldButton,
        PFButtonGhost,
        PFChipStatus,
        PFSectionHeader,
        PFModal,
        PFBottomSheet,
        PFTag,
        PFAvatar,
        PFSkeleton,
        PFEmptyState,
        PFLiveDot,
        PFPlateBadge,
        pfGoldGradient,
        pfPinkHeroGradient,
        PFNavItem,
        PFHeaderBar,
        PFBottomNav,
        PFNavRail,
        PFSidebar,
        PFSecondaryButton,
        PFTextField,
        PFMotion,
        PFPressFeedback,
        PFHoverCard,
        PFPulse,
        PFLightColors,
        PFThemeMode;

/// Returns the Pink Fleets Light Luxury theme — default for all apps.
ThemeData pinkFleetsTheme() => pfLightTheme().copyWith(
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: Colors.black87, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return PFColors.pink1;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return PFColors.pink1.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
      ),
    );
