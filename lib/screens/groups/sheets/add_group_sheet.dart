import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';
import 'package:pigio_app/core/i18n/i18n.dart';

class AddGroupSheet extends StatefulWidget {
  final List<String>? preSelectedContactIds;
  const AddGroupSheet({super.key, this.preSelectedContactIds});

  @override
  State<AddGroupSheet> createState() => _AddGroupSheetState();
}

class _AddGroupSheetState extends State<AddGroupSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  String _selectedEmoji = '👥';
  late final List<String> _selectedMembers;
  String _memberSearch = '';
  String? _nameError;
  TrustLevel _selectedTrustLevel = TrustLevel.friend;

  final List<String> _emojis = ['👥', '🏠', '🎁', '⚡', '🌟', '💖', '👔', '🍕', '🎉', '✈️'];

  @override
  void initState() {
    super.initState();
    _selectedMembers = List<String>.from(widget.preSelectedContactIds ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final state = Provider.of<PigioAppState>(context, listen: false);

    // Case-insensitive duplicate check
    final alreadyExists = state.groups.any(
      (g) => g.name.toLowerCase() == name.toLowerCase(),
    );
    if (alreadyExists) {
      setState(() => _nameError = t(context, 'circle_duplicate').replaceAll('\$name', name));
      return;
    }

    state.addGroup(
      name,
      _selectedEmoji,
      _selectedMembers,
      trustLevel: _selectedTrustLevel,
    );

    Navigator.pop(context);
  }


  Widget _trustChip(String title, TrustLevel level, PigioThemeData theme) {
    bool isSel = _selectedTrustLevel == level;
    return GestureDetector(
      onTap: () => setState(() => _selectedTrustLevel = level),
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

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context);
    final contacts = state.contacts;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: theme.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: theme.mid.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 24),
            Text("Créer un Cercle", style: fw(size: 24, w: FontWeight.w900, color: theme.ink)),
            const SizedBox(height: 8),
            Text("Organisez vos proches par groupes pour plus de clarté.", style: fw(size: 14, w: FontWeight.w600, color: theme.mid)),
            const SizedBox(height: 24),

            // Emoji & Name Row
            Row(
              children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
                  alignment: Alignment.center,
                  child: Text(_selectedEmoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
                    child: TextField(
                      controller: _nameCtrl,
                      onChanged: (_) {
                        if (_nameError != null) setState(() => _nameError = null);
                      },
                      style: fw(size: 16, w: FontWeight.w700, color: theme.ink),
                      decoration: InputDecoration(
                        hintText: "Nom du groupe (ex: Amis)",
                        hintStyle: fw(size: 16, w: FontWeight.w500, color: theme.light),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                )
              ],
            ),
          const SizedBox(height: 20),
          
            if (_nameError != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 70),
                child: Text(_nameError!, style: fw(size: 12, w: FontWeight.w600, color: theme.error)),
              ),
            ],
            const SizedBox(height: 16),
            
            // Emoji Picker list
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _emojis.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = _emojis[index]),
                  child: Container(
                    width: 40, margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _selectedEmoji == _emojis[index] ? theme.primary.withValues(alpha: 0.1) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: _selectedEmoji == _emojis[index] ? Border.all(color: theme.primary) : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(_emojis[index], style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Trust Level
            Row(
              children: [
                _trustChip('Amis', TrustLevel.friend, theme),
                const SizedBox(width: 8),
                _trustChip('Famille', TrustLevel.family, theme),
                const SizedBox(width: 8),
                _trustChip('Public', TrustLevel.public_, theme),
              ],
            ),
            const SizedBox(height: 24),

            // Membres Header & Search
            Row(
              children: [
                Text("Membres", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                const Spacer(),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      onChanged: (v) => setState(() => _memberSearch = v),
                      style: fw(size: 13, w: FontWeight.w600, color: theme.ink),
                      decoration: InputDecoration(
                        hintText: "Rechercher...",
                        hintStyle: fw(size: 13, w: FontWeight.w500, color: theme.light),
                        icon: Icon(Icons.search, size: 16, color: theme.mid),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.only(bottom: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Recent Profiles Bubble Row (Ajout Rapide)
            if (_memberSearch.isEmpty && state.recentProfiles.isNotEmpty) ...[
              SizedBox(
                height: 72,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.recentProfiles.length,
                  itemBuilder: (_, index) {
                    final cId = state.recentProfiles[index];
                    final c = state.contacts.where((c) => c.id == cId).firstOrNull;
                    if (c == null) return const SizedBox.shrink();
                    final isSelected = _selectedMembers.contains(c.id);
                    
                    return GestureDetector(
                      onTap: () => setState(() {
                        isSelected ? _selectedMembers.remove(c.id) : _selectedMembers.add(c.id);
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              children: [
                                PigioAvatar(name: c.name, size: 48, avatarIcon: c.avatarIcon, avatarColor: c.avatarColor, ringColor: isSelected ? theme.success : c.color),
                                if (isSelected)
                                  Positioned(
                                    bottom: 0, right: 0,
                                    child: Container(
                                      width: 16, height: 16,
                                      decoration: BoxDecoration(color: theme.success, shape: BoxShape.circle, border: Border.all(color: theme.sheet, width: 2)),
                                      child: const Icon(Icons.check, size: 10, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(c.name.split(' ').first, style: fw(size: 10, w: FontWeight.w700, color: theme.mid)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            Expanded(
              child: Builder(builder: (_) {
                final filteredContacts = contacts.where((c) => _memberSearch.isEmpty || c.name.toLowerCase().contains(_memberSearch.toLowerCase())).toList();
                
                if (filteredContacts.isEmpty) {
                  return Center(child: Text("Aucun contact trouvé", style: fw(size: 13, color: theme.mid)));
                }

                return ListView.builder(
                  itemCount: filteredContacts.length,
                  itemBuilder: (context, index) {
                    final c = filteredContacts[index];
                    final isSelected = _selectedMembers.contains(c.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedMembers.add(c.id);
                          } else {
                            _selectedMembers.remove(c.id);
                          }
                        });
                      },
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(c.name, style: fw(size: 15, w: FontWeight.w700, color: theme.ink)),
                          ),
                        ],
                      ),
                      subtitle: Text(c.role, style: fw(size: 12, color: theme.mid)),
                      secondary: PigioAvatar(name: c.name, size: 40, avatarIcon: c.avatarIcon, avatarColor: c.avatarColor, ringColor: c.color),
                      activeColor: theme.primary,
                      checkColor: theme.onAccent,
                      checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      contentPadding: EdgeInsets.zero,
                    );
                  },
                );
              }),
            ),
          const SizedBox(height: 24),
          PigioButton(label: "Créer le groupe", color: theme.primary, textColor: theme.onAccent, onTap: _save),
        ],
      ),
    ),
    );
  }
}
