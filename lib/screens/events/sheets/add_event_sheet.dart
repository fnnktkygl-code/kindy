import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';

void showAddEventSheet(
  BuildContext context, {
  VoidCallback? onAdded,
  String? initialTitle,
  String? initialEmoji,
  DateTime? initialDate,
  bool initialRecurring = false,
  String? initialContactId,
  String? initialGroupId,
  String? initialTypeEn,
  String? initialTypeFr,
}) {
  final theme = context.ptnl;
  final navigator = Navigator.of(context, rootNavigator: false);

  showModalBottomSheet<void>(
    context: navigator.context,
    isScrollControlled: true,
    backgroundColor: theme.sheet,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (ctx) => AddEventSheet(
      onAdded: onAdded,
      initialTitle: initialTitle,
      initialEmoji: initialEmoji,
      initialDate: initialDate,
      initialRecurring: initialRecurring,
      initialContactId: initialContactId,
      initialGroupId: initialGroupId,
      initialTypeEn: initialTypeEn,
      initialTypeFr: initialTypeFr,
    ),
  );
}

class AddEventSheet extends StatefulWidget {
  final VoidCallback? onAdded;
  final String? initialTitle;
  final String? initialEmoji;
  final DateTime? initialDate;
  final bool initialRecurring;
  final String? initialContactId;
  final String? initialGroupId;
  final String? initialTypeEn;
  final String? initialTypeFr;

  const AddEventSheet({
    super.key,
    this.onAdded,
    this.initialTitle,
    this.initialEmoji,
    this.initialDate,
    this.initialRecurring = false,
    this.initialContactId,
    this.initialGroupId,
    this.initialTypeEn,
    this.initialTypeFr,
  });

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emojiCtrl;
  late DateTime _selectedDate;
  bool _isRecurring = false;
  String? _selectedContactId;
  String? _selectedGroupId;
  late String? _fixedTypeEn;
  late String? _fixedTypeFr;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _emojiCtrl = TextEditingController(text: widget.initialEmoji ?? '🎉');
    _selectedDate = widget.initialDate ?? DateTime.now().add(const Duration(days: 7));
    _isRecurring = widget.initialRecurring;
    _selectedContactId = widget.initialContactId;
    _selectedGroupId = widget.initialGroupId;
    _fixedTypeEn = widget.initialTypeEn;
    _fixedTypeFr = widget.initialTypeFr;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  void _save(PigioAppState state) {
    if (_nameCtrl.text.trim().isEmpty) return;
    state.addEvent(
      title: _nameCtrl.text.trim(),
      date: _selectedDate,
      isRecurring: _isRecurring,
      emoji: _emojiCtrl.text.trim().isEmpty ? '🎉' : _emojiCtrl.text.trim(),
      typeFr: _fixedTypeFr ?? _nameCtrl.text.trim(),
      typeEn: _fixedTypeEn ?? _nameCtrl.text.trim(),
      contactId: _selectedContactId,
    );
    Navigator.pop(context);
    widget.onAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context, listen: false);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(context).viewInsets.bottom + 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.divider, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text("Nouvel événement", style: fw(size: 22, w: FontWeight.w900, color: theme.ink)),
          const SizedBox(height: 20),
          
