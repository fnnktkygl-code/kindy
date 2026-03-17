import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight, privacy-first analytics service.
///
/// Logs key user events locally and optionally forwards them to the
/// `analytics` Supabase table when authenticated. No third-party SDK required.
///
/// Events tracked (10 key growth events):
///   1. onboarding_completed   — with step count & whether contact was added
///   2. first_contact_added    — activation signal
///   3. first_wish_added       — core value action
///   4. first_invite_sent      — growth loop entry
///   5. invite_accepted        — growth loop completion
///   6. circle_created         — network expansion
///   7. daily_return           — D1/D7/D30 cohort marker
///   8. mascot_interaction     — engagement depth
///   9. wardrobe_unlock        — retention mechanic
///  10. push_opened            — channel effectiveness
class AnalyticsService {
  AnalyticsService._();

  static const _eventsKey = 'pigio_analytics_events';
  static const _dailyReturnKey = 'pigio_daily_return_last';
  static const _installDayKey = 'pigio_install_day';

  static bool _initialized = false;
  static DateTime? _installDate;

  /// Call once at app start to record install date and daily return.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();

    // Record install date (first ever open)
    final installRaw = prefs.getString(_installDayKey);
    if (installRaw == null) {
      _installDate = DateTime.now();
      await prefs.setString(_installDayKey, _installDate!.toIso8601String());
      await log('first_open');
    } else {
      _installDate = DateTime.tryParse(installRaw) ?? DateTime.now();
    }

    // Daily return tracking
    final lastReturnRaw = prefs.getString(_dailyReturnKey);
    final today = _dateKey(DateTime.now());
    if (lastReturnRaw != today) {
      await prefs.setString(_dailyReturnKey, today);
      final daysSinceInstall = DateTime.now().difference(_installDate!).inDays;
      await log('daily_return', {'day': daysSinceInstall});
    }
  }

  /// Log an analytics event with optional properties.
  static Future<void> log(String event, [Map<String, dynamic>? props]) async {
    final entry = {
      'event': event,
      'ts': DateTime.now().toIso8601String(),
      if (props != null) ...props,
    };

    if (kDebugMode) debugPrint('[Analytics] $event ${props ?? ''}');

    // Persist locally (ring buffer of last 200 events)
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_eventsKey) ?? [];
      raw.add(jsonEncode(entry));
      if (raw.length > 200) raw.removeRange(0, raw.length - 200);
      await prefs.setStringList(_eventsKey, raw);
    } catch (_) {}

    // Forward to Supabase if authenticated
    _forwardToSupabase(entry);
  }

  /// Track one-time milestone events (only fires once per key).
  static Future<void> logOnce(String event, [Map<String, dynamic>? props]) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'pigio_a_once_$event';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);
    await log(event, props);
  }

  /// Days since install (for cohort bucketing).
  static int get daysSinceInstall =>
      _installDate != null ? DateTime.now().difference(_installDate!).inDays : 0;

  // ── Convenience loggers for the 10 key events ──────────────────────────────

  static Future<void> onboardingCompleted({
    required int stepCount,
    required bool addedContact,
    required bool addedWish,
  }) =>
      logOnce('onboarding_completed', {
        'steps': stepCount,
        'added_contact': addedContact,
        'added_wish': addedWish,
      });

  static Future<void> firstContactAdded() => logOnce('first_contact_added');

  static Future<void> firstWishAdded() => logOnce('first_wish_added');

  static Future<void> firstInviteSent() => logOnce('first_invite_sent');

  static Future<void> inviteAccepted() => log('invite_accepted');

  static Future<void> circleCreated() => logOnce('circle_created');

  static Future<void> mascotInteraction(String type) =>
      log('mascot_interaction', {'type': type});

  static Future<void> wardrobeUnlock(String itemId) =>
      log('wardrobe_unlock', {'item': itemId});

  static Future<void> pushOpened(String type) =>
      log('push_opened', {'type': type});

  // ── Private ────────────────────────────────────────────────────────────────

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> _forwardToSupabase(Map<String, dynamic> entry) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;
      await Supabase.instance.client.from('analytics').insert({
        'user_id': session.user.id,
        'event': entry['event'],
        'properties': jsonEncode(entry),
        'created_at': entry['ts'],
      });
    } catch (_) {
      // Analytics should never crash the app — silently discard failures.
    }
  }
}
