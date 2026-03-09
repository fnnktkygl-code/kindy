import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/i18n/i18n.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';
import 'package:pigio_app/shared/widgets/wish_card.dart';
import 'package:pigio_app/shared/widgets/gift_pot_card.dart';
import 'package:pigio_app/screens/wishes/sheets/wish_editor_sheet.dart';
import 'package:pigio_app/screens/wishes/sheets/gift_pot_editor_sheet.dart';
import 'package:pigio_app/screens/wishes/sheets/gift_pot_detail_sheet.dart';

// ─── Dotted paper background painter ──────────────────────────────────────────
class _DottedPaperPainter extends CustomPainter {
  final Color dotColor;
  const _DottedPaperPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    const spacing = 22.0;
    const radius = 1.1;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DottedPaperPainter old) => old.dotColor != dotColor;
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class WishesScreen extends StatefulWidget {
  const WishesScreen({super.key});

  @override
  State<WishesScreen> createState() => _WishesScreenState();
}

class _WishesScreenState extends State<WishesScreen> {
  String _currentTab = "grid";
  WishPriority? _priorityFilter;
  bool? _reservedFilter; // null=all, true=reserved, false=unreserved

  // Scrapbook tab pills
  Widget _buildTab(String id, String label, PigioThemeData theme) {
    final active = _currentTab == id;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = id),
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

  String _getMonthName(int month) {
    const m = [
      "Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
      "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"
    ];
    return m[month - 1];
  }

