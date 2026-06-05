import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/shared/widgets/pigio_painter.dart';
import 'mascot_outfit_engine.dart';

/// Share card format with optimized dimensions for each platform.
enum ShareFormat {
  story(1080, 1920, 'Story'),
  square(1080, 1080, 'Carré'),
  card(600, 800, 'Carte');

  const ShareFormat(this.width, this.height, this.label);
  final int width;
  final int height;
  final String label;

  double get w => width.toDouble();
  double get h => height.toDouble();
}

/// Service for generating and sharing Pigio achievement cards.
class MascotShareService {
  MascotShareService._();

  /// Generate a shareable achievement card image and open the share sheet.
  /// [itemId] is the newly unlocked clothing item.
  /// [format] controls the output dimensions.
  static Future<void> shareAchievementCard({
    required BuildContext context,
    required String itemId,
    required PigioAppState state,
    ShareFormat format = ShareFormat.card,
  }) async {
    final item = MascotOutfitEngine.getItem(itemId);
    if (item == null) return;

    final isFr = state.locale.languageCode == 'fr';
    final bondTitle = state.mascotBondTitle;
    final bondEmoji = state.mascotBondEmoji;

    // Render the card
    final imageBytes = await _renderCard(
      format: format,
      outfit: state.activeOutfit,
      outfitColors: state.outfitColors,
      scarfColor: state.mascotScarfColor,
      itemEmoji: item.emoji,
      itemName: isFr ? item.name : item.name, // Clothing names are in French by design
      rarityName: item.rarity.name.toUpperCase(),
      rarityColor: _rarityColor(item.rarity),
      bondTitle: bondTitle,
      bondEmoji: bondEmoji,
    );

    if (imageBytes == null) return;

    final text = isFr
        ? 'Mon Pigio a débloqué ${item.emoji} ${item.name} ! $bondEmoji Rejoins Pigio pour créer ta liste de cadeaux.'
        : 'My Pigio unlocked ${item.emoji} ${item.name}! $bondEmoji Join Pigio to create your gift wishlist.';

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(imageBytes, mimeType: 'image/png', name: 'pigio_achievement.png')],
        text: text,
      ),
    );
  }

  /// Share the current outfit as a card image (social feed / outfit comparison).
  static Future<void> shareOutfitCard({
    required BuildContext context,
    required PigioAppState state,
    ShareFormat format = ShareFormat.square,
  }) async {
    final isFr = state.locale.languageCode == 'fr';
    final equippedItems = state.activeOutfit.entries
        .where((e) => e.value != null)
        .map((e) => MascotOutfitEngine.getItem(e.value!))
        .whereType<ClothingItem>()
        .toList();
    final emojis = equippedItems.map((i) => i.emoji).join(' ');

    final imageBytes = await _renderOutfitCard(
      format: format,
      outfit: state.activeOutfit,
      outfitColors: state.outfitColors,
      scarfColor: state.mascotScarfColor,
      userName: state.profile.firstName,
      equippedEmojis: emojis,
      stage: state.mascotStage,
    );
    if (imageBytes == null) return;

    final text = isFr
        ? 'Voici mon look Pigio du jour ! $emojis Rejoins Pigio.'
        : 'Here\'s my Pigio look of the day! $emojis Join Pigio.';

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(imageBytes, mimeType: 'image/png', name: 'pigio_outfit.png')],
        text: text,
      ),
    );
  }

  /// Render an outfit showcase card.
  static Future<Uint8List?> _renderOutfitCard({
    required ShareFormat format,
    required Map<ClothingSlot, String?> outfit,
    required Map<String, int> outfitColors,
    required Color scarfColor,
    required String userName,
    required String equippedEmojis,
    int stage = 1,
  }) async {
    final double w = format.w;
    final double h = format.h;
    final double s = w / 600;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // Background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Decorative circles
    canvas.drawCircle(Offset(w * 0.85, h * 0.12), 160 * s, Paint()..color = Colors.white.withValues(alpha: 0.05));
    canvas.drawCircle(Offset(w * 0.15, h * 0.85), 120 * s, Paint()..color = Colors.white.withValues(alpha: 0.04));

    final double yBase = format == ShareFormat.story ? (h - 800 * s) / 2 : 0;

    // Title
    final titlePainter = TextPainter(
      text: TextSpan(
        text: userName.isEmpty ? 'MY PIGIO LOOK' : '${userName.toUpperCase()}\'S PIGIO',
        style: TextStyle(color: Colors.white70, fontSize: 16 * s, fontWeight: FontWeight.w900, letterSpacing: 4 * s),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titlePainter.paint(canvas, Offset((w - titlePainter.width) / 2, yBase + 40 * s));

    // Mascot
    final mascotW = 280 * s;
    final mascotH = 364 * s;
    canvas.save();
    canvas.translate((w - mascotW) / 2, yBase + 90 * s);
    PigioPainter(
      mood: PigMood.thumbsUp,
      outfit: outfit,
      outfitColors: outfitColors,
      scarfColor: scarfColor,
      stage: stage,
    ).paint(canvas, Size(mascotW, mascotH));
    canvas.restore();

    // Equipped items row
    if (equippedEmojis.isNotEmpty) {
      final emojiPainter = TextPainter(
        text: TextSpan(text: equippedEmojis, style: TextStyle(fontSize: 32 * s)),
        textDirection: TextDirection.ltr,
      )..layout();
      emojiPainter.paint(canvas, Offset((w - emojiPainter.width) / 2, yBase + 490 * s));
    }

    // Watermark
    final watermark = TextPainter(
      text: TextSpan(
        text: 'pigio.app',
        style: TextStyle(color: Colors.white24, fontSize: 14 * s, fontWeight: FontWeight.w700, letterSpacing: 2 * s),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    watermark.paint(canvas, Offset((w - watermark.width) / 2, h - 50 * s));

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  static Color _rarityColor(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common:
        return const Color(0xFF8B90B0);
      case ItemRarity.uncommon:
        return const Color(0xFF4A6FE3);
      case ItemRarity.rare:
        return const Color(0xFF9C6FE3);
      case ItemRarity.legendary:
        return const Color(0xFFFFAA00);
    }
  }

  /// Render an achievement card as PNG bytes, scaled to [format] dimensions.
  static Future<Uint8List?> _renderCard({
    ShareFormat format = ShareFormat.card,
    required Map<ClothingSlot, String?> outfit,
    required Map<String, int> outfitColors,
    required Color scarfColor,
    required String itemEmoji,
    required String itemName,
    required String rarityName,
    required Color rarityColor,
    required String bondTitle,
    required String bondEmoji,
  }) async {
    final double w = format.w;
    final double h = format.h;
    // Scale factor relative to the base 600x800 card.
    final double s = w / 600;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // Background gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(32 * s)),
      bgPaint,
    );

    // Decorative circles
    canvas.drawCircle(
      Offset(w * 0.83, h * 0.15),
      180 * s,
      Paint()..color = const Color(0xFF9C6FE3).withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      Offset(w * 0.17, h * 0.81),
      140 * s,
      Paint()..color = const Color(0xFF4A6FE3).withValues(alpha: 0.06),
    );

    // Vertical center offset — for story format push content towards center.
    final double yBase = format == ShareFormat.story ? (h - 800 * s) / 2 : 0;

    // Title: "ACHIEVEMENT UNLOCKED"
    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'ACHIEVEMENT UNLOCKED',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 16 * s,
          fontWeight: FontWeight.w900,
          letterSpacing: 4 * s,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titlePainter.paint(canvas, Offset((w - titlePainter.width) / 2, yBase + 50 * s));

    // Pigio mascot (rendered via PigioPainter)
    final mascotW = 250 * s;
    final mascotH = 325 * s;
    canvas.save();
    canvas.translate((w - mascotW) / 2, yBase + 100 * s);
    final pigioPainter = PigioPainter(
      mood: PigMood.celebrating,
      outfit: outfit,
      outfitColors: outfitColors,
      scarfColor: scarfColor,
    );
    pigioPainter.paint(canvas, Size(mascotW, mascotH));
    canvas.restore();

    // Item emoji + name
    final emojiPainter = TextPainter(
      text: TextSpan(
        text: itemEmoji,
        style: TextStyle(fontSize: 56 * s),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emojiPainter.paint(canvas, Offset((w - emojiPainter.width) / 2, yBase + 450 * s));

    final namePainter = TextPainter(
      text: TextSpan(
        text: itemName,
        style: TextStyle(
          color: Colors.white,
          fontSize: 28 * s,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    namePainter.paint(canvas, Offset((w - namePainter.width) / 2, yBase + 520 * s));

    // Rarity badge
    final rarityRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, yBase + 575 * s), width: 140 * s, height: 32 * s),
      Radius.circular(16 * s),
    );
    canvas.drawRRect(rarityRect, Paint()..color = rarityColor);
    final rarityPainter = TextPainter(
      text: TextSpan(
        text: rarityName,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13 * s,
          fontWeight: FontWeight.w900,
          letterSpacing: 2 * s,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rarityPainter.paint(canvas, Offset((w - rarityPainter.width) / 2, yBase + 567 * s));

    // Bond level
    final bondPainter = TextPainter(
      text: TextSpan(
        text: '$bondEmoji $bondTitle',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 18 * s,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    bondPainter.paint(canvas, Offset((w - bondPainter.width) / 2, yBase + 620 * s));

    // Watermark — always anchored near the bottom of the canvas.
    final watermarkPainter = TextPainter(
      text: TextSpan(
        text: 'pigio.app',
        style: TextStyle(
          color: Colors.white24,
          fontSize: 14 * s,
          fontWeight: FontWeight.w700,
          letterSpacing: 2 * s,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    watermarkPainter.paint(canvas, Offset((w - watermarkPainter.width) / 2, h - 50 * s));

    // Convert to PNG
    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}
