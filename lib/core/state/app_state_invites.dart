part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Invite System ───────────────────────────────────────────────────────────

extension InvitesExtension on PigioAppState {
  // ── Public Invite Actions ──────────────────────────────────────────────────

  void clearInviteFocusContactId() {
    if (_inviteFocusContactId == null) return;
    _inviteFocusContactId = null;
    notifyListeners();
  }

  void expirePendingInvites() {
    final changed = InviteCommands.expirePendingInvites(_pendingInvites);
    if (changed) {
      notifyListeners();
      _saveData();
    }
  }

  /// Send an invite to a known contact.
  Future<String?> sendInvite(
      String contactId, {
        String? groupId,
        InviteChannel channel = InviteChannel.copyLink,
      }) async {
    final contact = _contacts.where((c) => c.id == contactId).firstOrNull;
    if (contact == null) throw Exception('Contact introuvable');
    if (contact.isManaged) {
      throw Exception(
          'Ce profil est administré localement et ne peut pas recevoir d\'invitation.');
    }
    if (contact.status == ContactStatus.joined) {
      throw Exception(
          'Ce contact est déjà connecté sur Pigio. Réinitialisez-le s\'il a changé de compte.');
    }

    final inviterId =
    _profile.handle.trim().isEmpty ? _profile.name : _profile.handle;
    final token = await _createTokenWithFallback(
      inviterId: inviterId,
      contactId: contactId,
      groupId: groupId,
      channel: channel,
    );

    InviteCommands.upsertPendingInvite(
      _pendingInvites,
      PendingInvite(
        id: token.invitationId,
        tokenId: token.tokenId,
        inviterId: inviterId,
        contactId: contactId,
        groupId: groupId,
        channel: channel,
        state: PendingInviteState.pending,
        sentAt: DateTime.now(),
        expiresAt: token.expiresAt,
      ),
      replaceWhere: (item) =>
          item.contactId == contactId &&
          item.groupId == groupId &&
          item.state == PendingInviteState.pending,
    );

    _setContactStatus(contactId, ContactStatus.invited);
    if (groupId != null) _addGroupPendingInvite(groupId, contactId);

    setMascotMoment(MascotMoment.inviteSent);
    logActivity('Invitation envoyée à ${contact.name}', '📩',
        contactId: contactId);
    _saveData();

    // Pre-push own profile so the accepter can pull it immediately.
    final preInviteKey = 'cprof_inv_${token.tokenId}';
    Future.microtask(() => _invitationService
        .pushProfileData(
      profileKey: preInviteKey,
      profile: _buildProfileSyncPayload(),
      sizes: _sizes
          .where((s) => s.contactId == null)
          .map((s) => s.toMap()..remove('contactId'))
          .toList(),
      wishes: _wishes
        .where((w) => w.contactId == null)
        .map((w) => w.toMap())
        .toList(),
    )
        .catchError((_) => false));

    return _toAppInviteLink(token.inviteLink);
  }

  /// Generate a generic invite link (no specific target contact).
  Future<String?> createContactListInviteLink({
    InviteChannel channel = InviteChannel.copyLink,
  }) async {
    if (!_contactsConsentGiven) {
      throw Exception(
          'Consentement requis avant de générer un lien d\'invitation.');
    }
    final inviterId =
    _profile.handle.trim().isEmpty ? _profile.name : _profile.handle;
    final token = await _createTokenWithFallback(
      inviterId: inviterId,
      channel: channel,
    );
    InviteCommands.upsertPendingInvite(
      _pendingInvites,
      PendingInvite(
        id: token.invitationId,
        tokenId: token.tokenId,
        inviterId: inviterId,
        contactId: '',
        channel: channel,
        state: PendingInviteState.pending,
        sentAt: DateTime.now(),
        expiresAt: token.expiresAt,
      ),
      replaceWhere: (item) =>
          item.contactId.isEmpty &&
          item.groupId == null &&
          item.state == PendingInviteState.pending,
    );
    Future.microtask(() => _invitationService
        .pushProfileData(
      profileKey: 'cprof_inv_${token.tokenId}',
      profile: _buildProfileSyncPayload(),
      sizes: _sizes
          .where((s) => s.contactId == null)
          .map((s) => s.toMap()..remove('contactId'))
          .toList(),
      wishes: _wishes
        .where((w) => w.contactId == null)
        .map((w) => w.toMap())
        .toList(),
    )
        .catchError((_) => false));
    logActivity('Lien d\'invitation généré pour la liste de contacts', '🔗');
    _saveData();
    return _toAppInviteLink(token.inviteLink);
  }

