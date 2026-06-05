import 'package:flutter/material.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/services/affiliate_service.dart';
import 'package:kindy/services/ai_service.dart';

/// A widget that shows AI-generated gift suggestions with affiliate links.
/// Designed to be dropped into a contact detail page or wish list.
class AiGiftSuggestions extends StatefulWidget {
  final ContactProfile contact;
  final PigioAppState state;
  final PigioThemeData theme;

  const AiGiftSuggestions({
    super.key,
    required this.contact,
    required this.state,
    required this.theme,
  });

  @override
  State<AiGiftSuggestions> createState() => _AiGiftSuggestionsState();
}

class _AiGiftSuggestionsState extends State<AiGiftSuggestions> {
  List<Map<String, String>>? _suggestions;
  bool _loading = false;
  String? _error;

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; });

    // Check concierge limit for free users
    final isPremium = widget.state.isPremium;
    if (!isPremium) {
      final remaining = await AiService.remainingFreeConcierge();
      if (remaining <= 0) {
        if (!mounted) return;
        final isFr = widget.state.locale.languageCode == 'fr';
        setState(() {
          _loading = false;
          _error = isFr
              ? 'Limite atteinte ce mois-ci. Passez à Pigio+ pour des suggestions illimitées !'
              : 'Monthly limit reached. Upgrade to Pigio+ for unlimited suggestions!';
        });
        return;
      }
    }

    final existingWishes = widget.state.wishes
        .where((w) => w.contactId == widget.contact.id)
        .map((w) => w.title)
        .toList();

    final results = await AiService.generateGiftSuggestions(
      widget.contact,
      personalityContext: widget.state.personalityProfileSummary,
      existingWishes: existingWishes,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _suggestions = results.isNotEmpty ? results : null;
      if (results.isEmpty) {
        final isFr = widget.state.locale.languageCode == 'fr';
        _error = isFr
            ? 'Impossible de générer des suggestions pour le moment.'
            : 'Could not generate suggestions right now.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isFr = widget.state.locale.languageCode == 'fr';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isFr ? 'Idées cadeaux IA' : 'AI Gift Ideas',
                  style: fw(size: 16, w: FontWeight.w700, color: theme.ink),
                ),
              ),
              if (_suggestions == null && !_loading)
                GestureDetector(
                  onTap: _generate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isFr ? 'Générer' : 'Generate',
                      style: fw(size: 13, w: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),

          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: fw(size: 13, color: theme.mid)),
          ],

          if (_suggestions != null) ...[
            const SizedBox(height: 12),
            ..._suggestions!.map((s) => _SuggestionTile(
                  name: s['name'] ?? '',
                  emoji: s['emoji'] ?? '🎁',
                  searchUrl: s['searchUrl'] ?? '',
                  theme: theme,
                )),
            const SizedBox(height: 4),
            Text(
              isFr ? 'Les liens mènent vers Amazon.fr' : 'Links lead to Amazon.fr',
              style: fw(size: 11, color: theme.light),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String name;
  final String emoji;
  final String searchUrl;
  final PigioThemeData theme;

  const _SuggestionTile({
    required this.name,
    required this.emoji,
    required this.searchUrl,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: searchUrl.isNotEmpty
          ? () => AffiliateService.openAffiliateUrl(searchUrl)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(name, style: fw(size: 14, w: FontWeight.w600, color: theme.ink)),
            ),
            if (searchUrl.isNotEmpty)
              Icon(Icons.open_in_new, size: 16, color: theme.mid),
          ],
        ),
      ),
    );
  }
}
