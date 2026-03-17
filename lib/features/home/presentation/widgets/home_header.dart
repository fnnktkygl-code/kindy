import 'package:flutter/material.dart';
import '../../../../shared/widgets/ui_widgets.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';

class HomeHeader extends StatelessWidget {
  final String displayName;
  final String? avatarIcon;
  final Color? avatarColor;
  final int unseenLogsCount;
  final PigioThemeData theme;
  final VoidCallback onOpenDrawer;
  final VoidCallback onOpenActivity;

  const HomeHeader({
    super.key,
    required this.displayName,
    required this.avatarIcon,
    required this.avatarColor,
    required this.unseenLogsCount,
    required this.theme,
    required this.onOpenDrawer,
    required this.onOpenActivity,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onOpenDrawer,
            child: PigioAvatar(
              name: displayName,
              size: 56,
              ringColor: theme.mid.withValues(alpha: 0.1),
              avatarIcon: avatarIcon,
              avatarColor: avatarColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Bonjour ${displayName.split(' ').first} 👋", style: fw(size: 26, w: FontWeight.w900, color: theme.ink, letterSpacing: -0.5)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onOpenActivity,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: theme.surface, shape: BoxShape.circle),
                  child: Icon(Icons.notifications_outlined, color: theme.ink, size: 28),
                ),
                if (unseenLogsCount > 0)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: theme.accent2, shape: BoxShape.circle, border: Border.all(color: theme.scaffold, width: 2.5)),
                      child: Text("$unseenLogsCount", style: fw(size: 10, w: FontWeight.w900, color: theme.onAccent)),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}