import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/services/subscription_service.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';

class PigioPlusScreen extends StatefulWidget {
  const PigioPlusScreen({super.key});

  @override
  State<PigioPlusScreen> createState() => _PigioPlusScreenState();
}

class _PigioPlusScreenState extends State<PigioPlusScreen> {
  bool _yearly = true;
  bool _purchasing = false;
  bool _restoring = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PigioAppState>(context);
    final theme = context.pt;
    final isFr = state.locale.languageCode == 'fr';
    final isPremium = state.isPremium;

    return Scaffold(
      backgroundColor: theme.scaffold,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.primary,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    children: [
                      // Close button
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset('icon/app_icon.png', fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Pigio+',
                        style: GoogleFonts.caveat(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isFr
                            ? 'Débloquez le plein potentiel de Pigio'
                            : 'Unlock Pigio\'s full potential',
                        style: fw(size: 15, color: Colors.white70, w: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      if (isPremium) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                isFr ? 'Abonnement actif' : 'Active subscription',
                                style: fw(size: 14, w: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Features list ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFr ? 'Avantages Pigio+' : 'Pigio+ Perks',
                    style: fw(size: 20, w: FontWeight.w800, color: theme.ink),
                  ),
                  const SizedBox(height: 16),
                  _FeatureRow(
                    icon: Icons.auto_awesome,
                    color: const Color(0xFFFFD54F),
                    title: isFr ? 'Garde-robe exclusive' : 'Exclusive wardrobe',
                    subtitle: isFr
                        ? 'Accédez aux objets légendaires et aux drops saisonniers en avance'
                        : 'Access legendary items and early seasonal drops',
                    theme: theme,
                  ),
                  _FeatureRow(
                    icon: Icons.cloud_outlined,
                    color: const Color(0xFF7C3AED),
                    title: isFr ? 'Sauvegarde Cloud E2E' : 'E2E Cloud Backup',
                    subtitle: isFr
                        ? 'Sauvegarde chiffrée de vos données avec restauration'
                        : 'Encrypted data backup with recovery',
                    theme: theme,
                  ),
                  _FeatureRow(
                    icon: Icons.insights,
                    color: const Color(0xFF2196F3),
                    title: isFr ? 'Statistiques avancées' : 'Advanced analytics',
                    subtitle: isFr
                        ? 'Insights sur vos habitudes de cadeau et vos cercles'
                        : 'Insights on your gifting habits and circles',
                    theme: theme,
                  ),
                  _FeatureRow(
                    icon: Icons.card_giftcard,
                    color: const Color(0xFFDB2777),
                    title: isFr ? 'Suggestions IA' : 'AI suggestions',
                    subtitle: isFr
                        ? 'Recommandations de cadeaux personnalisées par l\'IA'
                        : 'Personalized AI gift recommendations',
                    theme: theme,
                  ),
                  _FeatureRow(
                    icon: Icons.palette_outlined,
                    color: const Color(0xFFFF9800),
                    title: isFr ? 'Thèmes premium' : 'Premium themes',
                    subtitle: isFr
                        ? 'Débloquez des thèmes exclusifs pour votre app'
                        : 'Unlock exclusive app themes',
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),

          // ── Plan picker + CTA ────────────────────────────────────────
          if (!isPremium)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Plan toggle
                    Row(
                      children: [
                        Expanded(
                          child: _PlanCard(
                            selected: _yearly,
                            title: isFr ? 'Annuel' : 'Yearly',
                            price: '29,99 €',
                            badge: isFr ? '-40%' : '-40%',
                            subtitle: isFr ? '2,50 € / mois' : '€2.50 / month',
                            theme: theme,
                            onTap: () => setState(() => _yearly = true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PlanCard(
                            selected: !_yearly,
                            title: isFr ? 'Mensuel' : 'Monthly',
                            price: '4,99 €',
                            subtitle: isFr ? 'par mois' : 'per month',
                            theme: theme,
                            onTap: () => setState(() => _yearly = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Purchase button
                    PigioButton(
                      label: _purchasing
                          ? (isFr ? 'Chargement...' : 'Loading...')
                          : (isFr ? 'S\'abonner à Pigio+' : 'Subscribe to Pigio+'),
                      icon: Icons.star,
                      color: const Color(0xFF7C3AED),
                      textColor: Colors.white,
                      height: 54,
                      fontSize: 16,
                      fullWidth: true,
                      onTap: _purchasing
                          ? null
                          : () async {
                              setState(() => _purchasing = true);
                              final ok = _yearly
                                  ? await SubscriptionService.purchasePigioPlusYearly()
                                  : await SubscriptionService.purchasePigioPlusMonthly();
                              if (!mounted) return;
                              setState(() => _purchasing = false);
                              if (ok) {
                                if (!context.mounted) return;
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isFr
                                        ? 'Bienvenue dans Kindy+ ! 🎉'
                                        : 'Welcome to Kindy+! 🎉'),
                                  ),
                                );
                              }
                            },
                    ),
                    const SizedBox(height: 12),

                    // Restore purchases
                    TextButton(
                      onPressed: _restoring
                          ? null
                          : () async {
                              setState(() => _restoring = true);
                              await state.restorePurchases();
                              if (!mounted) return;
                              setState(() => _restoring = false);
                              if (state.isPremium && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      child: Text(
                        isFr ? 'Restaurer mes achats' : 'Restore purchases',
                        style: fw(size: 14, color: theme.mid),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Premium status section ───────────────────────────────────
          if (isPremium)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: theme.success, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isFr ? 'Abonnement actif' : 'Active subscription',
                            style: fw(size: 16, w: FontWeight.w700, color: theme.ink),
                          ),
                        ],
                      ),
                      if (state.plusExpirationDate != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, color: theme.mid, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              isFr
                                  ? 'Renouvellement : ${_formatDate(state.plusExpirationDate!)}'
                                  : 'Renews: ${_formatDate(state.plusExpirationDate!)}',
                              style: fw(size: 13, color: theme.mid),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}

// ── Feature Row ──────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final PigioThemeData theme;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: fw(size: 15, w: FontWeight.w700, color: theme.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: fw(size: 13, color: theme.mid)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Plan Card ────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String price;
  final String? badge;
  final String subtitle;
  final PigioThemeData theme;
  final VoidCallback onTap;

  const _PlanCard({
    required this.selected,
    required this.title,
    required this.price,
    this.badge,
    required this.subtitle,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED).withValues(alpha: 0.08) : theme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF7C3AED) : theme.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: fw(size: 14, w: FontWeight.w700, color: theme.ink)),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDB2777),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge!, style: fw(size: 10, w: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(price, style: fw(size: 22, w: FontWeight.w800, color: theme.ink)),
            const SizedBox(height: 4),
            Text(subtitle, style: fw(size: 12, color: theme.mid)),
          ],
        ),
      ),
    );
  }
}
