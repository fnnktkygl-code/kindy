import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';
import 'package:pigio_app/shared/widgets/pigio_painter.dart';
import 'package:pigio_app/services/mascot_outfit_engine.dart';

// Per-slot accent colors — used in filter chips, slot dots, and item cards.
const _kSlotAccents = <ClothingSlot?, Color>{
  null: Color(0xFF337EA9),
  ClothingSlot.hat: Color(0xFFE63950),
  ClothingSlot.glasses: Color(0xFF4A6FE3),
  ClothingSlot.top: Color(0xFF1B8A4C), // Fixed: was 0xFF2ECC71 (WCAG AA fail)
  ClothingSlot.shoes: Color(0xFFFF9500),
  ClothingSlot.accessory: Color(0xFF9C6FE3),
};

const _kRarityColors = <ItemRarity, Color>{
  ItemRarity.common: Color(0xFF8B90B0),
  ItemRarity.uncommon: Color(0xFF4A6FE3),
  ItemRarity.rare: Color(0xFF9C6FE3),
  ItemRarity.legendary: Color(0xFFFFAA00),
};

const _kItemColors = <Color>[
  Color(0xFFFFD54F), // Yellow (default)
  Color(0xFFFF7043), // Orange
  Color(0xFFEF5350), // Red
  Color(0xFFEC407A), // Pink
  Color(0xFFAB47BC), // Purple
  Color(0xFF42A5F5), // Blue
  Color(0xFF26A69A), // Teal
  Color(0xFF66BB6A), // Green
];

const _kSlotFilters = <({String label, String emoji, ClothingSlot? slot})>[
  (label: 'Tout', emoji: '✨', slot: null),
  (label: 'Têtes', emoji: '🎩', slot: ClothingSlot.hat),
  (label: 'Lunettes', emoji: '👓', slot: ClothingSlot.glasses),
  (label: 'Hauts', emoji: '👕', slot: ClothingSlot.top),
  (label: 'Chaussures', emoji: '👟', slot: ClothingSlot.shoes),
  (label: 'Accessoires', emoji: '🎀', slot: ClothingSlot.accessory),
];

class MascotWardrobeScreen extends StatefulWidget {
  final ClothingSlot? initialSlot;
  const MascotWardrobeScreen({super.key, this.initialSlot});

  @override
  State<MascotWardrobeScreen> createState() => _MascotWardrobeScreenState();
}

