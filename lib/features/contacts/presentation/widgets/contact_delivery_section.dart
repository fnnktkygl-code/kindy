import 'package:flutter/material.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';

class ContactDeliverySection extends StatelessWidget {
  final ContactProfile contact;
  final bool canEditProfile;
  final PigioThemeData theme;
  final VoidCallback onEditProfile;

  const ContactDeliverySection({
    super.key,
    required this.contact,
    required this.canEditProfile,
    required this.theme,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("LIVRAISON", style: fw(size: 12, w: FontWeight.w800, color: theme.mid, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          _AddressCard(
            icon: "🏠",
            title: "Adresse postale",
            value: contact.address,
            isHidden: contact.hideAddress,
            hiddenLabel: "Cachée",
            onTap: canEditProfile ? onEditProfile : null,
            theme: theme,
          ),
          const SizedBox(height: 12),
          _AddressCard(
            icon: "📦",
            title: "Point Relais Favori",
            value: contact.mondialRelayPoint,
            isHidden: contact.hideMondialRelay,
            hiddenLabel: "Caché",
            onTap: canEditProfile ? onEditProfile : null,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final String icon;
  final String title;
  final String? value;
  final bool isHidden;
  final String hiddenLabel;
  final VoidCallback? onTap;
  final PigioThemeData theme;

  const _AddressCard({
    required this.icon,
    required this.title,
    required this.value,
    this.isHidden = false,
    this.hiddenLabel = "Caché",
    this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == null || value!.isEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.divider.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: fw(size: 14, w: FontWeight.w800, color: theme.ink)),
                      if (isHidden) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: theme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(hiddenLabel, style: fw(size: 10, w: FontWeight.w700, color: theme.primary)),
                        ),
                      ]
                    ],
                  ),
                  if (isHidden && !isEmpty)
                    Text("Masqué du public", style: fw(size: 13, w: FontWeight.w600, color: theme.mid))
                  else if (!isEmpty)
                    Text(value!, style: fw(size: 13, w: FontWeight.w600, color: theme.mid), maxLines: 1, overflow: TextOverflow.ellipsis)
                  else
                    Text("Non renseigné", style: fw(size: 12, w: FontWeight.w600, color: theme.light)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.chevron_right, color: theme.light),
          ],
        ),
      ),
    );
  }
}