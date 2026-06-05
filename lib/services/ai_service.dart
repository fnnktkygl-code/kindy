import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kindy/core/state/app_state.dart';

class AiService {
  // The Vertex AI key is now kept server-side in the ai-proxy edge function.
  // Only the Supabase URL and anon key are needed client-side.
  static const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _storage = FlutterSecureStorage();

  // ─── INTERNAL HELPERS ──────────────────────────────────────────────────────

  /// Core LLM call via server-side ai-proxy with local caching.
  /// [systemPrompt] sets the persona; [userPrompt] is the dynamic task.
  /// Both are hashed together for the cache key.
  static Future<String?> _call(
      String systemPrompt,
      String userPrompt,
      String contextName, {
        bool useThinking = false,
      }) async {
    if (_supabaseUrl.isEmpty) return null;
    try {
      final cacheKey = 'ai_v3_${(systemPrompt + userPrompt).hashCode.abs()}';
      final tsKey = '${cacheKey}_ts';
      const cacheTtl = Duration(hours: 24);
      const maxCacheEntries = 30;

      // Check cache validity (TTL) — stored in encrypted FlutterSecureStorage
      final cachedTs = await _storage.read(key: tsKey);
      if (cachedTs != null) {
        final cached = await _storage.read(key: cacheKey);
        if (cached != null) {
          final age = DateTime.now().millisecondsSinceEpoch - (int.tryParse(cachedTs) ?? 0);
          if (age < cacheTtl.inMilliseconds) {
            if (kDebugMode) debugPrint('[$contextName] Cache hit');
            return cached;
          } else {
            // Expired — evict
            await _storage.delete(key: cacheKey);
            await _storage.delete(key: tsKey);
          }
        }
      }

      // Enforce max cache size via manifest stored in secure storage.
      final manifestRaw = await _storage.read(key: 'ai_cache_manifest');
      List<String> manifest = manifestRaw != null
          ? List<String>.from(jsonDecode(manifestRaw))
          : <String>[];
      if (manifest.length >= maxCacheEntries) {
        // Evict oldest entries (they are added in order)
        final toEvict = manifest.sublist(0, manifest.length - maxCacheEntries + 1);
        for (final old in toEvict) {
          await _storage.delete(key: old);
          await _storage.delete(key: '${old}_ts');
        }
        manifest = manifest.sublist(toEvict.length);
        await _storage.write(
          key: 'ai_cache_manifest',
          value: jsonEncode(manifest),
        );
      }

      // Call the ai-proxy edge function — API key stays server-side.
      final url = Uri.parse('$_supabaseUrl/functions/v1/ai-proxy');
      final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
      final authToken = (jwt != null && jwt.isNotEmpty) ? jwt : _supabaseAnonKey;

      final body = {
        'systemPrompt': systemPrompt,
        'userPrompt': userPrompt,
        'maxOutputTokens': 80,
        'temperature': 0.9,
        'useThinking': useThinking,
      };

      final response = await http
          .post(url,
              headers: {
                'Content-Type': 'application/json',
                'apikey': _supabaseAnonKey,
                'Authorization': 'Bearer $authToken',
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['text'] as String?;

        if (result != null && result.isNotEmpty) {
          await _storage.write(key: cacheKey, value: result);
          await _storage.write(
            key: tsKey,
            value: DateTime.now().millisecondsSinceEpoch.toString(),
          );
          // Update manifest
          if (!manifest.contains(cacheKey)) {
            manifest.add(cacheKey);
            await _storage.write(
              key: 'ai_cache_manifest',
              value: jsonEncode(manifest),
            );
          }
          return result;
        }
      } else {
        if (kDebugMode) {
          debugPrint('[$contextName] HTTP ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[$contextName] Error: $e');
    }
    return null;
  }

  // ─── PUBLIC API ────────────────────────────────────────────────────────────

  /// Generates a short, personalised gift suggestion for an upcoming birthday.
  /// Output is intentionally capped at ~15 words so it fits in the mascot bubble.
  static Future<String?> generateGiftConcierge(
      ContactProfile contact, {String personalityContext = ''}) async {
    final rel = contact.role.isNotEmpty ? contact.role : 'proche';
    final bday = contact.birthdate?.isNotEmpty == true
        ? 'Birthdate: ${contact.birthdate}'
        : '';
    final personality = personalityContext.isNotEmpty
        ? "Recipient's personality & preferences: $personalityContext"
        : '';

    const system = '''
You are Pigio, a warm gift-app mascot. 
Reply in the app's language (French if context is French, English otherwise).
Write EXACTLY 1 sentence, max 15 words. Sign with "— Pigio 🎁".
No markdown, no bullet points, no newlines.
''';

    final user =
        'Suggest one very specific, original gift for ${contact.name} ($rel). $bday $personality'.trim();

    final result = await _call(system, user, 'Gift Concierge');
    if (result != null) await _incrementConciergeUsage();
    return result;
  }

  /// Check how many concierge calls the user has made this month.
  /// Returns the remaining free calls (out of [freeMonthlyLimit]).
  static Future<int> remainingFreeConcierge({int freeMonthlyLimit = 3}) async {
    final used = await _conciergeUsedThisMonth();
    return (freeMonthlyLimit - used).clamp(0, freeMonthlyLimit);
  }

  /// Increment the monthly concierge usage counter.
  static Future<void> _incrementConciergeUsage() async {
    final now = DateTime.now();
    final monthKey = 'ai_concierge_${now.year}_${now.month}';
    final raw = await _storage.read(key: monthKey);
    final count = (raw != null ? int.tryParse(raw) ?? 0 : 0) + 1;
    await _storage.write(key: monthKey, value: count.toString());
  }

  static Future<int> _conciergeUsedThisMonth() async {
    final now = DateTime.now();
    final monthKey = 'ai_concierge_${now.year}_${now.month}';
    final raw = await _storage.read(key: monthKey);
    return raw != null ? int.tryParse(raw) ?? 0 : 0;
  }

  /// Generates 3 specific gift suggestions with product names and search URLs.
  /// Each suggestion is returned as a map with 'name', 'emoji', and 'searchUrl'.
  /// The caller should wrap searchUrl through AffiliateService.affiliateUrl().
  /// Premium feature: free users get 3/month, Pigio+ gets unlimited.
  static Future<List<Map<String, String>>> generateGiftSuggestions(
    ContactProfile contact, {
    String personalityContext = '',
    List<String> existingWishes = const [],
  }) async {
    final rel = contact.role.isNotEmpty ? contact.role : 'proche';
    final bday = contact.birthdate?.isNotEmpty == true
        ? 'Birthdate: ${contact.birthdate}'
        : '';
    final personality = personalityContext.isNotEmpty
        ? "Recipient's personality: $personalityContext"
        : '';
    final existing = existingWishes.isNotEmpty
        ? 'Already on wishlist (avoid duplicates): ${existingWishes.take(10).join(', ')}'
        : '';

    const system = '''
You are Pigio, a gift recommendation engine.
Reply ONLY with a JSON array of exactly 3 objects.
Each object: {"name": "Product name", "emoji": "single emoji", "searchUrl": "https://www.amazon.fr/s?k=url-encoded+search+terms"}
Rules:
- Be specific (brand + model when possible)
- Price range: 15-80€
- Use amazon.fr search URLs with relevant keywords
- No markdown, no explanation, just the JSON array
''';

    final user =
        'Suggest 3 gift ideas for ${contact.name} ($rel). $bday $personality $existing'.trim();

    final result = await _call(system, user, 'Gift Suggestions');
    if (result == null) return [];
    await _incrementConciergeUsage();

    try {
      final decoded = jsonDecode(result);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>().map((m) => {
              'name': m['name']?.toString() ?? '',
              'emoji': m['emoji']?.toString() ?? '🎁',
              'searchUrl': m['searchUrl']?.toString() ?? '',
            }).toList();
      }
    } catch (_) {
      // Fallback: try to extract from malformed JSON
    }
    return [];
  }
}