  /// Generate an invite link for a circle/group.
  Future<String?> createGroupInviteLink(
      String groupId, {
        InviteChannel channel = InviteChannel.copyLink,
      }) async {
    if (!_contactsConsentGiven) {
      throw Exception(
          'Consentement requis avant de générer un lien d\'invitation.');
    }
    final group = _groups.where((g) => g.id == groupId).firstOrNull;
    if (group == null) throw Exception('Cercle introuvable');

    final inviterId =
    _profile.handle.trim().isEmpty ? _profile.name : _profile.handle;
    final token = await _createTokenWithFallback(
      inviterId: inviterId,
      groupId: groupId,
      channel: channel,
    );
    InviteCommands.upsertPendingInvite(
      _pendingInvites,
      PendingInvite(
        id: token.invitationId,
        tokenId: token.tokenId,
        inviterId: inviterId,
        contactId: '',
        groupId: groupId,
        channel: channel,
        state: PendingInviteState.pending,
        sentAt: DateTime.now(),
        expiresAt: token.expiresAt,
      ),
      replaceWhere: (item) =>
          item.contactId.isEmpty &&
          item.groupId == groupId &&
          item.state == PendingInviteState.pending,
    );
    Future.microtask(() => _invitationService
        .pushProfileData(
      profileKey: 'cprof_inv_${token.tokenId}',
      profile: _buildProfileSyncPayload(),
      sizes: _sizes
          .where((s) => s.contactId == null)
          .map((s) => s.toMap()..remove('contactId'))
          .toList(),
      wishes: _wishes
        .where((w) => w.contactId == null)
        .map((w) => w.toMap())
        .toList(),
    )
        .catchError((_) => false));
    logActivity('Lien d\'invitation généré pour ${group.name}', '🔗');
    _saveData();
    return _toAppInviteLink(token.inviteLink);
  }

  /// Resolve an incoming link WITHOUT accepting (so UI can show confirm dialog).
  Future<InvitationLinkResolution> resolveIncomingInviteLink(Uri link) async {
    return await _resolveIncomingLinkWithFallback(link);
  }

  /// Accept a previously resolved invite after the user confirms.
  Future<bool> acceptResolvedInvite(InvitationLinkResolution result) async {
    if (!result.valid) return false;

    final inviteContactId = _acceptInviteAsDirectContact(result);
    final tokenId = result.tokenId;
    if (tokenId != null) {
      final inviteIdx =
      _pendingInvites.indexWhere((i) => i.tokenId == tokenId);
      if (inviteIdx >= 0) {
        _pendingInvites[inviteIdx] = _pendingInvites[inviteIdx].copyWith(
          state: PendingInviteState.accepted,
          acceptedAt: DateTime.now(),
        );
      }
      final contact =
          _contacts.where((c) => c.id == inviteContactId).firstOrNull;
      final pushKey = contact?.profilePushKey;
      final pullKey = contact?.profilePullKey;
      if (pushKey != null) {
        final ownSizes = _sizes
            .where((s) => s.contactId == null)
            .map((s) => s.toMap()..remove('contactId'))
            .toList();
        final ownWishes = _wishes
            .where((w) => w.contactId == null)
            .map((w) => w.toMap())
            .toList();
        Future.microtask(() async {
          await InviteSync.pushAndPullContactExchange(
            invitationService: _invitationService,
            pushKey: pushKey,
            pullKey: pullKey,
            profilePayload: _buildProfileSyncPayload(),
            sizesPayload: ownSizes,
            wishesPayload: ownWishes,
            onPulledSizes: (rawSizes) {
              _applyExchangedSizesToContact(inviteContactId, rawSizes);
            },
            onPulledProfile: (pd) {
              final idx2 = _contacts.indexWhere((c) => c.id == inviteContactId);
              if (idx2 >= 0) {
                final c2 = _contacts[idx2];
                _contacts[idx2] =
                    InviteMappers.mergeContactFromPulledProfile(c2, pd);
              }
            },
            onPulledCompleted: () {
              notifyListeners();
              _saveData();
            },
          );
        });
      }
    }

    final acceptedGroupId = result.groupId;
    if (acceptedGroupId != null && acceptedGroupId.isNotEmpty) {
      _addOrJoinGroupDirectly(acceptedGroupId, inviteContactId);
    }

    _inviteFocusContactId = inviteContactId;
    setTabIndex(3);
    setContactsSubIndex(0);
    setMascotMoment(MascotMoment.inviteAccepted);
    logActivity('Invitation acceptée', '✅', contactId: inviteContactId);

    notifyListeners();
    _saveData();
    return true;
  }