  ImageProvider? _getImageProvider(String? path) {
    if (path == null || path.isEmpty || path == 'null') return null;
    if (path.startsWith('http')) return CachedNetworkImageProvider(path);
    final file = File(path);
    if (file.existsSync()) return FileImage(file);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;

    final dotColor = theme.isDark
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.black.withValues(alpha: 0.07);

    // Keep sepia paper tint only for sepia theme; light uses its own scaffold.
    final paperBg = theme.variant == PigioThemeVariant.sepia
      ? const Color(0xFFF6F3EC)
      : theme.scaffold;

    final wishes = context.select<PigioAppState, List<Wish>>(
            (state) => state.getWishesFor(null));
    final archivedWishes = context.select<PigioAppState, List<Wish>>(
            (state) => state.getArchivedWishesFor(null));
    final surpriseMode = context.select<PigioAppState, bool>(
            (state) => state.surpriseMode);
    final giftPots = context.select<PigioAppState, List<GiftPot>>(
            (state) => state.activePots);

    return Scaffold(
      backgroundColor: paperBg,
      // ── Custom app bar that fits the scrapbook header ──────────────────────
      appBar: PigioAppBar(
        title: t(context, 'wishes_title'),
        autoShowBackFromCanPop: false,
      ),
      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.accent2,
        elevation: 6,
        onPressed: () async {
          if (_currentTab == "pots") {
            _showPotEditorSheet(context, theme);
          } else {
            final state = context.read<PigioAppState>();
            final originalCount = state.getWishesFor(null).length;
            final added = await _showAddWishDialog(context, state, theme);
            if (added == true &&
                originalCount == 0 &&
                state.getWishesFor(null).length == 1) {
              state.setMascotMoment(MascotMoment.firstWish);
            }
          }
        },
        icon: Icon(
          _currentTab == "pots" ? Icons.group_add : Icons.favorite,
          color: theme.onAccent,
          size: 20,
        ),
        label: Text(
          _currentTab == "pots"
              ? t(context, 'pot_new')
              : "Nouvelle Envie",
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: theme.onAccent,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      body: Stack(
        children: [
          // ── Dotted paper background ────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _DottedPaperPainter(dotColor: dotColor),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Tab row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        _buildTab("grid", "Mes envies", theme),
                        const SizedBox(width: 10),
                        _buildTab("history", "Archivées", theme),
                        const SizedBox(width: 10),
                        _buildTab("pots", t(context, 'gift_pots'), theme),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Filter chips (grid tab only) ──────────────────────
                  if (_currentTab == "grid" && wishes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(null, '🎯 Tout', theme,
                                isActive: _priorityFilter == null && _reservedFilter == null,
                                onTap: () => setState(() {
                                  _priorityFilter = null;
                                  _reservedFilter = null;
                                })),
                            const SizedBox(width: 6),
                            _buildFilterChip(WishPriority.high, '🔥 Priorité', theme,
                                isActive: _priorityFilter == WishPriority.high,
                                onTap: () => setState(() {
                                  _priorityFilter = _priorityFilter == WishPriority.high ? null : WishPriority.high;
                                })),
                            const SizedBox(width: 6),
                            _buildFilterChip(WishPriority.medium, '⭐ Normal', theme,
                                isActive: _priorityFilter == WishPriority.medium,
                                onTap: () => setState(() {
                                  _priorityFilter = _priorityFilter == WishPriority.medium ? null : WishPriority.medium;
                                })),
                            const SizedBox(width: 6),
                            _buildFilterChip(WishPriority.low, '💤 Pas pressé', theme,
                                isActive: _priorityFilter == WishPriority.low,
                                onTap: () => setState(() {
                                  _priorityFilter = _priorityFilter == WishPriority.low ? null : WishPriority.low;
                                })),
                            const SizedBox(width: 6),
                            _buildFilterChip(null, '✅ Réservé', theme,
                                isActive: _reservedFilter == true,
                                onTap: () => setState(() {
                                  _reservedFilter = _reservedFilter == true ? null : true;
                                })),
                            const SizedBox(width: 6),
                            _buildFilterChip(null, '🎁 Libre', theme,
                                isActive: _reservedFilter == false,
                                onTap: () => setState(() {
                                  _reservedFilter = _reservedFilter == false ? null : false;
                                })),
                          ],
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _currentTab == "grid"
                        ? (wishes.isEmpty && _reservedFilter != true
                        ? _buildEmptyState(theme)
                        : _buildSmartMasonryGrid(
                        _applyWishFilters(wishes, context.read<PigioAppState>()), theme,
                        context.read<PigioAppState>(),
                        surpriseMode))
                        : _currentTab == "pots"
                        ? _buildPotsContent(giftPots, theme)
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildGroupedWishes(
                          archivedWishes,
                          theme,
                          context.read<PigioAppState>()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Wish Filters ──────────────────────────────────────────────────────────

  List<Wish> _applyWishFilters(List<Wish> wishes, PigioAppState state) {
    var filtered = wishes;
    if (_priorityFilter != null) {
      filtered = filtered.where((w) => w.priority == _priorityFilter).toList();
    }
    if (_reservedFilter != null) {
      if (_reservedFilter!) {
        // Show own reserved wishes + wishes from contacts that the user reserved
        final ownReserved = filtered.where((w) => w.reservedById != null).toList();
        final ownIds = ownReserved.map((w) => w.id).toSet();
        final contactReserved = state.wishes
            .where((w) => w.contactId != null && w.reservedById == 'self' && !ownIds.contains(w.id))
            .toList();
        filtered = [...ownReserved, ...contactReserved];
      } else {
        filtered = filtered.where((w) => w.reservedById == null).toList();
      }
    }
    return filtered;
  }

  Widget _buildFilterChip(
    WishPriority? priority,
    String label,
    PigioThemeData theme, {
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? theme.accent2.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? theme.accent2 : theme.divider,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: fw(
            size: 12,
            w: FontWeight.w700,
            color: isActive ? theme.accent2 : theme.mid,
          ),
        ),
      ),
    );
  }

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState(PigioThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            // Animated dashed circle
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 1),
              builder: (ctx, val, _) => Opacity(
                opacity: val,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.mid.withValues(alpha: 0.35),
                      width: 2.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text("💭", style: TextStyle(fontSize: 38)),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              "Une page blanche...",
              style: GoogleFonts.caveat(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: theme.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "C'est le moment de coller ici\ntes premières idées cadeaux !",
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.mid,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grouped archived wishes ─────────────────────────────────────────────────
  List<Widget> _buildGroupedWishes(
      List<Wish> wishes, PigioThemeData theme, PigioAppState state) {
    Map<String, List<Wish>> grouped = {};
    for (var w in wishes) {
      String k =
          "${w.addedAt.year}-${w.addedAt.month.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(k, () => []).add(w);
    }
    var sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    List<Widget> sections = [];

    for (var key in sortedKeys) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final isCurrentMonth =
          DateTime.now().year == year && DateTime.now().month == month;
      final title =
      isCurrentMonth ? "Ce mois-ci" : "${_getMonthName(month)} $year";

      sections.add(Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 10, left: 4),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: theme.mid,
            letterSpacing: 1.4,
          ),
        ),
      ));

      for (var w in grouped[key]!) {
        sections.add(GestureDetector(
          onTap: () => _showAddWishDialog(context, state, theme, existingWish: w),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.divider),
            ),
            child: ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(10),
                  image: _getImageProvider(w.imageUrl) != null
                      ? DecorationImage(
                          image: _getImageProvider(w.imageUrl)!,
                          fit: BoxFit.cover)
                      : null,
                ),
                alignment: Alignment.center,
                child: _getImageProvider(w.imageUrl) == null
                    ? Text(w.emoji,
                        style: const TextStyle(fontSize: 22))
                    : null,
              ),
              title: Text(w.title,
                  style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
              subtitle: w.reservedById != null
                  ? Text("Réservé 🎁",
                  style: fw(
                      size: 12, w: FontWeight.w700, color: theme.success))
                  : Text(w.addedAt.year.toString(),
                  style: fw(size: 12, w: FontWeight.w600, color: theme.mid)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (w.priority == WishPriority.high) ...[
                    Icon(Icons.local_fire_department,
                        color: theme.warning, size: 16),
                    const SizedBox(width: 4),
                  ],
                  if (w.url != null)
                    Icon(Icons.link, color: theme.primary, size: 18),
                  if (w.reservedById != null) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle, color: theme.success, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ));
      }
    }
    return sections;
  }

  // ── Masonry grid ────────────────────────────────────────────────────────────
  Widget _buildSmartMasonryGrid(List<Wish> wishes, PigioThemeData theme,
      PigioAppState state, bool surpriseMode) {
    return SmartMasonryGrid(
      estimatedHeights:
      wishes.map((w) => WishCard.estimateHeight(w)).toList(),
      children: wishes
          .map((w) => WishCard(
        wish: w,
        theme: theme,
        surpriseMode: surpriseMode,
        isMine: w.contactId == null,
        onTap: () =>
            _showAddWishDialog(context, state, theme, existingWish: w),
        onEdit: () =>
            _showAddWishDialog(context, state, theme, existingWish: w),
        onDelete: () async {
          final confirm =
          await _showDeleteConfirmation(context, theme);
          if (confirm == true) state.deleteWish(w.id);
        },
      ))
          .toList(),
    );
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────
  Future<bool?> _showDeleteConfirmation(
      BuildContext context, PigioThemeData theme) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.sheet,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Supprimer l'envie ?",
            style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
        content: Text(
            "Cette action est irréversible. Voulez-vous vraiment supprimer cet article ?",
            style: fw(size: 14, w: FontWeight.w600, color: theme.mid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Annuler",
                style: fw(size: 14, w: FontWeight.w800, color: theme.mid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Supprimer",
                style: fw(size: 14, w: FontWeight.w900, color: theme.error)),
          ),
        ],
      ),
    );
  }

  void _showPotEditorSheet(BuildContext context, PigioThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => const GiftPotEditorSheet(),
    );
  }

  Widget _buildPotsContent(List<GiftPot> pots, PigioThemeData theme) {
    if (pots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(
            children: [
              const Text("🎁", style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                "Pas encore de cagnotte",
                style: GoogleFonts.caveat(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: theme.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Créez une cagnotte pour offrir\nun cadeau à plusieurs !",
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.mid,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final state = context.read<PigioAppState>();
    return SmartMasonryGrid(
      estimatedHeights: pots.map((p) => GiftPotCard.estimateHeight(p)).toList(),
      children: pots.map((pot) {
        final recipientName = state.contacts
                .where((c) => c.id == pot.recipientContactId)
                .firstOrNull
                ?.name ??
            '?';
        return GiftPotCard(
          pot: pot,
          theme: theme,
          recipientName: recipientName,
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: theme.sheet,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              builder: (ctx) => GiftPotDetailSheet(potId: pot.id),
            );
          },
        );
      }).toList(),
    );
  }

  Future<bool?> _showAddWishDialog(
      BuildContext context, PigioAppState state, PigioThemeData theme,
      {Wish? existingWish}) async {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) =>
          WishEditorSheet(state: state, existingWish: existingWish),
    );
  }
}
