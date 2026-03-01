import 'package:flutter/material.dart';

class AppMeta {
  static const String name = 'Pigio';
  static const String version = '2.0.0';
}

class MondialRelayConfig {
  // Brand ID for Mondial Relay. 
  // 'BDTEST13' is the public demo account.
  static const String brandId = 'BDTEST';
}

class AppColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color bg = Color(0xFFF0F2FA);
  static const Color ink = Color(0xFF1A1B2E);
  static const Color mid = Color(0xFF6B6F8A);
  static const Color light = Color(0xFFB0B5CC);
  
  static const Color blue = Color(0xFF4B7BF5);
  static const Color blueSoft = Color(0xFFEEF2FE);
  
  static const Color pink = Color(0xFFF43F82);
  static const Color pinkSoft = Color(0xFFFEE8F1);
  
  static const Color yellow = Color(0xFFFFD166);
  static const Color yellowSoft = Color(0xFFFFF6DC);
  
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleSoft = Color(0xFFEDE9FD);
  
  static const Color green = Color(0xFF06D6A0);
  static const Color greenSoft = Color(0xFFE0FAF4);
  
  static const Color coral = Color(0xFFFF6B6B);
  static const Color coralSoft = Color(0xFFFFE8E8);
  
  static const Color orange = Color(0xFFFF9F43);
  static const Color orangeSoft = Color(0xFFFFF0DC);
  
  static const Color teal = Color(0xFF2EC4B6);
  static const Color tealSoft = Color(0xFFE0F7F6);

  static const List<Color> avPalette = [
    Color(0xFF4B7BF5),
    Color(0xFFF43F82),
    Color(0xFFFFD166),
    Color(0xFF06D6A0),
    Color(0xFF8B5CF6),
    Color(0xFFFF6B6B),
    Color(0xFFFF9F43),
  ];

  // Notion warm colors for avatar backgrounds (light mode)
  static const List<Color> notionWarmColors = [
    Color(0xFFFDEBDE), // Orange background
    Color(0xFFFDF3D8), // Yellow background
    Color(0xFFF4EBE6), // Brown background
    Color(0xFFFDE5E2), // Red background
    Color(0xFFFCE8F3), // Pink background
    Color(0xFFEFE5FD), // Purple background
    Color(0xFFE5F4F4), // Blue background
    Color(0xFFE7F3ED), // Green background
    Color(0xFFF1F1EF), // Gray background
  ];

  // Richer, deeper avatar background colors for dark/OLED themes
  static const List<Color> notionWarmColorsDark = [
    Color(0xFFE8A87C), // Warm orange
    Color(0xFFE8D174), // Golden yellow
    Color(0xFFC4A882), // Warm brown
    Color(0xFFE88B85), // Soft red
    Color(0xFFDB7EB8), // Rose pink
    Color(0xFFB48EE0), // Vivid purple
    Color(0xFF7CBDBD), // Teal
    Color(0xFF7CBF96), // Soft green
    Color(0xFFB0B0AD), // Neutral gray
  ];
  
  static Color getAvColor(String name) {
    if (name.isEmpty) return avPalette[0];
    return avPalette[name.codeUnitAt(0) % avPalette.length];
  }
}

class PigioPalette {
  static const Color body = Color(0xFF8A9BC4);
  static const Color bodyDk = Color(0xFF6A7BA8);
  static const Color bodyLt = Color(0xFFA4B2D4);
  static const Color bodyHi = Color(0xFFC0CBE8);
  
  static const Color belly = Color(0xFFB2BED8);
  static const Color bellyLt = Color(0xFFCDD6E8);
  
  static const Color tape = Color(0xFFFFD633);
  static const Color tapeDk = Color(0xFFC8A000);
  static const Color tapeSd = Color(0xFFE8BC00);
  static const Color tapeMet = Color(0xFFC8CACC);
  
  static const Color beak = Color(0xFFE07848);
  static const Color beakDk = Color(0xFFB85830);
  static const Color beakIn = Color(0xFFCC3333);
  
  static const Color foot = Color(0xFFD06850);
  
  static const Color white = Color(0xFFFFFFFF);
  static const Color pupil = Color(0xFF1C1E2E);
  static const Color eyeWhite = Color(0xFFF2F4FA);
  static const Color eyeRing = Color(0xFFE0E5F5);

  static const Color wingDk = Color(0xFF5A6B98);
  static const Color wingFeat = Color(0xFF7A8BB8);
  
  static const Color brow = Color(0xFF404870);
  static const Color shadow = Color.fromARGB(33, 50, 60, 110);
}

// Simple text style helper to mimic 'fw' in React
TextStyle fw({double size = 16, FontWeight w = FontWeight.w700, Color? color, double? letterSpacing, double? height}) {
  return TextStyle(
    fontFamily: 'Nunito', 
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height ?? 1.35,
    letterSpacing: letterSpacing,
  );
}