  /// Handle a deep-link invite URL received by the app.
  Future<bool> handleIncomingLink(Uri link) async {
    final result = await _resolveIncomingLinkWithFallback(link);
    if (!result.valid) return false;

    final inviteContactId = _acceptInviteAsDirectContact(result);
    final tokenId = result.tokenId;
    if (tokenId != null) {
      final inviteIdx =
      _pendingInvites.indexWhere((i) => i.tokenId == tokenId);
      if (inviteIdx >= 0) {
        _pendingInvites[inviteIdx] = _pendingInvites[inviteIdx].copyWith(
          state: PendingInviteState.accepted,
          acceptedAt: DateTime.now(),
        );
      }
      final contact =
          _contacts.where((c) => c.id == inviteContactId).firstOrNull;
      final pushKey = contact?.profilePushKey;
      final pullKey = contact?.profilePullKey;
      if (pushKey != null) {
        final ownSizes = _sizes
            .where((s) => s.contactId == null)
            .map((s) => s.toMap()..remove('contactId'))
            .toList();
        final ownWishes = _wishes
            .where((w) => w.contactId == null)
            .map((w) => w.toMap())
            .toList();
        Future.microtask(() async {
          await InviteSync.pushAndPullContactExchange(
            invitationService: _invitationService,
            pushKey: pushKey,
            pullKey: pullKey,
            profilePayload: _buildProfileSyncPayload(),
            sizesPayload: ownSizes,
            wishesPayload: ownWishes,
            onPulledSizes: (rawSizes) {
              _applyExchangedSizesToContact(inviteContactId, rawSizes);
            },
            onPulledProfile: (pd) {
              final idx2 = _contacts.indexWhere((c) => c.id == inviteContactId);
              if (idx2 >= 0) {
                final c2 = _contacts[idx2];
                _contacts[idx2] =
                    InviteMappers.mergeContactFromPulledProfile(c2, pd);
              }
            },
            onPulledCompleted: () {
              notifyListeners();
              _saveData();
            },
          );
        });
      }
    }

    final acceptedGroupId = result.groupId;
    if (acceptedGroupId != null && acceptedGroupId.isNotEmpty) {
      _addOrJoinGroupDirectly(acceptedGroupId, inviteContactId);
    }

    _inviteFocusContactId = inviteContactId;
    setTabIndex(3);
    setContactsSubIndex(0);
    setMascotMoment(MascotMoment.inviteAccepted);
    logActivity('Invitation acceptée automatiquement', '✅',
        contactId: inviteContactId);

    notifyListeners();
    _saveData();
    return true;
  }

  /// Check whether any pending invites were accepted (called on app resume).
  Future<void> checkPendingInvites() async {
    await _syncPendingInvitesFromServer();
  }

  // ── Server Polling ─────────────────────────────────────────────────────────

