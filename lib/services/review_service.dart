import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages in-app review prompts at high-value moments.
/// Uses Apple/Google's native review dialog — they control display frequency.
class ReviewService {
  ReviewService._();

  static const _lastPromptKey = 'pigio_last_review_prompt';
  static const _promptCountKey = 'pigio_review_prompt_count';
  static const _minDaysBetweenPrompts = 60; // Don't ask more than every 2 months
  static const _maxLifetimePrompts = 5;     // Stop after 5 attempts total

  /// Try to show a review prompt if conditions are met.
  /// Call this at high-value moments:
  /// - After bond level-up
  /// - After first invite accepted
  /// - After 7-day streak
  /// Safe to call frequently — internally rate-limited.
  static Future<void> tryPrompt() async {
    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;

      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_promptCountKey) ?? 0;
      if (count >= _maxLifetimePrompts) return;

      final lastRaw = prefs.getString(_lastPromptKey);
      if (lastRaw != null) {
        final last = DateTime.tryParse(lastRaw);
        if (last != null && DateTime.now().difference(last).inDays < _minDaysBetweenPrompts) {
          return;
        }
      }

      await review.requestReview();

      await prefs.setString(_lastPromptKey, DateTime.now().toIso8601String());
      await prefs.setInt(_promptCountKey, count + 1);
    } catch (e) {
      if (kDebugMode) debugPrint('ReviewService: $e');
    }
  }
}
