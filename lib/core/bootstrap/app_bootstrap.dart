import 'dart:io';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/analytics_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/pigio_logger.dart';
import '../../services/subscription_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch Flutter framework errors (widget build failures, layout errors, etc.)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    log.error('Flutter', details.exceptionAsString(), details.exception, details.stack);
  };

  // Catch asynchronous errors not handled by Flutter (platform channel failures, etc.)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    log.error('Platform', error.toString(), error, stack);
    return true;
  };

  if (Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  // Injected at build time via --dart-define=SUPABASE_URL=... and
  // --dart-define=SUPABASE_ANON_KEY=... Never hard-code these values.
  String supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  String supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');
  if (supabaseUrl.isEmpty) {
    supabaseUrl = 'https://vcnelfgziucsyukahhey.supabase.co';
  }
  if (supabaseAnonKey.isEmpty) {
    supabaseAnonKey = 'sb_publishable_wzRubrYmP5G_hJFlW8BScg_pNeHzSiQ';
  }

  ConnectivityService.instance.init();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await AnalyticsService.init();

  // Initialize RevenueCat subscription service (anonymous until auth identifies user)
  await SubscriptionService.init();
}
