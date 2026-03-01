import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pigio_app/core/state/app_state.dart';

enum PigMood { normal, excited, waving, thumbsUp, thinking, sad, embarrassed, searching, celebrating, love }

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
  final Color scarfColor;
  final int contactCount;
  final int reservedCount;
  final Map<ClothingSlot, String?> outfit;

  static final Map<String, Shader> _shaderCache = {};

  PigioPainter({
    this.mood = PigMood.normal,
    this.scarfColor = const Color(0xFFF7C427),
    this.contactCount = 0,
    this.reservedCount = 0,
    this.outfit = const {},
  });

  Shader _getCachedShader(String key, Rect bounds, Gradient gradient) {
    return _shaderCache.putIfAbsent(key, () => gradient.createShader(bounds));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Shift slightly down so hat elements don't clip the widget top boundary.
    // All coordinates below are in this translated space (effective y-origin is 5 units
    // below the widget top). SVG overlays are NOT used — all clothing is drawn here so
    // coordinates are always in the same space as the mascot body.
    canvas.translate(0, 5);

    final hatId = outfit[ClothingSlot.hat];
    final glassesId = outfit[ClothingSlot.glasses];
    final topId = outfit[ClothingSlot.top];
    final shoesId = outfit[ClothingSlot.shoes];
    final accId = outfit[ClothingSlot.accessory];

    // 1. Ground shadow
    canvas.drawOval(
      const Rect.fromLTWH(20, 115, 60, 10),
      Paint()
        ..color = Colors.black12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // 2. Back wings (raised — drawn behind body)
    if (mood == PigMood.excited || mood == PigMood.celebrating) {
      _drawRaisedWing(canvas, true);
      _drawRaisedWing(canvas, false);
    } else if (mood == PigMood.waving) {
      _drawRaisedWing(canvas, false);
    }

    // 3. Feet (then shoes on top)
    _drawFeet(canvas);
    if (shoesId != null) _drawShoes(canvas, shoesId);

    // 4. Body (then top on top)
    _drawBody(canvas);
    if (topId != null) _drawTop(canvas, topId);

    // 5. Head
    _drawHead(canvas);

    // 6. Scarf — skip default if thick scarf top is equipped (it draws its own)
    if (topId != 'top_scarf_thick') _drawScarf(canvas);

    // 7. Face
    _drawFace(canvas, mood);

    // 8. Glasses (outfit takes priority over seasonal sunglasses)
    if (glassesId != null) {
      _drawGlasses(canvas, glassesId);
    }

    // 9. Front wings
    if (mood == PigMood.normal || mood == PigMood.sad || mood == PigMood.love) {
      _drawRestWing(canvas, true);
      _drawRestWing(canvas, false);
    } else if (mood == PigMood.waving) {
      _drawRestWing(canvas, true);
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

    // 10. Hat (outfit → party hat for celebrating → seasonal)
    if (mood == PigMood.celebrating) {
      _drawPartyHat(canvas);
    } else if (hatId != null) {
      _drawHat(canvas, hatId);
    }

    // 11. Seasonal extras that outfit doesn't replace
    _drawSeasonalFiltered(canvas, hasHat: hatId != null, hasGlasses: glassesId != null);

    // 12. Held accessory (drawn after wings so it appears in front)
    if (accId != null) _drawAccessory(canvas, accId);

    if (mood == PigMood.love) _drawHearts(canvas);

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
    final hsl = HSLColor.fromColor(scarfColor);
    final highlight = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    final shadow = hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0)).toColor();

    final wrapPath = Path()
      ..moveTo(18, 50)
      ..quadraticBezierTo(50, 66, 82, 50)
      ..lineTo(80, 62)
      ..quadraticBezierTo(50, 78, 20, 62)
      ..close();

    canvas.drawPath(wrapPath.shift(const Offset(0, 3)), Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    fill.shader = _getCachedShader('scarf_wrap_${scarfColor.toARGB32()}', wrapPath.getBounds(), LinearGradient(
      colors: [highlight, scarfColor, shadow],
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
    fill.shader = _getCachedShader('scarf_tail_${scarfColor.toARGB32()}_$tailLength', tailPath.getBounds(), LinearGradient(
      colors: [scarfColor, shadow],
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
    bool beakOpen = (mood == PigMood.excited || mood == PigMood.waving || mood == PigMood.celebrating);

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

    const radius = 9.5;
    canvas.drawCircle(Offset(cx, cy + 1), radius, Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));

    final eyeRect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    canvas.drawCircle(Offset(cx, cy), radius, Paint()..shader = _getCachedShader(
      'eye_white_${cx}_$cy', eyeRect, const RadialGradient(
        colors: [_ClayColors.eyeWhite, _ClayColors.eyeShadow],
        center: Alignment(-0.3, -0.3), radius: 0.9,
      )
    ));

    double px = cx, py = cy + 1;
    if (state == "look_up") { py = cy - 2; px = isLeft ? cx + 1 : cx - 1; }
    canvas.drawCircle(Offset(px, py), 3.5, Paint()..color = _ClayColors.pupil);
    canvas.drawCircle(Offset(px - 1.5, py - 1.5), 1.2, Paint()..color = Colors.white);

    if (state == "half_open") {
      final lidPath = Path()
        ..moveTo(cx - radius - 1, cy - radius)
        ..lineTo(cx + radius + 1, cy - radius)
        ..lineTo(cx + radius + 1, cy + 1)
        ..lineTo(cx - radius - 1, cy + 1)..close();
      canvas.drawPath(lidPath, Paint()..shader = _getCachedShader(
        'eye_lid_${state}_${cx}_$cy', lidPath.getBounds(), const LinearGradient(
          colors: [_ClayColors.blueMain, _ClayColors.blueShadow], begin: Alignment.topCenter, end: Alignment.bottomCenter,
        )
      ));
      canvas.drawLine(Offset(cx - radius, cy + 1), Offset(cx + radius, cy + 1), Paint()..color = _ClayColors.blueShadow..strokeWidth = 2);
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
    final hat = Path()..moveTo(50, -2)..lineTo(38, 20)..quadraticBezierTo(50, 24, 62, 20)..close();
    canvas.drawPath(hat, Paint()..shader = _getCachedShader('party_hat', hat.getBounds(), const LinearGradient(colors: [Color(0xFFFF528A), Color(0xFFE01C5E)])));
    canvas.drawPath(Path()..moveTo(43, 8)..lineTo(56, 5)..lineTo(58, 12)..lineTo(41, 15)..close(), Paint()..color = const Color(0xFFFFD13B));
    canvas.drawCircle(const Offset(50, -2), 5, Paint()..color = const Color(0xFFFFD13B));

    final colors = [Colors.greenAccent, Colors.purpleAccent, Colors.yellowAccent, Colors.blueAccent];
    final offsets = [const Offset(20, 10), const Offset(80, 15), const Offset(15, 35), const Offset(85, 30)];
    for (int i = 0; i < offsets.length; i++) {
      canvas.drawRect(Rect.fromCenter(center: offsets[i], width: 4, height: 6), Paint()..color = colors[i]);
    }
  }

  // ─────────────────── SEASONAL (filtered by outfit) ───────────────────

  void _drawSeasonalFiltered(Canvas canvas, {required bool hasHat, required bool hasGlasses}) {
    final month = DateTime.now().month;
    if (!hasHat && month == 12) {
      final hatPath = Path()..moveTo(50, -5)..lineTo(36, 18)..quadraticBezierTo(50, 24, 64, 18)..close();
      canvas.drawPath(hatPath, Paint()..shader = _getCachedShader('santa_hat', hatPath.getBounds(), const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFC62828)], begin: Alignment.topCenter, end: Alignment.bottomCenter)));
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(33, 16, 34, 8), const Radius.circular(4)), Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(40, -5), 6, Paint()..color = Colors.white);
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
    switch (id) {
      case 'hat_winter': _drawWinterBeanie(canvas); break;
      case 'hat_straw': _drawStrawHat(canvas); break;
      case 'hat_birthday': _drawCrown(canvas); break;
      case 'hat_santa':
        final hatPath = Path()..moveTo(50, -5)..lineTo(36, 18)..quadraticBezierTo(50, 24, 64, 18)..close();
        canvas.drawPath(hatPath, Paint()..shader = _getCachedShader('santa_hat_eq', hatPath.getBounds(), const LinearGradient(colors: [Color(0xFFE53935), Color(0xFFC62828)], begin: Alignment.topCenter, end: Alignment.bottomCenter)));
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(33, 16, 34, 8), const Radius.circular(4)), Paint()..color = Colors.white);
        canvas.drawCircle(const Offset(40, -5), 6, Paint()..color = Colors.white);
        break;
      case 'hat_witch': _drawWitchHat(canvas); break;
    }
  }

  void _drawGlasses(Canvas canvas, String id) {
    switch (id) {
      case 'glasses_sun': _drawSunglasses(canvas); break;
      case 'glasses_heart': _drawHeartGlasses(canvas); break;
      case 'glasses_reading': _drawReadingGlasses(canvas); break;
    }
  }

  void _drawTop(Canvas canvas, String id) {
    switch (id) {
      case 'top_raincoat': _drawRaincoat(canvas); break;
      case 'top_scarf_thick': _drawThickScarf(canvas); break;
      case 'top_hawaiian': _drawHawaiianShirt(canvas); break;
      case 'top_pyjama': _drawPyjama(canvas); break;
    }
  }

  void _drawShoes(Canvas canvas, String id) {
    switch (id) {
      case 'shoes_boots': _drawRainBoots(canvas); break;
      case 'shoes_flipflops': _drawFlipFlops(canvas); break;
      case 'shoes_slippers': _drawSlippers(canvas); break;
    }
  }

  void _drawAccessory(Canvas canvas, String id) {
    switch (id) {
      case 'acc_umbrella': _drawUmbrella(canvas); break;
      case 'acc_flowers': _drawBouquet(canvas); break;
      case 'acc_flag': _drawFlag(canvas); break;
      case 'acc_pumpkin': _drawPumpkin(canvas); break;
      case 'acc_star': _drawStarWand(canvas); break;
    }
  }

  // ─────────────────── HAT DRAWING ───────────────────

  void _drawWinterBeanie(Canvas canvas) {
    // Shadow
    canvas.drawPath(
      (Path()..moveTo(28, 18)..quadraticBezierTo(30, -3, 50, -6)..quadraticBezierTo(70, -3, 72, 18)..close()).shift(const Offset(0, 2)),
      Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Dome
    final dome = Path()..moveTo(28, 18)..quadraticBezierTo(30, -3, 50, -6)..quadraticBezierTo(70, -3, 72, 18)..close();
    canvas.drawPath(dome, Paint()..color = const Color(0xFF1565C0));
    // Stripe
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(28, 8, 44, 5), const Radius.circular(2)),
      Paint()..color = const Color(0xFFEF5350),
    );
    // Brim roll
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(25, 14, 50, 10), const Radius.circular(5)),
      Paint()..color = const Color(0xFF0D47A1),
    );
    // Pompom
    canvas.drawCircle(const Offset(50, -9), 7, Paint()..color = Colors.white70);
    canvas.drawCircle(const Offset(50, -9), 5, Paint()..color = Colors.white);
  }

  void _drawStrawHat(Canvas canvas) {
    const straw = Color(0xFFD4A853);
    const darkStraw = Color(0xFFA1784A);
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

  void _drawCrown(Canvas canvas) {
    const gold = Color(0xFFFFD700);
    const darkGold = Color(0xFFFFA000);
    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(28, 12, 44, 11), const Radius.circular(3)),
      Paint()..color = Colors.black12..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Base band
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(28, 10, 44, 11), const Radius.circular(3)),
      Paint()..color = darkGold,
    );
    // Crown points
    final crownPath = Path()
      ..moveTo(28, 10)
      ..lineTo(28, -2)
      ..lineTo(38, 8)
      ..lineTo(50, -8)
      ..lineTo(62, 8)
      ..lineTo(72, -2)
      ..lineTo(72, 10)
      ..close();
    canvas.drawPath(crownPath, Paint()..shader = _getCachedShader(
      'crown', crownPath.getBounds(),
      const LinearGradient(colors: [Color(0xFFFFEA00), gold, darkGold], begin: Alignment.topCenter, end: Alignment.bottomCenter),
    ));
    // Gems
    canvas.drawCircle(const Offset(50, -2), 4, Paint()..color = const Color(0xFFE53935));
    canvas.drawCircle(const Offset(50, -2), 2, Paint()..color = Colors.white54);
    canvas.drawCircle(const Offset(34, 6), 3, Paint()..color = const Color(0xFF42A5F5));
    canvas.drawCircle(const Offset(66, 6), 3, Paint()..color = const Color(0xFF66BB6A));
  }

  void _drawWitchHat(Canvas canvas) {
    const darkPurple = Color(0xFF4A148C);
    const purple = Color(0xFF7B1FA2);
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

  // ─────────────────── GLASSES DRAWING ───────────────────

  void _drawSunglasses(Canvas canvas) {
    final glassPaint = Paint()..color = const Color(0xFF1F2937);
    canvas.drawLine(const Offset(32, 26), const Offset(68, 26), Paint()..color = const Color(0xFF1F2937)..strokeWidth = 2);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 22, 16, 12), const Radius.circular(3)), glassPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(54, 22, 16, 12), const Radius.circular(3)), glassPaint);
    canvas.drawLine(const Offset(34, 24), const Offset(42, 32), Paint()..color = Colors.white24..strokeWidth = 2);
    canvas.drawLine(const Offset(58, 24), const Offset(66, 32), Paint()..color = Colors.white24..strokeWidth = 2);
    // Temples
    canvas.drawLine(const Offset(30, 26), const Offset(22, 28), Paint()..color = const Color(0xFF1F2937)..strokeWidth = 2);
    canvas.drawLine(const Offset(70, 26), const Offset(78, 28), Paint()..color = const Color(0xFF1F2937)..strokeWidth = 2);
  }

  void _drawHeartGlasses(Canvas canvas) {
    const pink = Color(0xFFE91E63);
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

  void _drawReadingGlasses(Canvas canvas) {
    const brown = Color(0xFF795548);
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

  void _drawRaincoat(Canvas canvas) {
    const yellow = Color(0xFFFFEB3B);
    const darkYellow = Color(0xFFF9A825);
    final bodyPath = Path()
      ..moveTo(18, 58)
      ..quadraticBezierTo(18, 46, 50, 46)
      ..quadraticBezierTo(82, 46, 82, 58)
      ..lineTo(82, 110)
      ..quadraticBezierTo(82, 114, 68, 114)
      ..lineTo(32, 114)
      ..quadraticBezierTo(18, 114, 18, 110)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = yellow);
    // V-collar
    canvas.drawPath(
      Path()..moveTo(44, 46)..lineTo(50, 60)..lineTo(56, 46)..close(),
      Paint()..color = darkYellow,
    );
    // Buttons
    for (double y = 68; y <= 102; y += 12) {
      canvas.drawCircle(Offset(50, y), 2.5, Paint()..color = darkYellow);
    }
  }

  void _drawThickScarf(Canvas canvas) {
    // This replaces the default scarf visually (paint() already skips _drawScarf when this is equipped)
    const scarfColor = Color(0xFFEF5350);
    const darkScarf = Color(0xFFC62828);
    final wrapPath = Path()
      ..moveTo(17, 47)
      ..quadraticBezierTo(50, 65, 83, 47)
      ..lineTo(83, 67)
      ..quadraticBezierTo(50, 85, 17, 67)
      ..close();
    canvas.drawPath(wrapPath, Paint()..color = scarfColor);
    // Cable knit
    final linePaint = Paint()..color = darkScarf..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    for (double x = 24; x <= 76; x += 8) {
      double yBase = 50 + (x - 50).abs() * 0.18;
      canvas.drawLine(Offset(x, yBase), Offset(x, yBase + 14), linePaint);
    }
    // Dangling tail
    canvas.drawPath(
      Path()..moveTo(22, 60)..lineTo(36, 66)..lineTo(30, 94)..lineTo(17, 90)..close(),
      Paint()..color = scarfColor,
    );
  }

  void _drawHawaiianShirt(Canvas canvas) {
    const teal = Color(0xFF26C6DA);
    const darkTeal = Color(0xFF00ACC1);
    final bodyPath = Path()
      ..moveTo(18, 58)
      ..quadraticBezierTo(18, 46, 50, 46)
      ..quadraticBezierTo(82, 46, 82, 58)
      ..lineTo(82, 110)
      ..quadraticBezierTo(82, 114, 68, 114)
      ..lineTo(32, 114)
      ..quadraticBezierTo(18, 114, 18, 110)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = teal);
    // V-collar
    canvas.drawPath(Path()..moveTo(43, 46)..lineTo(50, 60)..lineTo(57, 46)..close(), Paint()..color = darkTeal);
    // Flowers
    final fp = Paint()..color = Colors.orangeAccent.withValues(alpha: 0.9);
    for (final c in [const Offset(30, 72), const Offset(66, 70), const Offset(36, 97), const Offset(64, 98)]) {
      canvas.drawCircle(c, 5, fp);
      canvas.drawCircle(Offset(c.dx - 7, c.dy), 3.5, fp);
      canvas.drawCircle(Offset(c.dx + 7, c.dy), 3.5, fp);
      canvas.drawCircle(Offset(c.dx, c.dy - 7), 3.5, fp);
      canvas.drawCircle(Offset(c.dx, c.dy + 7), 3.5, fp);
      canvas.drawCircle(c, 3, Paint()..color = Colors.amber);
    }
  }

  void _drawPyjama(Canvas canvas) {
    const blue = Color(0xFF5C6BC0);
    const stripe = Color(0xFF7986CB);
    final bodyPath = Path()
      ..moveTo(18, 58)
      ..quadraticBezierTo(18, 46, 50, 46)
      ..quadraticBezierTo(82, 46, 82, 58)
      ..lineTo(82, 110)
      ..quadraticBezierTo(82, 114, 68, 114)
      ..lineTo(32, 114)
      ..quadraticBezierTo(18, 114, 18, 110)
      ..close();
    canvas.drawPath(bodyPath, Paint()..color = blue);
    // Stripes — clip to body shape
    canvas.save();
    canvas.clipPath(bodyPath);
    final stripePaint = Paint()..color = stripe..strokeWidth = 4;
    for (double y = 52; y <= 110; y += 10) {
      canvas.drawLine(Offset(18, y), Offset(82, y), stripePaint);
    }
    canvas.restore();
    // Button placket
    canvas.drawLine(const Offset(50, 46), const Offset(50, 110), Paint()..color = const Color(0xFF3949AB)..strokeWidth = 2);
    for (double y = 60; y <= 100; y += 14) {
      canvas.drawCircle(Offset(50, y), 2.5, Paint()..color = const Color(0xFF3949AB));
    }
  }

  // ─────────────────── SHOES DRAWING ───────────────────

  void _drawRainBoots(Canvas canvas) {
    const bootColor = Color(0xFFEF5350);
    const bootDark = Color(0xFFC62828);
    // Left boot
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(27, 100, 16, 22), const Radius.circular(5)), Paint()..color = bootColor);
    canvas.drawOval(const Rect.fromLTWH(24, 115, 22, 10), Paint()..color = bootColor);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(27, 100, 16, 6), const Radius.circular(5)), Paint()..color = bootDark);
    // Right boot
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(57, 100, 16, 22), const Radius.circular(5)), Paint()..color = bootColor);
    canvas.drawOval(const Rect.fromLTWH(54, 115, 22, 10), Paint()..color = bootColor);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(57, 100, 16, 6), const Radius.circular(5)), Paint()..color = bootDark);
  }

  void _drawFlipFlops(Canvas canvas) {
    const flip = Color(0xFF42A5F5);
    final solePaint = Paint()..color = flip.withValues(alpha: 0.55);
    final strapPaint = Paint()..color = flip..strokeWidth = 3.5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    // Left
    canvas.drawOval(const Rect.fromLTWH(25, 112, 22, 8), solePaint);
    canvas.drawLine(const Offset(36, 112), const Offset(30, 107), strapPaint);
    canvas.drawLine(const Offset(36, 112), const Offset(42, 107), strapPaint);
    // Right
    canvas.drawOval(const Rect.fromLTWH(53, 112, 22, 8), solePaint);
    canvas.drawLine(const Offset(64, 112), const Offset(58, 107), strapPaint);
    canvas.drawLine(const Offset(64, 112), const Offset(70, 107), strapPaint);
  }

  void _drawSlippers(Canvas canvas) {
    const pink = Color(0xFFF48FB1);
    const darkPink = Color(0xFFE91E63);
    // Left slipper
    canvas.drawOval(const Rect.fromLTWH(24, 108, 24, 14), Paint()..color = pink);
    canvas.drawOval(const Rect.fromLTWH(27, 98, 5, 12), Paint()..color = pink);
    canvas.drawOval(const Rect.fromLTWH(34, 98, 5, 12), Paint()..color = pink);
    canvas.drawOval(const Rect.fromLTWH(28, 100, 3, 8), Paint()..color = darkPink);
    canvas.drawOval(const Rect.fromLTWH(35, 100, 3, 8), Paint()..color = darkPink);
    canvas.drawCircle(const Offset(32, 113), 1.5, Paint()..color = Colors.black38);
    canvas.drawCircle(const Offset(36, 113), 1.5, Paint()..color = Colors.black38);
    // Right slipper
    canvas.drawOval(const Rect.fromLTWH(52, 108, 24, 14), Paint()..color = pink);
    canvas.drawOval(const Rect.fromLTWH(55, 98, 5, 12), Paint()..color = pink);
    canvas.drawOval(const Rect.fromLTWH(62, 98, 5, 12), Paint()..color = pink);
    canvas.drawOval(const Rect.fromLTWH(56, 100, 3, 8), Paint()..color = darkPink);
    canvas.drawOval(const Rect.fromLTWH(63, 100, 3, 8), Paint()..color = darkPink);
    canvas.drawCircle(const Offset(60, 113), 1.5, Paint()..color = Colors.black38);
    canvas.drawCircle(const Offset(64, 113), 1.5, Paint()..color = Colors.black38);
  }

  // ─────────────────── ACCESSORY DRAWING ───────────────────

  void _drawUmbrella(Canvas canvas) {
    // Pole
    canvas.drawLine(const Offset(82, 98), const Offset(82, 46), Paint()..color = const Color(0xFF424242)..strokeWidth = 3..strokeCap = StrokeCap.round);
    // Hook at bottom
    canvas.drawArc(const Rect.fromLTWH(78, 94, 8, 8), 0, 3.14159, false,
        Paint()..color = const Color(0xFF424242)..style = PaintingStyle.stroke..strokeWidth = 3);
    // Dome
    canvas.drawArc(const Rect.fromLTWH(64, 32, 36, 20), 3.14159, 3.14159, true, Paint()..color = const Color(0xFFEF5350));
    // Ribs
    final ribPaint = Paint()..color = const Color(0xFFC62828)..strokeWidth = 1;
    for (final tip in [const Offset(64, 52), const Offset(73, 54), const Offset(82, 52), const Offset(91, 54), const Offset(100, 52)]) {
      canvas.drawLine(const Offset(82, 42), tip, ribPaint);
    }
  }

  void _drawBouquet(Canvas canvas) {
    final stemPaint = Paint()..color = const Color(0xFF4CAF50)..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(80, 92), const Offset(74, 72), stemPaint);
    canvas.drawLine(const Offset(80, 92), const Offset(80, 68), stemPaint);
    canvas.drawLine(const Offset(80, 92), const Offset(86, 72), stemPaint);
    canvas.drawOval(const Rect.fromLTWH(76, 80, 8, 5), Paint()..color = const Color(0xFF388E3C));
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

  void _drawPumpkin(Canvas canvas) {
    const orange = Color(0xFFFF8F00);
    const darkOrange = Color(0xFFE65100);
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

  void _drawStarWand(Canvas canvas) {
    canvas.drawLine(const Offset(86, 97), const Offset(74, 50),
        Paint()..color = const Color(0xFFD4A853)..strokeWidth = 3.5..strokeCap = StrokeCap.round);
    _drawStarShape(canvas, const Offset(70, 46), 13, Paint()..color = const Color(0xFFFFD700));
    _drawStarShape(canvas, const Offset(70, 46), 13,
        Paint()..color = const Color(0xFFFFA000)..style = PaintingStyle.stroke..strokeWidth = 1.5);
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

  @override
  bool shouldRepaint(covariant PigioPainter oldDelegate) =>
      oldDelegate.mood != mood ||
      oldDelegate.scarfColor != scarfColor ||
      oldDelegate.contactCount != contactCount ||
      oldDelegate.reservedCount != reservedCount ||
      !_outfitsEqual(oldDelegate.outfit, outfit);

  static bool _outfitsEqual(Map<ClothingSlot, String?> a, Map<ClothingSlot, String?> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

class PigioWidget extends StatelessWidget {
  final PigMood mood;
  final double size;
  final Color scarfColor;
  final int contactCount;
  final int reservedCount;
  final Map<ClothingSlot, String?> outfit;

  const PigioWidget({
    super.key,
    this.mood = PigMood.normal,
    this.size = 100,
    this.scarfColor = const Color(0xFFF7C427),
    this.contactCount = 0,
    this.reservedCount = 0,
    this.outfit = const {},
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.3,
      child: CustomPaint(
        painter: PigioPainter(
          mood: mood,
          scarfColor: scarfColor,
          contactCount: contactCount,
          reservedCount: reservedCount,
          outfit: outfit,
        ),
      ),
    );
  }
}
