import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../shared/widgets/mascot_overlay.dart';
import '../shared/widgets/ui_widgets.dart';
import '../core/deeplink/deeplink_coordinator.dart';
import '../core/notifications/fcm_coordinator.dart';
import 'package:pigio_app/screens/activity/activity_history_screen.dart';
import 'package:pigio_app/screens/events/calendar_screen.dart';
import 'package:pigio_app/screens/contacts/contacts_screen.dart';
import 'package:pigio_app/features/home/presentation/home_screen.dart';
import 'package:pigio_app/screens/profile/profile_screen.dart';
import 'package:pigio_app/screens/settings/settings_screen.dart';
import 'package:pigio_app/screens/auth/splash_screen.dart';
import 'package:pigio_app/screens/sizes/wardrobe_screen.dart';
import 'package:pigio_app/screens/wishes/wishes_screen.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/i18n/i18n.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  final DeeplinkCoordinator _deeplinkCoordinator = DeeplinkCoordinator();
  final FcmCoordinator _fcmCoordinator = FcmCoordinator();

  final List<Widget> _screens = [
    const HomeScreen(),
    const WishesScreen(),
    const WardrobeScreen(),
    const ContactsScreen(),
  ];

  // MSN Wizz — full-screen shake
  late final AnimationController _shakeCtrl;
  int _lastWizzNonce = 0;
  double _shakeAmplitude = 16;
  double _shakeVerticalFactor = 0.35;
  double _shakeCycles = 9;

  @override
  void initState() {
    super.initState();
    _initDeepLinkHandling();
    _initFcm();

    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
  }

  void _playWizzShake(WizzEffectMode mode) {
    if (!mounted) return;
    if (mode == WizzEffectMode.phase2) {
      _shakeAmplitude = 28;
      _shakeVerticalFactor = 0.55;
      _shakeCycles = 16;
      _shakeCtrl.duration = const Duration(milliseconds: 1150);
    } else {
      _shakeAmplitude = 16;
      _shakeVerticalFactor = 0.35;
      _shakeCycles = 9;
      _shakeCtrl.duration = const Duration(milliseconds: 760);
    }
    _shakeCtrl.forward(from: 0);
  }

  Future<void> _initDeepLinkHandling() async {
    try {
      await context.read<PigioAppState>().ready;
      await _deeplinkCoordinator.init(
        isMounted: () => mounted,
        onInviteUri: _processIncomingInvite,
      );
    } catch (_) {
      // Keep app flow resilient if deep-link stream cannot be initialized.
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
        const SnackBar(content: Text('Invitation invalide ou expirée.')),
      );
      return;
    }

    final inviterName =
        resolution.inviterProfile?.name ?? resolution.inviterId ?? 'Quelqu\'un';
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          '📩  Invitation reçue',
          style: TextStyle(fontWeight: FontWeight.w900, color: theme.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PigioAvatar(
              name: inviterName,
              size: 64,
              avatarIcon: resolution.inviterProfile?.avatarIcon,
              avatarColor: resolution.inviterProfile?.avatarColor != null
                  ? Color(resolution.inviterProfile!.avatarColor!)
                  : null,
              ringColor: resolution.inviterProfile?.avatarColor != null
                  ? Color(resolution.inviterProfile!.avatarColor!)
                  : theme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '$inviterName vous invite à rejoindre Pigio.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Voulez-vous accepter cette invitation et ajouter ce contact ?',
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
              'Décliner',
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
            child: const Text(
              'Accepter',
              style: TextStyle(fontWeight: FontWeight.w800),
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
                ? 'Invitation acceptée : contact ajouté !'
                : 'Erreur lors de l\'acceptation.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation déclinée.')),
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
    _shakeCtrl.dispose();
    _deeplinkCoordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PigioAppState>(context);
    final int currentIndex =
        state.currentTabIndex >= _screens.length ? 0 : state.currentTabIndex;
    final profile = state.profile;
    final theme = context.pt;

    // Trigger full-screen shake when a new Wizz arrives
    final wizzNonce = state.globalWizzNonce;
    if (wizzNonce != _lastWizzNonce) {
      _lastWizzNonce = wizzNonce;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _playWizzShake(state.wizzEffectMode);
      });
    }

    final shakeProgress = _shakeCtrl.value;
    final envelope = (1.0 - shakeProgress).clamp(0.0, 1.0);
    final waveX = math.sin(shakeProgress * math.pi * 2 * _shakeCycles);
    final waveY = math.sin(shakeProgress * math.pi * 2 * (_shakeCycles + 1.7));
    final shakeX = waveX * _shakeAmplitude * envelope;
    final shakeY = waveY * _shakeAmplitude * _shakeVerticalFactor * envelope;

    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (context, child) => Transform.translate(
        offset: Offset(shakeX, shakeY),
        child: child,
      ),
      child: Scaffold(
      drawer: _buildDrawer(context, profile, theme),
      body: Stack(
        children: [
          _screens[currentIndex],
          DraggableMascot(tabIndex: currentIndex),
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
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.primary.withValues(alpha: 0.05), theme.navBar],
              ),
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
                _drawerItem(Icons.security_outlined, 'Confidentialité', () {
                  launchUrl(Uri.parse('https://pigio.app/privacy/'), mode: LaunchMode.externalApplication);
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
                    await Supabase.instance.client.auth.signOut();
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
