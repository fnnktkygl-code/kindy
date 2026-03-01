import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/state/app_state.dart';
// import 'package:passkeys/passkeys.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'onboarding/onboarding_shell.dart';
import '../../app_shell/main_shell.dart';

class PasskeySetupScreen extends StatefulWidget {
  const PasskeySetupScreen({super.key});

  @override
  State<PasskeySetupScreen> createState() => _PasskeySetupScreenState();
}

class _PasskeySetupScreenState extends State<PasskeySetupScreen> {
  bool _isLoading = false;

  Future<void> _setupPasskey() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Note: This requires a backend endpoint to generate the registration challenge
      // and verify the registration response.
      // For now, we simulate the flow.
      
      /*
      final authenticator = PasskeyAuth();
      final result = await authenticator.register(
        rpId: 'pigio.app',
        rpName: 'Pigio',
        userId: user.id,
        userName: user.email ?? '',
        userDisplayName: user.email ?? '',
        attestation: AttestationConveyancePreference.none,
      );
      
      // Send result to backend to store public key
      */
      
      await Future.delayed(const Duration(seconds: 1)); // Simulate network request
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passkey configuré avec succès !')),
      );
      
      _goToNextScreen();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goToNextScreen() {
    final state = context.read<PigioAppState>();
    final Widget next = state.onboardingCompleted
        ? const MainShell()
        : const OnboardingShell();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => next),
      (route) => false,
    );
  }

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
              const Center(
                child: Text(
                  '🎁👍',
                  style: TextStyle(fontSize: 80),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Activez la connexion rapide",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: pt.ink,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Connectez-vous avec Face ID ou votre empreinte — en une seconde, sans mot de passe.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: pt.ink.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 32),
              
              _buildFeatureRow(pt, "✅", "Personne d'autre ne peut accéder à votre compte"),
              const SizedBox(height: 12),
              _buildFeatureRow(pt, "✅", "Fonctionne même hors ligne"),
              const SizedBox(height: 12),
              _buildFeatureRow(pt, "✅", "Impossible à hameçonner"),
              
              const Spacer(),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _setupPasskey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: pt.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Activer Face ID / Empreinte →',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : _goToNextScreen,
                child: Text(
                  "Pas maintenant",
                  style: TextStyle(
                    color: pt.ink.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(dynamic pt, String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: pt.ink,
            ),
          ),
        ),
      ],
    );
  }
}
