import 'dart:convert';

import 'package:http/http.dart' as http;

/// Public profile payload exchanged during invite create/resolve.
class ExchangeProfile {
  final String? name;
  final String? handle;
  final int? memberSince;
  final String? avatarIcon;
  final int? avatarColor;
  final String? birthdate;
  final String? address;
  final String? mondialRelayPoint;
  final bool? hideBirthdate;
  final bool? hideAddress;
  final bool? hideMondialRelay;
  final String? fcmToken;
  /// Serialized SizeProfile list (only own sizes, contactId omitted).
  final List<Map<String, dynamic>>? sizes;
  /// Serialized own wishes list.
  final List<Map<String, dynamic>>? wishes;

  const ExchangeProfile({
    this.name,
    this.handle,
    this.memberSince,
    this.avatarIcon,
    this.avatarColor,
    this.birthdate,
    this.address,
    this.mondialRelayPoint,
    this.hideBirthdate,
    this.hideAddress,
    this.hideMondialRelay,
    this.fcmToken,
    this.sizes,
    this.wishes,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'handle': handle,
        'memberSince': memberSince,
        'avatarIcon': avatarIcon,
        'avatarColor': avatarColor,
        'birthdate': birthdate,
        'address': address,
        'mondialRelayPoint': mondialRelayPoint,
        'hideBirthdate': hideBirthdate,
        'hideAddress': hideAddress,
        'hideMondialRelay': hideMondialRelay,
        'fcmToken': fcmToken,
        if (sizes != null && sizes!.isNotEmpty) 'sizes': sizes,
        if (wishes != null && wishes!.isNotEmpty) 'wishes': wishes,
      };

  factory ExchangeProfile.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>>? parsedSizes;
    List<Map<String, dynamic>>? parsedWishes;
    final sizesRaw = map['sizes'];
    if (sizesRaw is List) {
      parsedSizes = sizesRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final wishesRaw = map['wishes'];
    if (wishesRaw is List) {
      parsedWishes = wishesRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return ExchangeProfile(
      name: map['name'] as String?,
      handle: map['handle'] as String?,
      memberSince: map['memberSince'] is int ? map['memberSince'] as int : null,
      avatarIcon: map['avatarIcon'] as String?,
      avatarColor: map['avatarColor'] is int ? map['avatarColor'] as int : null,
      birthdate: map['birthdate'] as String?,
      address: map['address'] as String?,
      mondialRelayPoint: map['mondialRelayPoint'] as String?,
      hideBirthdate: map['hideBirthdate'] as bool?,
      hideAddress: map['hideAddress'] as bool?,
      hideMondialRelay: map['hideMondialRelay'] as bool?,
      fcmToken: map['fcmToken'] as String?,
      sizes: parsedSizes,
      wishes: parsedWishes,
    );
  }
}

class InvitationServiceException implements Exception {
  final String message;
  final int? statusCode;

  InvitationServiceException(this.message, {this.statusCode});

  @override
  String toString() {
    if (statusCode == null) return message;
    return '$message (HTTP $statusCode)';
  }
}

class InvitationTokenResponse {
  final String invitationId;
  final String tokenId;
  final String inviteLink;
  final DateTime expiresAt;

  InvitationTokenResponse({
    required this.invitationId,
    required this.tokenId,
    required this.inviteLink,
    required this.expiresAt,
  });

  factory InvitationTokenResponse.fromMap(Map<String, dynamic> map) {
    final invitationId = (map['invitationId'] ?? map['id'] ?? '').toString();
    final tokenId = (map['tokenId'] ?? map['token'] ?? '').toString();
    final inviteLink = (map['inviteLink'] ?? map['link'] ?? '').toString();
    final expiresAtRaw = (map['expiresAt'] ?? map['expires_at'] ?? '').toString();

    return InvitationTokenResponse(
      invitationId: invitationId,
      tokenId: tokenId,
      inviteLink: inviteLink,
      expiresAt: DateTime.tryParse(expiresAtRaw) ?? DateTime.now(),
    );
  }
}

class InvitationLinkResolution {
  final bool valid;
  final String? tokenId;
  final String? inviterId;
  final String? contactId;
  final String? groupId;
  final DateTime? expiresAt;
  final ExchangeProfile? inviterProfile;

  InvitationLinkResolution({
    required this.valid,
    this.tokenId,
    this.inviterId,
    this.contactId,
    this.groupId,
    this.expiresAt,
    this.inviterProfile,
  });

  factory InvitationLinkResolution.fromMap(Map<String, dynamic> map) {
    final inviterRaw = map['inviterProfile'];
    return InvitationLinkResolution(
      valid: map['valid'] as bool? ?? false,
      tokenId: (map['tokenId'] ?? map['token'])?.toString(),
      inviterId: (map['inviterId'] ?? map['inviter_id'])?.toString(),
      contactId: (map['contactId'] ?? map['contact_id'])?.toString(),
      groupId: (map['groupId'] ?? map['group_id'])?.toString(),
      expiresAt: (map['expiresAt'] ?? map['expires_at']) != null
          ? DateTime.tryParse((map['expiresAt'] ?? map['expires_at']).toString())
          : null,
      inviterProfile: inviterRaw is Map<String, dynamic>
          ? ExchangeProfile.fromMap(inviterRaw)
          : null,
    );
  }
}

class InvitationTokenStatus {
  final bool found;
  final String status;
  final String? tokenId;
  final String? inviterId;
  final String? contactId;
  final String? groupId;
  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final ExchangeProfile? accepterProfile;

  InvitationTokenStatus({
    required this.found,
    required this.status,
    this.tokenId,
    this.inviterId,
    this.contactId,
    this.groupId,
    this.expiresAt,
    this.acceptedAt,
    this.accepterProfile,
  });

  factory InvitationTokenStatus.fromMap(Map<String, dynamic> map) {
    final accepterRaw = map['accepterProfile'];
    return InvitationTokenStatus(
      found: map['found'] as bool? ?? false,
      status: (map['status'] as String?) ?? 'unknown',
      tokenId: map['tokenId']?.toString(),
      inviterId: (map['inviterId'] ?? map['inviter_id'])?.toString(),
      contactId: (map['contactId'] ?? map['contact_id'])?.toString(),
      groupId: (map['groupId'] ?? map['group_id'])?.toString(),
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt'].toString())
          : null,
      acceptedAt: map['acceptedAt'] != null
          ? DateTime.tryParse(map['acceptedAt'].toString())
          : null,
      accepterProfile: accepterRaw is Map<String, dynamic>
          ? ExchangeProfile.fromMap(accepterRaw)
          : null,
    );
  }
}

class InvitationService {
  static const String _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final String baseApiUrl;
  final Future<String?> Function()? authTokenProvider;
  final http.Client _httpClient;
  final String createTokenPath;
  final String resolvePath;
  final String statusPath;
  final String syncPath;
  final String legacyCreateTokenPath;
  final String legacyResolvePath;

  InvitationService({
    required this.baseApiUrl,
    this.authTokenProvider,
    this.createTokenPath = '/functions/v1/invite-create',
    this.resolvePath = '/functions/v1/invite-resolve',
    this.statusPath = '/functions/v1/invite-status',
    this.syncPath = '/functions/v1/data-sync',
    this.legacyCreateTokenPath = '/v1/invitations/token',
    this.legacyResolvePath = '/v1/invitations/resolve',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  void dispose() {
    _httpClient.close();
  }

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

  Future<InvitationTokenResponse> createToken({
    required String inviterId,
    String? contactId,
    String? groupId,
    required String channel,
    Duration ttl = const Duration(hours: 48),
    ExchangeProfile? profile,
  }) async {
    final payload = <String, dynamic>{
      'inviterId': inviterId,
      'groupId': groupId,
      'channel': channel,
      'ttlSeconds': ttl.inSeconds,
    };
    if (contactId != null && contactId.trim().isNotEmpty) {
      payload['contactId'] = contactId;
    }
    if (profile != null) {
      payload['profile'] = profile.toMap();
    }

    final response = await _postWithLegacyFallback(
      primaryPath: createTokenPath,
      legacyPath: legacyCreateTokenPath,
      payload: payload,
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return InvitationTokenResponse.fromMap(data);
  }

  Future<InvitationLinkResolution> resolveIncomingLink(
    Uri link, {
    ExchangeProfile? accepterProfile,
  }) async {
    final payload = <String, dynamic>{
      'incomingUrl': link.toString(),
    };
    if (accepterProfile != null) {
      payload['accepterProfile'] = accepterProfile.toMap();
    }

    final response = await _postWithLegacyFallback(
      primaryPath: resolvePath,
      legacyPath: legacyResolvePath,
      payload: payload,
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return InvitationLinkResolution.fromMap(data);
  }

  Future<InvitationTokenStatus?> getTokenStatus(String tokenId) async {
    final token = tokenId.trim();
    if (token.isEmpty) return null;

    final uri = Uri.parse(_buildUrl(statusPath)).replace(queryParameters: {'token': token});
    final response = await _httpClient
      .get(uri, headers: await _headers())
      .timeout(const Duration(seconds: 12));

    if (response.statusCode == 404 || response.statusCode == 405) {
      return null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return InvitationTokenStatus.fromMap(data);
  }

  // ─── Cloud Sync ───────────────────────────────────────────────

  /// Pull all user data from the cloud for the given sync key.
  Future<Map<String, dynamic>?> pullSyncData(String syncKey) async {
    final uri = Uri.parse(_buildUrl(syncPath)).replace(queryParameters: {'key': syncKey});
    final response = await _httpClient
      .get(uri, headers: await _headers())
      .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['found'] != true) return null;
    return data;
  }

  /// Push user data to the cloud for the given sync key.
  Future<bool> pushSyncData({
    required String syncKey,
    required List<Map<String, dynamic>> contacts,
    required List<Map<String, dynamic>> circles,
    required List<Map<String, dynamic>> pendingInvites,
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> wishes,
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> sizes,
    List<Map<String, dynamic>> giftPots = const [],
  }) async {
    final payload = {
      'key': syncKey,
      'contacts': contacts,
      'circles': circles,
      'pendingInvites': pendingInvites,
      'profile': profile,
      'wishes': wishes,
      'events': events,
      'sizes': sizes,
      'giftPots': giftPots,
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

  /// Push only profile + sizes to a contact-profile exchange key.
  /// Used so that the other side of an invite can pull your latest profile.
  Future<bool> pushProfileData({
    required String profileKey,
    required Map<String, dynamic> profile,
    required List<Map<String, dynamic>> sizes,
    List<Map<String, dynamic>>? wishes,
  }) async {
    final payload = {
      'key': profileKey,
      'profile': profile,
      'sizes': sizes,
      // Empty collections to satisfy backend schema if required
      'contacts': <dynamic>[],
      'circles': <dynamic>[],
      'pendingInvites': <dynamic>[],
      'wishes': wishes ?? <dynamic>[],
      'events': <dynamic>[],
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

  /// Pull only profile + sizes from a contact-profile exchange key.
  Future<Map<String, dynamic>?> pullProfileData(String profileKey) async {
    final uri = Uri.parse(_buildUrl(syncPath)).replace(queryParameters: {'key': profileKey});
    final response = await _httpClient
      .get(uri, headers: await _headers())
      .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['found'] != true) return null;
    return data;
  }

  // ─── Internals ──────────────────────────────────────────────

  Future<http.Response> _postWithLegacyFallback({
    required String primaryPath,
    required String legacyPath,
    required Map<String, dynamic> payload,
  }) async {
    final primaryUri = Uri.parse(_buildUrl(primaryPath));
    final primaryResponse = await _httpClient
        .post(
          primaryUri,
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));

    if (primaryResponse.statusCode >= 200 && primaryResponse.statusCode < 300) {
      return primaryResponse;
    }

    final fallbackStatuses = {404, 405, 501};
    if (!fallbackStatuses.contains(primaryResponse.statusCode)) {
      throw InvitationServiceException(
        'Service invitation indisponible',
        statusCode: primaryResponse.statusCode,
      );
    }

    final legacyUri = Uri.parse(_buildUrl(legacyPath));
    final legacyResponse = await _httpClient
        .post(
          legacyUri,
          headers: await _headers(),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));

    if (legacyResponse.statusCode < 200 || legacyResponse.statusCode >= 300) {
      throw InvitationServiceException(
        'Impossible de traiter la requête d’invitation',
        statusCode: legacyResponse.statusCode,
      );
    }

    return legacyResponse;
  }

  String _buildUrl(String path) {
    final base = baseApiUrl.endsWith('/') ? baseApiUrl.substring(0, baseApiUrl.length - 1) : baseApiUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$base$normalizedPath';
  }
}
