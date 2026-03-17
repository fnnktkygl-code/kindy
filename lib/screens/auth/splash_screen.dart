import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/auth_service.dart';
import '../../app_shell/main_shell.dart';
import 'auth_screen.dart';
import 'onboarding/onboarding_shell.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/state/app_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  late final AnimationController _textCtrl;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  late final AnimationController _loaderCtrl;
  late final Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();

    // Logo: fade in + subtle scale
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack),
    );

    // Brand text: staggered fade + slide
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    // Loader: delayed fade in
    _loaderCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loaderFade = CurvedAnimation(parent: _loaderCtrl, curve: Curves.easeIn);

    _runEntrySequence();
  }

  Future<void> _runEntrySequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _loaderCtrl.forward();

    _checkAuth();
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _loaderCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final state = context.read<PigioAppState>();
    await state.ready.timeout(
      const Duration(seconds: 8),
      onTimeout: () {},
    );

    await Future.delayed(const Duration(milliseconds: 200));

    final session = Supabase.instance.client.auth.currentSession;
    await state.reconcileAuthenticatedUser(session?.user.id);

    if (!mounted) return;

    bool hasValidSession = false;
    if (session != null) {
      final expiresAt = session.expiresAt;
      final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (expiresAt != null && expiresAt <= nowEpoch) {
        try {
          await Supabase.instance.client.auth.refreshSession();
          hasValidSession =
              Supabase.instance.client.auth.currentSession != null;
        } catch (_) {
          hasValidSession = false;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Session expirée, veuillez vous reconnecter.'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                duration: const Duration(seconds: 3),
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
      final canCheck =
          await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
      if (!canCheck || !mounted) {
        _goToWelcome();
        return;
      }

      final ok = await localAuth.authenticate(
        localizedReason: 'Connectez-vous avec votre empreinte ou Face ID',
        biometricOnly: true,
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
      final Widget next =
      state.needsOnboarding ? const OnboardingShell() : const MainShell();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => next),
      );
    } catch (_) {
      if (mounted) _goToWelcome();
    }
  }

  void _goToWelcome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AuthScreen(mode: AuthScreenMode.signIn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: pt.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: pt.scaffold,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with scale + fade
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: pt.primary.withValues(alpha: 0.12),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'icon/app_icon.png',
                        width: 88,
                        height: 88,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Brand name
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: Text(
                    'Pigio',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: pt.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Minimal loader
              FadeTransition(
                opacity: _loaderFade,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      pt.primary.withValues(alpha: 0.5),
                    ),
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