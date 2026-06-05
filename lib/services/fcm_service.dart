import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'pigio_voice.dart';

/// Sends real FCM push notifications via the Supabase Edge Function `send-fcm`.
///
/// The Edge Function must be deployed at:
///   `https://PROJECT_REF.supabase.co/functions/v1/send-fcm`
///
/// It accepts a JSON body:
///   `{ "token": "FCM_DEVICE_TOKEN", "title": "...", "body": "...", "type": "..." }`
///
/// See: supabase/functions/send-fcm/index.ts
class FcmService {
  static const String _path = '/functions/v1/send-fcm';
  static const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const int _maxRetries = 2;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Send a push notification to a single device identified by [fcmToken].
  /// Retries up to [_maxRetries] times on transient failures (timeout, 5xx).
  static Future<void> sendPush({
    required String baseUrl,
    required String fcmToken,
    required String title,
    required String body,
    required String type,
    required String? userJwt,
  }) async {
    final jwt = userJwt?.isNotEmpty == true ? userJwt! : _supabaseAnonKey;
    final uri = Uri.parse('$baseUrl$_path');

    final useMascotVoice = switch (type) {
      'mascot_reengage' || 'circle_stale' => true,
      _ => false,
    };
    final pushTitle = useMascotVoice ? PigioVoice.title(title) : title;
    final pushBody = useMascotVoice ? PigioVoice.body(body) : body;

    final payload = jsonEncode({
      'token': fcmToken,
      'title': pushTitle,
      'body': pushBody,
      'type': type,
    });
    final headers = {
      'Content-Type': 'application/json',
      'apikey': _supabaseAnonKey,
      'Authorization': 'Bearer $jwt',
    };

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http
            .post(uri, headers: headers, body: payload)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode < 400) return; // Success

        // 4xx = client error, don't retry (bad token, malformed request, etc.)
        if (response.statusCode < 500) {
          if (kDebugMode) debugPrint('[Kindy] FCM push failed (${response.statusCode}): ${response.body}');
          return;
        }

        // 5xx = server error, retry
        if (kDebugMode) debugPrint('[Kindy] FCM push 5xx (attempt ${attempt + 1}/${_maxRetries + 1})');
      } catch (e) {
        // Timeout or network error — retry
        if (kDebugMode) debugPrint('[Kindy] FCM push error (attempt ${attempt + 1}/${_maxRetries + 1}): $e');
      }

      if (attempt < _maxRetries) {
        await Future.delayed(_retryDelay * (attempt + 1)); // Linear backoff
      }
    }
  }
}
