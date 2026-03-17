import 'package:flutter/material.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/services/tooltip_service.dart';

/// A dismissible contextual tip banner for progressive disclosure.
/// Shows once per tooltip key, then never again.
class ContextualTip extends StatefulWidget {
  final String tooltipKey;
  final String text;
  final IconData icon;
  final VoidCallback? onTap;

  const ContextualTip({
    super.key,
    required this.tooltipKey,
    required this.text,
    this.icon = Icons.lightbulb_outline,
    this.onTap,
  });

  @override
  State<ContextualTip> createState() => _ContextualTipState();
}

class _ContextualTipState extends State<ContextualTip>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _checkVisibility();
  }

  Future<void> _checkVisibility() async {
    final show = await TooltipService.shouldShow(widget.tooltipKey);
    if (show && mounted) {
      setState(() => _visible = true);
      _ctrl.forward();
    }
  }

  void _dismiss() {
    _ctrl.reverse().then((_) {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final theme = context.pt;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: GestureDetector(
          onTap: () {
            widget.onTap?.call();
            _dismiss();
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: theme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.primary,
                      height: 1.3,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: theme.mid),
                  onPressed: _dismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
