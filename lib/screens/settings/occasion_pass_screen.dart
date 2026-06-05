import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/services/mascot_outfit_engine.dart';

class OccasionPassScreen extends StatelessWidget {
  const OccasionPassScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PigioAppState>(context);
    final theme = context.pt;
    final isFr = state.locale.languageCode == 'fr';
    final tiers = MascotOutfitEngine.occasionPassTiers;
    final currentLevel = state.occasionPassLevel;
    final hasPremiumPass = state.isPremium || state.hasOccasionPass;
    final season = MascotOutfitEngine.currentSeason();

    return Scaffold(
      backgroundColor: theme.scaffold,
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B35), Color(0xFFFF1744), Color(0xFF7C3AED)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Text(
                        isFr ? 'Occasion Pass' : 'Occasion Pass',
                        style: GoogleFonts.caveat(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFr ? 'Saison $season' : 'Season $season',
                        style: fw(size: 14, color: Colors.white70, w: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      // Progress bar
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (currentLevel / tiers.length).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$currentLevel / ${tiers.length}',
                        style: fw(size: 16, w: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Tier list ─────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, index) {
                  final tier = tiers[index];
                  final reached = currentLevel >= tier.level;
                  final locked = tier.premiumTrack && !hasPremiumPass;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: reached
                          ? (tier.premiumTrack
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.08)
                              : theme.success.withValues(alpha: 0.06))
                          : theme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: reached
                            ? (tier.premiumTrack ? const Color(0xFF7C3AED).withValues(alpha: 0.3) : theme.success.withValues(alpha: 0.3))
                            : theme.divider,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Level badge
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: reached
                                ? (tier.premiumTrack ? const Color(0xFF7C3AED) : theme.success)
                                : theme.surface,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: reached
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : Text('${tier.level}', style: fw(size: 14, w: FontWeight.w800, color: theme.mid)),
                        ),
                        const SizedBox(width: 14),
                        // Reward info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(tier.emoji, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      isFr ? tier.nameFr : tier.nameEn,
                                      style: fw(size: 15, w: FontWeight.w700, color: theme.ink),
                                    ),
                                  ),
                                ],
                              ),
                              if (tier.premiumTrack)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    isFr ? 'Piste premium' : 'Premium track',
                                    style: fw(size: 11, w: FontWeight.w600, color: const Color(0xFF7C3AED)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Status
                        if (reached && !locked)
                          Icon(Icons.check_circle, color: theme.success, size: 22)
                        else if (locked)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 12, color: const Color(0xFF7C3AED)),
                                const SizedBox(width: 4),
                                Text('Premium', style: fw(size: 11, w: FontWeight.w700, color: const Color(0xFF7C3AED))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
                childCount: tiers.length,
              ),
            ),
          ),

          // ── Purchase CTA for non-premium users ────────────────────
          if (!hasPremiumPass)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: GestureDetector(
                  onTap: () async {
                    final ok = await state.purchaseOccasionPass();
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isFr ? 'Occasion Pass activé !' : 'Occasion Pass activated!')),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isFr ? 'Débloquer la piste premium' : 'Unlock premium track',
                      textAlign: TextAlign.center,
                      style: fw(size: 16, w: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}
