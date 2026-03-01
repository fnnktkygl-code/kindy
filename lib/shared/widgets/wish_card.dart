import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/core/state/app_state.dart';

// EN-2: Smart Masonry Grid - Balances columns by estimated height, avoiding visual gaps
class SmartMasonryGrid extends StatelessWidget {
  final List<Widget> children;
  final List<double> estimatedHeights;
  const SmartMasonryGrid({super.key, required this.children, required this.estimatedHeights});

  @override
  Widget build(BuildContext context) {
    List<Widget> left = [];
    List<Widget> right = [];
    double leftH = 0;
    double rightH = 0;

    for (int i = 0; i < children.length; i++) {
      if (leftH <= rightH) {
        left.add(children[i]);
        leftH += estimatedHeights[i];
      } else {
        right.add(children[i]);
        rightH += estimatedHeights[i];
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: left)),
        const SizedBox(width: 14),
        Expanded(child: Column(children: right)),
      ],
    );
  }
}

// Washi tape colors — chosen to be vibrant but theme-safe
const List<Color> _washiColors = [
  Color(0xFFFFBFA8), // peach
  Color(0xFFB2D8CB), // mint
  Color(0xFFFFD166), // yellow
  Color(0xFFA8C4FF), // periwinkle
  Color(0xFFFFC8DE), // pink
];

// Deterministic tilt & washi from wish id
double _getTilt(String id) {
  final h = id.hashCode;
  final t = ((h % 7) - 3) * 0.018; // range ~[-0.054, 0.054] rad
  return t;
}

Color _getWashiColor(String id) {
  return _washiColors[id.hashCode.abs() % _washiColors.length];
}

// Paper-white tint that adapts per theme mode
Color _getPaperColor(PigioThemeData theme, String id) {
  // Slight variation to make each card feel distinct
  final tints = theme.isDark
      ? [
    const Color(0xFF2A2C3E),
    const Color(0xFF262836),
    const Color(0xFF2C2A38),
    const Color(0xFF252730),
  ]
      : [
    const Color(0xFFFFFEFA),
    const Color(0xFFFEF9F0),
    const Color(0xFFFBFAF5),
    const Color(0xFFFFF8EE),
  ];
  return tints[id.hashCode.abs() % tints.length];
}

class WishCard extends StatelessWidget {
  final Wish wish;
  final PigioThemeData theme;
  final bool surpriseMode;
  final bool isMine;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget? customAction;

  const WishCard({
    super.key,
    required this.wish,
    required this.theme,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.surpriseMode = false,
    this.isMine = true,
    this.customAction,
  });

  static double getImageHeight(WishPriority priority) {
    switch (priority) {
      case WishPriority.low:
        return 110.0;
      case WishPriority.medium:
        return 160.0;
      case WishPriority.high:
        return 220.0;
    }
  }

  static double estimateHeight(Wish w, {bool hasCustomAction = false}) {
    double h = getImageHeight(w.priority);
    h += 36.0; // padding + washi tap
    h += (w.title.length / 14).ceil() * 22;
    if (w.priceRange != null) h += 26;
    if (hasCustomAction) h += 50;
    h += 20; // margin + tilt visual space
    return h;
  }

  ImageProvider? _getImageProvider(String path) {
    if (path.isEmpty || path == 'null') return null;
    if (path.startsWith('http')) return NetworkImage(path);
    final file = File(path);
    if (file.existsSync()) return FileImage(file);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tilt = _getTilt(wish.id);
    final washiColor = _getWashiColor(wish.id);
    final paperColor = _getPaperColor(theme, wish.id);
    final imageHeight = getImageHeight(wish.priority);
    final imageProvider = wish.imageUrl != null ? _getImageProvider(wish.imageUrl!) : null;

    Widget? badgeOverlay;
    if (wish.reservedById != null) {
      if (!surpriseMode) {
        badgeOverlay = _buildReservedStamp(theme);
      } else {
        badgeOverlay = _buildSurpriseStamp(theme);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: tilt,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: paperColor,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: theme.isDark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.09),
                blurRadius: 12,
                offset: const Offset(2, 5),
              ),
              BoxShadow(
                color: theme.isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Washi tape strip
              _buildWashiTape(washiColor, wish.id),

              // Image area
              Stack(
                children: [
                  Container(
                    height: imageHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.surface,
                      image: imageProvider != null
                          ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: imageProvider != null
                        ? null
                        : Text(wish.emoji, style: const TextStyle(fontSize: 44)),
                  ),
                  if (badgeOverlay != null)
                    Positioned.fill(child: badgeOverlay),
                  if (isMine)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (wish.priority == WishPriority.high)
                            Container(
                              padding: const EdgeInsets.all(5),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.local_fire_department,
                                  color: theme.warning, size: 16),
                            ),
                          _buildMoreMenu(context, theme),
                        ],
                      ),
                    ),
                ],
              ),

              // Bottom: Polaroid-style caption area
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wish.title,
                      style: GoogleFonts.caveat(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: theme.ink,
                        height: 1.25,
                      ),
                    ),
                    if (wish.priceRange != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: theme.isDark
                                  ? theme.divider
                                  : Colors.grey.shade400,
                              width: 1,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          wish.priceRange == WishPriceRange.budget
                              ? "< 30€"
                              : wish.priceRange == WishPriceRange.mid
                              ? "30 – 100€"
                              : "100€+",
                          style: GoogleFonts.caveat(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.mid,
                          ),
                        ),
                      ),
                    ],
                    if (customAction != null) ...[
                      const SizedBox(height: 10),
                      customAction!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWashiTape(Color color, String id) {
    // Position tape slightly off-center for organic feel
    final offset = (id.hashCode % 30) - 15.0; // -15 to +15 px
    return SizedBox(
      height: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -8,
            left: 20 + offset,
            child: Transform.rotate(
              angle: (id.hashCode % 5 - 2) * 0.04,
              child: Container(
                width: 52,
                height: 20,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservedStamp(PigioThemeData theme) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
        ),
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: -0.35,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: theme.success, width: 3),
              borderRadius: BorderRadius.circular(6),
              color: Colors.white.withValues(alpha: 0.92),
            ),
            child: Text(
              "RÉSERVÉ !",
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: theme.success,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSurpriseStamp(PigioThemeData theme) {
    return Positioned.fill(
      child: Container(
        color: theme.ink.withValues(alpha: 0.80),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("🤫", style: TextStyle(fontSize: 30)),
            const SizedBox(height: 4),
            Text(
              "SURPRISE",
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context, PigioThemeData theme) {
    return Container(
      decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: 0.92), shape: BoxShape.circle),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_horiz, color: theme.ink, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onSelected: (val) {
          if (val == 'edit') onEdit?.call();
          if (val == 'delete') onDelete?.call();
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 18, color: theme.ink),
              const SizedBox(width: 12),
              const Text("Modifier"),
            ]),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(children: [
              Icon(Icons.delete_outline, size: 18, color: theme.error),
              const SizedBox(width: 12),
              Text("Supprimer", style: TextStyle(color: theme.error)),
            ]),
          ),
        ],
      ),
    );
  }
}