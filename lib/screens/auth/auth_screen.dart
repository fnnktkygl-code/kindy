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
import 'verify_screen.dart';

enum AuthScreenMode { signUp, signIn }

class AuthScreen extends StatefulWidget {
  final AuthScreenMode mode;
  final String? initialEmail;

  const AuthScreen({super.key, required this.mode, this.initialEmail});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _localAuth = LocalAuthentication();
  StreamSubscription<AuthState>? _authSub;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _enableBiometricForNextLogins = false;
  bool _biometricAvailable = false;
  bool _hasBiometricCredentials = false;

  // RFC 5322-inspired: requires local@domain.tld structure.
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  bool get _isSignIn => widget.mode == AuthScreenMode.signIn;

  @override
  void initState() {
    super.initState();
    // Listen for OAuth redirect callback
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
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // _handleOAuthSignIn is now handled by AuthNavigator.handleSignIn in the auth listener above.

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un email valide')),
      );
      return;
    }

    if (password.length < 10 ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vérifiez les critères du mot de passe ci-dessus.')),
      );
      return;
    }

    if (!_isSignIn && _confirmPasswordController.text != password) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas')),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Compte créé ! Vérifiez votre email pour confirmer.'),
              duration: Duration(seconds: 4),
            ),
          );
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ce compte existe déjà. Connectez-vous ou utilisez le code email.'),
              ),
            );
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

      // Save email for remember-me
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
      final Widget next = state.needsOnboarding
          ? const OnboardingShell()
          : const MainShell();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => next),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authErrorMessage(e, isSignUp: !_isSignIn))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSignIn
                ? 'Connexion impossible. Vérifiez vos identifiants.'
                : 'Création du compte impossible. Réessayez.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _authErrorMessage(AuthException e, {required bool isSignUp}) {
    final msg = e.message.toLowerCase();
    if (msg.contains('rate limit')) {
      return 'Limite d\'envoi d\'emails atteinte côté Supabase. Attendez un peu avant de réessayer.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email non confirmé. Vérifiez votre boîte mail puis reconnectez-vous.';
    }
    if (isSignUp && _isAlreadyRegisteredError(e)) {
      return 'Ce compte existe déjà. Connectez-vous ou utilisez le code email.';
    }
    return e.message;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez votre email pour réinitialiser le mot de passe.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un lien de réinitialisation a été envoyé à votre email.'),
          duration: Duration(seconds: 5),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'envoyer le lien: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      final Widget next = state.needsOnboarding
          ? const OnboardingShell()
          : const MainShell();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => next),
        (route) => false,
      );
    } on AuthException catch (e) {
      // Token expired or invalid — clear stale credentials
      await AuthService().clearBiometricCredentials();
      if (!mounted) return;
      setState(() => _hasBiometricCredentials = false);
      final msg = e.message.toLowerCase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.contains('expired') || msg.contains('invalid')
                ? 'Session biométrique expirée. Reconnectez-vous avec email et mot de passe.'
                : 'Connexion biométrique échouée : ${e.message}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connexion biométrique impossible : ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isSignIn ? "Se connecter" : "Créer un compte",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: pt.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isSignIn
                    ? "Entrez votre email et votre mot de passe."
                    : "Créez votre compte avec email et mot de passe.",
                style: TextStyle(
                  fontSize: 16,
                  color: pt.ink.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "votre@email.com",
                  filled: true,
                  fillColor: pt.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                style: TextStyle(color: pt.ink),
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),
              
              const SizedBox(height: 12),

              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: "Mot de passe",
                  filled: true,
                  fillColor: pt.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  ),
                ),
                style: TextStyle(color: pt.ink),
                onSubmitted: (_) => _submit(),
              ),

              if (!_isSignIn) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: "Confirmer le mot de passe",
                    filled: true,
                    fillColor: pt.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  style: TextStyle(color: pt.ink),
                  onSubmitted: (_) => _submit(),
                ),
              ],

              // Inline password strength indicator (sign-up only)
              if (!_isSignIn) ...[
                const SizedBox(height: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _passwordController,
                  builder: (_, value, __) {
                    final pw = value.text;
                    return _PasswordStrengthIndicator(password: pw, theme: pt);
                  },
                ),
              ],

              const SizedBox(height: 12),

              SwitchListTile.adaptive(
                value: _enableBiometricForNextLogins,
                onChanged: _biometricAvailable && !_isLoading
                    ? (value) => setState(() => _enableBiometricForNextLogins = value)
                    : null,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Activer connexion par empreinte / Face ID',
                  style: TextStyle(color: pt.ink, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _biometricAvailable
                      ? 'Connexion rapide sur cet appareil.'
                      : 'Biométrie non disponible sur cet appareil.',
                  style: TextStyle(color: pt.ink.withValues(alpha: 0.65), fontSize: 12),
                ),
              ),

              const SizedBox(height: 12),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
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
                    : Text(
                        _isSignIn ? 'Se connecter' : 'Créer mon compte',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),

              if (_isSignIn && _biometricAvailable && _hasBiometricCredentials) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Se connecter avec empreinte / Face ID'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: pt.ink.withValues(alpha: 0.2)),
                    foregroundColor: pt.ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // --- OAuth divider + buttons ---
              Row(
                children: [
                  Expanded(child: Divider(color: pt.ink.withValues(alpha: 0.2))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('ou', style: TextStyle(color: pt.ink.withValues(alpha: 0.5), fontSize: 14)),
                  ),
                  Expanded(child: Divider(color: pt.ink.withValues(alpha: 0.2))),
                ],
              ),
              const SizedBox(height: 16),

              // Apple Sign In — iOS only
              if (Platform.isIOS) ...[
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _signInWithOAuth(OAuthProvider.apple),
                  icon: const Icon(Icons.apple, color: Colors.white),
                  label: const Text('Continuer avec Apple'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Google Sign In
              ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _signInWithOAuth(OAuthProvider.google),
                icon: Icon(Icons.g_mobiledata, color: Colors.black, size: 28),
                label: const Text('Continuer avec Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        final nextMode = _isSignIn ? AuthScreenMode.signUp : AuthScreenMode.signIn;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => AuthScreen(
                              mode: nextMode,
                              initialEmail: _emailController.text.trim(),
                            ),
                          ),
                        );
                      },
                child: Text(
                  _isSignIn
                      ? 'Pas encore de compte ? Créer un compte'
                      : 'Déjà un compte ? Se connecter',
                  style: TextStyle(
                    color: pt.primary,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              if (_isSignIn) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _isLoading ? null : _forgotPassword,
                  child: Text(
                    'Mot de passe oublié ? Réinitialiser par code email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: pt.primary,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline indicator showing password requirement progress.
class _PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final dynamic theme;
  const _PasswordStrengthIndicator({required this.password, required this.theme});

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 10;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);

    Widget row(bool ok, String label) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.circle_outlined,
              size: 16,
              color: ok ? const Color(0xFF4CAF50) : theme.mid,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ok ? theme.ink : theme.mid,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(hasLength, '10 caractères minimum'),
        row(hasUpper, '1 lettre majuscule'),
        row(hasDigit, '1 chiffre'),
      ],
    );
  }
}

