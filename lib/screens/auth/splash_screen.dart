import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/auth_service.dart';
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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _checkAuth();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    // Wait for state to load
    final state = context.read<PigioAppState>();
    await state.ready.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );

    // Brief splash
    await Future.delayed(const Duration(milliseconds: 100));

    final session = Supabase.instance.client.auth.currentSession;
    await state.reconcileAuthenticatedUser(session?.user.id);

    if (!mounted) return;

    // Verify the session is still valid (not just non-null but also not expired).
    bool hasValidSession = false;
    if (session != null) {
      final expiresAt = session.expiresAt;
      final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (expiresAt != null && expiresAt <= nowEpoch) {
        // Token expired — attempt refresh
        try {
          await Supabase.instance.client.auth.refreshSession();
          hasValidSession =
              Supabase.instance.client.auth.currentSession != null;
        } catch (_) {
          hasValidSession = false;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Session expirée, veuillez vous reconnecter.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        hasValidSession = true;
      }
    }

    if (!mounted) return;

    if (hasValidSession) {
      if (state.needsOnboarding) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingShell()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } else {
      // No valid session — try auto biometric sign-in if credentials exist
      await _tryAutoBiometric(state);
    }
  }

  Future<void> _tryAutoBiometric(PigioAppState state) async {
    try {
      final auth = AuthService();
      final hasCreds = await auth.hasBiometricCredentials();
      if (!hasCreds || !mounted) {
        _goToWelcome();
        return;
      }

      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
      if (!canCheck || !mounted) {
        _goToWelcome();
        return;
      }

      // Updated to avoid 'options' if it's causing build issues in this environment
      final ok = await localAuth.authenticate(
        localizedReason: 'Connectez-vous avec votre empreinte ou Face ID',
      );
      if (!ok || !mounted) {
        _goToWelcome();
        return;
      }

      HapticFeedback.lightImpact();
      await auth.signInWithBiometricToken();
      if (!mounted) return;

      final session = auth.currentSession;
      await state.reconcileAuthenticatedUser(session?.user.id);

      if (!mounted) return;
      final Widget next = state.needsOnboarding
          ? const OnboardingShell()
          : const MainShell();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    } catch (_) {
      if (mounted) _goToWelcome();
    }
  }

  void _goToWelcome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthWelcomeScreen()),
    );
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
            const SizedBox(height: 32),
            // Pulsing loading indicator
            FadeTransition(
              opacity: _pulseCtrl.drive(
                Tween(begin: 0.3, end: 1.0),
              ),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    pt.primary.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
