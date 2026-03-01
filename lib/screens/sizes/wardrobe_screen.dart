import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';

import 'package:pigio_app/core/i18n/i18n.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';
import 'package:pigio_app/screens/sizes/sheets/size_editor_sheet.dart';

class WardrobeScreen extends StatefulWidget {
  final bool isOwnList;
  const WardrobeScreen({super.key, this.isOwnList = true});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  String? _flash;

  static const _categoryOrder = ['clothes', 'bottoms', 'shoes'];

  Map<String, Map<String, dynamic>> _getMeta(PigioThemeData theme) => {
    'clothes': {
      'emoji': '👕',
      'bg': theme.primary.withValues(alpha: 0.15),
      'visColor': theme.primary,
      'fields': ['standard', 'eu_clothes'],
      'fits': ['slim', 'regular', 'oversized'],
    },
    'bottoms': {
      'emoji': '👖',
      'bg': theme.success.withValues(alpha: 0.15),
      'visColor': theme.success,
      'fields': ['eu_bottoms', 'us_waist', 'standard'],
      'fits': ['skinny', 'straight', 'relaxed'],
    },
    'shoes': {
      'emoji': '👟',
      'bg': theme.accent3.withValues(alpha: 0.15),
      'visColor': theme.accent3,
      'fields': ['eu_shoes', 'us_shoes', 'uk_shoes', 'cm_shoes'],
      'fits': ['regular'],
    },
  };

  List<String> _getChips(SizeProfile? profile, String key) {
    if (profile == null) return [];
    final v = profile.values;
    final chips = <String>[];
    if (key == 'clothes') {
      if (v['standard'] != null) chips.add(v['standard']!);
      if (v['eu_clothes'] != null) chips.add('EU ${v['eu_clothes']!}');
    } else if (key == 'bottoms') {
      if (v['eu_bottoms'] != null) chips.add('EU ${v['eu_bottoms']!}');
      if (v['us_waist'] != null && v['us_length'] != null) {
        chips.add('W${v['us_waist']} L${v['us_length']}');
      } else if (v['us_waist'] != null) {
        chips.add('W${v['us_waist']}');
      }
      if (v['standard'] != null) chips.add(v['standard']!);
    } else if (key == 'shoes') {
      if (v['eu_shoes'] != null) chips.add('EU ${v['eu_shoes']!}');
      if (v['cm_shoes'] != null) chips.add('${v['cm_shoes']}cm');
      if (v['us_shoes'] != null) chips.add('${v['us_shoes']} US');
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final sizes = state.getSizesFor(null);
    final filledCount = _categoryOrder
        .where((k) => sizes.any((s) => s.categoryKey == k))
        .length;

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: PigioAppBar(
        title: t(context, 'sizes_title'),
        showBack: !widget.isOwnList,
        autoShowBackFromCanPop: !widget.isOwnList,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero / completion card ──
              _HeroCard(
                state: state,
                theme: theme,
                filledCount: filledCount,
                flash: _flash,
              ),

              // ── Category cards ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  children: [
                    for (final key in _categoryOrder) ...[
                      if (key != _categoryOrder.first) const SizedBox(height: 10),
                      _buildSizeCard(context, state, sizes, key, theme),
                    ],
                  ],
                ),
              ),

