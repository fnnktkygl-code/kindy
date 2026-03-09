import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Structured logger for the Pigio app.
///
/// In debug builds, messages are printed via [debugPrint].
/// In release builds, only warnings and errors are recorded.
enum LogLevel { debug, info, warn, error }

class PigioLogger {
  PigioLogger._();
  static final PigioLogger instance = PigioLogger._();

  /// Minimum level that gets printed / reported.
  LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.warn;

  // ── Public API ──────────────────────────────────────────────────────────

  void debug(String tag, String message) =>
      _log(LogLevel.debug, tag, message);

  void info(String tag, String message) =>
      _log(LogLevel.info, tag, message);

  void warn(String tag, String message, [Object? error]) =>
      _log(LogLevel.warn, tag, message, error);

  void error(String tag, String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.error, tag, message, error, stack);

  // ── Internals ───────────────────────────────────────────────────────────

  void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (level.index < minLevel.index) return;

    final prefix = '[${level.name.toUpperCase()}] [$tag]';
    final line = error != null ? '$prefix $message — $error' : '$prefix $message';

    if (kDebugMode) {
      debugPrint(line);
      if (stack != null) debugPrintStack(stackTrace: stack);
    }

    // In release, route warnings/errors to a crash reporting backend.
    if (!kDebugMode && level.index >= LogLevel.warn.index) {
      _reportToBackend(level, tag, message, error, stack);
    }
  }

  /// Reports errors to the backend via Supabase edge function.
  void _reportToBackend(
    LogLevel level,
    String tag,
    String message,
    Object? error,
    StackTrace? stack,
  ) {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      client.functions.invoke(
        'log-error',
        body: {
          'level': level.name,
          'tag': tag,
          'message': message,
          if (error != null) 'error': error.toString(),
          if (stack != null) 'stack': stack.toString().substring(0, (stack.toString().length).clamp(0, 4000)),
          'userId': ?userId,
        },
      );
      // Fire-and-forget — we don't await to avoid blocking the app.
    } catch (_) {
      // Swallow silently — logging must never crash the app.
    }
  }
}

/// Convenience top-level accessor.
final log = PigioLogger.instance;
