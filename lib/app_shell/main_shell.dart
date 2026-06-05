import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/widgets/mascot_overlay.dart';
import '../shared/widgets/ui_widgets.dart';
import '../core/deeplink/deeplink_coordinator.dart';
import '../core/notifications/fcm_coordinator.dart';
import 'package:kindy/screens/activity/activity_history_screen.dart';
import 'package:kindy/screens/events/calendar_screen.dart';
import 'package:kindy/screens/contacts/contacts_screen.dart';
import 'package:kindy/features/home/presentation/home_screen.dart';
import 'package:kindy/screens/profile/profile_screen.dart';
import 'package:kindy/screens/settings/settings_screen.dart';
import 'package:kindy/screens/auth/splash_screen.dart';
import 'package:kindy/screens/mascot/wrapped_screen.dart';
import 'package:kindy/screens/sizes/wardrobe_screen.dart';
import 'package:kindy/screens/wishes/wishes_screen.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/i18n/i18n.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/services/notification_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  final DeeplinkCoordinator _deeplinkCoordinator = DeeplinkCoordinator();
  final FcmCoordinator _fcmCoordinator = FcmCoordinator();

  final List<Widget> _screens = [
    const HomeScreen(),
    const WishesScreen(),
    const WardrobeScreen(),
    const ContactsScreen(),
  ];

  final Set<String> _shownInAppWizzNotificationIds = <String>{};
  PigioNotification? _activeWizzBanner;
  Timer? _wizzBannerTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    _initDeepLinkHandling();
    _initFcm();
  }

  late final WidgetsBindingObserver _lifecycleObserver =
      _MainShellLifecycleObserver((state) {
        if (!mounted) return;
        context.read<PigioAppState>().setAppLifecycleState(state);
      });

  Future<void> _initDeepLinkHandling() async {
    try {
      await context.read<PigioAppState>().ready;
      await _deeplinkCoordinator.init(
        isMounted: () => mounted,
        onInviteUri: _processIncomingInvite,
      );
    } catch (e) {
      debugPrint('[MainShell] Deep-link init failed: $e');
    }
  }

  Future<void> _processIncomingInvite(Uri uri) async {
    if (!mounted) return;
    final state = context.read<PigioAppState>();
    final theme = context.read<PigioAppState>().currentTheme;

    final resolution = await state.resolveIncomingInviteLink(uri);
    if (!mounted) return;
    if (!resolution.valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'invite_invalid'))),
      );
      return;
    }

    final inviterName =
        resolution.inviterProfile?.name ?? resolution.inviterId ?? t(context, 'invite_someone');
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          t(context, 'invite_received_title'),
          style: TextStyle(fontWeight: FontWeight.w900, color: theme.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(builder: (_) {
              final color = resolution.inviterProfile?.avatarColor;
              return PigioAvatar(
                name: inviterName,
                size: 64,
                avatarIcon: resolution.inviterProfile?.avatarIcon,
                avatarColor: color != null ? Color(color) : null,
                ringColor: color != null ? Color(color) : theme.primary,
              );
            }),
            const SizedBox(height: 12),
            Text(
              '$inviterName ${t(context, 'invite_join_msg')}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(context, 'invite_confirm_msg'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.mid,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t(context, 'invite_decline'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: theme.error,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: theme.onAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t(context, 'invite_accept'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (accepted == true) {
      final result = await state.acceptResolvedInvite(resolution);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result
                ? t(context, 'invite_accepted')
                : t(context, 'invite_accept_error'),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t(context, 'invite_declined'))),
      );
    }
  }

  Future<void> _initFcm() async {
    if (!mounted) return;
    final state = context.read<PigioAppState>();
    await _fcmCoordinator.init(state: state, isMounted: () => mounted);
  }

  @override
  void dispose() {
    _wizzBannerTimer?.cancel();
    _fcmCoordinator.dispose();
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _deeplinkCoordinator.dispose();
    super.dispose();
  }

  void _maybeShowInAppWizzBanner(PigioAppState state) {
    final now = DateTime.now();
    final latest = state.notifications
        .where((n) =>
            n.type == 'wizz' &&
            now.difference(n.createdAt).inMinutes <= 10 &&
            !_shownInAppWizzNotificationIds.contains(n.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (latest.isEmpty) return;
    final notif = latest.first;
    _shownInAppWizzNotificationIds.add(notif.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _wizzBannerTimer?.cancel();
      setState(() => _activeWizzBanner = notif);
      _wizzBannerTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() => _activeWizzBanner = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PigioAppState>(context);
    final int currentIndex =
        state.currentTabIndex >= _screens.length ? 0 : state.currentTabIndex;
    final profile = state.profile;
    final theme = context.pt;
    _maybeShowInAppWizzBanner(state);

    return Scaffold(
      drawer: _buildDrawer(context, profile, theme),
      body: Stack(
        children: [
          _screens[currentIndex],
          SafeDraggableMascot(tabIndex: currentIndex),
          _buildWizzBanner(theme),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.navBar,
          boxShadow: [
            BoxShadow(
              color: theme.shadow,
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, '🏠', t(context, 'nav_home'), theme.accent1),
              _navItem(1, '🎁', t(context, 'nav_wishes'), theme.accent2),
              _navItem(2, '📐', t(context, 'nav_sizes'), theme.accent3),
              _navItem(3, '👥', t(context, 'nav_family'), theme.accent4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWizzBanner(PigioThemeData theme) {
    final notif = _activeWizzBanner;
    final isVisible = notif != null;

    return IgnorePointer(
      ignoring: !isVisible,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            offset: isVisible ? Offset.zero : const Offset(0, -1.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: isVisible ? 1 : 0,
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.divider.withValues(alpha: 0.85)),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadow,
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: theme.accent1.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        notif?.emoji ?? '⚡',
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Wizz reçu',
                            style: fw(size: 13, w: FontWeight.w900, color: theme.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notif?.message ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: fw(size: 12, w: FontWeight.w700, color: theme.mid),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _wizzBannerTimer?.cancel();
                        setState(() => _activeWizzBanner = null);
                      },
                      icon: Icon(Icons.close_rounded, size: 18, color: theme.mid),
                      splashRadius: 18,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    UserProfile profile,
    PigioThemeData theme,
  ) {
    return Drawer(
      backgroundColor: theme.navBar,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
            decoration: BoxDecoration(
              color: theme.navBar,
            ),
            child: Row(
              children: [
                PigioAvatar(
                  name: profile.name,
                  size: 64,
                  avatarIcon: profile.avatarIcon,
                  avatarColor: profile.avatarColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: fw(size: 20, w: FontWeight.w900, color: theme.ink),
                      ),
                      Text(
                        profile.handle,
                        style: fw(size: 14, w: FontWeight.w600, color: theme.mid),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _drawerItem(Icons.person_outline, 'Mon Profil', () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                }, theme),
                _drawerItem(Icons.calendar_month_outlined, 'Évènement', () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CalendarScreen()),
                  );
                }, theme),
                _drawerItem(Icons.settings_outlined, 'Paramètres', () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                }, theme),
                _drawerItem(Icons.history_outlined, 'Historique', () {
                  Navigator.pop(context);
                  final state = Provider.of<PigioAppState>(
                    context,
                    listen: false,
                  );
                  final currentCount = state.unseenLogsCount;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActivityHistoryScreen(
                        initialUnseenCount: currentCount,
                      ),
                    ),
                  );
                  state.clearUnseenLogs();
                }, theme),
                _drawerItem(Icons.auto_awesome_outlined, 'Pigio Wrapped', () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WrappedScreen()),
                  );
                }, theme),
                _drawerItem(Icons.security_outlined, 'Confidentialité', () {
                  launchUrl(Uri.parse('https://fnnktkygl-code.github.io/pigio-app/privacy/'), mode: LaunchMode.externalApplication);
                }, theme),
                _drawerItem(Icons.help_outline, 'Centre d\'aide', () {
                  launchUrl(Uri.parse('https://pigio.app/'), mode: LaunchMode.externalApplication);
                }, theme),
                Divider(height: 40, color: theme.divider),
                _drawerItem(
                  Icons.logout,
                  'Déconnexion',
                  () async {
                    Navigator.pop(context);
                    final state = context.read<PigioAppState>();
                    await state.signOutAndCleanupLocalState();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                      (route) => false,
                    );
                  },
                  theme,
                  isDestructive: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Pigio v${AppMeta.version}',
              style: fw(size: 12, color: theme.light),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String label,
    VoidCallback onTap,
    PigioThemeData theme, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? theme.error : theme.ink,
        size: 22,
      ),
      title: Text(
        label,
        style: fw(
          size: 16,
          w: FontWeight.w700,
          color: isDestructive ? theme.error : theme.ink,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _navItem(int i, String icon, String label, Color color) {
    final state = Provider.of<PigioAppState>(context, listen: false);
    final active = state.currentTabIndex == i;

    return GestureDetector(
      onTap: () => state.setTabIndex(i),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: active ? 16 : 8, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            if (active) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: fw(size: 13, w: FontWeight.w900, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MainShellLifecycleObserver extends WidgetsBindingObserver {
  final void Function(AppLifecycleState state) onLifecycle;
  _MainShellLifecycleObserver(this.onLifecycle);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onLifecycle(state);
  }
}
