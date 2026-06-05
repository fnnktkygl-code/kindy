import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

// ── THEME VARIANT ENUM ──
enum PigioThemeVariant { light, sepia, dark, oled }

// ── DESIGN CONSTRAINTS ──
class PigioDesign {
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 14.0;
  static const double radiusLarge = 20.0;
  static const double radiusXLarge = 24.0;
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
}

// ── SEMANTIC THEME DATA ──
class PigioThemeData {
  final PigioThemeVariant variant;

  // Scaffolds & large backgrounds
  final Color scaffold;    // page background
  final Color card;        // card / container surface
  final Color sheet;       // bottom sheet background
  final Color navBar;      // bottom nav bar + sticky headers

  // Surfaces (inset panels, inputs)
  final Color surface;     // slightly recessed panel
  final Color surfaceAlt;  // deeper inset

  // Typography
  final Color ink;         // primary text
  final Color mid;         // secondary / muted text
  final Color light;       // placeholder / disabled
  final Color onAccent;    // text on colored buttons

  // Borders & Shadows
  final Color divider;     // card borders, thin rules
  final Color shadow;      // box shadow color

  // Centralized Semantic Colors (Notion inspired)
  final Color primary;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Accents for tabs & categories (Notion inspired)
  final Color accent1; // Home (Blue)
  final Color accent2; // Wishes (Pink/Red)
  final Color accent3; // Sizes (Purple)
  final Color accent4; // Circles (Green)

  // Notion warm colors (avatar background picker)
  final List<Color> notionWarmColors;

  const PigioThemeData({
    required this.variant,
    required this.scaffold,
    required this.card,
    required this.sheet,
    required this.navBar,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.mid,
    required this.light,
    required this.onAccent,
    required this.divider,
    required this.shadow,
    required this.primary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.accent1,
    required this.accent2,
    required this.accent3,
    required this.accent4,
    required this.notionWarmColors,
  });

  bool get isDark => variant == PigioThemeVariant.dark || variant == PigioThemeVariant.oled;

  PigioThemeData copyWith({
    Color? primary,
    Color? onAccent,
  }) {
    return PigioThemeData(
      variant: variant,
      scaffold: scaffold,
      card: card,
      sheet: sheet,
      navBar: navBar,
      surface: surface,
      surfaceAlt: surfaceAlt,
      ink: ink,
      mid: mid,
      light: light,
      onAccent: onAccent ?? this.onAccent,
      divider: divider,
      shadow: shadow,
      primary: primary ?? this.primary,
      success: success,
      warning: warning,
      error: error,
      info: info,
      accent1: accent1,
      accent2: accent2,
      accent3: accent3,
      accent4: accent4,
      notionWarmColors: notionWarmColors,
    );
  }
}

// ── 4 THEME DEFINITIONS ──
class PigioThemes {
  // Notion warm palettes
  static const List<Color> _notionLight = [
    Color(0xFFFDEBDE), Color(0xFFFDF3D8), Color(0xFFF4EBE6),
    Color(0xFFFDE5E2), Color(0xFFFCE8F3), Color(0xFFEFE5FD),
    Color(0xFFE5F4F4), Color(0xFFE7F3ED), Color(0xFFF1F1EF),
  ];

  static const List<Color> _notionDark = [
    Color(0xFF3A2E22), Color(0xFF3A3520), Color(0xFF2E2825),
    Color(0xFF3A2522), Color(0xFF38202E), Color(0xFF2A1E3A),
    Color(0xFF1E3030), Color(0xFF1E3028), Color(0xFF2A2A28),
  ];

  // ─── LIGHT ───
  static const PigioThemeData light = PigioThemeData(
    variant: PigioThemeVariant.light,
    scaffold:   Color(0xFFF0F2FA),
    card:       Color(0xFFFFFFFF),
    sheet:      Color(0xFFFFFFFF),
    navBar:     Color(0xFFFFFFFF),
    surface:    Color(0xFFEEF0F8),
    surfaceAlt: Color(0xFFE6E9F5),
    ink:        Color(0xFF1A1B2E),
    mid:        Color(0xFF6B6F8A),
    light:      Color(0xFFB0B5CC),
    onAccent:   Color(0xFFFFFFFF),
    divider:    Color(0xFFE5E8F5),
    shadow:     Color(0x0D1A1B2E),
    primary:    Color(0xFF337EA9), // Notion Blue
    success:    Color(0xFF448361), // Notion Green
    warning:    Color(0xFFD9730D), // Notion Orange
    error:      Color(0xFFD44C47), // Notion Red
    info:       Color(0xFF9065B0), // Notion Purple
    accent1:    Color(0xFF337EA9),
    accent2:    Color(0xFFC14C8A), // Notion Pink
    accent3:    Color(0xFF9065B0),
    accent4:    Color(0xFF448361),
    notionWarmColors: _notionLight,
  );

