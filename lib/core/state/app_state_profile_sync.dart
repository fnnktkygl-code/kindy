part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member, unnecessary_type_check

// ─── Contact Profile Push / Pull Sync ───────────────────────────────────────

extension ProfileSyncExtension on PigioAppState {
  Map<String, dynamic> _buildProfileSyncPayload() {
    final profileMap = Map<String, dynamic>.from(_profile.toMap());
    profileMap['name'] = _profile.name;
    profileMap['handle'] = _profile.handle;
    profileMap['memberSince'] = _profile.memberSince;
    profileMap['birthdate'] = _profile.hideBirthdate ? null : _profile.birthdate;
    profileMap['address'] = _profile.hideAddress ? null : _profile.address;
    profileMap['mondialRelayPoint'] =
        _profile.hideMondialRelay ? null : _profile.mondialRelayPoint;
    profileMap['hideBirthdate'] = _profile.hideBirthdate;
    profileMap['hideAddress'] = _profile.hideAddress;
    profileMap['hideMondialRelay'] = _profile.hideMondialRelay;
    profileMap['avatarIcon'] = _profile.avatarIcon;
    profileMap['avatarColor'] = _profile.avatarColor?.toARGB32();
    profileMap['fcmToken'] = _profile.fcmToken;
    return profileMap;
  }

