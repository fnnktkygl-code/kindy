import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/services/mascot_outfit_engine.dart';
import 'package:kindy/services/subscription_service.dart';

class PlumesShopScreen extends StatefulWidget {
  const PlumesShopScreen({super.key});

  @override
  State<PlumesShopScreen> createState() => _PlumesShopScreenState();
}

class _PlumesShopScreenState extends State<PlumesShopScreen> {
  bool _purchasing = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PigioAppState>(context);
    final theme = context.pt;
    final isFr = state.locale.languageCode == 'fr';

    final plumeItems = MascotOutfitEngine.catalog
        .where((i) => i.isPlumeItem)
        .toList()
      ..sort((a, b) => (a.plumeCost ?? 0).compareTo(b.plumeCost ?? 0));

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💎', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              isFr ? 'Boutique Plumes' : 'Plumes Shop',
              style: fw(size: 20, w: FontWeight.w800, color: theme.ink),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Balance card ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    isFr ? 'Votre solde' : 'Your balance',
                    style: fw(size: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${state.plumes}',
                    style: GoogleFonts.caveat(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Plumes',
                    style: fw(size: 16, w: FontWeight.w700, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Buy Plumes packs ─────────────────────────────────────
            Text(
              isFr ? 'Acheter des Plumes' : 'Buy Plumes',
              style: fw(size: 18, w: FontWeight.w800, color: theme.ink),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PlumePack(
                    amount: 100,
                    price: '0,99 €',
                    theme: theme,
                    purchasing: _purchasing,
                    onTap: () => _buyPack(state, SubscriptionService.kPlumes100),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PlumePack(
                    amount: 500,
                    price: '3,99 €',
                    badge: isFr ? 'Populaire' : 'Popular',
                    theme: theme,
                    purchasing: _purchasing,
                    onTap: () => _buyPack(state, SubscriptionService.kPlumes500),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PlumePack(
                    amount: 1200,
                    price: '7,99 €',
                    badge: isFr ? '-33%' : '-33%',
                    theme: theme,
                    purchasing: _purchasing,
                    onTap: () => _buyPack(state, SubscriptionService.kPlumes1200),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Premium items ────────────────────────────────────────
            Text(
              isFr ? 'Objets exclusifs' : 'Exclusive items',
              style: fw(size: 18, w: FontWeight.w800, color: theme.ink),
            ),
            const SizedBox(height: 12),
            ...plumeItems.map((item) => _PlumeItemTile(
                  item: item,
                  owned: state.unlockedClothing.contains(item.id),
                  canAfford: state.plumes >= (item.plumeCost ?? 0),
                  isPremium: state.isPremium,
                  theme: theme,
                  isFr: isFr,
                  onBuy: () {
                    final ok = state.purchaseWithPlumes(item.id);
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFr
                              ? '${item.emoji} ${item.name} débloqué !'
                              : '${item.emoji} ${item.name} unlocked!'),
                        ),
                      );
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _buyPack(PigioAppState state, String productId) async {
    setState(() => _purchasing = true);
    await state.purchasePlumePack(productId);
    if (mounted) setState(() => _purchasing = false);
  }
}

// ── Plume Pack Card ──────────────────────────────────────────────────────────

class _PlumePack extends StatelessWidget {
  final int amount;
  final String price;
  final String? badge;
  final PigioThemeData theme;
  final bool purchasing;
  final VoidCallback onTap;

  const _PlumePack({
    required this.amount,
    required this.price,
    this.badge,
    required this.theme,
    required this.purchasing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: purchasing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.divider),
        ),
        child: Column(
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge!, style: fw(size: 9, w: FontWeight.w800, color: Colors.white)),
              ),
            Text('💎', style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text('$amount', style: fw(size: 18, w: FontWeight.w800, color: theme.ink)),
            const SizedBox(height: 4),
            Text(price, style: fw(size: 13, w: FontWeight.w600, color: const Color(0xFF7C3AED))),
          ],
        ),
      ),
    );
  }
}

// ── Plume Item Tile ──────────────────────────────────────────────────────────

class _PlumeItemTile extends StatelessWidget {
  final ClothingItem item;
  final bool owned;
  final bool canAfford;
  final bool isPremium;
  final PigioThemeData theme;
  final bool isFr;
  final VoidCallback onBuy;

  const _PlumeItemTile({
    required this.item,
    required this.owned,
    required this.canAfford,
    required this.isPremium,
    required this.theme,
    required this.isFr,
    required this.onBuy,
  });

  static const _kRarityColors = {
    ItemRarity.common: Color(0xFF9E9E9E),
    ItemRarity.uncommon: Color(0xFF4CAF50),
    ItemRarity.rare: Color(0xFF2196F3),
    ItemRarity.legendary: Color(0xFFFF9800),
  };

  @override
  Widget build(BuildContext context) {
    final rarityColor = _kRarityColors[item.rarity] ?? theme.mid;
    final locked = item.premiumOnly && !isPremium;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: owned ? Border.all(color: theme.success.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(item.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(item.name, style: fw(size: 15, w: FontWeight.w700, color: theme.ink)),
                    ),
                    if (item.premiumOnly) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('PIGIO+', style: fw(size: 9, w: FontWeight.w800, color: const Color(0xFF7C3AED))),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.rarity.name.toUpperCase(),
                  style: fw(size: 11, w: FontWeight.w700, color: rarityColor),
                ),
              ],
            ),
          ),
          // Price / Owned badge
          if (owned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isFr ? 'Obtenu' : 'Owned',
                style: fw(size: 12, w: FontWeight.w700, color: theme.success),
              ),
            )
          else
            GestureDetector(
              onTap: (canAfford && !locked) ? onBuy : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (canAfford && !locked)
                      ? const Color(0xFF7C3AED)
                      : theme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (locked)
                      Icon(Icons.lock, size: 12, color: theme.mid)
                    else ...[
                      const Text('💎', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      locked
                          ? 'Pigio+'
                          : '${item.plumeCost}',
                      style: fw(
                        size: 13,
                        w: FontWeight.w700,
                        color: (canAfford && !locked) ? Colors.white : theme.mid,
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
}
