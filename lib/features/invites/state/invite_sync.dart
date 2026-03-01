import '../../../services/invitation_service.dart';

class InviteSync {
  static Future<void> pushAndPullContactExchange({
    required InvitationService invitationService,
    required String pushKey,
    String? pullKey,
    required Map<String, dynamic> profilePayload,
    required List<Map<String, dynamic>> sizesPayload,
    required List<Map<String, dynamic>> wishesPayload,
    required void Function(List rawSizes) onPulledSizes,
    required void Function(Map<String, dynamic> pulledProfile) onPulledProfile,
    required void Function() onPulledCompleted,
  }) async {
    await invitationService.pushProfileData(
      profileKey: pushKey,
      profile: profilePayload,
      sizes: sizesPayload,
      wishes: wishesPayload,
    );

    if (pullKey == null) return;

    final pulled = await invitationService.pullProfileData(pullKey);
    if (pulled == null) return;

    final rawSizes = pulled['sizes'] is List ? pulled['sizes'] as List : null;
    if (rawSizes != null) {
      onPulledSizes(rawSizes);
    }

    final profileData = pulled['profile'] is Map<String, dynamic>
        ? pulled['profile'] as Map<String, dynamic>
        : null;
    if (profileData != null) {
      onPulledProfile(profileData);
    }

    onPulledCompleted();
  }
}
