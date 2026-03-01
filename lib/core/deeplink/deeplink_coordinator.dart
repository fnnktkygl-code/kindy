import 'dart:async';

import 'package:app_links/app_links.dart';

class DeeplinkCoordinator {
  DeeplinkCoordinator({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // In-session replay guard: track URIs already dispatched this session.
  final Set<String> _dispatchedUris = {};

  // Matches UUID v4 (e.g. 550e8400-e29b-41d4-a716-446655440000)
  // and Supabase token format (alphanumeric, 16–128 chars).
  static final _tokenPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$|^[A-Za-z0-9_\-]{16,128}$',
  );

  bool isInviteLink(Uri uri) {
    // Custom scheme: pigio://invite/<token>
    if (uri.scheme.toLowerCase() == 'pigio' &&
        uri.host.toLowerCase() == 'invite') {
      final token = uri.pathSegments.firstOrNull ?? '';
      return _tokenPattern.hasMatch(token);
    }

    // HTTPS: must be a trusted host AND the first path segment must be exactly "invite".
    // Using pathSegments.first prevents substring matches like /user-invitedto/...
    // or query-param tricks like ?foo=invite.
    const trustedHosts = {'pigio.app'};
    if (!trustedHosts.contains(uri.host.toLowerCase())) return false;
    if (uri.pathSegments.length < 2) return false;
    if (uri.pathSegments.first.toLowerCase() != 'invite') return false;
    // Validate the token segment format
    final token = uri.pathSegments[1];
    return _tokenPattern.hasMatch(token);
  }

  Future<void> init({
    required bool Function() isMounted,
    required Future<void> Function(Uri uri) onInviteUri,
  }) async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null && isMounted() && isInviteLink(initial)) {
        await _dispatch(initial, onInviteUri);
      }

      _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
        if (!isMounted() || !isInviteLink(uri)) return;
        await _dispatch(uri, onInviteUri);
      });
    } catch (_) {
      // Keep app flow resilient if deep-link stream cannot be initialized.
    }
  }

  /// Dispatches a URI at most once per app session to prevent replay attacks.
  Future<void> _dispatch(Uri uri, Future<void> Function(Uri) onInviteUri) async {
    final key = uri.toString();
    if (_dispatchedUris.contains(key)) return;
    _dispatchedUris.add(key);
    await onInviteUri(uri);
  }

  Future<void> dispose() async {
    await _linkSubscription?.cancel();
  }
}
