import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
  ClothingSlot.top: Color(0xFF2ECC71),
  ClothingSlot.shoes: Color(0xFFFF9500),
  ClothingSlot.accessory: Color(0xFF9C6FE3),
};

const _kScarfColors = <Color>[
  Color(0xFFFFD54F), // Yellow (default)
  Color(0xFFFF7043), // Orange
  Color(0xFFEF5350), // Red
  Color(0xFFEC407A), // Pink
  Color(0xFFAB47BC), // Purple
  Color(0xFF42A5F5), // Blue
  Color(0xFF26A69A), // Teal
  Color(0xFF66BB6A), // Green
  Color(0xFFBDBDBD), // Gray
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
  const MascotWardrobeScreen({super.key});

  @override
  State<MascotWardrobeScreen> createState() => _MascotWardrobeScreenState();
}

class _MascotWardrobeScreenState extends State<MascotWardrobeScreen>
    with TickerProviderStateMixin {
  ClothingSlot? _selectedSlot;
  late final AnimationController _previewBounce;

  @override
  void initState() {
    super.initState();
    _previewBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
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
    super.dispose();
  }

  void _onEquip(PigioAppState state, ClothingItem item, bool isEquipped) {
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
          // ── 1. Preview card (scrolls away) ──
          SliverToBoxAdapter(
            child: _PreviewCard(
              state: state,
              theme: theme,
              equippedCount: equippedCount,
              selectedSlot: _selectedSlot,
              bounce: _previewBounce,
              onClear: () {
                HapticFeedback.mediumImpact();
                state.clearOutfit();
              },
              onRandom: () => _onRandomOutfit(state),
              onSlotTap: _onSlotTap,
            ),
          ),

          // ── 2. Suggestion banner ──
          SliverToBoxAdapter(
            child: _SuggestionBanner(
              state: state,
              theme: theme,
              onEquip: (item) => _onEquip(state, item, false),
            ),
          ),

          // ── 3. Scarf colour picker ──
          SliverToBoxAdapter(
            child: _ScarfColorPicker(state: state, theme: theme),
          ),

          // ── 4. Filter bar — pinned so it stays visible while scrolling ──
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(
              selected: _selectedSlot,
              theme: theme,
              onSelect: _onSlotTap,
            ),
          ),

          // ── 5. 2-column item grid ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: items.isEmpty
                ? SliverToBoxAdapter(child: _EmptySlotState(theme: theme))
                : SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final item = items[i];
                        final isEquipped = state.activeOutfit[item.slot] == item.id;
                        return _WardrobeItemCard(
                          item: item,
                          isEquipped: isEquipped,
                          theme: theme,
                          onTap: () => _onEquip(state, item, isEquipped),
                        );
                      },
                      childCount: items.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Scarf colour picker
// ─────────────────────────────────────────────────────────────

