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
    } catch (_) {
      return InvitationLinkResolution(valid: false);
    }
  }
}
