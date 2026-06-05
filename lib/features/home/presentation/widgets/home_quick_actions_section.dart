import 'package:flutter/material.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';

class HomeQuickActionsSection extends StatelessWidget {
  final PigioThemeData theme;
  final VoidCallback onAddWish;
  final VoidCallback onAddEvent;
  final VoidCallback onAddContact;
  final VoidCallback onInvite;
  final VoidCallback onAddGroup;

  const HomeQuickActionsSection({
    super.key,
    required this.theme,
    required this.onAddWish,
    required this.onAddEvent,
    required this.onAddContact,
    required this.onInvite,
    required this.onAddGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Actions rapides", style: fw(size: 13, w: FontWeight.w800, color: theme.mid, letterSpacing: 0.8)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _primaryActionCard(
                  context,
                  emoji: "🎁",
                  label: "Ajouter une envie",
                  subtitle: "Sur ma liste",
                  color: theme.accent2,
                  onTap: onAddWish,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _primaryActionCard(
                  context,
                  emoji: "🗓",
                  label: "Créer un événement",
                  subtitle: "Anniversaire, fête…",
                  color: theme.accent1,
                  onTap: onAddEvent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _secondaryActionCard(
                  context,
                  emoji: "👤",
                  label: "Créer un contact",
                  color: theme.success,
                  onTap: onAddContact,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _secondaryActionCard(
                  context,
                  emoji: "📩",
                  label: "Inviter quelqu'un",
                  color: theme.primary,
                  onTap: onInvite,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _secondaryActionCard(
                  context,
                  emoji: "👥",
                  label: "Créer un cercle",
                  color: theme.accent4,
                  onTap: onAddGroup,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _primaryActionCard(BuildContext context, {
    required String emoji,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final localTheme = context.pt;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.18), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: fw(size: 13, w: FontWeight.w800, color: localTheme.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(subtitle, style: fw(size: 11, color: localTheme.mid), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secondaryActionCard(BuildContext context, {
    required String emoji,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(height: 8),
            Text(label, style: fw(size: 11, w: FontWeight.w800, color: color, height: 1.2), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}