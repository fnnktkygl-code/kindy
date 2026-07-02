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

  bool isHandledLink(Uri uri) {
    if (uri.scheme.toLowerCase() == 'pigio') {
      final host = uri.host.toLowerCase();
      
      // pigio://invite?token=TOKEN
      if (host == 'invite') {
        final token = uri.queryParameters['token'] ??
            uri.queryParameters['tokenId'] ??
            (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '');
        return _tokenPattern.hasMatch(token);
      }
      
      // pigio://event?id=XXX
      if (host == 'event') {
        return uri.queryParameters.containsKey('id');
      }

      // pigio://contact?id=XXX
      if (host == 'contact') {
        return uri.queryParameters.containsKey('id');
      }
    }

    // Accept HTTPS links from trusted hosts.
    final host = uri.host.toLowerCase();
    const pigioHost = 'pigio.app';
    const pigioWwwHost = 'www.pigio.app';
    const supabaseHost = 'vcnelfgziucsyukahhey.supabase.co';
    if (host != pigioHost && host != pigioWwwHost && host != supabaseHost) return false;

    // Supabase invite-open edge function URL
    if (host == supabaseHost) {
      final path = uri.path.toLowerCase();
      if (!path.startsWith('/functions/v1/invite-open') && !path.startsWith('/invite')) return false;
      final token = uri.queryParameters['token'] ?? uri.queryParameters['tokenId'] ?? '';
      return _tokenPattern.hasMatch(token);
    }

    // pigio.app: first path segment must be "invite" or "join"
    final firstSegment = uri.pathSegments.isNotEmpty
        ? uri.pathSegments.first.toLowerCase()
        : '';
    if (firstSegment != 'invite' && firstSegment != 'join') return false;
    // Token can be in query params or as the second path segment
    final token = uri.queryParameters['token'] ??
        (uri.pathSegments.length >= 2 ? uri.pathSegments[1] : '');
    return _tokenPattern.hasMatch(token);
  }

  Future<void> init({
    required bool Function() isMounted,
    required Future<void> Function(Uri uri) onHandledUri,
  }) async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null && isMounted() && isHandledLink(initial)) {
        await _dispatch(initial, onHandledUri);
      }

      _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
        if (!isMounted() || !isHandledLink(uri)) return;
        await _dispatch(uri, onHandledUri);
      });
    } catch (_) {
      // Keep app flow resilient if deep-link stream cannot be initialized.
    }
  }

  /// Dispatches a URI at most once per app session to prevent replay attacks.
  Future<void> _dispatch(Uri uri, Future<void> Function(Uri) onHandledUri) async {
    final key = uri.toString();
    if (_dispatchedUris.contains(key)) return;
    _dispatchedUris.add(key);
    await onHandledUri(uri);
  }

  Future<void> dispose() async {
    await _linkSubscription?.cancel();
  }
}
