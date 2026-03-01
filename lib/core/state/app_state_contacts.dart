part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Contact & Group Management ──────────────────────────────────────────────

extension ContactsExtension on PigioAppState {
  // ── Contact Queries ────────────────────────────────────────────────────────

  ContactStatus statusForContact(String contactId) {
    final c = _contacts.where((c) => c.id == contactId).firstOrNull;
    return c?.status ?? ContactStatus.local;
  }

  InviteBlockReason? getInviteBlockReason(String contactId) {
    final contact = _contacts.where((c) => c.id == contactId).firstOrNull;
    if (contact == null) return null;
    if (contact.isManaged) return InviteBlockReason.managedProfile;
    if (contact.status == ContactStatus.joined) return InviteBlockReason.alreadyJoined;
    final hasActive = _pendingInvites.any((i) =>
        i.contactId == contactId &&
        i.state == PendingInviteState.pending &&
        !i.isExpired);
    if (hasActive) return InviteBlockReason.pendingActive;
    return null;
  }

  PendingInvite? getActivePendingInviteFor(String contactId) {
    return _pendingInvites
        .where((i) =>
            i.contactId == contactId &&
            i.state == PendingInviteState.pending &&
            !i.isExpired)
        .firstOrNull;
  }

  PendingInvite? getLatestInviteFor(String contactId) {
    final all = _pendingInvites
        .where((i) => i.contactId == contactId)
        .toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return all.isEmpty ? null : all.first;
  }

  // ── Contact CRUD ────────────────────────────────────────────────────────────

  void addContact({
    required String name,
    required String role,
    TrustLevel trustLevel = TrustLevel.friend,
    String? birthdate,
    String? address,
    String? mondialRelayPoint,
    bool hideBirthdate = false,
    bool hideAddress = false,
    bool hideMondialRelay = false,
    String? avatarIcon,
    Color? avatarColor,
  }) {
    _contacts.add(ContactProfile(
      id: _newId(),
      name: name,
      role: role,
      avatarName: name,
      color: avatarColor ??
          AppColors.avPalette[_contacts.length % AppColors.avPalette.length],
      trustLevel: trustLevel,
      birthdate: birthdate,
      address: address,
      mondialRelayPoint: mondialRelayPoint,
      hideBirthdate: hideBirthdate,
      hideAddress: hideAddress,
      hideMondialRelay: hideMondialRelay,
      avatarIcon: avatarIcon,
      avatarColor: avatarColor,
      managedProfile: true,
      status: ContactStatus.local,
    ));
    notifyListeners();
    _saveData();
    logActivity('Contact ajouté : $name', '👤', contactId: _contacts.last.id);
  }

  void updateContact({
    required String id,
    required String name,
    required String role,
    String? birthdate,
    String? address,
    String? mondialRelayPoint,
    bool? hideBirthdate,
    bool? hideAddress,
    bool? hideMondialRelay,
    String? avatarIcon,
    Color? avatarColor,
    TrustLevel? trustLevel,
  }) {
    final idx = _contacts.indexWhere((c) => c.id == id);
    if (idx < 0) return;

    final old = _contacts[idx];
    final changes = <String>[];
    if (name != old.name) changes.add('Nom');
    if (role != old.role) changes.add('Rôle');
    if (birthdate != old.birthdate) changes.add('Anniversaire');
    if (address != old.address) changes.add('Adresse');
    if (mondialRelayPoint != old.mondialRelayPoint) changes.add('Mondial Relay');
    if (trustLevel != null && trustLevel != old.trustLevel) changes.add('Cercle/Confiance');
    if (avatarIcon != null && avatarIcon != old.avatarIcon) {
      changes.add('Avatar');
    }
    if (avatarColor != null && avatarColor != old.color) {
      changes.add('Couleur');
    }
    if (hideMondialRelay != null && hideMondialRelay != old.hideMondialRelay) {
      changes.add('Visibilité Relais');
    }
    if (hideAddress != null && hideAddress != old.hideAddress) {
      changes.add('Visibilité Adresse');
    }
    if (hideBirthdate != null && hideBirthdate != old.hideBirthdate) {
      changes.add('Visibilité Anniversaire');
    }

    _contacts[idx] = ContactProfile(
      id: id,
      name: name,
      role: role,
      avatarName: name,
      color: avatarColor ?? old.color,
      trustLevel: trustLevel ?? old.trustLevel,
      birthdate: birthdate,
      address: address,
      mondialRelayPoint: mondialRelayPoint,
      hideBirthdate: hideBirthdate ?? old.hideBirthdate,
      hideAddress: hideAddress ?? old.hideAddress,
      hideMondialRelay: hideMondialRelay ?? old.hideMondialRelay,
      avatarIcon: avatarIcon ?? old.avatarIcon,
      avatarColor: avatarColor ?? old.avatarColor,
      managedProfile: old.managedProfile,
      status: old.status,
      profilePushKey: old.profilePushKey,
      profilePullKey: old.profilePullKey,
    );
    _syncFamilleGroupMembership(id, trustLevel ?? old.trustLevel);
    notifyListeners();
    _saveData();
    final desc = changes.isNotEmpty ? changes.join(', ') : 'Général';
    logActivity('Profil modifié : $name ($desc)', '✏️', contactId: id);
  }

