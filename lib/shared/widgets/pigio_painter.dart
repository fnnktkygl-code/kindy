import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pigio_app/core/state/app_state.dart';

enum PigMood { normal, excited, waving, thumbsUp, thinking, sad, embarrassed, searching, celebrating, love, sleeping, dizzy }
enum PigPose { normal, coldTucked, sunRelaxed, umbrellaBrace }

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

class PigioPainter extends CustomPainter {
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

  final int currentMonth;

  static final Map<String, Shader> _shaderCache = {};
  static final List<String> _shaderLruKeys = []; // P4: LRU eviction order
  static const int _shaderCacheMax = 50;

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
    int? currentMonth,
  }) : currentMonth = currentMonth ?? DateTime.now().month;

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

    final hatId = outfit[ClothingSlot.hat];
    final glassesId = outfit[ClothingSlot.glasses];
    final topId = outfit[ClothingSlot.top];
    final shoesId = outfit[ClothingSlot.shoes];
    final accId = outfit[ClothingSlot.accessory];
    final bool hasTop = topId != null;
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

    // ── 2. Back raised wings (behind body) ──
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

    // ── 8. Scarf — skip when ANY top is equipped ──
    if (!hasTop) _drawScarf(canvas);

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
    final fill = Paint()
      ..shader = _getCachedShader('body', bodyRect, const RadialGradient(
        colors: [_ClayColors.blueHighlight, _ClayColors.blueMain, _ClayColors.blueShadow],
        center: Alignment(-0.3, -0.4),
        radius: 0.8,
      ));
    canvas.drawOval(bodyRect, fill);

    final bellyRect = const Rect.fromLTWH(28, 55, 44, 52);
    final bellyFill = Paint()
      ..shader = _getCachedShader('belly', bellyRect, const RadialGradient(
        colors: [_ClayColors.bellyHighlight, _ClayColors.bellyMain],
        center: Alignment(-0.2, -0.2),
        radius: 0.7,
      ));
    canvas.drawOval(bellyRect, bellyFill);
  }

  void _drawHead(Canvas canvas) {
    final headRect = const Rect.fromLTWH(25, 8, 50, 52);
    final fill = Paint()
      ..shader = _getCachedShader('head', headRect, const RadialGradient(
        colors: [_ClayColors.blueHighlight, _ClayColors.blueMain, _ClayColors.blueShadow],
        center: Alignment(-0.3, -0.3),
        radius: 0.8,
      ));
    canvas.drawOval(headRect, fill);
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
    }
  }

  void _drawGlasses(Canvas canvas, String id) {
    final tint = outfitColors[id] != null ? Color(outfitColors[id]!) : null;
    switch (id) {
      case 'glasses_sun': _drawSunglasses(canvas, tint); break;
      case 'glasses_heart': _drawHeartGlasses(canvas, tint); break;
      case 'glasses_reading': _drawReadingGlasses(canvas, tint); break;
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
    }
  }

  void _drawShoes(Canvas canvas, String id) {
    final tint = outfitColors[id] != null ? Color(outfitColors[id]!) : null;
    switch (id) {
      case 'shoes_boots': _drawRainBoots(canvas, tint); break;
      case 'shoes_flipflops': _drawFlipFlops(canvas, tint); break;
      case 'shoes_sandals': _drawSandals(canvas, tint); break;
      case 'shoes_slippers': _drawSlippers(canvas, tint); break;
    }
  }

  void _drawAccessory(Canvas canvas, String id) {
    final tint = outfitColors[id] != null ? Color(outfitColors[id]!) : null;
    switch (id) {
      case 'acc_umbrella': _drawUmbrella(canvas, tint); break;
      case 'acc_flowers': _drawBouquet(canvas, tint); break;
      case 'acc_flag': _drawFlag(canvas); break; // Flag keeps national colors
      case 'acc_pumpkin': _drawPumpkin(canvas, tint); break;
      case 'acc_star': _drawStarWand(canvas, tint); break;
      case 'acc_egg': _drawEasterEgg(canvas, tint); break;
      case 'acc_bowtie': _drawBowtie(canvas, tint); break;
      case 'acc_cape': _drawCape(canvas, tint); break;
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
    final glassPaint = Paint()..color = c;
    canvas.drawLine(const Offset(32, 26), const Offset(68, 26), Paint()..color = c..strokeWidth = 2);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 22, 16, 12), const Radius.circular(3)), glassPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(54, 22, 16, 12), const Radius.circular(3)), glassPaint);
    canvas.drawLine(const Offset(34, 24), const Offset(42, 32), Paint()..color = Colors.white24..strokeWidth = 2);
    canvas.drawLine(const Offset(58, 24), const Offset(66, 32), Paint()..color = Colors.white24..strokeWidth = 2);
    // Temples
    canvas.drawLine(const Offset(30, 26), const Offset(22, 28), Paint()..color = c..strokeWidth = 2);
    canvas.drawLine(const Offset(70, 26), const Offset(78, 28), Paint()..color = c..strokeWidth = 2);
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

  /// Draws arms/wings with fabric-colored sleeves for the equipped top.
  /// Handles all arm positions: resting, raised, waving, thumbsUp, thinking, etc.
  void _drawArmsWithSleeves(Canvas canvas, String topId, PigMood mood, bool holdingUmbrella, {PigPose pose = PigPose.normal}) {
    // Get the top's colors
    final (Color primary, Color secondary) = _topColors(topId);
    final bool isRaised = mood == PigMood.excited || mood == PigMood.celebrating;
    final bool isWaving = mood == PigMood.waving;
    final bool isShortSleeve = topId == 'top_hawaiian' || topId == 'top_linen';

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
              currentMonth: DateTime.now().month,
            ),
          ),
        );
      },
    );
  }
}
