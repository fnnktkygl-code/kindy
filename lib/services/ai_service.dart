import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pigio_app/core/state/app_state.dart';

class AiService {
  // Injected at build time via --dart-define=VERTEX_AI_KEY=... and
  // --dart-define=VERTEX_PROJECT_ID=... Never hard-code these values.
  static const _apiKey = String.fromEnvironment('VERTEX_AI_KEY');
  static const _projectId = String.fromEnvironment('VERTEX_PROJECT_ID');
  static const _region = 'europe-west9';
  static const _modelName = 'gemini-2.5-flash';

  // ─── INTERNAL HELPERS ──────────────────────────────────────────────────────

  static void _logUsageRaw(Map<String, dynamic>? usage, String ctx) {
    if (kDebugMode && usage != null) {
      debugPrint('--- GEMINI ($ctx) | '
          'prompt=${usage['promptTokenCount']} '
          'out=${usage['candidatesTokenCount']} '
          'total=${usage['totalTokenCount']} ---');
    }
  }

  /// Core LLM call with local caching.
  /// [systemPrompt] sets the persona; [userPrompt] is the dynamic task.
  /// Both are hashed together for the cache key.
  static Future<String?> _call(
      String systemPrompt,
      String userPrompt,
      String contextName, {
        bool useThinking = false,
      }) async {
    if (_apiKey.isEmpty || _projectId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'ai_v3_${(systemPrompt + userPrompt).hashCode.abs()}';
      final tsKey = '${cacheKey}_ts';
      const cacheTtl = Duration(hours: 24);
      const cachePrefix = 'ai_v3_';
      const maxCacheEntries = 30;

      // Check cache validity (TTL)
      final cachedTs = prefs.getInt(tsKey);
      if (cachedTs != null && prefs.containsKey(cacheKey)) {
        final age = DateTime.now().millisecondsSinceEpoch - cachedTs;
        if (age < cacheTtl.inMilliseconds) {
          if (kDebugMode) debugPrint('[$contextName] Cache hit');
          return prefs.getString(cacheKey);
        } else {
          // Expired — evict
          await prefs.remove(cacheKey);
          await prefs.remove(tsKey);
        }
      }

      // Enforce max cache size (evict oldest entries)
      final allKeys = prefs.getKeys()
          .where((k) => k.startsWith(cachePrefix) && !k.endsWith('_ts'))
          .toList();
      if (allKeys.length >= maxCacheEntries) {
        allKeys.sort((a, b) {
          final ta = prefs.getInt('${a}_ts') ?? 0;
          final tb = prefs.getInt('${b}_ts') ?? 0;
          return ta.compareTo(tb);
        });
        for (final old in allKeys.take(allKeys.length - maxCacheEntries + 1)) {
          await prefs.remove(old);
          await prefs.remove('${old}_ts');
        }
      }

      final url = Uri.parse(
          'https://$_region-aiplatform.googleapis.com/v1/projects/$_projectId/locations/$_region/publishers/google/models/$_modelName:generateContent');

      final body = {
        'systemInstruction': {
          'role': 'system',
          'parts': [
            {'text': systemPrompt}
          ]
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': userPrompt}
            ]
          }
        ],
        'generationConfig': {
          if (!useThinking) 'thinkingConfig': {'thinkingBudget': 0},
          'maxOutputTokens': 80, // Hard cap — keeps output short
          'temperature': 0.9,
        },
      };

      final response = await http
          .post(url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': _apiKey,
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _logUsageRaw(data['usageMetadata'], contextName);

        final text = (data['candidates'] as List?)
            ?.firstOrNull?['content']?['parts']
        as List?;
        final result = text?.firstOrNull?['text'] as String?;

        if (result != null && result.isNotEmpty) {
          await prefs.setString(cacheKey, result);
          await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
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

  /// Parses a user-provided URL or free-text into a structured wish object.
  static Future<Map<String, dynamic>?> generateMagicWish(String input) async {
    String pageContext = 'Raw input: $input';
    String scrapingStatus = 'Not attempted';

    if (input.startsWith('http')) {
      scrapingStatus = 'Attempting via Microlink…';
      try {
        final res = await http
            .get(Uri.parse(
            'https://api.microlink.io?url=${Uri.encodeComponent(input)}'))
            .timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'success') {
            final meta = data['data'];
            scrapingStatus = 'Success';
            pageContext =
            'Title: ${meta['title'] ?? 'Unknown'}\n'
                'Image: ${meta['image']?['url'] ?? 'None'}\n'
                'URL: $input';
          } else {
            scrapingStatus = 'Failed (bot protection)';
          }
        } else {
          scrapingStatus = 'Failed (HTTP ${res.statusCode})';
        }
      } catch (_) {
        scrapingStatus = 'Failed (network)';
      }
    }

    const system = '''
You are a wish-list assistant. Return ONLY a JSON object, no markdown, no extra text.
Rules:
- title: max 5 words, no brand hallucination
- priceRange: "budget"|"mid"|"premium"|null
- priority: "low"|"medium"|"high"
- suggestedImages: array of 0–3 real image URLs from the scraped data
''';

    final user = '''
Scrape status: $scrapingStatus
Available data: $pageContext

Return: {"title":"…","priceRange":…,"priority":…,"suggestedImages":[…]}
''';

    try {
      final text = await _call(system, user, 'Magic Wish');
      if (text != null) {
        final clean = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final map = jsonDecode(clean) as Map<String, dynamic>;
        if (map['suggestedImages'] != null &&
            (map['suggestedImages'] as List).isNotEmpty) {
          map['imageUrl'] = (map['suggestedImages'] as List).first;
        }
        return map;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Magic Wish parse error: $e');
    }
    return null;
  }

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

    return _call(system, user, 'Gift Concierge');
  }

  /// Warns the user about a busy upcoming month with no gifts saved.
  static Future<String?> generateBusyMonthInsight(
      String monthName, List<String> names) async {
    const system = '''
You are Pigio, a warm gift-app mascot.
Reply in the app's language (French if context is French, English otherwise).
Write EXACTLY 1 sentence, max 18 words. Friendly & slightly playful. Sign "— Pigio 📅".
No markdown, no bullet points, no newlines.
''';

    final namesList = names.join(', ');
    final user =
        '$monthName has events for $namesList but no gifts are saved yet.';

    return _call(system, user, 'Busy Month');
  }

  /// Produces a short, funny year-in-review for the user's wish history.
  /// Output is limited to 2 short sentences.
  static Future<String?> generatePigioWrapped(List<Wish> wishes) async {
    if (wishes.isEmpty) return null;

    const system = '''
You are Pigio, a warm gift-app mascot doing a year-end wrap-up.
Reply in French (or English if the user's language is English).
Write EXACTLY 2 short sentences, max 25 words total. Be funny, warm, a bit cheeky.
Sign "— Pigio 🎁". No markdown, no bullet points.
''';

    final summary = wishes
        .map((w) =>
    '${w.title} (${w.priceRange?.name ?? 'unknown price'})')
        .join(', ');

    final user = 'Gifts this year: $summary';

    return _call(system, user, 'Pigio Wrapped');
  }
}