class _MascotWardrobeScreenState extends State<MascotWardrobeScreen>
    with TickerProviderStateMixin {
  ClothingSlot? _selectedSlot;
  late final AnimationController _previewBounce;
  late final AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _selectedSlot = widget.initialSlot;
    _previewBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = Provider.of<PigioAppState>(context, listen: false);
      if (state.currentClothingRequest == null) {
        final req = await MascotOutfitEngine.evaluateContext(state);
        if (mounted && req != null) state.setClothingRequest(req);
      }
    });
  }

  @override
  void dispose() {
    _previewBounce.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  void _onEquip(PigioAppState state, ClothingItem item, bool isEquipped) {
    if (!MascotOutfitEngine.isItemUnlocked(item.id, state)) return;
    HapticFeedback.lightImpact();
    if (isEquipped) {
      state.unequipClothing(item.slot);
    } else {
      state.equipClothing(item.slot, item.id);
      _previewBounce.forward(from: 0).then((_) => _previewBounce.reverse());
    }
  }

  void _onRandomOutfit(PigioAppState state) {
    HapticFeedback.mediumImpact();
    state.clearOutfit();
    final rng = math.Random();
    final bySlot = <ClothingSlot, List<ClothingItem>>{};
    for (final item in MascotOutfitEngine.catalog) {
      if (!MascotOutfitEngine.isItemUnlocked(item.id, state)) continue;
      bySlot.putIfAbsent(item.slot, () => []).add(item);
    }
    for (final entry in bySlot.entries) {
      final picked = entry.value[rng.nextInt(entry.value.length)];
      state.equipClothing(picked.slot, picked.id);
    }
    _previewBounce.forward(from: 0).then((_) => _previewBounce.reverse());
  }

  void _onSlotTap(ClothingSlot? slot) {
    HapticFeedback.selectionClick();
    setState(() => _selectedSlot = slot);
    _staggerCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final items = MascotOutfitEngine.catalog.where((c) {
      if (_selectedSlot == null) return true;
      return c.slot == _selectedSlot;
    }).toList();
    final equippedCount = state.activeOutfit.values.where((v) => v != null).length;

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: PigioAppBar(title: "Garde-robe de Pigio", showNotification: false),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 1. Sticky Mascot Header (pinned) ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _MascotHeaderDelegate(
              state: state,
              theme: theme,
              equippedCount: equippedCount,
              selectedSlot: _selectedSlot,
              bounce: _previewBounce,
              onSlotTap: _onSlotTap,
            ),
          ),

          // ── 1.5. Action buttons (scrolls away) ──
          SliverToBoxAdapter(
            child: _ActionSection(
              state: state,
              theme: theme,
              equippedCount: equippedCount,
              onClear: () {
                HapticFeedback.mediumImpact();
                final previousOutfit = Map<ClothingSlot, String?>.from(state.activeOutfit);
                state.clearOutfit();
                if (previousOutfit.values.any((v) => v != null)) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tenue retirée', style: fw(size: 13, w: FontWeight.w600)),
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(
                        label: 'Annuler',
                        onPressed: () {
                          for (final entry in previousOutfit.entries) {
                            if (entry.value != null) state.equipClothing(entry.key, entry.value);
                          }
                        },
                      ),
                    ),
                  );
                }
              },
              onRandom: () => _onRandomOutfit(state),
              onUndo: state.canUndoOutfit ? () {
                HapticFeedback.lightImpact();
                state.undoOutfit();
                _previewBounce.forward(from: 0).then((_) => _previewBounce.reverse());
              } : null,
              onSavePreset: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),

          // ── 2. Outfit presets carousel ──
          SliverToBoxAdapter(
            child: _PresetCarousel(state: state, theme: theme),
          ),

          // ── 3. Suggestion banner ──
          SliverToBoxAdapter(
            child: _SuggestionBanner(
              state: state,
              theme: theme,
              onEquip: (item) => _onEquip(state, item, false),
              onDismiss: () => state.setClothingRequest(null),
            ),
          ),

          // Removed `_ItemColorPicker` from here.

          // ── 5. Filter bar — pinned so it stays visible while scrolling ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(
              selected: _selectedSlot,
              theme: theme,
              onSelect: _onSlotTap,
            ),
          ),
          
          // ── 5.5 Item colour pickers ──
          SliverToBoxAdapter(
            child: _ItemColorPicker(
                state: state, theme: theme, selectedSlot: _selectedSlot),
          ),

          // ── 6. 2-column item grid ──
          if (items.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverToBoxAdapter(child: _EmptySlotState(theme: theme)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final item = items[i];
                    final isEquipped = state.activeOutfit[item.slot] == item.id;
                    final isFavorite = state.isClothingFavorite(item.id);
                    return AnimatedBuilder(
                      animation: _staggerCtrl,
                      builder: (ctx, child) {
                        final delay = (i * 0.08).clamp(0.0, 0.5);
                        final t = ((_staggerCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0);
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1.0 - t)),
                            child: child,
                          ),
                        );
                      },
                      child: _WardrobeItemCard(
                        item: item,
                        isEquipped: isEquipped,
                        isFavorite: isFavorite,
                        isLocked: !MascotOutfitEngine.isItemUnlocked(item.id, state),
                        unlockHint: MascotOutfitEngine.getUnlockHint(item.id, state.locale.languageCode),
                        theme: theme,
                        onTap: () => _onEquip(state, item, isEquipped),
                        onFavorite: () {
                          HapticFeedback.selectionClick();
                          state.toggleFavoriteClothing(item.id);
                        },
                      ),
                    );
                  },
                  childCount: items.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Unified item colour picker — single section, item chips as tabs
// ─────────────────────────────────────────────────────────────

