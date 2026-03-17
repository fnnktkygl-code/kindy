import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';
import 'package:pigio_app/shared/widgets/pigio_painter.dart';

/// E10: Pigio Memories — a timeline of meaningful moments shared with the mascot.
/// Reinforces emotional bond and gives long-term retention value.
class MascotMemoriesScreen extends StatelessWidget {
  const MascotMemoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final lang = state.locale.languageCode;
    final memories = state.mascotMemories;

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: PigioAppBar(title: lang == 'fr' ? "Souvenirs" : "Memories", showNotification: false),
      body: SafeArea(
        child: memories.isEmpty
            ? _buildEmptyState(theme, lang)
            : _buildTimeline(context, theme, lang, memories),
      ),
    );
  }

  Widget _buildEmptyState(PigioThemeData theme, String lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PigioWidget(mood: PigMood.searching, size: 100),
            const SizedBox(height: 24),
            Text(
              lang == 'fr'
                  ? "Pas encore de souvenirs !"
                  : "No memories yet!",
              style: fw(size: 18, w: FontWeight.w800, color: theme.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              lang == 'fr'
                  ? "Les moments partagés avec Pigio apparaîtront ici 💛"
                  : "Moments shared with Pigio will appear here 💛",
              style: fw(size: 14, color: theme.mid),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, PigioThemeData theme, String lang, List<MascotMemory> memories) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: memories.length,
      itemBuilder: (context, index) {
        final memory = memories[index];
        final title = lang == 'fr' ? memory.titleFr : memory.titleEn;
        final relativeTime = _formatRelativeTime(memory.timestamp, lang);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline dot + line
              Semantics(
                label: '${memory.emoji} $title, $relativeTime',
                child: Column(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(memory.emoji, style: const TextStyle(fontSize: 18)),
                  ),
                  if (index < memories.length - 1)
                    Container(
                      width: 2, height: 40,
                      color: theme.divider,
                    ),
                ],
              ),
              ),
              const SizedBox(width: 14),
              // Memory card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.divider, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: fw(size: 14, w: FontWeight.w700, color: theme.ink)),
                      const SizedBox(height: 4),
                      Text(relativeTime, style: fw(size: 11, color: theme.mid)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatRelativeTime(DateTime timestamp, String lang) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return lang == 'fr' ? "À l'instant" : "Just now";
    if (diff.inMinutes < 60) {
      return lang == 'fr' ? "Il y a ${diff.inMinutes} min" : "${diff.inMinutes}m ago";
    }
    if (diff.inHours < 24) {
      return lang == 'fr' ? "Il y a ${diff.inHours}h" : "${diff.inHours}h ago";
    }
    if (diff.inDays < 7) {
      return lang == 'fr' ? "Il y a ${diff.inDays}j" : "${diff.inDays}d ago";
    }
    if (diff.inDays < 30) {
      final weeks = diff.inDays ~/ 7;
      return lang == 'fr' ? "Il y a $weeks sem." : "${weeks}w ago";
    }
    final months = diff.inDays ~/ 30;
    return lang == 'fr' ? "Il y a $months mois" : "${months}mo ago";
  }
}
