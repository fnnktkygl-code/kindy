import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';
import 'package:pigio_app/services/ai_service.dart';

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
  String? _aiQuip;
  bool _loadingAI = true;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _loadAIQuip();
  }

  Future<void> _loadAIQuip() async {
    final state = Provider.of<PigioAppState>(context, listen: false);
    final allWishes = state.wishes.where((w) => w.contactId == null).toList();
    final quip = await AiService.generatePigioWrapped(allWishes);
    if (mounted) {
      setState(() {
        _aiQuip = quip;
        _loadingAI = false;
      });
    }
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
              child: _loadingAI
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(
                          color: theme.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Text(
                      _aiQuip ?? (isFr
                          ? 'Pigio n\'a pas pu résumer ton année cette fois. 🐧'
                          : 'Pigio couldn\'t summarize your year this time. 🐧'),
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
