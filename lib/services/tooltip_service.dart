import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which contextual tooltips have been shown to avoid repetition.
/// Used for post-onboarding progressive disclosure.
class TooltipService {
  TooltipService._();

  static const _prefix = 'pigio_tooltip_';

  // Tooltip keys
  static const homeAddContact = 'home_add_contact';
  static const calendarEmpty = 'calendar_empty';
  static const firstContactInvite = 'first_contact_invite';
  static const wishlistShare = 'wishlist_share';
  static const circleCreate = 'circle_create';

  /// Returns true if the tooltip has NOT been shown yet, then marks it as shown.
  /// Use: `if (await TooltipService.shouldShow(TooltipService.homeAddContact)) { ... }`
  static Future<bool> shouldShow(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final fullKey = '$_prefix$key';
    if (prefs.getBool(fullKey) == true) return false;
    await prefs.setBool(fullKey, true);
    return true;
  }

  /// Check without marking as shown.
  static Future<bool> wasShown(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$key') == true;
  }

  /// Reset a specific tooltip (for testing).
  static Future<void> reset(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  /// Reset all tooltips.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
