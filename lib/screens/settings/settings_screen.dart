import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/core/i18n/i18n.dart';
import 'package:kindy/screens/mascot/mascot_settings_screen.dart';
import 'package:kindy/screens/settings/pigio_plus_screen.dart';
import 'package:kindy/screens/settings/notification_settings_screen.dart';
import 'package:kindy/screens/auth/splash_screen.dart';
import 'package:kindy/screens/settings/sheets/cloud_sync_sheet.dart';
import 'package:kindy/services/pigio_logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PigioAppState>(context);
    final theme = context.pt;

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: AppBar(
        title: Text(t(context, 'settings_title'), style: fw(size: 20, w: FontWeight.w800, color: theme.ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PigioDesign.paddingMedium),
        child: Column(
          children: [
            // ── Appearance ──────────────────────────────────────────────
            _buildSectionTitle(context, t(context, 'settings_appearance'), theme),
            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              padding: const EdgeInsets.all(8),
              child: _ThemePicker(
                currentVariant: state.themeVariant,
                autoTheme: state.autoTheme,
                onSelect: (v) {
                  state.setAutoTheme(false);
                  state.setTheme(v);
                },
                onAutoTheme: () => state.setAutoTheme(true),
              ),
            ),

            // ── General ─────────────────────────────────────────────────
            _buildSectionTitle(context, t(context, 'settings_general'), theme),
            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              child: Column(
                children: [
                  ListTile(
                    title: Text(t(context, 'settings_language'), style: fw(size: 16, w: FontWeight.w700, color: theme.ink)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LangBtn(lang: 'en', current: state.locale.languageCode, onTap: () => state.setLocale(const Locale('en'))),
                        const SizedBox(width: 8),
                        _LangBtn(lang: 'fr', current: state.locale.languageCode, onTap: () => state.setLocale(const Locale('fr'))),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: theme.divider),
                  ListTile(
                    leading: Icon(Icons.notifications_active, color: theme.primary, size: 22),
                    title: Text(
                      state.locale.languageCode == 'fr' ? 'Notifications & Rappels' : 'Notifications & Reminders',
                      style: fw(size: 16, w: FontWeight.w700, color: theme.ink),
                    ),
                    trailing: Icon(Icons.chevron_right, color: theme.light),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Pigio+ ──────────────────────────────────────────────────
            _buildSectionTitle(context, "PIGIO+", theme),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PigioPlusScreen())),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.primary,
                  borderRadius: BorderRadius.circular(PigioDesign.radiusMedium),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.star, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.isPremium
                                ? (state.locale.languageCode == 'fr' ? 'Pigio+ Actif' : 'Pigio+ Active')
                                : 'Pigio+',
                            style: fw(size: 16, w: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.isPremium
                                ? (state.locale.languageCode == 'fr' ? 'Abonnement actif ✓' : 'Subscription active ✓')
                                : (state.locale.languageCode == 'fr' ? 'Débloquez les avantages premium' : 'Unlock premium perks'),
                            style: fw(size: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white70),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ── Pigio ───────────────────────────────────────────────────
            _buildSectionTitle(context, "PIGIO", theme),
            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              child: ListTile(
                leading: const Text("🎁", style: TextStyle(fontSize: 22)),
                title: Text(t(context, 'settings_pigio'), style: fw(size: 16, w: FontWeight.w700, color: theme.ink)),
                subtitle: Text(t(context, 'settings_pigio_sub'), style: fw(size: 12, color: theme.mid)),
                trailing: Icon(Icons.chevron_right, color: theme.mid),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MascotSettingsScreen())),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t(context, 'settings_wizz'), style: fw(size: 16, w: FontWeight.w800, color: theme.ink)),
                  const SizedBox(height: 4),
                  Text(t(context, 'settings_wizz_sub'), style: fw(size: 12, color: theme.mid)),
                  const SizedBox(height: 12),
                  SegmentedButton<WizzEffectMode>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return theme.primary.withValues(alpha: 0.14);
                        }
                        return theme.surface;
                      }),
                      side: WidgetStatePropertyAll(BorderSide(color: theme.divider)),
                      foregroundColor: WidgetStatePropertyAll(theme.ink),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: WizzEffectMode.phase1,
                        label: Text('Phase 1'),
                        icon: Text('⚡'),
                      ),
                      ButtonSegment(
                        value: WizzEffectMode.phase2,
                        label: Text('Phase 2'),
                        icon: Text('💥'),
                      ),
                    ],
                    selected: {state.wizzEffectMode},
                    onSelectionChanged: (selection) {
                      final mode = selection.first;
                      state.setWizzEffectMode(mode);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Data ────────────────────────────────────────────────────
            _buildSectionTitle(context, t(context, 'settings_data'), theme),
            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              child: Column(
                children: [
                  ListTile(
                    title: Text(t(context, 'settings_delete_account'), style: fw(size: 16, w: FontWeight.w700, color: theme.error)),
                    subtitle: Text(t(context, 'settings_delete_account_sub'), style: fw(size: 12, color: theme.mid)),
                    trailing: Icon(Icons.warning_amber_rounded, color: theme.error),
                    onTap: _isDeleting ? null : () => _confirmAccountDelete(context, state, theme),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Cloud Backup ─────────────────────────────────────────────
            _buildSectionTitle(context, 'Sauvegarde', theme),
            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              child: ListTile(
                leading: Icon(Icons.cloud_outlined, color: state.syncEnabled && state.backupLookupKey.isNotEmpty ? theme.success : theme.mid),
                title: Text('Sauvegarde Cloud', style: fw(size: 16, w: FontWeight.w700, color: theme.ink)),
                subtitle: Text(
                  state.syncEnabled && state.backupLookupKey.isNotEmpty ? 'Chiffrement E2E activé ✓' : 'Non activée',
                  style: fw(size: 12, color: state.syncEnabled && state.backupLookupKey.isNotEmpty ? theme.success : theme.mid),
                ),
                trailing: Icon(Icons.chevron_right, color: theme.mid),
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const CloudSyncSheet(),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ── Legal ───────────────────────────────────────────────────
            _buildSectionTitle(context, t(context, 'settings_legal'), theme),
            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              child: Column(
                children: [
                  ListTile(
                    title: Text(t(context, 'settings_privacy'), style: fw(size: 16, w: FontWeight.w700, color: theme.ink)),
                    trailing: Icon(Icons.open_in_new, color: theme.mid),
                    onTap: () {
                      launchUrl(Uri.parse('https://fnnktkygl-code.github.io/pigio-app/privacy/'));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text(t(context, 'settings_terms'), style: fw(size: 16, w: FontWeight.w700, color: theme.ink)),
                    trailing: Icon(Icons.open_in_new, color: theme.mid),
                    onTap: () {
                      launchUrl(Uri.parse('https://fnnktkygl-code.github.io/pigio-app/cgu/'));
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ── Account / Logout ────────────────────────────────────────
            _buildSectionTitle(context, t(context, 'settings_account'), theme),
            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              child: Column(
                children: [
                  if (Supabase.instance.client.auth.currentUser != null) ...[
                    ListTile(
                      title: Text(
                        Supabase.instance.client.auth.currentUser?.email ?? t(context, 'settings_connected'),
                        style: fw(size: 14, color: theme.mid),
                      ),
                      leading: Icon(Icons.person_outline, color: theme.primary),
                    ),
                    const Divider(height: 1),
                  ],
                  ListTile(
                    title: Text(t(context, 'settings_sign_out'), style: fw(size: 16, w: FontWeight.w700, color: theme.error)),
                    trailing: Icon(Icons.logout, color: theme.error),
                    onTap: () => _confirmSignOut(context, state, theme),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            Text('${t(context, 'app_name')} v${AppMeta.version}', style: fw(size: 12, color: theme.light, w: FontWeight.w600)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, PigioThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title.toUpperCase(), style: fw(size: 12, w: FontWeight.w800, color: theme.mid, letterSpacing: 1.2)),
      ),
    );
  }

  // ── Sign-out with confirmation ──────────────────────────────────────────
  void _confirmSignOut(BuildContext context, PigioAppState state, PigioThemeData theme) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.card,
        title: Text(t(context, 'settings_sign_out_title', listen: false), style: fw(size: 20, w: FontWeight.w800, color: theme.ink)),
        content: Text(t(context, 'settings_sign_out_confirm', listen: false), style: fw(size: 14, color: theme.mid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t(context, 'cancel', listen: false), style: fw(size: 16, color: theme.mid)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await state.signOutAndCleanupLocalState();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
            child: Text(t(context, 'settings_sign_out', listen: false), style: fw(size: 16, w: FontWeight.w800, color: theme.error)),
          ),
        ],
      ),
    );
  }

  // ── Account deletion with confirmation + loading ─────────────────────────
  void _confirmAccountDelete(BuildContext context, PigioAppState state, PigioThemeData theme) {
    final TextEditingController confirmCtrl = TextEditingController();
    final keyword = t(context, 'settings_delete_keyword', listen: false);
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: theme.card,
            title: Text(t(context, 'settings_delete_title', listen: false), style: fw(size: 20, w: FontWeight.w800, color: theme.error)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(context, 'settings_delete_body', listen: false), style: fw(size: 14, color: theme.mid)),
                const SizedBox(height: 16),
                Text(t(context, 'settings_delete_hint', listen: false), style: fw(size: 12, w: FontWeight.w700, color: theme.error)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  decoration: InputDecoration(
                    hintText: keyword,
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.divider), borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.error), borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) => setDialogState(() {}),
                  style: fw(size: 14, color: theme.ink),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text(t(context, 'cancel', listen: false), style: fw(size: 16, color: theme.mid))),
              TextButton(
                onPressed: confirmCtrl.text == keyword ? () async {
                  Navigator.pop(c);
                  setState(() => _isDeleting = true);

                  try {
                    final session = Supabase.instance.client.auth.currentSession;
                    if (session != null) {
                      try {
                        await Supabase.instance.client.functions.invoke(
                          'account-delete',
                          method: HttpMethod.post,
                          headers: {'Authorization': 'Bearer ${session.accessToken}'},
                          body: {'syncKey': state.syncKey},
                        );
                      } catch (e) {
                        log.warn('Settings', 'account-delete edge function failed, wiping locally', e);
                      }
                    }

                    await state.deleteAccount();

                    try {
                      await Supabase.instance.client.auth.signOut();
                    } catch (e) {
                      log.warn('Settings', 'Supabase sign-out failed during deletion', e);
                    }

                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                      (route) => false,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _isDeleting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(t(context, 'settings_delete_error', listen: false))),
                    );
                  }
                } : null,
                child: _isDeleting
                    ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.error))
                    : Text(t(context, 'settings_delete_btn', listen: false), style: fw(size: 16, w: FontWeight.w800, color: confirmCtrl.text == keyword ? theme.error : theme.light)),
              ),
            ],
          );
        }
      ),
    );
  }

}

