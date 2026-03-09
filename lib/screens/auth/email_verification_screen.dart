import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'auth_screen.dart';

/// Shown after sign-up when Supabase requires email confirmation.
/// Gives the user a friendly "check your inbox" prompt.
class EmailVerificationScreen extends StatelessWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;

    return Scaffold(
      backgroundColor: pt.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: pt.ink),
      ),
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
                  '📬',
                  style: TextStyle(fontSize: 80),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Vérifiez votre boîte mail",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: pt.ink,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Nous avons envoyé un email de confirmation à :",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: pt.ink.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: pt.primary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pt.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _tipRow(pt, '1.', 'Ouvrez votre boîte mail'),
                    const SizedBox(height: 8),
                    _tipRow(pt, '2.', 'Cliquez sur le lien de confirmation'),
                    const SizedBox(height: 8),
                    _tipRow(pt, '3.', 'Revenez ici pour vous connecter'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Pensez aussi à vérifier vos spams.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: pt.ink.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => AuthScreen(
                        mode: AuthScreenMode.signIn,
                        initialEmail: email,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: pt.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Se connecter',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Retour',
                  style: TextStyle(
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

  Widget _tipRow(dynamic pt, String number, String text) {
    return Row(
      children: [
        Text(
          number,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: pt.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, color: pt.ink),
          ),
        ),
      ],
    );
  }
}
