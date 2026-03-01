import 'package:flutter/material.dart';
import '../../../../shared/widgets/ui_widgets.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';

class ContactProfileHeader extends StatelessWidget {
  final ContactProfile contact;
  final bool isFamily;
  final bool canEditProfile;
  final bool canEditTrustLevel;
  final PigioThemeData theme;
  final Animation<double> avatarShakeAnimation;
  final Widget inviteStatusSection;
  final VoidCallback onEdit;
  final VoidCallback onPickCircle;
  final VoidCallback onWizz;

  const ContactProfileHeader({
    super.key,
    required this.contact,
    required this.isFamily,
    required this.canEditProfile,
    this.canEditTrustLevel = false,
    required this.theme,
    required this.avatarShakeAnimation,
    required this.inviteStatusSection,
    required this.onEdit,
    required this.onPickCircle,
    required this.onWizz,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        border: Border(bottom: BorderSide(color: theme.divider.withValues(alpha: 0.5), width: 1)),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: avatarShakeAnimation,
            builder: (_, child) => Transform.translate(
              offset: Offset(avatarShakeAnimation.value, 0),
              child: child,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                PigioAvatar(
                  name: contact.name,
                  size: 90,
                  avatarIcon: contact.avatarIcon,
                  avatarColor: contact.avatarColor,
                  ringColor: contact.color,
                ),
                if (isFamily)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.success,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: theme.shadow, blurRadius: 4)],
                      ),
                      child: Icon(Icons.verified_user, size: 14, color: theme.onAccent),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(contact.name, style: fw(size: 26, w: FontWeight.w900, color: theme.ink)),
              if (isFamily) ...[
                const SizedBox(width: 8),
                _tag("Famille", theme.success),
              ]
            ],
          ),
          Text(contact.role.toLowerCase(), style: fw(size: 14, w: FontWeight.w600, color: theme.mid)),
          const SizedBox(height: 20),
          inviteStatusSection,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (canEditProfile || canEditTrustLevel) ...[
                PigioButton(
                  label: "Modifier",
                  icon: Icons.edit_outlined,
                  color: theme.surface,
                  textColor: theme.ink,
                  height: 44,
                  fontSize: 14,
                  hasShadow: false,
                  onTap: onEdit,
                  fullWidth: false,
                ),
                const SizedBox(width: 12),
              ],
              PigioButton(
                label: "Cercle",
                icon: Icons.group_add_outlined,
                color: theme.accent4.withValues(alpha: 0.1),
                textColor: theme.accent4,
                height: 44,
                fontSize: 14,
                hasShadow: false,
                onTap: onPickCircle,
                fullWidth: false,
              ),
              if (contact.status == ContactStatus.joined ||
                  contact.status == ContactStatus.invited) ...[
                const SizedBox(width: 12),
                PigioButton(
                  label: "Wizz ⚡",
                  color: theme.accent1.withValues(alpha: 0.1),
                  textColor: theme.accent1,
                  height: 44,
                  fontSize: 14,
                  hasShadow: false,
                  onTap: onWizz,
                  fullWidth: false,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: fw(size: 10, w: FontWeight.w800, color: color)),
    );
  }
}