import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kindy/core/state/app_state.dart';

enum PigMood { normal, excited, waving, thumbsUp, thinking, sad, embarrassed, searching, celebrating, love, sleeping, dizzy }
enum PigPose { normal, coldTucked, sunRelaxed, umbrellaBrace }
enum PigViewAngle { front, threeQuarterRight, back, threeQuarterLeft }

/// Dedicated palette to replicate the soft 3D clay aesthetic
class _ClayColors {
  static const blueHighlight = Color(0xFF98A9C4);
  static const blueMain = Color(0xFF7B8CA3);
  static const blueShadow = Color(0xFF5D6D86);

  static const bellyHighlight = Color(0xFFD4DEED);
  static const bellyMain = Color(0xFFB4C2D8);

  static const beakHighlight = Color(0xFFF79870);
  static const beakMain = Color(0xFFE86B3E);
  static const beakShadow = Color(0xFFBE4C24);

  static const wingHighlight = Color(0xFF8B9DB8);
  static const wingMain = Color(0xFF6F82A3);

  static const eyeWhite = Color(0xFFFFFFFF);
  static const eyeShadow = Color(0xFFCED6E5);
  static const pupil = Color(0xFF2C3E50);

  static const orangeFeet = Color(0xFFE86B3E);
}

/// Reusable rendering helpers for clay-style depth
mixin _ClayRenderMixin {
  /// Cache reference — subclass must provide
  Shader getCachedShaderFor(String key, Rect bounds, Gradient gradient);

  /// Draw a drop shadow for any Path
  void drawDropShadow(Canvas canvas, Path path, {double blur = 2.0, Offset offset = const Offset(1, 2)}) {
    canvas.drawPath(
      path.shift(offset),
      Paint()..color = Colors.black12..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  /// Create a radial gradient Paint for clay-like 3D surfaces
  Paint clayFill(String key, Rect bounds, Color base) {
    final hsl = HSLColor.fromColor(base);
    final highlight = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    final shadow = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
    return Paint()
      ..shader = getCachedShaderFor(key, bounds, RadialGradient(
        colors: [highlight, base, shadow],
        center: const Alignment(-0.3, -0.4),
        radius: 0.9,
      ));
  }

  /// Specular highlight — small bright spot on curved surfaces
  void drawSpecular(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(center, radius, Paint()..color = Colors.white.withValues(alpha: 0.35));
  }

  /// Inner shadow along the bottom of a clipped shape for depth
  void drawInnerShadow(Canvas canvas, Path path, {double blur = 1.5}) {
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withValues(alpha: 0.08)..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
    canvas.restore();
  }
}

class PigioPainter extends CustomPainter with _ClayRenderMixin {
  final PigMood mood;
  final PigPose pose;
  final String? weatherCondition;
  final double weatherExposure;
  final bool weatherIsDay;
  final double weatherTemperature;
  final Color scarfColor;
  final int contactCount;
  final int reservedCount;
  final Map<ClothingSlot, String?> outfit;
  final Map<String, int> outfitColors; // itemId → ARGB32 color
  final double blinkPhase; // 0 = open, 1 = fully closed
  final bool isTalking; // true = beak open for talking animation
  final double lookOffsetX; // -1 to 1, shifts pupils left/right
  final int stage; // 0=Egg, 1=Chick, 2=Juvenile, 3=Adult, 4=Elder
  final PigViewAngle viewAngle;

  final int currentMonth;

  static final Map<String, Shader> _shaderCache = {};
  static final List<String> _shaderLruKeys = []; // P4: LRU eviction order
  static const int _shaderCacheMax = 80;

  PigioPainter({
    this.mood = PigMood.normal,
    this.pose = PigPose.normal,
    this.weatherCondition,
    this.weatherExposure = 0.0,
    this.weatherIsDay = true,
    this.weatherTemperature = 0.0,
    this.scarfColor = const Color(0xFFF7C427),
    this.contactCount = 0,
    this.reservedCount = 0,
    this.outfit = const {},
    this.outfitColors = const {},
    this.blinkPhase = 0.0,
    this.isTalking = false,
    this.lookOffsetX = 0.0,
    this.stage = 1,
    this.viewAngle = PigViewAngle.front,
    int? currentMonth,
  }) : currentMonth = currentMonth ?? DateTime.now().month;

  @override
  Shader getCachedShaderFor(String key, Rect bounds, Gradient gradient) =>
      _getCachedShader(key, bounds, gradient);

  // P4: LRU shader cache — evicts oldest entries beyond _shaderCacheMax.
  // Key includes bounds hash to avoid reusing shaders created for different sizes.
  Shader _getCachedShader(String key, Rect bounds, Gradient gradient) {
    final fullKey = '$key@${bounds.width.toInt()}x${bounds.height.toInt()}';
    final cached = _shaderCache[fullKey];
    if (cached != null) {
      // Move to end (most recently used)
      _shaderLruKeys.remove(fullKey);
      _shaderLruKeys.add(fullKey);
      return cached;
    }
    // Evict oldest if at capacity
    while (_shaderCache.length >= _shaderCacheMax && _shaderLruKeys.isNotEmpty) {
      final evict = _shaderLruKeys.removeAt(0);
      _shaderCache.remove(evict);
    }
    final shader = gradient.createShader(bounds);
    _shaderCache[fullKey] = shader;
    _shaderLruKeys.add(fullKey);
    return shader;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale, scale);

    // currentMonth is now a constructor parameter — no DateTime.now() inside paint.

    // Stage 0 (Egg) — render smaller
    if (stage == 0) {
      canvas.translate(10, 15);
      canvas.scale(0.8, 0.8);
    }

    // Stage 4 (Elder) — golden aura behind the mascot
    if (stage >= 4) {
      canvas.drawCircle(
        const Offset(50, 60),
        55,
        Paint()
          ..color = const Color(0xFFFFAA00).withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
      canvas.drawCircle(
        const Offset(50, 60),
        40,
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Shift slightly down so hat elements don't clip the widget top boundary.
    // All coordinates below are in this translated space (effective y-origin is 5 units
    // below the widget top). SVG overlays are NOT used — all clothing is drawn here so
    // coordinates are always in the same space as the mascot body.
    canvas.translate(0, 5);

    switch (pose) {
      case PigPose.coldTucked:
        canvas.translate(0, 3);
        canvas.scale(0.97, 1.03);
        break;
      case PigPose.sunRelaxed:
        canvas.translate(1, -1);
        canvas.rotate(-0.055);
        break;
      case PigPose.umbrellaBrace:
        canvas.translate(-3, 1);
        canvas.rotate(0.045);
        break;
      case PigPose.normal:
        break;
    }

    // ── View angle transforms ──
    if (viewAngle == PigViewAngle.back) {
      _drawBackView(canvas);
      canvas.restore();
      return;
    }
    if (viewAngle == PigViewAngle.threeQuarterRight) {
      // Compress horizontally + slight skew to simulate perspective
      canvas.translate(50, 0);
      canvas.scale(0.88, 1.0);
      canvas.translate(-50, 0);
    } else if (viewAngle == PigViewAngle.threeQuarterLeft) {
      canvas.translate(50, 0);
      canvas.scale(0.88, 1.0);
      canvas.translate(-50, 0);
      // Mirror horizontally so left side is more visible
      canvas.translate(100, 0);
      canvas.scale(-1, 1);
    }

    final hatId = outfit[ClothingSlot.hat];
    final glassesId = outfit[ClothingSlot.glasses];
    final topId = outfit[ClothingSlot.top];
    final scarfId = outfit[ClothingSlot.scarf];
    final shoesId = outfit[ClothingSlot.shoes];
    final accId = outfit[ClothingSlot.accessory];
    final bool hasTop = topId != null;
    final bool hasScarfItem = scarfId != null;
    final bool isUmbrella = accId == 'acc_umbrella';
    final bool isRaisedMood = mood == PigMood.excited || mood == PigMood.celebrating;
    final bool isWaving = mood == PigMood.waving;

    // ── 1. Ground shadow ──
    canvas.drawOval(
      const Rect.fromLTWH(20, 115, 60, 10),
      Paint()
        ..color = Colors.black12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ── 2. Behind-body accessories (cape, backpack) ──
    if (accId == 'acc_cape') _drawCape(canvas, outfitColors[accId] != null ? Color(outfitColors[accId]!) : null);
    if (accId == 'acc_backpack') _drawBackpack(canvas, outfitColors[accId] != null ? Color(outfitColors[accId]!) : null);

    // ── 2.5. Back raised wings (behind body) ──
    // Only draw bare wings if NOT wearing an arm-covering top.
    // Thick scarf doesn't cover arms, so bare wings still show.
    // Skip when holding umbrella — the umbrella branch in step 11 handles arms.
    final bool topCoversBack = hasTop && topId != 'top_scarf_thick';
    if (!topCoversBack && !isUmbrella) {
      if (pose == PigPose.coldTucked) {
        _drawTuckedWing(canvas, true);
        _drawTuckedWing(canvas, false);
      } else if (isRaisedMood) {
        _drawRaisedWing(canvas, true);
        _drawRaisedWing(canvas, false);
      }
    }

    // ── 3. Feet — only draw bare feet if NO shoes ──
    if (shoesId == null) _drawFeet(canvas);

    // ── 4. Body ──
    _drawBody(canvas);

    // ── 5. Top clothing (on body) ──
    if (hasTop) _drawTop(canvas, topId);

    // ── 6. Shoes — drawn AFTER body+top so they overlap the bottom edge ──
    //        This makes the feet appear to be INSIDE the shoes.
    if (shoesId != null) _drawShoes(canvas, shoesId);

    // ── 7. Head ──
    _drawHead(canvas);

    // ── 8. Scarf — default scarf only when no top AND no scarf item ──
    if (!hasTop && !hasScarfItem) _drawScarf(canvas);

    // ── 8.5 Scarf item — neckwear drawn OVER tops ──
    if (hasScarfItem) _drawScarfItem(canvas, scarfId);

    // ── 9. Face ──
    _drawFace(canvas, mood);

    // ── 10. Glasses ──
    if (glassesId != null) _drawGlasses(canvas, glassesId);

    // ── 11. Arms/Wings ──
    // Thick scarf is a neck accessory — it does NOT cover the arms.
    // Only actual garments (raincoat, hawaiian, pyjama) color the arms.
    final bool topCoversArms = hasTop && topId != 'top_scarf_thick';
    if (topCoversArms) {
      _drawArmsWithSleeves(canvas, topId, mood, isUmbrella, pose: pose);
    } else {
      // Bare wings (no top, or thick scarf which doesn't cover arms)
      if (isUmbrella) {
        _drawRestWing(canvas, true);
        _drawUmbrellaHoldingWing(canvas);
      } else if (pose == PigPose.coldTucked) {
        _drawTuckedWing(canvas, true);
        _drawTuckedWing(canvas, false);
      } else if (pose == PigPose.sunRelaxed) {
        _drawRelaxedWing(canvas, true);
        _drawRelaxedWing(canvas, false);
      } else if (mood == PigMood.normal || mood == PigMood.sad || mood == PigMood.love || mood == PigMood.sleeping) {
        _drawRestWing(canvas, true);
        _drawRestWing(canvas, false);
      } else if (isWaving) {
        _drawRestWing(canvas, true);
        _drawWavingWing(canvas, false);
      } else if (isRaisedMood) {
        // Both raised wings already drawn at step 2 (behind body) — no front wings
      } else if (mood == PigMood.thumbsUp) {
        _drawRestWing(canvas, true);
        _drawThumbsUpArm(canvas);
      } else if (mood == PigMood.thinking) {
        _drawRestWing(canvas, true);
        _drawThinkingArm(canvas);
      } else if (mood == PigMood.embarrassed) {
        _drawRestWing(canvas, false);
        _drawFacepalmArm(canvas);
      } else if (mood == PigMood.searching) {
        _drawRestWing(canvas, true);
        _drawSearchingArm(canvas);
      }
    }

    // ── 12. Hat ──
    if (mood == PigMood.celebrating) {
      _drawPartyHat(canvas);
    } else if (hatId != null) {
      _drawHat(canvas, hatId);
    }

    // ── 13. Seasonal extras ──
    _drawSeasonalFiltered(canvas, hasHat: hatId != null, hasGlasses: glassesId != null, month: currentMonth);

    // ── 13.5. Localized weather traces on Pigio ──
    _drawWeatherMicroEffects(canvas, hasHat: hatId != null, hasUmbrella: isUmbrella);

    // ── 14. Held accessory (in front of body, but UNDER umbrella canopy) ──
    if (accId != null) _drawAccessory(canvas, accId);

    if (mood == PigMood.love) _drawHearts(canvas);

    // ── 15. Umbrella canopy — absolute last layer so it shelters everything ──
    if (isUmbrella) {
      final umbTint = outfitColors['acc_umbrella'] != null ? Color(outfitColors['acc_umbrella']!) : null;
      _drawUmbrellaCanopy(canvas, umbTint);
    }

    canvas.restore();
  }

  // ─────────────────── BODY PARTS ───────────────────

  void _drawBody(Canvas canvas) {
    final bodyRect = const Rect.fromLTWH(15, 45, 70, 68);
    // Drop shadow
    drawDropShadow(canvas, Path()..addOval(bodyRect), blur: 4, offset: const Offset(2, 3));
    final fill = Paint()
      ..shader = _getCachedShader('body', bodyRect, const RadialGradient(
        colors: [_ClayColors.blueHighlight, _ClayColors.blueMain, _ClayColors.blueShadow],
        center: Alignment(-0.3, -0.4),
        radius: 0.8,
      ));
    canvas.drawOval(bodyRect, fill);
    // Rim light — subtle edge highlight
    canvas.drawOval(
      bodyRect.deflate(1),
      Paint()..color = Colors.white.withValues(alpha: 0.06)..style = PaintingStyle.stroke..strokeWidth = 1,
    );

    final bellyRect = const Rect.fromLTWH(28, 55, 44, 52);
    final bellyFill = Paint()
      ..shader = _getCachedShader('belly', bellyRect, const RadialGradient(
        colors: [_ClayColors.bellyHighlight, _ClayColors.bellyMain],
        center: Alignment(-0.2, -0.2),
        radius: 0.7,
      ));
    canvas.drawOval(bellyRect, bellyFill);
    // Belly specular
    drawSpecular(canvas, const Offset(42, 68), 4);
  }

  void _drawHead(Canvas canvas) {
    final headRect = const Rect.fromLTWH(25, 8, 50, 52);
    // Subtle head shadow
    drawDropShadow(canvas, Path()..addOval(headRect), blur: 3, offset: const Offset(1, 2));
    final fill = Paint()
      ..shader = _getCachedShader('head', headRect, const RadialGradient(
        colors: [_ClayColors.blueHighlight, _ClayColors.blueMain, _ClayColors.blueShadow],
        center: Alignment(-0.3, -0.3),
        radius: 0.8,
      ));
    canvas.drawOval(headRect, fill);
    // Rim light
    canvas.drawOval(
      headRect.deflate(1),
      Paint()..color = Colors.white.withValues(alpha: 0.06)..style = PaintingStyle.stroke..strokeWidth = 0.8,
    );
    // Head specular
    drawSpecular(canvas, const Offset(40, 22), 3.5);
  }

  void _drawFeet(Canvas canvas) {
    final fill = Paint()..color = _ClayColors.orangeFeet;

    canvas.drawOval(const Rect.fromLTWH(28, 116, 18, 6), Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawOval(const Rect.fromLTWH(54, 116, 18, 6), Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 108, 12, 10), const Radius.circular(5)), fill);
    canvas.drawCircle(const Offset(31, 116), 4.5, fill);
    canvas.drawCircle(const Offset(36, 118), 4.5, fill);
    canvas.drawCircle(const Offset(41, 116), 4.5, fill);

    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(58, 108, 12, 10), const Radius.circular(5)), fill);
    canvas.drawCircle(const Offset(59, 116), 4.5, fill);
    canvas.drawCircle(const Offset(64, 118), 4.5, fill);
    canvas.drawCircle(const Offset(69, 116), 4.5, fill);
  }

  void _drawScarf(Canvas canvas) {
    final fill = Paint();
    final effectiveColor = outfitColors['scarf'] != null ? Color(outfitColors['scarf']!) : scarfColor;
    final hsl = HSLColor.fromColor(effectiveColor);
    final highlight = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    final shadow = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();

    final wrapPath = Path()
      ..moveTo(18, 50)
      ..quadraticBezierTo(50, 66, 82, 50)
      ..lineTo(80, 62)
      ..quadraticBezierTo(50, 78, 20, 62)
      ..close();

    canvas.drawPath(wrapPath.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    fill.shader = _getCachedShader('scarf_wrap_${effectiveColor.toARGB32()}', wrapPath.getBounds(), LinearGradient(
      colors: [highlight, effectiveColor, shadow],
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
    ));
    canvas.drawPath(wrapPath, fill);

    final tailLength = 94.0 + (contactCount * 3).clamp(0, 30).toDouble();
    final tailPath = Path()
      ..moveTo(24, 60)
      ..lineTo(38, 66)
      ..lineTo(33, tailLength)
      ..lineTo(21, tailLength - 3)
      ..close();

    canvas.drawPath(tailPath.shift(const Offset(0, 2)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    fill.shader = _getCachedShader('scarf_tail_${effectiveColor.toARGB32()}_$tailLength', tailPath.getBounds(), LinearGradient(
      colors: [effectiveColor, shadow],
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
    ));
    canvas.drawPath(tailPath, fill);

    final tickPaint = Paint()..color = const Color(0xFF2D3748)..strokeWidth = 1.8..strokeCap = StrokeCap.round;
    // The scarf top edge is a quadratic bezier: moveTo(18,50) quadraticBezierTo(50,66,82,50)
    // Parametric: x=18+64t, y_top=50+32t(1-t)  →  t=(x-18)/64
    for (double x = 25; x <= 75; x += 6) {
      final t = (x - 18) / 64;
      final yBase = 50 + 32 * t * (1 - t) + 1; // +1 padding so tick starts just inside scarf
      canvas.drawLine(Offset(x, yBase), Offset(x, yBase + 5), tickPaint);
    }
    // Tail ticks — horizontal lines spanning the tail width
    for (double y = 70; y <= tailLength - 6; y += 6) {
      final frac = (y - 60) / (tailLength - 60);
      final xLeft = 24 + (21 - 24) * frac;
      final xRight = 38 + (33 - 38) * ((y - 66).clamp(0, tailLength - 66) / (tailLength - 66));
      canvas.drawLine(Offset(xLeft + 1, y), Offset(xRight - 1, y), tickPaint);
    }

    if (reservedCount >= 10) {
      final badgeCenter = const Offset(30, 72);
      canvas.drawCircle(badgeCenter, 5, Paint()..color = const Color(0xFFFFD700));
      canvas.drawCircle(badgeCenter, 3.5, Paint()..color = const Color(0xFFFFA000));
      canvas.drawCircle(badgeCenter, 1.8, Paint()..color = Colors.white);
    }
  }

  void _drawFace(Canvas canvas, PigMood mood) {
    bool beakOpen = isTalking || (mood == PigMood.excited || mood == PigMood.waving || mood == PigMood.celebrating);

    canvas.drawOval(const Rect.fromLTWH(40, 38, 20, 12).shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    if (beakOpen) {
      canvas.drawOval(const Rect.fromLTWH(43, 42, 14, 12), Paint()..color = const Color(0xFF4A1515));
      canvas.drawOval(const Rect.fromLTWH(46, 48, 8, 5), Paint()..color = const Color(0xFFE27474));
      final lowRect = const Rect.fromLTWH(44, 49, 12, 7);
      canvas.drawOval(lowRect, Paint()..shader = _getCachedShader('low_open', lowRect, const RadialGradient(colors: [_ClayColors.beakMain, _ClayColors.beakShadow], center: Alignment(0, 0.5), radius: 0.8)));
    } else {
      final lowRect = const Rect.fromLTWH(45, 43, 10, 6);
      canvas.drawOval(lowRect, Paint()..shader = _getCachedShader('low_closed', lowRect, const RadialGradient(colors: [_ClayColors.beakMain, _ClayColors.beakShadow], center: Alignment(0, 0.5), radius: 0.8)));
    }

    final upRect = const Rect.fromLTWH(40, 35, 20, 13);
    canvas.drawOval(upRect, Paint()..shader = _getCachedShader('up_beak', upRect, const RadialGradient(colors: [_ClayColors.beakHighlight, _ClayColors.beakMain, _ClayColors.beakShadow], center: Alignment(-0.2, -0.4), radius: 0.9)));

    String leftEye = "open", rightEye = "open", leftBrow = "normal", rightBrow = "normal";
    switch (mood) {
      case PigMood.excited:
      case PigMood.celebrating:
        leftEye = rightEye = "closed_happy";
        leftBrow = rightBrow = "raised"; break;
      case PigMood.thumbsUp:
        rightEye = "closed_happy";
        leftBrow = "normal"; rightBrow = "raised"; break;
      case PigMood.waving:
        leftBrow = "normal"; rightBrow = "raised"; break;
      case PigMood.thinking:
        leftEye = rightEye = "sleeping";
        leftBrow = rightBrow = "normal"; break;
      case PigMood.sleeping:
        leftEye = rightEye = "sleeping";
        leftBrow = rightBrow = "normal"; break;
      case PigMood.sad:
        leftEye = rightEye = "half_open";
        leftBrow = rightBrow = "sad"; break;
      case PigMood.embarrassed:
        leftBrow = rightBrow = "sad"; break;
      case PigMood.searching:
        leftEye = "half_open";
        leftBrow = "furrow"; rightBrow = "raised"; break;
      case PigMood.love:
        leftEye = rightEye = "closed_happy";
        leftBrow = rightBrow = "raised"; break;
      case PigMood.dizzy:
        leftEye = rightEye = "dizzy";
        leftBrow = rightBrow = "furrow"; break;
      default: break;
    }

    _drawEye(canvas, 36, 30, leftEye, true);
    _drawEye(canvas, 64, 30, rightEye, false);
    _drawBrow(canvas, 36, 20, leftBrow, true);
    _drawBrow(canvas, 64, 20, rightBrow, false);

    // Stage 2+ (Juvenile) — head tuft
    if (stage >= 2) {
      final tuftPaint = Paint()..color = _ClayColors.blueMain..strokeWidth = 2.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      canvas.drawLine(const Offset(47, -2), const Offset(44, -9), tuftPaint);
      canvas.drawLine(const Offset(50, -3), const Offset(50, -11), tuftPaint);
      canvas.drawLine(const Offset(53, -2), const Offset(56, -9), tuftPaint);
    }

    // Stage 3+ (Adult) — cheek blush
    if (stage >= 3) {
      final blushPaint = Paint()..color = const Color(0xFFFF8A80).withValues(alpha: 0.25);
      canvas.drawOval(const Rect.fromLTWH(20, 33, 12, 7), blushPaint);
      canvas.drawOval(const Rect.fromLTWH(68, 33, 12, 7), blushPaint);
    }
  }

  void _drawEye(Canvas canvas, double cx, double cy, String state, bool isLeft) {
    if (state == "closed_happy") {
      final path = Path()
        ..moveTo(cx - 7, cy + 2)
        ..quadraticBezierTo(cx, cy - 8, cx + 7, cy + 2);
      canvas.drawPath(path, Paint()..color = _ClayColors.pupil..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round);
      return;
    } else if (state == "sleeping") {
      final path = Path()
        ..moveTo(cx - 7, cy)
        ..lineTo(cx + 7, cy);
      canvas.drawPath(path, Paint()..color = _ClayColors.pupil..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round);
      return;
    }
    
    if (state == "dizzy") {
      final swirlPaint = Paint()
        ..color = _ClayColors.pupil
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      
      final path = Path();
      for (double t = 0; t < 3.5 * math.pi; t += 0.2) {
        final r = t * 0.7;
        final x = cx + r * math.cos(t);
        final y = cy + r * math.sin(t);
        if (t == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, swirlPaint);
      return;
    }

    const radius = 9.5;
    canvas.drawCircle(Offset(cx, cy + 1), radius, Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));

    final eyeRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    canvas.drawCircle(Offset(cx, cy), radius, Paint()..shader = _getCachedShader(
      'eye_white_${cx}_$cy', eyeRect, const RadialGradient(
        colors: [_ClayColors.eyeWhite, _ClayColors.eyeShadow],
        center: Alignment(-0.3, -0.3), radius: 0.9,
      )
    ));

    double px = cx + lookOffsetX * 2.5, py = cy + 1;
    if (state == "look_up") {
      py = cy - 2;
      px = isLeft ? cx + 1 : cx - 1;
    }
    canvas.drawCircle(Offset(px, py), 3.5, Paint()..color = _ClayColors.pupil);
    canvas.drawCircle(Offset(px - 1.5, py - 1.5), 1.2, Paint()..color = Colors.white);

    // Blink lid — slides down over eye when blinkPhase > 0
    final effectiveBlinkPhase = (state == "half_open") ? math.max(blinkPhase, 0.5) : blinkPhase;
    if (effectiveBlinkPhase > 0) {
      final lidBottom = cy - radius + (2 * radius + 2) * effectiveBlinkPhase;
      final lidPath = Path()
        ..moveTo(cx - radius - 1, cy - radius)
        ..lineTo(cx + radius + 1, cy - radius)
        ..lineTo(cx + radius + 1, lidBottom)
        ..lineTo(cx - radius - 1, lidBottom)..close();
      canvas.drawPath(lidPath, Paint()..shader = _getCachedShader(
        'eye_lid_blink_${cx}_$cy', Rect.fromLTWH(cx - radius, cy - radius, radius * 2, radius * 2), const LinearGradient(
          colors: [_ClayColors.blueMain, _ClayColors.blueShadow], begin: Alignment.topCenter, end: Alignment.bottomCenter,
        )
      ));
      canvas.drawLine(Offset(cx - radius, lidBottom), Offset(cx + radius, lidBottom), Paint()..color = _ClayColors.blueShadow..strokeWidth = 2);
    }
  }

  void _drawBrow(Canvas canvas, double cx, double cy, String state, bool isLeft) {
    final paint = Paint()..color = _ClayColors.blueShadow..style = PaintingStyle.stroke..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    Path path;
    switch (state) {
      case "raised":
        path = Path()..moveTo(cx - 6, cy - 3)..quadraticBezierTo(cx, cy - 9, cx + 6, cy - 3); break;
      case "sad":
        path = Path()..moveTo(cx - 6, cy - 5)..quadraticBezierTo(cx, cy + 1, cx + 6, cy - 5); break;
      case "furrow":
        path = isLeft ? (Path()..moveTo(cx - 6, cy - 3)..lineTo(cx + 6, cy + 3)) : (Path()..moveTo(cx - 6, cy + 3)..lineTo(cx + 6, cy - 3)); break;
      case "normal":
      default:
        path = Path()..moveTo(cx - 6, cy)..quadraticBezierTo(cx, cy - 4, cx + 6, cy); break;
    }
    canvas.drawPath(path, paint);
  }

  Paint _wingPaint(Rect bounds, {bool isFront = true}) {
    return Paint()..shader = _getCachedShader(
      'wing_${isFront}_${bounds.left}_${bounds.top}_${bounds.width}_${bounds.height}',
      bounds,
      LinearGradient(
        colors: isFront ? [_ClayColors.wingHighlight, _ClayColors.wingMain] : [_ClayColors.blueMain, _ClayColors.blueShadow],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      )
    );
  }

  void _drawRestWing(Canvas canvas, bool isLeft) {
    Path path;
    if (isLeft) {
      path = Path()..moveTo(22, 62)..quadraticBezierTo(8, 75, 12, 98)..quadraticBezierTo(22, 106, 30, 85)..quadraticBezierTo(28, 70, 22, 62)..close();
    } else {
      path = Path()..moveTo(78, 62)..quadraticBezierTo(92, 75, 88, 98)..quadraticBezierTo(78, 106, 70, 85)..quadraticBezierTo(72, 70, 78, 62)..close();
    }
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(path, _wingPaint(path.getBounds(), isFront: true));
  }

  void _drawRaisedWing(Canvas canvas, bool isLeft) {
    Path path;
    if (isLeft) {
      path = Path()..moveTo(30, 60)..quadraticBezierTo(10, 45, 8, 20)..quadraticBezierTo(18, 15, 22, 28)..quadraticBezierTo(28, 20, 32, 35)..quadraticBezierTo(38, 45, 40, 60)..close();
    } else {
      path = Path()..moveTo(70, 60)..quadraticBezierTo(90, 45, 92, 20)..quadraticBezierTo(82, 15, 78, 28)..quadraticBezierTo(72, 20, 68, 35)..quadraticBezierTo(62, 45, 60, 60)..close();
    }
    canvas.drawPath(path, _wingPaint(path.getBounds(), isFront: false));
  }

  void _drawWavingWing(Canvas canvas, bool isLeft) {
    Path path;
    if (isLeft) {
      path = Path()
        ..moveTo(29, 62)
        ..quadraticBezierTo(10, 52, 14, 26)
        ..quadraticBezierTo(18, 10, 29, 22)
        ..quadraticBezierTo(37, 31, 38, 48)
        ..quadraticBezierTo(39, 60, 29, 62)
        ..close();
    } else {
      path = Path()
        ..moveTo(71, 62)
        ..quadraticBezierTo(90, 52, 86, 26)
        ..quadraticBezierTo(82, 10, 71, 22)
        ..quadraticBezierTo(63, 31, 62, 48)
        ..quadraticBezierTo(61, 60, 71, 62)
        ..close();
    }
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(path, _wingPaint(path.getBounds(), isFront: true));
  }

  void _drawThumbsUpArm(Canvas canvas) {
    final paint = _wingPaint(const Rect.fromLTWH(65, 50, 35, 30), isFront: true);
    canvas.drawPath(Path()..moveTo(70, 70)..quadraticBezierTo(85, 80, 88, 65)..lineTo(75, 60)..close(), paint);
    canvas.drawCircle(const Offset(88, 62), 6.5, paint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(84, 48, 8, 14), const Radius.circular(4)), paint);
  }

  void _drawThinkingArm(Canvas canvas) {
    final paint = _wingPaint(const Rect.fromLTWH(60, 40, 35, 40), isFront: true);
    canvas.drawPath(Path()..moveTo(75, 75)..quadraticBezierTo(85, 65, 70, 48)..lineTo(60, 55)..quadraticBezierTo(70, 70, 75, 75)..close(), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(56, 42, 8, 14), const Radius.circular(4)), paint);
  }

  void _drawFacepalmArm(Canvas canvas) {
    final paint = _wingPaint(const Rect.fromLTWH(20, 30, 30, 50), isFront: true);
    canvas.drawPath(Path()..moveTo(25, 75)..quadraticBezierTo(10, 50, 30, 35)..quadraticBezierTo(40, 45, 35, 70)..close(), paint);
    canvas.drawCircle(const Offset(35, 36), 9, paint);
  }

  void _drawSearchingArm(Canvas canvas) {
    final paint = _wingPaint(const Rect.fromLTWH(65, 45, 30, 30), isFront: true);
    canvas.drawPath(Path()..moveTo(75, 70)..quadraticBezierTo(85, 60, 82, 50)..lineTo(70, 55)..close(), paint);
    canvas.drawCircle(const Offset(80, 52), 7, paint);

    final glassPaint = Paint()..color = const Color(0xFF333333)..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawLine(const Offset(80, 52), const Offset(64, 32), glassPaint);
    canvas.drawCircle(const Offset(64, 32), 14, glassPaint);
    canvas.drawCircle(const Offset(64, 32), 12.5, Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.3)..style = PaintingStyle.fill);
    canvas.drawArc(Rect.fromCircle(center: const Offset(64, 32), radius: 9), -3.14 / 4, 3.14 / 2, false, Paint()..color = Colors.white.withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round);
  }

  void _drawPartyHat(Canvas canvas) {
    final hat = Path()..moveTo(50, -4)..lineTo(32, 20)..quadraticBezierTo(50, 26, 68, 20)..close();
    canvas.drawPath(hat, Paint()..shader = _getCachedShader('party_hat', hat.getBounds(), const LinearGradient(colors: [Color(0xFFFF528A), Color(0xFFE01C5E)])));
    canvas.drawPath(Path()..moveTo(40, 8)..lineTo(56, 5)..lineTo(58, 14)..lineTo(38, 15)..close(), Paint()..color = const Color(0xFFFFD13B));
    canvas.drawCircle(const Offset(50, -4), 5, Paint()..color = const Color(0xFFFFD13B));

    final colors = [Colors.greenAccent, Colors.purpleAccent, Colors.yellowAccent, Colors.blueAccent];
    final offsets = [const Offset(20, 10), const Offset(80, 15), const Offset(15, 35), const Offset(85, 30)];
    for (int i = 0; i < offsets.length; i++) {
      canvas.drawRect(Rect.fromCenter(center: offsets[i], width: 4, height: 6), Paint()..color = colors[i]);
    }
  }

  // ─────────────────── SEASONAL (filtered by outfit) ───────────────────

  void _drawSeasonalFiltered(Canvas canvas, {required bool hasHat, required bool hasGlasses, required int month}) {
    if (!hasHat && month == 12) {
      final hatPath = Path()..moveTo(50, -6)..lineTo(30, 20)..quadraticBezierTo(50, 26, 70, 20)..close();
      canvas.drawPath(hatPath, Paint()..shader = _getCachedShader('santa_hat', hatPath.getBounds(), const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFC62828)], begin: Alignment.topCenter, end: Alignment.bottomCenter)));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(27, 18, 46, 8), const Radius.circular(4)), Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(50, -6), 6, Paint()..color = Colors.white);
    }
    // February heart antenna — not a hat or glasses, always show
    if (month == 2) {
      canvas.drawLine(const Offset(50, 8), const Offset(50, -8), Paint()..color = const Color(0xFF2D3748)..strokeWidth = 2..strokeCap = StrokeCap.round);
      canvas.drawPath(Path()..moveTo(50, -18)..cubicTo(56, -24, 62, -14, 50, -6)..cubicTo(38, -14, 44, -24, 50, -18), Paint()..color = const Color(0xFFE91E63));
    }
    if (!hasGlasses && month >= 6 && month <= 8) {
      final glassPaint = Paint()..color = const Color(0xFF1F2937);
      canvas.drawLine(const Offset(32, 26), const Offset(68, 26), Paint()..color = const Color(0xFF1F2937)..strokeWidth = 2);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 22, 16, 12), const Radius.circular(3)), glassPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(54, 22, 16, 12), const Radius.circular(3)), glassPaint);
      canvas.drawLine(const Offset(34, 24), const Offset(42, 32), Paint()..color = Colors.white24..strokeWidth = 2);
      canvas.drawLine(const Offset(58, 24), const Offset(66, 32), Paint()..color = Colors.white24..strokeWidth = 2);
    }
  }

  static final TextPainter _heartSmall = TextPainter(
    text: const TextSpan(text: "💗", style: TextStyle(fontSize: 18)),
    textDirection: TextDirection.ltr,
  )..layout();
  static final TextPainter _heartLarge = TextPainter(
    text: const TextSpan(text: "💗", style: TextStyle(fontSize: 24)),
    textDirection: TextDirection.ltr,
  )..layout();

  void _drawHearts(Canvas canvas) {
    _heartSmall.paint(canvas, const Offset(15, 15));
    _heartLarge.paint(canvas, const Offset(65, 5));
  }

  // ─────────────────── CLOTHING DISPATCH ───────────────────

  void _drawHat(Canvas canvas, String id) {
    final tint = outfitColors[id] != null ? Color(outfitColors[id]!) : null;
    switch (id) {
      case 'hat_winter': _drawWinterBeanie(canvas, tint); break;
      case 'hat_straw': _drawStrawHat(canvas, tint); break;
      case 'hat_bucket': _drawBucketHat(canvas, tint); break;
      case 'hat_birthday': _drawCrown(canvas, tint); break;
      case 'hat_santa':
        final base = tint ?? const Color(0xFFE53935);
        final dark = HSLColor.fromColor(base).withLightness((HSLColor.fromColor(base).lightness - 0.15).clamp(0.0, 1.0)).toColor();
        final hatPath = Path()..moveTo(50, -6)..lineTo(30, 20)..quadraticBezierTo(50, 26, 70, 20)..close();
        canvas.drawPath(hatPath, Paint()..shader = _getCachedShader('santa_hat_eq_${base.toARGB32()}', hatPath.getBounds(), LinearGradient(colors: [base, dark], begin: Alignment.topCenter, end: Alignment.bottomCenter)));
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(27, 18, 46, 8), const Radius.circular(4)), Paint()..color = Colors.white);
        canvas.drawCircle(const Offset(50, -6), 6, Paint()..color = Colors.white);
        break;
      case 'hat_witch': _drawWitchHat(canvas, tint); break;
      case 'hat_nightcap': _drawNightcap(canvas, tint); break;
      case 'hat_detective': _drawDetectiveHat(canvas, tint); break;
      case 'hat_party': _drawPartyHat2(canvas, tint); break;
      case 'hat_ambassador': _drawAmbassadorCrown(canvas, tint); break;
      case 'hat_heart': _drawHeartHeadband(canvas, tint); break;
      case 'hat_crown_diamond': _drawDiamondCrown(canvas, tint); break;
      case 'hat_astronaut': _drawAstronautHelmet(canvas, tint); break;
      case 'hat_beret': _drawBeret(canvas, tint); break;
      case 'hat_baseball': _drawBaseballCap(canvas, tint); break;
      case 'hat_fedora': _drawFedora(canvas, tint); break;
      case 'hat_pirate': _drawPirateHat(canvas, tint); break;
      case 'hat_chef': _drawChefToque(canvas, tint); break;
      case 'hat_viking': _drawVikingHelmet(canvas, tint); break;
      case 'hat_halo': _drawHalo(canvas, tint); break;
      case 'hat_flower_crown': _drawFlowerCrown(canvas, tint); break;
      case 'hat_headband': _drawHeadband(canvas, tint); break;
      case 'hat_turban': _drawTurban(canvas, tint); break;
      case 'hat_tiara': _drawTiara(canvas, tint); break;
      case 'hat_earmuffs': _drawEarmuffs(canvas, tint); break;
    }
  }

  void _drawGlasses(Canvas canvas, String id) {
    final tint = outfitColors[id] != null ? Color(outfitColors[id]!) : null;
    switch (id) {
      case 'glasses_sun': _drawSunglasses(canvas, tint); break;
      case 'glasses_heart': _drawHeartGlasses(canvas, tint); break;
      case 'glasses_reading': _drawReadingGlasses(canvas, tint); break;
      case 'glasses_star': _drawStarGlasses(canvas, tint); break;
      case 'glasses_monocle': _drawMonocle(canvas, tint); break;
      case 'glasses_vr': _drawVRHeadset(canvas, tint); break;
      case 'glasses_round': _drawRoundGlasses(canvas, tint); break;
      case 'glasses_cat_eye': _drawCatEyeGlasses(canvas, tint); break;
      case 'glasses_ski': _drawSkiGoggles(canvas, tint); break;
      case 'glasses_3d': _draw3DGlasses(canvas, tint); break;
      case 'glasses_steampunk': _drawSteampunkGoggles(canvas, tint); break;
      case 'glasses_swim': _drawSwimGoggles(canvas, tint); break;
      case 'glasses_neon': _drawNeonGlasses(canvas, tint); break;
      case 'glasses_pixel': _drawPixelGlasses(canvas, tint); break;
      case 'glasses_rose': _drawRoseGlasses(canvas, tint); break;
      case 'glasses_aviator': _drawAviatorGlasses(canvas, tint); break;
      case 'glasses_shield': _drawShieldVisor(canvas, tint); break;
      case 'glasses_opera': _drawOperaMask(canvas, tint); break;
      case 'glasses_nerd': _drawNerdGlasses(canvas, tint); break;
      case 'glasses_half_moon': _drawHalfMoonGlasses(canvas, tint); break;
      case 'glasses_butterfly': _drawButterflyGlasses(canvas, tint); break;
      case 'glasses_eye_patch': _drawEyePatch(canvas, tint); break;
      case 'glasses_cyberpunk': _drawCyberpunkVisor(canvas, tint); break;
      case 'glasses_disco': _drawDiscoGlasses(canvas, tint); break;
      case 'glasses_loupe': _drawLoupe(canvas, tint); break;
    }
  }

  void _drawTop(Canvas canvas, String id) {
    final tint = outfitColors[id] != null ? Color(outfitColors[id]!) : null;
    switch (id) {
      case 'top_raincoat': _drawRaincoat(canvas, tint); break;
      case 'top_windbreaker': _drawWindbreaker(canvas, tint); break;
      case 'top_scarf_thick': _drawThickScarf(canvas, tint); break;
      case 'top_hawaiian': _drawHawaiianShirt(canvas, tint); break;
      case 'top_linen': _drawLinenShirt(canvas, tint); break;
      case 'top_pyjama': _drawPyjama(canvas, tint); break;
      case 'top_golden': _drawGenericTop(canvas, tint ?? const Color(0xFFFFD700), vNeck: true); break;
      case 'top_tuxedo': _drawTuxedo(canvas, tint); break;
      case 'top_hoodie': _drawHoodie(canvas, tint); break;
      case 'top_vest': _drawVest(canvas, tint); break;
      case 'top_turtleneck': _drawGenericTop(canvas, tint ?? const Color(0xFF212121), collar: true); break;
      case 'top_tank': _drawTank(canvas, tint); break;
      case 'top_blazer': _drawGenericTop(canvas, tint ?? const Color(0xFF1565C0), vNeck: true, buttons: true); break;
      case 'top_overalls': _drawOveralls(canvas, tint); break;
      case 'top_sweater': _drawGenericTop(canvas, tint ?? const Color(0xFFF5F5DC), collar: true, knit: true); break;
      case 'top_poncho': _drawPoncho(canvas, tint); break;
      case 'top_kimono': _drawKimono(canvas, tint); break;
      case 'top_lab_coat': _drawGenericTop(canvas, tint ?? const Color(0xFFF5F5F5), buttons: true); break;
      case 'top_apron': _drawApron(canvas, tint); break;
      case 'top_sailor': _drawSailor(canvas, tint); break;
      case 'top_varsity': _drawVarsity(canvas, tint); break;
      case 'top_denim': _drawGenericTop(canvas, tint ?? const Color(0xFF5C6BC0), buttons: true); break;
      case 'top_leather': _drawGenericTop(canvas, tint ?? const Color(0xFF3E2723), vNeck: true); break;
      case 'top_cardigan': _drawGenericTop(canvas, tint ?? const Color(0xFFBCAAA4), buttons: true, knit: true); break;
      case 'top_jersey': _drawJersey(canvas, tint); break;
    }
  }

  void _drawShoes(Canvas canvas, String id) {
    final tint = outfitColors[id] != null ? Color(outfitColors[id]!) : null;
    switch (id) {
      case 'shoes_boots': _drawRainBoots(canvas, tint); break;
      case 'shoes_flipflops': _drawFlipFlops(canvas, tint); break;
      case 'shoes_sandals': _drawSandals(canvas, tint); break;
      case 'shoes_slippers': _drawSlippers(canvas, tint); break;
      case 'shoes_golden': _drawGenericShoes(canvas, tint ?? const Color(0xFFFFD700)); break;
      case 'shoes_crystal': _drawGenericShoes(canvas, tint ?? const Color(0xFF81D4FA), crystal: true); break;
      case 'shoes_sneakers': _drawGenericShoes(canvas, tint ?? const Color(0xFFF5F5F5)); break;
      case 'shoes_heels': _drawHeels(canvas, tint); break;
      case 'shoes_cowboy': _drawCowboyBoots(canvas, tint); break;
      case 'shoes_ballet': _drawBalletShoes(canvas, tint); break;
      case 'shoes_roller': _drawRollerSkates(canvas, tint); break;
      case 'shoes_ice_skates': _drawIceSkates(canvas, tint); break;
      case 'shoes_crocs': _drawCrocs(canvas, tint); break;
      case 'shoes_platform': _drawPlatforms(canvas, tint); break;
      case 'shoes_moon': _drawMoonBoots(canvas, tint); break;
      case 'shoes_hiking': _drawHikingBoots(canvas, tint); break;
      case 'shoes_loafers': _drawGenericShoes(canvas, tint ?? const Color(0xFF795548)); break;
      case 'shoes_combat': _drawCombatBoots(canvas, tint); break;
      case 'shoes_running': _drawGenericShoes(canvas, tint ?? const Color(0xFFFF9800)); break;
      case 'shoes_clogs': _drawClogs(canvas, tint); break;
      case 'shoes_fuzzy': _drawFuzzySlippers(canvas, tint); break;
      case 'shoes_ski': _drawSkiBoots(canvas, tint); break;
      case 'shoes_gladiator': _drawGladiatorSandals(canvas, tint); break;
      case 'shoes_rocket': _drawRocketBoots(canvas, tint); break;
      case 'shoes_knight': _drawKnightBoots(canvas, tint); break;
    }
  }

  void _drawAccessory(Canvas canvas, String id) {
    final tint = outfitColors[id] != null ? Color(outfitColors[id]!) : null;
    switch (id) {
      // Behind-body items — already drawn at step 2, skip here
      case 'acc_cape': break;
      case 'acc_backpack': break;
      // Front items
      case 'acc_umbrella': _drawUmbrella(canvas, tint); break;
      case 'acc_flowers': _drawBouquet(canvas, tint); break;
      case 'acc_flag': _drawFlag(canvas); break;
      case 'acc_pumpkin': _drawPumpkin(canvas, tint); break;
      case 'acc_star': _drawStarWand(canvas, tint); break;
      case 'acc_egg': _drawEasterEgg(canvas, tint); break;
      case 'acc_bowtie': _drawBowtie(canvas, tint); break;
      case 'acc_gift': _drawGiftBox(canvas, tint); break;
      case 'acc_wand': _drawMagicWand(canvas, tint); break;
      case 'acc_guitar': _drawGuitar(canvas, tint); break;
      case 'acc_skateboard': _drawSkateboard(canvas, tint); break;
      case 'acc_teddy': _drawTeddy(canvas, tint); break;
      case 'acc_balloon': _drawBalloon(canvas, tint); break;
      case 'acc_lantern': _drawLantern(canvas, tint); break;
      case 'acc_shield': _drawShield(canvas, tint); break;
      case 'acc_book': _drawGrimoire(canvas, tint); break;
      case 'acc_crystal_ball': _drawCrystalBall(canvas, tint); break;
      case 'acc_fishing_rod': _drawFishingRod(canvas, tint); break;
      case 'acc_paint_palette': _drawPaintPalette(canvas, tint); break;
      case 'acc_sword': _drawSword(canvas, tint); break;
      case 'acc_trophy': _drawTrophy(canvas, tint); break;
      case 'acc_friendship': _drawFriendshipBracelet(canvas, tint); break;
    }
  }

  // ─────────────────── HAT DRAWING ───────────────────

  void _drawWinterBeanie(Canvas canvas, [Color? tint]) {
    final primary = tint ?? const Color(0xFF1565C0);
    final hsl = HSLColor.fromColor(primary);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Shadow
    canvas.drawPath(
      (Path()..moveTo(28, 18)..quadraticBezierTo(30, -3, 50, -6)..quadraticBezierTo(70, -3, 72, 18)..close()).shift(const Offset(0, 2)),
      Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Dome
    final dome = Path()..moveTo(28, 18)..quadraticBezierTo(30, -3, 50, -6)..quadraticBezierTo(70, -3, 72, 18)..close();
    canvas.drawPath(dome, Paint()..color = primary);
    // Stripe
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(28, 8, 44, 5), const Radius.circular(2)),
      Paint()..color = hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor(),
    );
    // Brim roll
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(25, 14, 50, 10), const Radius.circular(5)),
      Paint()..color = dark,
    );
    // Pompom
    canvas.drawCircle(const Offset(50, -9), 7, Paint()..color = Colors.white70);
    canvas.drawCircle(const Offset(50, -9), 5, Paint()..color = Colors.white);
  }

  void _drawStrawHat(Canvas canvas, [Color? tint]) {
    final straw = tint ?? const Color(0xFFD4A853);
    final hsl = HSLColor.fromColor(straw);
    final darkStraw = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
    // Shadow
    canvas.drawOval(const Rect.fromLTWH(10, 14, 80, 9),
        Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    // Brim
    canvas.drawOval(const Rect.fromLTWH(10, 12, 80, 9), Paint()..color = straw);
    canvas.drawOval(const Rect.fromLTWH(10, 15, 80, 6), Paint()..color = darkStraw.withValues(alpha: 0.35));
    // Crown
    final dome = Path()
      ..moveTo(30, 14)
      ..quadraticBezierTo(32, -2, 50, -5)
      ..quadraticBezierTo(68, -2, 70, 14)
      ..close();
    canvas.drawPath(dome, Paint()..color = straw);
    // Hatband
    canvas.drawRect(const Rect.fromLTWH(30, 9, 40, 5), Paint()..color = darkStraw);
  }

  void _drawBucketHat(Canvas canvas, [Color? tint]) {
    final base = tint ?? const Color(0xFF90CAF9);
    final hsl = HSLColor.fromColor(base);
    final dark = hsl.withLightness((hsl.lightness - 0.14).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    final crown = RRect.fromRectAndRadius(const Rect.fromLTWH(28, 0, 44, 18), const Radius.circular(9));
    canvas.drawRRect(crown, Paint()..color = base);
    final brim = Path()
      ..moveTo(18, 16)
      ..quadraticBezierTo(30, 10, 50, 10)
      ..quadraticBezierTo(70, 10, 82, 16)
      ..quadraticBezierTo(72, 24, 50, 24)
      ..quadraticBezierTo(28, 24, 18, 16)
      ..close();
    canvas.drawPath(brim, Paint()..color = dark);
    canvas.drawLine(const Offset(30, 6), const Offset(70, 6), Paint()..color = light..strokeWidth = 2);
  }

  void _drawCrown(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFFFD700);
    final hsl = HSLColor.fromColor(gold);
    final darkGold = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final lightGold = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    // Shadow — widened to match head
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(26, 14, 48, 11), const Radius.circular(3)),
      Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Base band
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(26, 12, 48, 11), const Radius.circular(3)),
      Paint()..color = darkGold,
    );
    // Crown points
    final crownPath = Path()
      ..moveTo(26, 12)
      ..lineTo(26, 0)
      ..lineTo(38, 10)
      ..lineTo(50, -6)
      ..lineTo(62, 10)
      ..lineTo(74, 0)
      ..lineTo(74, 12)
      ..close();
    canvas.drawPath(crownPath, Paint()..shader = _getCachedShader(
      'crown_${gold.toARGB32()}', crownPath.getBounds(),
      LinearGradient(colors: [lightGold, gold, darkGold], begin: Alignment.topCenter, end: Alignment.bottomCenter),
    ));
    // Gems
    canvas.drawCircle(const Offset(50, 0), 4, Paint()..color = const Color(0xFFE53935));
    canvas.drawCircle(const Offset(50, 0), 2, Paint()..color = Colors.white54);
    canvas.drawCircle(const Offset(34, 8), 3, Paint()..color = const Color(0xFF42A5F5));
    canvas.drawCircle(const Offset(66, 8), 3, Paint()..color = const Color(0xFF66BB6A));
  }

  void _drawWitchHat(Canvas canvas, [Color? tint]) {
    final purple = tint ?? const Color(0xFF7B1FA2);
    final hsl = HSLColor.fromColor(purple);
    final darkPurple = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    const gold = Color(0xFFFFD700);
    // Shadow
    canvas.drawOval(const Rect.fromLTWH(16, 15, 68, 9),
        Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    // Brim
    canvas.drawOval(const Rect.fromLTWH(16, 13, 68, 9), Paint()..color = darkPurple);
    // Cone
    final cone = Path()..moveTo(28, 16)..lineTo(50, -22)..lineTo(72, 16)..close();
    canvas.drawPath(cone, Paint()..color = darkPurple);
    // Band
    canvas.drawRect(const Rect.fromLTWH(28, 10, 44, 6), Paint()..color = purple);
    // Buckle
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(45, 9, 10, 8), const Radius.circular(2)), Paint()..color = gold);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(47, 11, 6, 4), const Radius.circular(1)), Paint()..color = darkPurple);
  }

  void _drawNightcap(Canvas canvas, [Color? tint]) {
    final blue = tint ?? const Color(0xFF3949AB);
    final hsl = HSLColor.fromColor(blue);
    final lightBlue = hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0)).toColor();
    // Droopy cap shape
    final cap = Path()..moveTo(30, 16)..quadraticBezierTo(50, 8, 65, -8)..quadraticBezierTo(60, 0, 70, 16)..close();
    canvas.drawPath(cap, Paint()..color = blue);
    // Band at bottom
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 14, 40, 5), const Radius.circular(2)), Paint()..color = lightBlue);
    // Pompom at tip
    canvas.drawCircle(const Offset(65, -8), 5, Paint()..color = Colors.white);
    // Moon decoration
    final moon = Path()
      ..addArc(const Rect.fromLTWH(44, 2, 12, 12), -0.5, 3.14)
      ..close();
    canvas.drawPath(moon, Paint()..color = const Color(0xFFFFD54F));
  }

  void _drawDetectiveHat(Canvas canvas, [Color? tint]) {
    final brown = tint ?? const Color(0xFF5D4037);
    final hsl = HSLColor.fromColor(brown);
    final darkBrown = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    // Brim
    canvas.drawOval(const Rect.fromLTWH(18, 13, 64, 10), Paint()..color = darkBrown);
    // Crown
    final crown = Path()..moveTo(26, 16)..quadraticBezierTo(38, -6, 50, 8)..quadraticBezierTo(62, -6, 74, 16)..close();
    canvas.drawPath(crown, Paint()..color = brown);
    // Band
    canvas.drawRect(const Rect.fromLTWH(26, 11, 48, 5), Paint()..color = darkBrown);
  }

  void _drawPartyHat2(Canvas canvas, [Color? tint]) {
    final primary = tint ?? const Color(0xFFFF7043);
    // Striped cone — widened to match head
    final cone = Path()..moveTo(30, 20)..lineTo(50, -10)..lineTo(70, 20)..close();
    canvas.drawPath(cone, Paint()..color = primary);
    // Stripe
    canvas.drawLine(const Offset(40, 4), const Offset(60, 4), Paint()..color = Colors.white..strokeWidth = 3);
    canvas.drawLine(const Offset(36, 12), const Offset(64, 12), Paint()..color = const Color(0xFFFFD54F)..strokeWidth = 3);
    // Pom pom
    canvas.drawCircle(const Offset(50, -10), 4, Paint()..color = const Color(0xFFE91E63));
    // Elastic
    canvas.drawLine(const Offset(30, 20), const Offset(24, 28), Paint()..color = Colors.white54..strokeWidth = 1);
    canvas.drawLine(const Offset(70, 20), const Offset(76, 28), Paint()..color = Colors.white54..strokeWidth = 1);
  }

  void _drawAmbassadorCrown(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFFFD700);
    final hsl = HSLColor.fromColor(gold);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    // Base band — ornate, wider
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(24, 12, 52, 12), const Radius.circular(3)), Paint()..color = dark);
    // Crown points — 5 points for ambassador
    final p = Path()..moveTo(24, 12)..lineTo(26, -2)..lineTo(34, 10)..lineTo(42, -4)..lineTo(50, 8)..lineTo(58, -4)..lineTo(66, 10)..lineTo(74, -2)..lineTo(76, 12)..close();
    canvas.drawPath(p, Paint()..shader = _getCachedShader('amb_crown_${gold.toARGB32()}', p.getBounds(), LinearGradient(colors: [light, gold, dark], begin: Alignment.topCenter, end: Alignment.bottomCenter)));
    // Gems on each point
    for (final cx in [34.0, 42.0, 50.0, 58.0, 66.0]) {
      canvas.drawCircle(Offset(cx, 6), 2.5, Paint()..color = const Color(0xFF4CAF50));
      canvas.drawCircle(Offset(cx, 6), 1.2, Paint()..color = Colors.white54);
    }
    // Center large gem
    canvas.drawCircle(const Offset(50, 2), 4, Paint()..color = const Color(0xFFE53935));
    canvas.drawCircle(const Offset(50, 2), 2, Paint()..color = Colors.white54);
  }

  void _drawHeartHeadband(Canvas canvas, [Color? tint]) {
    final pink = tint ?? const Color(0xFFE91E63);
    // Headband arc
    final band = Path()..moveTo(24, 20)..quadraticBezierTo(50, 10, 76, 20);
    canvas.drawPath(band, Paint()..color = pink..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round);
    // Two bouncy hearts on top
    void heart(Offset c, double r) {
      final h = Path()..moveTo(c.dx, c.dy + r * 0.5)..cubicTo(c.dx + r, c.dy + r * 0.1, c.dx + r * 1.2, c.dy - r * 0.7, c.dx, c.dy - r * 0.2)..cubicTo(c.dx - r * 1.2, c.dy - r * 0.7, c.dx - r, c.dy + r * 0.1, c.dx, c.dy + r * 0.5);
      canvas.drawPath(h, Paint()..color = pink);
    }
    heart(const Offset(38, 8), 7);
    heart(const Offset(62, 8), 7);
  }

  void _drawDiamondCrown(Canvas canvas, [Color? tint]) {
    final silver = tint ?? const Color(0xFFB0BEC5);
    final hsl = HSLColor.fromColor(silver);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    // Base
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 12, 48, 11), const Radius.circular(3)), Paint()..color = dark);
    // Points
    final p = Path()..moveTo(26, 12)..lineTo(26, 0)..lineTo(38, 10)..lineTo(50, -6)..lineTo(62, 10)..lineTo(74, 0)..lineTo(74, 12)..close();
    canvas.drawPath(p, Paint()..shader = _getCachedShader('dia_crown_${silver.toARGB32()}', p.getBounds(), LinearGradient(colors: [light, silver, dark])));
    // Diamond gems — white/blue sparkle
    for (final cx in [36.0, 50.0, 64.0]) {
      final d = Path()..moveTo(cx, 2)..lineTo(cx + 4, 7)..lineTo(cx, 12)..lineTo(cx - 4, 7)..close();
      canvas.drawPath(d, Paint()..color = const Color(0xFF81D4FA));
      canvas.drawPath(d, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }
  }

  void _drawAstronautHelmet(Canvas canvas, [Color? tint]) {
    final white = tint ?? const Color(0xFFECEFF1);
    final dark = const Color(0xFF78909C);
    // Dome — larger, covers whole head
    final dome = Path()..moveTo(20, 28)..quadraticBezierTo(20, -14, 50, -16)..quadraticBezierTo(80, -14, 80, 28)..lineTo(76, 34)..quadraticBezierTo(50, 40, 24, 34)..close();
    canvas.drawPath(dome, Paint()..color = white);
    canvas.drawPath(dome, Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 2);
    // Visor — dark reflective
    final visor = Path()..moveTo(30, 18)..quadraticBezierTo(30, 4, 50, 2)..quadraticBezierTo(70, 4, 70, 18)..quadraticBezierTo(70, 28, 50, 30)..quadraticBezierTo(30, 28, 30, 18)..close();
    canvas.drawPath(visor, Paint()..color = const Color(0xFF37474F));
    // Reflection on visor
    canvas.drawLine(const Offset(36, 10), const Offset(44, 20), Paint()..color = Colors.white30..strokeWidth = 3..strokeCap = StrokeCap.round);
    // Side details
    canvas.drawCircle(const Offset(24, 22), 3, Paint()..color = dark);
    canvas.drawCircle(const Offset(76, 22), 3, Paint()..color = dark);
  }

  void _drawBeret(Canvas canvas, [Color? tint]) {
    final red = tint ?? const Color(0xFFE53935);
    final hsl = HSLColor.fromColor(red);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Flat beret shape — tilted slightly
    final beret = Path()..moveTo(26, 18)..quadraticBezierTo(28, 2, 50, 0)..quadraticBezierTo(78, 2, 76, 18)..close();
    canvas.drawPath(beret, Paint()..color = red);
    // Band at bottom
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 15, 50, 5), const Radius.circular(2)), Paint()..color = dark);
    // Small stem on top
    canvas.drawCircle(const Offset(50, 0), 3, Paint()..color = dark);
  }

  void _drawBaseballCap(Canvas canvas, [Color? tint]) {
    final navy = tint ?? const Color(0xFF1565C0);
    final hsl = HSLColor.fromColor(navy);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Crown
    final crown = Path()..moveTo(28, 18)..quadraticBezierTo(30, 0, 50, -2)..quadraticBezierTo(70, 0, 72, 18)..close();
    canvas.drawPath(crown, Paint()..color = navy);
    // Visor — forward-facing curved brim
    final visor = Path()..moveTo(28, 17)..quadraticBezierTo(50, 14, 72, 17)..quadraticBezierTo(78, 26, 50, 28)..quadraticBezierTo(22, 26, 28, 17)..close();
    canvas.drawPath(visor, Paint()..color = dark);
    // Button on top
    canvas.drawCircle(const Offset(50, -2), 3, Paint()..color = dark);
    // Seam lines
    canvas.drawLine(const Offset(50, -2), const Offset(50, 16), Paint()..color = dark.withValues(alpha: 0.3)..strokeWidth = 1);
  }

  void _drawFedora(Canvas canvas, [Color? tint]) {
    final grey = tint ?? const Color(0xFF424242);
    final hsl = HSLColor.fromColor(grey);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    // Brim
    canvas.drawOval(const Rect.fromLTWH(14, 13, 72, 10), Paint()..color = dark);
    // Crown with indentation
    final crown = Path()..moveTo(28, 16)..quadraticBezierTo(30, -1, 50, 2)..quadraticBezierTo(70, -1, 72, 16)..close();
    canvas.drawPath(crown, Paint()..color = grey);
    // Crown dent
    canvas.drawLine(const Offset(36, 4), const Offset(64, 4), Paint()..color = dark..strokeWidth = 2);
    // Hatband with bow
    canvas.drawRect(const Rect.fromLTWH(28, 11, 44, 5), Paint()..color = light);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 12, 6, 4), const Radius.circular(1)), Paint()..color = dark);
  }

  void _drawPirateHat(Canvas canvas, [Color? tint]) {
    final black = tint ?? const Color(0xFF212121);
    final dark = const Color(0xFF111111);
    // Tricorn shape
    final hat = Path()..moveTo(14, 18)..quadraticBezierTo(20, -2, 50, -10)..quadraticBezierTo(80, -2, 86, 18)..quadraticBezierTo(70, 22, 50, 20)..quadraticBezierTo(30, 22, 14, 18)..close();
    canvas.drawPath(hat, Paint()..color = black);
    // Brim fold-up
    canvas.drawPath(Path()..moveTo(18, 18)..quadraticBezierTo(50, 12, 82, 18)..quadraticBezierTo(50, 24, 18, 18)..close(), Paint()..color = dark);
    // Skull & crossbones emblem
    canvas.drawCircle(const Offset(50, 6), 5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(48, 5), 1.5, Paint()..color = black);
    canvas.drawCircle(const Offset(52, 5), 1.5, Paint()..color = black);
    canvas.drawLine(const Offset(44, 10), const Offset(56, 2), Paint()..color = Colors.white..strokeWidth = 2);
    canvas.drawLine(const Offset(44, 2), const Offset(56, 10), Paint()..color = Colors.white..strokeWidth = 2);
  }

  void _drawChefToque(Canvas canvas, [Color? tint]) {
    final white = tint ?? const Color(0xFFF5F5F5);
    final cream = const Color(0xFFE0E0E0);
    // Tall puffy dome
    final dome = Path()..moveTo(30, 16)..quadraticBezierTo(28, -8, 40, -14)..quadraticBezierTo(50, -18, 60, -14)..quadraticBezierTo(72, -8, 70, 16)..close();
    canvas.drawPath(dome, Paint()..color = white);
    // Puffy bulges
    canvas.drawCircle(const Offset(38, -6), 9, Paint()..color = white);
    canvas.drawCircle(const Offset(50, -10), 10, Paint()..color = white);
    canvas.drawCircle(const Offset(62, -6), 9, Paint()..color = white);
    // Band at bottom
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(28, 12, 44, 7), const Radius.circular(3)), Paint()..color = cream);
  }

  void _drawVikingHelmet(Canvas canvas, [Color? tint]) {
    final iron = tint ?? const Color(0xFF78909C);
    final dark = const Color(0xFF546E7A);
    final gold = const Color(0xFFFFD700);
    // Helmet dome
    final dome = Path()..moveTo(26, 20)..quadraticBezierTo(28, -2, 50, -4)..quadraticBezierTo(72, -2, 74, 20)..close();
    canvas.drawPath(dome, Paint()..color = iron);
    // Nose guard
    canvas.drawLine(const Offset(50, -2), const Offset(50, 26), Paint()..color = dark..strokeWidth = 3);
    // Eye guards
    canvas.drawPath(Path()..moveTo(30, 18)..lineTo(48, 18)..lineTo(48, 24)..lineTo(30, 22)..close(), Paint()..color = dark);
    canvas.drawPath(Path()..moveTo(52, 18)..lineTo(70, 18)..lineTo(70, 22)..lineTo(52, 24)..close(), Paint()..color = dark);
    // Horns
    final leftHorn = Path()..moveTo(26, 12)..quadraticBezierTo(10, -4, 8, -16)..quadraticBezierTo(14, -12, 18, -8)..quadraticBezierTo(24, 0, 30, 10)..close();
    canvas.drawPath(leftHorn, Paint()..color = gold);
    final rightHorn = Path()..moveTo(74, 12)..quadraticBezierTo(90, -4, 92, -16)..quadraticBezierTo(86, -12, 82, -8)..quadraticBezierTo(76, 0, 70, 10)..close();
    canvas.drawPath(rightHorn, Paint()..color = gold);
  }

  void _drawHalo(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFFFD700);
    // Floating golden ring above head
    canvas.drawOval(const Rect.fromLTWH(30, -12, 40, 10), Paint()..color = gold.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawOval(const Rect.fromLTWH(30, -12, 40, 10), Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 4);
    canvas.drawOval(const Rect.fromLTWH(32, -10, 36, 7), Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _drawFlowerCrown(Canvas canvas, [Color? tint]) {
    final green = tint ?? const Color(0xFF4CAF50);
    // Vine wreath base
    final vine = Path()..moveTo(24, 16)..quadraticBezierTo(30, 6, 50, 4)..quadraticBezierTo(70, 6, 76, 16);
    canvas.drawPath(vine, Paint()..color = green..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round);
    // Flowers along the crown
    final flowerColors = [const Color(0xFFFF7043), const Color(0xFFFFEB3B), const Color(0xFFE91E63), const Color(0xFF7E57C2), const Color(0xFFFF7043)];
    final flowerX = [28.0, 38.0, 50.0, 62.0, 72.0];
    for (int i = 0; i < 5; i++) {
      final t = (flowerX[i] - 24) / 52;
      final y = 16 - 12 * 4 * t * (1 - t);
      for (double a = 0; a < 6.28; a += 1.26) {
        canvas.drawCircle(Offset(flowerX[i] + 4 * math.cos(a), y + 4 * math.sin(a)), 3, Paint()..color = flowerColors[i]);
      }
      canvas.drawCircle(Offset(flowerX[i], y), 2.5, Paint()..color = Colors.amber);
    }
  }

  void _drawHeadband(Canvas canvas, [Color? tint]) {
    final neon = tint ?? const Color(0xFF76FF03);
    final dark = HSLColor.fromColor(neon).withLightness((HSLColor.fromColor(neon).lightness - 0.2).clamp(0.0, 1.0)).toColor();
    // Sport headband — thick elastic band across forehead
    final band = Path()..moveTo(22, 16)..quadraticBezierTo(50, 8, 78, 16)..lineTo(78, 22)..quadraticBezierTo(50, 14, 22, 22)..close();
    canvas.drawPath(band, Paint()..color = neon);
    // Center logo mark
    canvas.drawCircle(const Offset(50, 16), 3, Paint()..color = dark);
  }

  void _drawTurban(Canvas canvas, [Color? tint]) {
    final purple = tint ?? const Color(0xFF7B1FA2);
    final hsl = HSLColor.fromColor(purple);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Wrapped layers
    final base = Path()..moveTo(24, 20)..quadraticBezierTo(24, -6, 50, -8)..quadraticBezierTo(76, -6, 76, 20)..close();
    canvas.drawPath(base, Paint()..color = purple);
    // Wrap folds
    canvas.drawPath(Path()..moveTo(28, 14)..quadraticBezierTo(50, 4, 72, 14), Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 2.5);
    canvas.drawPath(Path()..moveTo(30, 8)..quadraticBezierTo(50, -2, 70, 8), Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 2);
    // Jewel centerpiece
    canvas.drawCircle(const Offset(50, 6), 5, Paint()..color = const Color(0xFFFFD700));
    canvas.drawCircle(const Offset(50, 6), 3, Paint()..color = const Color(0xFFE53935));
    canvas.drawCircle(const Offset(50, 6), 1.5, Paint()..color = Colors.white54);
    // Feather plume
    final feather = Path()..moveTo(50, 2)..quadraticBezierTo(56, -10, 58, -18)..quadraticBezierTo(54, -12, 50, -4);
    canvas.drawPath(feather, Paint()..color = const Color(0xFFFFD700)..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  void _drawTiara(Canvas canvas, [Color? tint]) {
    final silver = tint ?? const Color(0xFFE0E0E0);
    final sparkle = const Color(0xFF81D4FA);
    // Delicate tiara arc
    final arc = Path()..moveTo(28, 18)..quadraticBezierTo(36, 8, 42, 6)..lineTo(46, -2)..lineTo(50, 4)..lineTo(54, -2)..lineTo(58, 6)..quadraticBezierTo(64, 8, 72, 18);
    canvas.drawPath(arc, Paint()..color = silver..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
    // Crystal drops
    for (final x in [42.0, 50.0, 58.0]) {
      final d = Path()..moveTo(x, 0)..lineTo(x + 3, 5)..lineTo(x, 10)..lineTo(x - 3, 5)..close();
      canvas.drawPath(d, Paint()..color = sparkle);
      canvas.drawPath(d, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 0.6);
    }
  }

  void _drawEarmuffs(Canvas canvas, [Color? tint]) {
    final pink = tint ?? const Color(0xFFF48FB1);
    final dark = HSLColor.fromColor(pink).withLightness((HSLColor.fromColor(pink).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Headband arc over the head
    final band = Path()..moveTo(22, 22)..quadraticBezierTo(50, -8, 78, 22);
    canvas.drawPath(band, Paint()..color = const Color(0xFF424242)..style = PaintingStyle.stroke..strokeWidth = 3);
    // Left muff
    canvas.drawCircle(const Offset(22, 24), 10, Paint()..color = pink);
    canvas.drawCircle(const Offset(22, 24), 7, Paint()..color = dark);
    // Right muff
    canvas.drawCircle(const Offset(78, 24), 10, Paint()..color = pink);
    canvas.drawCircle(const Offset(78, 24), 7, Paint()..color = dark);
  }

  void _drawEasterEgg(Canvas canvas, [Color? tint]) {
    final eggColor = tint ?? const Color(0xFF81D4FA);
    // Held at right side, tilted
    canvas.save();
    canvas.translate(72, 70);
    canvas.rotate(0.3);
    // Egg shape
    final egg = Path()..addOval(const Rect.fromLTWH(-6, -10, 12, 16));
    canvas.drawPath(egg, Paint()..color = eggColor);
    // Stripes
    canvas.drawLine(const Offset(-4, -4), const Offset(4, -4), Paint()..color = const Color(0xFFFF80AB)..strokeWidth = 2);
    canvas.drawLine(const Offset(-5, 0), const Offset(5, 0), Paint()..color = const Color(0xFFFFD54F)..strokeWidth = 2);
    canvas.drawLine(const Offset(-4, 4), const Offset(4, 4), Paint()..color = const Color(0xFFA5D6A7)..strokeWidth = 2);
    canvas.restore();
  }

  void _drawBowtie(Canvas canvas, [Color? tint]) {
    final red = tint ?? const Color(0xFFE53935);
    final hsl = HSLColor.fromColor(red);
    final darkRed = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Left triangle
    final left = Path()..moveTo(50, 50)..lineTo(38, 44)..lineTo(38, 56)..close();
    canvas.drawPath(left, Paint()..color = red);
    // Right triangle
    final right = Path()..moveTo(50, 50)..lineTo(62, 44)..lineTo(62, 56)..close();
    canvas.drawPath(right, Paint()..color = red);
    // Center knot
    canvas.drawCircle(const Offset(50, 50), 3, Paint()..color = darkRed);
  }

  void _drawCape(Canvas canvas, [Color? tint]) {
    final red = tint ?? const Color(0xFFD32F2F);
    final hsl = HSLColor.fromColor(red);
    final darkRed = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    // Cape flows behind body — drawn as a wide flowing shape
    final cape = Path()
      ..moveTo(30, 50)
      ..quadraticBezierTo(25, 80, 20, 115)
      ..lineTo(80, 115)
      ..quadraticBezierTo(75, 80, 70, 50)
      ..close();
    canvas.drawPath(cape, Paint()..color = red);
    // Inner lining
    final inner = Path()
      ..moveTo(35, 55)
      ..quadraticBezierTo(32, 80, 28, 110)
      ..lineTo(72, 110)
      ..quadraticBezierTo(68, 80, 65, 55)
      ..close();
    canvas.drawPath(inner, Paint()..color = darkRed);
  }

  // ─────────────────── GLASSES DRAWING ───────────────────

  void _drawSunglasses(Canvas canvas, [Color? tint]) {
    final c = tint ?? const Color(0xFF1F2937);
    final hsl = HSLColor.fromColor(c);
    final dark = hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
    // Bridge with shadow
    canvas.drawLine(const Offset(32, 27), const Offset(68, 27),
        Paint()..color = Colors.black12..strokeWidth = 2.5..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
    canvas.drawLine(const Offset(32, 26), const Offset(68, 26), Paint()..color = c..strokeWidth = 2);
    // Left lens — gradient
    const leftRect = Rect.fromLTWH(30, 22, 16, 12);
    drawDropShadow(canvas, Path()..addRRect(RRect.fromRectAndRadius(leftRect, const Radius.circular(3))), blur: 1.5, offset: const Offset(0.5, 1));
    canvas.drawRRect(RRect.fromRectAndRadius(leftRect, const Radius.circular(3)), clayFill('sunglass_l', leftRect, c));
    drawSpecular(canvas, const Offset(35, 25), 2.5);
    // Right lens — gradient
    const rightRect = Rect.fromLTWH(54, 22, 16, 12);
    drawDropShadow(canvas, Path()..addRRect(RRect.fromRectAndRadius(rightRect, const Radius.circular(3))), blur: 1.5, offset: const Offset(0.5, 1));
    canvas.drawRRect(RRect.fromRectAndRadius(rightRect, const Radius.circular(3)), clayFill('sunglass_r', rightRect, c));
    drawSpecular(canvas, const Offset(59, 25), 2.5);
    // Glare streaks
    canvas.drawLine(const Offset(34, 24), const Offset(42, 32), Paint()..color = Colors.white24..strokeWidth = 2);
    canvas.drawLine(const Offset(58, 24), const Offset(66, 32), Paint()..color = Colors.white24..strokeWidth = 2);
    // Temples
    canvas.drawLine(const Offset(30, 26), const Offset(22, 28), Paint()..color = dark..strokeWidth = 2);
    canvas.drawLine(const Offset(70, 26), const Offset(78, 28), Paint()..color = dark..strokeWidth = 2);
  }

  void _drawHeartGlasses(Canvas canvas, [Color? tint]) {
    final pink = tint ?? const Color(0xFFE91E63);
    // Bridge
    canvas.drawLine(const Offset(46, 28), const Offset(54, 28), Paint()..color = pink..strokeWidth = 2.5);
    // Temples
    canvas.drawLine(const Offset(26, 27), const Offset(20, 29), Paint()..color = pink..strokeWidth = 2);
    canvas.drawLine(const Offset(74, 27), const Offset(80, 29), Paint()..color = pink..strokeWidth = 2);
    // Hearts
    final leftHeart = Path();
    _addHeartPath(leftHeart, const Offset(36, 29), 10);
    canvas.drawPath(leftHeart, Paint()..color = pink);
    canvas.drawCircle(const Offset(30, 24), 2, Paint()..color = Colors.white54);

    final rightHeart = Path();
    _addHeartPath(rightHeart, const Offset(64, 29), 10);
    canvas.drawPath(rightHeart, Paint()..color = pink);
    canvas.drawCircle(const Offset(58, 24), 2, Paint()..color = Colors.white54);
  }

  void _addHeartPath(Path path, Offset center, double r) {
    path.moveTo(center.dx, center.dy + r * 0.5);
    path.cubicTo(
      center.dx + r * 1.0, center.dy + r * 0.1,
      center.dx + r * 1.2, center.dy - r * 0.7,
      center.dx, center.dy - r * 0.2,
    );
    path.cubicTo(
      center.dx - r * 1.2, center.dy - r * 0.7,
      center.dx - r * 1.0, center.dy + r * 0.1,
      center.dx, center.dy + r * 0.5,
    );
    path.close();
  }

  void _drawReadingGlasses(Canvas canvas, [Color? tint]) {
    final brown = tint ?? const Color(0xFF795548);
    final framePaint = Paint()..color = brown..style = PaintingStyle.stroke..strokeWidth = 3;
    // Bridge
    canvas.drawLine(const Offset(46, 28), const Offset(54, 28), Paint()..color = brown..strokeWidth = 2.5);
    // Tinted lenses
    canvas.drawCircle(const Offset(36, 29), 10, Paint()..color = Colors.amber.withValues(alpha: 0.18));
    canvas.drawCircle(const Offset(64, 29), 10, Paint()..color = Colors.amber.withValues(alpha: 0.18));
    // Round frames
    canvas.drawCircle(const Offset(36, 29), 10, framePaint);
    canvas.drawCircle(const Offset(64, 29), 10, framePaint);
    // Temples
    canvas.drawLine(const Offset(26, 28), const Offset(20, 30), Paint()..color = brown..strokeWidth = 2.5);
    canvas.drawLine(const Offset(74, 28), const Offset(80, 30), Paint()..color = brown..strokeWidth = 2.5);
    // Glints
    canvas.drawLine(const Offset(29, 23), const Offset(32, 26), Paint()..color = Colors.white54..strokeWidth = 2..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(57, 23), const Offset(60, 26), Paint()..color = Colors.white54..strokeWidth = 2..strokeCap = StrokeCap.round);
  }

  void _drawStarGlasses(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFFFD700);
    canvas.drawLine(const Offset(46, 28), const Offset(54, 28), Paint()..color = gold..strokeWidth = 2.5);
    canvas.drawLine(const Offset(26, 27), const Offset(20, 29), Paint()..color = gold..strokeWidth = 2);
    canvas.drawLine(const Offset(74, 27), const Offset(80, 29), Paint()..color = gold..strokeWidth = 2);
    _drawStarShape(canvas, const Offset(36, 28), 11, Paint()..color = gold);
    _drawStarShape(canvas, const Offset(64, 28), 11, Paint()..color = gold);
    canvas.drawCircle(const Offset(32, 24), 2, Paint()..color = Colors.white54);
    canvas.drawCircle(const Offset(60, 24), 2, Paint()..color = Colors.white54);
  }

  void _drawMonocle(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFD4A853);
    canvas.drawCircle(const Offset(64, 29), 11, Paint()..color = Colors.amber.withValues(alpha: 0.12));
    canvas.drawCircle(const Offset(64, 29), 11, Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawLine(const Offset(64, 40), const Offset(60, 70), Paint()..color = gold..strokeWidth = 1.5);
    canvas.drawLine(const Offset(57, 23), const Offset(60, 26), Paint()..color = Colors.white54..strokeWidth = 2..strokeCap = StrokeCap.round);
  }

  void _drawVRHeadset(Canvas canvas, [Color? tint]) {
    final white = tint ?? const Color(0xFFECEFF1);
    final dark = const Color(0xFF37474F);
    final visor = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 18, 56, 22), const Radius.circular(8));
    canvas.drawRRect(visor, Paint()..color = white);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 22, 48, 14), const Radius.circular(5)), Paint()..color = dark);
    canvas.drawLine(const Offset(32, 26), const Offset(38, 32), Paint()..color = const Color(0xFF2196F3).withValues(alpha: 0.4)..strokeWidth = 2);
    canvas.drawLine(const Offset(20, 28), const Offset(16, 28), Paint()..color = white..strokeWidth = 3);
    canvas.drawLine(const Offset(80, 28), const Offset(84, 28), Paint()..color = white..strokeWidth = 3);
  }

  void _drawRoundGlasses(Canvas canvas, [Color? tint]) {
    final wire = tint ?? const Color(0xFF9E9E9E);
    final frame = Paint()..color = wire..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawLine(const Offset(46, 28), const Offset(54, 28), Paint()..color = wire..strokeWidth = 2);
    canvas.drawCircle(const Offset(36, 29), 10, Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.08));
    canvas.drawCircle(const Offset(64, 29), 10, Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.08));
    canvas.drawCircle(const Offset(36, 29), 10, frame);
    canvas.drawCircle(const Offset(64, 29), 10, frame);
    canvas.drawLine(const Offset(26, 28), const Offset(20, 30), Paint()..color = wire..strokeWidth = 2);
    canvas.drawLine(const Offset(74, 28), const Offset(80, 30), Paint()..color = wire..strokeWidth = 2);
  }

  void _drawCatEyeGlasses(Canvas canvas, [Color? tint]) {
    final black = tint ?? const Color(0xFF212121);
    final frame = Paint()..color = black..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawLine(const Offset(46, 27), const Offset(54, 27), Paint()..color = black..strokeWidth = 2.5);
    // Cat-eye shape: wider at top-outer corners
    final left = Path()..moveTo(26, 30)..quadraticBezierTo(26, 22, 36, 20)..quadraticBezierTo(48, 22, 46, 30)..quadraticBezierTo(44, 36, 36, 36)..quadraticBezierTo(26, 36, 26, 30)..close();
    final right = Path()..moveTo(54, 30)..quadraticBezierTo(52, 22, 64, 20)..quadraticBezierTo(74, 22, 74, 30)..quadraticBezierTo(74, 36, 64, 36)..quadraticBezierTo(56, 36, 54, 30)..close();
    canvas.drawPath(left, Paint()..color = Colors.purple.withValues(alpha: 0.1));
    canvas.drawPath(right, Paint()..color = Colors.purple.withValues(alpha: 0.1));
    canvas.drawPath(left, frame);
    canvas.drawPath(right, frame);
    canvas.drawLine(const Offset(26, 26), const Offset(20, 28), Paint()..color = black..strokeWidth = 2);
    canvas.drawLine(const Offset(74, 26), const Offset(80, 28), Paint()..color = black..strokeWidth = 2);
  }

  void _drawSkiGoggles(Canvas canvas, [Color? tint]) {
    final orange = tint ?? const Color(0xFFFF9800);
    final dark = const Color(0xFF424242);
    // Elastic strap
    canvas.drawLine(const Offset(18, 26), const Offset(82, 26), Paint()..color = dark..strokeWidth = 4);
    // Goggle body
    final goggles = RRect.fromRectAndRadius(const Rect.fromLTWH(24, 20, 52, 18), const Radius.circular(9));
    canvas.drawRRect(goggles, Paint()..color = dark);
    // Lens
    final lens = RRect.fromRectAndRadius(const Rect.fromLTWH(28, 23, 44, 12), const Radius.circular(6));
    canvas.drawRRect(lens, Paint()..color = orange.withValues(alpha: 0.7));
    canvas.drawLine(const Offset(34, 26), const Offset(40, 32), Paint()..color = Colors.white30..strokeWidth = 2..strokeCap = StrokeCap.round);
  }

  void _draw3DGlasses(Canvas canvas, [Color? tint]) {
    final frame = tint ?? const Color(0xFFEEEEEE);
    canvas.drawLine(const Offset(46, 28), const Offset(54, 28), Paint()..color = frame..strokeWidth = 2.5);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 22, 18, 14), const Radius.circular(3)), Paint()..color = const Color(0xFFE53935).withValues(alpha: 0.6));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(56, 22, 18, 14), const Radius.circular(3)), Paint()..color = const Color(0xFF2196F3).withValues(alpha: 0.6));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 22, 18, 14), const Radius.circular(3)), Paint()..color = frame..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(56, 22, 18, 14), const Radius.circular(3)), Paint()..color = frame..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawLine(const Offset(26, 28), const Offset(20, 30), Paint()..color = frame..strokeWidth = 2);
    canvas.drawLine(const Offset(74, 28), const Offset(80, 30), Paint()..color = frame..strokeWidth = 2);
  }

  void _drawSteampunkGoggles(Canvas canvas, [Color? tint]) {
    final brass = tint ?? const Color(0xFFD4A853);
    final dark = const Color(0xFF795548);
    // Leather strap
    canvas.drawLine(const Offset(18, 27), const Offset(82, 27), Paint()..color = dark..strokeWidth = 5);
    // Round goggle housings
    canvas.drawCircle(const Offset(36, 28), 12, Paint()..color = brass);
    canvas.drawCircle(const Offset(64, 28), 12, Paint()..color = brass);
    // Dark lenses
    canvas.drawCircle(const Offset(36, 28), 9, Paint()..color = const Color(0xFF37474F));
    canvas.drawCircle(const Offset(64, 28), 9, Paint()..color = const Color(0xFF37474F));
    // Gear details
    canvas.drawCircle(const Offset(36, 28), 12, Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(const Offset(64, 28), 12, Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 2);
    // Rivets
    for (final o in [const Offset(26, 22), const Offset(46, 22), const Offset(54, 22), const Offset(74, 22)]) {
      canvas.drawCircle(o, 2, Paint()..color = brass);
    }
  }

  void _drawSwimGoggles(Canvas canvas, [Color? tint]) {
    final blue = tint ?? const Color(0xFF42A5F5);
    canvas.drawLine(const Offset(18, 28), const Offset(82, 28), Paint()..color = blue..strokeWidth = 3);
    canvas.drawOval(const Rect.fromLTWH(28, 22, 16, 14), Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.25));
    canvas.drawOval(const Rect.fromLTWH(56, 22, 16, 14), Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.25));
    canvas.drawOval(const Rect.fromLTWH(28, 22, 16, 14), Paint()..color = blue..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawOval(const Rect.fromLTWH(56, 22, 16, 14), Paint()..color = blue..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawLine(const Offset(44, 28), const Offset(56, 28), Paint()..color = blue..strokeWidth = 3);
  }

  void _drawNeonGlasses(Canvas canvas, [Color? tint]) {
    final neon = tint ?? const Color(0xFF76FF03);
    final glow = Paint()..color = neon.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 22, 18, 14), const Radius.circular(4)), glow);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(56, 22, 18, 14), const Radius.circular(4)), glow);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 22, 18, 14), const Radius.circular(4)), Paint()..color = neon..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(56, 22, 18, 14), const Radius.circular(4)), Paint()..color = neon..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawLine(const Offset(44, 28), const Offset(56, 28), Paint()..color = neon..strokeWidth = 2.5);
    canvas.drawLine(const Offset(26, 28), const Offset(20, 30), Paint()..color = neon..strokeWidth = 2);
    canvas.drawLine(const Offset(74, 28), const Offset(80, 30), Paint()..color = neon..strokeWidth = 2);
  }

  void _drawPixelGlasses(Canvas canvas, [Color? tint]) {
    final black = tint ?? const Color(0xFF212121);
    // 8-bit pixel shades — blocky rectangles
    for (double x = 26; x <= 42; x += 4) { canvas.drawRect(Rect.fromLTWH(x, 24, 4, 4), Paint()..color = black); }
    for (double x = 26; x <= 42; x += 4) { canvas.drawRect(Rect.fromLTWH(x, 28, 4, 4), Paint()..color = black); }
    for (double x = 56; x <= 72; x += 4) { canvas.drawRect(Rect.fromLTWH(x, 24, 4, 4), Paint()..color = black); }
    for (double x = 56; x <= 72; x += 4) { canvas.drawRect(Rect.fromLTWH(x, 28, 4, 4), Paint()..color = black); }
    canvas.drawRect(const Rect.fromLTWH(44, 26, 12, 4), Paint()..color = black);
    canvas.drawRect(const Rect.fromLTWH(18, 26, 8, 4), Paint()..color = black);
    canvas.drawRect(const Rect.fromLTWH(74, 26, 8, 4), Paint()..color = black);
  }

  void _drawRoseGlasses(Canvas canvas, [Color? tint]) {
    final pink = tint ?? const Color(0xFFF48FB1);
    final gold = const Color(0xFFD4A853);
    final frame = Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawLine(const Offset(46, 28), const Offset(54, 28), Paint()..color = gold..strokeWidth = 2);
    canvas.drawCircle(const Offset(36, 29), 10, Paint()..color = pink.withValues(alpha: 0.35));
    canvas.drawCircle(const Offset(64, 29), 10, Paint()..color = pink.withValues(alpha: 0.35));
    canvas.drawCircle(const Offset(36, 29), 10, frame);
    canvas.drawCircle(const Offset(64, 29), 10, frame);
    canvas.drawLine(const Offset(26, 28), const Offset(20, 30), Paint()..color = gold..strokeWidth = 2);
    canvas.drawLine(const Offset(74, 28), const Offset(80, 30), Paint()..color = gold..strokeWidth = 2);
  }

  void _drawAviatorGlasses(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFD4A853);
    final frame = Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawLine(const Offset(46, 26), const Offset(54, 26), Paint()..color = gold..strokeWidth = 2);
    // Teardrop shape
    final left = Path()..moveTo(26, 26)..quadraticBezierTo(26, 20, 36, 20)..quadraticBezierTo(46, 20, 46, 26)..quadraticBezierTo(46, 38, 36, 38)..quadraticBezierTo(26, 38, 26, 26)..close();
    final right = Path()..moveTo(54, 26)..quadraticBezierTo(54, 20, 64, 20)..quadraticBezierTo(74, 20, 74, 26)..quadraticBezierTo(74, 38, 64, 38)..quadraticBezierTo(54, 38, 54, 26)..close();
    canvas.drawPath(left, Paint()..color = const Color(0xFF37474F).withValues(alpha: 0.5));
    canvas.drawPath(right, Paint()..color = const Color(0xFF37474F).withValues(alpha: 0.5));
    canvas.drawPath(left, frame);
    canvas.drawPath(right, frame);
    canvas.drawLine(const Offset(26, 26), const Offset(20, 28), Paint()..color = gold..strokeWidth = 2);
    canvas.drawLine(const Offset(74, 26), const Offset(80, 28), Paint()..color = gold..strokeWidth = 2);
  }

  void _drawShieldVisor(Canvas canvas, [Color? tint]) {
    final mirror = tint ?? const Color(0xFF42A5F5);
    final visor = Path()..moveTo(20, 28)..quadraticBezierTo(50, 18, 80, 28)..quadraticBezierTo(80, 38, 50, 40)..quadraticBezierTo(20, 38, 20, 28)..close();
    canvas.drawPath(visor, Paint()..color = mirror.withValues(alpha: 0.5));
    canvas.drawPath(visor, Paint()..color = mirror..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawLine(const Offset(30, 24), const Offset(44, 32), Paint()..color = Colors.white30..strokeWidth = 2..strokeCap = StrokeCap.round);
  }

  void _drawOperaMask(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFFFD700);
    final dark = const Color(0xFF795548);
    // Venetian mask shape
    final mask = Path()..moveTo(20, 30)..quadraticBezierTo(20, 16, 50, 14)..quadraticBezierTo(80, 16, 80, 30)..quadraticBezierTo(80, 38, 50, 40)..quadraticBezierTo(20, 38, 20, 30)..close();
    canvas.drawPath(mask, Paint()..color = gold);
    // Eye holes
    canvas.drawOval(const Rect.fromLTWH(28, 24, 16, 10), Paint()..color = dark);
    canvas.drawOval(const Rect.fromLTWH(56, 24, 16, 10), Paint()..color = dark);
    // Ornamental details
    canvas.drawCircle(const Offset(50, 18), 3, Paint()..color = const Color(0xFFE53935));
    // Feather on right side
    final feather = Path()..moveTo(78, 22)..quadraticBezierTo(88, 10, 92, -2)..quadraticBezierTo(86, 8, 80, 16);
    canvas.drawPath(feather, Paint()..color = const Color(0xFF7B1FA2)..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  void _drawNerdGlasses(Canvas canvas, [Color? tint]) {
    final black = tint ?? const Color(0xFF212121);
    final frame = Paint()..color = black..style = PaintingStyle.stroke..strokeWidth = 3.5;
    canvas.drawLine(const Offset(46, 28), const Offset(54, 28), Paint()..color = black..strokeWidth = 3);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 22, 18, 14), const Radius.circular(3)), Paint()..color = Colors.white.withValues(alpha: 0.15));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(56, 22, 18, 14), const Radius.circular(3)), Paint()..color = Colors.white.withValues(alpha: 0.15));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(26, 22, 18, 14), const Radius.circular(3)), frame);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(56, 22, 18, 14), const Radius.circular(3)), frame);
    // Tape on bridge
    canvas.drawRect(const Rect.fromLTWH(48, 26, 4, 5), Paint()..color = const Color(0xFFEEEEEE));
    canvas.drawLine(const Offset(26, 28), const Offset(20, 30), Paint()..color = black..strokeWidth = 2.5);
    canvas.drawLine(const Offset(74, 28), const Offset(80, 30), Paint()..color = black..strokeWidth = 2.5);
  }

  void _drawHalfMoonGlasses(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFD4A853);
    final frame = Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawLine(const Offset(46, 32), const Offset(54, 32), Paint()..color = gold..strokeWidth = 2);
    // Half-circle lenses — positioned lower on face
    canvas.drawArc(const Rect.fromLTWH(26, 26, 18, 18), 0, 3.14159, false, Paint()..color = Colors.amber.withValues(alpha: 0.12));
    canvas.drawArc(const Rect.fromLTWH(26, 26, 18, 18), 0, 3.14159, false, frame);
    canvas.drawArc(const Rect.fromLTWH(56, 26, 18, 18), 0, 3.14159, false, Paint()..color = Colors.amber.withValues(alpha: 0.12));
    canvas.drawArc(const Rect.fromLTWH(56, 26, 18, 18), 0, 3.14159, false, frame);
    canvas.drawLine(const Offset(26, 32), const Offset(20, 34), Paint()..color = gold..strokeWidth = 2);
    canvas.drawLine(const Offset(74, 32), const Offset(80, 34), Paint()..color = gold..strokeWidth = 2);
  }

  void _drawButterflyGlasses(Canvas canvas, [Color? tint]) {
    final purple = tint ?? const Color(0xFF7E57C2);
    final frame = Paint()..color = purple..style = PaintingStyle.stroke..strokeWidth = 2.5;
    canvas.drawLine(const Offset(46, 26), const Offset(54, 26), Paint()..color = purple..strokeWidth = 2);
    // Oversized butterfly shape
    final left = Path()..moveTo(24, 26)..quadraticBezierTo(22, 18, 36, 16)..quadraticBezierTo(48, 18, 46, 26)..quadraticBezierTo(46, 38, 36, 40)..quadraticBezierTo(22, 38, 24, 26)..close();
    final right = Path()..moveTo(54, 26)..quadraticBezierTo(52, 18, 64, 16)..quadraticBezierTo(78, 18, 76, 26)..quadraticBezierTo(78, 38, 64, 40)..quadraticBezierTo(54, 38, 54, 26)..close();
    canvas.drawPath(left, Paint()..color = purple.withValues(alpha: 0.25));
    canvas.drawPath(right, Paint()..color = purple.withValues(alpha: 0.25));
    canvas.drawPath(left, frame);
    canvas.drawPath(right, frame);
    canvas.drawLine(const Offset(24, 26), const Offset(18, 28), Paint()..color = purple..strokeWidth = 2);
    canvas.drawLine(const Offset(76, 26), const Offset(82, 28), Paint()..color = purple..strokeWidth = 2);
  }

  void _drawEyePatch(Canvas canvas, [Color? tint]) {
    final black = tint ?? const Color(0xFF212121);
    // Strap across head
    canvas.drawLine(const Offset(20, 28), const Offset(80, 28), Paint()..color = black..strokeWidth = 2.5);
    // Patch over right eye
    final patch = Path()..moveTo(56, 20)..quadraticBezierTo(56, 16, 64, 16)..quadraticBezierTo(74, 16, 74, 28)..quadraticBezierTo(74, 40, 64, 40)..quadraticBezierTo(56, 40, 56, 28)..close();
    canvas.drawPath(patch, Paint()..color = black);
    // Skull detail
    canvas.drawCircle(const Offset(65, 27), 3, Paint()..color = Colors.white54);
  }

  void _drawCyberpunkVisor(Canvas canvas, [Color? tint]) {
    final cyan = tint ?? const Color(0xFF00BCD4);
    final dark = const Color(0xFF263238);
    // Wide visor
    final visor = RRect.fromRectAndRadius(const Rect.fromLTWH(18, 20, 64, 16), const Radius.circular(5));
    canvas.drawRRect(visor, Paint()..color = dark);
    // LED strip
    final led = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 24, 56, 8), const Radius.circular(4));
    canvas.drawRRect(led, Paint()..color = cyan.withValues(alpha: 0.6));
    canvas.drawRRect(led, Paint()..color = cyan..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Glow
    canvas.drawRRect(led, Paint()..color = cyan.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }

  void _drawDiscoGlasses(Canvas canvas, [Color? tint]) {
    final mirror = tint ?? const Color(0xFFE0E0E0);
    canvas.drawLine(const Offset(46, 28), const Offset(54, 28), Paint()..color = mirror..strokeWidth = 2.5);
    // Mirrored disco ball spheres
    canvas.drawCircle(const Offset(36, 28), 11, Paint()..color = mirror);
    canvas.drawCircle(const Offset(64, 28), 11, Paint()..color = mirror);
    // Grid lines for disco effect
    final grid = Paint()..color = Colors.grey..strokeWidth = 0.8;
    for (double dy = -8; dy <= 8; dy += 4) { canvas.drawLine(Offset(26, 28 + dy), Offset(46, 28 + dy), grid); canvas.drawLine(Offset(54, 28 + dy), Offset(74, 28 + dy), grid); }
    for (double dx = -8; dx <= 8; dx += 4) { canvas.drawLine(Offset(36 + dx, 18), Offset(36 + dx, 38), grid); canvas.drawLine(Offset(64 + dx, 18), Offset(64 + dx, 38), grid); }
    canvas.drawLine(const Offset(26, 28), const Offset(20, 30), Paint()..color = mirror..strokeWidth = 2);
    canvas.drawLine(const Offset(74, 28), const Offset(80, 30), Paint()..color = mirror..strokeWidth = 2);
  }

  void _drawLoupe(Canvas canvas, [Color? tint]) {
    final brass = tint ?? const Color(0xFFD4A853);
    // Loupe clips onto right side
    canvas.drawCircle(const Offset(68, 26), 12, Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.2));
    canvas.drawCircle(const Offset(68, 26), 12, Paint()..color = brass..style = PaintingStyle.stroke..strokeWidth = 3);
    // Handle
    canvas.drawLine(const Offset(68, 38), const Offset(62, 50), Paint()..color = brass..strokeWidth = 3..strokeCap = StrokeCap.round);
    // Glint
    canvas.drawLine(const Offset(62, 20), const Offset(65, 24), Paint()..color = Colors.white54..strokeWidth = 2..strokeCap = StrokeCap.round);
  }

  // ─────────────────── SCARF/NECKWEAR DRAWING ───────────────────

  void _drawScarfItem(Canvas canvas, String id) {
    final tint = outfitColors[id] != null ? Color(outfitColors[id]!) : null;
    switch (id) {
      case 'scarf_classic': _drawScarfWrap(canvas, tint ?? const Color(0xFFE53935)); break;
      case 'scarf_silk': _drawScarfWrap(canvas, tint ?? const Color(0xFFF48FB1)); break;
      case 'scarf_plaid': _drawScarfWrap(canvas, tint ?? const Color(0xFFE53935), plaid: true); break;
      case 'scarf_infinity': _drawSnood(canvas, tint); break;
      case 'scarf_bandana': _drawBandana(canvas, tint); break;
      case 'scarf_bow': _drawBowAscot(canvas, tint); break;
      case 'scarf_fur': _drawFurCollar(canvas, tint); break;
      case 'scarf_knit': _drawScarfWrap(canvas, tint ?? const Color(0xFFFFA000), knit: true); break;
      case 'scarf_chain': _drawChainNecklace(canvas, tint); break;
      case 'scarf_lei': _drawLei(canvas, tint); break;
      case 'scarf_medal': _drawMedal(canvas, tint); break;
      case 'scarf_pearls': _drawPearls(canvas, tint); break;
      case 'scarf_tie': _drawNecktie(canvas, tint); break;
      case 'scarf_garland': _drawGarland(canvas, tint); break;
      case 'scarf_pendant': _drawPendant(canvas, tint); break;
      case 'scarf_headphones': _drawHeadphones(canvas, tint); break;
      case 'scarf_whistle': _drawWhistle(canvas, tint); break;
      case 'scarf_stethoscope': _drawStethoscope(canvas, tint); break;
      case 'scarf_camera': _drawCameraNeck(canvas, tint); break;
      case 'scarf_feather_boa': _drawFeatherBoa(canvas, tint); break;
      case 'scarf_necklace_star': _drawStarPendant(canvas, tint); break;
      case 'scarf_lanyard': _drawLanyard(canvas, tint); break;
      case 'scarf_cape_mini': _drawMiniCape(canvas, tint); break;
      case 'scarf_rainbow': _drawScarfWrap(canvas, tint ?? const Color(0xFFE91E63), rainbow: true); break;
      case 'scarf_dog_tag': _drawDogTags(canvas, tint); break;
    }
  }

  /// Reusable wrapped scarf around neck with optional patterns
  void _drawScarfWrap(Canvas canvas, Color base, {bool plaid = false, bool knit = false, bool rainbow = false}) {
    final hsl = HSLColor.fromColor(base);
    final dark = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
    final highlight = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    final wrap = Path()..moveTo(18, 50)..quadraticBezierTo(50, 66, 82, 50)..lineTo(80, 62)..quadraticBezierTo(50, 78, 20, 62)..close();
    canvas.drawPath(wrap.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(wrap, Paint()..shader = _getCachedShader('scarf_item_${base.toARGB32()}', wrap.getBounds(), LinearGradient(colors: [highlight, base, dark])));
    // Dangling tail
    final tail = Path()..moveTo(24, 60)..lineTo(38, 66)..lineTo(33, 96)..lineTo(21, 93)..close();
    canvas.drawPath(tail, Paint()..color = base);
    canvas.drawPath(tail, Paint()..color = dark.withValues(alpha: 0.3));
    if (plaid) {
      canvas.save(); canvas.clipPath(wrap);
      for (double x = 22; x <= 78; x += 8) canvas.drawLine(Offset(x, 48), Offset(x, 66), Paint()..color = dark.withValues(alpha: 0.3)..strokeWidth = 1.5);
      for (double x = 22; x <= 78; x += 8) canvas.drawLine(Offset(x + 4, 48), Offset(x + 4, 66), Paint()..color = Colors.green.withValues(alpha: 0.3)..strokeWidth = 1);
      canvas.restore();
    }
    if (knit) {
      for (double x = 25; x <= 75; x += 6) {
        final t = (x - 18) / 64;
        final y = 50 + 16 * 2 * t * (1 - t) + 1;
        canvas.drawLine(Offset(x, y), Offset(x, y + 8), Paint()..color = dark.withValues(alpha: 0.4)..strokeWidth = 1.5);
      }
    }
    if (rainbow) {
      canvas.save(); canvas.clipPath(wrap);
      final colors = [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple];
      for (int i = 0; i < colors.length; i++) canvas.drawLine(Offset(18, 52 + i * 2.0), Offset(82, 52 + i * 2.0), Paint()..color = colors[i]..strokeWidth = 2);
      canvas.restore();
    }
  }

  void _drawSnood(Canvas canvas, [Color? tint]) {
    final grey = tint ?? const Color(0xFF9E9E9E);
    final dark = HSLColor.fromColor(grey).withLightness((HSLColor.fromColor(grey).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Infinity loop around neck — thicker, no tail
    final wrap = Path()..moveTo(16, 48)..quadraticBezierTo(50, 68, 84, 48)..lineTo(82, 66)..quadraticBezierTo(50, 84, 18, 66)..close();
    canvas.drawPath(wrap, Paint()..color = grey);
    for (double x = 22; x <= 78; x += 6) {
      final t = (x - 16) / 68;
      final y = 48 + 20 * 2 * t * (1 - t);
      canvas.drawLine(Offset(x, y), Offset(x, y + 14), Paint()..color = dark.withValues(alpha: 0.3)..strokeWidth = 1.5);
    }
  }

  void _drawBandana(Canvas canvas, [Color? tint]) {
    final red = tint ?? const Color(0xFFE53935);
    final dark = HSLColor.fromColor(red).withLightness((HSLColor.fromColor(red).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Triangular bandana around neck
    final tri = Path()..moveTo(22, 50)..quadraticBezierTo(50, 58, 78, 50)..lineTo(50, 80)..close();
    canvas.drawPath(tri, Paint()..color = red);
    // Paisley dots
    for (final c in [const Offset(40, 62), const Offset(50, 68), const Offset(60, 62)]) {
      canvas.drawCircle(c, 2, Paint()..color = dark.withValues(alpha: 0.4));
    }
  }

  void _drawBowAscot(Canvas canvas, [Color? tint]) {
    final purple = tint ?? const Color(0xFF7B1FA2);
    final dark = HSLColor.fromColor(purple).withLightness((HSLColor.fromColor(purple).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Satin bow at neck
    canvas.drawPath(Path()..moveTo(50, 52)..lineTo(34, 46)..lineTo(34, 58)..close(), Paint()..color = purple);
    canvas.drawPath(Path()..moveTo(50, 52)..lineTo(66, 46)..lineTo(66, 58)..close(), Paint()..color = purple);
    canvas.drawCircle(const Offset(50, 52), 4, Paint()..color = dark);
    // Tails
    canvas.drawLine(const Offset(50, 56), const Offset(46, 72), Paint()..color = purple..strokeWidth = 3..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(50, 56), const Offset(54, 72), Paint()..color = purple..strokeWidth = 3..strokeCap = StrokeCap.round);
  }

  void _drawFurCollar(Canvas canvas, [Color? tint]) {
    final white = tint ?? const Color(0xFFF5F5F5);
    // Fluffy collar — many small circles
    for (double a = 0; a < 3.14; a += 0.25) {
      final x = 50 + 34 * math.cos(a + 3.14);
      final y = 54 + 10 * math.sin(a + 3.14);
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = white);
    }
    // Shadow underneath
    for (double a = 0; a < 3.14; a += 0.3) {
      final x = 50 + 32 * math.cos(a + 3.14);
      final y = 56 + 10 * math.sin(a + 3.14);
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.grey.withValues(alpha: 0.15));
    }
  }

  void _drawChainNecklace(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFFFD700);
    // Chain links around neck
    for (double a = 0.3; a < 2.85; a += 0.25) {
      final x = 50 + 30 * math.cos(a + 3.14);
      final y = 56 + 12 * math.sin(a + 3.14);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 6, height: 4), Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 2.5);
    }
  }

  void _drawLei(Canvas canvas, [Color? tint]) {
    final pink = tint ?? const Color(0xFFE91E63);
    // Flower garland around neck
    for (double a = 0.2; a < 2.9; a += 0.3) {
      final x = 50 + 32 * math.cos(a + 3.14);
      final y = 56 + 12 * math.sin(a + 3.14);
      final color = a.toInt() % 2 == 0 ? pink : Colors.white;
      canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = Colors.amber);
    }
  }

  void _drawMedal(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFFFD700);
    // Ribbon
    canvas.drawLine(const Offset(44, 48), const Offset(50, 76), Paint()..color = const Color(0xFFE53935)..strokeWidth = 5);
    canvas.drawLine(const Offset(56, 48), const Offset(50, 76), Paint()..color = const Color(0xFF1565C0)..strokeWidth = 5);
    // Medal disc
    canvas.drawCircle(const Offset(50, 80), 8, Paint()..color = gold);
    canvas.drawCircle(const Offset(50, 80), 6, Paint()..color = HSLColor.fromColor(gold).withLightness(0.45).toColor());
    _drawStarShape(canvas, const Offset(50, 80), 5, Paint()..color = gold);
  }

  void _drawPearls(Canvas canvas, [Color? tint]) {
    final white = tint ?? const Color(0xFFF5F5F5);
    for (double a = 0.2; a < 2.9; a += 0.22) {
      final x = 50 + 30 * math.cos(a + 3.14);
      final y = 56 + 12 * math.sin(a + 3.14);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = white);
      canvas.drawCircle(Offset(x - 1, y - 1), 1, Paint()..color = Colors.white);
    }
  }

  void _drawNecktie(Canvas canvas, [Color? tint]) {
    final navy = tint ?? const Color(0xFF1A237E);
    final dark = HSLColor.fromColor(navy).withLightness((HSLColor.fromColor(navy).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Knot at neck
    canvas.drawCircle(const Offset(50, 52), 4, Paint()..color = navy);
    // Tie body — long triangle down
    final tie = Path()..moveTo(46, 54)..lineTo(50, 100)..lineTo(54, 54)..close();
    canvas.drawPath(tie, Paint()..color = navy);
    // Diagonal stripes
    canvas.save(); canvas.clipPath(tie);
    for (double y = 58; y <= 96; y += 8) canvas.drawLine(Offset(44, y), Offset(56, y - 6), Paint()..color = dark.withValues(alpha: 0.3)..strokeWidth = 2);
    canvas.restore();
  }

  void _drawGarland(Canvas canvas, [Color? tint]) {
    // String lights around neck
    final wire = Paint()..color = const Color(0xFF4CAF50)..strokeWidth = 2..style = PaintingStyle.stroke;
    final garland = Path()..moveTo(20, 52)..quadraticBezierTo(50, 66, 80, 52);
    canvas.drawPath(garland, wire);
    // Bulbs
    final colors = [Colors.red, Colors.yellow, Colors.blue, Colors.green, Colors.orange, Colors.purple];
    for (int i = 0; i < 6; i++) {
      final t = (i + 0.5) / 6;
      final x = 20 + 60 * t;
      final y = 52 + 14 * 4 * t * (1 - t);
      canvas.drawCircle(Offset(x, y + 2), 3, Paint()..color = colors[i]);
      canvas.drawCircle(Offset(x - 0.5, y + 0.5), 1.2, Paint()..color = Colors.white54);
    }
  }

  void _drawPendant(Canvas canvas, [Color? tint]) {
    final silver = tint ?? const Color(0xFFB0BEC5);
    // Thin chain
    for (double a = 0.4; a < 2.7; a += 0.15) {
      final x = 50 + 26 * math.cos(a + 3.14);
      final y = 54 + 10 * math.sin(a + 3.14);
      canvas.drawCircle(Offset(x, y), 1, Paint()..color = silver);
    }
    // Crystal pendant
    final crystal = Path()..moveTo(50, 66)..lineTo(56, 76)..lineTo(50, 86)..lineTo(44, 76)..close();
    canvas.drawPath(crystal, Paint()..color = const Color(0xFF7E57C2));
    canvas.drawPath(crystal, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 0.8);
    canvas.drawLine(const Offset(48, 72), const Offset(50, 78), Paint()..color = Colors.white30..strokeWidth = 2);
  }

  void _drawHeadphones(Canvas canvas, [Color? tint]) {
    final black = tint ?? const Color(0xFF212121);
    final dark = const Color(0xFF111111);
    // Headband over head
    final band = Path()..moveTo(18, 28)..quadraticBezierTo(50, -4, 82, 28);
    canvas.drawPath(band, Paint()..color = black..style = PaintingStyle.stroke..strokeWidth = 4);
    // Ear cups
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(12, 22, 12, 16), const Radius.circular(4)), Paint()..color = black);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(76, 22, 12, 16), const Radius.circular(4)), Paint()..color = black);
    // Cushions
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(14, 24, 8, 12), const Radius.circular(3)), Paint()..color = dark);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(78, 24, 8, 12), const Radius.circular(3)), Paint()..color = dark);
  }

  void _drawWhistle(Canvas canvas, [Color? tint]) {
    final silver = tint ?? const Color(0xFFB0BEC5);
    // Cord around neck
    canvas.drawLine(const Offset(40, 48), const Offset(50, 72), Paint()..color = const Color(0xFFE53935)..strokeWidth = 2);
    canvas.drawLine(const Offset(60, 48), const Offset(50, 72), Paint()..color = const Color(0xFFE53935)..strokeWidth = 2);
    // Whistle body
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(44, 72, 16, 8), const Radius.circular(3)), Paint()..color = silver);
    canvas.drawCircle(const Offset(60, 76), 4, Paint()..color = silver);
  }

  void _drawStethoscope(Canvas canvas, [Color? tint]) {
    final blue = tint ?? const Color(0xFF42A5F5);
    // Tubes around neck
    canvas.drawLine(const Offset(40, 48), const Offset(36, 70), Paint()..color = blue..strokeWidth = 3);
    canvas.drawLine(const Offset(60, 48), const Offset(64, 70), Paint()..color = blue..strokeWidth = 3);
    // Chest piece
    canvas.drawLine(const Offset(36, 70), const Offset(50, 90), Paint()..color = blue..strokeWidth = 3);
    canvas.drawLine(const Offset(64, 70), const Offset(50, 90), Paint()..color = blue..strokeWidth = 3);
    canvas.drawCircle(const Offset(50, 94), 6, Paint()..color = const Color(0xFFB0BEC5));
    canvas.drawCircle(const Offset(50, 94), 4, Paint()..color = const Color(0xFF78909C));
  }

  void _drawCameraNeck(Canvas canvas, [Color? tint]) {
    final brown = tint ?? const Color(0xFF795548);
    // Strap around neck
    canvas.drawLine(const Offset(35, 48), const Offset(58, 82), Paint()..color = brown..strokeWidth = 3);
    canvas.drawLine(const Offset(65, 48), const Offset(62, 82), Paint()..color = brown..strokeWidth = 3);
    // Camera body
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(50, 80, 20, 14), const Radius.circular(3)), Paint()..color = const Color(0xFF424242));
    // Lens
    canvas.drawCircle(const Offset(60, 87), 5, Paint()..color = const Color(0xFF212121));
    canvas.drawCircle(const Offset(60, 87), 3, Paint()..color = const Color(0xFF37474F));
    canvas.drawCircle(const Offset(59, 85), 1.5, Paint()..color = Colors.white30);
  }

  void _drawFeatherBoa(Canvas canvas, [Color? tint]) {
    final magenta = tint ?? const Color(0xFFE91E63);
    // Fluffy feathers around neck
    for (double a = 0; a < 3.14; a += 0.18) {
      final x = 50 + 36 * math.cos(a + 3.14);
      final y = 54 + 12 * math.sin(a + 3.14);
      canvas.drawCircle(Offset(x, y), 5 + math.sin(a * 3) * 2, Paint()..color = magenta.withValues(alpha: 0.7));
    }
    // Draping tail
    for (double dy = 0; dy < 30; dy += 4) {
      canvas.drawCircle(Offset(24 - dy * 0.1, 58 + dy), 4 + math.sin(dy) * 1.5, Paint()..color = magenta.withValues(alpha: 0.6));
    }
  }

  void _drawStarPendant(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFFFD700);
    // Delicate chain
    for (double a = 0.4; a < 2.7; a += 0.15) {
      final x = 50 + 26 * math.cos(a + 3.14);
      final y = 54 + 10 * math.sin(a + 3.14);
      canvas.drawCircle(Offset(x, y), 1, Paint()..color = gold);
    }
    // Star
    _drawStarShape(canvas, const Offset(50, 76), 8, Paint()..color = gold);
    canvas.drawCircle(const Offset(49, 74), 1.5, Paint()..color = Colors.white54);
  }

  void _drawLanyard(Canvas canvas, [Color? tint]) {
    final blue = tint ?? const Color(0xFF42A5F5);
    // Lanyard cord
    canvas.drawLine(const Offset(42, 48), const Offset(46, 86), Paint()..color = blue..strokeWidth = 3);
    canvas.drawLine(const Offset(58, 48), const Offset(54, 86), Paint()..color = blue..strokeWidth = 3);
    // Badge
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(42, 86, 16, 20), const Radius.circular(3)), Paint()..color = Colors.white);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(42, 86, 16, 20), const Radius.circular(3)), Paint()..color = blue..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // VIP text
    final tp = TextPainter(text: const TextSpan(text: 'VIP', style: TextStyle(color: Color(0xFFE53935), fontSize: 7, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(50 - tp.width / 2, 92));
  }

  void _drawMiniCape(Canvas canvas, [Color? tint]) {
    final red = tint ?? const Color(0xFFE53935);
    final dark = HSLColor.fromColor(red).withLightness((HSLColor.fromColor(red).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Small cape — shorter than full cape, flutters
    final cape = Path()..moveTo(32, 50)..quadraticBezierTo(28, 74, 26, 96)..lineTo(74, 96)..quadraticBezierTo(72, 74, 68, 50)..close();
    canvas.drawPath(cape, Paint()..color = red);
    canvas.drawPath(Path()..moveTo(36, 54)..quadraticBezierTo(34, 72, 30, 92)..lineTo(70, 92)..quadraticBezierTo(66, 72, 64, 54)..close(), Paint()..color = dark);
    // Clasp at neck
    canvas.drawCircle(const Offset(50, 50), 3, Paint()..color = const Color(0xFFFFD700));
  }

  void _drawDogTags(Canvas canvas, [Color? tint]) {
    final silver = tint ?? const Color(0xFFB0BEC5);
    // Chain
    for (double a = 0.3; a < 2.8; a += 0.18) {
      final x = 50 + 24 * math.cos(a + 3.14);
      final y = 54 + 10 * math.sin(a + 3.14);
      canvas.drawCircle(Offset(x, y), 1.2, Paint()..color = silver);
    }
    // Two dog tags
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(44, 72, 10, 16), const Radius.circular(3)), Paint()..color = silver);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(48, 76, 10, 16), const Radius.circular(3)), Paint()..color = silver);
    // Engraving lines
    canvas.drawLine(const Offset(46, 78), const Offset(52, 78), Paint()..color = Colors.grey..strokeWidth = 1);
    canvas.drawLine(const Offset(46, 81), const Offset(52, 81), Paint()..color = Colors.grey..strokeWidth = 1);
  }

  // ─────────────────── TOP DRAWING ───────────────────

  void _drawRaincoat(Canvas canvas, [Color? tint]) {
    final yellow = tint ?? const Color(0xFFFFEB3B);
    final hsl = HSLColor.fromColor(yellow);
    final darkYellow = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    final shadow = hsl.withLightness((hsl.lightness - 0.06).clamp(0.0, 1.0)).toColor();
    // Full waterproof coat — covers entire torso from neck to below knees
    final bodyPath = Path()
      ..moveTo(14, 52)
      ..quadraticBezierTo(14, 44, 50, 44)
      ..quadraticBezierTo(86, 44, 86, 52)
      ..lineTo(86, 105)
      ..quadraticBezierTo(86, 115, 50, 118)
      ..quadraticBezierTo(14, 115, 14, 105)
      ..close();
    // Shadow behind coat
    canvas.drawPath(bodyPath.shift(const Offset(0, 2)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawPath(bodyPath, Paint()..color = yellow);
    // High collar that wraps the neck
    final collarPath = Path()
      ..moveTo(30, 48)
      ..quadraticBezierTo(50, 55, 70, 48)
      ..lineTo(68, 44)
      ..quadraticBezierTo(50, 40, 32, 44)
      ..close();
    canvas.drawPath(collarPath, Paint()..color = darkYellow);
    // Center zipper/button line
    canvas.drawLine(const Offset(50, 52), const Offset(50, 114), Paint()..color = darkYellow..strokeWidth = 2);
    // Buttons
    for (double y = 60; y <= 108; y += 12) {
      canvas.drawCircle(Offset(50, y), 2.5, Paint()..color = darkYellow);
    }
    // Side pocket lines
    canvas.drawLine(const Offset(24, 82), const Offset(38, 82), Paint()..color = shadow..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(62, 82), const Offset(76, 82), Paint()..color = shadow..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    // Bottom edge seam
    canvas.save();
    canvas.clipPath(bodyPath);
    canvas.drawPath(
      Path()..moveTo(14, 112)..quadraticBezierTo(50, 120, 86, 112),
      Paint()..color = darkYellow..style = PaintingStyle.stroke..strokeWidth = 2,
    );
    canvas.restore();
  }

  void _drawThickScarf(Canvas canvas, [Color? tint]) {
    // A cozy thick wrap scarf — replaces the default scarf
    final scarfColor = tint ?? const Color(0xFFEF5350);
    final hsl = HSLColor.fromColor(scarfColor);
    final darkScarf = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
    // Main wrap that hugs the neck-body junction
    final wrapPath = Path()
      ..moveTo(19, 49)
      ..quadraticBezierTo(50, 66, 81, 49)
      ..lineTo(81, 65)
      ..quadraticBezierTo(50, 82, 19, 65)
      ..close();
    // Shadow
    canvas.drawPath(wrapPath.shift(const Offset(0, 2)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(wrapPath, Paint()..color = scarfColor);
    // Cable knit lines
    final linePaint = Paint()..color = darkScarf..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    for (double x = 25; x <= 75; x += 7) {
      double t = (x - 19) / 62;
      double yTop = 49 + (66 - 49) * 2 * t * (1 - t) + 1;
      canvas.drawLine(Offset(x, yTop), Offset(x, yTop + 12), linePaint);
    }
    // Dangling tail portion
    canvas.drawPath(
      Path()..moveTo(23, 58)..lineTo(36, 64)..lineTo(31, 92)..lineTo(19, 88)..close(),
      Paint()..color = scarfColor,
    );
    // Tail shadow
    canvas.drawPath(
      Path()..moveTo(23, 60)..lineTo(36, 66)..lineTo(31, 94)..lineTo(19, 90)..close(),
      Paint()..color = darkScarf.withValues(alpha: 0.3),
    );
  }

  void _drawHawaiianShirt(Canvas canvas, [Color? tint]) {
    final teal = tint ?? const Color(0xFF26C6DA);
    final hsl = HSLColor.fromColor(teal);
    final darkTeal = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    // Short-sleeve shirt — slightly wider than body to show it's a garment
    final bodyPath = Path()
      ..moveTo(16, 54)
      ..quadraticBezierTo(16, 46, 50, 46)
      ..quadraticBezierTo(84, 46, 84, 54)
      ..lineTo(84, 100)
      ..quadraticBezierTo(84, 110, 50, 113)
      ..quadraticBezierTo(16, 110, 16, 100)
      ..close();
    // Shadow
    canvas.drawPath(bodyPath.shift(const Offset(0, 2)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(bodyPath, Paint()..color = teal);
    // Open V-collar showing chest
    canvas.drawPath(Path()..moveTo(42, 46)..lineTo(50, 60)..lineTo(58, 46)..close(), Paint()..color = darkTeal);
    // Flower pattern — clipped to shirt
    canvas.save();
    canvas.clipPath(bodyPath);
    final fp = Paint()..color = Colors.orangeAccent.withValues(alpha: 0.85);
    for (final c in [const Offset(30, 68), const Offset(68, 66), const Offset(35, 92), const Offset(65, 94), const Offset(50, 80)]) {
      canvas.drawCircle(c, 4.5, fp);
      canvas.drawCircle(Offset(c.dx - 5, c.dy), 3, fp);
      canvas.drawCircle(Offset(c.dx + 5, c.dy), 3, fp);
      canvas.drawCircle(Offset(c.dx, c.dy - 5), 3, fp);
      canvas.drawCircle(Offset(c.dx, c.dy + 5), 3, fp);
      canvas.drawCircle(c, 2.5, Paint()..color = Colors.amber);
    }
    canvas.restore();
  }

  void _drawLinenShirt(Canvas canvas, [Color? tint]) {
    final beige = tint ?? const Color(0xFFF3E5C8);
    final hsl = HSLColor.fromColor(beige);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    final bodyPath = Path()
      ..moveTo(18, 54)
      ..quadraticBezierTo(18, 46, 50, 46)
      ..quadraticBezierTo(82, 46, 82, 54)
      ..lineTo(82, 100)
      ..quadraticBezierTo(82, 109, 50, 112)
      ..quadraticBezierTo(18, 109, 18, 100)
      ..close();
    canvas.drawPath(bodyPath.shift(const Offset(0, 2)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(bodyPath, Paint()..color = beige);
    canvas.drawPath(Path()..moveTo(40, 46)..lineTo(50, 60)..lineTo(60, 46)..close(), Paint()..color = dark.withValues(alpha: 0.9));
    canvas.drawLine(const Offset(50, 58), const Offset(50, 108), Paint()..color = dark.withValues(alpha: 0.7)..strokeWidth = 1.6);
    for (double y = 66; y <= 98; y += 12) {
      canvas.drawCircle(Offset(50, y), 2.2, Paint()..color = dark);
    }
    final weavePaint = Paint()..color = Colors.white.withValues(alpha: 0.18)..strokeWidth = 1;
    for (double x = 24; x <= 76; x += 8) {
      canvas.drawLine(Offset(x, 58), Offset(x - 4, 106), weavePaint);
    }
  }

  void _drawWindbreaker(Canvas canvas, [Color? tint]) {
    final mint = tint ?? const Color(0xFF80CBC4);
    final hsl = HSLColor.fromColor(mint);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final bodyPath = Path()
      ..moveTo(16, 52)
      ..quadraticBezierTo(16, 42, 50, 42)
      ..quadraticBezierTo(84, 42, 84, 52)
      ..lineTo(84, 102)
      ..quadraticBezierTo(84, 112, 50, 114)
      ..quadraticBezierTo(16, 112, 16, 102)
      ..close();
    canvas.drawPath(bodyPath.shift(const Offset(0, 2)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(bodyPath, Paint()..color = mint);
    canvas.drawLine(const Offset(50, 42), const Offset(50, 110), Paint()..color = dark..strokeWidth = 2.2);
    canvas.drawPath(Path()..moveTo(32, 46)..lineTo(50, 68)..lineTo(68, 46)..close(), Paint()..color = dark.withValues(alpha: 0.85));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(24, 70, 16, 14), const Radius.circular(4)), Paint()..color = dark.withValues(alpha: 0.18));
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(60, 70, 16, 14), const Radius.circular(4)), Paint()..color = dark.withValues(alpha: 0.18));
    canvas.drawLine(const Offset(24, 92), const Offset(76, 92), Paint()..color = dark.withValues(alpha: 0.3)..strokeWidth = 2);
  }

  void _drawPyjama(Canvas canvas, [Color? tint]) {
    final blue = tint ?? const Color(0xFF5C6BC0);
    final hsl = HSLColor.fromColor(blue);
    final stripe = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    final darkBlue = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Full-length pyjama — wider than body
    final bodyPath = Path()
      ..moveTo(14, 54)
      ..quadraticBezierTo(14, 44, 50, 44)
      ..quadraticBezierTo(86, 44, 86, 54)
      ..lineTo(86, 105)
      ..quadraticBezierTo(86, 115, 50, 118)
      ..quadraticBezierTo(14, 115, 14, 105)
      ..close();
    // Shadow
    canvas.drawPath(bodyPath.shift(const Offset(0, 2)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(bodyPath, Paint()..color = blue);
    // Stripes — clip to body shape
    canvas.save();
    canvas.clipPath(bodyPath);
    final stripePaint = Paint()..color = stripe..strokeWidth = 4;
    for (double y = 50; y <= 116; y += 10) {
      canvas.drawLine(Offset(14, y), Offset(86, y), stripePaint);
    }
    canvas.restore();
    // Button placket
    canvas.save();
    canvas.clipPath(bodyPath);
    canvas.drawLine(const Offset(50, 44), const Offset(50, 116), Paint()..color = darkBlue..strokeWidth = 2);
    for (double y = 56; y <= 108; y += 14) {
      canvas.drawCircle(Offset(50, y), 2.5, Paint()..color = darkBlue);
    }
    canvas.restore();
    // Small collar
    final collarPath = Path()
      ..moveTo(34, 48)
      ..quadraticBezierTo(50, 53, 66, 48)
      ..lineTo(64, 44)
      ..quadraticBezierTo(50, 40, 36, 44)
      ..close();
    canvas.drawPath(collarPath, Paint()..color = darkBlue);
  }

  /// Generic top body path — reusable for many garment types.
  Path _topBodyPath() => Path()
    ..moveTo(16, 52)..quadraticBezierTo(16, 44, 50, 44)..quadraticBezierTo(84, 44, 84, 52)
    ..lineTo(84, 104)..quadraticBezierTo(84, 114, 50, 116)..quadraticBezierTo(16, 114, 16, 104)..close();

  void _drawGenericTop(Canvas canvas, Color base, {bool vNeck = false, bool collar = false, bool buttons = false, bool knit = false}) {
    final hsl = HSLColor.fromColor(base);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    final body = _topBodyPath();
    drawDropShadow(canvas, body, blur: 3, offset: const Offset(1, 2));
    // Clay gradient fill instead of flat color
    const topBounds = Rect.fromLTWH(16, 44, 68, 72);
    canvas.drawPath(body, clayFill('genTop_${base.toARGB32()}', topBounds, base));
    // Rim light
    canvas.drawPath(body, Paint()..color = Colors.white.withValues(alpha: 0.06)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    if (vNeck) canvas.drawPath(Path()..moveTo(42, 46)..lineTo(50, 60)..lineTo(58, 46)..close(), Paint()..color = dark);
    if (collar) {
      final c = Path()..moveTo(30, 48)..quadraticBezierTo(50, 55, 70, 48)..lineTo(68, 44)..quadraticBezierTo(50, 40, 32, 44)..close();
      canvas.drawPath(c, Paint()..color = dark);
    }
    if (buttons) {
      canvas.drawLine(const Offset(50, 52), const Offset(50, 112), Paint()..color = dark..strokeWidth = 1.5);
      for (double y = 60; y <= 104; y += 12) canvas.drawCircle(Offset(50, y), 2, Paint()..color = dark);
    }
    if (knit) {
      canvas.save(); canvas.clipPath(body);
      final kp = Paint()..color = dark.withValues(alpha: 0.15)..strokeWidth = 1;
      for (double y = 52; y <= 114; y += 6) canvas.drawLine(Offset(16, y), Offset(84, y), kp);
      canvas.restore();
    }
  }

  void _drawTuxedo(Canvas canvas, [Color? tint]) {
    final black = tint ?? const Color(0xFF212121);
    final hsl = HSLColor.fromColor(black);
    final dark = hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0)).toColor();
    final body = _topBodyPath();
    canvas.drawPath(body.shift(const Offset(0, 2)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(body, Paint()..color = black);
    // White shirt front
    canvas.drawPath(Path()..moveTo(40, 46)..lineTo(50, 110)..lineTo(60, 46)..close(), Paint()..color = Colors.white);
    // Lapels
    canvas.drawPath(Path()..moveTo(40, 46)..lineTo(34, 70)..lineTo(44, 70)..lineTo(48, 46)..close(), Paint()..color = dark);
    canvas.drawPath(Path()..moveTo(60, 46)..lineTo(66, 70)..lineTo(56, 70)..lineTo(52, 46)..close(), Paint()..color = dark);
    // Bow tie
    canvas.drawPath(Path()..moveTo(50, 52)..lineTo(43, 48)..lineTo(43, 56)..close(), Paint()..color = const Color(0xFFE53935));
    canvas.drawPath(Path()..moveTo(50, 52)..lineTo(57, 48)..lineTo(57, 56)..close(), Paint()..color = const Color(0xFFE53935));
    canvas.drawCircle(const Offset(50, 52), 2.5, Paint()..color = const Color(0xFFC62828));
  }

  void _drawHoodie(Canvas canvas, [Color? tint]) {
    final grey = tint ?? const Color(0xFF78909C);
    final hsl = HSLColor.fromColor(grey);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final body = _topBodyPath();
    canvas.drawPath(body.shift(const Offset(0, 2)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(body, Paint()..color = grey);
    // Hood behind head
    final hood = Path()..moveTo(28, 20)..quadraticBezierTo(28, 10, 50, 8)..quadraticBezierTo(72, 10, 72, 20)..lineTo(72, 46)..lineTo(28, 46)..close();
    canvas.drawPath(hood, Paint()..color = dark);
    // Kangaroo pocket
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 80, 40, 18), const Radius.circular(8)), Paint()..color = dark.withValues(alpha: 0.25));
    // Drawstrings
    canvas.drawLine(const Offset(44, 46), const Offset(42, 62), Paint()..color = dark..strokeWidth = 1.5);
    canvas.drawLine(const Offset(56, 46), const Offset(58, 62), Paint()..color = dark..strokeWidth = 1.5);
  }

  void _drawVest(Canvas canvas, [Color? tint]) {
    final olive = tint ?? const Color(0xFF689F38);
    final hsl = HSLColor.fromColor(olive);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    // Vest — shorter, no sleeves, wider armholes
    final body = Path()..moveTo(22, 50)..quadraticBezierTo(22, 44, 50, 44)..quadraticBezierTo(78, 44, 78, 50)..lineTo(78, 100)..quadraticBezierTo(78, 108, 50, 110)..quadraticBezierTo(22, 108, 22, 100)..close();
    canvas.drawPath(body, Paint()..color = olive);
    canvas.drawLine(const Offset(50, 44), const Offset(50, 108), Paint()..color = dark..strokeWidth = 2);
    // Quilted pattern
    canvas.save(); canvas.clipPath(body);
    final qp = Paint()..color = dark.withValues(alpha: 0.15)..strokeWidth = 1;
    for (double y = 52; y <= 106; y += 8) canvas.drawLine(Offset(22, y), Offset(78, y), qp);
    canvas.restore();
  }

  void _drawTank(Canvas canvas, [Color? tint]) {
    final white = tint ?? const Color(0xFFF5F5F5);
    final dark = HSLColor.fromColor(white).withLightness((HSLColor.fromColor(white).lightness - 0.12).clamp(0.0, 1.0)).toColor();
    // Sleeveless tank — narrow shoulders
    final body = Path()..moveTo(28, 50)..quadraticBezierTo(28, 44, 50, 44)..quadraticBezierTo(72, 44, 72, 50)..lineTo(72, 104)..quadraticBezierTo(72, 112, 50, 114)..quadraticBezierTo(28, 112, 28, 104)..close();
    canvas.drawPath(body, Paint()..color = white);
    // Scoop neck
    canvas.drawPath(Path()..moveTo(36, 46)..quadraticBezierTo(50, 56, 64, 46), Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawOveralls(Canvas canvas, [Color? tint]) {
    final blue = tint ?? const Color(0xFF5C6BC0);
    final dark = HSLColor.fromColor(blue).withLightness((HSLColor.fromColor(blue).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Bib + straps over body
    final bib = Path()..moveTo(32, 50)..lineTo(32, 110)..quadraticBezierTo(50, 116, 68, 110)..lineTo(68, 50)..close();
    canvas.drawPath(bib, Paint()..color = blue);
    // Bib top
    canvas.drawRect(const Rect.fromLTWH(36, 50, 28, 20), Paint()..color = blue);
    // Straps
    canvas.drawLine(const Offset(38, 50), const Offset(34, 38), Paint()..color = blue..strokeWidth = 5..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(62, 50), const Offset(66, 38), Paint()..color = blue..strokeWidth = 5..strokeCap = StrokeCap.round);
    // Buckles
    canvas.drawRect(const Rect.fromLTWH(33, 48, 6, 5), Paint()..color = dark);
    canvas.drawRect(const Rect.fromLTWH(61, 48, 6, 5), Paint()..color = dark);
    // Pocket on bib
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(42, 60, 16, 12), const Radius.circular(3)), Paint()..color = dark.withValues(alpha: 0.2));
  }

  void _drawPoncho(Canvas canvas, [Color? tint]) {
    final multi = tint ?? const Color(0xFFE57373);
    final hsl = HSLColor.fromColor(multi);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Wide draped shape
    final body = Path()..moveTo(6, 55)..quadraticBezierTo(6, 44, 50, 42)..quadraticBezierTo(94, 44, 94, 55)..lineTo(88, 105)..quadraticBezierTo(50, 115, 12, 105)..close();
    canvas.drawPath(body, Paint()..color = multi);
    // Stripe pattern
    canvas.save(); canvas.clipPath(body);
    final colors = [const Color(0xFFFFEB3B), const Color(0xFF4CAF50), const Color(0xFF2196F3)];
    for (int i = 0; i < 3; i++) canvas.drawLine(Offset(6, 65 + i * 14.0), Offset(94, 65 + i * 14.0), Paint()..color = colors[i]..strokeWidth = 4);
    canvas.restore();
    // Fringe at bottom
    for (double x = 16; x <= 84; x += 4) canvas.drawLine(Offset(x, 105), Offset(x, 112), Paint()..color = dark..strokeWidth = 1.5);
    // Neck hole
    canvas.drawOval(const Rect.fromLTWH(40, 42, 20, 12), Paint()..color = dark);
  }

  void _drawKimono(Canvas canvas, [Color? tint]) {
    final red = tint ?? const Color(0xFFE53935);
    final hsl = HSLColor.fromColor(red);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final gold = const Color(0xFFFFD700);
    // Wide flowing robe
    final body = Path()..moveTo(10, 52)..quadraticBezierTo(10, 42, 50, 42)..quadraticBezierTo(90, 42, 90, 52)..lineTo(90, 112)..quadraticBezierTo(50, 120, 10, 112)..close();
    canvas.drawPath(body, Paint()..color = red);
    // Cross-over lapels
    canvas.drawPath(Path()..moveTo(34, 42)..lineTo(50, 70)..lineTo(66, 42)..close(), Paint()..color = dark);
    // Obi belt
    canvas.drawRect(const Rect.fromLTWH(20, 72, 60, 12), Paint()..color = gold);
    canvas.drawRect(const Rect.fromLTWH(44, 72, 12, 12), Paint()..color = dark);
    // Floral pattern
    canvas.save(); canvas.clipPath(body);
    for (final c in [const Offset(24, 58), const Offset(76, 56), const Offset(30, 98), const Offset(70, 100)]) {
      canvas.drawCircle(c, 4, Paint()..color = Colors.pinkAccent.withValues(alpha: 0.5));
      canvas.drawCircle(c, 2, Paint()..color = Colors.white54);
    }
    canvas.restore();
  }

  void _drawApron(Canvas canvas, [Color? tint]) {
    final pink = tint ?? const Color(0xFFF48FB1);
    final dark = HSLColor.fromColor(pink).withLightness((HSLColor.fromColor(pink).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Apron front panel — over body, not covering back
    final apron = Path()..moveTo(32, 50)..lineTo(68, 50)..lineTo(72, 112)..quadraticBezierTo(50, 118, 28, 112)..close();
    canvas.drawPath(apron, Paint()..color = pink);
    // Bib
    canvas.drawRect(const Rect.fromLTWH(36, 46, 28, 16), Paint()..color = pink);
    // Neck strap
    canvas.drawLine(const Offset(40, 46), const Offset(40, 38), Paint()..color = dark..strokeWidth = 3);
    canvas.drawLine(const Offset(60, 46), const Offset(60, 38), Paint()..color = dark..strokeWidth = 3);
    // Pocket
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(40, 80, 20, 14), const Radius.circular(4)), Paint()..color = dark.withValues(alpha: 0.2));
    // Waist ties
    canvas.drawLine(const Offset(32, 72), const Offset(18, 80), Paint()..color = dark..strokeWidth = 2..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(68, 72), const Offset(82, 80), Paint()..color = dark..strokeWidth = 2..strokeCap = StrokeCap.round);
  }

  void _drawSailor(Canvas canvas, [Color? tint]) {
    final navy = tint ?? const Color(0xFF1A237E);
    final body = _topBodyPath();
    canvas.drawPath(body.shift(const Offset(0, 2)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(body, Paint()..color = Colors.white);
    // Navy stripes
    canvas.save(); canvas.clipPath(body);
    for (double y = 52; y <= 114; y += 6) canvas.drawLine(Offset(16, y), Offset(84, y), Paint()..color = navy..strokeWidth = 2);
    canvas.restore();
  }

  void _drawVarsity(Canvas canvas, [Color? tint]) {
    final red = tint ?? const Color(0xFFE53935);
    final hsl = HSLColor.fromColor(red);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    final body = _topBodyPath();
    canvas.drawPath(body, Paint()..color = red);
    // White sleeves (will show on arms)
    canvas.drawLine(const Offset(50, 44), const Offset(50, 112), Paint()..color = dark..strokeWidth = 2);
    // Buttons
    for (double y = 56; y <= 104; y += 12) canvas.drawCircle(Offset(50, y), 2.2, Paint()..color = dark);
    // Letter patch
    canvas.drawCircle(const Offset(50, 76), 10, Paint()..color = Colors.white);
    final tp = TextPainter(text: const TextSpan(text: 'P', style: TextStyle(color: Color(0xFFE53935), fontSize: 13, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(50 - tp.width / 2, 76 - tp.height / 2));
  }

  void _drawJersey(Canvas canvas, [Color? tint]) {
    final green = tint ?? const Color(0xFF4CAF50);
    final dark = HSLColor.fromColor(green).withLightness((HSLColor.fromColor(green).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final body = _topBodyPath();
    canvas.drawPath(body, Paint()..color = green);
    // V-neck with collar
    canvas.drawPath(Path()..moveTo(40, 44)..lineTo(50, 56)..lineTo(60, 44)..close(), Paint()..color = dark);
    // Number 10
    final tp = TextPainter(text: const TextSpan(text: '10', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(50 - tp.width / 2, 72));
  }

  /// Draws arms/wings with fabric-colored sleeves for the equipped top.
  /// Handles all arm positions: resting, raised, waving, thumbsUp, thinking, etc.
  void _drawArmsWithSleeves(Canvas canvas, String topId, PigMood mood, bool holdingUmbrella, {PigPose pose = PigPose.normal}) {
    // Get the top's colors
    final (Color primary, Color secondary) = _topColors(topId);
    final bool isRaised = mood == PigMood.excited || mood == PigMood.celebrating;
    final bool isWaving = mood == PigMood.waving;
    final bool isShortSleeve = topId == 'top_hawaiian' || topId == 'top_linen' || topId == 'top_tank' || topId == 'top_vest' || topId == 'top_apron' || topId == 'top_overalls';

    if (holdingUmbrella) {
      if (isShortSleeve) {
        _drawShortSleeveRestWing(canvas, primary, secondary, true);
      } else {
        _drawSleevedRestWing(canvas, primary, secondary, true);
      }
      _drawUmbrellaHoldingWing(canvas, primary: primary, secondary: secondary, shortSleeve: isShortSleeve);
      return;
    }

    if (pose == PigPose.coldTucked) {
      if (isShortSleeve) {
        _drawShortSleeveTuckedWing(canvas, primary, secondary, true);
        _drawShortSleeveTuckedWing(canvas, primary, secondary, false);
      } else {
        _drawSleevedTuckedWing(canvas, primary, secondary, true);
        _drawSleevedTuckedWing(canvas, primary, secondary, false);
      }
      return;
    }

    if (pose == PigPose.sunRelaxed && mood == PigMood.normal) {
      if (isShortSleeve) {
        _drawShortSleeveRelaxedWing(canvas, primary, secondary, true);
        _drawShortSleeveRelaxedWing(canvas, primary, secondary, false);
      } else {
        _drawSleevedRelaxedWing(canvas, primary, secondary, true);
        _drawSleevedRelaxedWing(canvas, primary, secondary, false);
      }
      return;
    }

    if (mood == PigMood.normal || mood == PigMood.sad || mood == PigMood.love || mood == PigMood.sleeping) {
      if (isShortSleeve) {
        _drawShortSleeveRestWing(canvas, primary, secondary, true);
        _drawShortSleeveRestWing(canvas, primary, secondary, false);
      } else {
        _drawSleevedRestWing(canvas, primary, secondary, true);
        _drawSleevedRestWing(canvas, primary, secondary, false);
      }
    } else if (isRaised) {
      if (isShortSleeve) {
        _drawShortSleeveRaisedWing(canvas, primary, secondary, true);
        _drawShortSleeveRaisedWing(canvas, primary, secondary, false);
      } else {
        _drawSleevedRaisedWing(canvas, primary, secondary, true);
        _drawSleevedRaisedWing(canvas, primary, secondary, false);
      }
    } else if (isWaving) {
      if (isShortSleeve) {
        _drawShortSleeveRestWing(canvas, primary, secondary, true);
        _drawShortSleeveWavingWing(canvas, primary, secondary, false);
      } else {
        _drawSleevedRestWing(canvas, primary, secondary, true);
        _drawSleevedWavingWing(canvas, primary, secondary, false);
      }
    } else if (mood == PigMood.thumbsUp) {
      if (isShortSleeve) {
        _drawShortSleeveRestWing(canvas, primary, secondary, true);
      } else {
        _drawSleevedRestWing(canvas, primary, secondary, true);
      }
      _drawThumbsUpArm(canvas);
    } else if (mood == PigMood.thinking) {
      if (isShortSleeve) {
        _drawShortSleeveRestWing(canvas, primary, secondary, true);
      } else {
        _drawSleevedRestWing(canvas, primary, secondary, true);
      }
      _drawThinkingArm(canvas);
    } else if (mood == PigMood.embarrassed) {
      if (isShortSleeve) {
        _drawShortSleeveRestWing(canvas, primary, secondary, false);
      } else {
        _drawSleevedRestWing(canvas, primary, secondary, false);
      }
      _drawFacepalmArm(canvas);
    } else if (mood == PigMood.searching) {
      if (isShortSleeve) {
        _drawShortSleeveRestWing(canvas, primary, secondary, true);
      } else {
        _drawSleevedRestWing(canvas, primary, secondary, true);
      }
      _drawSearchingArm(canvas);
    }
  }

  /// Returns (primary, secondary) colors for a given top ID, honoring user tints.
  (Color, Color) _topColors(String topId) {
    final userArgb = outfitColors[topId];
    if (userArgb != null) {
      final c = Color(userArgb);
      final hsl = HSLColor.fromColor(c);
      return (c, hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor());
    }
    switch (topId) {
      case 'top_raincoat':
        return (const Color(0xFFFFEB3B), const Color(0xFFF9A825));
      case 'top_windbreaker':
        return (const Color(0xFF80CBC4), const Color(0xFF26A69A));
      case 'top_pyjama':
        return (const Color(0xFF5C6BC0), const Color(0xFF7986CB));
      case 'top_hawaiian':
        return (const Color(0xFF26C6DA), const Color(0xFF00ACC1));
      case 'top_linen':
        return (const Color(0xFFF3E5C8), const Color(0xFFD7C4A3));
      case 'top_scarf_thick':
        return (const Color(0xFFEF5350), const Color(0xFFC62828));
      case 'top_golden':
        return (const Color(0xFFFFD700), const Color(0xFFF9A825));
      case 'top_tuxedo':
        return (const Color(0xFF212121), const Color(0xFF111111));
      case 'top_hoodie':
        return (const Color(0xFF78909C), const Color(0xFF546E7A));
      case 'top_vest':
        return (const Color(0xFF689F38), const Color(0xFF558B2F));
      case 'top_turtleneck':
        return (const Color(0xFF212121), const Color(0xFF111111));
      case 'top_tank':
        return (const Color(0xFFF5F5F5), const Color(0xFFE0E0E0));
      case 'top_blazer':
        return (const Color(0xFF1565C0), const Color(0xFF0D47A1));
      case 'top_overalls':
        return (const Color(0xFF5C6BC0), const Color(0xFF3949AB));
      case 'top_sweater':
        return (const Color(0xFFF5F5DC), const Color(0xFFD7C4A3));
      case 'top_poncho':
        return (const Color(0xFFE57373), const Color(0xFFC62828));
      case 'top_kimono':
        return (const Color(0xFFE53935), const Color(0xFFC62828));
      case 'top_lab_coat':
        return (const Color(0xFFF5F5F5), const Color(0xFFE0E0E0));
      case 'top_apron':
        return (const Color(0xFFF48FB1), const Color(0xFFE91E63));
      case 'top_sailor':
        return (const Color(0xFFFFFFFF), const Color(0xFF1A237E));
      case 'top_varsity':
        return (const Color(0xFFE53935), const Color(0xFFC62828));
      case 'top_denim':
        return (const Color(0xFF5C6BC0), const Color(0xFF3949AB));
      case 'top_leather':
        return (const Color(0xFF3E2723), const Color(0xFF1B0000));
      case 'top_cardigan':
        return (const Color(0xFFBCAAA4), const Color(0xFF8D6E63));
      case 'top_jersey':
        return (const Color(0xFF4CAF50), const Color(0xFF2E7D32));
      default:
        return (const Color(0xFF78909C), const Color(0xFF546E7A));
    }
  }

  /// Draws a resting arm/wing filled with the top's color.
  void _drawSleevedRestWing(Canvas canvas, Color primary, Color secondary, bool isLeft) {
    // Same shape as _drawRestWing but filled with clothing color
    Path path;
    if (isLeft) {
      path = Path()
        ..moveTo(24, 62)
        ..quadraticBezierTo(6, 74, 10, 100)
        ..quadraticBezierTo(16, 106, 24, 92)
        ..quadraticBezierTo(24, 80, 28, 70)
        ..close();
    } else {
      path = Path()
        ..moveTo(76, 62)
        ..quadraticBezierTo(94, 74, 90, 100)
        ..quadraticBezierTo(84, 106, 76, 92)
        ..quadraticBezierTo(76, 80, 72, 70)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = primary);
    canvas.drawPath(path, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  /// Draws a raised arm/wing filled with the top's color.
  void _drawSleevedRaisedWing(Canvas canvas, Color primary, Color secondary, bool isLeft) {
    // Same shape as _drawRaisedWing but filled with clothing color
    Path path;
    if (isLeft) {
      path = Path()
        ..moveTo(30, 60)
        ..quadraticBezierTo(10, 45, 8, 20)
        ..quadraticBezierTo(18, 15, 22, 28)
        ..quadraticBezierTo(28, 20, 32, 35)
        ..quadraticBezierTo(38, 45, 40, 60)
        ..close();
    } else {
      path = Path()
        ..moveTo(70, 60)
        ..quadraticBezierTo(90, 45, 92, 20)
        ..quadraticBezierTo(82, 15, 78, 28)
        ..quadraticBezierTo(72, 20, 68, 35)
        ..quadraticBezierTo(62, 45, 60, 60)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = primary);
    canvas.drawPath(path, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  void _drawShortSleeveRestWing(Canvas canvas, Color primary, Color secondary, bool isLeft) {
    _drawRestWing(canvas, isLeft);
    final sleeve = Path()
      ..moveTo(isLeft ? 24 : 76, 62)
      ..quadraticBezierTo(isLeft ? 11 : 89, 72, isLeft ? 17 : 83, 83)
      ..quadraticBezierTo(isLeft ? 24 : 76, 86, isLeft ? 28 : 72, 73)
      ..close();
    canvas.drawPath(sleeve, Paint()..color = primary);
    canvas.drawPath(sleeve, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.1);
  }

  void _drawShortSleeveRaisedWing(Canvas canvas, Color primary, Color secondary, bool isLeft) {
    _drawRaisedWing(canvas, isLeft);
    final sleeve = Path()
      ..moveTo(isLeft ? 31 : 69, 59)
      ..quadraticBezierTo(isLeft ? 18 : 82, 52, isLeft ? 20 : 80, 39)
      ..quadraticBezierTo(isLeft ? 29 : 71, 34, isLeft ? 34 : 66, 46)
      ..close();
    canvas.drawPath(sleeve, Paint()..color = primary);
    canvas.drawPath(sleeve, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.1);
  }

  void _drawSleevedWavingWing(Canvas canvas, Color primary, Color secondary, bool isLeft) {
    final path = Path()
      ..moveTo(isLeft ? 29 : 71, 62)
      ..quadraticBezierTo(isLeft ? 10 : 90, 52, isLeft ? 14 : 86, 26)
      ..quadraticBezierTo(isLeft ? 18 : 82, 10, isLeft ? 29 : 71, 22)
      ..quadraticBezierTo(isLeft ? 37 : 63, 31, isLeft ? 38 : 62, 48)
      ..quadraticBezierTo(isLeft ? 39 : 61, 60, isLeft ? 29 : 71, 62)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(path, Paint()..color = primary);
    canvas.drawPath(path, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  void _drawShortSleeveWavingWing(Canvas canvas, Color primary, Color secondary, bool isLeft) {
    _drawWavingWing(canvas, isLeft);
    final sleeve = Path()
      ..moveTo(isLeft ? 31 : 69, 61)
      ..quadraticBezierTo(isLeft ? 18 : 82, 55, isLeft ? 21 : 79, 43)
      ..quadraticBezierTo(isLeft ? 29 : 71, 37, isLeft ? 35 : 65, 45)
      ..quadraticBezierTo(isLeft ? 36 : 64, 56, isLeft ? 31 : 69, 61)
      ..close();
    canvas.drawPath(sleeve, Paint()..color = primary);
    canvas.drawPath(sleeve, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.1);
  }

  void _drawUmbrellaHoldingWing(Canvas canvas, {Color? primary, Color? secondary, bool shortSleeve = false}) {
    final holdingPath = Path()
      ..moveTo(73, 63)
      ..quadraticBezierTo(85, 69, 83, 82)
      ..quadraticBezierTo(81, 88, 78, 91)
      ..quadraticBezierTo(72, 88, 69, 79)
      ..quadraticBezierTo(68, 70, 73, 63)
      ..close();

    if (primary == null || secondary == null) {
      canvas.drawPath(holdingPath.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawPath(holdingPath, _wingPaint(holdingPath.getBounds(), isFront: true));
      return;
    }

    if (shortSleeve) {
      final exposedWing = Path()
        ..moveTo(74, 68)
        ..quadraticBezierTo(86, 74, 84, 85)
        ..quadraticBezierTo(81, 90, 78, 91)
        ..quadraticBezierTo(73, 88, 70, 81)
        ..quadraticBezierTo(69, 75, 74, 68)
        ..close();
      canvas.drawPath(exposedWing.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawPath(exposedWing, _wingPaint(exposedWing.getBounds(), isFront: true));
      final sleeve = Path()
        ..moveTo(72, 62)
        ..quadraticBezierTo(82, 66, 81, 74)
        ..quadraticBezierTo(76, 77, 70, 72)
        ..quadraticBezierTo(69, 66, 72, 62)
        ..close();
      canvas.drawPath(sleeve, Paint()..color = primary);
      canvas.drawPath(sleeve, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.1);
      return;
    }

    canvas.drawPath(holdingPath.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(holdingPath, Paint()..color = primary);
    canvas.drawPath(holdingPath, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  void _drawTuckedWing(Canvas canvas, bool isLeft) {
    final path = Path()
      ..moveTo(isLeft ? 28 : 72, 70)
      ..quadraticBezierTo(isLeft ? 20 : 80, 82, isLeft ? 28 : 72, 98)
      ..quadraticBezierTo(isLeft ? 36 : 64, 96, isLeft ? 34 : 66, 80)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(path, _wingPaint(path.getBounds(), isFront: true));
  }

  void _drawRelaxedWing(Canvas canvas, bool isLeft) {
    final path = Path()
      ..moveTo(isLeft ? 23 : 77, 68)
      ..quadraticBezierTo(isLeft ? 12 : 88, 84, isLeft ? 16 : 84, 98)
      ..quadraticBezierTo(isLeft ? 28 : 72, 103, isLeft ? 31 : 69, 86)
      ..quadraticBezierTo(isLeft ? 29 : 71, 74, isLeft ? 23 : 77, 68)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(path, _wingPaint(path.getBounds(), isFront: true));
  }

  void _drawSleevedTuckedWing(Canvas canvas, Color primary, Color secondary, bool isLeft) {
    final path = Path()
      ..moveTo(isLeft ? 29 : 71, 70)
      ..quadraticBezierTo(isLeft ? 21 : 79, 82, isLeft ? 28 : 72, 98)
      ..quadraticBezierTo(isLeft ? 36 : 64, 96, isLeft ? 35 : 65, 80)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(path, Paint()..color = primary);
    canvas.drawPath(path, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  void _drawSleevedRelaxedWing(Canvas canvas, Color primary, Color secondary, bool isLeft) {
    final path = Path()
      ..moveTo(isLeft ? 24 : 76, 68)
      ..quadraticBezierTo(isLeft ? 12 : 88, 83, isLeft ? 18 : 82, 98)
      ..quadraticBezierTo(isLeft ? 30 : 70, 103, isLeft ? 32 : 68, 87)
      ..quadraticBezierTo(isLeft ? 30 : 70, 74, isLeft ? 24 : 76, 68)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(path, Paint()..color = primary);
    canvas.drawPath(path, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  void _drawShortSleeveTuckedWing(Canvas canvas, Color primary, Color secondary, bool isLeft) {
    _drawTuckedWing(canvas, isLeft);
    final sleeve = Path()
      ..moveTo(isLeft ? 31 : 69, 69)
      ..quadraticBezierTo(isLeft ? 23 : 77, 75, isLeft ? 26 : 74, 83)
      ..quadraticBezierTo(isLeft ? 32 : 68, 84, isLeft ? 35 : 65, 78)
      ..close();
    canvas.drawPath(sleeve, Paint()..color = primary);
    canvas.drawPath(sleeve, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.1);
  }

  void _drawShortSleeveRelaxedWing(Canvas canvas, Color primary, Color secondary, bool isLeft) {
    _drawRelaxedWing(canvas, isLeft);
    final sleeve = Path()
      ..moveTo(isLeft ? 25 : 75, 67)
      ..quadraticBezierTo(isLeft ? 16 : 84, 73, isLeft ? 18 : 82, 80)
      ..quadraticBezierTo(isLeft ? 24 : 76, 83, isLeft ? 30 : 70, 77)
      ..close();
    canvas.drawPath(sleeve, Paint()..color = primary);
    canvas.drawPath(sleeve, Paint()..color = secondary..style = PaintingStyle.stroke..strokeWidth = 1.1);
  }

  // ─────────────────── SHOES DRAWING ───────────────────

  void _drawRainBoots(Canvas canvas, [Color? tint]) {
    final bootColor = tint ?? const Color(0xFFEF5350);
    final hsl = HSLColor.fromColor(bootColor);
    final bootDark = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
    final bootLight = hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor();
    const soleColor = Color(0xFF4E342E);
    const soleDark = Color(0xFF3E2723);

    void drawBoot(double cx) {
      final x = cx - 12; // left edge from center
      // Drop shadow
      canvas.drawOval(Rect.fromLTWH(x - 2, 118, 26, 7),
          Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      // Thick rubber sole with rounded front
      final solePath = Path()
        ..moveTo(x, 118)
        ..lineTo(x, 121)
        ..quadraticBezierTo(x + 2, 125, x + 11, 125)
        ..quadraticBezierTo(x + 22, 125, x + 23, 121)
        ..lineTo(x + 23, 118)
        ..close();
      canvas.drawPath(solePath, Paint()..color = soleColor);
      canvas.drawPath(solePath, Paint()..color = soleDark..style = PaintingStyle.stroke..strokeWidth = 0.8);
      // Tread marks on sole
      for (var i = 0; i < 3; i++) {
        final tx = x + 5 + i * 6.0;
        canvas.drawLine(Offset(tx, 122), Offset(tx, 124),
            Paint()..color = Colors.black26..strokeWidth = 1.5..strokeCap = StrokeCap.round);
      }
      // Main boot shaft — rounded rectangle with gradient
      final shaftRect = Rect.fromLTWH(x + 1, 97, 21, 22);
      final shaftRR = RRect.fromRectAndRadius(shaftRect, const Radius.circular(5));
      final shaftPaint = Paint()
        ..shader = _getCachedShader('boot_shaft_${bootColor.toARGB32()}_$cx', shaftRect,
            LinearGradient(
              colors: [bootLight, bootColor, bootDark],
              stops: const [0.0, 0.45, 1.0],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ));
      canvas.drawRRect(shaftRR, shaftPaint);
      // Boot toe cap — rounded front bulge
      final toePath = Path()
        ..moveTo(x + 1, 115)
        ..quadraticBezierTo(x + 1, 120, x + 11, 120)
        ..quadraticBezierTo(x + 23, 120, x + 22, 115)
        ..lineTo(x + 1, 115)
        ..close();
      canvas.drawPath(toePath, Paint()..color = bootColor);
      canvas.drawPath(toePath, Paint()..color = bootDark.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 0.8);
      // Elastic side panel
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + 3, 99, 4, 14), const Radius.circular(2)),
        Paint()..color = bootDark.withValues(alpha: 0.35),
      );
      // Pull tab at top
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + 8, 95, 7, 4), const Radius.circular(2)),
        Paint()..color = bootDark,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + 9.5, 96, 4, 2), const Radius.circular(1)),
        Paint()..color = bootLight.withValues(alpha: 0.6),
      );
      // Highlight shine on shaft
      canvas.drawLine(Offset(x + 6, 100), Offset(x + 6, 112),
          Paint()..color = Colors.white30..strokeWidth = 2..strokeCap = StrokeCap.round);
      // Outline
      canvas.drawRRect(shaftRR, Paint()..color = bootDark.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    }

    drawBoot(35); // Left boot (centered on left foot)
    drawBoot(65); // Right boot (centered on right foot)
  }

  void _drawFlipFlops(Canvas canvas, [Color? tint]) {
    final flip = tint ?? const Color(0xFF42A5F5);
    final hsl = HSLColor.fromColor(flip);
    final flipDark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final orangeFeet = Paint()..color = _ClayColors.orangeFeet;
    // Draw the feet first (since shoes replace feet, we re-draw them here)
    // Left foot
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 108, 12, 10), const Radius.circular(5)), orangeFeet);
    canvas.drawCircle(const Offset(31, 116), 4.5, orangeFeet);
    canvas.drawCircle(const Offset(36, 118), 4.5, orangeFeet);
    canvas.drawCircle(const Offset(41, 116), 4.5, orangeFeet);
    // Right foot
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(58, 108, 12, 10), const Radius.circular(5)), orangeFeet);
    canvas.drawCircle(const Offset(59, 116), 4.5, orangeFeet);
    canvas.drawCircle(const Offset(64, 118), 4.5, orangeFeet);
    canvas.drawCircle(const Offset(69, 116), 4.5, orangeFeet);
    // Left flip-flop sole under the foot
    canvas.drawOval(const Rect.fromLTWH(25, 116, 22, 8), Paint()..color = flip);
    canvas.drawOval(const Rect.fromLTWH(25, 119, 22, 5), Paint()..color = flipDark.withValues(alpha: 0.3));
    // Straps
    final strapPaint = Paint()..color = flipDark..strokeWidth = 3..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(36, 114), const Offset(29, 109), strapPaint);
    canvas.drawLine(const Offset(36, 114), const Offset(43, 109), strapPaint);
    // Right flip-flop
    canvas.drawOval(const Rect.fromLTWH(53, 116, 22, 8), Paint()..color = flip);
    canvas.drawOval(const Rect.fromLTWH(53, 119, 22, 5), Paint()..color = flipDark.withValues(alpha: 0.3));
    canvas.drawLine(const Offset(64, 114), const Offset(57, 109), strapPaint);
    canvas.drawLine(const Offset(64, 114), const Offset(71, 109), strapPaint);
  }

  void _drawSandals(Canvas canvas, [Color? tint]) {
    final leather = tint ?? const Color(0xFF8D6E63);
    final hsl = HSLColor.fromColor(leather);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final feetPaint = Paint()..color = _ClayColors.orangeFeet;

    void drawFoot(double left) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left + 4, 108, 12, 10), const Radius.circular(5)), feetPaint);
      canvas.drawCircle(Offset(left + 5, 116), 4.5, feetPaint);
      canvas.drawCircle(Offset(left + 10, 118), 4.5, feetPaint);
      canvas.drawCircle(Offset(left + 15, 116), 4.5, feetPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(left, 116, 22, 8), const Radius.circular(4)),
        Paint()..color = leather,
      );
      canvas.drawLine(Offset(left + 6, 111), Offset(left + 17, 111), Paint()..color = dark..strokeWidth = 3.2..strokeCap = StrokeCap.round);
      canvas.drawLine(Offset(left + 6, 114), Offset(left + 17, 114), Paint()..color = dark.withValues(alpha: 0.8)..strokeWidth = 2.8..strokeCap = StrokeCap.round);
    }

    drawFoot(25);
    drawFoot(53);
  }

  void _drawSlippers(Canvas canvas, [Color? tint]) {
    final pink = tint ?? const Color(0xFFF48FB1);
    final hsl = HSLColor.fromColor(pink);
    final darkPink = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
    // Left slipper — covers foot entirely
    canvas.drawOval(const Rect.fromLTWH(22, 106, 26, 16), Paint()..color = pink); // Main slipper body
    // Bunny ears on the slipper
    canvas.drawOval(const Rect.fromLTWH(27, 98, 6, 12), Paint()..color = pink);
    canvas.drawOval(const Rect.fromLTWH(35, 98, 6, 12), Paint()..color = pink);
    canvas.drawOval(const Rect.fromLTWH(28, 100, 4, 8), Paint()..color = darkPink);
    canvas.drawOval(const Rect.fromLTWH(36, 100, 4, 8), Paint()..color = darkPink);
    // Eyes on slipper
    canvas.drawCircle(const Offset(31, 113), 1.8, Paint()..color = Colors.black54);
    canvas.drawCircle(const Offset(37, 113), 1.8, Paint()..color = Colors.black54);
    // Nose
    canvas.drawCircle(const Offset(34, 115), 1.2, Paint()..color = darkPink);
    // Right slipper
    canvas.drawOval(const Rect.fromLTWH(52, 106, 26, 16), Paint()..color = pink);
    canvas.drawOval(const Rect.fromLTWH(57, 98, 6, 12), Paint()..color = pink);
    canvas.drawOval(const Rect.fromLTWH(65, 98, 6, 12), Paint()..color = pink);
    canvas.drawOval(const Rect.fromLTWH(58, 100, 4, 8), Paint()..color = darkPink);
    canvas.drawOval(const Rect.fromLTWH(66, 100, 4, 8), Paint()..color = darkPink);
    canvas.drawCircle(const Offset(61, 113), 1.8, Paint()..color = Colors.black54);
    canvas.drawCircle(const Offset(67, 113), 1.8, Paint()..color = Colors.black54);
    canvas.drawCircle(const Offset(64, 115), 1.2, Paint()..color = darkPink);
  }

  /// Generic shoe — simple sneaker/trainer shape, reusable with different colors
  void _drawGenericShoes(Canvas canvas, Color base, {bool crystal = false}) {
    final hsl = HSLColor.fromColor(base);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    void drawShoe(double cx) {
      final x = cx - 12;
      // Ground contact shadow
      canvas.drawOval(Rect.fromLTWH(x - 1, 118, 24, 6), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      // Sole
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 116, 24, 8), const Radius.circular(4)), Paint()..color = Colors.white);
      // Upper — clay gradient
      final upperRect = Rect.fromLTWH(x + 1, 106, 22, 12);
      final upperRR = RRect.fromRectAndRadius(upperRect, const Radius.circular(6));
      canvas.drawRRect(upperRR, clayFill('shoe_${base.toARGB32()}_$cx', upperRect, base));
      // Toe specular
      drawSpecular(canvas, Offset(x + 6, 109), 2.5);
      if (crystal) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, 106, 22, 12), const Radius.circular(6)), Paint()..color = Colors.white30);
        canvas.drawLine(Offset(x + 6, 108), Offset(x + 10, 114), Paint()..color = Colors.white54..strokeWidth = 2..strokeCap = StrokeCap.round);
      }
      // Accent stripe
      canvas.drawLine(Offset(x + 4, 112), Offset(x + 18, 112), Paint()..color = dark..strokeWidth = 2..strokeCap = StrokeCap.round);
    }
    drawShoe(35);
    drawShoe(65);
  }

  void _drawHeels(Canvas canvas, [Color? tint]) {
    final red = tint ?? const Color(0xFFE53935);
    final dark = HSLColor.fromColor(red).withLightness((HSLColor.fromColor(red).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    void drawHeel(double cx) {
      final x = cx - 10;
      // Shoe body — pointed toe
      final shoe = Path()..moveTo(x, 110)..quadraticBezierTo(x, 118, x + 8, 120)..lineTo(x + 22, 120)..lineTo(x + 22, 112)..quadraticBezierTo(x + 20, 106, x + 10, 106)..close();
      canvas.drawPath(shoe, Paint()..color = red);
      // Heel
      canvas.drawRect(Rect.fromLTWH(x + 18, 112, 4, 12), Paint()..color = dark);
      // Sole
      canvas.drawLine(Offset(x + 2, 120), Offset(x + 22, 120), Paint()..color = dark..strokeWidth = 2);
    }
    drawHeel(35);
    drawHeel(65);
  }

  void _drawCowboyBoots(Canvas canvas, [Color? tint]) {
    final brown = tint ?? const Color(0xFF795548);
    final dark = HSLColor.fromColor(brown).withLightness((HSLColor.fromColor(brown).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    void drawBoot(double cx) {
      final x = cx - 12;
      // Shaft
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, 94, 20, 24), const Radius.circular(4)), Paint()..color = brown);
      // Pointed toe
      final toe = Path()..moveTo(x, 118)..quadraticBezierTo(x + 4, 124, x + 12, 124)..quadraticBezierTo(x + 24, 124, x + 24, 118)..close();
      canvas.drawPath(toe, Paint()..color = dark);
      // Heel
      canvas.drawRect(Rect.fromLTWH(x + 16, 118, 6, 6), Paint()..color = dark);
      // Decorative stitching
      canvas.drawPath(Path()..moveTo(x + 6, 98)..quadraticBezierTo(x + 12, 104, x + 18, 98), Paint()..color = dark.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
    drawBoot(35);
    drawBoot(65);
  }

  void _drawBalletShoes(Canvas canvas, [Color? tint]) {
    final pink = tint ?? const Color(0xFFF48FB1);
    final feetPaint = Paint()..color = _ClayColors.orangeFeet;
    // Draw feet
    for (final cx in [35.0, 65.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 6, 108, 12, 10), const Radius.circular(5)), feetPaint);
    }
    // Ballet slippers
    for (final cx in [35.0, 65.0]) {
      canvas.drawOval(Rect.fromLTWH(cx - 10, 112, 20, 10), Paint()..color = pink);
      // Ribbons winding up
      canvas.drawLine(Offset(cx - 4, 112), Offset(cx - 8, 98), Paint()..color = pink..strokeWidth = 1.5..strokeCap = StrokeCap.round);
      canvas.drawLine(Offset(cx + 4, 112), Offset(cx + 8, 98), Paint()..color = pink..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    }
  }

  void _drawRollerSkates(Canvas canvas, [Color? tint]) {
    final white = tint ?? const Color(0xFFF5F5F5);
    final dark = const Color(0xFF424242);
    for (final cx in [35.0, 65.0]) {
      final x = cx - 12;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, 104, 20, 14), const Radius.circular(5)), Paint()..color = white);
      // Wheels
      for (double wx = x + 5; wx <= x + 19; wx += 7) {
        canvas.drawCircle(Offset(wx, 122), 3, Paint()..color = dark);
        canvas.drawCircle(Offset(wx, 122), 1.5, Paint()..color = Colors.white54);
      }
      // Stopper
      canvas.drawCircle(Offset(x + 2, 120), 2.5, Paint()..color = const Color(0xFFE53935));
    }
  }

  void _drawIceSkates(Canvas canvas, [Color? tint]) {
    final white = tint ?? const Color(0xFFF5F5F5);
    for (final cx in [35.0, 65.0]) {
      final x = cx - 12;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, 100, 20, 18), const Radius.circular(5)), Paint()..color = white);
      // Blade
      canvas.drawLine(Offset(x, 122), Offset(x + 24, 122), Paint()..color = const Color(0xFFB0BEC5)..strokeWidth = 2);
      // Laces
      for (double y = 104; y <= 114; y += 4) canvas.drawLine(Offset(x + 8, y), Offset(x + 16, y), Paint()..color = Colors.grey..strokeWidth = 1);
    }
  }

  void _drawCrocs(Canvas canvas, [Color? tint]) {
    final lime = tint ?? const Color(0xFF76FF03);
    final dark = HSLColor.fromColor(lime).withLightness((HSLColor.fromColor(lime).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    for (final cx in [35.0, 65.0]) {
      final x = cx - 12;
      // Rounded clog shape
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 108, 24, 14), const Radius.circular(7)), Paint()..color = lime);
      // Holes
      for (double hx = x + 6; hx <= x + 18; hx += 6) {
        canvas.drawCircle(Offset(hx, 113), 2, Paint()..color = dark.withValues(alpha: 0.3));
      }
      // Heel strap
      canvas.drawLine(Offset(x + 2, 116), Offset(x + 22, 116), Paint()..color = dark..strokeWidth = 2);
    }
  }

  void _drawPlatforms(Canvas canvas, [Color? tint]) {
    final purple = tint ?? const Color(0xFF7E57C2);
    final dark = HSLColor.fromColor(purple).withLightness((HSLColor.fromColor(purple).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    for (final cx in [35.0, 65.0]) {
      final x = cx - 12;
      // Thick platform sole
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 116, 24, 10), const Radius.circular(4)), Paint()..color = dark);
      // Upper shoe
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, 104, 20, 14), const Radius.circular(5)), Paint()..color = purple);
    }
  }

  void _drawMoonBoots(Canvas canvas, [Color? tint]) {
    final silver = tint ?? const Color(0xFFB0BEC5);
    final dark = const Color(0xFF78909C);
    for (final cx in [35.0, 65.0]) {
      final x = cx - 14;
      // Puffy, oversized boot
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 94, 28, 28), const Radius.circular(10)), Paint()..color = silver);
      // Sole
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, 118, 24, 6), const Radius.circular(3)), Paint()..color = dark);
      // Buckle straps
      canvas.drawLine(Offset(x + 4, 102), Offset(x + 24, 102), Paint()..color = dark..strokeWidth = 2);
      canvas.drawLine(Offset(x + 4, 110), Offset(x + 24, 110), Paint()..color = dark..strokeWidth = 2);
    }
  }

  void _drawHikingBoots(Canvas canvas, [Color? tint]) {
    final brown = tint ?? const Color(0xFF795548);
    final dark = HSLColor.fromColor(brown).withLightness((HSLColor.fromColor(brown).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    for (final cx in [35.0, 65.0]) {
      final x = cx - 12;
      // Sole with lugs
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 1, 118, 26, 7), const Radius.circular(3)), Paint()..color = const Color(0xFF3E2723));
      // Boot shaft
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, 96, 22, 24), const Radius.circular(5)), Paint()..color = brown);
      // Laces
      for (double y = 100; y <= 114; y += 4) {
        canvas.drawLine(Offset(x + 8, y), Offset(x + 16, y), Paint()..color = dark..strokeWidth = 1.2);
      }
      // Metal eyelets
      for (double y = 100; y <= 114; y += 4) {
        canvas.drawCircle(Offset(x + 7, y), 1, Paint()..color = const Color(0xFFB0BEC5));
        canvas.drawCircle(Offset(x + 17, y), 1, Paint()..color = const Color(0xFFB0BEC5));
      }
    }
  }

  void _drawCombatBoots(Canvas canvas, [Color? tint]) {
    final black = tint ?? const Color(0xFF212121);
    final dark = const Color(0xFF111111);
    for (final cx in [35.0, 65.0]) {
      final x = cx - 12;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 1, 118, 26, 7), const Radius.circular(3)), Paint()..color = dark);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, 94, 22, 26), const Radius.circular(5)), Paint()..color = black);
      // Buckle
      canvas.drawRect(Rect.fromLTWH(x + 6, 96, 12, 4), Paint()..color = const Color(0xFFB0BEC5));
      // Laces
      for (double y = 104; y <= 116; y += 4) canvas.drawLine(Offset(x + 8, y), Offset(x + 16, y), Paint()..color = Colors.white30..strokeWidth = 1);
    }
  }

  void _drawClogs(Canvas canvas, [Color? tint]) {
    final wood = tint ?? const Color(0xFFD4A853);
    final dark = HSLColor.fromColor(wood).withLightness((HSLColor.fromColor(wood).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    for (final cx in [35.0, 65.0]) {
      final x = cx - 12;
      // Wooden sole
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 114, 24, 10), const Radius.circular(5)), Paint()..color = wood);
      // Wood grain
      canvas.drawLine(Offset(x + 4, 118), Offset(x + 20, 118), Paint()..color = dark.withValues(alpha: 0.3)..strokeWidth = 1);
      // Upper
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, 108, 20, 8), const Radius.circular(4)), Paint()..color = dark);
    }
  }

  void _drawFuzzySlippers(Canvas canvas, [Color? tint]) {
    final brown = tint ?? const Color(0xFF795548);
    final dark = HSLColor.fromColor(brown).withLightness((HSLColor.fromColor(brown).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    for (final cx in [35.0, 65.0]) {
      // Fluffy bear face slipper
      canvas.drawOval(Rect.fromLTWH(cx - 13, 108, 26, 14), Paint()..color = brown);
      // Ears
      canvas.drawCircle(Offset(cx - 6, 106), 4, Paint()..color = brown);
      canvas.drawCircle(Offset(cx + 6, 106), 4, Paint()..color = brown);
      canvas.drawCircle(Offset(cx - 6, 106), 2.5, Paint()..color = dark);
      canvas.drawCircle(Offset(cx + 6, 106), 2.5, Paint()..color = dark);
      // Eyes + nose
      canvas.drawCircle(Offset(cx - 4, 114), 1.5, Paint()..color = Colors.black54);
      canvas.drawCircle(Offset(cx + 4, 114), 1.5, Paint()..color = Colors.black54);
      canvas.drawCircle(Offset(cx, 116), 1.2, Paint()..color = dark);
    }
  }

  void _drawSkiBoots(Canvas canvas, [Color? tint]) {
    final blue = tint ?? const Color(0xFF42A5F5);
    final dark = HSLColor.fromColor(blue).withLightness((HSLColor.fromColor(blue).lightness - 0.15).clamp(0.0, 1.0)).toColor();
    for (final cx in [35.0, 65.0]) {
      final x = cx - 14;
      // Rigid shell boot
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 96, 28, 26), const Radius.circular(6)), Paint()..color = blue);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 2, 118, 24, 6), const Radius.circular(3)), Paint()..color = dark);
      // Buckles
      for (double y = 100; y <= 112; y += 6) {
        canvas.drawRect(Rect.fromLTWH(x + 4, y, 20, 3), Paint()..color = dark);
        canvas.drawRect(Rect.fromLTWH(x + 10, y, 6, 3), Paint()..color = const Color(0xFFB0BEC5));
      }
    }
  }

  void _drawGladiatorSandals(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFD4A853);
    final feetPaint = Paint()..color = _ClayColors.orangeFeet;
    for (final cx in [35.0, 65.0]) {
      // Feet visible
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 6, 108, 12, 10), const Radius.circular(5)), feetPaint);
      // Sole
      canvas.drawOval(Rect.fromLTWH(cx - 10, 116, 20, 7), Paint()..color = gold);
      // Wrap-up straps
      for (double y = 100; y <= 114; y += 4) {
        canvas.drawLine(Offset(cx - 8, y), Offset(cx + 8, y), Paint()..color = gold..strokeWidth = 2);
      }
    }
  }

  void _drawRocketBoots(Canvas canvas, [Color? tint]) {
    final chrome = tint ?? const Color(0xFFB0BEC5);
    final dark = const Color(0xFF78909C);
    for (final cx in [35.0, 65.0]) {
      final x = cx - 12;
      // Metal boot
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, 96, 22, 24), const Radius.circular(5)), Paint()..color = chrome);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, 96, 22, 24), const Radius.circular(5)), Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 1.5);
      // Flame jets
      final flame = Path()..moveTo(cx - 4, 122)..quadraticBezierTo(cx, 136, cx + 4, 122);
      canvas.drawPath(flame, Paint()..color = const Color(0xFFFF9800));
      canvas.drawPath(Path()..moveTo(cx - 2, 122)..quadraticBezierTo(cx, 132, cx + 2, 122), Paint()..color = const Color(0xFFFFEB3B));
      // Exhaust glow
      canvas.drawCircle(Offset(cx, 124), 4, Paint()..color = const Color(0xFFFF9800).withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  void _drawKnightBoots(Canvas canvas, [Color? tint]) {
    final silver = tint ?? const Color(0xFFB0BEC5);
    final dark = const Color(0xFF78909C);
    final gold = const Color(0xFFFFD700);
    for (final cx in [35.0, 65.0]) {
      final x = cx - 12;
      // Armored plate boot
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, 94, 22, 26), const Radius.circular(4)), Paint()..color = silver);
      // Plate segments
      for (double y = 98; y <= 114; y += 5) {
        canvas.drawLine(Offset(x + 3, y), Offset(x + 21, y), Paint()..color = dark..strokeWidth = 1.2);
      }
      // Gold trim
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 3, 94, 18, 4), const Radius.circular(2)), Paint()..color = gold);
      // Sole
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 118, 24, 6), const Radius.circular(3)), Paint()..color = dark);
    }
  }

  // ─────────────────── BACK VIEW ───────────────────

  void _drawBackView(Canvas canvas) {
    final hatId = outfit[ClothingSlot.hat];
    final topId = outfit[ClothingSlot.top];
    final scarfId = outfit[ClothingSlot.scarf];
    final shoesId = outfit[ClothingSlot.shoes];
    final accId = outfit[ClothingSlot.accessory];
    final bool hasTop = topId != null;

    // ── 1. Ground shadow ──
    canvas.drawOval(
      const Rect.fromLTWH(20, 115, 60, 10),
      Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ── 2. Cape (behind everything) ──
    if (accId == 'acc_cape') {
      final tint = outfitColors[accId] != null ? Color(outfitColors[accId]!) : null;
      final red = tint ?? const Color(0xFFD32F2F);
      final hsl = HSLColor.fromColor(red);
      final darkRed = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
      // Cape visible from behind — wider, flowing down
      final cape = Path()
        ..moveTo(22, 48)..quadraticBezierTo(14, 80, 12, 118)
        ..lineTo(88, 118)..quadraticBezierTo(86, 80, 78, 48)..close();
      canvas.drawPath(cape, Paint()..color = red);
      // Inner folds
      canvas.drawLine(const Offset(36, 52), const Offset(30, 114), Paint()..color = darkRed..strokeWidth = 1);
      canvas.drawLine(const Offset(50, 50), const Offset(50, 116), Paint()..color = darkRed..strokeWidth = 1);
      canvas.drawLine(const Offset(64, 52), const Offset(70, 114), Paint()..color = darkRed..strokeWidth = 1);
    }

    // ── 3. Feet/shoes ──
    if (shoesId == null) {
      _drawFeet(canvas);
    } else {
      _drawShoes(canvas, shoesId);
    }

    // ── 4. Body (back) ──
    final bodyBack = Path()
      ..addOval(const Rect.fromLTWH(15, 45, 70, 68));
    canvas.drawPath(bodyBack, Paint()..color = _ClayColors.blueMain);
    // Back shading — lighter center, darker edges
    canvas.drawOval(
      const Rect.fromLTWH(25, 50, 50, 58),
      Paint()..color = _ClayColors.blueHighlight.withValues(alpha: 0.3),
    );

    // ── 5. Top (back view) ──
    if (hasTop) {
      _drawTopBack(canvas, topId);
    }

    // ── 6. Backpack (over top) ──
    if (accId == 'acc_backpack') {
      final tint = outfitColors[accId] != null ? Color(outfitColors[accId]!) : null;
      _drawBackpackBack(canvas, tint);
    }

    // ── 7. Wings (from behind — small stubs on sides) ──
    final wingColor = hasTop ? null : _ClayColors.wingMain;
    // Left wing stub
    canvas.drawOval(
      const Rect.fromLTWH(4, 62, 18, 30),
      Paint()..color = wingColor ?? _getTopColor(topId!),
    );
    // Right wing stub
    canvas.drawOval(
      const Rect.fromLTWH(78, 62, 18, 30),
      Paint()..color = wingColor ?? _getTopColor(topId!),
    );

    // ── 8. Scarf (back) ──
    if (scarfId != null) {
      final scarfTint = outfitColors[scarfId] != null ? Color(outfitColors[scarfId]!) : null;
      final base = scarfTint ?? const Color(0xFFF7C427);
      // Scarf tail hanging down the back
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(30, 44, 40, 12), const Radius.circular(4)),
        Paint()..color = base,
      );
      // Dangling ends
      final tail = Path()
        ..moveTo(32, 56)..quadraticBezierTo(28, 72, 30, 82)
        ..lineTo(38, 82)..quadraticBezierTo(36, 72, 38, 56)..close();
      canvas.drawPath(tail, Paint()..color = base);
    } else if (!hasTop) {
      // Default scarf from behind
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(30, 44, 40, 12), const Radius.circular(4)),
        Paint()..color = scarfColor,
      );
    }

    // ── 9. Head (back — no face) ──
    canvas.drawOval(
      const Rect.fromLTWH(25, 8, 50, 52),
      Paint()..color = _ClayColors.blueMain,
    );
    // Back-of-head highlight
    canvas.drawOval(
      const Rect.fromLTWH(32, 14, 36, 40),
      Paint()..color = _ClayColors.blueHighlight.withValues(alpha: 0.2),
    );
    // Small tail feather tuft at back of head
    final tuft = Path()
      ..moveTo(46, 10)..quadraticBezierTo(50, 2, 54, 10);
    canvas.drawPath(tuft, Paint()..color = _ClayColors.blueMain..strokeWidth = 3..style = PaintingStyle.stroke);

    // ── 10. Hat (from behind) ──
    if (hatId != null) {
      _drawHat(canvas, hatId); // Most hats look similar from behind
    }
  }

  /// Get the primary color of a top for wing coloring in back view
  Color _getTopColor(String topId) {
    final tint = outfitColors[topId] != null ? Color(outfitColors[topId]!) : null;
    if (tint != null) return tint;
    // Default top colors — simplified version
    const topColors = <String, Color>{
      'top_raincoat': Color(0xFF1565C0),
      'top_hawaiian': Color(0xFF2E7D32),
      'top_pyjama': Color(0xFFAB47BC),
      'top_scarf_thick': Color(0xFFF7C427),
      'top_linen': Color(0xFFE8D5B5),
      'top_hoodie': Color(0xFF455A64),
      'top_tuxedo': Color(0xFF212121),
      'top_vest': Color(0xFF795548),
      'top_tank': Color(0xFFE53935),
      'top_overalls': Color(0xFF1565C0),
      'top_poncho': Color(0xFFE65100),
      'top_kimono': Color(0xFFAD1457),
      'top_apron': Color(0xFFECEFF1),
      'top_sailor': Color(0xFFE8EAF6),
      'top_varsity': Color(0xFF1B5E20),
      'top_jersey': Color(0xFFE53935),
    };
    return topColors[topId] ?? const Color(0xFF26A69A);
  }

  /// Draws the back of a top garment
  void _drawTopBack(Canvas canvas, String topId) {
    final color = _getTopColor(topId);
    final hsl = HSLColor.fromColor(color);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    // Generic top back shape (same body oval but clipped)
    final topBody = _topBodyPath();
    canvas.drawPath(topBody, Paint()..color = color);
    // Center seam
    canvas.drawLine(const Offset(50, 46), const Offset(50, 112),
        Paint()..color = dark..strokeWidth = 1);
    // Shoulder seams
    canvas.drawLine(const Offset(50, 46), const Offset(22, 58),
        Paint()..color = dark..strokeWidth = 0.8);
    canvas.drawLine(const Offset(50, 46), const Offset(78, 58),
        Paint()..color = dark..strokeWidth = 0.8);
    // Bottom hem
    canvas.drawLine(const Offset(20, 110), const Offset(80, 110),
        Paint()..color = dark..strokeWidth = 1.2);
    // Hood for hoodie
    if (topId == 'top_hoodie') {
      final hood = Path()
        ..moveTo(30, 28)..quadraticBezierTo(50, 16, 70, 28)
        ..lineTo(68, 48)..quadraticBezierTo(50, 44, 32, 48)..close();
      canvas.drawPath(hood, Paint()..color = color);
      canvas.drawPath(hood, Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 1);
    }
    // Cape collar for tuxedo
    if (topId == 'top_tuxedo') {
      canvas.drawLine(const Offset(30, 48), const Offset(30, 68),
          Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = 2);
      canvas.drawLine(const Offset(70, 48), const Offset(70, 68),
          Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = 2);
    }
  }

  /// Draws the backpack from behind (full view with straps)
  void _drawBackpackBack(Canvas canvas, [Color? tint]) {
    final base = tint ?? const Color(0xFFE53935);
    final hsl = HSLColor.fromColor(base);
    final dark = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    // Straps going over shoulders
    final leftStrap = Path()
      ..moveTo(32, 48)..quadraticBezierTo(28, 56, 30, 68)
      ..lineTo(34, 68)..quadraticBezierTo(32, 56, 36, 48)..close();
    canvas.drawPath(leftStrap, Paint()..color = dark);
    final rightStrap = Path()
      ..moveTo(68, 48)..quadraticBezierTo(72, 56, 70, 68)
      ..lineTo(66, 68)..quadraticBezierTo(68, 56, 64, 48)..close();
    canvas.drawPath(rightStrap, Paint()..color = dark);
    // Main bag body
    final bag = RRect.fromRectAndRadius(const Rect.fromLTWH(26, 54, 48, 44), const Radius.circular(10));
    canvas.drawRRect(bag.shift(const Offset(1, 2)),
        Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawRRect(bag, Paint()..color = base);
    // Top flap
    final flap = RRect.fromRectAndRadius(const Rect.fromLTWH(28, 54, 44, 18), const Radius.circular(8));
    canvas.drawRRect(flap, Paint()..color = dark);
    // Buckle
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(44, 68, 12, 8), const Radius.circular(2)),
      Paint()..color = const Color(0xFFC0C0C0),
    );
    // Front pocket
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(34, 78, 32, 16), const Radius.circular(6)),
      Paint()..color = light,
    );
    // Zipper
    canvas.drawLine(const Offset(38, 86), const Offset(62, 86),
        Paint()..color = dark..strokeWidth = 1);
    canvas.drawCircle(const Offset(62, 86), 2, Paint()..color = const Color(0xFFC0C0C0));
    // Logo dot
    canvas.drawCircle(const Offset(50, 62), 3, Paint()..color = light);
  }

  // ─────────────────── ACCESSORY DRAWING ───────────────────

  /// Draws the umbrella pole and grip only — the canopy is drawn as step 15
  /// (on top of everything) so that the hat, head, etc. appear UNDER it.
  void _drawUmbrella(Canvas canvas, [Color? tint]) {
    const pole = Color(0xFF424242);
    const gripPoint = Offset(78, 86);
    const poleTop = Offset(50, -22);
    // Pole — angled from grip in right wing up to canopy center
    canvas.drawLine(gripPoint, poleTop, Paint()..color = pole..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    // Grip handle
    canvas.drawCircle(gripPoint, 4, Paint()..color = const Color(0xFF607D8B));
    canvas.drawCircle(gripPoint, 2.5, Paint()..color = pole);
    // Ferrule at top of pole (will be hidden behind canopy)
    canvas.drawCircle(poleTop, 2, Paint()..color = pole);
  }

  /// Draws the umbrella canopy — called as the very last paint step so it
  /// shelters the hat, head, glasses, and entire body beneath it.
  void _drawUmbrellaCanopy(Canvas canvas, [Color? tint]) {
    final dome = tint ?? const Color(0xFFEF5350);
    final hsl = HSLColor.fromColor(dome);
    final domeDark = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
    // Canopy — wide enough to cover the full body (x: -4 to 104) and
    // tall enough to clear even the tallest hats (peak ≈ y -24).
    final domePath = Path()
      ..moveTo(-4, 2)
      ..quadraticBezierTo(50, -52, 104, 2)
      ..close();
    // Drop shadow
    canvas.drawPath(
      domePath.shift(const Offset(0, 3)),
      Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Solid fill
    canvas.drawPath(domePath, Paint()..color = dome);
    // Scalloped edge along the bottom curve of the dome
    final scallops = Path();
    for (double x = 2; x <= 94; x += 15) {
      scallops.addArc(Rect.fromLTWH(x, -2, 15, 8), 0, 3.14159);
    }
    canvas.drawPath(scallops, Paint()..color = domeDark..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Ribs from pole tip to dome edge
    const poleTop = Offset(50, -22);
    final ribPaint = Paint()..color = domeDark..strokeWidth = 0.9;
    for (final dx in [6.0, 22.0, 38.0, 54.0, 70.0, 86.0, 98.0]) {
      final t = (dx + 4) / 108;
      final tipY = 2 - (1 - (2 * t - 1).abs()) * 6;
      canvas.drawLine(Offset(poleTop.dx, poleTop.dy + 4), Offset(dx, tipY), ribPaint);
    }
    // Ferrule dot at peak
    canvas.drawCircle(poleTop, 2.5, Paint()..color = const Color(0xFF424242));
  }

  void _drawBouquet(Canvas canvas, [Color? tint]) {
    final stemColor = tint ?? const Color(0xFF4CAF50);
    final hsl = HSLColor.fromColor(stemColor);
    final darkStem = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    final stemPaint = Paint()..color = stemColor..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(80, 92), const Offset(74, 72), stemPaint);
    canvas.drawLine(const Offset(80, 92), const Offset(80, 68), stemPaint);
    canvas.drawLine(const Offset(80, 92), const Offset(86, 72), stemPaint);
    canvas.drawOval(const Rect.fromLTWH(76, 80, 8, 5), Paint()..color = darkStem);
    final colors = [const Color(0xFFFF7043), const Color(0xFFFFEB3B), const Color(0xFFE91E63)];
    final centers = [const Offset(74, 68), const Offset(80, 62), const Offset(86, 68)];
    for (int i = 0; i < 3; i++) {
      final fp = Paint()..color = colors[i];
      final c = centers[i];
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx - 5, c.dy), width: 9, height: 7), fp);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx + 5, c.dy), width: 9, height: 7), fp);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - 5), width: 7, height: 9), fp);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy + 5), width: 7, height: 9), fp);
      canvas.drawCircle(c, 4, Paint()..color = Colors.amber);
    }
  }

  void _drawFlag(Canvas canvas) {
    canvas.drawLine(const Offset(84, 100), const Offset(84, 46), Paint()..color = const Color(0xFF424242)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    canvas.drawRect(const Rect.fromLTWH(84, 46, 9, 18), Paint()..color = const Color(0xFF0055A4));
    canvas.drawRect(const Rect.fromLTWH(93, 46, 9, 18), Paint()..color = Colors.white);
    canvas.drawRect(const Rect.fromLTWH(102, 46, 9, 18), Paint()..color = const Color(0xFFEF4135));
    canvas.drawRect(const Rect.fromLTWH(84, 46, 27, 18),
        Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 0.8);
  }

  void _drawPumpkin(Canvas canvas, [Color? tint]) {
    final orange = tint ?? const Color(0xFFFF8F00);
    final hsl = HSLColor.fromColor(orange);
    final darkOrange = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    canvas.drawOval(const Rect.fromLTWH(68, 104, 24, 18), Paint()..color = orange);
    canvas.drawLine(const Offset(80, 104), const Offset(80, 122), Paint()..color = darkOrange..strokeWidth = 1.5);
    canvas.drawLine(const Offset(73, 105), const Offset(71, 121), Paint()..color = darkOrange..strokeWidth = 1.2);
    canvas.drawLine(const Offset(87, 105), const Offset(89, 121), Paint()..color = darkOrange..strokeWidth = 1.2);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(78, 100, 4, 6), const Radius.circular(2)), Paint()..color = const Color(0xFF4CAF50));
    // Carved face
    canvas.drawPath(Path()..moveTo(73, 111)..lineTo(77, 107)..lineTo(77, 111)..close(), Paint()..color = Colors.black54);
    canvas.drawPath(Path()..moveTo(83, 111)..lineTo(83, 107)..lineTo(87, 111)..close(), Paint()..color = Colors.black54);
    canvas.drawPath(Path()..moveTo(72, 116)..quadraticBezierTo(80, 122, 88, 116),
        Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawStarWand(Canvas canvas, [Color? tint]) {
    final starColor = tint ?? const Color(0xFFFFD700);
    final hsl = HSLColor.fromColor(starColor);
    final darkStar = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    canvas.drawLine(const Offset(86, 97), const Offset(74, 50),
        Paint()..color = const Color(0xFFD4A853)..strokeWidth = 3.5..strokeCap = StrokeCap.round);
    _drawStarShape(canvas, const Offset(70, 46), 13, Paint()..color = starColor);
    _drawStarShape(canvas, const Offset(70, 46), 13,
        Paint()..color = darkStar..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final sp = Paint()..color = Colors.yellowAccent..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(60, 40), const Offset(56, 36), sp);
    canvas.drawLine(const Offset(58, 49), const Offset(53, 49), sp);
    canvas.drawLine(const Offset(62, 57), const Offset(58, 61), sp);
  }

  void _drawStarShape(Canvas canvas, Offset center, double r, Paint paint) {
    const pi = math.pi;
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 2 * pi / 5) - pi / 2;
      final innerAngle = outerAngle + pi / 5;
      final outerX = center.dx + r * math.cos(outerAngle);
      final outerY = center.dy + r * math.sin(outerAngle);
      final innerX = center.dx + r * 0.38 * math.cos(innerAngle);
      final innerY = center.dy + r * 0.38 * math.sin(innerAngle);
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawGiftBox(Canvas canvas, [Color? tint]) {
    final base = tint ?? const Color(0xFFE53935);
    final hsl = HSLColor.fromColor(base);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Held at right side
    const bx = 70.0, by = 78.0;
    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(bx - 1, by + 17, 22, 4), const Radius.circular(2)),
      Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Box body
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(bx, by, 20, 18), const Radius.circular(2)),
      Paint()..color = base,
    );
    // Dark bottom half
    canvas.drawRect(Rect.fromLTWH(bx, by + 9, 20, 9), Paint()..color = dark);
    // Ribbon vertical
    canvas.drawRect(Rect.fromLTWH(bx + 8.5, by, 3, 18), Paint()..color = const Color(0xFFFFD54F));
    // Ribbon horizontal
    canvas.drawRect(Rect.fromLTWH(bx, by + 7.5, 20, 3), Paint()..color = const Color(0xFFFFD54F));
    // Bow on top
    final bow = Path()
      ..moveTo(bx + 10, by)..lineTo(bx + 4, by - 6)..lineTo(bx + 10, by - 2)..close();
    canvas.drawPath(bow, Paint()..color = const Color(0xFFFFD54F));
    final bow2 = Path()
      ..moveTo(bx + 10, by)..lineTo(bx + 16, by - 6)..lineTo(bx + 10, by - 2)..close();
    canvas.drawPath(bow2, Paint()..color = const Color(0xFFFFC107));
  }

  void _drawMagicWand(Canvas canvas, [Color? tint]) {
    final wandColor = tint ?? const Color(0xFF4A148C);
    // Wand stick — held at right side, angled upward
    canvas.drawLine(const Offset(86, 97), const Offset(68, 44),
        Paint()..color = const Color(0xFF1A1A1A)..strokeWidth = 3..strokeCap = StrokeCap.round);
    // White tip bands
    canvas.drawLine(const Offset(86, 97), const Offset(84, 90),
        Paint()..color = Colors.white..strokeWidth = 3..strokeCap = StrokeCap.round);
    // Glowing star at tip
    final glow = Paint()..color = wandColor.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(68, 44), 10, glow);
    _drawStarShape(canvas, const Offset(68, 44), 10, Paint()..color = wandColor);
    _drawStarShape(canvas, const Offset(68, 44), 10,
        Paint()..color = Colors.white38..style = PaintingStyle.stroke..strokeWidth = 1);
    // Sparkle dots
    final sp = Paint()..color = Colors.white70;
    canvas.drawCircle(const Offset(60, 38), 1.5, sp);
    canvas.drawCircle(const Offset(76, 38), 1.5, sp);
    canvas.drawCircle(const Offset(64, 52), 1.5, sp);
  }

  void _drawGuitar(Canvas canvas, [Color? tint]) {
    final body = tint ?? const Color(0xFF8D6E63);
    final hsl = HSLColor.fromColor(body);
    final dark = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
    // Neck — angled from right hip up to left
    canvas.drawLine(const Offset(28, 30), const Offset(68, 85),
        Paint()..color = dark..strokeWidth = 4..strokeCap = StrokeCap.round);
    // Frets
    for (double t = 0.15; t < 0.6; t += 0.12) {
      final x = 28 + (68 - 28) * t, y = 30 + (85 - 30) * t;
      canvas.drawLine(Offset(x - 3, y - 2), Offset(x + 3, y + 2),
          Paint()..color = const Color(0xFFC0C0C0)..strokeWidth = 0.8);
    }
    // Body — figure-8 shape at lower right
    canvas.drawOval(const Rect.fromLTWH(55, 76, 22, 16), Paint()..color = body);
    canvas.drawOval(const Rect.fromLTWH(50, 86, 28, 22), Paint()..color = body);
    // Sound hole
    canvas.drawCircle(const Offset(64, 94), 5, Paint()..color = dark);
    canvas.drawCircle(const Offset(64, 94), 3.5, Paint()..color = Colors.black38);
    // Strings
    canvas.drawLine(const Offset(30, 32), const Offset(64, 94),
        Paint()..color = const Color(0xFFC0C0C0)..strokeWidth = 0.5);
    canvas.drawLine(const Offset(28, 34), const Offset(62, 96),
        Paint()..color = const Color(0xFFC0C0C0)..strokeWidth = 0.5);
    // Headstock
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(24, 24, 10, 10), const Radius.circular(3)),
      Paint()..color = dark,
    );
    // Tuning pegs
    canvas.drawCircle(const Offset(26, 26), 1.5, Paint()..color = const Color(0xFFC0C0C0));
    canvas.drawCircle(const Offset(32, 26), 1.5, Paint()..color = const Color(0xFFC0C0C0));
    canvas.drawCircle(const Offset(26, 32), 1.5, Paint()..color = const Color(0xFFC0C0C0));
    canvas.drawCircle(const Offset(32, 32), 1.5, Paint()..color = const Color(0xFFC0C0C0));
  }

  void _drawBackpack(Canvas canvas, [Color? tint]) {
    final base = tint ?? const Color(0xFFE53935);
    final hsl = HSLColor.fromColor(base);
    final dark = hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    // Main bag body — behind Pigio, slightly wider than body, visible as side bulges
    final bag = RRect.fromRectAndRadius(const Rect.fromLTWH(22, 52, 56, 48), const Radius.circular(10));
    // Shadow
    canvas.drawRRect(bag.shift(const Offset(2, 2)),
        Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawRRect(bag, Paint()..color = base);
    // Top flap
    final flap = Path()
      ..moveTo(24, 58)..quadraticBezierTo(50, 48, 76, 58)..lineTo(76, 66)
      ..quadraticBezierTo(50, 56, 24, 66)..close();
    canvas.drawPath(flap, Paint()..color = dark);
    // Buckle
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(44, 60, 12, 8), const Radius.circular(2)),
      Paint()..color = const Color(0xFFC0C0C0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(46, 62, 8, 4), const Radius.circular(1)),
      Paint()..color = dark,
    );
    // Straps visible on sides
    canvas.drawLine(const Offset(30, 54), const Offset(28, 74),
        Paint()..color = dark..strokeWidth = 3..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(70, 54), const Offset(72, 74),
        Paint()..color = dark..strokeWidth = 3..strokeCap = StrokeCap.round);
    // Front pocket
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(34, 72, 32, 20), const Radius.circular(6)),
      Paint()..color = light,
    );
    // Zipper line
    canvas.drawLine(const Offset(38, 82), const Offset(62, 82),
        Paint()..color = dark..strokeWidth = 1);
    // Zipper pull
    canvas.drawCircle(const Offset(62, 82), 2, Paint()..color = const Color(0xFFC0C0C0));
  }

  void _drawSkateboard(Canvas canvas, [Color? tint]) {
    final deck = tint ?? const Color(0xFF43A047);
    final hsl = HSLColor.fromColor(deck);
    final dark = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
    // Board on the ground beside Pigio
    // Deck
    final deckPath = Path()
      ..moveTo(10, 118)..quadraticBezierTo(6, 114, 10, 112)
      ..lineTo(55, 112)..quadraticBezierTo(59, 114, 55, 118)..close();
    canvas.drawPath(deckPath, Paint()..color = deck);
    // Grip tape stripe
    canvas.drawRect(const Rect.fromLTWH(14, 113, 37, 4), Paint()..color = dark.withValues(alpha: 0.5));
    // Trucks & wheels
    final truckPaint = Paint()..color = const Color(0xFF9E9E9E);
    final wheelPaint = Paint()..color = const Color(0xFF212121);
    // Front truck
    canvas.drawRect(const Rect.fromLTWH(14, 118, 10, 3), truckPaint);
    canvas.drawCircle(const Offset(16, 123), 3, wheelPaint);
    canvas.drawCircle(const Offset(22, 123), 3, wheelPaint);
    // Back truck
    canvas.drawRect(const Rect.fromLTWH(40, 118, 10, 3), truckPaint);
    canvas.drawCircle(const Offset(42, 123), 3, wheelPaint);
    canvas.drawCircle(const Offset(48, 123), 3, wheelPaint);
  }

  void _drawTeddy(Canvas canvas, [Color? tint]) {
    final fur = tint ?? const Color(0xFF8D6E63);
    final hsl = HSLColor.fromColor(fur);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    // Teddy held at right side
    const cx = 82.0, cy = 82.0;
    // Body
    canvas.drawOval(Rect.fromCenter(center: const Offset(cx, cy + 6), width: 14, height: 16), Paint()..color = fur);
    // Head
    canvas.drawCircle(const Offset(cx, cy - 5), 8, Paint()..color = fur);
    // Ears
    canvas.drawCircle(const Offset(cx - 6, cy - 11), 4, Paint()..color = fur);
    canvas.drawCircle(const Offset(cx + 6, cy - 11), 4, Paint()..color = fur);
    canvas.drawCircle(const Offset(cx - 6, cy - 11), 2.5, Paint()..color = light);
    canvas.drawCircle(const Offset(cx + 6, cy - 11), 2.5, Paint()..color = light);
    // Snout
    canvas.drawOval(Rect.fromCenter(center: const Offset(cx, cy - 3), width: 6, height: 5), Paint()..color = light);
    // Eyes
    canvas.drawCircle(const Offset(cx - 3, cy - 7), 1.5, Paint()..color = Colors.black87);
    canvas.drawCircle(const Offset(cx + 3, cy - 7), 1.5, Paint()..color = Colors.black87);
    // Nose
    canvas.drawOval(Rect.fromCenter(center: const Offset(cx, cy - 4), width: 3, height: 2), Paint()..color = dark);
    // Arms
    canvas.drawOval(Rect.fromCenter(center: const Offset(cx - 8, cy + 2), width: 6, height: 8), Paint()..color = fur);
    canvas.drawOval(Rect.fromCenter(center: const Offset(cx + 8, cy + 2), width: 6, height: 8), Paint()..color = fur);
    // Bow
    canvas.drawCircle(const Offset(cx, cy + 1), 2, Paint()..color = const Color(0xFFE53935));
    final bowL = Path()..moveTo(cx, cy + 1)..lineTo(cx - 5, cy - 1)..lineTo(cx - 4, cy + 4)..close();
    final bowR = Path()..moveTo(cx, cy + 1)..lineTo(cx + 5, cy - 1)..lineTo(cx + 4, cy + 4)..close();
    canvas.drawPath(bowL, Paint()..color = const Color(0xFFE53935));
    canvas.drawPath(bowR, Paint()..color = const Color(0xFFE53935));
  }

  void _drawBalloon(Canvas canvas, [Color? tint]) {
    final balloonColor = tint ?? const Color(0xFFE53935);
    final hsl = HSLColor.fromColor(balloonColor);
    final light = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    // String from right wing up to balloon
    canvas.drawLine(const Offset(78, 74), const Offset(72, 10),
        Paint()..color = Colors.grey..strokeWidth = 0.8);
    // Heart-shaped balloon
    final heart = Path()
      ..moveTo(72, 16)
      ..cubicTo(72, 8, 60, 4, 60, 14)
      ..cubicTo(60, 20, 72, 26, 72, 26)
      ..cubicTo(72, 26, 84, 20, 84, 14)
      ..cubicTo(84, 4, 72, 8, 72, 16);
    // Shadow
    canvas.drawPath(heart.shift(const Offset(1, 1)),
        Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(heart, Paint()..color = balloonColor);
    // Highlight
    canvas.drawCircle(const Offset(66, 12), 3, Paint()..color = light.withValues(alpha: 0.5));
    // Knot at bottom
    canvas.drawPath(
      Path()..moveTo(70, 26)..lineTo(72, 30)..lineTo(74, 26)..close(),
      Paint()..color = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor(),
    );
  }

  void _drawLantern(Canvas canvas, [Color? tint]) {
    final base = tint ?? const Color(0xFFFF5722);
    final hsl = HSLColor.fromColor(base);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Held at right side
    const cx = 82.0, cy = 80.0;
    // Handle
    final handle = Path()
      ..moveTo(cx - 6, cy - 12)
      ..quadraticBezierTo(cx, cy - 20, cx + 6, cy - 12);
    canvas.drawPath(handle, Paint()..color = const Color(0xFFD4A853)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    // Glow
    canvas.drawCircle(Offset(cx, cy), 14,
        Paint()..color = const Color(0xFFFFAB00).withValues(alpha: 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Body
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: 18, height: 22), Paint()..color = base);
    // Ribs
    canvas.drawLine(Offset(cx, cy - 11), Offset(cx, cy + 11),
        Paint()..color = dark..strokeWidth = 0.8);
    canvas.drawLine(Offset(cx - 4, cy - 10), Offset(cx - 4, cy + 10),
        Paint()..color = dark..strokeWidth = 0.6);
    canvas.drawLine(Offset(cx + 4, cy - 10), Offset(cx + 4, cy + 10),
        Paint()..color = dark..strokeWidth = 0.6);
    // Top cap
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy - 12), width: 10, height: 4), const Radius.circular(2)),
      Paint()..color = const Color(0xFFD4A853),
    );
    // Bottom cap
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy + 12), width: 10, height: 4), const Radius.circular(2)),
      Paint()..color = const Color(0xFFD4A853),
    );
    // Tassel
    canvas.drawLine(Offset(cx, cy + 14), Offset(cx, cy + 20),
        Paint()..color = const Color(0xFFE53935)..strokeWidth = 1.5..strokeCap = StrokeCap.round);
  }

  void _drawShield(Canvas canvas, [Color? tint]) {
    final base = tint ?? const Color(0xFF1565C0);
    final hsl = HSLColor.fromColor(base);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    // Shield held in front at left side
    const cx = 18.0, cy = 74.0;
    final shield = Path()
      ..moveTo(cx, cy - 16)
      ..lineTo(cx + 16, cy - 10)
      ..quadraticBezierTo(cx + 16, cy + 10, cx, cy + 18)
      ..quadraticBezierTo(cx - 16, cy + 10, cx - 16, cy - 10)
      ..close();
    // Shadow
    canvas.drawPath(shield.shift(const Offset(1, 2)),
        Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawPath(shield, Paint()..color = base);
    // Border
    canvas.drawPath(shield, Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Cross emblem
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: 4, height: 18), Paint()..color = light);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy - 2), width: 14, height: 4), Paint()..color = light);
    // Rivets
    for (final o in [Offset(cx - 10, cy - 8), Offset(cx + 10, cy - 8), Offset(cx - 8, cy + 8), Offset(cx + 8, cy + 8)]) {
      canvas.drawCircle(o, 1.5, Paint()..color = const Color(0xFFD4A853));
    }
  }

  void _drawGrimoire(Canvas canvas, [Color? tint]) {
    final cover = tint ?? const Color(0xFF4A148C);
    final hsl = HSLColor.fromColor(cover);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    // Held at right side, slightly open
    const bx = 70.0, by = 72.0;
    // Back cover
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(bx + 1, by + 1, 22, 28), const Radius.circular(2)),
      Paint()..color = dark,
    );
    // Pages
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(bx + 2, by + 2, 19, 26), const Radius.circular(1)),
      Paint()..color = const Color(0xFFFFF8E1),
    );
    // Front cover
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, 22, 28), const Radius.circular(2)),
      Paint()..color = cover,
    );
    // Spine
    canvas.drawLine(Offset(bx, by), Offset(bx, by + 28), Paint()..color = dark..strokeWidth = 2);
    // Emblem — glowing circle
    canvas.drawCircle(Offset(bx + 11, by + 12), 6,
        Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    _drawStarShape(canvas, Offset(bx + 11, by + 12), 5, Paint()..color = const Color(0xFFFFD54F));
    // Title line
    canvas.drawLine(Offset(bx + 5, by + 22), Offset(bx + 17, by + 22),
        Paint()..color = const Color(0xFFD4A853)..strokeWidth = 1);
  }

  void _drawCrystalBall(Canvas canvas, [Color? tint]) {
    final base = tint ?? const Color(0xFF7E57C2);
    // Held at right side
    const cx = 80.0, cy = 86.0;
    // Pedestal
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy + 14), width: 18, height: 6), const Radius.circular(2)),
      Paint()..color = const Color(0xFF6D4C41),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy + 10), width: 12, height: 4), const Radius.circular(1)),
      Paint()..color = const Color(0xFF5D4037),
    );
    // Glow
    canvas.drawCircle(Offset(cx, cy), 14,
        Paint()..color = base.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    // Sphere
    final sphereGrad = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: [Colors.white.withValues(alpha: 0.6), base.withValues(alpha: 0.7), base],
    );
    canvas.drawCircle(Offset(cx, cy), 12,
        Paint()..shader = sphereGrad.createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 12)));
    // Inner mist
    canvas.drawCircle(Offset(cx - 2, cy - 2), 4,
        Paint()..color = Colors.white24..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    // Specular highlight
    canvas.drawCircle(Offset(cx - 4, cy - 5), 3, Paint()..color = Colors.white38);
    canvas.drawCircle(Offset(cx - 3, cy - 4), 1.5, Paint()..color = Colors.white60);
  }

  void _drawFishingRod(Canvas canvas, [Color? tint]) {
    final rod = tint ?? const Color(0xFF795548);
    final hsl = HSLColor.fromColor(rod);
    final dark = hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
    // Rod — from right wing angled up and to the right
    canvas.drawLine(const Offset(82, 86), const Offset(98, 10),
        Paint()..color = rod..strokeWidth = 3..strokeCap = StrokeCap.round);
    // Thinner tip section
    canvas.drawLine(const Offset(94, 26), const Offset(98, 10),
        Paint()..color = dark..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    // Guide rings
    for (final t in [0.3, 0.5, 0.7]) {
      final x = 82 + (98 - 82) * t, y = 86 + (10 - 86) * t;
      canvas.drawCircle(Offset(x, y), 1.5, Paint()..color = const Color(0xFFC0C0C0));
    }
    // Reel at handle
    canvas.drawOval(const Rect.fromLTWH(78, 82, 8, 10), Paint()..color = const Color(0xFF9E9E9E));
    canvas.drawCircle(const Offset(82, 87), 2, Paint()..color = const Color(0xFF616161));
    // Fishing line from tip, dangling down
    final line = Path()
      ..moveTo(98, 10)
      ..quadraticBezierTo(104, 30, 100, 50);
    canvas.drawPath(line, Paint()..color = Colors.grey.shade400..strokeWidth = 0.6..style = PaintingStyle.stroke);
    // Hook
    final hook = Path()
      ..moveTo(100, 50)..lineTo(100, 56)
      ..quadraticBezierTo(100, 60, 96, 58)
      ..lineTo(97, 56);
    canvas.drawPath(hook, Paint()..color = const Color(0xFFC0C0C0)..strokeWidth = 1..style = PaintingStyle.stroke);
  }

  void _drawPaintPalette(Canvas canvas, [Color? tint]) {
    final wood = tint ?? const Color(0xFFD7A86E);
    final hsl = HSLColor.fromColor(wood);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    // Palette held at left side
    const cx = 18.0, cy = 84.0;
    // Thumb hole + palette shape
    final palette = Path()
      ..addOval(Rect.fromCenter(center: Offset(cx, cy), width: 30, height: 22));
    canvas.drawPath(palette, Paint()..color = wood);
    canvas.drawPath(palette, Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 1);
    // Thumb hole
    canvas.drawCircle(Offset(cx - 6, cy + 4), 4, Paint()..color = dark);
    canvas.drawCircle(Offset(cx - 6, cy + 4), 3, Paint()..color = const Color(0xFFBCAAA4));
    // Paint blobs
    final colors = [
      const Color(0xFFE53935), const Color(0xFF1E88E5), const Color(0xFFFFEB3B),
      const Color(0xFF43A047), const Color(0xFFFF9800), const Color(0xFF8E24AA),
    ];
    final positions = [
      Offset(cx + 4, cy - 6), Offset(cx + 10, cy - 3), Offset(cx + 8, cy + 4),
      Offset(cx + 2, cy + 6), Offset(cx - 2, cy - 6), Offset(cx + 12, cy + 2),
    ];
    for (int i = 0; i < colors.length; i++) {
      canvas.drawCircle(positions[i], 2.5, Paint()..color = colors[i]);
    }
    // Paintbrush — held in right wing
    canvas.drawLine(const Offset(82, 92), const Offset(72, 60),
        Paint()..color = const Color(0xFF8D6E63)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    // Brush tip
    canvas.drawOval(const Rect.fromLTWH(69, 56, 6, 8), Paint()..color = const Color(0xFFE53935));
    // Ferrule
    canvas.drawRect(const Rect.fromLTWH(70, 62, 4, 3), Paint()..color = const Color(0xFFC0C0C0));
  }

  void _drawSword(Canvas canvas, [Color? tint]) {
    final blade = tint ?? const Color(0xFF90CAF9);
    final hsl = HSLColor.fromColor(blade);
    final light = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    // Held at right side, angled upward
    // Blade
    final bladePath = Path()
      ..moveTo(80, 84)..lineTo(76, 30)..lineTo(84, 30)..close();
    canvas.drawPath(bladePath, Paint()..color = blade);
    // Edge highlight
    canvas.drawLine(const Offset(78, 80), const Offset(77, 34),
        Paint()..color = light..strokeWidth = 1);
    // Blade tip
    canvas.drawPath(
      Path()..moveTo(76, 30)..lineTo(80, 20)..lineTo(84, 30)..close(),
      Paint()..color = blade,
    );
    // Cross-guard
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(70, 82, 20, 5), const Radius.circular(2)),
      Paint()..color = const Color(0xFFD4A853),
    );
    // Grip
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(77, 87, 6, 14), const Radius.circular(2)),
      Paint()..color = const Color(0xFF5D4037),
    );
    // Grip wrap
    for (double y = 89; y < 100; y += 3) {
      canvas.drawLine(Offset(77, y), Offset(83, y + 1.5),
          Paint()..color = const Color(0xFF8D6E63)..strokeWidth = 0.8);
    }
    // Pommel
    canvas.drawCircle(const Offset(80, 103), 4, Paint()..color = const Color(0xFFD4A853));
    canvas.drawCircle(const Offset(80, 103), 2, Paint()..color = const Color(0xFFFFD54F));
    // Glow effect
    canvas.drawLine(const Offset(78, 32), const Offset(77, 26),
        Paint()..color = light.withValues(alpha: 0.6)..strokeWidth = 2..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }

  void _drawTrophy(Canvas canvas, [Color? tint]) {
    final gold = tint ?? const Color(0xFFFFD54F);
    final hsl = HSLColor.fromColor(gold);
    final dark = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    // Held at right side
    const cx = 82.0, cy = 80.0;
    // Base
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy + 16), width: 18, height: 5), const Radius.circular(2)),
      Paint()..color = dark,
    );
    // Stem
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + 10), width: 5, height: 10), Paint()..color = gold);
    // Cup
    final cup = Path()
      ..moveTo(cx - 10, cy - 6)
      ..lineTo(cx - 8, cy + 5)
      ..quadraticBezierTo(cx, cy + 8, cx + 8, cy + 5)
      ..lineTo(cx + 10, cy - 6)
      ..close();
    canvas.drawPath(cup, Paint()..color = gold);
    // Highlight
    canvas.drawLine(Offset(cx - 4, cy - 4), Offset(cx - 3, cy + 2),
        Paint()..color = light..strokeWidth = 2);
    // Rim
    canvas.drawLine(Offset(cx - 10, cy - 6), Offset(cx + 10, cy - 6),
        Paint()..color = dark..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    // Handles
    final lHandle = Path()
      ..moveTo(cx - 10, cy - 4)..quadraticBezierTo(cx - 16, cy, cx - 10, cy + 4);
    canvas.drawPath(lHandle, Paint()..color = dark..strokeWidth = 2..style = PaintingStyle.stroke);
    final rHandle = Path()
      ..moveTo(cx + 10, cy - 4)..quadraticBezierTo(cx + 16, cy, cx + 10, cy + 4);
    canvas.drawPath(rHandle, Paint()..color = dark..strokeWidth = 2..style = PaintingStyle.stroke);
    // Star emblem
    _drawStarShape(canvas, Offset(cx, cy - 1), 5, Paint()..color = dark);
  }

  void _drawFriendshipBracelet(Canvas canvas, [Color? tint]) {
    final base = tint ?? const Color(0xFFE91E63);
    // Drawn on left wing/wrist area
    const cy = 78.0, cx = 18.0;
    final colors = [
      base,
      const Color(0xFFFFEB3B),
      const Color(0xFF4CAF50),
      base,
      const Color(0xFF2196F3),
    ];
    // Bracelet band — series of colored segments wrapping the wing
    for (int i = 0; i < colors.length; i++) {
      final y = cy - 4 + i * 2.0;
      canvas.drawLine(
        Offset(cx - 6, y), Offset(cx + 6, y),
        Paint()..color = colors[i]..strokeWidth = 2..strokeCap = StrokeCap.round,
      );
    }
    // Outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 7, cy - 5, 14, 12), const Radius.circular(3)),
      Paint()..color = Colors.black26..style = PaintingStyle.stroke..strokeWidth = 0.8,
    );
    // Small heart charm
    final heart = Path()
      ..moveTo(cx, cy + 10)
      ..cubicTo(cx, cy + 8, cx - 4, cy + 7, cx - 4, cy + 9)
      ..cubicTo(cx - 4, cy + 12, cx, cy + 14, cx, cy + 14)
      ..cubicTo(cx, cy + 14, cx + 4, cy + 12, cx + 4, cy + 9)
      ..cubicTo(cx + 4, cy + 7, cx, cy + 8, cx, cy + 10);
    canvas.drawPath(heart, Paint()..color = const Color(0xFFE53935));
    // Chain link to charm
    canvas.drawLine(Offset(cx, cy + 7), Offset(cx, cy + 10),
        Paint()..color = const Color(0xFFC0C0C0)..strokeWidth = 0.8);
  }

  void _drawWeatherMicroEffects(Canvas canvas, {required bool hasHat, required bool hasUmbrella}) {
    final exposure = weatherExposure.clamp(0.0, 1.0);
    if (exposure <= 0.05) return;

    switch (weatherCondition) {
      case 'snow':
        _drawSnowDust(canvas, exposure, hasHat: hasHat);
        break;
      case 'rain':
      case 'storm':
        _drawWetDrips(canvas, exposure, hasUmbrella: hasUmbrella);
        break;
      case 'sunny':
      case 'cloudy':
        if (weatherIsDay && weatherTemperature >= 29) {
          _drawHeadHeatShimmer(canvas, exposure);
        }
        break;
    }
  }

  void _drawSnowDust(Canvas canvas, double exposure, {required bool hasHat}) {
    final snowPaint = Paint()..color = Colors.white.withValues(alpha: 0.55 + exposure * 0.25);
    final dustRects = [
      Rect.fromLTWH(20, 54, 12, 4 + exposure * 2),
      Rect.fromLTWH(68, 54, 12, 4 + exposure * 2),
      Rect.fromLTWH(40, 106, 20, 3 + exposure * 2),
    ];
    for (final rect in dustRects) {
      canvas.drawOval(rect, snowPaint);
    }
    if (!hasHat) {
      canvas.drawOval(Rect.fromLTWH(36, 10, 28, 5 + exposure * 2), snowPaint);
    }
    for (final point in [const Offset(28, 58), const Offset(73, 59), const Offset(45, 110), const Offset(57, 110)]) {
      canvas.drawCircle(point, 1.6 + exposure, snowPaint);
    }
  }

  void _drawWetDrips(Canvas canvas, double exposure, {required bool hasUmbrella}) {
    final dripPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(alpha: 0.22 + exposure * 0.18)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final dropPaint = Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.18 + exposure * 0.14);
    final dripStartY = hasUmbrella ? 74.0 : 68.0;
    for (final x in [30.0, 40.0, 60.0, 70.0]) {
      final length = 5 + exposure * 7 + ((x.toInt() % 3) * 1.5);
      canvas.drawLine(Offset(x, dripStartY), Offset(x - 1.5, dripStartY + length), dripPaint);
      canvas.drawCircle(Offset(x - 1.5, dripStartY + length + 1.5), 1.2 + exposure * 0.8, dropPaint);
    }
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 113), width: 24 + exposure * 8, height: 4 + exposure * 2),
      dropPaint,
    );
  }

  void _drawHeadHeatShimmer(Canvas canvas, double exposure) {
    final shimmerPaint = Paint()
      ..color = const Color(0xFFFFB74D).withValues(alpha: 0.08 + exposure * 0.08)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final x = 38 + i * 12.0;
      final wave = math.sin((i + 1) * 0.9) * 2.4;
      canvas.drawLine(Offset(x, 4 + wave), Offset(x + 3, 26 + wave), shimmerPaint);
    }
    canvas.drawCircle(
      const Offset(50, 28),
      14 + exposure * 4,
      Paint()..color = const Color(0xFFFFD180).withValues(alpha: 0.03 + exposure * 0.03),
    );
  }

  @override
  bool shouldRepaint(covariant PigioPainter oldDelegate) =>
      oldDelegate.mood != mood ||
      oldDelegate.pose != pose ||
      oldDelegate.weatherCondition != weatherCondition ||
      oldDelegate.weatherExposure != weatherExposure ||
      oldDelegate.weatherIsDay != weatherIsDay ||
      oldDelegate.weatherTemperature != weatherTemperature ||
      oldDelegate.scarfColor != scarfColor ||
      oldDelegate.contactCount != contactCount ||
      oldDelegate.reservedCount != reservedCount ||
      !_outfitsEqual(oldDelegate.outfit, outfit) ||
      !_mapIntEqual(oldDelegate.outfitColors, outfitColors) ||
      oldDelegate.blinkPhase != blinkPhase ||
      oldDelegate.isTalking != isTalking ||
      oldDelegate.lookOffsetX != lookOffsetX ||
      oldDelegate.currentMonth != currentMonth;

  static bool _outfitsEqual(Map<ClothingSlot, String?> a, Map<ClothingSlot, String?> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  static bool _mapIntEqual(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

class PigioWidget extends StatefulWidget {
  final PigMood mood;
  final PigPose pose;
  final String? weatherCondition;
  final double weatherExposure;
  final bool weatherIsDay;
  final double weatherTemperature;
  final double size;
  final Color scarfColor;
  final int contactCount;
  final int reservedCount;
  final Map<ClothingSlot, String?> outfit;
  final Map<String, int> outfitColors;
  final bool isTalking;
  final double lookOffsetX;
  final int stage;
  final PigViewAngle viewAngle;

  const PigioWidget({
    super.key,
    this.mood = PigMood.normal,
    this.pose = PigPose.normal,
    this.weatherCondition,
    this.weatherExposure = 0.0,
    this.weatherIsDay = true,
    this.weatherTemperature = 0.0,
    this.size = 100,
    this.scarfColor = const Color(0xFFF7C427),
    this.contactCount = 0,
    this.reservedCount = 0,
    this.outfit = const {},
    this.outfitColors = const {},
    this.isTalking = false,
    this.lookOffsetX = 0.0,
    this.stage = 1,
    this.viewAngle = PigViewAngle.front,
  });

  @override
  State<PigioWidget> createState() => _PigioWidgetState();
}

class _PigioWidgetState extends State<PigioWidget> with SingleTickerProviderStateMixin {
  late AnimationController _blinkCtrl;
  late Animation<double> _blinkAnim;
  late Timer _blinkTimer;
  Timer? _talkTimer;
  bool _talkFrame = false;
  static final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _blinkAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut));
    _scheduleBlink();
    _updateTalkTimer();
  }

  @override
  void didUpdateWidget(covariant PigioWidget old) {
    super.didUpdateWidget(old);
    if (old.isTalking != widget.isTalking) _updateTalkTimer();
  }

  void _updateTalkTimer() {
    _talkTimer?.cancel();
    if (widget.isTalking) {
      _talkTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
        if (mounted) setState(() => _talkFrame = !_talkFrame);
      });
    } else {
      _talkFrame = false;
    }
  }

  void _scheduleBlink() {
    final delay = Duration(milliseconds: 2500 + _rng.nextInt(4000));
    _blinkTimer = Timer(delay, () {
      if (mounted) {
        _blinkCtrl.forward(from: 0.0);
        _scheduleBlink();
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer.cancel();
    _talkTimer?.cancel();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blinkAnim,
      builder: (context, child) {
        final skipBlink = widget.mood == PigMood.excited ||
            widget.mood == PigMood.celebrating ||
            widget.mood == PigMood.love ||
            widget.mood == PigMood.sleeping;
        return SizedBox(
          width: widget.size,
          height: widget.size * 1.3,
          child: CustomPaint(
            painter: PigioPainter(
              mood: widget.mood,
              pose: widget.pose,
              weatherCondition: widget.weatherCondition,
              weatherExposure: widget.weatherExposure,
              weatherIsDay: widget.weatherIsDay,
              weatherTemperature: widget.weatherTemperature,
              scarfColor: widget.scarfColor,
              contactCount: widget.contactCount,
              reservedCount: widget.reservedCount,
              outfit: widget.outfit,
              outfitColors: widget.outfitColors,
              blinkPhase: skipBlink ? 0.0 : _blinkAnim.value,
              isTalking: _talkFrame,
              lookOffsetX: widget.lookOffsetX,
              stage: widget.stage,
              viewAngle: widget.viewAngle,
              currentMonth: DateTime.now().month,
            ),
          ),
        );
      },
    );
  }
}
