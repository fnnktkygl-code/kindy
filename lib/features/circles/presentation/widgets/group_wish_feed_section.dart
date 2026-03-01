import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/pigio_painter.dart';
import '../../../../shared/widgets/ui_widgets.dart';
import '../../../../shared/widgets/wish_card.dart';
import 'package:pigio_app/features/contacts/presentation/contact_profile_screen.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'group_birthday_timeline.dart';

enum _WishSort { member, birthday, wishCount }

class GroupWishFeedSection extends StatefulWidget {
  final CircleGroup group;

  const GroupWishFeedSection({super.key, required this.group});

  @override
  State<GroupWishFeedSection> createState() => _GroupWishFeedSectionState();
}

class _GroupWishFeedSectionState extends State<GroupWishFeedSection> {
  _WishSort _sort = _WishSort.member;

  int _daysUntilBirthday(ContactProfile contact) {
    if (contact.birthdate == null || contact.hideBirthdate) return 999;
    try {
      final parts = contact.birthdate!.split('/');
      if (parts.length < 2) return 999;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      if (month < 1 || month > 12 || day < 1 || day > 31) return 999;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int targetDay = day;
      if (month == 2 && day == 29) {
        final isLeap = (now.year % 4 == 0) && ((now.year % 100 != 0) || (now.year % 400 == 0));
        if (!isLeap) targetDay = 28;
      }
      var next = DateTime(now.year, month, targetDay);
      if (next.isBefore(today)) {
        final ny = now.year + 1;
        final isLeapNext = (ny % 4 == 0) && ((ny % 100 != 0) || (ny % 400 == 0));
        final nd = (month == 2 && day == 29 && !isLeapNext) ? 28 : day;
        next = DateTime(ny, month, nd);
      }
      return next.difference(today).inDays;
    } catch (_) {
      return 999;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final freshGroup = state.groups.where((g) => g.id == widget.group.id).firstOrNull ?? widget.group;
    final members = state.contacts.where((c) => freshGroup.contactIds.contains(c.id)).toList();
    final surpriseMode = state.surpriseMode;

    // Aggregate wishes per member
    var memberWishes = <(ContactProfile, List<Wish>)>[];
    for (final member in members) {
      final wishes = state.getWishesFor(member.id);
      if (wishes.isNotEmpty) {
        memberWishes.add((member, wishes));
      }
    }

    // Apply sort
    switch (_sort) {
      case _WishSort.member:
        memberWishes.sort((a, b) => a.$1.name.compareTo(b.$1.name));
      case _WishSort.birthday:
        memberWishes.sort((a, b) => _daysUntilBirthday(a.$1).compareTo(_daysUntilBirthday(b.$1)));
      case _WishSort.wishCount:
        memberWishes.sort((a, b) => b.$2.length.compareTo(a.$2.length));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Birthday timeline
        GroupBirthdayTimeline(members: members),

        // Sort chips (only when there is something to sort)
        if (memberWishes.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _sortChip(_WishSort.member, 'Par membre', theme),
                const SizedBox(width: 8),
                _sortChip(_WishSort.birthday, 'Anniversaire', theme),
                const SizedBox(width: 8),
                _sortChip(_WishSort.wishCount, 'Nb d\'envies', theme),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Wish feed
        if (memberWishes.isEmpty)
          _buildEmptyState(theme)
        else
          ...memberWishes.map((entry) {
            final (contact, wishes) = entry;
            return _buildMemberWishSection(context, contact, wishes, theme, state, surpriseMode);
          }),
      ],
    );
  }

  Widget _sortChip(_WishSort sort, String label, PigioThemeData theme) {
    final active = _sort == sort;
    return GestureDetector(
      onTap: () => setState(() => _sort = sort),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? theme.accent2 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? theme.accent2 : theme.divider, width: 1.5),
        ),
        child: Text(
          label,
          style: fw(size: 13, w: FontWeight.w700, color: active ? theme.onAccent : theme.mid),
        ),
      ),
    );
  }

  Widget _buildEmptyState(PigioThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CustomPaint(
            size: const Size(64, 64),
            painter: PigioPainter(mood: PigMood.searching, scarfColor: theme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            "Aucune envie dans ce cercle",
            style: fw(size: 15, w: FontWeight.w800, color: theme.ink),
          ),
          const SizedBox(height: 4),
          Text(
            "Les envies des membres apparaitront ici.",
            style: fw(size: 13, w: FontWeight.w600, color: theme.mid),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMemberWishSection(
    BuildContext context,
    ContactProfile contact,
    List<Wish> wishes,
    PigioThemeData theme,
    PigioAppState state,
    bool surpriseMode,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Member header
          GestureDetector(
            onTap: () {
              state.recordProfileView(contact.id);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ContactProfileScreen(contact: contact)));
            },
            child: Row(
              children: [
                PigioAvatar(
                  name: contact.name,
                  size: 28,
                  avatarIcon: contact.avatarIcon,
                  avatarColor: contact.avatarColor,
                  ringColor: contact.color,
                ),
                const SizedBox(width: 10),
                Text(
                  contact.name,
                  style: fw(size: 14, w: FontWeight.w800, color: theme.ink),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${wishes.length}",
                    style: fw(size: 11, w: FontWeight.w800, color: theme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Wish grid with reserve action
          SmartMasonryGrid(
            estimatedHeights: wishes
                .map((w) => WishCard.estimateHeight(
                      w,
                      hasCustomAction: w.reservedById == null || w.reservedById == 'self',
                    ))
                .toList(),
            children: wishes.map((w) {
              final canReserve = w.reservedById == null;
              final selfReserved = w.reservedById == 'self';
              return WishCard(
                wish: w,
                theme: theme,
                surpriseMode: surpriseMode,
                isMine: false,
                onTap: () {
                  state.recordProfileView(contact.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ContactProfileScreen(contact: contact)),
                  );
                },
                customAction: canReserve
                    ? PigioButton(
                        label: "Réserver 🎁",
                        color: theme.success,
                        textColor: theme.onAccent,
                        onTap: () {
                          state.toggleReserveWish(w.id, 'self');
                          setState(() {});
                        },
                        fullWidth: true,
                        height: 38,
                        fontSize: 13,
                      )
                    : selfReserved
                        ? PigioButton(
                            label: "Annuler réservation",
                            color: theme.mid.withValues(alpha: 0.12),
                            textColor: theme.mid,
                            onTap: () {
                              state.toggleReserveWish(w.id, 'self');
                              setState(() {});
                            },
                            fullWidth: true,
                            height: 38,
                            fontSize: 13,
                          )
                        : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
