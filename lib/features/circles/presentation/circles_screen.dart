import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/pigio_painter.dart';
import '../../../shared/widgets/ui_widgets.dart';
import 'package:kindy/screens/groups/sheets/add_group_sheet.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'widgets/group_detail_sheet.dart';

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key});

  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context);
    final contacts = state.contacts;
    final groups = state.groups;

    List<CircleGroup> filteredGroups;
    if (_filter == 'all') {
      filteredGroups = groups;
    } else {
      final TrustLevel targetLevel;
      switch (_filter) {
        case 'family':
          targetLevel = TrustLevel.family;
        case 'friend':
          targetLevel = TrustLevel.friend;
        default:
          targetLevel = TrustLevel.public_;
      }
      filteredGroups = groups.where((g) => g.trustLevel == targetLevel).toList();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.accent4,
        elevation: 4,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => const AddGroupSheet(),
          );
        },
        icon: Icon(Icons.group_add, color: theme.onAccent, size: 22),
        label: Text("Nouveau Cercle", style: fw(size: 15, w: FontWeight.w800, color: theme.onAccent)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                _filterChip('all', 'Tous', '👥', theme),
                const SizedBox(width: 8),
                _filterChip('family', 'Famille', '🏠', theme),
                const SizedBox(width: 8),
                _filterChip('friend', 'Amis', '💚', theme),
                const SizedBox(width: 8),
                _filterChip('public', 'Public', '🌍', theme),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Row(
              children: [
                Text("${filteredGroups.length} cercle${filteredGroups.length != 1 ? 's' : ''}", style: fw(size: 13, w: FontWeight.w700, color: theme.mid)),
              ],
            ),
          ),
          Expanded(
            child: _buildGroupsList(filteredGroups, contacts),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String id, String label, String emoji, PigioThemeData theme) {
    final isActive = _filter == id;
    final chipColor = id == 'family' ? theme.success : id == 'friend' ? theme.primary : id == 'public' ? theme.mid : theme.ink;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? chipColor.withValues(alpha: 0.12) : theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isActive ? chipColor.withValues(alpha: 0.3) : Colors.transparent),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text(label, style: fw(size: 11, w: isActive ? FontWeight.w800 : FontWeight.w600, color: isActive ? chipColor : theme.mid)),
            ],
          ),
        ),
      ),
    );
  }

  // Returns days until the contact's next birthday, or 999 if unknown/hidden.
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
    } catch (e) {
      debugPrint('[Circles] Invalid birthdate for ${contact.name}: ${contact.birthdate}');
      return 999;
    }
  }

  Widget _statChip(String emoji, String label, Color color, PigioThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(label, style: fw(size: 11, w: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _buildGroupsList(List<CircleGroup> groups, List<ContactProfile> contacts) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context, listen: false);
    final allGroups = List<CircleGroup>.from(groups)
      ..sort((a, b) => a.isSystem ? -1 : b.isSystem ? 1 : 0);
    final suggestions = state.mascotCircleSuggestions;

    if (allGroups.isEmpty && suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(size: const Size(64, 64), painter: PigioPainter(mood: PigMood.searching, scarfColor: theme.primary)),
              const SizedBox(height: 16),
              Text(
                _filter == 'all' ? 'Aucun cercle' : 'Aucun cercle dans cette catégorie',
                style: fw(size: 18, w: FontWeight.w900, color: theme.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                _filter == 'all'
                    ? 'Créez votre premier cercle pour regrouper vos proches et gérer leurs envies ensemble.'
                    : 'Essayez un autre filtre ou créez un nouveau cercle.',
                style: fw(size: 13, w: FontWeight.w600, color: theme.mid),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 120),
      itemCount: allGroups.length + (suggestions.isNotEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (suggestions.isNotEmpty && index == 0) {
          return _buildSuggestionBanner(suggestions.first, state, theme);
        }
        final g = allGroups[suggestions.isNotEmpty ? index - 1 : index];
        final members = contacts.where((c) => g.contactIds.contains(c.id)).toList();
        final isSystem = g.isSystem;
        final customColor = isSystem ? null : theme.notionWarmColors[g.id.hashCode.abs() % theme.notionWarmColors.length];

        // Compute group stats for the stat chips
        int totalWishes = 0;
        int? nearestBirthday;
        for (final m in members) {
          totalWishes += state.getWishesFor(m.id).length;
          final days = _daysUntilBirthday(m);
          if (days <= 90 && (nearestBirthday == null || days < nearestBirthday)) {
            nearestBirthday = days;
          }
        }
        final activePolls = state.getActivePollsForGroup(g.id).length;

        return GestureDetector(
          onTap: () => _showGroupDetail(context, g, state),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: isSystem
                  ? LinearGradient(
                      colors: [theme.success.withValues(alpha: 0.08), theme.primary.withValues(alpha: 0.04)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [customColor!.withValues(alpha: 0.1), theme.surface.withValues(alpha: 0.5)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
              color: isSystem ? null : theme.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSystem ? theme.success.withValues(alpha: 0.3) : customColor!.withValues(alpha: 0.1),
                width: isSystem ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSystem ? theme.success.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
                      alignment: Alignment.center,
                      child: Text(g.emoji, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.name, style: fw(size: 18, w: FontWeight.w900, color: theme.ink)),
                          Text("${members.length} membres", style: fw(size: 13, w: FontWeight.w600, color: theme.mid)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: theme.light),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (members.isEmpty)
                      Row(
                        children: [
                          CustomPaint(size: const Size(36, 36), painter: PigioPainter(mood: PigMood.searching, scarfColor: theme.primary)),
                          const SizedBox(width: 8),
                          Text("Cercle vide", style: fw(size: 13, w: FontWeight.w700, color: theme.mid)),
                        ],
                      )
                    else
                      SizedBox(
                        height: 36,
                        width: members.length > 5
                            ? (4 * 24.0 + 36.0 + 36.0)
                            : ((members.length - 1) * 24.0 + 36.0),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ...List.generate(
                              members.length > 5 ? 5 : members.length,
                              (i) {
                                final m = members[i];
                                return Positioned(
                                  left: i * 24.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: theme.card, width: 2),
                                    ),
                                    child: PigioAvatar(name: m.name, size: 32, avatarIcon: m.avatarIcon, avatarColor: m.avatarColor, ringColor: m.color),
                                  ),
                                );
                              },
                            ),
                            if (members.length > 5)
                              Positioned(
                                left: 5 * 24.0,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(color: theme.surface, shape: BoxShape.circle, border: Border.all(color: theme.card, width: 2)),
                                  alignment: Alignment.center,
                                  child: Text("+${members.length - 5}", style: fw(size: 12, w: FontWeight.w800, color: theme.mid)),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                // Stats chips: wishes · polls · birthday
                if (totalWishes > 0 || activePolls > 0 || nearestBirthday != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (totalWishes > 0)
                        _statChip(
                          '🎁',
                          '$totalWishes envie${totalWishes > 1 ? 's' : ''}',
                          theme.accent2,
                          theme,
                        ),
                      if (activePolls > 0)
                        _statChip(
                          '📊',
                          '$activePolls sondage${activePolls > 1 ? 's' : ''}',
                          theme.accent4,
                          theme,
                        ),
                      if (nearestBirthday != null)
                        _statChip(
                          '🎂',
                          nearestBirthday == 0
                              ? "Auj!"
                              : "dans ${nearestBirthday}j",
                          nearestBirthday <= 7
                              ? theme.warning
                              : theme.primary,
                          theme,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionBanner(CircleGroup suggestion, PigioAppState state, PigioThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CustomPaint(size: const Size(40, 40), painter: PigioPainter(mood: PigMood.excited, scarfColor: theme.info)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Suggestion Pigio ✨", style: fw(size: 12, w: FontWeight.w900, color: theme.info, letterSpacing: 1.1)),
                const SizedBox(height: 4),
                Text("Créer le cercle ${suggestion.emoji} ${suggestion.name} ?", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                const SizedBox(height: 2),
                Text("${suggestion.contactIds.length} membres potentiels trouvés.", style: fw(size: 13, w: FontWeight.w600, color: theme.mid)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        state.addGroup(
                          suggestion.name,
                          suggestion.emoji,
                          suggestion.contactIds,
                          trustLevel: TrustLevel.friend,
                        );
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: theme.info, borderRadius: BorderRadius.circular(12)),
                        child: Text("Créer", style: fw(size: 13, w: FontWeight.w800, color: theme.onAccent)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupDetail(BuildContext ctx, CircleGroup group, PigioAppState state) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupDetailSheet(group: group),
    );
  }
}