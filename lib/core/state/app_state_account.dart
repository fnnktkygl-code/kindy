part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Account Management ───────────────────────────────────────────────────────

extension AccountExtension on PigioAppState {
  Future<void> reconcileAuthenticatedUser(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final previousUserId = prefs.getString(PigioAppState._lastAuthUserIdKey);

    if (userId == null || userId.isEmpty) {
      await prefs.remove(PigioAppState._lastAuthUserIdKey);
      return;
    }

    if (previousUserId != null && previousUserId.isNotEmpty && previousUserId != userId) {
      await _wipeLocalUserDataForSessionSwitch();
    }

    await prefs.setString(PigioAppState._lastAuthUserIdKey, userId);

    // Restore per-user onboarding flag so returning users skip onboarding.
    final perUserKey = '${PigioAppState._onboardingCompletedKey}_$userId';
    final wasCompleted = prefs.getBool(perUserKey) ?? false;
    if (wasCompleted && !_onboardingCompleted) {
      _onboardingCompleted = true;
    }

    // Restore per-user profile (name, avatar, etc.)
    final perUserProfileKey = '${PigioAppState._profileKey}_$userId';
    final savedProfile = prefs.getString(perUserProfileKey);
    if (savedProfile != null && savedProfile.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedProfile) as Map<String, dynamic>;
        _profile = UserProfile.fromMap(decoded);
      } catch (e) {
        log.warn('Account', 'Failed to decode saved user profile for $userId', e);
      }
    }

    notifyListeners();
  }

  Future<void> signOutAndCleanupLocalState() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      log.warn('Account', 'Remote sign-out failed, continuing cleanup', e);
    }

    // Clear biometric credentials so the next user can't re-auth as this user.
    try {
      await const FlutterSecureStorage().deleteAll();
    } catch (e) {
      log.warn('Account', 'Failed to clear secure storage on sign-out', e);
    }

    await _wipeLocalUserDataForSessionSwitch();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PigioAppState._lastAuthUserIdKey);
  }

  Future<void> _wipeLocalUserDataForSessionSwitch() async {
    _wishes.clear();
    _contacts.clear();
    _groups.clear();
    _events.clear();
    _sizes.clear();
    _giftPots.clear();
    _polls.clear();
    _activityLogs.clear();
    _recentProfiles.clear();
    _pendingInvites.clear();
    _notifications.clear();

    _unseenLogsCount = 0;
    _unseenNotificationsCount = 0;
    _inviteFocusContactId = null;
    _personalityProfile.clear();
    _wizzHistory.clear();
    _consumedWizzNotificationIds.clear();
    _consumedWizzHapticNotificationIds.clear();
    _globalWizzNonce = 0;

    _activeOutfit.clear();
    _unlockedClothing.clear();
    _syncEnabled = false;
    _syncKey = '';
    _onboardingCompleted = false;
    _profile = const UserProfile(name: 'You', handle: '@you', memberSince: 2024);

    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      PigioAppState._wishesKey,
      PigioAppState._contactsKey,
      PigioAppState._groupsKey,
      PigioAppState._eventsKey,
      PigioAppState._sizesKey,
      PigioAppState._profileKey,
      PigioAppState._unseenLogsKey,
      PigioAppState._activityLogsKey,
      PigioAppState._recentProfilesKey,
      PigioAppState._pendingInvitesKey,
      PigioAppState._legacyPendingInvitesKey,
      PigioAppState._syncKeyKey,
      PigioAppState._onboardingCompletedKey,
      PigioAppState._personalityProfileKey,
      PigioAppState._wizzKey,
      PigioAppState._notificationsKey,
      PigioAppState._giftPotsKey,
      PigioAppState._pollsKey,
    ]) {
      await prefs.remove(key);
    }

    for (final key in [
      PigioAppState._contactsKey,
      PigioAppState._profileKey,
      PigioAppState._activityLogsKey,
      PigioAppState._pendingInvitesKey,
      PigioAppState._notificationsKey,
      PigioAppState._syncKeyKey,
      PigioAppState._wishesKey,
      PigioAppState._groupsKey,
      PigioAppState._eventsKey,
      PigioAppState._sizesKey,
      PigioAppState._giftPotsKey,
      PigioAppState._pollsKey,
      PigioAppState._personalityProfileKey,
    ]) {
      try {
        await PigioAppState._secureStorage.delete(key: key);
      } catch (e) {
        log.warn('Account', 'Failed to delete secure key $key during session wipe', e);
      }
    }

    notifyListeners();
    await _saveDataNow();
  }

  /// Clear all local data without touching the backend.
  void clearData() {
    _wishes.clear();
    _contacts.clear();
    _groups.clear();
    _events.clear();
    _sizes.clear();
    _giftPots.clear();
    _polls.clear();
    _activityLogs.clear();
    _recentProfiles.clear();
    _pendingInvites.clear();
    _notifications.clear();
    _unseenNotificationsCount = 0;
    _unseenLogsCount = 0;
    notifyListeners();
    _saveData();
  }

  /// Completely delete the account: wipe all local data, remove all backend
  /// sync data (profile push/pull keys, sync key), clear SharedPreferences,
  /// and reset to a fresh state. Returns true if successful.
  Future<bool> deleteAccount() async {
    // 1. Collect all push keys to wipe
    final pushKeys = _contacts
        .where((c) => c.profilePushKey != null)
        .map((c) => c.profilePushKey!)
        .toSet();
    for (final inv in _pendingInvites) {
      if (inv.tokenId.isNotEmpty) {
        pushKeys.add('cprof_inv_${inv.tokenId}');
      }
    }

    // Also delete notification inboxes
    final allKeys = <String>{...pushKeys};
    for (final key in pushKeys) {
      allKeys.add('notif_$key');
    }
    // Delete pull keys too (our profile stored under those keys on the other side)
    for (final c in _contacts) {
      if (c.profilePullKey != null) allKeys.add(c.profilePullKey!);
      if (c.profilePullKey != null) allKeys.add('notif_${c.profilePullKey}');
    }

    // Push empty data to each key to effectively wipe it
    for (final key in allKeys) {
      try {
        await _invitationService.pushSyncData(
          syncKey: key,
          contacts: [],
          circles: [],
          pendingInvites: [],
          profile: {},
          wishes: [],
          events: [],
          sizes: [],
        );
      } catch (e) {
        log.warn('Account', 'Failed to wipe sync key $key during deletion', e);
      }
    }

    // 2. Wipe cloud sync data
    if (_syncKey.isNotEmpty) {
      try {
        await _invitationService.pushSyncData(
          syncKey: _syncKey,
          contacts: [],
          circles: [],
          pendingInvites: [],
          profile: {},
          wishes: [],
          events: [],
          sizes: [],
        );
      } catch (e) {
        log.warn('Account', 'Failed to wipe cloud sync data during deletion', e);
      }
    }

    // 3. Cancel sync timer
    _syncTimer?.cancel();
    _syncTimer = null;

    // 4. Clear all local state
    _wishes.clear();
    _contacts.clear();
    _groups.clear();
    _events.clear();
    _sizes.clear();
    _activityLogs.clear();
    _recentProfiles.clear();
    _pendingInvites.clear();
    _notifications.clear();
    _unseenLogsCount = 0;
    _unseenNotificationsCount = 0;
    _personalityProfile.clear();
    _wizzHistory.clear();
    _activeOutfit.clear();
    _unlockedClothing.clear();
    _syncKey = '';
    _syncEnabled = false;
    _onboardingCompleted = false;
    _profile = const UserProfile(name: 'You', handle: '@you', memberSince: 2024);

    // 5. Wipe SharedPreferences entirely
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 6. Wipe FlutterSecureStorage — this is where all app data actually lives.
    //    Without this the data reappears on next launch.
    try {
      await PigioAppState._secureStorage.deleteAll();
    } catch (e) {
      log.warn('Account', 'Bulk secure storage delete failed, falling back to individual keys', e);
      for (final key in [
        PigioAppState._contactsKey,
        PigioAppState._profileKey,
        PigioAppState._activityLogsKey,
        PigioAppState._pendingInvitesKey,
        PigioAppState._notificationsKey,
        PigioAppState._syncKeyKey,
      ]) {
        try { await PigioAppState._secureStorage.delete(key: key); } catch (e2) { log.warn('Account', 'Failed to delete key $key', e2); }
      }
    }

    notifyListeners();
    return true;
  }
}
