import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../shared/auth_navigator.dart';

import 'onboarding/onboarding_shell.dart';
import 'email_verification_screen.dart';
import '../../app_shell/main_shell.dart';

enum AuthScreenMode { signUp, signIn }

class AuthScreen extends StatefulWidget {
  final AuthScreenMode mode;
  final String? initialEmail;

  const AuthScreen({super.key, required this.mode, this.initialEmail});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();
  final _localAuth = LocalAuthentication();
  StreamSubscription<AuthState>? _authSub;

  late final AnimationController _fadeCtrl;
  late final AnimationController _handCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _handAnim;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _enableBiometricForNextLogins = false;
  bool _biometricAvailable = false;
  bool _hasBiometricCredentials = false;

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  bool get _isSignIn => widget.mode == AuthScreenMode.signIn;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();

    _handCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _handAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.2), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.2, end: -0.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _handCtrl, curve: Curves.easeInOut));
    _handCtrl.repeat();

    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        AuthNavigator.handleSignIn(context, data.session!);
      }
    });

    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    } else {
      _loadLastEmail();
    }
    _initBiometricState();
  }

  Future<void> _loadLastEmail() async {
    final last = await AuthNavigator.loadLastEmail();
    if (last != null && last.isNotEmpty && _emailController.text.isEmpty) {
      _emailController.text = last;
    }
  }

  Future<void> _saveLastEmail(String email) async {
    await AuthNavigator.saveLastEmail(email);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _handCtrl.dispose();
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    await AuthNavigator.signInWithOAuth(context, provider);
  }

  Future<void> _initBiometricState() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final supported = await _localAuth.isDeviceSupported();
    final hasStored = await AuthService().hasBiometricCredentials();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = canCheck && supported;
      _hasBiometricCredentials = hasStored;
      _enableBiometricForNextLogins = hasStored;
    });
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      _showError('Veuillez entrer un email valide');
      return;
    }

    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    final metComplexity =
        password.length >= 10 && hasUpper && hasLower && hasDigit && hasSpecial;

    if (!metComplexity) {
      _showError(
          'Le mot de passe ne respecte pas les critères de sécurité (10+ caract., majuscule, minuscule, chiffre et symbole).');
      return;
    }

    if (!_isSignIn && _confirmPasswordController.text != password) {
      _showError('Les mots de passe ne correspondent pas');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final auth = AuthService();
      if (_isSignIn) {
        await auth.signInWithPassword(email, password);
      } else {
        final signUpResponse =
        await auth.signUpWithEmailPassword(email, password);

        final sessionAfterSignUp = signUpResponse.session;
        if (sessionAfterSignUp == null) {
          if (!mounted) return;
          HapticFeedback.mediumImpact();
          _showSuccess('Compte créé ! Vérifiez votre email pour confirmer.');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(email: email),
            ),
          );
          return;
        }

        try {
          await auth.signInWithPassword(email, password);
        } on AuthException catch (e) {
          if (_isAlreadyRegisteredError(e)) {
            if (!mounted) return;
            _showError(
                'Ce compte existe déjà. Connectez-vous ou utilisez le code email.');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AuthScreen(
                  mode: AuthScreenMode.signIn,
                  initialEmail: email,
                ),
              ),
            );
            return;
          }
          rethrow;
        }
      }

      await _saveLastEmail(email);

      if (_enableBiometricForNextLogins && _biometricAvailable) {
        await auth.saveBiometricCredentials(email, password);
      } else if (!_enableBiometricForNextLogins) {
        await auth.clearBiometricCredentials();
      }

      if (!mounted) return;
      final state = context.read<PigioAppState>();
      final session = AuthService().currentSession;
      await state.reconcileAuthenticatedUser(session?.user.id);

      if (!mounted) return;
      final Widget next =
      state.needsOnboarding ? const OnboardingShell() : const MainShell();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => next),
            (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError(_authErrorMessage(e, isSignUp: !_isSignIn));
    } catch (e) {
      if (!mounted) return;
      _showError(
        _isSignIn
            ? 'Connexion impossible. Vérifiez vos identifiants.'
            : 'Création du compte impossible. Réessayez.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _authErrorMessage(AuthException e, {required bool isSignUp}) {
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit')) {
      return 'Limite d\'envoi atteinte. Réessayez dans quelques minutes.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email non confirmé. Vérifiez votre boîte mail.';
    }
    if (isSignUp && _isAlreadyRegisteredError(e)) {
      return 'Ce compte existe déjà. Connectez-vous.';
    }
    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  bool _isAlreadyRegisteredError(AuthException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('already') ||
        msg.contains('registered') ||
        msg.contains('exists') ||
        msg.contains('already registered');
  }

  Future<void> _forgotPassword() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      _showError('Entrez votre email pour réinitialiser le mot de passe.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().resetPasswordForEmail(email);
      if (!mounted) return;
      _showSuccess('Lien de réinitialisation envoyé à votre email.');
    } on AuthException catch (e) {
      if (!mounted) return;
      _showError('Impossible d\'envoyer le lien. Réessayez plus tard.');
    } catch (e) {
      if (!mounted) return;
      _showError('Impossible d\'envoyer le lien. Réessayez plus tard.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithBiometrics() async {
    if (!_biometricAvailable || !_hasBiometricCredentials) return;
    setState(() => _isLoading = true);
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Connectez-vous avec votre empreinte ou Face ID',
        biometricOnly: true,
      );
      if (!ok) return;

      final auth = AuthService();
      await auth.signInWithBiometricToken();
      if (!mounted) return;

      final state = context.read<PigioAppState>();
      final session = auth.currentSession;
      await state.reconcileAuthenticatedUser(session?.user.id);

      if (!mounted) return;
      final Widget next =
      state.needsOnboarding ? const OnboardingShell() : const MainShell();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => next),
            (route) => false,
      );
    } on AuthException catch (e) {
      await AuthService().clearBiometricCredentials();
      if (!mounted) return;
      setState(() => _hasBiometricCredentials = false);
      final msg = e.message.toLowerCase();
      _showError(
        msg.contains('expired') || msg.contains('invalid')
            ? 'Session biométrique expirée. Reconnectez-vous avec vos identifiants.'
            : 'Connexion biométrique échouée : ${e.message}',
      );
    } catch (e) {
      if (!mounted) return;
      _showError(
          'Connexion biométrique impossible : ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration({
    required dynamic pt,
    required String hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: pt.ink.withValues(alpha: 0.35),
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon != null
          ? Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Icon(prefixIcon, size: 20, color: pt.ink.withValues(alpha: 0.4)),
      )
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: pt.isDark
          ? Colors.white.withValues(alpha: 0.06)
          : pt.ink.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
        BorderSide(color: pt.primary.withValues(alpha: 0.6), width: 1.5),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: pt.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: pt.scaffold,
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Unified card: logo + title + subtitle ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 32, horizontal: 24),
                            decoration: BoxDecoration(
                              color: pt.isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : pt.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: pt.isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : pt.primary.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Logo row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: pt.primary
                                                .withValues(alpha: 0.1),
                                            blurRadius: 15,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius:
                                        BorderRadius.circular(14),
                                        child: Image.asset(
                                          'icon/app_icon.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Pigio',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: pt.primary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // Title
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                          text: _isSignIn
                                              ? 'Bon retour '
                                              : 'Créer un compte'),
                                      if (_isSignIn)
                                        WidgetSpan(
                                          alignment:
                                          PlaceholderAlignment.middle,
                                          child: AnimatedBuilder(
                                            animation: _handAnim,
                                            builder: (context, child) {
                                              return Transform.rotate(
                                                angle: _handAnim.value,
                                                origin: const Offset(8, 8),
                                                child: const Text('👋',
                                                    style: TextStyle(
                                                        fontSize: 28)),
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    color: pt.ink,
                                    height: 1.15,
                                    letterSpacing: -0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 8),

                                // Subtitle
                                Text(
                                  _isSignIn
                                      ? 'Connectez-vous pour retrouver vos proches.'
                                      : 'Rejoignez Pigio en quelques secondes.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: pt.ink.withValues(alpha: 0.5),
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 36),

                          // ── OAuth buttons ──
                          if (Platform.isIOS) ...[
                            _OAuthButton(
                              onPressed: _isLoading
                                  ? null
                                  : () =>
                                  _signInWithOAuth(OAuthProvider.apple),
                              icon: Icons.apple,
                              label: 'Continuer avec Apple',
                              backgroundColor:
                              pt.isDark ? Colors.white : Colors.black,
                              foregroundColor:
                              pt.isDark ? Colors.black : Colors.white,
                            ),
                            const SizedBox(height: 12),
                          ],
                          _OAuthButton(
                            onPressed: _isLoading
                                ? null
                                : () =>
                                _signInWithOAuth(OAuthProvider.google),
                            iconWidget: Image.asset('icon/google.png',
                                width: 20, height: 20),
                            label: 'Continuer avec Google',
                            backgroundColor: pt.isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white,
                            foregroundColor: pt.ink,
                            borderColor: pt.ink.withValues(alpha: 0.12),
                          ),

                          const SizedBox(height: 28),

                          // ── Divider ──
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                    height: 1,
                                    color: pt.ink.withValues(alpha: 0.08)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                child: Text(
                                  'ou',
                                  style: TextStyle(
                                    color: pt.ink.withValues(alpha: 0.3),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                    height: 1,
                                    color: pt.ink.withValues(alpha: 0.08)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // ── Email field ──
                          TextField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => FocusScope.of(context)
                                .requestFocus(_passwordFocusNode),
                            decoration: _inputDecoration(
                              pt: pt,
                              hint: 'Email',
                              prefixIcon: Icons.mail_outline_rounded,
                            ),
                            style: TextStyle(
                              color: pt.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── Password field ──
                          TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: _obscurePassword,
                            textInputAction: _isSignIn
                                ? TextInputAction.done
                                : TextInputAction.next,
                            onSubmitted: (_) {
                              if (_isSignIn) {
                                _submit();
                              } else {
                                FocusScope.of(context)
                                    .requestFocus(_confirmFocusNode);
                              }
                            },
                            decoration: _inputDecoration(
                              pt: pt,
                              hint: 'Mot de passe',
                              prefixIcon: Icons.lock_outline_rounded,
                              suffixIcon: _VisibilityToggle(
                                obscured: _obscurePassword,
                                color: pt.ink.withValues(alpha: 0.4),
                                onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            style: TextStyle(
                              color: pt.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          // ── Confirm password (sign up) ──
                          if (!_isSignIn) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmPasswordController,
                              focusNode: _confirmFocusNode,
                              obscureText: _obscureConfirmPassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: _inputDecoration(
                                pt: pt,
                                hint: 'Confirmer le mot de passe',
                                prefixIcon: Icons.lock_outline_rounded,
                                suffixIcon: _VisibilityToggle(
                                  obscured: _obscureConfirmPassword,
                                  color: pt.ink.withValues(alpha: 0.4),
                                  onPressed: () => setState(() =>
                                  _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                                ),
                              ),
                              style: TextStyle(
                                color: pt.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],

                          // ── Password strength (sign up) ──
                          if (!_isSignIn) ...[
                            const SizedBox(height: 16),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _passwordController,
                              builder: (_, value, __) {
                                return _PasswordStrengthIndicator(
                                  password: value.text,
                                  theme: pt,
                                );
                              },
                            ),
                          ],

                          // ── Biometric toggle ──
                          if (_biometricAvailable) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  Icons.fingerprint,
                                  size: 20,
                                  color: _enableBiometricForNextLogins
                                      ? pt.primary
                                      : pt.ink.withValues(alpha: 0.3),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Connexion biométrique',
                                    style: TextStyle(
                                      color: pt.ink,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 28,
                                  child: Switch.adaptive(
                                    value: _enableBiometricForNextLogins,
                                    onChanged: !_isLoading
                                        ? (v) => setState(() =>
                                    _enableBiometricForNextLogins = v)
                                        : null,
                                    activeColor: pt.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // ── Forgot password (sign in) ──
                          if (_isSignIn) ...[
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: _isLoading ? null : _forgotPassword,
                                child: Text(
                                  'Mot de passe oublié ?',
                                  style: TextStyle(
                                    color: pt.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // ── Primary CTA ──
                          _PrimaryButton(
                            onPressed: _isLoading ? null : _submit,
                            isLoading: _isLoading,
                            label: _isSignIn
                                ? 'Se connecter'
                                : 'Créer mon compte',
                            color: pt.primary,
                          ),

                          // ── Biometric sign-in button ──
                          if (_isSignIn &&
                              _biometricAvailable &&
                              _hasBiometricCredentials) ...[
                            const SizedBox(height: 12),
                            _SecondaryButton(
                              onPressed:
                              _isLoading ? null : _signInWithBiometrics,
                              icon: Icons.fingerprint,
                              label: 'Empreinte / Face ID',
                              pt: pt,
                            ),
                          ],

                          const SizedBox(height: 28),

                          // ── Toggle sign in / sign up ──
                          Center(
                            child: GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () {
                                final nextMode = _isSignIn
                                    ? AuthScreenMode.signUp
                                    : AuthScreenMode.signIn;
                                Navigator.of(context).pushReplacement(
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation,
                                        secondaryAnimation) =>
                                        AuthScreen(
                                          mode: nextMode,
                                          initialEmail:
                                          _emailController.text.trim(),
                                        ),
                                    transitionDuration: Duration.zero,
                                    reverseTransitionDuration:
                                    Duration.zero,
                                  ),
                                );
                              },
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: pt.ink.withValues(alpha: 0.5),
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _isSignIn
                                          ? 'Pas de compte ? '
                                          : 'Déjà un compte ? ',
                                    ),
                                    TextSpan(
                                      text: _isSignIn
                                          ? 'Créer un compte'
                                          : 'Se connecter',
                                      style: TextStyle(
                                        color: pt.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────

class _VisibilityToggle extends StatelessWidget {
  final bool obscured;
  final Color color;
  final VoidCallback onPressed;

  const _VisibilityToggle({
    required this.obscured,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          obscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          key: ValueKey(obscured),
          size: 20,
          color: color,
        ),
      ),
      splashRadius: 20,
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? iconWidget;
  final double iconSize;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  const _OAuthButton({
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.iconSize = 22,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: borderColor != null
                ? BorderSide(color: borderColor!)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconWidget != null)
              iconWidget!
            else if (icon != null)
              Icon(icon, size: iconSize),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;
  final Color color;

  const _PrimaryButton({
    required this.onPressed,
    required this.isLoading,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? const SizedBox(
            key: ValueKey('loader'),
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
              AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Text(
            label,
            key: ValueKey(label),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final dynamic pt;

  const _SecondaryButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.pt,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: pt.ink.withValues(alpha: 0.1)),
          foregroundColor: pt.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final dynamic theme;

  const _PasswordStrengthIndicator(
      {required this.password, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final hasLength = password.length >= 10;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial =
    RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    final metCount =
        [hasLength, hasUpper, hasLower, hasDigit, hasSpecial]
            .where((b) => b)
            .length;
    final isStrong = metCount == 5;
    final isPassphrase = password.length >= 14 && isStrong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 4,
            child: LinearProgressIndicator(
              value: metCount / 5,
              backgroundColor: theme.ink.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                isStrong
                    ? const Color(0xFF4CAF50)
                    : metCount >= 3
                    ? const Color(0xFFFFA726)
                    : const Color(0xFFEF5350),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isPassphrase)
          _criteriaRow(true, 'Phrase secrète ultra-sécurisée \u{1F512}')
        else ...[
          _criteriaRow(hasLength, '10 caractères minimum'),
          const SizedBox(height: 6),
          _criteriaRow(hasUpper && hasLower && hasDigit && hasSpecial,
              'Majuscule, minuscule, chiffre et symbole'),
          if (isStrong && !isPassphrase) ...[
            const SizedBox(height: 4),
            Text(
              'Astuce : ajoutez des mots pour une phrase encore plus sûre.',
              style: TextStyle(
                fontSize: 11,
                color: theme.ink.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _criteriaRow(bool ok, String label) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok
                ? const Color(0xFF4CAF50).withValues(alpha: 0.12)
                : theme.ink.withValues(alpha: 0.06),
          ),
          child: Center(
            child: Icon(
              ok ? Icons.check_rounded : Icons.circle,
              size: ok ? 13 : 6,
              color: ok
                  ? const Color(0xFF4CAF50)
                  : theme.ink.withValues(alpha: 0.25),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: ok ? theme.ink : theme.ink.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}