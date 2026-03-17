import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/shared/widgets/pigio_painter.dart';
import 'mascot_outfit_engine.dart';

/// Service for generating and sharing Pigio achievement cards.
class MascotShareService {
  MascotShareService._();

  /// Generate a shareable achievement card image and open the share sheet.
  /// [itemId] is the newly unlocked clothing item.
  /// [context] is needed for theme colors.
  static Future<void> shareAchievementCard({
    required BuildContext context,
    required String itemId,
    required PigioAppState state,
  }) async {
    final item = MascotOutfitEngine.getItem(itemId);
    if (item == null) return;

    final isFr = state.locale.languageCode == 'fr';
    final bondTitle = state.mascotBondTitle;
    final bondEmoji = state.mascotBondEmoji;

    // Render the card
    final imageBytes = await _renderCard(
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

  /// Render a 600x800 achievement card as PNG bytes.
  static Future<Uint8List?> _renderCard({
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
    const double w = 600;
    const double h = 800;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

    // Background gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
      ).createShader(const Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, w, h), const Radius.circular(32)),
      bgPaint,
    );

    // Decorative circles
    canvas.drawCircle(
      const Offset(500, 120),
      180,
      Paint()..color = const Color(0xFF9C6FE3).withValues(alpha: 0.08),
    );
    canvas.drawCircle(
      const Offset(100, 650),
      140,
      Paint()..color = const Color(0xFF4A6FE3).withValues(alpha: 0.06),
    );

    // Title: "ACHIEVEMENT UNLOCKED"
    final titlePainter = TextPainter(
      text: const TextSpan(
        text: 'ACHIEVEMENT UNLOCKED',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titlePainter.paint(canvas, Offset((w - titlePainter.width) / 2, 50));

    // Pigio mascot (rendered via PigioPainter)
    canvas.save();
    canvas.translate((w - 250) / 2, 100);
    final pigioPainter = PigioPainter(
      mood: PigMood.celebrating,
      outfit: outfit,
      outfitColors: outfitColors,
      scarfColor: scarfColor,
    );
    pigioPainter.paint(canvas, const Size(250, 325));
    canvas.restore();

    // Item emoji + name
    final emojiPainter = TextPainter(
      text: TextSpan(
        text: itemEmoji,
        style: const TextStyle(fontSize: 56),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emojiPainter.paint(canvas, Offset((w - emojiPainter.width) / 2, 450));

    final namePainter = TextPainter(
      text: TextSpan(
        text: itemName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    namePainter.paint(canvas, Offset((w - namePainter.width) / 2, 520));

    // Rarity badge
    final rarityRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(w / 2, 575), width: 140, height: 32),
      const Radius.circular(16),
    );
    canvas.drawRRect(rarityRect, Paint()..color = rarityColor);
    final rarityPainter = TextPainter(
      text: TextSpan(
        text: rarityName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rarityPainter.paint(canvas, Offset((w - rarityPainter.width) / 2, 567));

    // Bond level
    final bondPainter = TextPainter(
      text: TextSpan(
        text: '$bondEmoji $bondTitle',
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    bondPainter.paint(canvas, Offset((w - bondPainter.width) / 2, 620));

    // Watermark
    final watermarkPainter = TextPainter(
      text: const TextSpan(
        text: 'pigio.app',
        style: TextStyle(
          color: Colors.white24,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    watermarkPainter.paint(canvas, Offset((w - watermarkPainter.width) / 2, 750));

    // Convert to PNG
    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}
