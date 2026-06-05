import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';

/// Year-end "Pigio Wrapped" summary screen — shows the user's gifting
/// stats for the current year alongside an AI-generated quip from Pigio.
class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  String _quip = '';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _generateQuip();
  }

  void _generateQuip() {
    final state = Provider.of<PigioAppState>(context, listen: false);
    final isFr = state.locale.languageCode == 'fr';
    final wishCount = state.wishes.where((w) => w.contactId == null).length;
    final reservedCount = state.wishes.where((w) => w.contactId != null && w.reservedById != null).length;
    final contactCount = state.contacts.length;
    final rng = math.Random();

    final List<String> pool;
    if (isFr) {
      pool = [
        if (wishCount == 0) "Nouvelle année, nouvelles envies à découvrir ! — Pigio 🎁",
        if (wishCount > 0 && wishCount <= 3) "$wishCount vœux tout doux. Discret, mais efficace ! — Pigio 🎁",
        if (wishCount > 3 && wishCount <= 10) "$wishCount envies cette année ! Tu sais ce que tu veux. — Pigio 🎁",
        if (wishCount > 10) "$wishCount envies ?! Tu es une machine à rêves ! — Pigio 🎁",
        if (reservedCount > 0) "$reservedCount cadeaux réservés en secret… Quel(le) complice ! — Pigio 🤫",
        if (contactCount >= 5) "$contactCount proches dans ton cercle. Belle équipe ! — Pigio 💛",
        if (contactCount == 0) "L'aventure Pigio ne fait que commencer ! — Pigio 🐧",
        "Une année de plus avec toi, et c'est toujours un bonheur. — Pigio 💛",
        "Merci d'avoir partagé cette année avec moi ! — Pigio 🎉",
      ];
    } else {
      pool = [
        if (wishCount == 0) "New year, new wishes to discover! — Pigio 🎁",
        if (wishCount > 0 && wishCount <= 3) "$wishCount gentle wishes. Subtle, but effective! — Pigio 🎁",
        if (wishCount > 3 && wishCount <= 10) "$wishCount wishes this year! You know what you want. — Pigio 🎁",
        if (wishCount > 10) "$wishCount wishes?! You're a dream machine! — Pigio 🎁",
        if (reservedCount > 0) "$reservedCount gifts secretly reserved… What a co-conspirator! — Pigio 🤫",
        if (contactCount >= 5) "$contactCount people in your circle. Great team! — Pigio 💛",
        if (contactCount == 0) "The Pigio adventure is just getting started! — Pigio 🐧",
        "Another year with you, and it's always a joy. — Pigio 💛",
        "Thanks for sharing this year with me! — Pigio 🎉",
      ];
    }
    _quip = pool[rng.nextInt(pool.length)];
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context);
    final now = DateTime.now();
    final year = now.year;
    final isFr = state.locale.languageCode == 'fr';

    // ── Compute stats ──────────────────────────────────────────────
    final ownWishes = state.wishes.where((w) => w.contactId == null).toList();
    final contactWishes = state.wishes.where((w) => w.contactId != null).toList();
    final reservedCount = contactWishes.where((w) => w.reservedById != null).length;
    final totalContacts = state.contacts.length;
    final joinedContacts =
        state.contacts.where((c) => c.status == ContactStatus.joined).length;
    final sizeCategories = state.sizes.where((s) => s.contactId == null).length;
    final totalEvents = state.events.length;

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: PigioAppBar(
        title: 'Pigio Wrapped $year',
        showNotification: false,
      ),
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Hero mascot
            Center(
              child: Text('🐧🎁', style: TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                isFr ? 'Ton année en cadeaux' : 'Your gifting year',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: theme.ink,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Stats grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _statCard(theme, '${ownWishes.length}',
                    isFr ? 'Vœux ajoutés' : 'Wishes added', '🎁'),
                _statCard(theme, '$reservedCount',
                    isFr ? 'Cadeaux réservés' : 'Gifts reserved', '🤫'),
                _statCard(theme, '$totalContacts',
                    isFr ? 'Contacts' : 'Contacts', '👥'),
                _statCard(theme, '$joinedContacts',
                    isFr ? 'Connectés Pigio' : 'Pigio connected', '🔗'),
                _statCard(theme, '$sizeCategories',
                    isFr ? 'Tailles enregistrées' : 'Sizes saved', '📏'),
                _statCard(theme, '$totalEvents',
                    isFr ? 'Événements' : 'Events', '📅'),
              ],
            ),
            const SizedBox(height: 28),

            // AI quip
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.ink.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                      _quip,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.ink,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(height: 28),

            // Top wish highlight
            if (ownWishes.isNotEmpty) ...[
              Text(
                isFr ? 'TON VŒU LE PLUS POPULAIRE' : 'YOUR TOP WISH',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: theme.mid,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${ownWishes.first.emoji} ${ownWishes.first.title}',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: theme.ink,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _statCard(PigioThemeData theme, String value, String label, String emoji) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.ink.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: theme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.mid,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
