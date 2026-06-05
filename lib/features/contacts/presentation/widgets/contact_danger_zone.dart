import 'package:flutter/material.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';

class ContactDangerZone extends StatelessWidget {
  final PigioThemeData theme;
  final VoidCallback onDelete;

  const ContactDangerZone({
    super.key,
    required this.theme,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ZONE DANGEREUSE",
            style: fw(size: 11, w: FontWeight.w900, color: theme.error, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.error.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person_remove_outlined, size: 18, color: theme.error),
                  const SizedBox(width: 12),
                  Text(
                    "Supprimer ce contact",
                    style: fw(size: 14, w: FontWeight.w800, color: theme.error),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}