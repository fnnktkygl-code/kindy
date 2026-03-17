import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'analytics_service.dart';

/// Generates shareable circle/group invite links for network-effect growth.
/// Recipients can join the circle directly via the invite link.
class CircleShareService {
  CircleShareService._();

  /// Share a group invite link. New users who tap the link install Pigio
  /// and get routed directly to the circle via deep linking.
  static Future<void> shareCircleLink({
    required BuildContext context,
    required PigioAppState state,
    required String groupId,
  }) async {
    final group = state.groups.where((g) => g.id == groupId).firstOrNull;
    if (group == null) return;

    final isFr = state.locale.languageCode == 'fr';
    final memberCount = group.contactIds.length;

    // The link resolves to pigio.app/join/<groupId> which triggers
    // the deeplink coordinator on install / open.
    final url = 'https://pigio.app/join/$groupId';
    final text = isFr
        ? 'Rejoins le cercle "${group.name}" ${group.emoji} sur Pigio ! '
            '($memberCount membre${memberCount > 1 ? 's' : ''})\n$url'
        : 'Join the "${group.name}" ${group.emoji} circle on Pigio! '
            '($memberCount member${memberCount > 1 ? 's' : ''})\n$url';

    await SharePlus.instance.share(ShareParams(text: text));
    AnalyticsService.log('circle_link_shared', {'group': groupId});
  }
}
