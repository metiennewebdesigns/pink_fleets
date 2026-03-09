import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pf_colors.dart';

/// Inter-based luxury type hierarchy.
class PFTypography {
  PFTypography._();

  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 40,
        fontWeight: FontWeight.w900,
        color: PFColors.ink,
        letterSpacing: -1.2,
        height: 1.1,
      );

  static TextStyle get displayMedium => GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: PFColors.ink,
        letterSpacing: -0.8,
        height: 1.15,
      );

  static TextStyle get headlineLarge => GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: PFColors.ink,
        letterSpacing: -0.5,
        height: 1.2,
      );

  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: PFColors.ink,
        letterSpacing: -0.4,
        height: 1.25,
      );

  static TextStyle get headlineSmall => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: PFColors.ink,
        letterSpacing: -0.3,
      );

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: PFColors.ink,
        letterSpacing: -0.2,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: PFColors.ink,
      );

  static TextStyle get titleSmall => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: PFColors.ink,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: PFColors.ink,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: PFColors.ink,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: PFColors.muted,
        height: 1.5,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: PFColors.ink,
        letterSpacing: 0.1,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: PFColors.ink,
        letterSpacing: 0.2,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: PFColors.muted,
        letterSpacing: 0.4,
      );

  static TextStyle get overline => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: PFColors.muted,
        letterSpacing: 1.2,
      );

  /// Full Inter text-theme for use in MaterialApp.
  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}
