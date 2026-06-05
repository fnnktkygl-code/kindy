import 'package:flutter/foundation.dart';
import '../../../services/invitation_service.dart';

class InviteResolution {
  static Future<InvitationLinkResolution> resolveIncomingLinkWithFallback({
    required InvitationService invitationService,
    required Uri link,
    required ExchangeProfile accepterProfile,
  }) async {
    try {
      return await invitationService.resolveIncomingLink(
        link,
        accepterProfile: accepterProfile,
      );
    } catch (e) {
      debugPrint('[InviteResolution] Failed to resolve link $link: $e');
      return InvitationLinkResolution(valid: false);
    }
  }
}