  // ─── SEPIA ───
  static const PigioThemeData sepia = PigioThemeData(
    variant: PigioThemeVariant.sepia,
    scaffold:   Color(0xFFF5F0E8),
    card:       Color(0xFFFFFDF7),
    sheet:      Color(0xFFFFFDF7),
    navBar:     Color(0xFFFFFDF7),
    surface:    Color(0xFFEDE8DC),
    surfaceAlt: Color(0xFFE5DFD0),
    ink:        Color(0xFF2C2418),
    mid:        Color(0xFF7A7060),
    light:      Color(0xFFB8AD9A),
    onAccent:   Color(0xFFFFFFFF),
    divider:    Color(0xFFE5DDD0),
    shadow:     Color(0x0D2C2418),
    primary:    Color(0xFF337EA9),
    success:    Color(0xFF448361),
    warning:    Color(0xFFD9730D),
    error:      Color(0xFFD44C47),
    info:       Color(0xFF9065B0),
    accent1:    Color(0xFF337EA9),
    accent2:    Color(0xFFC14C8A),
    accent3:    Color(0xFF9065B0),
    accent4:    Color(0xFF448361),
    notionWarmColors: [
      Color(0xFFF5E2D0), Color(0xFFF5EBC8), Color(0xFFECE0D5),
      Color(0xFFF5D8D5), Color(0xFFF4DAEB), Color(0xFFE5D8F5),
      Color(0xFFD8ECE8), Color(0xFFD8ECDE), Color(0xFFE8E5E0),
    ],
  );

  // ─── DARK ───
  static const PigioThemeData dark = PigioThemeData(
    variant: PigioThemeVariant.dark,
    scaffold:   Color(0xFF12131F),
    card:       Color(0xFF1E2035),
    sheet:      Color(0xFF1E2035),
    navBar:     Color(0xFF1A1B2E),
    surface:    Color(0xFF252740),
    surfaceAlt: Color(0xFF2A2C48),
    ink:        Color(0xFFE8EAF6),
    mid:        Color(0xFF8B90B0),
    light:      Color(0xFF5A5F7A),
    onAccent:   Color(0xFFFFFFFF),
    divider:    Color(0xFF2A2D45),
    shadow:     Color(0x33000000),
    primary:    Color(0xFF5E9ED6), // Lighter Notion Blue
    success:    Color(0xFF5DB081), // Lighter Notion Green
    warning:    Color(0xFFF59E42), // Lighter Notion Orange
    error:      Color(0xFFE86D68), // Lighter Notion Red
    info:       Color(0xFFB68ED6), // Lighter Notion Purple
    accent1:    Color(0xFF5E9ED6),
    accent2:    Color(0xFFE57EBA), // Lighter Notion Pink
    accent3:    Color(0xFFB68ED6),
    accent4:    Color(0xFF5DB081),
    notionWarmColors: _notionDark,
  );

  // ─── OLED ───
  static const PigioThemeData oled = PigioThemeData(
    variant: PigioThemeVariant.oled,
    scaffold:   Color(0xFF000000),
    card:       Color(0xFF0F1020),
    sheet:      Color(0xFF0F1020),
    navBar:     Color(0xFF080910),
    surface:    Color(0xFF181928),
    surfaceAlt: Color(0xFF1E1F32),
    ink:        Color(0xFFF0F2FF),
    mid:        Color(0xFF7880A8),
    light:      Color(0xFF454868),
    onAccent:   Color(0xFFFFFFFF),
    divider:    Color(0xFF1A1B2A),
    shadow:     Color(0x00000000),
    primary:    Color(0xFF5E9ED6),
    success:    Color(0xFF5DB081),
    warning:    Color(0xFFF59E42),
    error:      Color(0xFFE86D68),
    info:       Color(0xFFB68ED6),
    accent1:    Color(0xFF5E9ED6),
    accent2:    Color(0xFFE57EBA),
    accent3:    Color(0xFFB68ED6),
    accent4:    Color(0xFF5DB081),
    notionWarmColors: [
      Color(0xFF28201A), Color(0xFF282518), Color(0xFF221E1A),
      Color(0xFF281A18), Color(0xFF25141E), Color(0xFF1E1428),
      Color(0xFF142222), Color(0xFF14221C), Color(0xFF1E1E1C),
    ],
  );

  static PigioThemeData fromVariant(PigioThemeVariant variant) {
    PigioThemeData base;
    switch (variant) {
      case PigioThemeVariant.light: base = light; break;
      case PigioThemeVariant.sepia: base = sepia; break;
      case PigioThemeVariant.dark: base = dark; break;
      case PigioThemeVariant.oled: base = oled; break;
    }
    
    return base;
  }
}

// ── CONTEXT EXTENSION ──
extension PigioTheme on BuildContext {
  PigioThemeData get pt => Provider.of<PigioAppState>(this).currentTheme;
  PigioThemeData get ptnl => Provider.of<PigioAppState>(this, listen: false).currentTheme;
}
