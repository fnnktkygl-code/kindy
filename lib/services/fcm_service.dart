import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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

  /// Send a push notification to a single device identified by [fcmToken].
  ///
  /// [baseUrl]  — Supabase project base URL, e.g. https://abc.supabase.co
  /// [fcmToken] — recipient device FCM registration token
  /// [title]    — notification title (sender name)
  /// [body]     — notification body text
  /// [type]     — notification type identifier (e.g. 'profile_updated')
  static Future<void> sendPush({
    required String baseUrl,
    required String fcmToken,
    required String title,
    required String body,
    required String type,
  }) async {
    final uri = Uri.parse('$baseUrl$_path');
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': _supabaseAnonKey,
              'Authorization': 'Bearer $_supabaseAnonKey',
            },
            body: jsonEncode({
              'token': fcmToken,
              'title': title,
              'body': body,
              'type': type,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (kDebugMode && response.statusCode >= 400) {
        debugPrint('[Pigio] FCM push failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Pigio] FCM push error: $e');
    }
  }
}
