/// Spacing scale — 8 pt base grid.
class PFSpacing {
  PFSpacing._();

  // Primary 8-pt grid
  static const double xs = 4;
  static const double sm = 8;
  static const double sm12 = 12; // between sm and md
  static const double md = 16;
  static const double base = 16;  // alias for md
  static const double md20 = 20; // between md and lg
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;
  static const double huge = 64;
  static const double giant = 80;

  // Semantic layout constants
  static const double section = 32;  // gap between major content sections
  static const double page = 48;     // outer page padding on wide screens
  static const double pageMobile = 16; // outer page padding on mobile

  // Border radii
  static const double radiusSm = 8;
  static const double radius = 14;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radiusCard = 20;
  static const double radiusFull = 999;
}
