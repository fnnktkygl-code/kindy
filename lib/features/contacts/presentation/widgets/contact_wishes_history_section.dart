import 'package:flutter/material.dart';
import '../../../../shared/widgets/ui_widgets.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';

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
          ...historyChildren,
        ],
      ),
    );
  }
}