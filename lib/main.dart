import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/bootstrap/app_bootstrap.dart';
import 'package:kindy/core/state/app_state.dart';
import 'screens/auth/splash_screen.dart';

void main() async {
  await bootstrapApp();

  runApp(
    ChangeNotifierProvider(
      create: (context) => PigioAppState(),
      child: const PigioApp(),
    ),
  );
}

class PigioApp extends StatelessWidget {
  const PigioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PigioAppState>(
      builder: (context, state, child) {
        final pt = state.currentTheme;

        return MaterialApp(
          title: 'Kindy',
          theme: ThemeData(
            colorScheme: pt.isDark
                ? ColorScheme.dark(
                    primary: pt.primary,
                    surface: pt.card,
                    onSurface: pt.ink,
                  )
                : ColorScheme.light(
                    primary: pt.primary,
                    surface: pt.card,
                    onSurface: pt.ink,
                  ),
            useMaterial3: true,
            scaffoldBackgroundColor: pt.scaffold,
            textTheme: GoogleFonts.nunitoTextTheme().apply(
              bodyColor: pt.ink,
              displayColor: pt.ink,
            ),
            drawerTheme: DrawerThemeData(backgroundColor: pt.navBar),
            dialogTheme: DialogThemeData(backgroundColor: pt.card),
            bottomSheetTheme: BottomSheetThemeData(backgroundColor: pt.sheet),
            dividerTheme: DividerThemeData(color: pt.divider),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: pt.isDark ? pt.surface : pt.ink,
              contentTextStyle: TextStyle(
                color: pt.isDark ? pt.ink : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              actionTextColor: pt.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          home: const SplashScreen(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return _GlobalWizzShake(
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}

class _GlobalWizzShake extends StatefulWidget {
  final Widget child;

  const _GlobalWizzShake({required this.child});

  @override
  State<_GlobalWizzShake> createState() => _GlobalWizzShakeState();
}

class _GlobalWizzShakeState extends State<_GlobalWizzShake>
    with TickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final AnimationController _flashCtrl;
  late final Animation<double> _flashOpacity;

  int _lastWizzNonce = 0;
  double _shakeAmplitude = 16;
  double _shakeVerticalFactor = 0.35;
  double _shakeCycles = 9;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _flashOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.52), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 0.52, end: 0.0), weight: 55),
    ]).animate(CurvedAnimation(parent: _flashCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  void _playWizzShake(WizzEffectMode mode) {
    if (!mounted) return;
    if (mode == WizzEffectMode.phase2) {
      _shakeAmplitude = 62;
      _shakeVerticalFactor = 0.85;
      _shakeCycles = 24;
      _shakeCtrl.duration = const Duration(milliseconds: 1500);
    } else {
      _shakeAmplitude = 36;
      _shakeVerticalFactor = 0.62;
      _shakeCycles = 16;
      _shakeCtrl.duration = const Duration(milliseconds: 1050);
    }
    _flashCtrl.forward(from: 0);
    _shakeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PigioAppState>();
    final wizzNonce = state.globalWizzNonce;
    if (wizzNonce != _lastWizzNonce) {
      _lastWizzNonce = wizzNonce;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playWizzShake(state.wizzEffectMode);
      });
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_shakeCtrl, _flashCtrl]),
      builder: (context, child) {
        final shakeProgress = _shakeCtrl.value;
        final envelope = (1.0 - shakeProgress).clamp(0.0, 1.0);
        final waveX = math.sin(shakeProgress * math.pi * 2 * _shakeCycles);
        final waveY = math.sin(shakeProgress * math.pi * 2 * (_shakeCycles + 1.7));
        final jitterX = math.sin(shakeProgress * math.pi * 2 * (_shakeCycles * 3.3));
        final jitterY = math.sin(shakeProgress * math.pi * 2 * (_shakeCycles * 2.7 + 1.0));
        final shakeX = (waveX + jitterX * 0.42) * _shakeAmplitude * envelope;
        final shakeY = (waveY + jitterY * 0.34) * _shakeAmplitude * _shakeVerticalFactor * envelope;
        final shakeRotate = (waveX + jitterX * 0.28) * 0.072 * envelope;

        return Transform.translate(
          offset: Offset(shakeX, shakeY),
          child: Transform.rotate(
            angle: shakeRotate,
          child: Stack(
            children: [
              child!,
              IgnorePointer(
                child: Opacity(
                  opacity: _flashOpacity.value,
                  child: Container(
                    color: Colors.orangeAccent.withValues(alpha: 0.36),
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
