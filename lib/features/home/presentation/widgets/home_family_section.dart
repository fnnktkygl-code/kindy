import 'package:flutter/material.dart';

import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import '../../../../shared/widgets/ui_widgets.dart';

class HomeFamilySection extends StatelessWidget {
  const HomeFamilySection({
    super.key,
    required this.state,
    required this.theme,
    required this.onOpenSummary,
    required this.onSeeAllMembers,
  });

  final PigioAppState state;
  final PigioThemeData theme;
  final void Function(ContactProfile contact) onOpenSummary;
  final VoidCallback onSeeAllMembers;

  @override
  Widget build(BuildContext context) {
    final family = state.contacts.where((c) => c.isFamily).toList();
    if (family.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("MA FAMILLE", style: fw(size: 11, w: FontWeight.w800, color: theme.mid, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onSeeAllMembers,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.success.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🏠', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Ajouter des proches", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                        const SizedBox(height: 2),
                        Text("Ajoutez vos proches au cercle Famille pour suivre leurs envies.", style: fw(size: 12, w: FontWeight.w600, color: theme.mid)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.success, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("MA FAMILLE", style: fw(size: 11, w: FontWeight.w800, color: theme.mid, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ...family.take(3).map((member) {
          final sizes = state.getVisibleSizesFor(member.id, viewerTrustLevel: member.trustLevel);
          bool birthdaySoon = false;
          if (member.birthdate != null && !member.hideBirthdate) {
            try {
              final parts = member.birthdate!.split('/');
              final birthdate = DateTime(DateTime.now().year, int.parse(parts[1]), int.parse(parts[0]));
              final diff = birthdate.difference(DateTime.now()).inDays;
              if (diff >= 0 && diff <= 30) birthdaySoon = true;
            } catch (e) {
              debugPrint('[HomeFamily] Invalid birthdate for ${member.name}: ${member.birthdate}');
            }
          }
          final bool incomplete = sizes.length < 3;

          return GestureDetector(
            onTap: () => onOpenSummary(member),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.divider.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  PigioAvatar(name: member.name, size: 46, avatarIcon: member.avatarIcon, avatarColor: member.avatarColor, ringColor: member.color),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name, style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (birthdaySoon) _tag("🎂 Bientôt", theme.accent2),
                            if (incomplete) _tag("📏 Mesures", theme.warning),
                            if (!incomplete) _tag("✅ Complet", theme.success),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.light, size: 20),
                ],
              ),
            ),
          );
        }),
        if (family.length > 3)
          Center(
            child: TextButton(
              onPressed: onSeeAllMembers,
              child: Text("Et ${family.length - 3} autres membres…", style: fw(size: 13, w: FontWeight.w700, color: theme.light)),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: fw(size: 9, w: FontWeight.w800, color: color)),
    );
  }
}
