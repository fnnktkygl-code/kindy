import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'auth_screen.dart';
import '../../app_shell/main_shell.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;

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
                "Prêt à ne plus jamais rater un cadeau parfait ?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: pt.ink,
                ),
              ),
              const SizedBox(height: 48),
              
              // Apple Sign In — iOS only
              if (Platform.isIOS) ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await Supabase.instance.client.auth.signInWithOAuth(
                        OAuthProvider.apple,
                        redirectTo: 'com.pigio.app://auth/callback',
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur: ${e.toString()}')),
                      );
                    }
                  },
                  icon: const Icon(Icons.apple, color: Colors.white),
                  label: const Text('Continuer avec Apple'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Google Sign In — not yet configured for Android
              if (!Platform.isAndroid) ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      await Supabase.instance.client.auth.signInWithOAuth(
                        OAuthProvider.google,
                        redirectTo: 'com.pigio.app://auth/callback',
                        queryParams: {
                          'prompt': 'select_account',
                        },
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur: ${e.toString()}')),
                      );
                    }
                  },
                  icon: const Icon(Icons.g_mobiledata, color: Colors.black, size: 32),
                  label: const Text('Continuer avec Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Email Sign In
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                },
                icon: const Icon(Icons.email_outlined),
                label: const Text('Continuer avec l\'email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pt.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),

              // Guest mode
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false,
                  );
                },
                child: Text(
                  'Continuer sans compte',
                  style: TextStyle(
                    color: pt.ink.withValues(alpha: 0.5),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const Spacer(),
              
              // Terms
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://pigio.app/privacy/')),
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
}