  Future<void> _syncPendingInvitesFromServer() async {
    final pendingEntries = _pendingInvites
        .asMap()
        .entries
        .where((e) => e.value.state == PendingInviteState.pending)
        .toList();

    if (pendingEntries.isEmpty) return;

    final results = await Future.wait(
      pendingEntries.map((e) => _invitationService
          .getTokenStatus(e.value.tokenId)
          .catchError((err) {
        if (kDebugMode) debugPrint('[Pigio] Sync invite ${e.value.tokenId} failed: $err');
        return null as dynamic;
      })),
    );

    bool changed = false;
    for (int i = 0; i < pendingEntries.length; i++) {
      final status = results[i];
      if (status == null || !status.found) continue;
      final originalIdx = pendingEntries[i].key;
      final invite = pendingEntries[i].value;

      if (status.status == 'accepted') {
        _pendingInvites[originalIdx] = invite.copyWith(
          state: PendingInviteState.accepted,
          acceptedAt: status.acceptedAt ?? DateTime.now(),
        );
        final ap = status.accepterProfile;
        final tokenId = invite.tokenId;
        final pushKey = 'cprof_inv_$tokenId';
        final pullKey = 'cprof_acc_$tokenId';

        final existingCid =
        invite.contactId.isNotEmpty ? invite.contactId : null;
        int cIdx = existingCid != null
            ? _contacts.indexWhere((c) => c.id == existingCid)
            : -1;

        if (cIdx >= 0) {
          _setContactStatus(existingCid!, ContactStatus.joined);
          final existing = _contacts[cIdx];
          _contacts[cIdx] = existing.copyWith(
            name: (ap?.name?.isNotEmpty == true) ? ap!.name : null,
            avatarName: (ap?.name?.isNotEmpty == true) ? ap!.name : null,
            avatarIcon: ap?.avatarIcon ?? existing.avatarIcon,
            avatarColor:
            ap?.avatarColor != null ? Color(ap!.avatarColor!) : null,
            color: ap?.avatarColor != null ? Color(ap!.avatarColor!) : null,
            birthdate: ap?.birthdate ?? existing.birthdate,
            profilePushKey: pushKey,
            profilePullKey: pullKey,
          );
          if (ap?.sizes != null) {
            _applyExchangedSizesToContact(existingCid, ap!.sizes!);
          }
        } else {
          final accepterName = ap?.name?.isNotEmpty == true
              ? ap!.name!
              : (ap?.handle?.isNotEmpty == true
              ? ap!.handle!
              : 'Nouveau contact');
          final normalizedId = accepterName
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
          final newCid = 'accepted_${tokenId}_$normalizedId';
          final fallbackColor = ap?.avatarColor != null
              ? Color(ap!.avatarColor!)
              : AppColors
              .avPalette[_contacts.length % AppColors.avPalette.length];
          _contacts.add(ContactProfile(
            id: newCid,
            name: accepterName,
            role: 'Contact Pigio',
            avatarName: accepterName,
            color: fallbackColor,
            trustLevel: TrustLevel.friend,
            avatarIcon: ap?.avatarIcon,
            avatarColor:
            ap?.avatarColor != null ? Color(ap!.avatarColor!) : null,
            birthdate: ap?.birthdate,
            managedProfile: false,
            status: ContactStatus.joined,
            profilePushKey: pushKey,
            profilePullKey: pullKey,
          ));
          cIdx = _contacts.length - 1;
          if (ap?.sizes != null) {
            _applyExchangedSizesToContact(newCid, ap!.sizes!);
          }
          _pendingInvites[originalIdx] =
              _pendingInvites[originalIdx].copyWith(contactId: newCid);
          logActivity('Nouveau contact ajouté : $accepterName', '🆕',
              contactId: newCid);
        }

        final resolvedCid = cIdx >= 0 ? _contacts[cIdx].id : null;
        if (resolvedCid != null) {
          final ownSizes = _sizes
              .where((s) => s.contactId == null)
              .map((s) => s.toMap()..remove('contactId'))
              .toList();
          final ownWishes = _wishes
              .where((w) => w.contactId == null)
              .map((w) => w.toMap())
              .toList();
          Future.microtask(() async {
            await InviteSync.pushAndPullContactExchange(
              invitationService: _invitationService,
              pushKey: pushKey,
              pullKey: pullKey,
              profilePayload: _buildProfileSyncPayload(),
              sizesPayload: ownSizes,
              wishesPayload: ownWishes,
              onPulledSizes: (rawSizes) {
                _applyExchangedSizesToContact(resolvedCid, rawSizes);
              },
              onPulledProfile: (pd) {
                final idx2 = _contacts.indexWhere((c) => c.id == resolvedCid);
                if (idx2 >= 0) {
                  final c2 = _contacts[idx2];
                  _contacts[idx2] =
                      InviteMappers.mergeContactFromPulledProfile(c2, pd);
                }
              },
              onPulledCompleted: () {
                notifyListeners();
                _saveData();
              },
            );
          });
        }

        if (invite.groupId != null &&
            invite.groupId!.isNotEmpty &&
            resolvedCid != null) {
          _resolveGroupPendingInvite(invite.groupId!, resolvedCid, join: true);
        }
        final acceptedContact = resolvedCid != null
            ? _contacts.where((c) => c.id == resolvedCid).firstOrNull
            : null;
        if (acceptedContact != null) {
          logActivity(
              'Invitation acceptée par ${acceptedContact.name}', '✅',
              contactId: acceptedContact.id);
        } else {
          logActivity('Invitation acceptée', '✅');
        }
        setMascotMoment(MascotMoment.inviteAccepted);
        changed = true;
      } else if (status.status == 'expired') {
        _pendingInvites[originalIdx] =
            invite.copyWith(state: PendingInviteState.expired);
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
      _saveData();
      Future.microtask(_pullContactProfiles);
    }
  }

  // ── Private Helpers ────────────────────────────────────────────────────────

  Future<InvitationTokenResponse> _createTokenWithFallback({
    required String inviterId,
    String? contactId,
    String? groupId,
    required InviteChannel channel,
    ExchangeProfile? profile,
  }) async {
    // Sanitize: the edge function accepts any non-empty string ≤ 128 chars.
    // Ensure we never send an empty value.
    final safeInviterId = inviterId.trim().isEmpty ? 'user' : inviterId.trim();
    return await _invitationService.createToken(
      inviterId: safeInviterId,
      contactId: contactId,
      groupId: groupId,
      channel: channel.name,
      profile: profile ?? _buildExchangeProfile(),
    );
  }

  String _toAppInviteLink(String rawLink) => rawLink;

  String _acceptInviteAsDirectContact(InvitationLinkResolution result) {
    final inviterRaw = (result.inviterId ?? '').trim();
    final prof = result.inviterProfile;
    final inviterDisplay = prof?.name?.isNotEmpty == true
        ? prof!.name!
        : (inviterRaw.isNotEmpty
        ? inviterRaw.replaceAll('@', '')
        : 'Nouveau contact');
    final contactId = InviteMappers.buildInviteContactId(
      inviterRaw: inviterRaw,
      tokenId: result.tokenId,
      fallbackId: _newId(),
    );

    final profileAvatarIcon = prof?.avatarIcon;
    final profileAvatarColor =
    prof?.avatarColor != null ? Color(prof!.avatarColor!) : null;
    final profileBirthdate = prof?.birthdate;
    final fallbackColor = profileAvatarColor ??
        AppColors.avPalette[_contacts.length % AppColors.avPalette.length];

    final tokenId = result.tokenId;
    final pushKey = tokenId != null ? 'cprof_acc_$tokenId' : null;
    final pullKey = tokenId != null ? 'cprof_inv_$tokenId' : null;

    final existingIdx = _contacts.indexWhere((c) => c.id == contactId);
    if (existingIdx >= 0) {
      final existing = _contacts[existingIdx];
      _contacts[existingIdx] = existing.copyWith(
        name: inviterDisplay,
        avatarName: inviterDisplay,
        avatarIcon: profileAvatarIcon ?? existing.avatarIcon,
        avatarColor: profileAvatarColor ?? existing.avatarColor,
        color: profileAvatarColor ?? existing.color,
        birthdate: profileBirthdate ?? existing.birthdate,
        managedProfile: false,
        status: ContactStatus.joined,
        profilePushKey: pushKey,
        profilePullKey: pullKey,
      );
    } else {
      _contacts.add(ContactProfile(
        id: contactId,
        name: inviterDisplay,
        role: 'Contact Pigio',
        avatarName: inviterDisplay,
        color: fallbackColor,
        trustLevel: TrustLevel.friend,
        avatarIcon: profileAvatarIcon,
        avatarColor: profileAvatarColor,
        birthdate: profileBirthdate,
        managedProfile: false,
        status: ContactStatus.joined,
        profilePushKey: pushKey,
        profilePullKey: pullKey,
      ));
    }

    if (prof?.sizes != null) {
      _applyExchangedSizesToContact(contactId, prof!.sizes!);
    }
    return contactId;
  }

  void _addOrJoinGroupDirectly(String groupId, String contactId) {
    final groupIdx = _groups.indexWhere((g) => g.id == groupId);
    if (groupIdx >= 0) {
      final group = _groups[groupIdx];
      final members = List<String>.from(group.contactIds);
      if (!members.contains(contactId)) members.add(contactId);
      _groups[groupIdx] = CircleGroup(
        id: group.id,
        name: group.name,
        emoji: group.emoji,
        contactIds: members,
        isSystem: group.isSystem,
        trustLevel: group.trustLevel,
        pendingInviteIds:
        group.pendingInviteIds.where((id) => id != contactId).toList(),
      );
      return;
    }
    _groups.add(CircleGroup(
      id: groupId,
      name: 'Nouveau cercle',
      emoji: '👥',
      contactIds: [contactId],
      trustLevel: TrustLevel.friend,
      pendingInviteIds: const [],
    ));
  }

  Future<InvitationLinkResolution> _resolveIncomingLinkWithFallback(
      Uri link) async {
    return InviteResolution.resolveIncomingLinkWithFallback(
      invitationService: _invitationService,
      link: link,
      accepterProfile: _buildExchangeProfile(),
    );
  }
}