import 'package:pigio_app/core/state/app_state.dart';

/// Simple client-side churn risk scoring.
///
/// Computes a 0-100 risk score based on user behavior signals.
/// High-risk users (score > 60) get preemptive birthday/value pushes
/// instead of generic re-engagement messages.
class ChurnScoreService {
  ChurnScoreService._();

  /// Compute churn risk score (0 = no risk, 100 = very high risk).
  static int computeScore(PigioAppState state) {
    int score = 0;

    // Factor 1: Days since last open (strongest signal)
    final absence = state.mascotAbsenceDays;
    if (absence >= 14) {
      score += 40;
    } else if (absence >= 7) {
      score += 25;
    } else if (absence >= 3) {
      score += 10;
    }

    // Factor 2: No contacts = low value perception
    if (state.contacts.isEmpty) {
      score += 20;
    } else if (state.contacts.length < 3) {
      score += 10;
    }

    // Factor 3: No wishes = hasn't engaged with core feature
    if (state.getWishesFor(null).isEmpty) {
      score += 15;
    }

    // Factor 4: No invites sent = no social investment
    if (state.pendingInvites.isEmpty) {
      score += 10;
    }

    // Factor 5: Low bond level = low emotional connection
    if (state.mascotBondLevel == 0) {
      score += 10;
    }

    // Factor 6: Broken streak = engagement decay
    if (state.loginStreak == 0 && absence >= 2) {
      score += 5;
    }

    return score.clamp(0, 100);
  }

  /// Returns a risk tier for the score.
  static ChurnRisk riskTier(int score) {
    if (score >= 60) return ChurnRisk.high;
    if (score >= 30) return ChurnRisk.medium;
    return ChurnRisk.low;
  }

  /// Get the best preemptive push message for an at-risk user.
  /// Returns null if no high-value message is available (don't send a generic one).
  static ChurnPushContent? getPreemptivePush(PigioAppState state) {
    final score = computeScore(state);
    if (riskTier(score) == ChurnRisk.low) return null;

    final isFr = state.locale.languageCode == 'fr';

    // Priority 1: Upcoming birthday (highest-value contextual trigger)
    final now = DateTime.now();
    for (final contact in state.contacts) {
      if (contact.birthdate == null || contact.birthdate!.isEmpty) continue;
      final nextBday = _nextBirthday(contact.birthdate!, now);
      if (nextBday == null) continue;
      final daysUntil = nextBday.difference(now).inDays;
      if (daysUntil >= 0 && daysUntil <= 7) {
        return ChurnPushContent(
          title: isFr ? '🎂 Anniversaire à venir' : '🎂 Upcoming birthday',
          body: isFr
              ? "L'anniversaire de ${contact.name} est dans $daysUntil jour${daysUntil > 1 ? 's' : ''}"
              : "${contact.name}'s birthday is in $daysUntil day${daysUntil > 1 ? 's' : ''}",
          type: 'churn_birthday',
        );
      }
    }

    // Priority 2: Unreserved wishes in their contacts' lists
    final unreservedCount = state.wishes
        .where((w) => w.contactId != null && w.reservedById == null)
        .length;
    if (unreservedCount > 0) {
      return ChurnPushContent(
        title: isFr ? '🎁 Idées cadeaux' : '🎁 Gift ideas',
        body: isFr
            ? '$unreservedCount idée${unreservedCount > 1 ? 's' : ''} de cadeaux à découvrir'
            : '$unreservedCount gift idea${unreservedCount > 1 ? 's' : ''} to explore',
        type: 'churn_wishes',
      );
    }

    // Priority 3: Generic but warm (only for high risk)
    if (riskTier(score) == ChurnRisk.high) {
      return ChurnPushContent(
        title: isFr ? '🐧 Pigio' : '🐧 Pigio',
        body: isFr
            ? 'Tes proches ont peut-être mis à jour leurs envies'
            : 'Your friends may have updated their wishlists',
        type: 'churn_generic',
      );
    }

    return null;
  }

  static DateTime? _nextBirthday(String birthdate, DateTime now) {
    try {
      final parts = birthdate.split('/');
      if (parts.length < 2) return null;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      var next = DateTime(now.year, month, day);
      if (next.isBefore(now.subtract(const Duration(days: 1)))) {
        next = DateTime(now.year + 1, month, day);
      }
      return next;
    } catch (_) {
      return null;
    }
  }
}

enum ChurnRisk { low, medium, high }

class ChurnPushContent {
  final String title;
  final String body;
  final String type;

  const ChurnPushContent({
    required this.title,
    required this.body,
    required this.type,
  });
}
