import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../services/fcm_service.dart';
import 'package:pigio_app/core/state/app_state.dart';

class FcmCoordinator {
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

    if (!isMounted()) return;

    await state.ready;

    final token = await messaging.getToken();
    state.updateFcmToken(token);

    messaging.onTokenRefresh.listen(state.updateFcmToken);

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
    }

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await handleIncomingMessage(initialMessage, fromNotificationTap: true);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await handleIncomingMessage(message, fromNotificationTap: false);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await handleIncomingMessage(message, fromNotificationTap: true);
    });
  }

  Future<void> sendPush({
    required String baseUrl,
    required String fcmToken,
    required String title,
    required String body,
    required String type,
  }) {
    return FcmService.sendPush(
      baseUrl: baseUrl,
      fcmToken: fcmToken,
      title: title,
      body: body,
      type: type,
    );
  }
}
