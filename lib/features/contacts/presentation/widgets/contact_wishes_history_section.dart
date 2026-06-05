import 'package:flutter/material.dart';
import '../../../../shared/widgets/ui_widgets.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';

class ContactWishesHistorySection extends StatelessWidget {
  final bool canEditProfile;
  final PigioThemeData theme;
  final VoidCallback onAddWish;
  final List<Widget> historyChildren;

  const ContactWishesHistorySection({
    super.key,
    required this.canEditProfile,
    required this.theme,
    required this.onAddWish,
    required this.historyChildren,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Historique", style: fw(size: 22, w: FontWeight.w900, color: theme.ink)),
                  const SizedBox(height: 2),
                  Text("Les 12 derniers mois", style: fw(size: 13, w: FontWeight.w600, color: theme.mid)),
                ],
              ),
              if (canEditProfile)
                GestureDetector(
                  onTap: onAddWish,
                  child: PigioBadge(
                    label: "+ Ajouter",
                    color: theme.primary,
                    bg: theme.primary.withValues(alpha: 0.1),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (historyChildren.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.divider.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  const Text('📦', style: TextStyle(fontSize: 28)),
                  const SizedBox(height: 10),
                  Text("Aucun historique", style: fw(size: 16, w: FontWeight.w800, color: theme.ink)),
                  const SizedBox(height: 4),
                  Text("Les envies passées apparaîtront ici.", style: fw(size: 13, w: FontWeight.w600, color: theme.mid), textAlign: TextAlign.center),
                ],
              ),
            )
          else
            ...historyChildren,
        ],
      ),
    );
  }
}