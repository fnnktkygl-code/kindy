import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'auth_screen.dart';

/// Shown after sign-up when Supabase requires email confirmation.
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  children: [
                    // Top bar with back
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: pt.ink.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: pt.ink.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Illustration
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: pt.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.mark_email_read_outlined,
                          size: 40,
                          color: pt.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Text(
                      'Vérifiez votre email',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: pt.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Nous avons envoyé un lien de confirmation à',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: pt.ink.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: pt.primary,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Steps card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: pt.isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : pt.ink.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _StepRow(
                            pt: pt,
                            step: 1,
                            text: 'Ouvrez votre boîte mail',
                            icon: Icons.inbox_outlined,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 17),
                            child: Container(
                              width: 1,
                              height: 16,
                              color: pt.ink.withValues(alpha: 0.08),
                            ),
                          ),
                          _StepRow(
                            pt: pt,
                            step: 2,
                            text: 'Cliquez sur le lien',
                            icon: Icons.touch_app_outlined,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 17),
                            child: Container(
                              width: 1,
                              height: 16,
                              color: pt.ink.withValues(alpha: 0.08),
                            ),
                          ),
                          _StepRow(
                            pt: pt,
                            step: 3,
                            text: 'Revenez vous connecter',
                            icon: Icons.login_rounded,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Pensez à vérifier vos spams',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: pt.ink.withValues(alpha: 0.35),
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                    const Spacer(flex: 3),

                    // CTA
                    SizedBox(
                      height: 54,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => AuthScreen(
                                mode: AuthScreenMode.signIn,
                                initialEmail: widget.email,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: pt.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Se connecter',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final dynamic pt;
  final int step;
  final String text;
  final IconData icon;

  const _StepRow({
    required this.pt,
    required this.step,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: pt.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: pt.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: pt.ink,
            ),
          ),
        ),
        Icon(icon, size: 20, color: pt.ink.withValues(alpha: 0.3)),
      ],
    );
  }
}