              // ── Contextual tip ──
              if (filledCount < 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _TipBanner(theme: theme, filledCount: filledCount),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizeCard(
    BuildContext context,
    PigioAppState state,
    List<SizeProfile> sizes,
    String key,
    PigioThemeData theme,
  ) {
    final meta = _getMeta(theme)[key]!;
    final color = meta['visColor'] as Color;
    final emoji = meta['emoji'] as String;
    final profile = sizes.where((s) => s.categoryKey == key).firstOrNull;
    final chips = _getChips(profile, key);
    final isEmpty = chips.isEmpty;

    return GestureDetector(
      onTap: () => _showEditor(state, key, theme),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isEmpty ? Colors.transparent : theme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isEmpty
                ? color.withValues(alpha: 0.25)
                : color.withValues(alpha: 0.14),
            width: isEmpty ? 1.5 : 1.0,
          ),
          boxShadow: isEmpty
              ? []
              : [
                  BoxShadow(
                    color: theme.ink.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Icon bubble
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isEmpty ? 0.07 : 0.11),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),

            // Category name + values
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(context, key),
                    style: fw(
                      size: 15,
                      w: FontWeight.w800,
                      color: isEmpty ? theme.mid : theme.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (isEmpty)
                    Text(
                      'Appuie pour ajouter',
                      style: fw(
                        size: 13,
                        w: FontWeight.w500,
                        color: color.withValues(alpha: 0.75),
                      ),
                    )
                  else ...[
                    // Size chip pills
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: chips.map((chip) => _SizeChip(label: chip, color: color)).toList(),
                    ),
                    // Fit preference
                    if (profile?.fitKey != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.straighten_rounded, size: 11, color: theme.light),
                          const SizedBox(width: 3),
                          Text(
                            t(context, profile!.fitKey!),
                            style: fw(size: 11, w: FontWeight.w600, color: theme.light),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Edit / add button
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isEmpty ? 0.1 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEmpty ? Icons.add_rounded : Icons.edit_rounded,
                color: color,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditor(
    PigioAppState state,
    String initialKey,
    PigioThemeData theme,
  ) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizeEditorSheet(
        state: state,
        initialCategoryKey: initialKey,
        allMeta: _getMeta(theme),
      ),
    );

    if (result == true && mounted) {
      setState(() => _flash = initialKey);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() { if (_flash == initialKey) _flash = null; });
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Hero card — avatar + three-segment progress bar
// ─────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final PigioAppState state;
  final PigioThemeData theme;
  final int filledCount;
  final String? flash;

  const _HeroCard({
    required this.state,
    required this.theme,
    required this.filledCount,
    required this.flash,
  });

  @override
  Widget build(BuildContext context) {
    final allDone = filledCount == 3;
    final isFlashing = flash != null;
    final segColors = [theme.primary, theme.success, theme.accent3];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isFlashing
            ? theme.accent3.withValues(alpha: 0.08)
            : allDone
                ? theme.success.withValues(alpha: 0.06)
                : theme.card,
        borderRadius: BorderRadius.circular(24),
        border: isFlashing
            ? Border.all(color: theme.accent3.withValues(alpha: 0.4), width: 1.5)
            : allDone
                ? Border.all(color: theme.success.withValues(alpha: 0.35), width: 1.5)
                : null,
        boxShadow: [
          BoxShadow(
            color: theme.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with optional completion badge
          Stack(
            children: [
              PigioAvatar(
                name: state.profile.name,
                size: 64,
                avatarIcon: state.profile.avatarIcon,
                avatarColor: state.profile.avatarColor,
              ),
              if (allDone)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: theme.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.card, width: 2),
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Name + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFlashing
                      ? '✨ Mis à jour !'
                      : (state.profile.name.isNotEmpty ? state.profile.name : 'Mes tailles'),
                  style: fw(
                    size: 17,
                    w: FontWeight.w800,
                    color: isFlashing ? theme.accent3 : theme.ink,
                  ),
                ),
                const SizedBox(height: 10),
                // Three-segment progress bar (one per category)
                Row(
                  children: List.generate(3, (i) {
                    final filled = i < filledCount;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 280 + i * 80),
                        curve: Curves.easeOut,
                        margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                        height: 6,
                        decoration: BoxDecoration(
                          color: filled ? segColors[i] : theme.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 7),
                Text(
                  allDone
                      ? 'Profil complet — tes cercles peuvent te faire plaisir 🎁'
                      : '$filledCount / 3 catégories renseignées',
                  style: fw(
                    size: 12,
                    w: FontWeight.w600,
                    color: allDone ? theme.success : theme.mid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Size chip pill widget
// ─────────────────────────────────────────────────────────────

class _SizeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SizeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: fw(size: 13, w: FontWeight.w800, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Contextual tip / nudge banner
// ─────────────────────────────────────────────────────────────

class _TipBanner extends StatelessWidget {
  final PigioThemeData theme;
  final int filledCount;
  const _TipBanner({required this.theme, required this.filledCount});

  @override
  Widget build(BuildContext context) {
    final msg = filledCount == 0
        ? 'Renseigne tes tailles pour que tes proches sachent quoi t\'offrir !'
        : 'Plus tu renseignes, mieux tes cercles peuvent choisir un cadeau parfait.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: fw(size: 13, w: FontWeight.w500, color: theme.mid),
            ),
          ),
        ],
      ),
    );
  }
}
