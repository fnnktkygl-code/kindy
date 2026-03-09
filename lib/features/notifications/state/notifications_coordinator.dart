import 'package:flutter/foundation.dart';

import '../../../services/notification_service.dart';
import 'package:pigio_app/core/models/app_models.dart';

class NotificationsCoordinator {
  NotificationsCoordinator({
    required this.apiBaseUrl,
    required this.notificationService,
  });

  final String apiBaseUrl;
  final NotificationService notificationService;

  static const Set<String> eligibleNotificationTypes = {
    'wizz',
    'invite_accepted',
    'wish_added',
    'wish_updated',
    'wish_reserved',
    'profile_updated',
    'sizes_updated',
  };

  Duration cooldownForType(String type) {
    switch (type) {
      case 'wizz':
      case 'invite_accepted':
        return Duration.zero;
      case 'wish_added':
      case 'wish_updated':
      case 'wish_reserved':
        return const Duration(hours: 3);
      case 'profile_updated':
      case 'sizes_updated':
        return const Duration(hours: 12);
      default:
        return const Duration(hours: 6);
    }
  }

  bool shouldSendToContact({
    required String contactId,
    required String type,
    required Map<String, DateTime> cooldowns,
  }) {
    if (!eligibleNotificationTypes.contains(type)) return false;

    final cooldown = cooldownForType(type);
    if (cooldown == Duration.zero) return true;

    final now = DateTime.now();
    final key = '$contactId|$type';
    final last = cooldowns[key];
    if (last != null && now.difference(last) < cooldown) {
      return false;
    }
    cooldowns[key] = now;
    return true;
  }

  Future<void> appendNotificationToInbox({
    required String pushKey,
    required PigioNotification notification,
    int maxCloudItems = 50,
  }) async {
    final existing = await notificationService.pullNotifications(pushKey);
    final all = [...existing, notification];
    final trimmed = all.length > maxCloudItems
        ? all.sublist(all.length - maxCloudItems)
        : all;
    await notificationService.pushNotification(
      pushKey: pushKey,
      notifications: trimmed,
    );
  }

  Future<List<PigioNotification>> pullNotifications(String pullKey) {
    return notificationService.pullNotifications(pullKey);
  }

  int mergePulledNotifications({
    required List<PigioNotification> target,
    required Iterable<PigioNotification> pulled,
    required Set<String> existingIds,
    int maxLocalItems = 100,
  }) {
    var inserted = 0;
    for (final notif in pulled) {
      if (existingIds.contains(notif.id)) continue;
      target.insert(0, notif);
      existingIds.add(notif.id);
      inserted++;
    }

    if (target.length > maxLocalItems) {
      target.removeRange(maxLocalItems, target.length);
    }

    return inserted;
  }

  int consumeIncomingWizzCountForHaptics({
    required List<PigioNotification> notifications,
    required Set<String> consumedNotificationIds,
  }) {
    var count = 0;
    for (final notif in notifications) {
      if (notif.type != 'wizz') continue;
      if (consumedNotificationIds.contains(notif.id)) continue;
      consumedNotificationIds.add(notif.id);
      count++;
    }
    return count;
  }

  List<String> consumeIncomingWizzContactIds({
    required List<PigioNotification> notifications,
    required Set<String> consumedNotificationIds,
    required List<ContactProfile> contacts,
  }) {
    final contactIds = <String>{};
    for (final notif in notifications) {
      if (notif.type != 'wizz') continue;
      if (consumedNotificationIds.contains(notif.id)) continue;
      final contactId = matchContactIdForNotification(notif, contacts);
      if (contactId != null) {
        contactIds.add(contactId);
      }
      consumedNotificationIds.add(notif.id);
    }
    return contactIds.toList();
  }

  String? matchContactIdForNotification(
    PigioNotification notification,
    List<ContactProfile> contacts,
  ) {
    final senderName = notification.senderName.trim().toLowerCase();
    final senderId = notification.senderId.trim().toLowerCase();
    final normalizedSenderId =
        senderId.startsWith('@') ? senderId.substring(1) : senderId;

    final byName = contacts
        .where((c) =>
            c.status == ContactStatus.joined &&
            c.name.trim().toLowerCase() == senderName)
        .firstOrNull;
    if (byName != null) return byName.id;

    final bySenderId = contacts
        .where((c) {
          final name = c.name.trim().toLowerCase();
          return c.status == ContactStatus.joined &&
              (name == senderId || name == normalizedSenderId);
        })
        .firstOrNull;
    if (bySenderId != null) return bySenderId.id;

    return null;
  }

  Future<void> sendPushToFcmToken({
    required String fcmToken,
    required String title,
    required String body,
    required String type,
    required String? userJwt,
    required Future<void> Function({
      required String baseUrl,
      required String fcmToken,
      required String title,
      required String body,
      required String type,
      required String? userJwt,
    }) sender,
  }) {
    if (apiBaseUrl.isEmpty || fcmToken.isEmpty) return Future.value();

    return sender(
      baseUrl: apiBaseUrl,
      fcmToken: fcmToken,
      title: title,
      body: body,
      type: type,
      userJwt: userJwt,
    ).catchError((error) {
      if (kDebugMode) debugPrint('[Pigio] FCM push failed: $error');
    });
  }
}
