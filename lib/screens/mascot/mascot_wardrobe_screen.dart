import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';
import 'package:kindy/shared/widgets/pigio_painter.dart';
import 'package:kindy/services/mascot_outfit_engine.dart';
import 'package:kindy/services/mascot_share_service.dart';
import 'mascot_photobooth_screen.dart';

// Per-slot accent colors — used in filter chips, slot dots, and item cards.
const _kSlotAccents = <ClothingSlot?, Color>{
  null: Color(0xFF337EA9),
  ClothingSlot.hat: Color(0xFFE63950),
  ClothingSlot.glasses: Color(0xFF4A6FE3),
  ClothingSlot.top: Color(0xFF1B8A4C), // Fixed: was 0xFF2ECC71 (WCAG AA fail)
  ClothingSlot.scarf: Color(0xFFE6A817),
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

/// Zoom focus rectangles per slot, in PigioPainter's 100x130 coordinate space.
/// The preview will auto-zoom to show this region when the slot's filter is selected.
const _kSlotZoomRegions = <ClothingSlot, Rect>{
  ClothingSlot.hat:       Rect.fromLTWH(15, -5, 70, 45),   // head + hat
  ClothingSlot.glasses:   Rect.fromLTWH(18, 8, 64, 48),    // face / eyes
  ClothingSlot.top:       Rect.fromLTWH(8, 38, 84, 70),    // torso
  ClothingSlot.scarf:     Rect.fromLTWH(15, 30, 70, 50),   // neck area
  ClothingSlot.shoes:     Rect.fromLTWH(10, 82, 80, 50),   // feet
  ClothingSlot.accessory: Rect.fromLTWH(0, 0, 100, 130),   // full view
};

/// Lerp between two Matrix4 values element-by-element.
Matrix4 _lerpMatrix4(Matrix4 a, Matrix4 b, double t) {
  final result = Matrix4.zero();
  for (int i = 0; i < 16; i++) {
    result[i] = a[i] + (b[i] - a[i]) * t;
  }
  return result;
}

const _kSlotFilters = <({String labelFr, String labelEn, String emoji, ClothingSlot? slot})>[
  (labelFr: 'Tout', labelEn: 'All', emoji: '✨', slot: null),
  (labelFr: 'Têtes', labelEn: 'Hats', emoji: '🎩', slot: ClothingSlot.hat),
  (labelFr: 'Lunettes', labelEn: 'Glasses', emoji: '👓', slot: ClothingSlot.glasses),
  (labelFr: 'Hauts', labelEn: 'Tops', emoji: '👕', slot: ClothingSlot.top),
  (labelFr: 'Écharpes', labelEn: 'Scarves', emoji: '🧣', slot: ClothingSlot.scarf),
  (labelFr: 'Chaussures', labelEn: 'Shoes', emoji: '👟', slot: ClothingSlot.shoes),
  (labelFr: 'Accessoires', labelEn: 'Accessories', emoji: '🎀', slot: ClothingSlot.accessory),
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
  String? _lastEquippedItemId;
  bool _showLimited = false;
  late final AnimationController _previewBounce;
  late final AnimationController _staggerCtrl;

  // ── Auto-zoom per slot ──
  late final AnimationController _zoomCtrl;
  Matrix4 _zoomFrom = Matrix4.identity();
  Matrix4 _zoomTo = Matrix4.identity();

  // ── 360° rotation ──
  PigViewAngle _viewAngle = PigViewAngle.front;
  double _rotateProgress = 0.0; // 0=front, 0.25=3/4R, 0.5=back, 0.75=3/4L

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
    _zoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final state = Provider.of<PigioAppState>(context, listen: false);
      if (state.currentClothingRequest == null) {
        final req = await MascotOutfitEngine.evaluateContext(state);
        if (mounted && req != null) state.setClothingRequest(req);
      }
      // Check for newly unlocked achievements and celebrate
      if (mounted) {
        final newUnlocks = MascotOutfitEngine.checkAchievements(state);
        final celebrateItem = newUnlocks
            .map((id) => MascotOutfitEngine.getItem(id))
            .whereType<ClothingItem>()
            .firstOrNull;
        if (celebrateItem != null && mounted) {
          _showCelebration(celebrateItem, state);
        }
      }
    });
  }

  @override
  void dispose() {
    _previewBounce.dispose();
    _staggerCtrl.dispose();
    _zoomCtrl.dispose();
    super.dispose();
  }

  void _onEquip(PigioAppState state, ClothingItem item, bool isEquipped) {
    if (!MascotOutfitEngine.isItemUnlocked(item.id, state)) return;
    HapticFeedback.lightImpact();
    if (isEquipped) {
      state.unequipClothing(item.slot);
      setState(() => _lastEquippedItemId = null);
    } else {
      state.equipClothing(item.slot, item.id);
      setState(() => _lastEquippedItemId = item.id);
      _previewBounce.forward(from: 0).then((_) => _previewBounce.reverse());
      // Check for newly completed outfit combos
      final newCombos = MascotOutfitEngine.checkCompletedCombos(state);
      for (final combo in newCombos) {
        state.markComboCompleted(combo.nameFr);
        _showComboCompletedSheet(combo, state);
      }
      // Check daily challenge completion
      final challenge = MascotOutfitEngine.todaysChallenge(DateTime.now());
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      if (state.dailyChallengeCompleted != todayStr && MascotOutfitEngine.isChallengeMet(challenge, state)) {
        state.completeDailyChallenge();
      }
    }
  }

  void _showComboCompletedSheet(OutfitCombo combo, PigioAppState state) {
    final isFr = state.locale.languageCode == 'fr';
    final theme = context.pt;
    HapticFeedback.heavyImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎨', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              isFr ? 'Combo complété !' : 'Combo completed!',
              style: fw(size: 20, w: FontWeight.w800, color: theme.ink),
            ),
            const SizedBox(height: 6),
            Text(
              isFr ? combo.nameFr : combo.nameEn,
              style: fw(size: 16, w: FontWeight.w600, color: theme.mid),
            ),
            const SizedBox(height: 4),
            Text(
              '+25 XP',
              style: fw(size: 14, w: FontWeight.w700, color: const Color(0xFFFFAA00)),
            ),
            const SizedBox(height: 16),
            Text(
              combo.itemIds.map((id) => MascotOutfitEngine.getItem(id)?.emoji ?? '').join(' '),
              style: const TextStyle(fontSize: 28),
            ),
          ],
        ),
      ),
    );
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

  /// Compute a zoom Matrix4 that scales+translates to focus on a region.
  /// Region is in PigioPainter's 100x130 coordinate space.
  /// Widget display size is 130x169 (130 * 1.3).
  Matrix4 _zoomMatrixForSlot(ClothingSlot? slot) {
    if (slot == null) return Matrix4.identity();
    final region = _kSlotZoomRegions[slot];
    if (region == null) return Matrix4.identity();
    // Full coordinate space: 100 wide, 130 tall (+ 5 translate)
    const coordW = 100.0, coordH = 130.0;
    // Scale factor to fill preview with the region
    final sx = coordW / region.width;
    final sy = coordH / region.height;
    final s = math.min(sx, sy).clamp(1.0, 2.8);
    if (s <= 1.05) return Matrix4.identity(); // No meaningful zoom
    // Center the region
    final regionCx = region.left + region.width / 2;
    final regionCy = region.top + region.height / 2;
    // ignore: deprecated_member_use
    return Matrix4.identity()
      ..translate(coordW / 2 * (130 / coordW), coordH / 2 * (169 / coordH)) // ignore: deprecated_member_use
      ..scale(s, s) // ignore: deprecated_member_use
      ..translate(-regionCx * (130 / coordW), -regionCy * (169 / coordH));
  }

  void _onSlotTap(ClothingSlot? slot) {
    HapticFeedback.selectionClick();
    _zoomFrom = _zoomTo;
    _zoomTo = _zoomMatrixForSlot(slot);
    _zoomCtrl.forward(from: 0);
    setState(() => _selectedSlot = slot);
    _staggerCtrl.forward(from: 0);
  }

  PigViewAngle _angleFromProgress(double p) {
    final norm = p % 1.0;
    if (norm < 0.125 || norm >= 0.875) return PigViewAngle.front;
    if (norm < 0.375) return PigViewAngle.threeQuarterRight;
    if (norm < 0.625) return PigViewAngle.back;
    return PigViewAngle.threeQuarterLeft;
  }

  void _showCelebration(ClothingItem item, PigioAppState state) {
    final isFr = state.locale.languageCode == 'fr';
    final rarityColor = _kRarityColors[item.rarity] ?? const Color(0xFF8B90B0);

    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) HapticFeedback.mediumImpact();
    });

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'celebration',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, a1, a2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: a1, curve: Curves.elasticOut),
          child: FadeTransition(opacity: a1, child: child),
        );
      },
      // ignore: unnecessary_underscores
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: context.pt.card,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: rarityColor.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 4)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    height: 130,
                    child: PigioWidget(mood: PigMood.celebrating, outfit: state.activeOutfit, outfitColors: state.outfitColors, scarfColor: state.mascotScarfColor),
                  ),
                  const SizedBox(height: 16),
                  if (item.hasImage)
                    Image.asset(item.imageAsset!, width: 64, height: 64, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Text(item.emoji, style: const TextStyle(fontSize: 52)))
                  else
                    Text(item.emoji, style: const TextStyle(fontSize: 52)),
                  const SizedBox(height: 8),
                  Text(
                    isFr ? 'Nouvel objet débloqué !' : 'New item unlocked!',
                    style: fw(size: 20, w: FontWeight.w800, color: context.pt.ink),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(item.name, style: fw(size: 16, w: FontWeight.w600, color: context.pt.mid)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: rarityColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.rarity.name.toUpperCase(),
                      style: fw(size: 11, w: FontWeight.w900, color: rarityColor),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showFormatPicker(item.id, state);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: rarityColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(isFr ? 'Partager' : 'Share', style: fw(size: 14, w: FontWeight.w700, color: rarityColor)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            state.equipClothing(item.slot, item.id);
                            _previewBounce.forward(from: 0).then((_) => _previewBounce.reverse());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: rarityColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(isFr ? 'Essayer' : 'Try it', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFormatPicker(String itemId, PigioAppState state) {
    final isFr = state.locale.languageCode == 'fr';
    final theme = context.pt;
    const formats = ShareFormat.values;
    const icons = [Icons.phone_android_rounded, Icons.crop_square_rounded, Icons.credit_card_rounded];
    const subtitles = ['1080×1920', '1080×1080', '600×800'];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isFr ? 'Format de partage' : 'Share format',
              style: fw(size: 18, w: FontWeight.w800, color: theme.ink),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(formats.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: _FormatOption(
                      icon: icons[i],
                      label: formats[i].label,
                      subtitle: subtitles[i],
                      color: theme.primary,
                      onTap: () {
                        Navigator.pop(context);
                        MascotShareService.shareAchievementCard(
                          context: context,
                          itemId: itemId,
                          state: state,
                          format: formats[i],
                        );
                      },
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final limitedDrops = MascotOutfitEngine.seasonalDrops(DateTime.now());
    final items = MascotOutfitEngine.catalog.where((c) {
      if (_showLimited) return c.expiresAt != null && c.isAvailable;
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
              zoomCtrl: _zoomCtrl,
              zoomFrom: _zoomFrom,
              zoomTo: _zoomTo,
              viewAngle: _viewAngle,
              onRotateDelta: (dx) {
                setState(() {
                  _rotateProgress = (_rotateProgress + dx / 200) % 1.0;
                  if (_rotateProgress < 0) _rotateProgress += 1.0;
                  _viewAngle = _angleFromProgress(_rotateProgress);
                });
              },
              onRotateEnd: () {
                // Snap to nearest discrete angle
                const snaps = [0.0, 0.25, 0.5, 0.75];
                double nearest = 0.0;
                double minDist = 1.0;
                for (final s in snaps) {
                  final dist = ((_rotateProgress - s) % 1.0).abs();
                  final distWrap = (1.0 - dist).abs();
                  final d = math.min(dist, distWrap);
                  if (d < minDist) { minDist = d; nearest = s; }
                }
                setState(() {
                  _rotateProgress = nearest;
                  _viewAngle = _angleFromProgress(nearest);
                });
              },
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

          // ── 1.8. Outfit of the day ──
          SliverToBoxAdapter(
            child: _OutfitOfTheDayCard(
              state: state,
              theme: theme,
              onApply: () {
                HapticFeedback.mediumImpact();
                final ootd = MascotOutfitEngine.suggestOutfitOfTheDay(state, weather: state.currentWeather);
                state.clearOutfit();
                for (final entry in ootd.entries) {
                  state.equipClothing(entry.key, entry.value);
                }
                _previewBounce.forward(from: 0).then((_) => _previewBounce.reverse());
              },
            ),
          ),

          // ── 1.9. Daily challenge banner ──
          SliverToBoxAdapter(
            child: _DailyChallengeBanner(state: state, theme: theme),
          ),

          // ── 2. Outfit presets carousel ──
          SliverToBoxAdapter(
            child: _PresetCarousel(state: state, theme: theme),
          ),

          // ── 2.5. Collection progress ──
          SliverToBoxAdapter(
            child: _CollectionProgressCard(state: state, theme: theme),
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
              lang: state.locale.languageCode,
              onSelect: (slot) {
                _onSlotTap(slot);
                if (_showLimited) setState(() => _showLimited = false);
              },
              showLimited: _showLimited,
              limitedCount: limitedDrops.length,
              onToggleLimited: () => setState(() {
                _showLimited = !_showLimited;
                if (_showLimited) _selectedSlot = null;
              }),
            ),
          ),
          
          // ── 5.5 Item colour pickers ──
          SliverToBoxAdapter(
            child: _ItemColorPicker(
                state: state, theme: theme, selectedSlot: _selectedSlot, lastEquippedItemId: _lastEquippedItemId),
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
  final String? lastEquippedItemId;

  const _ItemColorPicker({
    required this.state,
    required this.theme,
    required this.selectedSlot,
    this.lastEquippedItemId,
  });

  /// Items that should not show a color picker (flag keeps national colors).
  static const _noTint = {'acc_flag'};

  ({String id, String label, String emoji})? _getTargetItem() {
    if (selectedSlot == null) {
      // "All" tab: show color picker for the last equipped item, or fall back to scarf
      if (lastEquippedItemId != null && !_noTint.contains(lastEquippedItemId)) {
        final meta = MascotOutfitEngine.getItem(lastEquippedItemId!);
        if (meta != null) {
          return (id: lastEquippedItemId!, label: meta.name, emoji: meta.emoji);
        }
      }
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
  final AnimationController zoomCtrl;
  final Matrix4 zoomFrom;
  final Matrix4 zoomTo;
  final PigViewAngle viewAngle;
  final ValueChanged<double> onRotateDelta;
  final VoidCallback onRotateEnd;

  _MascotHeaderDelegate({
    required this.state,
    required this.theme,
    required this.equippedCount,
    required this.selectedSlot,
    required this.bounce,
    required this.onSlotTap,
    required this.zoomCtrl,
    required this.zoomFrom,
    required this.zoomTo,
    required this.viewAngle,
    required this.onRotateDelta,
    required this.onRotateEnd,
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
                  // Bouncing mascot with zoom + rotation
                  Flexible(
                    child: Center(
                      child: GestureDetector(
                        onHorizontalDragUpdate: (d) => onRotateDelta(d.delta.dx),
                        onHorizontalDragEnd: (_) => onRotateEnd(),
                        onDoubleTap: () => onSlotTap(null), // Double-tap = zoom out
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Transform.scale(
                            scale: mascotScale,
                            child: AnimatedBuilder(
                              animation: Listenable.merge([bounce, zoomCtrl]),
                              builder: (ctx, child) {
                                final t = Curves.easeInOutCubic.transform(zoomCtrl.value);
                                // Interpolate zoom matrices
                                final zoom = _lerpMatrix4(zoomFrom, zoomTo, t);
                                return Transform(
                                  transform: zoom,
                                  alignment: Alignment.center,
                                  child: Transform.scale(
                                    scale: 1.0 + bounce.value * 0.08,
                                    child: child,
                                  ),
                                );
                              },
                              child: PigioWidget(
                                key: ValueKey(Object.hash(
                                  Object.hashAll(state.activeOutfit.values),
                                  Object.hashAll(state.outfitColors.values),
                                  state.mascotScarfColor,
                                  viewAngle,
                                )),
                                mood: PigMood.normal,
                                size: 130,
                                scarfColor: state.mascotScarfColor,
                                outfit: state.activeOutfit,
                                outfitColors: state.outfitColors,
                                viewAngle: viewAngle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Rotation angle indicator dots
                  if (progress < 0.6)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: PigViewAngle.values.map((a) {
                          final isActive = viewAngle == a;
                          return Container(
                            width: isActive ? 8 : 5,
                            height: isActive ? 8 : 5,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? theme.primary
                                  : theme.mid.withValues(alpha: 0.3),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  Offstage(
                    offstage: progress >= 0.8,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _kSlotFilters
                            .where((f) => f.slot != null)
                            .map((f) => Semantics(
                                  label: "${state.locale.languageCode == 'fr' ? f.labelFr : f.labelEn}, ${state.activeOutfit[f.slot] != null ? 'équipé' : 'vide'}",
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
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Photo',
                  emoji: '📸',
                  color: const Color(0xFF9C6FE3),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MascotPhotoboothScreen()),
                    );
                  },
                ),
              ),
            ],
          ),

          if (equippedCount > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
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
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => MascotShareService.shareOutfitCard(
                    context: context,
                    state: state,
                  ),
                  icon: const Text('📤', style: TextStyle(fontSize: 13)),
                  label: Text("Partager",
                    style: fw(size: 12, w: FontWeight.w800, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
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
// Outfit of the Day Card
// ─────────────────────────────────────────────────────────────

class _OutfitOfTheDayCard extends StatelessWidget {
  final PigioAppState state;
  final PigioThemeData theme;
  final VoidCallback onApply;

  const _OutfitOfTheDayCard({
    required this.state,
    required this.theme,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final ootd = MascotOutfitEngine.suggestOutfitOfTheDay(state, weather: state.currentWeather);
    if (ootd.isEmpty) return const SizedBox.shrink();

    final isFr = state.locale.languageCode == 'fr';
    final emojis = ootd.values
        .map((id) => MascotOutfitEngine.getItem(id)?.emoji ?? '')
        .where((e) => e.isNotEmpty)
        .join(' ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A6FE3), Color(0xFF9C6FE3)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFr ? 'Tenue du jour' : 'Outfit of the Day',
                    style: fw(size: 13, w: FontWeight.w700, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(emojis, style: const TextStyle(fontSize: 22)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onApply,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isFr ? 'Appliquer' : 'Apply',
                  style: fw(size: 13, w: FontWeight.w700, color: Colors.white),
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
// Daily Challenge Banner
// ─────────────────────────────────────────────────────────────

class _DailyChallengeBanner extends StatelessWidget {
  final PigioAppState state;
  final PigioThemeData theme;

  const _DailyChallengeBanner({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isFr = state.locale.languageCode == 'fr';
    final challenge = MascotOutfitEngine.todaysChallenge(DateTime.now());
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final isCompleted = state.dailyChallengeCompleted == todayStr;
    final isMet = MascotOutfitEngine.isChallengeMet(challenge, state);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCompleted
              ? const Color(0xFF1B8A4C).withValues(alpha: 0.08)
              : const Color(0xFFFFAA00).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFF1B8A4C).withValues(alpha: 0.25)
                : const Color(0xFFFFAA00).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Text(
              isCompleted ? '✅' : '🎯',
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFr ? 'Défi du jour' : 'Daily Challenge',
                    style: fw(size: 11, w: FontWeight.w700, color: theme.mid, letterSpacing: 1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isFr ? challenge.titleFr : challenge.titleEn,
                    style: fw(
                      size: 13,
                      w: FontWeight.w700,
                      color: isCompleted ? const Color(0xFF1B8A4C) : theme.ink,
                    ),
                  ),
                  if (isCompleted)
                    Text(
                      '+15 XP',
                      style: fw(size: 11, w: FontWeight.w700, color: const Color(0xFF1B8A4C)),
                    )
                  else if (isMet)
                    Text(
                      isFr ? 'Presque ! Continue...' : 'Almost there! Keep going...',
                      style: fw(size: 11, w: FontWeight.w600, color: const Color(0xFFFFAA00)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Collection Progress Card
// ─────────────────────────────────────────────────────────────

class _CollectionProgressCard extends StatelessWidget {
  final PigioAppState state;
  final PigioThemeData theme;

  const _CollectionProgressCard({required this.state, required this.theme});

  @override
  Widget build(BuildContext context) {
    final unlocked = MascotOutfitEngine.unlockedCount(state);
    final total = MascotOutfitEngine.totalItemCount;
    final combosCompleted = MascotOutfitEngine.completedComboCount(state);
    final combosTotal = MascotOutfitEngine.totalComboCount;
    final breakdown = MascotOutfitEngine.rarityBreakdown(state);
    final progress = total > 0 ? unlocked / total : 0.0;
    final isFr = state.locale.languageCode == 'fr';

    // Check collection milestones
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MascotOutfitEngine.checkCollectionMilestones(state);
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.divider),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Circular progress
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: theme.divider,
                        color: const Color(0xFFFFAA00),
                      ),
                      Text(
                        '$unlocked',
                        style: fw(size: 14, w: FontWeight.w800, color: theme.ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isFr ? 'Collection' : 'Collection',
                        style: fw(size: 15, w: FontWeight.w700, color: theme.ink),
                      ),
                      Text(
                        '$unlocked/$total ${isFr ? 'objets' : 'items'} · $combosCompleted/$combosTotal combos',
                        style: fw(size: 12, w: FontWeight.w500, color: theme.mid),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Rarity breakdown bars
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final rarity in ItemRarity.values)
                  _RarityBadge(
                    rarity: rarity,
                    unlocked: breakdown[rarity]!.unlocked,
                    total: breakdown[rarity]!.total,
                    theme: theme,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  final ItemRarity rarity;
  final int unlocked;
  final int total;
  final PigioThemeData theme;

  const _RarityBadge({
    required this.rarity,
    required this.unlocked,
    required this.total,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = _kRarityColors[rarity] ?? theme.mid;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$unlocked/$total ${rarity.name}',
        style: fw(size: 11, w: FontWeight.w700, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Share Format Option
// ─────────────────────────────────────────────────────────────

class _FormatOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FormatOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.divider),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(label, style: fw(size: 13, w: FontWeight.w700, color: theme.ink)),
            const SizedBox(height: 2),
            Text(subtitle, style: fw(size: 10, w: FontWeight.w500, color: theme.mid)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Countdown Badge (limited-time items)
// ─────────────────────────────────────────────────────────────

class _CountdownBadge extends StatelessWidget {
  final DateTime expiresAt;
  const _CountdownBadge({required this.expiresAt});

  @override
  Widget build(BuildContext context) {
    final remaining = expiresAt.difference(DateTime.now());
    final days = remaining.inDays;
    final label = days > 30 ? '${(days / 30).round()}mo' : '${days}d';
    final urgent = days <= 7;
    final color = urgent ? const Color(0xFFE63950) : const Color(0xFFFF6B35);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 10, color: color),
          const SizedBox(width: 2),
          Text(label, style: fw(size: 9, w: FontWeight.w800, color: color)),
        ],
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
  final String lang;
  final void Function(ClothingSlot?) onSelect;
  final bool showLimited;
  final int limitedCount;
  final VoidCallback onToggleLimited;

  _FilterBarDelegate({
    required this.selected,
    required this.theme,
    required this.lang,
    required this.onSelect,
    this.showLimited = false,
    this.limitedCount = 0,
    required this.onToggleLimited,
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
          children: [
            ..._kSlotFilters.map((f) {
              final isSelected = !showLimited && selected == f.slot;
              final accent = _kSlotAccents[f.slot] ?? theme.primary;
              final count = MascotOutfitEngine.countForSlot(f.slot);
              return Semantics(
                label: "${lang == 'fr' ? f.labelFr : f.labelEn}, $count ${lang == 'fr' ? 'articles' : 'items'}",
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
                          "${lang == 'fr' ? f.labelFr : f.labelEn} ($count)",
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
            }),
            if (limitedCount > 0)
              GestureDetector(
                onTap: onToggleLimited,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: showLimited ? const Color(0xFFFF6B35) : theme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: showLimited ? const Color(0xFFFF6B35) : theme.divider,
                    ),
                    boxShadow: showLimited
                        ? [BoxShadow(color: const Color(0xFFFF6B35).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('⏳', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        "${lang == 'fr' ? 'Limité' : 'Limited'} ($limitedCount)",
                        style: fw(
                          size: 13,
                          w: showLimited ? FontWeight.w800 : FontWeight.w600,
                          color: showLimited ? Colors.white : theme.mid,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_FilterBarDelegate old) =>
      old.selected != selected || old.theme != theme || old.lang != lang || old.showLimited != showLimited || old.limitedCount != limitedCount;
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
                    // ── Preview area with image or emoji ──
                    Expanded(
                      child: Center(
                        child: item.hasImage
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: Image.asset(item.imageAsset!, fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Text(item.emoji, style: const TextStyle(fontSize: 48))),
                              )
                            : Text(item.emoji, style: const TextStyle(fontSize: 48)),
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

                // ── Countdown badge (limited-time items) ──
                if (item.expiresAt != null && item.isAvailable && !isLocked)
                  Positioned(
                    top: 8, right: isEquipped ? 40 : 8,
                    child: _CountdownBadge(expiresAt: item.expiresAt!),
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
