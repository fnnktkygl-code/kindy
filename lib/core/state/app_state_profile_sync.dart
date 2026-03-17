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

  /// Public entry point for a full sync cycle — pull contacts + push own profile.
  /// Called on FCM push receive to keep UI fresh without waiting for the timer.
  void refreshContactDataAll() {
    Future.microtask(() {
      _pullContactProfiles();
      _pushOwnContactProfile();
    });
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

    // Collect reservations this user made on other contacts' wishes,
    // grouped by the wish owner's contact ID.
    final reservationsByContact = <String, List<Map<String, dynamic>>>{};
    for (final w in _wishes) {
      if (w.contactId != null && w.reservedById != null) {
        reservationsByContact.putIfAbsent(w.contactId!, () => []);
        reservationsByContact[w.contactId!]!
            .add({'wishId': w.id, 'reservedById': w.reservedById});
      }
    }

    final pushKeys = _contacts
        .where((c) =>
    c.profilePushKey != null && c.status == ContactStatus.joined)
        .map((c) => MapEntry(c.id, c.profilePushKey!));
    final inviteKeys = _pendingInvites
        .where((i) => i.state == PendingInviteState.accepted)
        .map((i) => MapEntry(i.contactId, 'cprof_inv_${i.tokenId}'));

    final allKeys = {...Map.fromEntries(pushKeys), ...Map.fromEntries(inviteKeys)};

    for (final entry in allKeys.entries) {
      try {
        // Include reservations this user made on this contact's wishes
        final reservationsForContact = reservationsByContact[entry.key];
        await _invitationService.pushProfileData(
          profileKey: entry.value,
          profile: profileMap,
          sizes: ownSizes,
          wishes: ownWishes,
          reservations: reservationsForContact,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[Pigio] Profile push to ${entry.value} failed: $e');
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
          _contacts[cIdx] = _mergeContactProfile(_contacts[cIdx], updatedProfile);
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

        // Apply incoming reservations — other contacts pushing reservations
        // they made on our own wishes (contactId == null).
        final rawReservations = data['reservations'];
        if (rawReservations is List && rawReservations.isNotEmpty) {
          for (final r in rawReservations) {
            if (r is! Map) continue;
            final wishId = r['wishId'] as String?;
            final reservedById = r['reservedById'] as String?;
            if (wishId == null) continue;
            final idx = _wishes.indexWhere((w) => w.id == wishId && w.contactId == null);
            if (idx >= 0) {
              final current = _wishes[idx];
              _wishes[idx] = Wish(
                id: current.id,
                title: current.title,
                emoji: current.emoji,
                url: current.url,
                imageUrl: current.imageUrl,
                addedAt: current.addedAt,
                contactId: current.contactId,
                reservedById: reservedById,
                priority: current.priority,
                priceRange: current.priceRange,
                notes: current.notes,
                giftPotId: current.giftPotId,
              );
              _invalidateWishCache();
              changed = true;
            }
          }
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
        _contacts[contactIdx] = _mergeContactProfile(_contacts[contactIdx], updatedProfile);
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

  /// Merge a remote profile map into an existing [ContactProfile], keeping
  /// local values for any fields the remote payload does not include.
  ContactProfile _mergeContactProfile(
      ContactProfile existing, Map<String, dynamic> p) {
    return existing.copyWith(
      name: (p['name'] as String?)?.isNotEmpty == true
          ? p['name'] as String
          : existing.name,
      avatarIcon: p.containsKey('avatarIcon')
          ? p['avatarIcon'] as String?
          : existing.avatarIcon,
      avatarColor: p.containsKey('avatarColor')
          ? (p['avatarColor'] != null ? Color(p['avatarColor'] as int) : null)
          : existing.avatarColor,
      birthdate: p.containsKey('birthdate')
          ? p['birthdate'] as String?
          : existing.birthdate,
      address: p.containsKey('address')
          ? p['address'] as String?
          : existing.address,
      mondialRelayPoint: p.containsKey('mondialRelayPoint')
          ? p['mondialRelayPoint'] as String?
          : existing.mondialRelayPoint,
      hideBirthdate: p.containsKey('hideBirthdate')
          ? p['hideBirthdate'] as bool?
          : existing.hideBirthdate,
      hideAddress: p.containsKey('hideAddress')
          ? p['hideAddress'] as bool?
          : existing.hideAddress,
      hideMondialRelay: p.containsKey('hideMondialRelay')
          ? p['hideMondialRelay'] as bool?
          : existing.hideMondialRelay,
      fcmToken: p.containsKey('fcmToken')
          ? p['fcmToken'] as String?
          : existing.fcmToken,
    );
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
      } catch (e) {
        log.warn('ProfileSync', 'Failed to apply exchanged size for contact $contactId', e);
      }
    }
    return changed;
  }
}