  /// Push own profile + sizes to every push key registered on joined contacts.
  /// Call this whenever the user updates their own profile or sizes.
  Future<void> _pushOwnContactProfile() async {
    if (_apiBaseUrl.isEmpty) return;
    final ownSizes = _sizes
        .where((s) => s.contactId == null)
        .map((s) => s.toMap()..remove('contactId'))
        .toList();
    final ownWishes = _wishes
      .where((w) => w.contactId == null)
      .map((w) => w.toMap())
      .toList();

    final profileMap = _buildProfileSyncPayload();

    final pushKeys = _contacts
        .where((c) =>
    c.profilePushKey != null && c.status == ContactStatus.joined)
        .map((c) => c.profilePushKey!)
        .toSet();
    for (final inv in _pendingInvites) {
      if (inv.state == PendingInviteState.accepted) {
        pushKeys.add('cprof_inv_${inv.tokenId}');
      }
    }
    for (final key in pushKeys) {
      try {
        await _invitationService.pushProfileData(
          profileKey: key,
          profile: profileMap,
          sizes: ownSizes,
          wishes: ownWishes,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[Pigio] Profile push to $key failed: $e');
      }
    }
  }

  /// Pull the latest profile + sizes for every joined contact that has a pull key.
  Future<void> _pullContactProfiles() async {
    if (_apiBaseUrl.isEmpty) return;
    final joinedWithKey = _contacts
        .where((c) =>
    c.profilePullKey != null && c.status == ContactStatus.joined)
        .toList();
    if (joinedWithKey.isEmpty) return;

    bool changed = false;
    for (final contact in joinedWithKey) {
      try {
        final data =
        await _invitationService.pullProfileData(contact.profilePullKey!);
        if (data == null) continue;

        final rawProf = data['profile'];
        final updatedProfile = rawProf is Map ? Map<String, dynamic>.from(rawProf) : null;
        final rawSizes =
        data['sizes'] is List ? data['sizes'] as List : null;
        final rawWishes =
            data['wishes'] is List ? data['wishes'] as List : null;
        if (updatedProfile == null && rawSizes == null && rawWishes == null) {
          continue;
        }

        final cIdx = _contacts.indexWhere((c) => c.id == contact.id);
        if (cIdx >= 0 && updatedProfile != null) {
          final existing = _contacts[cIdx];
          _contacts[cIdx] = existing.copyWith(
            name: (updatedProfile['name'] as String?)?.isNotEmpty == true
                ? updatedProfile['name'] as String
                : existing.name,
            avatarIcon: updatedProfile.containsKey('avatarIcon')
                ? updatedProfile['avatarIcon'] as String?
                : existing.avatarIcon,
            avatarColor: updatedProfile.containsKey('avatarColor')
                ? (updatedProfile['avatarColor'] != null
                ? Color(updatedProfile['avatarColor'] as int)
                : null)
                : existing.avatarColor,
            birthdate: updatedProfile.containsKey('birthdate')
                ? updatedProfile['birthdate'] as String?
                : existing.birthdate,
            address: updatedProfile.containsKey('address')
                ? updatedProfile['address'] as String?
                : existing.address,
            mondialRelayPoint: updatedProfile.containsKey('mondialRelayPoint')
                ? updatedProfile['mondialRelayPoint'] as String?
                : existing.mondialRelayPoint,
            hideBirthdate: updatedProfile.containsKey('hideBirthdate')
                ? updatedProfile['hideBirthdate'] as bool?
                : existing.hideBirthdate,
            hideAddress: updatedProfile.containsKey('hideAddress')
                ? updatedProfile['hideAddress'] as bool?
                : existing.hideAddress,
            hideMondialRelay: updatedProfile.containsKey('hideMondialRelay')
                ? updatedProfile['hideMondialRelay'] as bool?
                : existing.hideMondialRelay,
            fcmToken: updatedProfile.containsKey('fcmToken')
                ? updatedProfile['fcmToken'] as String?
                : existing.fcmToken,
          );
          changed = true;
        }

        if (rawSizes != null) {
          changed =
              _applyExchangedSizesToContact(contact.id, rawSizes) || changed;
        }

        if (rawWishes != null) {
          for (final wMap in rawWishes) {
            final mapped = Map<String, dynamic>.from(wMap as Map);
            mapped['contactId'] = contact.id;
            final wish = Wish.fromMap(mapped);
            _wishes.removeWhere((w) => w.id == wish.id);
            _wishes.add(wish);
          }
          _invalidateWishCache();
          changed = true;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[Pigio] Profile pull for ${contact.id} failed: $e');
      }
    }

    if (changed) {
      notifyListeners();
      _saveData();
    }
  }

  /// Refresh a contact's full profile (called when opening their profile screen).
  Future<void> refreshContactData(String contactId) async {
    final contactIdx = _contacts.indexWhere((c) => c.id == contactId);
    if (contactIdx == -1) return;
    final contact = _contacts[contactIdx];
    if (contact.status != ContactStatus.joined) return;

    // Push our own fresh profile so the other side can pull it.
    Future.microtask(_pushOwnContactProfile);

    try {
      final pullKey = contact.profilePullKey;
      if (pullKey == null) return;
      final data = await _invitationService.pullProfileData(pullKey);
      if (data == null) return;

      bool changed = false;

      final rawProf = data['profile'];
      final updatedProfile = rawProf is Map ? Map<String, dynamic>.from(rawProf) : null;
      if (updatedProfile != null) {
        final existing = _contacts[contactIdx];
        _contacts[contactIdx] = existing.copyWith(
          name: (updatedProfile['name'] as String?)?.isNotEmpty == true
              ? updatedProfile['name'] as String
              : existing.name,
          avatarIcon: updatedProfile.containsKey('avatarIcon')
              ? updatedProfile['avatarIcon'] as String?
              : existing.avatarIcon,
          avatarColor: updatedProfile.containsKey('avatarColor')
              ? (updatedProfile['avatarColor'] != null
              ? Color(updatedProfile['avatarColor'] as int)
              : null)
              : existing.avatarColor,
          birthdate: updatedProfile.containsKey('birthdate')
              ? updatedProfile['birthdate'] as String?
              : existing.birthdate,
          address: updatedProfile.containsKey('address')
              ? updatedProfile['address'] as String?
              : existing.address,
          mondialRelayPoint: updatedProfile.containsKey('mondialRelayPoint')
              ? updatedProfile['mondialRelayPoint'] as String?
              : existing.mondialRelayPoint,
          hideBirthdate: updatedProfile.containsKey('hideBirthdate')
              ? updatedProfile['hideBirthdate'] as bool?
              : existing.hideBirthdate,
          hideAddress: updatedProfile.containsKey('hideAddress')
              ? updatedProfile['hideAddress'] as bool?
              : existing.hideAddress,
          hideMondialRelay: updatedProfile.containsKey('hideMondialRelay')
              ? updatedProfile['hideMondialRelay'] as bool?
              : existing.hideMondialRelay,
          fcmToken: updatedProfile.containsKey('fcmToken')
              ? updatedProfile['fcmToken'] as String?
              : existing.fcmToken,
        );
        changed = true;
      }

      final rawSizes = data['sizes'] is List ? data['sizes'] as List : null;
      if (rawSizes != null) {
        changed = _applyExchangedSizesToContact(contactId, rawSizes) || changed;
      }

      final rawWishes = data['wishes'] is List ? data['wishes'] as List : null;
      if (rawWishes != null) {
        for (var wMap in rawWishes) {
          final mapped = Map<String, dynamic>.from(wMap as Map);
          mapped['contactId'] = contactId;
          final wish = Wish.fromMap(mapped);
          _wishes.removeWhere((w) => w.id == wish.id);
          _wishes.add(wish);
        }
        _invalidateWishCache();
        changed = true;
      }

      if (changed) {
        notifyListeners();
        _saveData();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Pigio] refreshContactData error for $contactId: $e');
    }
  }

  /// Apply a list of size maps received via profile exchange to a contact.
  /// Returns true if any change was made.
  bool _applyExchangedSizesToContact(String contactId, List rawSizes) {
    bool changed = false;
    for (final raw in rawSizes) {
      if (raw is! Map) continue;
      try {
        final sizeMap = Map<String, dynamic>.from(raw);
        sizeMap['contactId'] = contactId;
        sizeMap.putIfAbsent('visibilityKey', () => 'general_access');
        sizeMap.putIfAbsent('updatedAt', () => DateTime.now().toIso8601String());
        final sp = SizeProfile.fromMap(sizeMap);
        final idx = _sizes.indexWhere(
                (s) => s.contactId == contactId && s.categoryKey == sp.categoryKey);
        if (idx >= 0) {
          final merged = Map<String, String>.from(_sizes[idx].values)
            ..addAll(sp.values);
          _sizes[idx] = SizeProfile(
            contactId: contactId,
            categoryKey: sp.categoryKey,
            values: merged,
            fitKey: sp.fitKey ?? _sizes[idx].fitKey,
            visibilityKey: sp.visibilityKey,
            updatedAt: sp.updatedAt,
          );
        } else {
          _sizes.add(sp);
        }
        changed = true;
      } catch (_) {}
    }
    return changed;
  }
}