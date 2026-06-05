import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/core/state/app_state.dart';

// Paper tints matching WishCard style
Color _getPotPaperColor(PigioThemeData theme, String id) {
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

double _getPotTilt(String id) {
  final h = id.hashCode;
  return ((h % 7) - 3) * 0.014;
}

const List<Color> _potWashiColors = [
  Color(0xFFFFBFA8),
  Color(0xFFB2D8CB),
  Color(0xFFFFD166),
  Color(0xFFA8C4FF),
  Color(0xFFFFC8DE),
];

class GiftPotCard extends StatelessWidget {
  final GiftPot pot;
  final PigioThemeData theme;
  final String recipientName;
  final VoidCallback onTap;

  const GiftPotCard({
    super.key,
    required this.pot,
    required this.theme,
    required this.recipientName,
    required this.onTap,
  });

  static double estimateHeight(GiftPot pot) {
    double h = 170.0;
    if (pot.contributions.isNotEmpty) h += 20;
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final tilt = _getPotTilt(pot.id);
    final paperColor = _getPotPaperColor(theme, pot.id);
    final washiColor =
        _potWashiColors[pot.id.hashCode.abs() % _potWashiColors.length];
    final progress = pot.progressPercent;

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
              // Washi tape
              _buildWashiTape(washiColor),

              // Emoji + status area
              Container(
                height: 64,
                width: double.infinity,
                color: theme.surface,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(pot.emoji, style: const TextStyle(fontSize: 32)),
                    if (pot.status == GiftPotStatus.completed) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '✓',
                          style: TextStyle(
                              color: theme.success, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      pot.title,
                      style: GoogleFonts.caveat(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: theme.ink,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Recipient
                    Text(
                      'Pour $recipientName',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.mid,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: theme.divider,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(theme.accent2),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Amount + contributors
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${pot.totalContributed.toStringAsFixed(0)}€ / ${pot.targetAmount.toStringAsFixed(0)}€',
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: theme.ink,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 14, color: theme.mid),
                            const SizedBox(width: 3),
                            Text(
                              '${pot.contributorCount}',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.mid,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Mode indicator
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.isDark
                              ? theme.divider
                              : Colors.grey.shade400,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pot.mode == GiftPotMode.share
                            ? '${pot.sharePerPerson.toStringAsFixed(0)}€ / pers.'
                            : 'Montant libre',
                        style: GoogleFonts.caveat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.mid,
                        ),
                      ),
                    ),
                    if (pot.isSurprise) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('🤫', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            'Surprise',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.mid,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildWashiTape(Color color) {
    final offset = (pot.id.hashCode % 30) - 15.0;
    return SizedBox(
      height: 18,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -8,
            left: 20 + offset,
            child: Transform.rotate(
              angle: (pot.id.hashCode % 5 - 2) * 0.04,
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
}