  void deleteContact(String id) {
    final contact = _contacts.where((c) => c.id == id).firstOrNull;
    _contacts.removeWhere((c) => c.id == id);
    for (int i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      if (g.contactIds.contains(id)) {
        _groups[i] = CircleGroup(
          id: g.id,
          name: g.name,
          emoji: g.emoji,
          contactIds: g.contactIds.where((cId) => cId != id).toList(),
          isSystem: g.isSystem,
          trustLevel: g.trustLevel,
          pendingInviteIds:
              g.pendingInviteIds.where((pId) => pId != id).toList(),
        );
      }
    }
    _wishes.removeWhere((w) => w.contactId == id);
    _events.removeWhere((e) => e.contactId == id);
    notifyListeners();
    _saveData();
    if (contact != null) {
      logActivity('Contact supprimé : ${contact.name}', '🗑️');
    }
  }

  /// Resets a contact back to [ContactStatus.local] so they can be re-invited.
  void resetContactForReinvite(String contactId) {
    final idx = _contacts.indexWhere((c) => c.id == contactId);
    if (idx < 0) return;
    for (int i = 0; i < _pendingInvites.length; i++) {
      final inv = _pendingInvites[i];
      if (inv.contactId == contactId &&
          (inv.state == PendingInviteState.pending ||
              inv.state == PendingInviteState.accepted)) {
        _pendingInvites[i] = inv.copyWith(state: PendingInviteState.revoked);
      }
    }
    _contacts[idx] = _contacts[idx].copyWith(
      status: ContactStatus.local,
      managedProfile: false,
      profilePushKey: null,
      profilePullKey: null,
    );
    notifyListeners();
    _saveData();
    logActivity('Contact réinitialisé pour ré-invitation', '🔄',
        contactId: contactId);
  }

  // ── Internal helpers ───────────────────────────────────────────────────────

  void _setContactStatus(String contactId, ContactStatus status) {
    final idx = _contacts.indexWhere((c) => c.id == contactId);
    if (idx < 0) return;
    _contacts[idx] = _contacts[idx].copyWith(status: status);
  }

  // ── Group CRUD ──────────────────────────────────────────────────────────────

  void addGroup(
    String name,
    String emoji,
    List<String> contactIds, {
    TrustLevel trustLevel = TrustLevel.friend,
    bool isSystem = false,
  }) {
    _groups.add(CircleGroup(
      id: isSystem ? 'famille_default' : _newId(),
      name: name,
      emoji: emoji,
      contactIds: contactIds,
      isSystem: isSystem,
      trustLevel: trustLevel,
      pendingInviteIds: const [],
    ));
    notifyListeners();
    _saveData();
    logActivity('Cercle créé : $name', emoji);
  }

  void deleteGroup(String id) {
    final group = _groups.where((g) => g.id == id).firstOrNull;
    if (group != null && group.id == 'famille_default') return;
    _groups.removeWhere((g) => g.id == id);
    notifyListeners();
    _saveData();
  }

  void updateGroup(String id,
      {String? name, String? emoji, TrustLevel? trustLevel}) {
    final idx = _groups.indexWhere((g) => g.id == id);
    if (idx < 0) return;
    final g = _groups[idx];
    final newName = (g.isSystem && name != null) ? g.name : (name ?? g.name);
    _groups[idx] = CircleGroup(
      id: g.id,
      name: newName,
      emoji: emoji ?? g.emoji,
      contactIds: g.contactIds,
      isSystem: g.isSystem,
      trustLevel: trustLevel ?? g.trustLevel,
      pendingInviteIds: g.pendingInviteIds,
    );
    notifyListeners();
    _saveData();
  }

