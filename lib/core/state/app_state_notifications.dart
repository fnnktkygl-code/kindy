part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── In-App Notifications & Activity Log ─────────────────────────────────────

extension NotificationsExtension on PigioAppState {
  bool _isForegroundLifecycle(AppLifecycleState s) => s == AppLifecycleState.resumed;

  void setAppLifecycleState(AppLifecycleState state) {
    final isForeground = _isForegroundLifecycle(state);
    if (_appIsForeground == isForeground) return;
    _appIsForeground = isForeground;
    if (_appIsForeground) {
      // Immediate sync on app resume — complements Realtime + fallback timer.
      Future.microtask(() {
        _syncPendingInvitesFromServer();
        _pullContactProfiles();
        _pushOwnContactProfile();
        _pullNotifications();
        fetchWeather();
      });
      if (_pendingWizzShakeOnForeground) {
        _pendingWizzShakeOnForeground = false;
        _globalWizzNonce++;
        notifyListeners();
      }
    }
  }

  Future<void> _sendNotificationToContact(
    String contactId,
    String type,
    String message,
  ) async {
    if (_apiBaseUrl.isEmpty) return;
    final contact = _contacts.where((c) => c.id == contactId).firstOrNull;
    if (contact == null ||
        contact.status != ContactStatus.joined ||
        contact.profilePushKey == null) {
      return;
    }
    if (!_notificationsCoordinator.shouldSendToContact(
      contactId: contactId,
      type: type,
      cooldowns: _notificationCooldowns,
    )) {
      return;
    }

    final notif = PigioNotification(
      id: _newId(),
      senderId: _profile.handle.isNotEmpty ? _profile.handle : _profile.name,
      senderName: _profile.name,
      type: type,
      message: message,
      createdAt: DateTime.now(),
    );

    final key = contact.profilePushKey!;
    try {
      await _notificationsCoordinator.appendNotificationToInbox(
        pushKey: key,
        notification: notif,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Pigio] Single notification push failed for $contactId: $e');
    }

    final fcmToken = contact.fcmToken;
    if (fcmToken != null && fcmToken.isNotEmpty) {
      final userJwt = Supabase.instance.client.auth.currentSession?.accessToken;
      _notificationsCoordinator.sendPushToFcmToken(
        fcmToken: fcmToken,
        title: _profile.name,
        body: message,
        type: type,
        userJwt: userJwt,
        sender: ({
          required String baseUrl,
          required String fcmToken,
          required String title,
          required String body,
          required String type,
          required String? userJwt,
        }) => FcmService.sendPush(
          baseUrl: baseUrl,
          fcmToken: fcmToken,
          title: title,
          body: body,
          type: type,
          userJwt: userJwt,
        ),
      );
    }
  }

