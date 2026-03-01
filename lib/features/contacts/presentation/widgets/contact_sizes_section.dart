import 'package:flutter/material.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/i18n/i18n.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';

typedef ContactSizeCardBuilder = Widget Function(
  String key,
  String emoji,
  Color color,
);

class ContactSizesSection extends StatelessWidget {
  final ContactProfile contact;
  final List<SizeProfile> sizes;
  final bool canEditProfile;
  final PigioThemeData theme;
  final ContactSizeCardBuilder buildSizeCard;

  const ContactSizesSection({
    super.key,
    required this.contact,
    required this.sizes,
    required this.canEditProfile,
    required this.theme,
    required this.buildSizeCard,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t(context, 'sizes_title'), style: fw(size: 22, w: FontWeight.w900, color: theme.ink)),
              Text(
                canEditProfile ? t(context, 'tap_to_edit') : 'Lecture seule',
                style: fw(size: 12, w: FontWeight.w600, color: theme.mid),
              ),
            ],
          ),
          if (contact.status == ContactStatus.joined && sizes.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.accent1.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.accent1.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: theme.accent1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "${contact.name} peut partager ses tailles via son profil dans l'application Pigio. Les tailles des utilisateurs connectés seront bientôt synchronisées automatiquement.",
                      style: fw(size: 12, w: FontWeight.w600, color: theme.accent1, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: buildSizeCard('clothes', '👕', theme.primary)),
              const SizedBox(width: 12),
              Expanded(child: buildSizeCard('bottoms', '👖', theme.success)),
              const SizedBox(width: 12),
              Expanded(child: buildSizeCard('shoes', '👟', theme.accent3)),
            ],
          ),
        ],
      ),
    );
  }
}