import 'package:flutter/material.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/core/models/app_models.dart';

class PotProgressBar extends StatelessWidget {
  final GiftPot pot;
  final PigioThemeData theme;
  final bool showLabel;
  final bool isFr;

  const PotProgressBar({
    super.key,
    required this.pot,
    required this.theme,
    this.showLabel = true,
    this.isFr = true,
  });

  @override
  Widget build(BuildContext context) {
    if (pot.targetAmount == null || pot.targetAmount! <= 0) {
      return const SizedBox.shrink(); // No target, no progress bar
    }

    final totalCollected = pot.totalContributed;
    final target = pot.targetAmount!;
    final progress = (totalCollected / target).clamp(0.0, 1.0);
    final isCompleted = totalCollected >= target;

    final color = isCompleted ? theme.success : theme.primary;
    final bgColor = color.withValues(alpha: 0.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLabel) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isCompleted 
                    ? (isFr ? 'Objectif atteint ! 🎉' : 'Goal reached! 🎉')
                    : (isFr ? 'Objectif cagnotte' : 'Pot progress'),
                style: fw(size: 13, w: FontWeight.w600, color: isCompleted ? theme.success : theme.mid),
              ),
              Text(
                '${totalCollected.toInt()} / ${target.toInt()} €',
                style: fw(size: 13, w: FontWeight.w700, color: theme.ink),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
