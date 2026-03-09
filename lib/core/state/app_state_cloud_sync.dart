part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Multi-Device Cloud Sync ─────────────────────────────────────────────────

extension CloudSyncExtension on PigioAppState {
  /// Enable cloud sync with the given key (or generate one).
  Future<void> enableSync([String? key]) async {
    _syncKey = (key != null && key.trim().length >= 16) ? key.trim() : _newId();
    _syncEnabled = true;
    notifyListeners();
    await _saveDataNow();
    await _pushToCloud();
  }

  /// Link this device to an existing sync key (e.g. from another device).
  Future<bool> linkDevice(String key) async {
    if (key.trim().length < 16) return false;
    _syncKey = key.trim();
    _syncEnabled = true;
    final pulled = await _pullFromCloud();
    if (!pulled) {
      await _pushToCloud();
    }
    notifyListeners();
    await _saveDataNow();
    return true;
  }

  void disableSync() {
    _syncEnabled = false;
    notifyListeners();
    _saveData();
  }

  /// Force a full sync (pull then push).
  Future<void> syncNow() async {
    if (!_syncEnabled || _syncKey.isEmpty) return;
    await _pullFromCloud();
    await _pushToCloud();
    notifyListeners();
    _saveData();
  }

  Future<void> _pushToCloud() async {
    if (!_syncEnabled || _syncKey.isEmpty) return;
    try {
      await _invitationService.pushSyncData(
        syncKey: _syncKey,
        contacts: _contacts.map((c) => c.toMap()).toList(),
        circles: _groups.map((g) => g.toMap()).toList(),
        pendingInvites: _pendingInvites.map((i) => i.toMap()).toList(),
        profile: _profile.toMap(),
        wishes: _wishes.map((w) => w.toMap()).toList(),
        events: _events.map((e) => e.toMap()).toList(),
        sizes: _sizes.map((s) => s.toMap()).toList(),
        giftPots: _giftPots.map((p) => p.toMap()).toList(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Pigio] Cloud push failed: $e');
    }
  }

  Future<bool> _pullFromCloud() async {
    if (!_syncEnabled || _syncKey.isEmpty) return false;
    try {
      final data = await _invitationService.pullSyncData(_syncKey);
      if (data == null) return false;

      final cloudContacts = (data['contacts'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(ContactProfile.fromMap)
              .toList() ??
          [];
      final cloudGroups = (data['circles'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(CircleGroup.fromMap)
              .toList() ??
          [];
      final cloudInvites = (data['pendingInvites'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(PendingInvite.fromMap)
              .toList() ??
          [];
      final cloudWishes = (data['wishes'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(Wish.fromMap)
              .toList() ??
          [];
      final cloudEvents = (data['events'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(Event.fromMap)
              .toList() ??
          [];
      final cloudSizes = (data['sizes'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(SizeProfile.fromMap)
              .toList() ??
          [];
      final cloudGiftPots = (data['giftPots'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(GiftPot.fromMap)
              .toList() ??
          [];
      final rawProfile = data['profile'];
      final cloudProfile = rawProfile is Map<String, dynamic>
          ? UserProfile.fromMap(rawProfile)
          : null;

      _mergeById<ContactProfile>(_contacts, cloudContacts, (c) => c.id);
      _mergeById<CircleGroup>(_groups, cloudGroups, (g) => g.id);
      _mergeById<PendingInvite>(_pendingInvites, cloudInvites, (i) => i.id);
      _mergeById<Wish>(_wishes, cloudWishes, (w) => w.id);
      _mergeById<Event>(_events, cloudEvents, (e) => e.id);
      _mergeById<SizeProfile>(
          _sizes, cloudSizes, (s) => '${s.contactId}_${s.categoryKey}');
      _mergeById<GiftPot>(_giftPots, cloudGiftPots, (p) => p.id);

      if (cloudProfile != null) _profile = cloudProfile;

      _invalidateWishCache();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Pigio] Cloud pull failed: $e');
      return false;
    }
  }

  /// Merge cloud items into local list by ID — cloud wins on conflict.
  void _mergeById<T>(
      List<T> local, List<T> cloud, String Function(T) getId) {
    final cloudMap = {for (final item in cloud) getId(item): item};
    for (int i = 0; i < local.length; i++) {
      final id = getId(local[i]);
      if (cloudMap.containsKey(id)) {
        local[i] = cloudMap[id] as T;
        cloudMap.remove(id);
      }
    }
    for (final item in cloudMap.values) {
      local.add(item);
    }
  }
}