// ── THEME PICKER ──
class _ThemePicker extends StatelessWidget {
  final PigioThemeVariant currentVariant;
  final bool autoTheme;
  final ValueChanged<PigioThemeVariant> onSelect;
  final VoidCallback onAutoTheme;
  const _ThemePicker({required this.currentVariant, required this.autoTheme, required this.onSelect, required this.onAutoTheme});

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    return Column(
      children: [
        Row(
          children: [
            _ThemeChip(variant: PigioThemeVariant.light, label: t(context, 'theme_light'), icon: Icons.wb_sunny_outlined, current: currentVariant, onTap: onSelect, dimmed: autoTheme),
            const SizedBox(width: 8),
            _ThemeChip(variant: PigioThemeVariant.sepia, label: t(context, 'theme_sepia'), icon: Icons.coffee_outlined, current: currentVariant, onTap: onSelect, dimmed: autoTheme),
            const SizedBox(width: 8),
            _ThemeChip(variant: PigioThemeVariant.dark, label: t(context, 'theme_dark'), icon: Icons.nights_stay_outlined, current: currentVariant, onTap: onSelect, dimmed: autoTheme),
            const SizedBox(width: 8),
            _ThemeChip(variant: PigioThemeVariant.oled, label: t(context, 'theme_oled'), icon: Icons.circle, current: currentVariant, onTap: onSelect, dimmed: autoTheme),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: autoTheme ? null : onAutoTheme,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: autoTheme
                  ? LinearGradient(colors: [theme.primary.withValues(alpha: 0.12), theme.accent2.withValues(alpha: 0.12)])
                  : null,
              color: autoTheme ? null : theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: autoTheme ? theme.primary : Colors.transparent, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: autoTheme ? theme.primary : theme.mid),
                const SizedBox(width: 6),
                Text('Auto', style: fw(size: 12, w: FontWeight.w800, color: autoTheme ? theme.primary : theme.mid)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final PigioThemeVariant variant;
  final String label;
  final IconData icon;
  final PigioThemeVariant current;
  final ValueChanged<PigioThemeVariant> onTap;
  final bool dimmed;

  const _ThemeChip({
    required this.variant,
    required this.label,
    required this.icon,
    required this.current,
    required this.onTap,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = variant == current && !dimmed;
    final preview = PigioThemes.fromVariant(variant);

    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(variant),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: preview.scaffold,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? context.pt.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: preview.ink),
              const SizedBox(height: 12),
              Text(
                label,
                style: fw(size: 11, w: FontWeight.w800, color: preview.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Opacity(
                opacity: isActive ? 1.0 : 0.0,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.pt.primary,
                    shape: BoxShape.circle,
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

// ── LANGUAGE BUTTON ──
class _LangBtn extends StatelessWidget {
  final String lang;
  final String current;
  final VoidCallback onTap;
  const _LangBtn({required this.lang, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    bool active = lang == current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? theme.primary : theme.surface,
          borderRadius: BorderRadius.circular(PigioDesign.radiusSmall),
        ),
        child: Text(lang.toUpperCase(), style: fw(size: 14, w: FontWeight.w800, color: active ? theme.onAccent : theme.mid)),
      ),
    );
  }
}
