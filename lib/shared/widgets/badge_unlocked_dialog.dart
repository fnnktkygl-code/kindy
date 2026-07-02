import 'package:flutter/material.dart';
import 'package:kindy/core/models/user_badge.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class BadgeUnlockedDialog extends StatefulWidget {
  final UserBadge badge;
  final PigioThemeData theme;
  final bool isFr;

  const BadgeUnlockedDialog({
    super.key,
    required this.badge,
    required this.theme,
    this.isFr = true,
  });

  static void show(BuildContext context, UserBadge badge, PigioThemeData theme, {bool isFr = true}) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => BadgeUnlockedDialog(badge: badge, theme: theme, isFr: isFr),
    );
  }

  @override
  State<BadgeUnlockedDialog> createState() => _BadgeUnlockedDialogState();
}

class _BadgeUnlockedDialogState extends State<BadgeUnlockedDialog> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final scale = Curves.elasticOut.transform(_ctrl.value);
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: widget.theme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.theme.accent1.withValues(alpha: 0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.theme.accent1.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isFr ? 'Nouveau Badge !' : 'New Badge!',
                style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: widget.theme.primary),
              ),
              const SizedBox(height: 24),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.theme.accent1.withValues(alpha: 0.2),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.badge.emoji,
                  style: const TextStyle(fontSize: 50),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.isFr ? widget.badge.titleFr : widget.badge.titleEn,
                style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.bold, color: widget.theme.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isFr ? widget.badge.descriptionFr : widget.badge.descriptionEn,
                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.normal, color: widget.theme.mid),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.theme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    widget.isFr ? 'Génial !' : 'Awesome!',
                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: widget.theme.surface),
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
