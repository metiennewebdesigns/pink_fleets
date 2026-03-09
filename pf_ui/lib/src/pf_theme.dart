import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'pf_colors.dart';
import 'pf_typography.dart';
import 'pf_spacing.dart';

/// Returns the Pink Fleets Light Luxury [ThemeData].
///
/// This is the **default** theme for all apps. Clean Apple-inspired white palette.
///
/// Usage:
/// ```dart
/// MaterialApp(theme: pfLightTheme());
/// ```
ThemeData pfLightTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: PFLightColors.primary,
      onPrimary: Colors.white,
      secondary: PFLightColors.gold,
      onSecondary: PFLightColors.ink,
      surface: PFLightColors.surface,
      onSurface: PFLightColors.ink,
      surfaceContainerHighest: PFLightColors.surfaceHigh,
      outline: PFLightColors.border,
      error: PFLightColors.danger,
      onError: Colors.white,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: PFLightColors.canvas,

    textTheme: PFTypography.textTheme.apply(
      bodyColor: PFLightColors.ink,
      displayColor: PFLightColors.ink,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: PFLightColors.surface,
      foregroundColor: PFLightColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.5,
      shadowColor: const Color(0x0F000000),
      titleTextStyle: PFTypography.headlineSmall.copyWith(color: PFLightColors.ink),
      iconTheme: const IconThemeData(color: PFLightColors.ink),
    ),

    dividerTheme: const DividerThemeData(color: PFLightColors.border),

    cardTheme: CardThemeData(
      color: PFLightColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radiusMd),
        side: const BorderSide(color: PFLightColors.border),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: PFLightColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radiusLg),
        side: const BorderSide(color: PFLightColors.border),
      ),
      titleTextStyle: PFTypography.headlineSmall.copyWith(color: PFLightColors.ink),
      contentTextStyle: PFTypography.bodyMedium.copyWith(color: PFLightColors.inkSoft),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: PFLightColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PFSpacing.radiusXl),
        ),
      ),
      dragHandleColor: PFLightColors.muted,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PFLightColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: PFLightColors.primaryGlow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: PFSpacing.base, vertical: PFSpacing.md),
        textStyle: PFTypography.labelLarge,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PFLightColors.ink,
        side: const BorderSide(color: PFLightColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: PFSpacing.base, vertical: PFSpacing.md),
        textStyle: PFTypography.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PFLightColors.primary,
        textStyle: PFTypography.labelLarge,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PFLightColors.surface,
      hintStyle: PFTypography.bodyMedium.copyWith(color: PFLightColors.muted),
      labelStyle: PFTypography.bodyMedium.copyWith(color: PFLightColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radius),
        borderSide: const BorderSide(color: PFLightColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radius),
        borderSide: const BorderSide(color: PFLightColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radius),
        borderSide: const BorderSide(color: PFLightColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radius),
        borderSide: const BorderSide(color: PFLightColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radius),
        borderSide: const BorderSide(color: PFLightColors.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: PFSpacing.base, vertical: PFSpacing.md),
    ),

    chipTheme: base.chipTheme.copyWith(
      backgroundColor: PFLightColors.surfaceHigh,
      side: const BorderSide(color: PFLightColors.border),
      selectedColor: PFLightColors.primarySoft,
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: PFLightColors.ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PFSpacing.radiusFull)),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? PFLightColors.primary : PFLightColors.muted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? PFLightColors.primarySoft : PFLightColors.surfaceHigh),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? PFLightColors.primary : Colors.transparent),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: PFLightColors.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      textColor: PFLightColors.ink,
      iconColor: PFLightColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PFSpacing.radius)),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PFLightColors.surface,
      indicatorColor: PFLightColors.primarySoft,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? PFLightColors.primary : PFLightColors.muted,
          fontSize: 11,
        );
      }),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: PFLightColors.surface,
      indicatorColor: PFLightColors.primarySoft,
      selectedIconTheme: const IconThemeData(color: PFLightColors.primary),
      unselectedIconTheme: const IconThemeData(color: PFLightColors.muted),
      selectedLabelTextStyle: GoogleFonts.inter(color: PFLightColors.primary, fontSize: 11, fontWeight: FontWeight.w800),
      unselectedLabelTextStyle: GoogleFonts.inter(color: PFLightColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PFLightColors.surface,
      contentTextStyle: GoogleFonts.inter(color: PFLightColors.ink, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radius),
        side: const BorderSide(color: PFLightColors.border),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PFLightColors.primary,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PFLightColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
  );
}

