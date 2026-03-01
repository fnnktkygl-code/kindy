part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Own Profile Management ──────────────────────────────────────────────────

extension ProfileExtension on PigioAppState {
  void updateProfile({
    required String name,
    required String handle,
    required int memberSince,
    String? birthdate,
    String? address,
    String? mondialRelayPoint,
    bool hideBirthdate = false,
    bool hideAddress = false,
    bool hideMondialRelay = false,
    String? avatarIcon,
    Color? avatarColor,
  }) {
    _profile = UserProfile(
      name: name,
      handle: handle,
      memberSince: memberSince,
      birthdate: birthdate,
      address: address,
      mondialRelayPoint: mondialRelayPoint,
      hideBirthdate: hideBirthdate,
      hideAddress: hideAddress,
      hideMondialRelay: hideMondialRelay,
      avatarIcon: avatarIcon ?? _profile.avatarIcon,
      avatarColor: avatarColor ?? _profile.avatarColor,
      fcmToken: _profile.fcmToken,
    );
    notifyListeners();
    _saveData();
    Future.microtask(_pushOwnContactProfile);
    Future.microtask(() => _sendNotificationToContacts(
          'profile_updated',
          '${_profile.name} a mis à jour son profil.',
        ));
  }

  /// Called by main.dart when Firebase gives us a (new) FCM registration token.
  void updateFcmToken(String? token) {
    if (token == null || token == _profile.fcmToken) return;
    _profile = UserProfile(
      name: _profile.name,
      handle: _profile.handle,
      memberSince: _profile.memberSince,
      birthdate: _profile.birthdate,
      address: _profile.address,
      mondialRelayPoint: _profile.mondialRelayPoint,
      hideBirthdate: _profile.hideBirthdate,
      hideAddress: _profile.hideAddress,
      hideMondialRelay: _profile.hideMondialRelay,
      avatarIcon: _profile.avatarIcon,
      avatarColor: _profile.avatarColor,
      fcmToken: token,
    );
    _saveData();
    Future.microtask(_pushOwnContactProfile);
  }

  /// Build an [ExchangeProfile] from the current user's profile.
  ExchangeProfile _buildExchangeProfile() {
    final ownSizes = _sizes
        .where((s) => s.contactId == null)
        .map((s) => s.toMap()..remove('contactId'))
        .toList();
    final ownWishes = _wishes
        .where((w) => w.contactId == null)
        .map((w) => w.toMap())
        .toList();
    return ExchangeProfile(
      name: _profile.name,
      handle: _profile.handle,
      memberSince: _profile.memberSince,
      avatarIcon: _profile.avatarIcon,
      avatarColor: _profile.avatarColor?.toARGB32(),
      birthdate: _profile.hideBirthdate ? null : _profile.birthdate,
      address: _profile.hideAddress ? null : _profile.address,
      mondialRelayPoint:
          _profile.hideMondialRelay ? null : _profile.mondialRelayPoint,
      hideBirthdate: _profile.hideBirthdate,
      hideAddress: _profile.hideAddress,
      hideMondialRelay: _profile.hideMondialRelay,
      fcmToken: _profile.fcmToken,
      sizes: ownSizes.isEmpty ? null : ownSizes,
      wishes: ownWishes.isEmpty ? null : ownWishes,
    );
  }
}
