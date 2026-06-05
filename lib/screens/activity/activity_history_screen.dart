import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';
import 'package:kindy/shared/widgets/pigio_painter.dart';

class ActivityHistoryScreen extends StatelessWidget {
  final int initialUnseenCount;
  const ActivityHistoryScreen({super.key, this.initialUnseenCount = 0});

  static const _monthNames = [
    "Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
    "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"
  ];

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Returns (sortableKey, displayLabel) for smart grouping
  (String, String) _groupOf(DateTime ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tsDay = DateTime(ts.year, ts.month, ts.day);
    final diff = today.difference(tsDay).inDays;

    if (diff == 0) return ('_today', "Aujourd'hui");
    if (diff <= 6) return ('_week', 'Cette semaine');
    if (ts.year == now.year && ts.month == now.month) return ('_month', 'Ce mois-ci');
    return (
      '${ts.year}-${ts.month.toString().padLeft(2, '0')}',
      '${_monthNames[ts.month - 1]} ${ts.year}',
    );
  }

  int _groupSortKey(String key) {
    if (key == '_today') return 0;
    if (key == '_week') return 1;
    if (key == '_month') return 2;
    // Older months: sort descending (most recent first)
    return 3 + (9999 - int.parse(key.replaceAll('-', '')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context);
    final logs = state.activityLogs;

    // Group logs with smart buckets; track per-item unseen status
    final Map<String, (String, List<(ActivityLog, bool)>)> grouped = {};
    for (int i = 0; i < logs.length; i++) {
      final a = logs[i];
      final isUnseen = i < initialUnseenCount;
      final (key, label) = _groupOf(a.timestamp);
      if (!grouped.containsKey(key)) {
        grouped[key] = (label, []);
      }
      grouped[key]!.$2.add((a, isUnseen));
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => _groupSortKey(a).compareTo(_groupSortKey(b)));

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: PigioAppBar(title: "Historique", showNotification: false),
      body: SafeArea(
        child: logs.isEmpty
            ? _buildEmptyState(theme)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                itemCount: sortedKeys.length,
                itemBuilder: (context, sectionIndex) {
                  final key = sortedKeys[sectionIndex];
                  final (label, items) = grouped[key]!;
                  return _buildSection(label, items, theme);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(PigioThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(
            size: const Size(72, 72),
            painter: PigioPainter(mood: PigMood.searching, scarfColor: theme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            "Aucune activité",
            style: fw(size: 17, w: FontWeight.w900, color: theme.ink),
          ),
          const SizedBox(height: 6),
          Text(
            "Vos actions récentes apparaîtront ici.",
            style: fw(size: 13, w: FontWeight.w600, color: theme.mid),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String label, List<(ActivityLog, bool)> items, PigioThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 10, left: 2),
          child: Text(
            label.toUpperCase(),
            style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2),
          ),
        ),
        ...items.map((entry) {
          final (a, isUnseen) = entry;
          return _buildCard(a, isUnseen, theme);
        }),
      ],
    );
  }

  Widget _buildCard(ActivityLog a, bool isUnseen, PigioThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isUnseen ? theme.primary.withValues(alpha: 0.05) : theme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnseen ? theme.primary.withValues(alpha: 0.35) : theme.divider.withValues(alpha: 0.6),
          width: isUnseen ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Emoji badge on the left
          Container(
            width: 54,
            height: 62,
            decoration: BoxDecoration(
              color: isUnseen ? theme.primary.withValues(alpha: 0.1) : theme.surface,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(17)),
            ),
            alignment: Alignment.center,
            child: Text(a.emoji, style: const TextStyle(fontSize: 22)),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: fw(size: 14, w: FontWeight.w700, color: isUnseen ? theme.primary : theme.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _timeAgo(a.timestamp),
                    style: fw(
                      size: 12,
                      w: FontWeight.w600,
                      color: isUnseen ? theme.primary.withValues(alpha: 0.7) : theme.light,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Unseen indicator dot
          if (isUnseen)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: theme.primary, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}