/// Returns the canonical Pink Fleets luxury dark [ThemeData].
///
/// Usage:
/// ```dart
/// MaterialApp(theme: pfTheme());
/// ```
ThemeData pfTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: PFColors.primary,
      onPrimary: PFColors.white,
      secondary: PFColors.gold,
      onSecondary: PFColors.black,
      surface: PFColors.surface,
      onSurface: PFColors.ink,
      surfaceContainerHighest: PFColors.surfaceHigh,
      outline: PFColors.border,
      error: PFColors.danger,
      onError: PFColors.white,
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: PFColors.canvas,

    textTheme: PFTypography.textTheme,

    appBarTheme: AppBarTheme(
      backgroundColor: PFColors.canvas,
      foregroundColor: PFColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: PFTypography.headlineSmall,
      iconTheme: const IconThemeData(color: PFColors.ink),
    ),

    dividerTheme: const DividerThemeData(color: PFColors.border),

    cardTheme: CardThemeData(
      color: PFColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radiusMd),
        side: const BorderSide(color: PFColors.border),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: PFColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radiusLg),
        side: const BorderSide(color: PFColors.border),
      ),
      titleTextStyle: PFTypography.headlineSmall,
      contentTextStyle: PFTypography.bodyMedium,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: PFColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PFSpacing.radiusXl),
        ),
      ),
      dragHandleColor: PFColors.muted,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PFColors.primary,
        foregroundColor: PFColors.white,
        elevation: 0,
        shadowColor: PFColors.primaryGlow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: PFSpacing.base, vertical: PFSpacing.md),
        textStyle: PFTypography.labelLarge,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PFColors.ink,
        side: const BorderSide(color: PFColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PFSpacing.radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: PFSpacing.base, vertical: PFSpacing.md),
        textStyle: PFTypography.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PFColors.primary,
        textStyle: PFTypography.labelLarge,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PFColors.surfaceHigh,
      hintStyle: PFTypography.bodyMedium.copyWith(color: PFColors.muted),
      labelStyle: PFTypography.bodyMedium.copyWith(color: PFColors.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radius),
        borderSide: const BorderSide(color: PFColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radius),
        borderSide: const BorderSide(color: PFColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radius),
        borderSide: const BorderSide(color: PFColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radius),
        borderSide: const BorderSide(color: PFColors.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: PFSpacing.base, vertical: PFSpacing.md),
    ),

    chipTheme: base.chipTheme.copyWith(
      backgroundColor: PFColors.surfaceHigh,
      side: const BorderSide(color: PFColors.border),
      selectedColor: PFColors.primarySoft,
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, color: PFColors.ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PFSpacing.radiusFull)),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? PFColors.primary : PFColors.muted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? PFColors.primarySoft : PFColors.surface),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? PFColors.primary : Colors.transparent),
      checkColor: WidgetStateProperty.all(PFColors.white),
      side: const BorderSide(color: PFColors.border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      textColor: PFColors.ink,
      iconColor: PFColors.muted,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PFSpacing.radius)),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PFColors.surface,
      indicatorColor: PFColors.primarySoft,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return GoogleFonts.inter(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? PFColors.primary : PFColors.muted,
          fontSize: 11,
        );
      }),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: PFColors.surface,
      indicatorColor: PFColors.primarySoft,
      selectedIconTheme: const IconThemeData(color: PFColors.primary),
      unselectedIconTheme: const IconThemeData(color: PFColors.muted),
      selectedLabelTextStyle: GoogleFonts.inter(color: PFColors.primary, fontSize: 11, fontWeight: FontWeight.w800),
      unselectedLabelTextStyle: GoogleFonts.inter(color: PFColors.muted, fontSize: 11, fontWeight: FontWeight.w600),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PFColors.surfaceHigh,
      contentTextStyle: GoogleFonts.inter(color: PFColors.ink, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PFSpacing.radius),
        side: const BorderSide(color: PFColors.border),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PFColors.primary,
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PFColors.primary,
      foregroundColor: PFColors.white,
      elevation: 4,
    ),
  );
}