  /// Send a notification to all joined contacts.
  Future<void> _sendNotificationToContacts(
      String type, String message) async {
    if (_apiBaseUrl.isEmpty) return;
    if (!NotificationsCoordinator.eligibleNotificationTypes.contains(type)) {
      return;
    }

    final notif = PigioNotification(
      id: _newId(),
      senderId:
      _profile.handle.isNotEmpty ? _profile.handle : _profile.name,
      senderName: _profile.name,
      type: type,
      message: message,
      createdAt: DateTime.now(),
    );
    final joinedContacts = _contacts
        .where((c) =>
    c.profilePushKey != null && c.status == ContactStatus.joined)
        .toList();

    for (final contact in joinedContacts) {
      if (!_notificationsCoordinator.shouldSendToContact(
        contactId: contact.id,
        type: type,
        cooldowns: _notificationCooldowns,
      )) {
        continue;
      }
      final key = contact.profilePushKey!;
      try {
        await _notificationsCoordinator.appendNotificationToInbox(
          pushKey: key,
          notification: notif,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[Pigio] Notification push to $key failed: $e');
      }
    }
    // Real FCM push notification to contacts that have an FCM token
    final userJwt = Supabase.instance.client.auth.currentSession?.accessToken;
    for (final contact in joinedContacts) {
      final fcmToken = contact.fcmToken;
      if (fcmToken != null && fcmToken.isNotEmpty) {
        _notificationsCoordinator.sendPushToFcmToken(
          fcmToken: fcmToken,
          title: _profile.name,
          body: message,
          type: type,
          userJwt: userJwt,
          sender: ({
            required String baseUrl,
            required String fcmToken,
            required String title,
            required String body,
            required String type,
            required String? userJwt,
          }) => FcmService.sendPush(
            baseUrl: baseUrl,
            fcmToken: fcmToken,
            title: title,
            body: body,
            type: type,
            userJwt: userJwt,
          ),
        );
      }
    }
  }

  /// Pull notifications addressed to us from all our pull keys.
  Future<void> _pullNotifications() async {
    if (_apiBaseUrl.isEmpty) return;
    final pullKeys = _contacts
        .where((c) =>
    c.profilePullKey != null && c.status == ContactStatus.joined)
        .map((c) => c.profilePullKey!)
        .toSet();
    if (pullKeys.isEmpty) return;

    final existingIds = _notifications.map((n) => n.id).toSet();
    bool changed = false;
    bool hasIncomingWizz = false;
    for (final key in pullKeys) {
      try {
        final pulled = await _notificationsCoordinator.pullNotifications(key);
        for (final notif in pulled) {
          if (!existingIds.contains(notif.id) && notif.type == 'wizz') {
            hasIncomingWizz = true;
          }
        }
        final inserted = _notificationsCoordinator.mergePulledNotifications(
          target: _notifications,
          pulled: pulled,
          existingIds: existingIds,
        );
        if (inserted > 0) {
          _unseenNotificationsCount += inserted;
          changed = true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Pigio] Notification pull from $key failed: $e');
      }
    }
    if (changed) {
      if (hasIncomingWizz) {
        triggerIncomingWizzHaptic();
      }
      notifyListeners();
      _saveData();
    }
  }

  /// Public entry point used by FCM handlers to refresh notification bell state
  /// as soon as a push arrives or is opened.
  Future<void> refreshNotificationsFromCloud({
    int retries = 1,
    Duration retryDelay = const Duration(milliseconds: 550),
    bool triggerWizzHaptic = false,
  }) async {
    await _pullNotifications();
    for (int i = 0; i < retries; i++) {
      await Future.delayed(retryDelay);
      await _pullNotifications();
    }
    if (triggerWizzHaptic) {
      triggerIncomingWizzHaptic();
    }
  }

  /// Consumes newly received Wizz notifications once for haptic feedback.
  int consumeIncomingWizzCountForHaptics() {
    return _notificationsCoordinator.consumeIncomingWizzCountForHaptics(
      notifications: _notifications,
      consumedNotificationIds: _consumedWizzHapticNotificationIds,
    );
  }

  void triggerIncomingWizzHaptic() {
    final count = consumeIncomingWizzCountForHaptics();
    if (count > 0) {
      _playIncomingWizzSound();
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        try {
          HapticFeedback.heavyImpact();
        } catch (_) {
          // Ignore unsupported haptic platforms to keep desktop stable.
        }
      }
      if (_appIsForeground) {
        _globalWizzNonce++;
        notifyListeners();
      } else {
        _pendingWizzShakeOnForeground = true;
      }
    }
  }

  /// Local test helper: simulates a received Wizz for this account/UI only.
  void triggerIncomingWizzTest() {
    _playIncomingWizzSound();
    _globalWizzNonce++;
    notifyListeners();
  }

