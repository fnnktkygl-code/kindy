import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/pigio_painter.dart';
import '../../../../shared/widgets/ui_widgets.dart';
import 'package:kindy/features/contacts/presentation/contact_profile_screen.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';

class GroupMembersSection extends StatefulWidget {
  final CircleGroup group;

  const GroupMembersSection({super.key, required this.group});

  @override
  State<GroupMembersSection> createState() => _GroupMembersSectionState();
}

class _GroupMembersSectionState extends State<GroupMembersSection> {
  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final group = state.groups.where((g) => g.id == widget.group.id).firstOrNull ?? widget.group;
    final allContacts = state.contacts;
    final members = allContacts.where((c) => group.contactIds.contains(c.id)).toList();
    final pendingMembers = allContacts.where((c) => group.pendingInviteIds.contains(c.id)).toList();
    final nonMembers = allContacts.where((c) => !group.contactIds.contains(c.id) && !group.pendingInviteIds.contains(c.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text("MEMBRES", style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2)),
        ),
        if (members.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                CustomPaint(size: const Size(64, 64), painter: PigioPainter(mood: PigMood.searching, scarfColor: theme.primary)),
                const SizedBox(height: 12),
                Text(
                  "Pigio cherche des amis... 🐽",
                  style: fw(size: 14, w: FontWeight.w800, color: theme.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  "Ajoutez des membres à ce cercle\npour partager des listes et tailles.",
                  style: fw(size: 13, w: FontWeight.w600, color: theme.mid, height: 1.4),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...members.map((c) => _memberTile(c, group, state, theme, isMember: true)),

        if (pendingMembers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 10),
            child: Text("EN ATTENTE (${pendingMembers.length})", style: fw(size: 11, w: FontWeight.w900, color: theme.warning, letterSpacing: 1.2)),
          ),
          ...pendingMembers.map((c) => _memberTile(c, group, state, theme, isMember: false, isPending: true)),
        ],

        if (nonMembers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 10),
            child: Text("AJOUTER AU CERCLE", style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2)),
          ),
          ...nonMembers.map((c) => _memberTile(c, group, state, theme, isMember: false)),
        ],

        if (!group.isSystem)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.error.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Zone de danger", style: fw(size: 14, w: FontWeight.w800, color: theme.error)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _confirmDeleteGroup(context, group, state, theme),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: theme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, color: theme.error, size: 18),
                          const SizedBox(width: 8),
                          Text("Supprimer ce cercle", style: fw(size: 14, w: FontWeight.w800, color: theme.error)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _memberTile(ContactProfile contact, CircleGroup group, PigioAppState state, PigioThemeData theme, {required bool isMember, bool isPending = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPending ? theme.warning.withValues(alpha: 0.45) : (isMember ? theme.divider : theme.primary.withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              state.recordProfileView(contact.id);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ContactProfileScreen(contact: contact)));
            },
            child: PigioAvatar(name: contact.name, size: 40, avatarIcon: contact.avatarIcon, avatarColor: contact.avatarColor, ringColor: contact.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                state.recordProfileView(contact.id);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ContactProfileScreen(contact: contact)));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name, style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                  Text(
                    isPending
                        ? 'En attente de validation'
                        : (contact.status == ContactStatus.joined || contact.isManaged
                            ? contact.role
                            : '${contact.role} \u2022 Invitez depuis l\'onglet Contacts'),
                    style: fw(size: 12, w: FontWeight.w600, color: isPending ? theme.warning : theme.mid),
                  ),
                ],
              ),
            ),
          ),
          if (isPending)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => state.rejectPendingMember(group.id, contact.id),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: theme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.close, color: theme.error, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => state.approvePendingMember(group.id, contact.id),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: theme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.check, color: theme.success, size: 18),
                  ),
                ),
              ],
            )
          else if (isMember)
            GestureDetector(
              onTap: () => state.removeContactFromGroup(group.id, contact.id),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: theme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.person_remove, color: theme.error, size: 18),
              ),
            )
          else
            () {
              final isFamilyGroupBlocked = group.isSystem &&
                  group.trustLevel == TrustLevel.family &&
                  !contact.isFamily;
              if (isFamilyGroupBlocked) {
                return Tooltip(
                  message: 'Réservé aux contacts Famille',
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: theme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_outline, color: theme.warning, size: 18),
                  ),
                );
              }
              final canAdd = contact.isManaged || contact.status == ContactStatus.joined;
              return canAdd
                  ? GestureDetector(
                      onTap: () => state.addContactToGroup(group.id, contact.id),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: theme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.person_add, color: theme.success, size: 18),
                      ),
                    )
                  : Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: theme.mid.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.info_outline, color: theme.mid, size: 18),
                    );
            }(),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, CircleGroup group, PigioAppState state, PigioThemeData theme) {
    final members = state.contacts.where((c) => group.contactIds.contains(c.id)).toList();
    final familyMembers = members.where((m) => m.trustLevel == TrustLevel.family).length;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Supprimer \"${group.name}\" ?", style: fw(size: 18, w: FontWeight.w900, color: theme.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Cette action est irréversible. Les contacts ne seront pas supprimés, seul le cercle sera retiré.",
              style: fw(size: 14, w: FontWeight.w600, color: theme.mid, height: 1.4),
            ),
            if (familyMembers > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.visibility_outlined, color: theme.warning, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "$familyMembers membres ont accès à vos tailles exactes via ce cercle. Vérifiez leurs niveaux d'accès après suppression.",
                        style: fw(size: 13, w: FontWeight.w700, color: theme.warning, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Annuler", style: fw(size: 14, w: FontWeight.w800, color: theme.mid)),
          ),
          TextButton(
            onPressed: () {
              state.deleteGroup(group.id);
              Navigator.pop(ctx);
              if (mounted) Navigator.pop(context);
            },
            child: Text("Supprimer", style: fw(size: 14, w: FontWeight.w800, color: theme.error)),
          ),
        ],
      ),
    );
  }
}
