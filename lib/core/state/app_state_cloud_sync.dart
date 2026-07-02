part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── E2E Encrypted Cloud Sync ────────────────────────────────────────────────
//
// Zero-knowledge backup system. The server stores only an opaque AES-256-GCM
// encrypted blob + a non-secret salt. The key is derived from a 12-word
// recovery phrase (PBKDF2-HMAC-SHA256, 210k iterations) that the user sees
// exactly once during activation.
//
// Legacy "plain JSON" sync is preserved for rétro-compatibilité but will no
// longer be used for new activations.
// ─────────────────────────────────────────────────────────────────────────────

extension CloudSyncExtension on PigioAppState {

  // ── Enable E2E Backup ─────────────────────────────────────────────────────

  /// Activates E2E encrypted cloud backup.
  /// Returns the 12-word recovery phrase (displayed once to the user).
  Future<String> enableE2EBackup() async {
    // 1. Generate recovery phrase
    final phrase = BackupService.generateRecoveryPhrase();

    // 2. Generate salt and derive key
    final salt = BackupService.generateSalt();
    final key = await BackupService.deriveKey(phrase, salt);

    // 3. Compute lookup key (deterministic, derived from phrase)
    final lookupKey = await BackupService.computeLookupKey(phrase);

    // 4. Store locally
    _backupSalt = base64Encode(salt);
    _backupLookupKey = lookupKey;
    _derivedKey = key;
    _syncEnabled = true;

    // 5. Push initial backup
    notifyListeners();
    await _saveDataNow();
    await _pushE2EBackup();

    return phrase;
  }

  /// Restores data from an E2E encrypted backup using the recovery phrase.
  /// Returns true if successful, false if the phrase is wrong or no backup found.
  Future<bool> restoreFromPhrase(String phrase) async {
    try {
      // 1. Compute lookup key from phrase
      final lookupKey = await BackupService.computeLookupKey(phrase);

      // 2. Pull encrypted blob + salt from server
      final pullData = await _invitationService.pullSyncData(lookupKey);
      if (pullData == null || pullData['found'] != true) {
        if (kDebugMode) debugPrint('[CloudSync] No backup found for this phrase');
        return false;
      }

      // 3. Extract salt and encrypted blob
      final saltB64 = pullData['backup_salt'] as String?;
      final blobB64 = pullData['encrypted_blob'] as String?;

      if (saltB64 == null || blobB64 == null || saltB64.isEmpty || blobB64.isEmpty) {
        // Maybe this is a legacy (unencrypted) backup — try legacy restore
        if (kDebugMode) debugPrint('[CloudSync] No E2E blob found, checking legacy format');
        return false;
      }

      final salt = base64Decode(saltB64);
      final blob = base64Decode(blobB64);

      // 4. Derive key from phrase + salt
      final key = await BackupService.deriveKey(phrase, salt);

      // 5. Decrypt
      final data = await BackupService.decrypt(blob, key);
      if (data == null) {
        if (kDebugMode) debugPrint('[CloudSync] Decryption failed — wrong phrase?');
        return false;
      }

      // 6. Restore into state
      final success = BackupService.deserializeIntoState(data, this);
      if (!success) return false;

      // 7. Save locally and update sync state
      _backupSalt = saltB64;
      _backupLookupKey = lookupKey;
      _derivedKey = key;
      _syncEnabled = true;

      notifyListeners();
      await _saveDataNow();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CloudSync] Restore failed: $e');
      return false;
    }
  }

  // ── Push / Pull ───────────────────────────────────────────────────────────

  /// Pushes an E2E encrypted snapshot to the cloud.
  Future<void> _pushE2EBackup() async {
    if (!_syncEnabled || _backupLookupKey.isEmpty || _derivedKey == null) return;
    if (_backupSalt.isEmpty) return;

    try {
      // Serialize → encrypt
      final payload = BackupService.serializeAppState(this);
      final blob = await BackupService.encrypt(payload, _derivedKey!);
      final blobB64 = base64Encode(blob);

      // Push to server via the existing data-sync edge function
      // We send encrypted_blob + backup_salt as special fields
      await _invitationService.pushSyncData(
        syncKey: _backupLookupKey,
        contacts: [], // empty — all data is in the blob
        circles: [],
        pendingInvites: [],
        profile: {
          '__e2e': true,
          'encrypted_blob': blobB64,
          'backup_salt': _backupSalt,
        },
        wishes: [],
        events: [],
        sizes: [],
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[CloudSync] E2E push failed: $e');
    }
  }

  // ── Legacy Sync (backwards compat) ────────────────────────────────────────

  /// Enable cloud sync with the given key (or generate one).
  /// LEGACY — new users should use enableE2EBackup() instead.
  Future<void> enableSync([String? key]) async {
    _syncKey = (key != null && key.trim().length >= 16) ? key.trim() : _newId();
    _syncEnabled = true;
    notifyListeners();
    await _saveDataNow();
    await _pushToCloud();
  }

  /// Link this device to an existing sync key (e.g. from another device).
  /// LEGACY — new users should use restoreFromPhrase() instead.
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
    _derivedKey = null;
    notifyListeners();
    _saveData();
  }

  /// Force a full sync (pull then push).
  Future<void> syncNow() async {
    if (!_syncEnabled) return;

    // E2E path
    if (_backupLookupKey.isNotEmpty && _derivedKey != null) {
      await _pushE2EBackup();
      return;
    }

    // Legacy path
    if (_syncKey.isEmpty) return;
    await _pullFromCloud();
    await _pushToCloud();
    notifyListeners();
    _saveData();
  }

  /// Delete the cloud backup entirely (RGPD Art. 17 — right to erasure).
  Future<bool> deleteCloudBackup() async {
    try {
      if (_backupLookupKey.isNotEmpty) {
        // Push empty data to wipe the blob
        await _invitationService.pushSyncData(
          syncKey: _backupLookupKey,
          contacts: [],
          circles: [],
          pendingInvites: [],
          profile: {},
          wishes: [],
          events: [],
          sizes: [],
        );
      }

      _syncEnabled = false;
      _backupSalt = '';
      _backupLookupKey = '';
      _derivedKey = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(PigioAppState._backupSaltKey);
      await prefs.remove(PigioAppState._backupLookupKeyKey);

      notifyListeners();
      await _saveDataNow();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[CloudSync] Delete backup failed: $e');
      return false;
    }
  }

  // ── Legacy Push/Pull (plain JSON, no encryption) ──────────────────────────

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
        notificationPrefs: _notificationPrefs,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Kindy] Cloud push failed: $e');
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

      // Notification preferences — cloud wins on pull
      final cloudNotifPrefs = data['notificationPrefs'];
      if (cloudNotifPrefs is Map<String, dynamic> && cloudNotifPrefs.isNotEmpty) {
        _notificationPrefs = cloudNotifPrefs;
      }

      _invalidateWishCache();
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Kindy] Cloud pull failed: $e');
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
