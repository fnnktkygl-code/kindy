import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../services/analytics_service.dart';
import '../../services/fcm_service.dart';
import 'package:kindy/core/state/app_state.dart';

class FcmCoordinator {
  final List<StreamSubscription> _subscriptions = [];
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init({
    required PigioAppState state,
    required bool Function() isMounted,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Initialize Local Notifications for foreground display
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotificationsPlugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) {
          // Handle tap from foreground notification
          AnalyticsService.pushOpened(response.payload!);
        }
      },
    );

    if (!isMounted()) return;

    await state.ready;

    final token = await messaging.getToken();
    state.updateFcmToken(token);

    _subscriptions.add(
      messaging.onTokenRefresh.listen(state.updateFcmToken),
    );

    Future<void> handleIncomingMessage(
      RemoteMessage message, {
      required bool fromNotificationTap,
    }) async {
      // Only trigger Wizz haptic when the push notification is explicitly
      // typed as 'wizz' — prevents spoofed non-wizz messages from vibrating.
      final isWizz = message.data['type'] == 'wizz';
      await state.refreshNotificationsFromCloud(
        retries: fromNotificationTap ? 2 : 1,
        triggerWizzHaptic: isWizz,
      );
      // Piggy-back a contact data pull so the UI is fresh.
      state.refreshContactDataAll();
    }

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await handleIncomingMessage(initialMessage, fromNotificationTap: true);
    }

    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        await handleIncomingMessage(message, fromNotificationTap: false);
        
        // Show foreground notification
        final notification = message.notification;
        if (notification != null && notification.title != null && notification.body != null) {
          const androidDetails = AndroidNotificationDetails(
            'kindy_high_importance', // id
            'High Importance Notifications', // name
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.high,
          );
          const iosDetails = DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );
          await _localNotificationsPlugin.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
            payload: message.data['type'] as String?,
          );
        }
      }),
    );

    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        final type = message.data['type'] as String? ?? 'unknown';
        AnalyticsService.pushOpened(type);
        await handleIncomingMessage(message, fromNotificationTap: true);
      }),
    );
  }

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> sendPush({
    required String baseUrl,
    required String fcmToken,
    required String title,
    required String body,
    required String type,
    required String? userJwt,
  }) {
    return FcmService.sendPush(
      baseUrl: baseUrl,
      fcmToken: fcmToken,
      title: title,
      body: body,
      type: type,
      userJwt: userJwt,
    );
  }
}
