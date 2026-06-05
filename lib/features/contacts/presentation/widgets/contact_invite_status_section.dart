import 'package:flutter/material.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';

class ContactInviteStatusSection extends StatelessWidget {
  final PigioAppState state;
  final ContactProfile contact;
  final PigioThemeData theme;
  final VoidCallback onOpenInvite;
  final VoidCallback onConfirmReset;
  final VoidCallback onConfirmResend;

  const ContactInviteStatusSection({
    super.key,
    required this.state,
    required this.contact,
    required this.theme,
    required this.onOpenInvite,
    required this.onConfirmReset,
    required this.onConfirmResend,
  });

  @override
  Widget build(BuildContext context) {
    final blockReason = state.getInviteBlockReason(contact.id);

    if (contact.isManaged) return const SizedBox(height: 4);

    if (blockReason == InviteBlockReason.alreadyJoined) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          decoration: BoxDecoration(
            color: theme.success.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.success.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 14, color: theme.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Sur Pigio · tailles synchronisées automatiquement",
                      style: fw(size: 12, w: FontWeight.w700, color: theme.success),
                    ),
                  ),
                ],
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onConfirmReset,
                child: Text(
                  "${contact.name} a changé de compte ou d'email ?",
                  style: fw(size: 11, w: FontWeight.w700, color: theme.mid)
                      .copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (blockReason == InviteBlockReason.pendingActive) {
      final active = state.getActivePendingInviteFor(contact.id)!;
      final daysLeft = active.expiresAt.difference(DateTime.now()).inDays;
      final daysText = daysLeft <= 0 ? "expire aujourd'hui" : "expire dans $daysLeft j.";
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.warning.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.warning.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mail_outline_rounded, size: 14, color: theme.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Invitation en attente · $daysText",
                      style: fw(size: 12, w: FontWeight.w700, color: theme.warning),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                "Invitation envoyée. Vous pouvez partager le lien ou le renvoyer.",
                style: fw(size: 11, w: FontWeight.w600, color: theme.mid),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(Icons.refresh, size: 14, color: theme.warning),
                  label: Text("Renvoyer (annule l'ancien)",
                      style: fw(size: 11, w: FontWeight.w700, color: theme.warning)),
                  onPressed: onConfirmResend,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final latestInvite = state.getLatestInviteFor(contact.id);
    if (contact.status == ContactStatus.invited &&
        latestInvite != null &&
        (latestInvite.isExpired || latestInvite.state == PendingInviteState.expired)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.error.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.timer_off_outlined, size: 16, color: theme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Invitation expirée",
                  style: fw(size: 12, w: FontWeight.w700, color: theme.error),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onOpenInvite,
                child: Text("Renvoyer",
                    style: fw(size: 12, w: FontWeight.w800, color: theme.primary)),
              ),
            ],
          ),
        ),
      );
    }

    if (contact.status == ContactStatus.local) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: onOpenInvite,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.person_add_outlined, size: 18, color: theme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Inviter ${contact.name} sur Pigio pour synchroniser ses tailles",
                    style: fw(size: 12, w: FontWeight.w700, color: theme.primary, height: 1.4),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text("Inviter",
                      style: fw(size: 12, w: FontWeight.w800, color: theme.onAccent)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const SizedBox(height: 4);
  }
}