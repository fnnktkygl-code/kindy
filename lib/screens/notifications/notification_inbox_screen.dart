import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';
import 'package:kindy/services/notification_service.dart';
import 'package:kindy/core/i18n/i18n.dart';

// ─── Notification Inbox Screen ────────────────────────────────────────────────
class NotificationInboxScreen extends StatelessWidget {
  const NotificationInboxScreen({super.key});

  String _timeAgo(BuildContext context, DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return t(context, 'time_just_now');
    if (diff.inMinutes < 60) return t(context, 'time_minutes_ago').replaceAll('\$n', '${diff.inMinutes}');
    if (diff.inHours < 24) return t(context, 'time_hours_ago').replaceAll('\$n', '${diff.inHours}');
    if (diff.inDays == 1) return t(context, 'time_yesterday');
    if (diff.inDays < 7) return t(context, 'time_days_ago').replaceAll('\$n', '${diff.inDays}');
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  (String, String) _groupOf(BuildContext context, DateTime ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tsDay = DateTime(ts.year, ts.month, ts.day);
    final diff = today.difference(tsDay).inDays;

    if (diff == 0) return ('_today', t(context, 'group_today'));
    if (diff <= 6) return ('_week', t(context, 'group_this_week'));
    if (ts.year == now.year && ts.month == now.month) return ('_month', t(context, 'group_this_month'));
    return (
      '${ts.year}-${ts.month.toString().padLeft(2, '0')}',
      _monthLabel(ts),
    );
  }

  String _monthLabel(DateTime ts) {
    const months = [
      "Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
      "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"
    ];
    return '${months[ts.month - 1]} ${ts.year}';
  }

  int _groupSortKey(String key) {
    if (key == '_today') return 0;
    if (key == '_week') return 1;
    if (key == '_month') return 2;
    return 3 + (9999 - int.parse(key.replaceAll('-', '')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context);
    final notifications = state.notifications;

    // Mark all as read when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.markAllNotificationsRead();
    });

    // Group notifications
    final Map<String, (String, List<PigioNotification>)> grouped = {};
    for (final n in notifications) {
      final (key, label) = _groupOf(context, n.createdAt);
      if (!grouped.containsKey(key)) {
        grouped[key] = (label, []);
      }
      grouped[key]!.$2.add(n);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => _groupSortKey(a).compareTo(_groupSortKey(b)));

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: PigioAppBar(title: "Notifications", showNotification: false),
      body: SafeArea(
        child: notifications.isEmpty
            ? _buildEmptyState(theme)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                itemCount: sortedKeys.length,
                itemBuilder: (ctx, groupIdx) {
                  final key = sortedKeys[groupIdx];
                  final (label, items) = grouped[key]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (groupIdx > 0) const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 4),
                        child: Text(
                          label,
                          style: fw(
                            size: 13,
                            w: FontWeight.w800,
                            color: theme.mid,
                          ),
                        ),
                      ),
                      ...items.map((n) => _buildNotificationTile(context, n, theme)),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildNotificationTile(BuildContext context, PigioNotification notif, PigioThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: notif.read ? theme.card : theme.card.withAlpha(240),
        borderRadius: BorderRadius.circular(16),
        border: notif.read
            ? null
            : Border.all(color: theme.accent1.withAlpha(60), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notif.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.senderName,
                  style: fw(
                    size: 14,
                    w: FontWeight.w800,
                    color: theme.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notif.message,
                  style: fw(
                    size: 13,
                    w: FontWeight.w600,
                    color: theme.mid,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timeAgo(context, notif.createdAt),
            style: fw(size: 11, w: FontWeight.w600, color: theme.light),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(PigioThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔔', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Aucune notification',
            style: fw(size: 16, w: FontWeight.w800, color: theme.mid),
          ),
          const SizedBox(height: 8),
          Text(
            'Les mises à jour de tes contacts\napparaîtront ici.',
            textAlign: TextAlign.center,
            style: fw(size: 13, w: FontWeight.w600, color: theme.light),
          ),
        ],
      ),
    );
  }
}
