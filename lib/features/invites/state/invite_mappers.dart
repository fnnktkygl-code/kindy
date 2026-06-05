import 'package:flutter/material.dart';

import 'package:kindy/core/models/app_models.dart';

class InviteMappers {
  static ContactProfile mergeContactFromPulledProfile(
    ContactProfile existing,
    Map<String, dynamic> pulledProfile,
  ) {
    return existing.copyWith(
      name: (pulledProfile['name'] as String?)?.isNotEmpty == true
          ? pulledProfile['name'] as String
          : null,
      avatarIcon: pulledProfile['avatarIcon'] as String? ?? existing.avatarIcon,
      avatarColor: pulledProfile['avatarColor'] is int
          ? Color(pulledProfile['avatarColor'] as int)
          : null,
      birthdate: pulledProfile['birthdate'] as String? ?? existing.birthdate,
      address: pulledProfile['address'] as String? ?? existing.address,
      mondialRelayPoint:
          pulledProfile['mondialRelayPoint'] as String? ?? existing.mondialRelayPoint,
      hideBirthdate:
          pulledProfile['hideBirthdate'] as bool? ?? existing.hideBirthdate,
      hideAddress: pulledProfile['hideAddress'] as bool? ?? existing.hideAddress,
      hideMondialRelay:
          pulledProfile['hideMondialRelay'] as bool? ?? existing.hideMondialRelay,
      fcmToken: pulledProfile['fcmToken'] as String? ?? existing.fcmToken,
    );
  }

  static String buildInviteContactId({
    required String inviterRaw,
    String? tokenId,
    required String fallbackId,
  }) {
    final normalizedId = inviterRaw.isNotEmpty
        ? inviterRaw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        : (tokenId ?? fallbackId)
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return 'invite_$normalizedId';
  }
}
