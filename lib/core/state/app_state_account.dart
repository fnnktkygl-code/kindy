part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Account Management ───────────────────────────────────────────────────────

extension AccountExtension on PigioAppState {
  /// Clear all local data without touching the backend.
  void clearData() {
    _wishes.clear();
    _contacts.clear();
    _groups.clear();
    _events.clear();
    _sizes.clear();
    _giftPots.clear();
    _activityLogs.clear();
    _recentProfiles.clear();
    _notifications.clear();
    _unseenNotificationsCount = 0;
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
      } catch (_) {
        // Best effort — continue even if some fail
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
      } catch (_) {}
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

    notifyListeners();
    return true;
  }
}
