import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/screens/activity/activity_history_screen.dart';

class PigioAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final bool autoShowBackFromCanPop;
  final bool showNotification;

  const PigioAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
    this.autoShowBackFromCanPop = true,
    this.showNotification = true,
  });

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PigioAppState>(context);
    final notifCount = state.unseenLogsCount;
    final canPop = Navigator.of(context).canPop();
    final shouldShowBack = showBack || (autoShowBackFromCanPop && canPop);
    final theme = context.pt;

    return AppBar(
      backgroundColor: theme.navBar,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leadingWidth: 70,
      leading: Padding(
        padding: const EdgeInsets.only(left: 20, top: 6, bottom: 6),
        child: shouldShowBack
            ? Semantics(
          label: "Retour",
          button: true,
          child: GestureDetector(
            onTap: () {
              if (canPop) {
                Navigator.pop(context);
              } else {
                state.setTabIndex(0);
              }
            },
            child: Container(
              width: 44, height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: theme.surface, shape: BoxShape.circle),
              child: Icon(Icons.arrow_back_ios_new, size: 18, color: theme.ink),
            ),
          ),
        )
            : Semantics(
          label: "Menu principal",
          button: true,
          child: GestureDetector(
            onTap: () {
              context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer();
            },
            child: Container(
              alignment: Alignment.center,
              child: PigioAvatar(
                name: state.profile.name,
                size: 40,
                ringColor: theme.mid.withValues(alpha: 0.1),
                avatarIcon: state.profile.avatarIcon,
                avatarColor: state.profile.avatarColor,
              ),
            ),
          ),
        ),
      ),
      title: Text(title, style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
      actions: [
        if (actions != null) ...actions!,
        if (showNotification)
          Padding(
            padding: const EdgeInsets.only(right: 20, left: 8),
            child: Material(
              type: MaterialType.transparency,
              child: Semantics(
                label: "Historique d'activités",
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    final currentCount = state.unseenLogsCount;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityHistoryScreen(initialUnseenCount: currentCount)));
                    state.clearUnseenLogs();
                  },
                  child: Container(
                    width: 44, height: 44,
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(14)),
                          child: const Center(child: Text("🔔", style: TextStyle(fontSize: 20))),
                        ),
                        if (notifCount > 0)
                          Positioned(
                            top: -4, right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              decoration: BoxDecoration(
                                  color: theme.accent2,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: theme.navBar, width: 2)
                              ),
                              child: Center(
                                child: Text(
                                    notifCount > 9 ? '9+' : '$notifCount',
                                    style: fw(size: 11, w: FontWeight.w900, color: theme.onAccent, height: 1.1)
                                ),
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}

class PigioCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const PigioCard({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        margin: margin,
        decoration: BoxDecoration(
          color: color ?? theme.card,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: theme.shadow,
              offset: const Offset(0, 2),
              blurRadius: 16,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class PigioButton extends StatefulWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final VoidCallback? onTap;
  final IconData? icon;
  final double? width;
  final double height;
  final double fontSize;
  final bool fullWidth;
  final bool hasShadow;

  const PigioButton({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.onTap,
    this.icon,
    this.height = 54,
    this.fontSize = 15,
    this.width,
    this.fullWidth = true,
    this.hasShadow = true,
  });

  @override
  State<PigioButton> createState() => _PigioButtonState();
}

class _PigioButtonState extends State<PigioButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final btnColor = widget.color ?? theme.primary;
    final txtColor = widget.textColor ?? theme.onAccent;

    final bool effectiveShadow = widget.hasShadow && btnColor.a > 0.5;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Container(
        width: widget.fullWidth ? (widget.width ?? double.infinity) : widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: btnColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.ink.withValues(alpha: 0.05), width: 0.5),
          boxShadow: effectiveShadow ? [
            BoxShadow(
              color: btnColor.withValues(alpha: theme.isDark ? 0.2 : 0.3),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: txtColor, size: widget.fontSize + 4),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: fw(size: widget.fontSize, w: FontWeight.w800, color: txtColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PigioBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? bg;

  const PigioBadge({
    super.key,
    required this.label,
    this.color,
    this.bg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final badgeColor = color ?? theme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? badgeColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        label,
        style: fw(size: 10, w: FontWeight.w700, color: badgeColor).copyWith(letterSpacing: 0.3),
      ),
    );
  }
}

class PigioAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? ringColor;
  final String? avatarIcon;
  final Color? avatarColor;

  const PigioAvatar({
    super.key,
    this.name = "?",
    this.size = 40,
    this.ringColor,
    this.avatarIcon,
    this.avatarColor,
  });

  double _getCorrectiveScale(String path) {
    if (path.contains('hijabie') || path.contains('old_man') || path.contains('elder')) {
      return 1.35;
    }
    return 1.1;
  }

  Widget _buildInitials(String initials, Color color, PigioThemeData theme) {
    return Text(
      initials,
      style: fw(size: size * 0.37, w: FontWeight.w800, color: theme.ink),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final initials = name.split(" ").map((e) => e.isNotEmpty ? e[0] : "").join("").take(2).toUpperCase();
    final storedColor = avatarColor ?? AppColors.getAvColor(name);

    Color displayColor = storedColor;
    if (theme.isDark) {
      final idx = AppColors.notionWarmColors.indexOf(storedColor);
      if (idx >= 0 && idx < AppColors.notionWarmColorsDark.length) {
        displayColor = AppColors.notionWarmColorsDark[idx];
      }
    }

    Widget content;

    if (avatarIcon != null && avatarIcon!.isNotEmpty) {
      if (avatarIcon!.startsWith('assets/')) {
        content = ClipOval(
          child: Transform.scale(
            scale: _getCorrectiveScale(avatarIcon!),
            child: Image.asset(
              avatarIcon!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildInitials(initials, displayColor, theme),
            ),
          ),
        );
      } else if (avatarIcon!.startsWith('http')) {
        content = ClipOval(
          child: Image.network(
            avatarIcon!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildInitials(initials, displayColor, theme),
          ),
        );
      } else {
        content = Text(
          avatarIcon!,
          style: TextStyle(fontSize: size * 0.5),
        );
      }
    } else {
      content = _buildInitials(initials, displayColor, theme);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: displayColor,
        shape: BoxShape.circle,
        border: ringColor != null ? Border.all(color: ringColor!, width: 2.5) : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: content,
    );
  }
}

extension StringExtension on String {
  String take(int n) => length > n ? substring(0, n) : this;
}

class PigioProgressBar extends StatelessWidget {
  final double pct;
  final Color? color;
  final double height;

  const PigioProgressBar({
    super.key,
    required this.pct,
    this.color,
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final barColor = color ?? theme.primary;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: barColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      clipBehavior: Clip.hardEdge,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: pct > 0 ? (pct > 1 ? 1 : pct) : 0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [barColor, barColor.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}

class StreakBadge extends StatelessWidget {
  final int count;

  const StreakBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF3D00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5000).withValues(alpha: 0.35),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("🔥", style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            "$count",
            style: fw(size: 13, w: FontWeight.w900, color: const Color(0xFFFFFFFF)),
          ),
        ],
      ),
    );
  }
}