import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'auth_screen.dart';
import '../../shared/auth_navigator.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthWelcomeScreen extends StatefulWidget {
  const AuthWelcomeScreen({super.key});

  @override
  State<AuthWelcomeScreen> createState() => _AuthWelcomeScreenState();
}

class _AuthWelcomeScreenState extends State<AuthWelcomeScreen> {
  StreamSubscription<AuthState>? _authSub;
  bool _oauthLoading = false;
  String? _lastEmail;

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        AuthNavigator.handleSignIn(
          context,
          data.session!,
          onComplete: () { if (mounted) setState(() => _oauthLoading = false); },
        );
      }
    });
  }

  Future<void> _loadLastEmail() async {
    final email = await AuthNavigator.loadLastEmail();
    if (mounted && email != null && email.isNotEmpty) {
      setState(() => _lastEmail = email);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  // _handleOAuthSignIn is now handled by AuthNavigator.handleSignIn in the auth listener above.

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;
    final isAuthenticated = Supabase.instance.client.auth.currentUser != null;

    return Scaffold(
      backgroundColor: pt.scaffold,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Mascot
              const Center(
                child: Image(
                  image: AssetImage('icon/app_icon.png'),
                  width: 110,
                  height: 110,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Prends soin de tes proches, simplement.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: pt.ink,
                ),
              ),
              const SizedBox(height: 48),

              // Show last email for returning users
              if (_lastEmail != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: pt.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 18, color: pt.ink.withValues(alpha: 0.6)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Dernier compte: $_lastEmail',
                          style: TextStyle(fontSize: 13, color: pt.ink.withValues(alpha: 0.6)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Loading indicator for OAuth
              if (_oauthLoading) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
              ] else ...[
                // Apple Sign In — iOS only
                if (Platform.isIOS) ...[
                  _SocialButton(
                    onPressed: () => _signInWithOAuth(context, OAuthProvider.apple),
                    icon: Icons.apple,
                    label: 'Continuer avec Apple',
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Google Sign In — all platforms
                _SocialButton(
                  onPressed: () => _signInWithOAuth(context, OAuthProvider.google),
                  icon: Icons.g_mobiledata,
                  iconSize: 32,
                  label: 'Continuer avec Google',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  borderColor: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
              ],
              
              // Email — single entry point (defaults to sign-up)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthScreen(mode: AuthScreenMode.signUp)),
                  );
                },
                icon: const Icon(Icons.email_outlined),
                label: const Text('Continuer avec Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pt.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sign-in link for returning users
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthScreen(mode: AuthScreenMode.signIn)),
                  );
                },
                child: Text(
                  'Déjà un compte ? Se connecter',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: pt.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              

              const Spacer(),
              
              // Terms
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://fnnktkygl-code.github.io/pigio-app/privacy/')),
                child: Text.rich(
                  TextSpan(
                    text: "En continuant, vous acceptez nos ",
                    children: [
                      TextSpan(
                        text: "CGU",
                        style: TextStyle(decoration: TextDecoration.underline, color: pt.primary),
                      ),
                      const TextSpan(text: " et notre "),
                      TextSpan(
                        text: "Politique de confidentialité",
                        style: TextStyle(decoration: TextDecoration.underline, color: pt.primary),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: pt.ink.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithOAuth(BuildContext context, OAuthProvider provider) async {
    setState(() => _oauthLoading = true);
    await AuthNavigator.signInWithOAuth(context, provider);
    // If OAuth fails (error snackbar shown by AuthNavigator), reset loading.
    // On success, the auth listener above handles navigation.
    if (mounted && _oauthLoading) {
      // Still loading means browser opened but user hasn't returned yet — keep spinner.
    }
  }
}

/// Consistent social sign-in button widget.
class _SocialButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final double iconSize;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  const _SocialButton({
    required this.onPressed,
    required this.icon,
    this.iconSize = 24,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: foregroundColor, size: iconSize),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: borderColor != null
              ? BorderSide(color: borderColor!)
              : BorderSide.none,
        ),
      ),
    );
  }
}
