import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';
import 'package:pigio_app/shared/widgets/pigio_painter.dart';
import 'package:pigio_app/screens/mascot/mascot_wardrobe_screen.dart';
import 'package:pigio_app/screens/mascot/know_thyself_screen.dart';
import 'package:pigio_app/screens/mascot/mascot_memories_screen.dart';

class MascotSettingsScreen extends StatelessWidget {
  const MascotSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final bool fr = state.locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: PigioAppBar(title: "Pigio", showNotification: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview
              Center(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: PigioWidget(
                    mood: PigMood.excited,
                    size: 100,
                    scarfColor: state.mascotScarfColor,
                    outfit: state.activeOutfit,
                    outfitColors: state.outfitColors,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PigioButton(
                  label: fr ? "Habille Pigio 👕" : "Dress up Pigio 👕",
                  color: theme.primary,
                  textColor: theme.onAccent,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MascotWardrobeScreen()));
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ── KNOW THYSELF ──
              _sectionTitle(fr ? "CONNAIS-TOI" : "KNOW THYSELF", theme),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: fr ? 'Quiz : Connais-toi' : 'Quiz: Know thyself',
                child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KnowThyselfScreen())),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.primary.withValues(alpha: 0.25), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [theme.primary, theme.accent2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(child: Text('🧠', style: TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fr ? 'Quiz : Connais-toi !' : 'Quiz: Know thyself!', style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                            const SizedBox(height: 3),
                            Text(
                              state.personalityProfile.isEmpty
                                  ? (fr ? 'Réponds à 8 questions pour que Pigio te connaisse mieux' : 'Answer 8 questions so Pigio gets to know you')
                                  : '${state.personalityProfile.length * 100 ~/ 8}% ${fr ? 'complété' : 'completed'} — ${state.personalityProfile.values.fold(0, (s, v) => s + v.length)} ${fr ? 'réponses' : 'answers'}',
                              style: fw(size: 12, color: theme.mid),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        state.personalityProfile.isNotEmpty ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
                        color: state.personalityProfile.isNotEmpty ? theme.success : theme.mid,
                        size: state.personalityProfile.isNotEmpty ? 22 : 16,
                      ),
                    ],
                  ),
                ),
              ),
              ),
              const SizedBox(height: 12),

              // ── MEMORIES ──
              Semantics(
                button: true,
                label: fr ? 'Souvenirs avec Pigio' : 'Memories with Pigio',
                child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MascotMemoriesScreen())),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.primary.withValues(alpha: 0.15), width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [const Color(0xFFFFC107), theme.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(child: Text('📖', style: TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(state.locale.languageCode == 'fr' ? 'Souvenirs avec Pigio' : 'Memories with Pigio', style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                            const SizedBox(height: 3),
                            Text(
                              state.mascotMemories.isEmpty
                                  ? (state.locale.languageCode == 'fr' ? 'Aucun souvenir pour l\'instant' : 'No memories yet')
                                  : '${state.mascotMemories.length} ${state.locale.languageCode == 'fr' ? 'souvenirs' : 'memories'}',
                              style: fw(size: 12, color: theme.mid),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios_rounded, color: theme.mid, size: 16),
                    ],
                  ),
                ),
              ),
              ),
              const SizedBox(height: 32),

              // ── SPEECH ──
              _sectionTitle(fr ? "PAROLE" : "SPEECH", theme),
              const SizedBox(height: 12),
              _toggleRow(
                theme,
                icon: state.mascotVisible ? "🐧" : "🙈",
                label: fr ? "Afficher Pigio" : "Show Pigio",
                subtitle: fr ? "Active ou desactive Pigio dans l'application" : "Turn Pigio on or off across the app",
                value: state.mascotVisible,
                onChanged: (v) => state.setMascotVisible(v),
              ),
              const SizedBox(height: 12),
              _toggleRow(
                theme,
                icon: "🔇",
                label: fr ? "Mode silencieux" : "Silent mode",
                subtitle: fr ? "Pigio reste visible mais ne montre plus de bulles" : "Pigio stays visible but won't show speech bubbles",
                value: state.mascotSilent,
                onChanged: (v) => state.setMascotSilent(v),
              ),
              const SizedBox(height: 12),
              _toggleRow(
                theme,
                icon: state.mascotSoundEnabled ? "🔊" : "🔈",
                label: fr ? "Sons de Pigio" : "Pigio sounds",
                subtitle: fr ? "Joue de petits sons uniquement lors des interactions directes" : "Play short sounds only on direct interactions",
                value: state.mascotSoundEnabled,
                onChanged: (v) => state.setMascotSoundEnabled(v),
              ),
              const SizedBox(height: 12),
              _toggleRow(
                theme,
                icon: "🪶",
                label: fr ? "Mouvements reduits" : "Reduced motion",
                subtitle: fr ? "Desactive les animations et mouvements plus ludiques" : "Disables the more playful motion and animation",
                value: state.mascotReducedMotion,
                onChanged: (v) => state.setMascotReducedMotion(v),
              ),
              const SizedBox(height: 12),
              _toggleRow(
                theme,
                icon: "🔒",
                label: fr ? "Mode privé" : "Privacy mode",
                subtitle: fr ? "Pigio montre uniquement des émojis, pas de texte" : "Pigio shows only emojis, no text",
                value: state.mascotPrivacyMode,
                onChanged: (v) => state.setMascotPrivacyMode(v),
              ),
              const SizedBox(height: 16),

              // ── ATMOSPHERE ──
              _sectionTitle(fr ? "ATMOSPHÈRE" : "ATMOSPHERE", theme),
              const SizedBox(height: 12),
              _toggleRow(
                theme,
                icon: state.weatherEffectsEnabled ? "🌧" : "☀️",
                label: fr ? "Effets météo" : "Weather effects",
                subtitle: fr ? "Pluie, neige et effets visuels sur l'écran" : "Rain, snow and visual effects on screen",
                value: state.weatherEffectsEnabled,
                onChanged: (v) => state.setWeatherEffectsEnabled(v),
              ),
              const SizedBox(height: 16),

              // Chattiness
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text("🎚", style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Text(fr ? "Bavardage" : "Chattiness", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _chattinessChip(theme, state, 0, fr ? "Discret" : "Quiet"),
                        const SizedBox(width: 8),
                        _chattinessChip(theme, state, 1, "Normal"),
                        const SizedBox(width: 8),
                        _chattinessChip(theme, state, 2, fr ? "Bavard" : "Chatty"),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text("📍", style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Text(fr ? "Position par defaut" : "Default side", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _cornerChip(theme, state, 'left', fr ? 'Gauche' : 'Left'),
                        const SizedBox(width: 8),
                        _cornerChip(theme, state, 'right', fr ? 'Droite' : 'Right'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String label, PigioThemeData theme) {
    return Text(label, style: fw(size: 11, w: FontWeight.w800, color: theme.mid, letterSpacing: 1.2));
  }

  Widget _toggleRow(PigioThemeData theme, {required String icon, required String label, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: fw(size: 12, w: FontWeight.w600, color: theme.mid)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: theme.primary,
          ),
        ],
      ),
    );
  }

  Widget _chattinessChip(PigioThemeData theme, PigioAppState state, int level, String label) {
    final isActive = state.mascotChattiness == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => state.setMascotChattiness(level),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? theme.primary : theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isActive ? theme.primary : theme.divider, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(label, style: fw(size: 13, w: FontWeight.w800, color: isActive ? theme.onAccent : theme.mid)),
        ),
      ),
    );
  }

  Widget _cornerChip(PigioThemeData theme, PigioAppState state, String value, String label) {
    final isActive = state.mascotDefaultCorner == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => state.setMascotDefaultCorner(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? theme.primary : theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isActive ? theme.primary : theme.divider, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(label, style: fw(size: 13, w: FontWeight.w800, color: isActive ? theme.onAccent : theme.mid)),
        ),
      ),
    );
  }

}