  void _playIncomingWizzSound() {
    Future.microtask(() async {
      try {
        if (Platform.isMacOS) {
          await _playIncomingWizzSoundMac();
          return;
        }

        _wizzSoundBytes ??= (await rootBundle.load('msn-wizz-sound.mp3')).buffer.asUint8List();
        await _wizzAudioPlayer.stop();
        await _wizzAudioPlayer.play(
          BytesSource(_wizzSoundBytes!),
          volume: 1.0,
        );
        if (_wizzEffectMode == WizzEffectMode.phase2) {
          await Future.delayed(const Duration(milliseconds: 280));
          await _wizzAudioPlayer.stop();
          await _wizzAudioPlayer.play(
            BytesSource(_wizzSoundBytes!),
            volume: 1.0,
          );
        }
      } catch (_) {
        try {
          await SystemSound.play(SystemSoundType.alert);
        } catch (_) {
          // Keep Wizz functional even if sound APIs are unavailable.
        }
      }
    });
  }

  Future<void> _playIncomingWizzSoundMac() async {
    final path = await _ensureWizzSoundTempFile();
    if (path == null) return;

    final burstCount = _wizzEffectMode == WizzEffectMode.phase2 ? 2 : 1;
    for (int i = 0; i < burstCount; i++) {
      try {
        await Process.start('afplay', [path]);
      } catch (_) {
        break;
      }
      if (i < burstCount - 1) {
        await Future.delayed(const Duration(milliseconds: 260));
      }
    }
  }

  Future<String?> _ensureWizzSoundTempFile() async {
    try {
      final existingPath = _wizzSoundTempPath;
      if (existingPath != null && await File(existingPath).exists()) {
        return existingPath;
      }

      _wizzSoundBytes ??=
          (await rootBundle.load('msn-wizz-sound.mp3')).buffer.asUint8List();
      final out = File('${Directory.systemTemp.path}/pigio_wizz_sound.mp3');
      await out.writeAsBytes(_wizzSoundBytes!, flush: true);
      _wizzSoundTempPath = out.path;
      return out.path;
    } catch (_) {
      return null;
    }
  }

  void markNotificationRead(String notifId) {
    final idx = _notifications.indexWhere((n) => n.id == notifId);
    if (idx >= 0 && !_notifications[idx].read) {
      _notifications[idx] = _notifications[idx].copyWith(read: true);
      _unseenNotificationsCount =
      _unseenNotificationsCount > 0 ? _unseenNotificationsCount - 1 : 0;
      notifyListeners();
      _saveData();
    }
  }

  void markAllNotificationsRead() {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].read) {
        _notifications[i] = _notifications[i].copyWith(read: true);
        changed = true;
      }
    }
    if (changed) {
      _unseenNotificationsCount = 0;
      notifyListeners();
      _saveData();
    }
  }

  void logActivity(String title, String emoji, {String? contactId}) {
    _activityLogs.insert(
        0,
        ActivityLog(
          id: _newId(),
          title: title,
          emoji: emoji,
          timestamp: DateTime.now(),
          contactId: contactId,
        ));
    _unseenLogsCount++;
    // Keep only last 12 months
    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    _activityLogs.removeWhere((a) => a.timestamp.isBefore(cutoff));
    notifyListeners();
    _saveData();
  }

  void clearUnseenLogs() {
    if (_unseenLogsCount > 0) {
      _unseenLogsCount = 0;
      notifyListeners();
      _saveData();
    }
  }

  void recordProfileView(String contactId) {
    _recentProfiles.remove(contactId);
    _recentProfiles.insert(0, contactId);
    if (_recentProfiles.length > 3) {
      _recentProfiles.removeLast();
    }
    notifyListeners();
    _saveData();
  }

  /// Returns contact IDs that should play a one-shot incoming Wizz shake now.
  /// Each wizz notification is consumed once to avoid repeated tremble loops.
  List<String> consumeIncomingWizzContactIds() {
    return _notificationsCoordinator.consumeIncomingWizzContactIds(
      notifications: _notifications,
      consumedNotificationIds: _consumedWizzNotificationIds,
      contacts: _contacts,
    );
  }
}