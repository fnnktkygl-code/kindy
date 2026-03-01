import 'package:pigio_app/core/models/app_models.dart';

class InviteCommands {
  static bool expirePendingInvites(List<PendingInvite> pendingInvites) {
    var changed = false;
    for (int i = 0; i < pendingInvites.length; i++) {
      final invite = pendingInvites[i];
      if (invite.state == PendingInviteState.pending && invite.isExpired) {
        pendingInvites[i] = invite.copyWith(state: PendingInviteState.expired);
        changed = true;
      }
    }
    return changed;
  }

  static void upsertPendingInvite(
    List<PendingInvite> pendingInvites,
    PendingInvite invite, {
    required bool Function(PendingInvite item) replaceWhere,
  }) {
    pendingInvites.removeWhere(replaceWhere);
    pendingInvites.insert(0, invite);
  }
}
