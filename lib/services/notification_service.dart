import 'dart:convert';
import 'package:http/http.dart' as http;

/// A notification payload exchanged between contacts via the sync backend.
class PigioNotification {
  final String id;
  final String senderId;
  final String senderName;
  final String type; // profile_updated, sizes_updated, wish_added, wish_updated, invite_accepted
  final String message;
  final DateTime createdAt;
  final bool read;

  const PigioNotification({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.message,
    required this.createdAt,
    this.read = false,
  });

  PigioNotification copyWith({bool? read}) => PigioNotification(
        id: id,
        senderId: senderId,
        senderName: senderName,
        type: type,
        message: message,
        createdAt: createdAt,
        read: read ?? this.read,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'type': type,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };

  factory PigioNotification.fromMap(Map<String, dynamic> map) => PigioNotification(
        id: map['id'] as String? ?? '',
        senderId: map['senderId'] as String? ?? '',
        senderName: map['senderName'] as String? ?? '',
        type: map['type'] as String? ?? 'unknown',
        message: map['message'] as String? ?? '',
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        read: map['read'] as bool? ?? false,
      );

  /// Emoji for notification type
  String get emoji {
    switch (type) {
      case 'profile_updated':
        return '✏️';
      case 'sizes_updated':
        return '📐';
      case 'wish_added':
        return '🎁';
      case 'wish_updated':
        return '🎁';
      case 'invite_accepted':
        return '✅';
      case 'wizz':
        return '⚡';
      case 'pot_created':
      case 'pot_invite':
        return '🎉';
      case 'pot_contribution':
        return '💰';
      case 'pot_completed':
        return '🎊';
      default:
        return '🔔';
    }
  }
}

/// Service that pushes/pulls notifications between contacts using the
/// existing data-sync backend. Notifications are stored under a key
/// like `notif_{contactPushKey}` so each contact has their own inbox.
class NotificationService {
  static const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final String baseApiUrl;
  final http.Client _httpClient;
  final Future<String?> Function()? authTokenProvider;

  // Must match the InvitationService syncPath so both services hit the same
  // Supabase Edge Function endpoint.
  static const String syncPath = '/functions/v1/data-sync';

  NotificationService({
    required this.baseApiUrl,
    http.Client? httpClient,
    this.authTokenProvider,
  }) : _httpClient = httpClient ?? http.Client();

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_supabaseAnonKey.trim().isNotEmpty) {
      headers['apikey'] = _supabaseAnonKey;
    }

    final token = await authTokenProvider?.call();
    final authToken =
        (token != null && token.trim().isNotEmpty) ? token : _supabaseAnonKey;
    if (authToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  String _buildUrl(String path) {
    final base = baseApiUrl.endsWith('/')
        ? baseApiUrl.substring(0, baseApiUrl.length - 1)
        : baseApiUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$base$normalizedPath';
  }

  /// Push a notification to a contact's inbox key.
  /// The key is derived from the contact's push key: `notif_{pushKey}`.
  Future<bool> pushNotification({
    required String pushKey,
    required List<PigioNotification> notifications,
  }) async {
    final notifKey = 'notif_$pushKey';
    final payload = {
      'key': notifKey,
      // Store notifications under profile_data.notifications to remain
      // compatible with the existing data-sync schema.
      'profile': {
        'notifications': notifications.map((n) => n.toMap()).toList(),
      },
      // Satisfy backend schema
      'contacts': <dynamic>[],
      'circles': <dynamic>[],
      'pendingInvites': <dynamic>[],
      'wishes': <dynamic>[],
      'events': <dynamic>[],
      'sizes': <dynamic>[],
    };

    final uri = Uri.parse(_buildUrl(syncPath));
    final response = await _httpClient
        .post(
          uri,
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// Pull notifications from our inbox key.
  Future<List<PigioNotification>> pullNotifications(String pullKey) async {
    final notifKey = 'notif_$pullKey';
    final uri = Uri.parse(_buildUrl(syncPath))
        .replace(queryParameters: {'key': notifKey});
    final response = await _httpClient
      .get(uri, headers: await _headers())
      .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['found'] != true) return [];

    final profile = data['profile'];
    final rawNotifs = profile is Map<String, dynamic>
      ? profile['notifications']
      : null;
    if (rawNotifs is! List) return [];

    return rawNotifs
        .whereType<Map<String, dynamic>>()
        .map((m) => PigioNotification.fromMap(m))
        .toList();
  }
}
