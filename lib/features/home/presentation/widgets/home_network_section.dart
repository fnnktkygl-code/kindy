import 'package:flutter/material.dart';
import '../../../../shared/widgets/ui_widgets.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';

class HomeNetworkSection extends StatelessWidget {
  final PigioAppState state;
  final PigioThemeData theme;
  final VoidCallback onSeeAllContacts;
  final VoidCallback onManageGroups;
  final VoidCallback onCreateContact;
  final VoidCallback onInviteContact;
  final VoidCallback onCreateGroup;
  final void Function(ContactProfile contact) onOpenContact;
  final void Function(CircleGroup group) onInviteToGroup;

  const HomeNetworkSection({
    super.key,
    required this.state,
    required this.theme,
    required this.onSeeAllContacts,
    required this.onManageGroups,
    required this.onCreateContact,
    required this.onInviteContact,
    required this.onCreateGroup,
    required this.onOpenContact,
    required this.onInviteToGroup,
  });

  @override
  Widget build(BuildContext context) {
    final contacts = state.contacts;
    final groups = state.groups.where((g) => !g.isSystem).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 28, 14, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Mon réseau", style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
              GestureDetector(
                onTap: onSeeAllContacts,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Voir tout", style: fw(size: 13, w: FontWeight.w800, color: theme.primary)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: theme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _addContactBubble(
                  context,
                  emoji: "👤",
                  label: "Créer",
                  color: theme.success,
                  onTap: onCreateContact,
                ),
                const SizedBox(width: 10),
                _addContactBubble(
                  context,
                  emoji: "📩",
                  label: "Inviter",
                  color: theme.primary,
                  onTap: onInviteContact,
                ),
                if (contacts.isNotEmpty) const SizedBox(width: 16),
                ...contacts.take(8).map((contact) => GestureDetector(
                      onTap: () => onOpenContact(contact),
                      child: Container(
                        margin: const EdgeInsets.only(right: 14),
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                PigioAvatar(
                                  name: contact.name,
                                  size: 52,
                                  avatarIcon: contact.avatarIcon,
                                  avatarColor: contact.avatarColor,
                                  ringColor: contact.color,
                                ),
                                if (contact.status == ContactStatus.joined)
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: theme.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: theme.scaffold, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              contact.name.split(' ').first,
                              style: fw(size: 11, w: FontWeight.w700, color: theme.mid),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    )),
                if (contacts.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: GestureDetector(
                      onTap: onSeeAllContacts,
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(color: theme.surface, shape: BoxShape.circle, border: Border.all(color: theme.divider, width: 1.5)),
                            child: Center(child: Text("+${contacts.length - 8}", style: fw(size: 13, w: FontWeight.w800, color: theme.mid))),
                          ),
                          const SizedBox(height: 6),
                          Text("Tous", style: fw(size: 11, w: FontWeight.w700, color: theme.mid)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Mes cercles", style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
              GestureDetector(
                onTap: onManageGroups,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.accent4.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Gérer", style: fw(size: 13, w: FontWeight.w800, color: theme.accent4)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: theme.accent4),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            GestureDetector(
              onTap: onCreateGroup,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.divider, style: BorderStyle.solid),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: theme.accent4.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text("👥", style: TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Créer un cercle", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                          Text("Famille, amis, collègues…", style: fw(size: 12, color: theme.mid)),
                        ],
                      ),
                    ),
                    Icon(Icons.add_circle_rounded, color: theme.accent4, size: 26),
                  ],
                ),
              ),
            )
          else
            ...groups.take(3).map((g) {
              final members = state.contacts.where((c) => g.contactIds.contains(c.id)).toList();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.divider.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.accent4.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(child: Text(g.emoji, style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.name, style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                          const SizedBox(height: 2),
                          Text(
                            members.isEmpty
                                ? "Aucun membre"
                                : "${members.length} membre${members.length > 1 ? 's' : ''}",
                            style: fw(size: 12, color: theme.mid),
                          ),
                        ],
                      ),
                    ),
                    if (members.isNotEmpty)
                      SizedBox(
                        width: members.take(3).length * 22.0 + 10,
                        height: 32,
                        child: Stack(
                          children: members.take(3).toList().asMap().entries.map((e) {
                            return Positioned(
                              left: e.key * 20.0,
                              child: PigioAvatar(
                                name: e.value.name,
                                size: 32,
                                avatarIcon: e.value.avatarIcon,
                                avatarColor: e.value.avatarColor,
                                ringColor: theme.scaffold,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onInviteToGroup(g),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_add_alt_1_outlined, size: 14, color: theme.primary),
                            const SizedBox(width: 4),
                            Text("Inviter", style: fw(size: 11, w: FontWeight.w800, color: theme.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (groups.length > 3)
            Center(
              child: TextButton(
                onPressed: onManageGroups,
                child: Text("Et ${groups.length - 3} autres cercles…", style: fw(size: 13, w: FontWeight.w700, color: theme.mid)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _addContactBubble(BuildContext context, {
    required String emoji,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final localTheme = context.pt;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(height: 6),
          Text(label, style: fw(size: 11, w: FontWeight.w700, color: localTheme.mid)),
        ],
      ),
    );
  }
}