  /// Returns `false` when validation fails (e.g. non-family in Famille group).
  bool addContactToGroup(String groupId, String contactId) {
    final groupIdx = _groups.indexWhere((g) => g.id == groupId);
    if (groupIdx < 0) return false;
    final group = _groups[groupIdx];
    final contact = _contacts.where((c) => c.id == contactId).firstOrNull;
    if (contact == null) return false;

    if (group.isSystem && group.trustLevel == TrustLevel.family) {
      if (!contact.isFamily) return false;
    }
    if (contact.trustLevel == TrustLevel.public_ &&
        group.trustLevel == TrustLevel.family) {
      return false;
    }

    if (!group.contactIds.contains(contactId)) {
      _groups[groupIdx] = CircleGroup(
        id: group.id,
        name: group.name,
        emoji: group.emoji,
        contactIds: [...group.contactIds, contactId],
        isSystem: group.isSystem,
        trustLevel: group.trustLevel,
        pendingInviteIds:
            group.pendingInviteIds.where((id) => id != contactId).toList(),
      );
      notifyListeners();
      _saveData();
    }
    return true;
  }

  void removeContactFromGroup(String groupId, String contactId) {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    final g = _groups[idx];
    _groups[idx] = CircleGroup(
      id: g.id,
      name: g.name,
      emoji: g.emoji,
      contactIds: g.contactIds.where((cId) => cId != contactId).toList(),
      isSystem: g.isSystem,
      trustLevel: g.trustLevel,
      pendingInviteIds:
          g.pendingInviteIds.where((pId) => pId != contactId).toList(),
    );
    notifyListeners();
    _saveData();
  }

  List<ContactProfile> pendingMembersForGroup(String groupId) {
    final group = _groups.where((g) => g.id == groupId).firstOrNull;
    if (group == null) return const [];
    return _contacts.where((c) => group.pendingInviteIds.contains(c.id)).toList();
  }

  void approvePendingMember(String groupId, String contactId) {
    _setContactStatus(contactId, ContactStatus.joined);
    _resolveGroupPendingInvite(groupId, contactId, join: true);
    notifyListeners();
    _saveData();
  }

  void rejectPendingMember(String groupId, String contactId) {
    _setContactStatus(contactId, ContactStatus.local);
    _resolveGroupPendingInvite(groupId, contactId, join: false);
    notifyListeners();
    _saveData();
  }

  // ── Internal group helpers ─────────────────────────────────────────────────

  void _addGroupPendingInvite(String groupId, String contactId) {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    final group = _groups[idx];
    final pending = List<String>.from(group.pendingInviteIds);
    if (!pending.contains(contactId)) pending.add(contactId);
    _groups[idx] = CircleGroup(
      id: group.id,
      name: group.name,
      emoji: group.emoji,
      contactIds: group.contactIds,
      isSystem: group.isSystem,
      trustLevel: group.trustLevel,
      pendingInviteIds: pending,
    );
  }

  void _resolveGroupPendingInvite(String groupId, String contactId,
      {bool join = true}) {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    final group = _groups[idx];
    final pending =
        group.pendingInviteIds.where((id) => id != contactId).toList();
    final members = join && !group.contactIds.contains(contactId)
        ? [...group.contactIds, contactId]
        : group.contactIds;
    _groups[idx] = CircleGroup(
      id: group.id,
      name: group.name,
      emoji: group.emoji,
      contactIds: members,
      isSystem: group.isSystem,
      trustLevel: group.trustLevel,
      pendingInviteIds: pending,
    );
  }

  /// Keeps the system Famille group in sync with a contact's trust level.
  void _syncFamilleGroupMembership(String contactId, TrustLevel trustLevel) {
    final isFamily = trustLevel == TrustLevel.family;
    int gIdx =
        _groups.indexWhere((g) => g.isSystem && g.trustLevel == TrustLevel.family);
    if (gIdx < 0) {
      if (!isFamily) return;
      _groups.insert(
          0,
          CircleGroup(
            id: 'famille_default',
            name: 'Famille',
            emoji: '🏠',
            contactIds: [contactId],
            isSystem: true,
            trustLevel: TrustLevel.family,
            pendingInviteIds: const [],
          ));
      return;
    }
    final group = _groups[gIdx];
    final members = List<String>.from(group.contactIds);
    if (isFamily && !members.contains(contactId)) {
      members.add(contactId);
    } else if (!isFamily && members.contains(contactId)) {
      members.remove(contactId);
    } else {
      return;
    }
    _groups[gIdx] = CircleGroup(
      id: group.id,
      name: group.name,
      emoji: group.emoji,
      contactIds: members,
      isSystem: group.isSystem,
      trustLevel: group.trustLevel,
      pendingInviteIds: group.pendingInviteIds,
    );
  }
}
