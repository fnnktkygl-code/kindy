import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/app_shell/main_shell.dart';
import 'package:pigio_app/screens/auth/onboarding/onboarding_shell.dart';

/// Shared auth navigation helpers — eliminates duplicate code across
/// auth_screen.dart and auth_welcome_screen.dart.
class AuthNavigator {
  AuthNavigator._();

  static const _lastEmailKey = 'pigio_last_email';
  static const _secureStorage = FlutterSecureStorage();

  /// Save the user's email for the welcome screen "returning user" feature.
  static Future<void> saveLastEmail(String email) async {
    await _secureStorage.write(key: _lastEmailKey, value: email);
  }

  /// Load the last used email (nullable).
  static Future<String?> loadLastEmail() async {
    return _secureStorage.read(key: _lastEmailKey);
  }

  /// Handle a successful OAuth / session sign-in:
  /// saves email, reconciles user state, and navigates.
  static Future<void> handleSignIn(
    BuildContext context,
    Session session, {
    VoidCallback? onComplete,
  }) async {
    // Persist email for returning-user display
    final userEmail = session.user.email;
    if (userEmail != null && userEmail.isNotEmpty) {
      await saveLastEmail(userEmail);
    }

    if (!context.mounted) return;
    final state = context.read<PigioAppState>();
    await state.reconcileAuthenticatedUser(session.user.id);

    onComplete?.call();

    if (!context.mounted) return;
    final Widget next = state.needsOnboarding
        ? const OnboardingShell()
        : const MainShell();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => next),
      (route) => false,
    );
  }

  /// Launch OAuth sign-in (Google / Apple) with standard redirect.
  static Future<void> signInWithOAuth(
    BuildContext context,
    OAuthProvider provider,
  ) async {
    HapticFeedback.lightImpact();
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'pigio://auth/callback',
        authScreenLaunchMode: Platform.isAndroid || Platform.isIOS
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault,
        queryParams: provider == OAuthProvider.google
            ? {'prompt': 'select_account'}
            : null,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion impossible. Réessayez.')),
      );
    }
  }
}
