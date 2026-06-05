import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/shared/widgets/pigio_painter.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';
import 'package:kindy/services/mascot_share_service.dart';

const _kBackgrounds = <({String label, List<Color> colors})>[
  (label: 'Nuit', colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)]),
  (label: 'Aurore', colors: [Color(0xFFFFA17F), Color(0xFF00223E)]),
  (label: 'Forêt', colors: [Color(0xFF134E5E), Color(0xFF71B280)]),
  (label: 'Sunset', colors: [Color(0xFFe65c00), Color(0xFFF9D423)]),
  (label: 'Lavande', colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
  (label: 'Océan', colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)]),
  (label: 'Rose', colors: [Color(0xFFee9ca7), Color(0xFFffdde1)]),
  (label: 'Minuit', colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)]),
];

final _kMoods = <({String emoji, String label, PigMood mood})>[
  (emoji: '😊', label: 'Content', mood: PigMood.normal),
  (emoji: '🥳', label: 'Fête', mood: PigMood.celebrating),
  (emoji: '🤩', label: 'Excité', mood: PigMood.excited),
  (emoji: '😎', label: 'Cool', mood: PigMood.thumbsUp),
  (emoji: '💕', label: 'Amour', mood: PigMood.love),
  (emoji: '🤔', label: 'Pensif', mood: PigMood.thinking),
  (emoji: '😴', label: 'Dodo', mood: PigMood.sleeping),
  (emoji: '👋', label: 'Salut', mood: PigMood.waving),
];

class MascotPhotoboothScreen extends StatefulWidget {
  const MascotPhotoboothScreen({super.key});

  @override
  State<MascotPhotoboothScreen> createState() => _MascotPhotoboothScreenState();
}

class _MascotPhotoboothScreenState extends State<MascotPhotoboothScreen> {
  int _bgIndex = 0;
  int _moodIndex = 0;
  bool _isExporting = false;
  final _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _export(PigioAppState state, ShareFormat format) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _renderPhotobooth(
        format: format,
        background: _kBackgrounds[_bgIndex].colors,
        mood: _kMoods[_moodIndex].mood,
        outfit: state.activeOutfit,
        outfitColors: state.outfitColors,
        scarfColor: state.mascotScarfColor,
        caption: _captionController.text.trim(),
      );
      if (bytes == null) return;

      final isFr = state.locale.languageCode == 'fr';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'pigio_photobooth.png')],
          text: isFr ? 'Mon Pigio est trop stylé ! Rejoins Pigio.' : 'My Pigio is looking amazing! Join Pigio.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final bg = _kBackgrounds[_bgIndex];
    final mood = _kMoods[_moodIndex];

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: PigioAppBar(title: 'Photobooth', showNotification: false),
      body: Column(
        children: [
          // Preview
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: bg.colors,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PigioWidget(
                        mood: mood.mood,
                        outfit: state.activeOutfit,
                        outfitColors: state.outfitColors,
                        scarfColor: state.mascotScarfColor,
                      ),
                      if (_captionController.text.trim().isNotEmpty)
                        Positioned(
                          bottom: 32,
                          left: 16,
                          right: 16,
                          child: Text(
                            _captionController.text.trim(),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: fw(size: 16, w: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                          ),
                        ),
                      Positioned(
                        bottom: 12,
                        right: 16,
                        child: Text(
                          'pigio.app',
                          style: fw(size: 12, w: FontWeight.w700, color: Colors.white24, letterSpacing: 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Background picker
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kBackgrounds.length,
              itemBuilder: (_, i) {
                final isSelected = i == _bgIndex;
                return GestureDetector(
                  onTap: () => setState(() => _bgIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: _kBackgrounds[i].colors),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: _kBackgrounds[i].colors.first.withValues(alpha: 0.4), blurRadius: 8)]
                          : [],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Mood picker
          SizedBox(
            height: 54,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kMoods.length,
              itemBuilder: (_, i) {
                final isSelected = i == _moodIndex;
                return GestureDetector(
                  onTap: () => setState(() => _moodIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? theme.primary : theme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? theme.primary : theme.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_kMoods[i].emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 4),
                        Text(
                          _kMoods[i].label,
                          style: fw(
                            size: 12,
                            w: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : theme.mid,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Caption input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _captionController,
              maxLength: 60,
              style: fw(size: 14, w: FontWeight.w600, color: theme.ink),
              decoration: InputDecoration(
                hintText: 'Ajouter une légende...',
                hintStyle: fw(size: 14, w: FontWeight.w500, color: theme.mid),
                counterText: '',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: theme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.primary, width: 2),
                ),
                suffixIcon: _captionController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18, color: theme.mid),
                        onPressed: () => setState(() => _captionController.clear()),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),

          // Export buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                _ExportButton(
                  icon: Icons.phone_android_rounded,
                  label: 'Story',
                  color: theme.primary,
                  isLoading: _isExporting,
                  onTap: () => _export(state, ShareFormat.story),
                ),
                const SizedBox(width: 10),
                _ExportButton(
                  icon: Icons.crop_square_rounded,
                  label: 'Carré',
                  color: theme.primary,
                  isLoading: _isExporting,
                  onTap: () => _export(state, ShareFormat.square),
                ),
                const SizedBox(width: 10),
                _ExportButton(
                  icon: Icons.credit_card_rounded,
                  label: 'Carte',
                  color: theme.primary,
                  isLoading: _isExporting,
                  onTap: () => _export(state, ShareFormat.card),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

Future<Uint8List?> _renderPhotobooth({
  required ShareFormat format,
  required List<Color> background,
  required PigMood mood,
  required Map<ClothingSlot, String?> outfit,
  required Map<String, int> outfitColors,
  required Color scarfColor,
  String caption = '',
}) async {
  final double w = format.w;
  final double h = format.h;
  final double s = w / 600;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

  // Background
  final bgPaint = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: background,
    ).createShader(Rect.fromLTWH(0, 0, w, h));
  canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

  // Pigio mascot — centered
  final mascotW = 350 * s;
  final mascotH = 455 * s;
  canvas.save();
  canvas.translate((w - mascotW) / 2, (h - mascotH) / 2 - 30 * s);
  PigioPainter(
    mood: mood,
    outfit: outfit,
    outfitColors: outfitColors,
    scarfColor: scarfColor,
  ).paint(canvas, Size(mascotW, mascotH));
  canvas.restore();

  // Caption
  if (caption.isNotEmpty) {
    final captionPainter = TextPainter(
      text: TextSpan(
        text: caption,
        style: TextStyle(
          color: Colors.white,
          fontSize: 28 * s,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5 * s,
          shadows: [
            Shadow(color: Colors.black54, blurRadius: 8 * s),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    )..layout(maxWidth: w - 60 * s);
    captionPainter.paint(
      canvas,
      Offset((w - captionPainter.width) / 2, h - 100 * s - captionPainter.height),
    );
  }

  // Watermark
  final watermark = TextPainter(
    text: TextSpan(
      text: 'pigio.app',
      style: TextStyle(
        color: Colors.white24,
        fontSize: 16 * s,
        fontWeight: FontWeight.w700,
        letterSpacing: 2 * s,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  watermark.paint(canvas, Offset((w - watermark.width) / 2, h - 50 * s));

  final picture = recorder.endRecording();
  final img = await picture.toImage(w.toInt(), h.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}
