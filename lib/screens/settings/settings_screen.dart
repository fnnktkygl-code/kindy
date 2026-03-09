import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/core/i18n/i18n.dart';
import 'package:pigio_app/screens/mascot/mascot_settings_screen.dart';
import 'package:pigio_app/screens/auth/splash_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
            // Appearance
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



            // Language
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
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Pigio
            _buildSectionTitle(context, "PIGIO", theme),
            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              child: ListTile(
                leading: const Text("🎁", style: TextStyle(fontSize: 22)),
                title: Text(state.locale.languageCode == 'fr' ? "Réglages de Pigio" : "Pigio Settings", style: fw(size: 16, w: FontWeight.w700, color: theme.ink)),
                subtitle: Text(state.locale.languageCode == 'fr' ? "Bavardage, écharpe, position..." : "Chattiness, scarf, position...", style: fw(size: 12, color: theme.mid)),
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
                  Text('Wizz', style: fw(size: 16, w: FontWeight.w800, color: theme.ink)),
                  const SizedBox(height: 4),
                  Text('Choisissez le style d\'effet Wizz reçu.', style: fw(size: 12, color: theme.mid)),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        state.triggerIncomingWizzTest();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Test Wizz reçu déclenché ⚡')),
                        );
                      },
                      icon: const Text('🧪'),
                      label: const Text('Tester un Wizz reçu maintenant'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.accent1,
                        side: BorderSide(color: theme.accent1.withValues(alpha: 0.45)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Data
            _buildSectionTitle(context, t(context, 'settings_data'), theme),
            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              child: Column(
                children: [
                  ListTile(
                    title: Text(t(context, 'settings_reset_data'), style: fw(size: 16, w: FontWeight.w700, color: theme.error)),
                    subtitle: Text(t(context, 'settings_reset_sub'), style: fw(size: 12, color: theme.mid)),
                    trailing: Icon(Icons.delete_outline, color: theme.error),
                    onTap: () => _confirmReset(context, state, theme),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text("Relancer l'onboarding", style: fw(size: 16, w: FontWeight.w700, color: theme.ink)),
                    subtitle: Text("Affiche à nouveau le parcours d'accueil au prochain lancement", style: fw(size: 12, color: theme.mid)),
                    trailing: Icon(Icons.replay_outlined, color: theme.primary),
                    onTap: () => _confirmOnboardingReset(context, state, theme),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text("Exporter mes données", style: fw(size: 16, w: FontWeight.w700, color: theme.ink)),
                    subtitle: Text("Télécharger une copie de vos données (JSON)", style: fw(size: 12, color: theme.mid)),
                    trailing: Icon(Icons.download_outlined, color: theme.primary),
                    onTap: () async {
                      final session = Supabase.instance.client.auth.currentSession;
                      if (session == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vous devez être connecté pour exporter vos données')),
                        );
                        return;
                      }
                      try {
                        await Supabase.instance.client.functions.invoke(
                          'account-export',
                          headers: {'Authorization': 'Bearer ${session.accessToken}'},
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Export réussi — données disponibles')),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: ${e.toString()}')),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text("Supprimer mon compte", style: fw(size: 16, w: FontWeight.w700, color: theme.error)),
                    subtitle: Text("Action irréversible — toutes vos données seront effacées", style: fw(size: 12, color: theme.mid)),
                    trailing: Icon(Icons.warning_amber_rounded, color: theme.error),
                    onTap: () => _confirmAccountDelete(context, state, theme),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Legal
            _buildSectionTitle(context, "Légal", theme),
            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              child: Column(
                children: [
                  ListTile(
                    title: Text("Politique de confidentialité", style: fw(size: 16, w: FontWeight.w700, color: theme.ink)),
                    trailing: Icon(Icons.open_in_new, color: theme.mid),
                    onTap: () {
                      launchUrl(Uri.parse('https://fnnktkygl-code.github.io/pigio-app/privacy/'));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: Text("Conditions générales d'utilisation", style: fw(size: 16, w: FontWeight.w700, color: theme.ink)),
                    trailing: Icon(Icons.open_in_new, color: theme.mid),
                    onTap: () {
                      launchUrl(Uri.parse('https://fnnktkygl-code.github.io/pigio-app/cgu/'));
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Account / Logout
            _buildSectionTitle(context, "Compte", theme),
            Container(
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(PigioDesign.radiusMedium)),
              child: Column(
                children: [
                  if (Supabase.instance.client.auth.currentUser != null) ...[
                    ListTile(
                      title: Text(
                        Supabase.instance.client.auth.currentUser?.email ?? "Connecté",
                        style: fw(size: 14, color: theme.mid),
                      ),
                      leading: Icon(Icons.person_outline, color: theme.primary),
                    ),
                    const Divider(height: 1),
                  ],
                  ListTile(
                    title: Text("Se déconnecter", style: fw(size: 16, w: FontWeight.w700, color: theme.error)),
                    trailing: Icon(Icons.logout, color: theme.error),
                    onTap: () async {
                      await state.signOutAndCleanupLocalState();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const SplashScreen()),
                        (route) => false,
                      );
                    },
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

  void _confirmAccountDelete(BuildContext context, PigioAppState state, PigioThemeData theme) {
    final TextEditingController confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: theme.card,
            title: Text("Supprimer votre compte ?", style: fw(size: 20, w: FontWeight.w800, color: theme.error)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Cette action est irréversible. Toutes vos données seront définitivement supprimées.", style: fw(size: 14, color: theme.mid)),
                const SizedBox(height: 16),
                Text("Tapez 'SUPPRIMER' pour confirmer :", style: fw(size: 12, w: FontWeight.w700, color: theme.error)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  decoration: InputDecoration(
                    hintText: "SUPPRIMER",
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.divider), borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.error), borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) => setState(() {}),
                  style: fw(size: 14, color: theme.ink),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text("Annuler", style: fw(size: 16, color: theme.mid))),
              TextButton(
                onPressed: confirmCtrl.text == 'SUPPRIMER' ? () async {
                  Navigator.pop(c);
                  try {
                    // Best-effort: call the server-side deletion function if
                    // we have a live Supabase session (deletes the auth user
                    // from the database). Silently ignored when offline/anon.
                    final session = Supabase.instance.client.auth.currentSession;
                    if (session != null) {
                      try {
                        await Supabase.instance.client.functions.invoke(
                          'account-delete',
                          method: HttpMethod.post,
                          headers: {'Authorization': 'Bearer ${session.accessToken}'},
                          // Pass syncKey so the Edge Function can delete user_data
                          // (user_data table is keyed by sync_key, not user_id).
                          body: {'syncKey': state.syncKey},
                        );
                      } catch (_) {
                        // If edge function fails, still wipe locally
                      }
                    }

                    // Wipe all local state and SharedPreferences
                    await state.deleteAccount();

                    // Sign out of Supabase auth so the session is invalidated
                    // locally (prevents the splash screen from auto-logging in).
                    try {
                      await Supabase.instance.client.auth.signOut();
                    } catch (_) {}

                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SplashScreen()),
                      (route) => false,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Une erreur est survenue. Réessaie.')),
                    );
                  }
                } : null,
                child: Text("Supprimer", style: fw(size: 16, w: FontWeight.w800, color: confirmCtrl.text == 'SUPPRIMER' ? theme.error : theme.light)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _confirmReset(BuildContext context, PigioAppState state, PigioThemeData theme) {
    final TextEditingController confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: theme.card,
            title: Text(t(context, 'settings_reset_title'), style: fw(size: 20, w: FontWeight.w800, color: theme.ink)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t(context, 'settings_reset_confirm'), style: fw(size: 14, color: theme.mid)),
                const SizedBox(height: 16),
                Text("Veuillez taper 'SUPPRIMER' pour confirmer :", style: fw(size: 12, w: FontWeight.w700, color: theme.error)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmCtrl,
                  decoration: InputDecoration(
                    hintText: "SUPPRIMER",
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.divider), borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: theme.error), borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (val) => setState(() {}),
                  style: fw(size: 14, color: theme.ink),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text(t(context, 'cancel'), style: fw(size: 16, color: theme.mid))),
              TextButton(
                onPressed: confirmCtrl.text == 'SUPPRIMER' ? () {
                  state.clearData();
                  Navigator.pop(c);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(context, 'settings_reset_done'))));
                } : null,
                child: Text(t(context, 'settings_reset_btn'), style: fw(size: 16, w: FontWeight.w800, color: confirmCtrl.text == 'SUPPRIMER' ? theme.error : theme.light)),
              ),
            ],
          );
        }
      ),
    );
  }

  void _confirmOnboardingReset(BuildContext context, PigioAppState state, PigioThemeData theme) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.card,
        title: Text("Relancer l'onboarding ?", style: fw(size: 20, w: FontWeight.w800, color: theme.ink)),
        content: Text(
          "Le parcours d'accueil sera affiché à nouveau au prochain écran.",
          style: fw(size: 14, color: theme.mid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text("Annuler", style: fw(size: 16, color: theme.mid)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await state.resetOnboardingForDebug();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Onboarding réinitialisé")),
              );
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SplashScreen()),
                (route) => false,
              );
            },
            child: Text("Confirmer", style: fw(size: 16, w: FontWeight.w800, color: theme.primary)),
          ),
        ],
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
            _ThemeChip(variant: PigioThemeVariant.light, label: 'Clair', icon: Icons.wb_sunny_outlined, current: currentVariant, onTap: onSelect, dimmed: autoTheme),
            const SizedBox(width: 8),
            _ThemeChip(variant: PigioThemeVariant.sepia, label: 'Sépia', icon: Icons.coffee_outlined, current: currentVariant, onTap: onSelect, dimmed: autoTheme),
            const SizedBox(width: 8),
            _ThemeChip(variant: PigioThemeVariant.dark, label: 'Sombre', icon: Icons.nights_stay_outlined, current: currentVariant, onTap: onSelect, dimmed: autoTheme),
            const SizedBox(width: 8),
            _ThemeChip(variant: PigioThemeVariant.oled, label: 'OLED', icon: Icons.circle, current: currentVariant, onTap: onSelect, dimmed: autoTheme),
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
              // Indicator dot
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
        // Ensures the text color contrasts properly based on the dynamic primary color chosen
        child: Text(lang.toUpperCase(), style: fw(size: 14, w: FontWeight.w800, color: active ? theme.onAccent : theme.mid)),
      ),
    );
  }
}
