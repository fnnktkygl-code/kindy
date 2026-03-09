import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/core/i18n/i18n.dart';
import 'group_members_section.dart';
import 'group_wish_feed_section.dart';
import 'group_polls_section.dart';

class GroupDetailSheet extends StatefulWidget {
  final CircleGroup group;
  const GroupDetailSheet({super.key, required this.group});

  @override
  State<GroupDetailSheet> createState() => _GroupDetailSheetState();
}

class _GroupDetailSheetState extends State<GroupDetailSheet> {
  late TextEditingController _nameCtrl;
  late String _emoji;
  late TrustLevel _trustLevel;
  bool _isEditing = false;
  String _selectedTab = 'envies';

  static const _emojis = ['🏠', '❤️', '🎉', '💼', '⚽', '🎵', '🎮', '📚', '🌟', '👫', '🎂', '💎', '🏆', '🎯', '🌈', '🔥'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.group.name);
    _emoji = widget.group.emoji;
    _trustLevel = widget.group.trustLevel;
  }

  void _saveChanges(PigioAppState state) {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'circle_name_empty'))),
      );
      return;
    }
    state.updateGroup(
      widget.group.id,
      name: _nameCtrl.text.trim(),
      emoji: _emoji,
      trustLevel: _trustLevel,
    );
    setState(() => _isEditing = false);
  }

  Future<void> _shareGroupInviteLink(PigioAppState state, CircleGroup group, PigioThemeData theme, {required bool copyOnly}) async {
    try {
      final link = await state.createGroupInviteLink(group.id, channel: copyOnly ? InviteChannel.copyLink : InviteChannel.whatsApp);
      if (link == null || link.isEmpty) {
        throw Exception('Lien vide');
      }
      if (copyOnly) {
        await Clipboard.setData(ClipboardData(text: link));
      } else {
        await SharePlus.instance.share(
          ShareParams(text: 'Invitation cercle ${group.name}: $link', title: 'Invitation cercle ${group.name}'),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copyOnly ? 'Lien copié.' : 'Lien prêt à partager.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Widget _trustChip(String title, TrustLevel level, PigioThemeData theme) {
    bool isSel = _trustLevel == level;
    return GestureDetector(
      onTap: () => setState(() => _trustLevel = level),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? theme.primary.withValues(alpha: 0.1) : theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSel ? theme.primary : Colors.transparent),
        ),
        child: Text(title, style: fw(size: 13, w: isSel ? FontWeight.w800 : FontWeight.w600, color: isSel ? theme.primary : theme.mid)),
      ),
    );
  }

  Widget _buildTab(String id, String label, PigioThemeData theme) {
    final active = _selectedTab == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? theme.accent2 : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? theme.accent2 : theme.divider,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: fw(size: 14, w: FontWeight.w800, color: active ? theme.onAccent : theme.mid),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context);
    final group = state.groups.where((g) => g.id == widget.group.id).firstOrNull ?? widget.group;
    final members = state.contacts.where((c) => group.contactIds.contains(c.id)).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: theme.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.divider, borderRadius: BorderRadius.circular(2))),
          ),
          Flexible(
            child: CustomScrollView(
              shrinkWrap: true,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (group.isSystem) return;
                                if (!_isEditing) setState(() => _isEditing = true);
                                _showEmojiPicker(context, state, group, theme);
                              },
                              child: Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: theme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  border: _isEditing ? Border.all(color: theme.primary.withValues(alpha: 0.3)) : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(_emoji, style: const TextStyle(fontSize: 30)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _isEditing
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(14)),
                                      child: TextField(
                                        controller: _nameCtrl,
                                        autofocus: true,
                                        style: fw(size: 20, w: FontWeight.w900, color: theme.ink),
                                        decoration: const InputDecoration(border: InputBorder.none),
                                        onSubmitted: (_) => _saveChanges(state),
                                      ),
                                    )
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(group.name, style: fw(size: 22, w: FontWeight.w900, color: theme.ink)),
                                        Text("${members.length} membres", style: fw(size: 13, w: FontWeight.w600, color: theme.mid)),
                                      ],
                                    ),
                            ),
                            if (!_isEditing && !group.isSystem)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => _shareGroupInviteLink(state, group, theme, copyOnly: true),
                                    child: Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(12)),
                                      child: Icon(Icons.link, color: theme.accent4, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _shareGroupInviteLink(state, group, theme, copyOnly: false),
                                    child: Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(12)),
                                      child: Icon(Icons.share_outlined, color: theme.primary, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(() => _isEditing = true),
                                    child: Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(12)),
                                      child: Icon(Icons.edit, color: theme.mid, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        if (_isEditing && !group.isSystem) ...[
                          const SizedBox(height: 20),
                          Text("CONFIDENTIALITÉ", style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2)),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _trustChip('Amis', TrustLevel.friend, theme),
                                const SizedBox(width: 8),
                                _trustChip('Famille', TrustLevel.family, theme),
                                const SizedBox(width: 8),
                                _trustChip('Public', TrustLevel.public_, theme),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () => _saveChanges(state),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(color: theme.primary, borderRadius: BorderRadius.circular(16)),
                              alignment: Alignment.center,
                              child: Text("Enregistrer", style: fw(size: 15, w: FontWeight.w800, color: theme.onAccent)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTab('envies', 'Envies', theme),
                        const SizedBox(width: 8),
                        _buildTab('membres', 'Membres', theme),
                        const SizedBox(width: 8),
                        _buildTab('sondages', 'Sondages', theme),
                      ],
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: _selectedTab == 'envies'
                        ? GroupWishFeedSection(group: group)
                        : _selectedTab == 'membres'
                            ? GroupMembersSection(group: group)
                            : GroupPollsSection(group: group),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEmojiPicker(BuildContext context, PigioAppState state, CircleGroup group, PigioThemeData theme) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Choisir un emoji", style: fw(size: 18, w: FontWeight.w900, color: theme.ink)),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _emojis.map((e) => GestureDetector(
            onTap: () {
              setState(() => _emoji = e);
              Navigator.pop(ctx);
            },
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _emoji == e ? theme.primary.withValues(alpha: 0.15) : theme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _emoji == e ? theme.primary : theme.divider),
              ),
              alignment: Alignment.center,
              child: Text(e, style: const TextStyle(fontSize: 24)),
            ),
          )).toList(),
        ),
      ),
    );
  }

}