class _ItemColorPicker extends StatelessWidget {
  final PigioAppState state;
  final PigioThemeData theme;
  final ClothingSlot? selectedSlot;

  const _ItemColorPicker({
    required this.state,
    required this.theme,
    required this.selectedSlot,
  });

  /// Items that should not show a color picker (flag keeps national colors).
  static const _noTint = {'acc_flag'};

  ({String id, String label, String emoji})? _getTargetItem() {
    if (selectedSlot == null) {
      return (id: 'scarf', label: 'Écharpe', emoji: '🧣');
    }
    final equippedId = state.activeOutfit[selectedSlot];
    if (equippedId == null || _noTint.contains(equippedId)) return null;
    
    final meta = MascotOutfitEngine.getItem(equippedId);
    return (
      id: equippedId,
      label: meta?.name ?? 'Élément',
      emoji: meta?.emoji ?? '👕'
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = _getTargetItem();
    if (target == null) return const SizedBox.shrink();

    final currentArgb = target.id == 'scarf'
        ? state.mascotScarfColor.toARGB32()
        : state.outfitColors[target.id];
    final currentColor = currentArgb != null ? Color(currentArgb) : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🎨 Couleur', style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
              const SizedBox(width: 8),
              Text('•', style: fw(size: 15, w: FontWeight.w800, color: theme.divider)),
              const SizedBox(width: 8),
              Text(target.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(target.label, style: fw(size: 14, w: FontWeight.w700, color: theme.mid)),
            ],
          ),
          const SizedBox(height: 14),

          // ── Colour palette ──────────────────────────────────
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kItemColors.map((c) {
              final isSelected = currentColor?.toARGB32() == c.toARGB32();
              return Semantics(
                label: 'Couleur ${target.label}',
                selected: isSelected,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (target.id == 'scarf') {
                      state.setMascotScarfColor(c);
                    } else {
                      state.setOutfitItemColor(target.id, c);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? theme.primary : theme.divider,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: isSelected
                        ? const Center(child: Icon(Icons.check, color: Colors.white, size: 20))
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Preview Card — mascot + slot indicators + action row
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// Sticky Mascot Header — Pinned at the top with scaling effect
// ─────────────────────────────────────────────────────────────

class _MascotHeaderDelegate extends SliverPersistentHeaderDelegate {
  final PigioAppState state;
  final PigioThemeData theme;
  final int equippedCount;
  final ClothingSlot? selectedSlot;
  final AnimationController bounce;
  final void Function(ClothingSlot?) onSlotTap;

  _MascotHeaderDelegate({
    required this.state,
    required this.theme,
    required this.equippedCount,
    required this.selectedSlot,
    required this.bounce,
    required this.onSlotTap,
  });

  @override
  double get minExtent => 140 + 50; // Min height when pinned
  @override
  double get maxExtent => 280 + 50; // Max height when expanded

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final accentColor = theme.primary;

    // Scaling factors
    final mascotScale = 1.0 - (progress * 0.35); // Shrinks by 35%
    final verticalPadding = 28.0 - (progress * 20.0);
    final bottomPadding = 20.0 - (progress * 15.0);

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffold,
          boxShadow: overlapsContent || progress > 0.1
              ? [
                  BoxShadow(
                    color: theme.ink.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Container(
        margin: EdgeInsets.fromLTRB(16, 16, 16, progress > 0.9 ? 0 : 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(28 * (1.0 - progress * 0.5)),
          boxShadow: progress < 0.1
              ? [
                  BoxShadow(
                    color: theme.ink.withValues(alpha: 0.07),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            // Gradient tint
            Positioned(
              top: 0, left: 0, right: 0, height: 120,
              child: Opacity(
                opacity: 1.0 - progress,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accentColor.withValues(alpha: 0.10),
                        accentColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(20, verticalPadding, 20, bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bouncing mascot
                  Flexible(
                    child: Center(
                      child: Transform.scale(
                        scale: mascotScale,
                        child: AnimatedBuilder(
                          animation: bounce,
                          builder: (ctx, child) => Transform.scale(
                            scale: 1.0 + bounce.value * 0.08,
                            child: child,
                          ),
                          child: PigioWidget(
                            key: ValueKey(Object.hash(
                              Object.hashAll(state.activeOutfit.values),
                              Object.hashAll(state.outfitColors.values),
                              state.mascotScarfColor,
                            )),
                            mood: equippedCount > 0 ? PigMood.excited : PigMood.normal,
                            size: 130, // Base size
                            scarfColor: state.mascotScarfColor,
                            outfit: state.activeOutfit,
                            outfitColors: state.outfitColors,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Offstage(
                    offstage: progress >= 0.8,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _kSlotFilters
                            .where((f) => f.slot != null)
                            .map((f) => Semantics(
                                  label: "${f.label}, ${state.activeOutfit[f.slot] != null ? 'équipé' : 'vide'}",
                                  button: true,
                                  child: _SlotDot(
                                    emoji: f.emoji,
                                    color: _kSlotAccents[f.slot]!,
                                    isEquipped: state.activeOutfit[f.slot] != null,
                                    isSelected: selectedSlot == f.slot,
                                    onTap: () => onSlotTap(f.slot),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  @override
  bool shouldRebuild(covariant _MascotHeaderDelegate oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────
// Action Section — scrolls away normally
// ─────────────────────────────────────────────────────────────

class _ActionSection extends StatelessWidget {
  final PigioAppState state;
  final PigioThemeData theme;
  final int equippedCount;
  final VoidCallback onClear;
  final VoidCallback onRandom;
  final VoidCallback? onUndo;
  final VoidCallback onSavePreset;

  const _ActionSection({
    required this.state,
    required this.theme,
    required this.equippedCount,
    required this.onClear,
    required this.onRandom,
    required this.onUndo,
    required this.onSavePreset,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Aléatoire',
                  emoji: '🎲',
                  color: theme.primary,
                  onTap: onRandom,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedOpacity(
                  opacity: onUndo != null ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 200),
                  child: _ActionButton(
                    label: 'Annuler',
                    emoji: '↩️',
                    color: theme.info,
                    onTap: onUndo,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedOpacity(
                  opacity: equippedCount > 0 ? 1.0 : 0.3,
                  duration: const Duration(milliseconds: 200),
                  child: _ActionButton(
                    label: 'Tout enlever',
                    emoji: '✂️',
                    color: theme.warning,
                    onTap: equippedCount > 0 ? onClear : null,
                  ),
                ),
              ),
            ],
          ),

          if (equippedCount > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSavePreset,
                icon: const Text('✅', style: TextStyle(fontSize: 13)),
                label: Text("Valider ce look",
                  style: fw(size: 12, w: FontWeight.w800, color: theme.ink)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.surface,
                  foregroundColor: theme.ink,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: theme.divider),
                  ),
                ),
              ),
            ),
          ],

          if (equippedCount == 0) ...[
            const SizedBox(height: 10),
            Text(
              "Appuie sur un accessoire pour habiller Pigio !",
              textAlign: TextAlign.center,
              style: fw(size: 13, w: FontWeight.w600, color: theme.mid, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

// Reusable pill action button
class _ActionButton extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      enabled: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: fw(size: 13, w: FontWeight.w700, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Animated slot dot — tappable to filter by slot (48px touch target)
class _SlotDot extends StatelessWidget {
  final String emoji;
  final Color color;
  final bool isEquipped;
  final bool isSelected;
  final VoidCallback onTap;

  const _SlotDot({
    required this.emoji,
    required this.color,
    required this.isEquipped,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : isEquipped
                  ? color.withValues(alpha: 0.12)
                  : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? color
                : isEquipped
                    ? color.withValues(alpha: 0.6)
                    : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 2.5 : isEquipped ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)]
              : [],
        ),
        child: Center(
          child: AnimatedScale(
            scale: isSelected ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isEquipped || isSelected ? 1.0 : 0.45,
              child: Text(emoji, style: const TextStyle(fontSize: 19)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Outfit Preset Carousel
// ─────────────────────────────────────────────────────────────

class _PresetCarousel extends StatelessWidget {
  final PigioAppState state;
  final PigioThemeData theme;

  const _PresetCarousel({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: state.outfitPresets.isEmpty
            ? const SizedBox(width: double.infinity, height: 0)
            : SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.outfitPresets.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final preset = state.outfitPresets[i];
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              state.loadOutfitPreset(preset);
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: theme.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  title: Text('Supprimer "${preset.name}" ?',
                      style: fw(size: 16, w: FontWeight.w900, color: theme.ink)),
                  content: Text('Ce look sauvegardé sera définitivement supprimé.',
                      style: fw(size: 13, w: FontWeight.w500, color: theme.mid)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Annuler', style: fw(size: 14, w: FontWeight.w700, color: theme.mid)),
                    ),
                    TextButton(
                      onPressed: () {
                        state.deleteOutfitPreset(preset.id);
                        Navigator.pop(ctx);
                      },
                      child: Text('Supprimer', style: fw(size: 14, w: FontWeight.w800, color: const Color(0xFFE63950))),
                    ),
                  ],
                ),
              );
            },
            child: Semantics(
              label: "Look ${preset.name}",
              button: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(preset.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(preset.name, style: fw(size: 13, w: FontWeight.w700, color: theme.ink)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Suggestion Banner
// ─────────────────────────────────────────────────────────────

class _SuggestionBanner extends StatelessWidget {
  final PigioAppState state;
  final PigioThemeData theme;
  final void Function(ClothingItem item) onEquip;
  final VoidCallback onDismiss;

  const _SuggestionBanner({
    required this.state,
    required this.theme,
    required this.onEquip,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final request = state.currentClothingRequest;
    final isVisible = request != null &&
        state.activeOutfit[request.item.slot] != request.item.id;

    // Use AnimatedSize + ClipRect to animate size away safely
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: isVisible
            ? AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.primary.withValues(alpha: 0.2), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(request.item.emoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.contextHint,
                              style: fw(size: 11, w: FontWeight.w700, color: theme.primary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Pigio veut : ${request.item.name}",
                              style: fw(size: 13, w: FontWeight.w600, color: theme.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Dismiss button
                      GestureDetector(
                        onTap: onDismiss,
                        child: Semantics(
                          label: "Fermer la suggestion",
                          button: true,
                          child: Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.surface,
                            ),
                            child: Icon(Icons.close, size: 14, color: theme.mid),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Equip button
                      Semantics(
                        label: "Essayer ${request.item.name}",
                        button: true,
                        child: GestureDetector(
                          onTap: () => onEquip(request.item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "Essayer",
                              style: fw(size: 12, w: FontWeight.w800, color: theme.onAccent),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pinned Filter Bar
// ─────────────────────────────────────────────────────────────

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final ClothingSlot? selected;
  final PigioThemeData theme;
  final void Function(ClothingSlot?) onSelect;

  _FilterBarDelegate({
    required this.selected,
    required this.theme,
    required this.onSelect,
  });

  @override
  double get minExtent => 54;
  @override
  double get maxExtent => 54;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: theme.scaffold,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: _kSlotFilters.map((f) {
            final isSelected = selected == f.slot;
            final accent = _kSlotAccents[f.slot] ?? theme.primary;
            final count = MascotOutfitEngine.countForSlot(f.slot);
            return Semantics(
              label: "${f.label}, $count articles",
              selected: isSelected,
              button: true,
              child: GestureDetector(
                onTap: () => onSelect(f.slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? accent : theme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? accent : theme.divider,
                      width: 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(f.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        "${f.label} ($count)",
                        style: fw(
                          size: 13,
                          w: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : theme.mid,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterBarDelegate old) =>
      old.selected != selected || old.theme != theme;
}

// ─────────────────────────────────────────────────────────────
// Empty state when a slot category has no items
// ─────────────────────────────────────────────────────────────

class _EmptySlotState extends StatelessWidget {
  final PigioThemeData theme;
  const _EmptySlotState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Text("🪹", style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            "Rien dans cette catégorie pour l'instant",
            textAlign: TextAlign.center,
            style: fw(size: 14, w: FontWeight.w600, color: theme.mid),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Wardrobe Item Card
// ─────────────────────────────────────────────────────────────

class _WardrobeItemCard extends StatefulWidget {
  final ClothingItem item;
  final bool isEquipped;
  final bool isFavorite;
  final bool isLocked;
  final String? unlockHint;
  final PigioThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  const _WardrobeItemCard({
    required this.item,
    required this.isEquipped,
    required this.isFavorite,
    this.isLocked = false,
    this.unlockHint,
    required this.theme,
    required this.onTap,
    required this.onFavorite,
  });

  @override
  State<_WardrobeItemCard> createState() => _WardrobeItemCardState();
}

class _WardrobeItemCardState extends State<_WardrobeItemCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap;

  @override
  void initState() {
    super.initState();
    _tap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isEquipped = widget.isEquipped;
    final isFavorite = widget.isFavorite;
    final isLocked = widget.isLocked;
    final theme = widget.theme;
    final accent = _kSlotAccents[item.slot] ?? theme.primary;
    final rarityColor = _kRarityColors[item.rarity] ?? theme.mid;

    return Semantics(
      label: "${item.name}, ${isLocked ? 'verrouillé' : isEquipped ? 'équipé' : 'non équipé'}, ${item.rarity.name}",
      button: !isLocked,
      child: GestureDetector(
        onTapDown: isLocked ? null : (_) => _tap.forward(),
        onTapUp: isLocked ? null : (_) {
          _tap.reverse();
          widget.onTap();
        },
        onTapCancel: isLocked ? null : () => _tap.reverse(),
        child: AnimatedBuilder(
          animation: _tap,
          builder: (ctx, child) => Transform.scale(
            scale: 1.0 - _tap.value * 0.04,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isEquipped ? accent.withValues(alpha: 0.07) : theme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isEquipped ? accent : theme.divider.withValues(alpha: 0.5),
                width: isEquipped ? 2.0 : 1.0,
              ),
              boxShadow: [
                if (isEquipped)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                BoxShadow(
                  color: theme.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Main content area
                Column(
                  children: [
                    // ── Preview area with large emoji ──
                    Expanded(
                      child: Center(
                        child: Text(item.emoji, style: const TextStyle(fontSize: 48)),
                      ),
                    ),

                    // ── Name + rarity footer ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      color: isEquipped
                          ? accent.withValues(alpha: 0.08)
                          : theme.surface.withValues(alpha: 0.55),
                      child: Column(
                        children: [
                          Text(
                            item.name,
                            textAlign: TextAlign.center,
                            style: fw(
                              size: 12,
                              w: isEquipped ? FontWeight.w800 : FontWeight.w600,
                              color: isEquipped ? accent : theme.ink,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isEquipped) ...[
                            const SizedBox(height: 3),
                            Text(
                              "✓ ÉQUIPÉ",
                              style: fw(
                                size: 9,
                                w: FontWeight.w700,
                                color: accent.withValues(alpha: 0.7),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Rarity dot (top-left) ──
                if (item.rarity != ItemRarity.common)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rarityColor,
                        boxShadow: [BoxShadow(color: rarityColor.withValues(alpha: 0.5), blurRadius: 4)],
                      ),
                    ),
                  ),

                // ── Favorite heart (top-left, after rarity) ──
                Positioned(
                  top: 6,
                  left: item.rarity != ItemRarity.common ? 22 : 6,
                  child: GestureDetector(
                    onTap: widget.onFavorite,
                    behavior: HitTestBehavior.opaque,
                    child: Semantics(
                      label: isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                      button: true,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFavorite ? const Color(0xFFE63950) : theme.light,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Equipped checkmark badge (top-right) ──
                if (isEquipped)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),

                // ── Lock overlay (locked items) ──
                if (isLocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.ink.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.9), size: 28),
                          if (widget.unlockHint != null) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                widget.unlockHint!,
                                textAlign: TextAlign.center,
                                style: fw(size: 10, w: FontWeight.w700, color: Colors.white.withValues(alpha: 0.85), height: 1.3),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
