import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/i18n/i18n.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';

class GiftPotEditorSheet extends StatefulWidget {
  /// If provided, pre-selects this contact as recipient.
  final String? preselectedContactId;

  /// If provided, pre-links this wish.
  final Wish? preselectedWish;

  const GiftPotEditorSheet({
    super.key,
    this.preselectedContactId,
    this.preselectedWish,
  });

  @override
  State<GiftPotEditorSheet> createState() => _GiftPotEditorSheetState();
}

class _GiftPotEditorSheetState extends State<GiftPotEditorSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedContactId;
  Wish? _selectedWish;
  bool _isCustomGift = false;
  GiftPotMode _mode = GiftPotMode.amount;
  bool _isSurprise = true;
  final Set<String> _invitedIds = {};

  @override
  void initState() {
    super.initState();
    _selectedContactId = widget.preselectedContactId;
    if (widget.preselectedWish != null) {
      _selectedWish = widget.preselectedWish;
      _titleController.text = widget.preselectedWish!.title;
      _selectedContactId ??= widget.preselectedWish!.contactId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _titleController.text.trim().isNotEmpty &&
      _selectedContactId != null &&
      (_amountController.text.isNotEmpty &&
          double.tryParse(_amountController.text) != null &&
          double.parse(_amountController.text) > 0);

  void _submit() {
    if (!_isValid) return;
    final state = context.read<PigioAppState>();
    state.createGiftPot(
      title: _titleController.text.trim(),
      description:
          _isCustomGift ? _descriptionController.text.trim() : null,
      wishId: _selectedWish?.id,
      recipientContactId: _selectedContactId!,
      mode: _mode,
      targetAmount: double.parse(_amountController.text),
      isSurprise: _isSurprise,
      invitedContactIds: _invitedIds.toList(),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.read<PigioAppState>();
    final contacts = state.contacts;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: BoxDecoration(
        color: theme.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t(context, 'pot_new'),
                    style: fw(size: 20, w: FontWeight.w900, color: theme.ink),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: theme.mid),
                ),
              ],
            ),
          ),
          Divider(color: theme.divider, height: 1),
          // Scrollable form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Recipient
                  _sectionLabel(t(context, 'pot_for'), theme),
                  const SizedBox(height: 8),
                  _buildContactPicker(contacts, theme),
                  const SizedBox(height: 20),

                  // 2. Gift source toggle
                  _sectionLabel(
                    _isCustomGift
                        ? t(context, 'pot_gift_source_custom')
                        : t(context, 'pot_gift_source_wish'),
                    theme,
                  ),
                  const SizedBox(height: 8),
                  _buildSourceToggle(theme),
                  const SizedBox(height: 12),
                  if (_isCustomGift) ...[
                    _buildTextField(
                        _titleController, 'Titre du cadeau', theme),
                    const SizedBox(height: 10),
                    _buildTextField(_descriptionController,
                        t(context, 'pot_description_hint'), theme,
                        maxLines: 3),
                  ] else ...[
                    _buildWishPicker(state, theme),
                  ],
                  const SizedBox(height: 20),

                  // 3. Mode
                  _sectionLabel('Mode', theme),
                  const SizedBox(height: 8),
                  _buildModeChips(theme),
                  const SizedBox(height: 20),

                  // 4. Amount
                  _sectionLabel(t(context, 'pot_amount_label'), theme),
                  const SizedBox(height: 8),
                  _buildTextField(_amountController, '0', theme,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 20),

                  // 5. Surprise toggle
                  _buildSurpriseToggle(theme),
                  const SizedBox(height: 20),

                  // 6. Invite contributors
                  _sectionLabel(t(context, 'pot_invite_members'), theme),
                  const SizedBox(height: 8),
                  _buildContributorList(contacts, theme),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // Submit button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isValid ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent2,
                  foregroundColor: theme.onAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text(
                  t(context, 'create_pot'),
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, PigioThemeData theme) {
    return Text(
      text,
      style: fw(size: 14, w: FontWeight.w800, color: theme.mid),
    );
  }

  Widget _buildContactPicker(
      List<ContactProfile> contacts, PigioThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: contacts.map((c) {
        final selected = _selectedContactId == c.id;
        return ChoiceChip(
          label: Text(c.name),
          selected: selected,
          selectedColor: theme.accent2.withValues(alpha: 0.25),
          backgroundColor: theme.surface,
          labelStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: selected ? theme.accent2 : theme.ink,
          ),
          side: BorderSide(
            color: selected ? theme.accent2 : theme.divider,
          ),
          onSelected: (_) {
            setState(() {
              _selectedContactId = c.id;
              _selectedWish = null;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildSourceToggle(PigioThemeData theme) {
    return Row(
      children: [
        _togglePill(
          t(context, 'pot_gift_source_wish'),
          !_isCustomGift,
          theme,
          () => setState(() => _isCustomGift = false),
        ),
        const SizedBox(width: 10),
        _togglePill(
          t(context, 'pot_gift_source_custom'),
          _isCustomGift,
          theme,
          () => setState(() {
            _isCustomGift = true;
            _selectedWish = null;
          }),
        ),
      ],
    );
  }

  Widget _togglePill(
      String label, bool active, PigioThemeData theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? theme.accent2 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? theme.accent2 : theme.divider,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: fw(
            size: 13,
            w: FontWeight.w800,
            color: active ? theme.onAccent : theme.mid,
          ),
        ),
      ),
    );
  }

  Widget _buildWishPicker(PigioAppState state, PigioThemeData theme) {
    if (_selectedContactId == null) {
      return Text(
        'Sélectionnez d\'abord un destinataire',
        style: GoogleFonts.nunito(
            fontSize: 13, color: theme.mid, fontStyle: FontStyle.italic),
      );
    }
    final wishes = state.getWishesFor(_selectedContactId);
    if (wishes.isEmpty) {
      return Text(
        'Aucune envie trouvée — passez en mode personnalisé',
        style: GoogleFonts.nunito(
            fontSize: 13, color: theme.mid, fontStyle: FontStyle.italic),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: wishes.map((w) {
        final selected = _selectedWish?.id == w.id;
        return ChoiceChip(
          label: Text('${w.emoji} ${w.title}'),
          selected: selected,
          selectedColor: theme.accent2.withValues(alpha: 0.25),
          backgroundColor: theme.surface,
          labelStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? theme.accent2 : theme.ink,
          ),
          side: BorderSide(
            color: selected ? theme.accent2 : theme.divider,
          ),
          onSelected: (_) {
            setState(() {
              _selectedWish = w;
              _titleController.text = w.title;
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildModeChips(PigioThemeData theme) {
    return Row(
      children: [
        _togglePill(
          t(context, 'pot_mode_amount'),
          _mode == GiftPotMode.amount,
          theme,
          () => setState(() => _mode = GiftPotMode.amount),
        ),
        const SizedBox(width: 10),
        _togglePill(
          t(context, 'pot_mode_share'),
          _mode == GiftPotMode.share,
          theme,
          () => setState(() => _mode = GiftPotMode.share),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    PigioThemeData theme, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GoogleFonts.nunito(color: theme.ink),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.nunito(color: theme.light),
        filled: true,
        fillColor: theme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.accent2, width: 2),
        ),
      ),
    );
  }

  Widget _buildSurpriseToggle(PigioThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.divider),
      ),
      child: Row(
        children: [
          const Text('🤫', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(context, 'pot_surprise'),
                  style: fw(size: 14, w: FontWeight.w800, color: theme.ink),
                ),
                Text(
                  t(context, 'pot_surprise_desc'),
                  style: GoogleFonts.nunito(fontSize: 12, color: theme.mid),
                ),
              ],
            ),
          ),
          Switch(
            value: _isSurprise,
            activeTrackColor: theme.accent2,
            onChanged: (v) => setState(() => _isSurprise = v),
          ),
        ],
      ),
    );
  }

  Widget _buildContributorList(
      List<ContactProfile> contacts, PigioThemeData theme) {
    // Exclude recipient from potential contributors if surprise
    final eligible = contacts.where((c) {
      if (_isSurprise && c.id == _selectedContactId) return false;
      return c.id != _selectedContactId;
    }).toList();

    if (eligible.isEmpty) {
      return Text(
        'Ajoutez des contacts pour les inviter',
        style: GoogleFonts.nunito(
            fontSize: 13, color: theme.mid, fontStyle: FontStyle.italic),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: eligible.map((c) {
        final selected = _invitedIds.contains(c.id);
        return FilterChip(
          label: Text(c.name),
          selected: selected,
          selectedColor: theme.accent4.withValues(alpha: 0.25),
          backgroundColor: theme.surface,
          checkmarkColor: theme.accent4,
          labelStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            color: selected ? theme.accent4 : theme.ink,
          ),
          side: BorderSide(
            color: selected ? theme.accent4 : theme.divider,
          ),
          onSelected: (v) {
            setState(() {
              if (v) {
                _invitedIds.add(c.id);
              } else {
                _invitedIds.remove(c.id);
              }
            });
          },
        );
      }).toList(),
    );
  }
}