class _ScarfColorPicker extends StatelessWidget {
  final PigioAppState state;
  final PigioThemeData theme;
  const _ScarfColorPicker({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text("Couleur de l'écharpe",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: theme.ink)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _kScarfColors.map((c) {
              final isSelected = state.mascotScarfColor.toARGB32() == c.toARGB32();
              return GestureDetector(
                onTap: () => state.setMascotScarfColor(c),
                child: Container(
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
                        ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check,
                          color: c.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                          size: 18)
                      : null,
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

class _PreviewCard extends StatelessWidget {
  final PigioAppState state;
  final PigioThemeData theme;
  final int equippedCount;
  final ClothingSlot? selectedSlot;
  final AnimationController bounce;
  final VoidCallback onClear;
  final VoidCallback onRandom;
  final void Function(ClothingSlot?) onSlotTap;

  const _PreviewCard({
    required this.state,
    required this.theme,
    required this.equippedCount,
    required this.selectedSlot,
    required this.bounce,
    required this.onClear,
    required this.onRandom,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = theme.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.ink.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Gradient tint at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
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

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Column(
              children: [
                // Bouncing mascot
                AnimatedBuilder(
                  animation: bounce,
                  builder: (ctx, child) => Transform.scale(
                    scale: 1.0 + bounce.value * 0.08,
                    child: child,
                  ),
                  child: PigioWidget(
                    mood: equippedCount > 0 ? PigMood.excited : PigMood.normal,
                    size: 150,
                    scarfColor: state.mascotScarfColor,
                    outfit: state.activeOutfit,
                  ),
                ),

                const SizedBox(height: 20),

                // Slot indicator dots — tappable to filter
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _kSlotFilters
                      .where((f) => f.slot != null)
                      .map((f) => _SlotDot(
                            emoji: f.emoji,
                            color: _kSlotAccents[f.slot]!,
                            isEquipped: state.activeOutfit[f.slot] != null,
                            isSelected: selectedSlot == f.slot,
                            onTap: () => onSlotTap(f.slot),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 18),

                // Action row — always visible
                Row(
                  children: [
                    // Random outfit button
                    Expanded(
                      child: _ActionButton(
                        label: 'Aléatoire',
                        emoji: '🎲',
                        color: theme.primary,
                        onTap: onRandom,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Clear all button — dimmed when nothing equipped
                    Expanded(
                      child: AnimatedOpacity(
                        opacity: equippedCount > 0 ? 1.0 : 0.4,
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

                // Empty-state hint
                if (equippedCount == 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Appuie sur un accessoire pour habiller Pigio !",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.mid,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
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
    return GestureDetector(
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
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Animated slot dot — tappable to filter by slot
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
        margin: const EdgeInsets.symmetric(horizontal: 5),
        width: 40,
        height: 40,
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
              opacity: isEquipped || isSelected ? 1.0 : 0.35,
              child: Text(emoji, style: const TextStyle(fontSize: 17)),
            ),
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

  const _SuggestionBanner({
    required this.state,
    required this.theme,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final request = state.currentClothingRequest;
    if (request == null) return const SizedBox.shrink();

    final isAlreadyEquipped = state.activeOutfit[request.item.slot] == request.item.id;
    if (isAlreadyEquipped) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: theme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Pigio veut : ${request.item.name}",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => onEquip(request.item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Essayer",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: theme.onAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
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
            return GestureDetector(
              onTap: () => onSelect(f.slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? accent : theme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.30),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
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
                      f.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : theme.mid,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterBarDelegate old) => old.selected != selected;
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
            style: TextStyle(color: theme.mid, fontSize: 14),
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
  final PigioThemeData theme;
  final VoidCallback onTap;

  const _WardrobeItemCard({
    required this.item,
    required this.isEquipped,
    required this.theme,
    required this.onTap,
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
    final theme = widget.theme;
    final accent = _kSlotAccents[item.slot] ?? theme.primary;

    return GestureDetector(
      onTapDown: (_) => _tap.forward(),
      onTapUp: (_) {
        _tap.reverse();
        widget.onTap();
      },
      onTapCancel: () => _tap.reverse(),
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
                color: theme.ink.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Preview area ──
              Expanded(
                child: Stack(
                  children: [
                    // Soft slot-colored disc behind the mascot
                    Positioned.fill(
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: isEquipped ? 0.14 : 0.07),
                          ),
                        ),
                      ),
                    ),
                    // Mini mascot wearing just this item
                    Center(
                      child: PigioWidget(
                        mood: PigMood.normal,
                        size: 76,
                        outfit: {item.slot: item.id},
                      ),
                    ),
                    // Equipped checkmark badge
                    if (isEquipped)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 26,
                          height: 26,
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
                  ],
                ),
              ),

              // ── Name footer ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                color: isEquipped
                    ? accent.withValues(alpha: 0.08)
                    : theme.surface.withValues(alpha: 0.55),
                child: Text(
                  item.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isEquipped ? FontWeight.w700 : FontWeight.w500,
                    color: isEquipped ? accent : theme.ink,
                    height: 1.25,
                  ),
                  maxLines: 2,
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
