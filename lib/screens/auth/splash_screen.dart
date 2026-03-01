import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app_shell/main_shell.dart';
import 'auth_welcome_screen.dart';
import 'onboarding/onboarding_shell.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/state/app_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Wait for state to load
    final state = context.read<PigioAppState>();
    await state.ready;
    
    // Brief splash
    await Future.delayed(const Duration(milliseconds: 400));

    final session = Supabase.instance.client.auth.currentSession;
    
    if (!mounted) return;

    if (session != null) {
      if (!state.onboardingCompleted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingShell()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWelcomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;
    return Scaffold(
      backgroundColor: pt.scaffold,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'icon/app_icon.png',
              width: 110,
              height: 110,
            ),
            const SizedBox(height: 24),
            Text(
              'Pigio',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: pt.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
