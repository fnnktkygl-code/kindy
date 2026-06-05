import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';

// ---------------------------------------------------------------------------
// Wizz option model
// ---------------------------------------------------------------------------

class WizzOption {
  final String emoji;
  final String label;
  final String subtitle;

  const WizzOption({required this.emoji, required this.label, required this.subtitle});
}

const List<WizzOption> kWizzOptions = [
  WizzOption(emoji: '👋', label: 'Profil général',     subtitle: 'Mets à jour ton profil Pigio'),
  WizzOption(emoji: '📏', label: 'Tailles',            subtitle: 'Partage tes mesures pour les cadeaux'),
  WizzOption(emoji: '✨', label: 'Liste de souhaits',  subtitle: 'Ajoute des envies à ta liste'),
  WizzOption(emoji: '📦', label: 'Adresse',            subtitle: 'Renseigne ton adresse de livraison'),
  WizzOption(emoji: '🎂', label: 'Anniversaire',       subtitle: 'Partage ta date d\'anniversaire'),
];

// ---------------------------------------------------------------------------
// WizzSheet
// ---------------------------------------------------------------------------

class WizzSheet extends StatefulWidget {
  final ContactProfile contact;

  /// Called immediately after the wizz is recorded, before the sheet closes.
  /// Use it to trigger a shake animation in the parent widget.
  final VoidCallback? onSent;

  const WizzSheet({super.key, required this.contact, this.onSent});

  @override
  State<WizzSheet> createState() => _WizzSheetState();
}

class _WizzSheetState extends State<WizzSheet> with SingleTickerProviderStateMixin {
  int _selected = 0;
  bool _sent = false;

  late final AnimationController _sendCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _sendCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.14), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 1.14, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _sendCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _sendCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(BuildContext ctx, PigioAppState state) async {
    if (_sent) return;
    if (!state.canWizz(widget.contact.id)) return;
    setState(() => _sent = true);
    final selectedOption = kWizzOptions[_selected];
    final nav = Navigator.of(ctx); // capture before async gap
    HapticFeedback.mediumImpact();
    _sendCtrl.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 200));
    state.sendWizz(
      widget.contact.id,
      reasonLabel: selectedOption.label,
      reasonSubtitle: selectedOption.subtitle,
    );
    if (!mounted) return;
    widget.onSent?.call();
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    if (nav.canPop()) {
      await nav.maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.read<PigioAppState>();

    return Container(
      decoration: BoxDecoration(
        color: theme.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20,
        MediaQuery.of(context).viewInsets.bottom + 36,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: theme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header row
          Row(
            children: [
              const Text('⚡', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wizz à ${widget.contact.name}',
                      style: fw(size: 20, w: FontWeight.w900, color: theme.ink),
                    ),
                    Text(
                      'Un petit coup de pouce amical 😄',
                      style: fw(size: 13, w: FontWeight.w600, color: theme.mid),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Text(
            'QUE VEUX-TU LUI DEMANDER ?',
            style: fw(size: 11, w: FontWeight.w800, color: theme.mid, letterSpacing: 1.1),
          ),
          const SizedBox(height: 12),

          // Wizz type chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(kWizzOptions.length, (i) {
              final opt = kWizzOptions[i];
              final isSelected = _selected == i;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selected = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.accent1.withValues(alpha: 0.1)
                        : theme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? theme.accent1 : theme.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(opt.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt.label,
                            style: fw(
                              size: 13,
                              w: FontWeight.w800,
                              color: isSelected ? theme.accent1 : theme.ink,
                            ),
                          ),
                          Text(
                            opt.subtitle,
                            style: fw(size: 10, w: FontWeight.w600, color: theme.mid),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 24),

          // Send button (animated bounce on send)
          Builder(builder: (_) {
            final remaining = state.wizzCooldownRemaining(widget.contact.id);
            final onCooldown = remaining > Duration.zero;

            return AnimatedBuilder(
              animation: _scaleAnim,
              builder: (_, child) =>
                  Transform.scale(scale: _scaleAnim.value, child: child),
              child: _sent
                  ? Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.success,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: theme.onAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Wizz envoyé !',
                            style: fw(
                                size: 16, w: FontWeight.w900, color: theme.onAccent),
                          ),
                        ],
                      ),
                    )
                  : onCooldown
                      ? Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '⏱ ${_formatCooldown(remaining)}',
                            style: fw(size: 14, w: FontWeight.w700, color: theme.mid),
                          ),
                        )
                      : PigioButton(
                          label: 'Envoyer le Wizz ⚡',
                          color: theme.accent1,
                          textColor: theme.onAccent,
                          height: 52,
                          fontSize: 15,
                          hasShadow: true,
                          onTap: () => _send(context, state),
                          fullWidth: true,
                        ),
            );
          }),
        ],
      ),
    );
  }

  String _formatCooldown(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    if (m > 0) return '${m}min${s.toString().padLeft(2, '0')}';
    return '${s}s';
  }
}