          // Name
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: _nameCtrl,
              style: fw(size: 16, w: FontWeight.w600, color: theme.ink),
              decoration: InputDecoration(
                hintText: "Nom de l'événement",
                hintStyle: fw(size: 16, w: FontWeight.w500, color: theme.light),
                border: InputBorder.none,
                icon: Icon(Icons.event, color: theme.mid),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Emoji
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: _emojiCtrl,
              style: const TextStyle(fontSize: 24),
              decoration: InputDecoration(
                hintText: "Emoji",
                hintStyle: fw(size: 16, w: FontWeight.w500, color: theme.light),
                border: InputBorder.none,
                icon: Icon(Icons.emoji_emotions, color: theme.mid),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Date
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: theme.isDark 
                        ? ColorScheme.dark(
                            primary: theme.primary, 
                            onPrimary: theme.onAccent,
                            surface: theme.card,
                            onSurface: theme.ink,
                          )
                        : ColorScheme.light(
                            primary: theme.primary,
                            onPrimary: theme.onAccent,
                            surface: theme.card,
                            onSurface: theme.ink,
                          ),
                      textButtonTheme: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.primary, 
                        ),
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: theme.mid, size: 20),
                  const SizedBox(width: 14),
                  Text(
                    "${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}",
                    style: fw(size: 16, w: FontWeight.w700, color: theme.ink),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Recurring toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(Icons.repeat, color: theme.mid, size: 20),
                const SizedBox(width: 14),
                Expanded(child: Text("Récurrent (chaque année)", style: fw(size: 14, w: FontWeight.w700, color: theme.ink))),
                Switch(
                  value: _isRecurring,
                  activeThumbColor: theme.primary,
                  onChanged: (val) => setState(() => _isRecurring = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Link to Contact or Group
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.link, color: theme.mid, size: 20),
                    const SizedBox(width: 14),
                    Text("Lier à", style: fw(size: 14, w: FontWeight.w700, color: theme.ink)),
                  ],
                ),
                const SizedBox(height: 12),
                // Contact selector
                _buildContactSelector(state, theme),
                const SizedBox(height: 8),
                // Group selector
                _buildGroupSelector(state, theme),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          PigioButton(
            label: "Créer",
            icon: Icons.check,
            color: theme.primary,
            textColor: theme.onAccent,
            height: 52,
            fontSize: 16,
            onTap: () => _save(state),
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildContactSelector(PigioAppState state, PigioThemeData theme) {
    final contacts = state.contacts;
    if (contacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () async {
        // Show contact picker dialog
        final selected = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.card,
            title: Text("Choisir un contact", style: fw(size: 18, w: FontWeight.w900, color: theme.ink)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: Text("Aucun contact", style: fw(size: 15, w: FontWeight.w600, color: theme.mid)),
                    onTap: () => Navigator.pop(ctx, 'none'),
                  ),
                  ...contacts.map((c) => ListTile(
                    title: Text(c.name, style: fw(size: 15, w: FontWeight.w700, color: theme.ink)),
                    trailing: _selectedContactId == c.id ? Icon(Icons.check, color: theme.primary) : null,
                    onTap: () => Navigator.pop(ctx, c.id),
                  )),
                ],
              ),
            ),
          ),
        );
        
        if (selected != null) {
          setState(() {
            if (selected == 'none') {
              _selectedContactId = null;
            } else {
              _selectedContactId = selected;
              _selectedGroupId = null; // Clear group if contact selected
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _selectedContactId != null ? theme.primary.withValues(alpha: 0.1) : theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedContactId != null ? theme.primary.withValues(alpha: 0.3) : theme.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person,
              size: 18,
              color: _selectedContactId != null ? theme.primary : theme.mid,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedContactId != null 
                  ? state.contacts.firstWhere((c) => c.id == _selectedContactId).name
                  : "Contact (optionnel)",
                style: fw(
                  size: 14,
                  w: _selectedContactId != null ? FontWeight.w700 : FontWeight.w600,
                  color: _selectedContactId != null ? theme.primary : theme.mid,
                ),
              ),
            ),
            Icon(
              _selectedContactId != null ? Icons.check_circle : Icons.chevron_right,
              size: 18,
              color: _selectedContactId != null ? theme.primary : theme.light,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSelector(PigioAppState state, PigioThemeData theme) {
    final groups = state.groups.where((g) => !g.isSystem).toList();
    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () async {
        // Show group picker dialog
        final selected = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.card,
            title: Text("Choisir un cercle", style: fw(size: 18, w: FontWeight.w900, color: theme.ink)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    title: Text("Aucun cercle", style: fw(size: 15, w: FontWeight.w600, color: theme.mid)),
                    onTap: () => Navigator.pop(ctx, 'none'),
                  ),
                  ...groups.map((g) => ListTile(
                    leading: Text(g.emoji, style: const TextStyle(fontSize: 20)),
                    title: Text(g.name, style: fw(size: 15, w: FontWeight.w700, color: theme.ink)),
                    trailing: _selectedGroupId == g.id ? Icon(Icons.check, color: theme.primary) : null,
                    onTap: () => Navigator.pop(ctx, g.id),
                  )),
                ],
              ),
            ),
          ),
        );
        
        if (selected != null) {
          setState(() {
            if (selected == 'none') {
              _selectedGroupId = null;
            } else {
              _selectedGroupId = selected;
              _selectedContactId = null; // Clear contact if group selected
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _selectedGroupId != null ? theme.accent2.withValues(alpha: 0.1) : theme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedGroupId != null ? theme.accent2.withValues(alpha: 0.3) : theme.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.group,
              size: 18,
              color: _selectedGroupId != null ? theme.accent2 : theme.mid,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _selectedGroupId != null 
                  ? "${state.groups.firstWhere((g) => g.id == _selectedGroupId).emoji} ${state.groups.firstWhere((g) => g.id == _selectedGroupId).name}"
                  : "Cercle (optionnel)",
                style: fw(
                  size: 14,
                  w: _selectedGroupId != null ? FontWeight.w700 : FontWeight.w600,
                  color: _selectedGroupId != null ? theme.accent2 : theme.mid,
                ),
              ),
            ),
            Icon(
              _selectedGroupId != null ? Icons.check_circle : Icons.chevron_right,
              size: 18,
              color: _selectedGroupId != null ? theme.accent2 : theme.light,
            ),
          ],
        ),
      ),
    );
  }
}

