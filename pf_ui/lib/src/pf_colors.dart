import 'package:flutter/material.dart';

/// Pink Fleets Light Luxury colour palette.
///
/// All apps share these tokens. Reference via `PFColors.canvas`, `PFColors.primary`, etc.
/// This palette is Light Luxury only — no dark mode.
class PFColors {
  PFColors._();

  // ── Backgrounds ─────────────────────────────────────────────────────────
  /// Soft off-white — main scaffold / page background.
  static const Color canvas = Color(0xFFF5F6FA);

  /// Pure white — default card / surface.
  static const Color surface = Color(0xFFFFFFFF);

  /// Slightly off-white elevated surface — panels, modals, inputs.
  static const Color surfaceHigh = Color(0xFFF0F1F5);

  /// Light glass overlay tint — for blur/glass effects on white backgrounds.
  static const Color surfaceGlass = Color(0xB3FFFFFF); // 70% white

  // ── Borders ──────────────────────────────────────────────────────────────
  static const Color border = Color(0xFFE6E8EF);
  static const Color borderStrong = Color(0xFFD1D5DB);

  // ── Text ─────────────────────────────────────────────────────────────────
  /// Primary text — near-black for high contrast on white.
  static const Color ink = Color(0xFF0B0B10);

  /// Secondary text — dark charcoal.
  static const Color inkSoft = Color(0xFF1F2937);

  /// Muted / placeholder / caption — #4B5563 per design spec.
  static const Color muted = Color(0xFF4B5563);

  // ── Brand ────────────────────────────────────────────────────────────────
  /// Pink brand accent — #E83E8C per design spec.
  static const Color primary = Color(0xFFE83E8C);
  static const Color primarySoft = Color(0x1AE83E8C); // ~10 % alpha on white
  static const Color primaryGlow = Color(0x33E83E8C); // ~20 % alpha on white

  // Aliases kept for backward compat
  static const Color pink1 = primary;
  static const Color pink2 = Color(0xFFFF5B82);
  static const Color pinkDeep = primary;
  static const Color pink = pink2;
  static const Color blush = Color(0x1AE83E8C);
  static const Color primarySoftLegacy = Color(0xFFFCE7F3); // light pink tint (was dark in old palette)

  // ── Gold ─────────────────────────────────────────────────────────────────
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldDeep = Color(0xFFB88917);
  static const Color goldLight = Color(0xFFFFE08A);
  static const Color goldSoft = Color(0x1AD4AF37);
  static const Color goldBase = gold;

  // ── Semantic — darker shades for WCAG contrast on white ─────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0x1A16A34A);

  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0x1AD97706);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0x1ADC2626);

  static const Color info = Color(0xFF0284C7);
  static const Color infoSoft = Color(0x1A0284C7);

  // ── Misc ─────────────────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Semantic aliases
  static const Color cardSurface = surface;

  // Legacy aliases
  /// @deprecated Use [canvas] instead.
  static const Color page = canvas;
  /// @deprecated Use [inkSoft] instead.
  static const Color subtle = Color(0xFF6B7280);
  static const Color accent = info;

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient pinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE83E8C), Color(0xFFFF5B82)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB88917), Color(0xFFD4AF37), Color(0xFFFFE08A), Color(0xFFD4AF37)],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const LinearGradient canvasGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8F9FC), Color(0xFFF5F6FA)],
  );

  // ── Status colours by name ───────────────────────────────────────────────
  static Color statusColor(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'accepted':
      case 'driver_assigned':
      case 'confirmed':
        return primary;
      case 'en_route':
        return warning;
      case 'arrived':
        return info;
      case 'in_progress':
        return success;
      case 'completed':
        return muted;
      case 'cancelled':
        return danger;
      default:
        return inkSoft;
    }
  }
}

/// Legacy helpers — kept so existing code using pfGoldGradient() still works.
LinearGradient pfGoldGradient() => PFColors.goldGradient;
LinearGradient pfPinkHeroGradient() => PFColors.pinkGradient;

// ─────────────────────────────────────────────────────────────────────────────
// THEME MODE — switch at runtime for toggle support
// ─────────────────────────────────────────────────────────────────────────────

/// Three-way luxury theme selector.
/// Default: [PFThemeMode.lightLuxury].
enum PFThemeMode {
  /// Light Luxury — Apple-inspired off-white. Default for all apps.
  lightLuxury,

  /// Dark Luxury — deep charcoal glass-morphism. Original palette.
  darkLuxury,

  /// Mixed — light forms/portals, dark map/hero overlays.
  mixed,
}

// ─────────────────────────────────────────────────────────────────────────────
// LIGHT LUXURY PALETTE
// Background: #F5F6FA · Surface: #FFFFFF · Primary text: #0B0B10
// ─────────────────────────────────────────────────────────────────────────────

/// Light Luxury colour palette — clean Apple-style white theme.
///
/// Use on all app login screens and form pages by default.
class PFLightColors {
  PFLightColors._();

  // ── Backgrounds ─────────────────────────────────────────────────────────
  /// Soft off-white page background.
  static const Color canvas = Color(0xFFF5F6FA);

  /// Pure white card / surface.
  static const Color surface = Color(0xFFFFFFFF);

  /// Slightly off-white elevated surface — inputs, inner panels.
  static const Color surfaceHigh = Color(0xFFF0F1F5);

  // ── Borders ──────────────────────────────────────────────────────────────
  static const Color border = Color(0xFFE6E8EF);
  static const Color borderStrong = Color(0xFFD1D5DB);

  // ── Text ─────────────────────────────────────────────────────────────────
  /// Primary text — near-black for high contrast on white.
  static const Color ink = Color(0xFF0B0B10);

  /// Secondary text — dark charcoal.
  static const Color inkSoft = Color(0xFF1F2937);

  /// Muted / placeholder / caption — #4B5563 per design spec.
  static const Color muted = Color(0xFF4B5563);

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFFE83E8C);
  static const Color primarySoft = Color(0x1AE83E8C); // ~10 % alpha
  static const Color primaryGlow = Color(0x33E83E8C); // ~20 % alpha

  // ── Gold ─────────────────────────────────────────────────────────────────
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldSoft = Color(0x1AD4AF37);

  // ── Semantic (darker shades for accessibility on white) ──────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0x1216A34A);

  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0x12D97706);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0x12DC2626);

  static const Color info = Color(0xFF0284C7);
  static const Color infoSoft = Color(0x120284C7);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient pinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE83E8C), Color(0xFFFF5B82)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB88917), Color(0xFFD4AF37), Color(0xFFFFE08A), Color(0xFFD4AF37)],
    stops: [0.0, 0.35, 0.7, 1.0],
  );
}
