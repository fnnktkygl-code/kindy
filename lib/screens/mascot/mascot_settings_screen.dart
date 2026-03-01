import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';
import 'package:pigio_app/shared/widgets/pigio_painter.dart';
import 'package:pigio_app/screens/mascot/mascot_wardrobe_screen.dart';
import 'package:pigio_app/screens/mascot/know_thyself_screen.dart';

class MascotSettingsScreen extends StatelessWidget {
  const MascotSettingsScreen({super.key});

  static const List<Color> scarfColors = [
    Color(0xFFFFD54F), // Yellow (default)
    Color(0xFFFF7043), // Orange
    Color(0xFFEF5350), // Red
    Color(0xFFEC407A), // Pink
    Color(0xFFAB47BC), // Purple
    Color(0xFF42A5F5), // Blue
    Color(0xFF26A69A), // Teal
    Color(0xFF66BB6A), // Green
    Color(0xFFBDBDBD), // Gray
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();

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
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: PigioButton(
                  label: "Habille Pigio 👕",
                  color: theme.primary,
                  textColor: theme.onAccent,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MascotWardrobeScreen()));
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ── KNOW THYSELF ──
              _sectionTitle("CONNAIS-TOI", theme),
              const SizedBox(height: 12),
              GestureDetector(
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
                            Text('Quiz : Connais-toi !', style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                            const SizedBox(height: 3),
                            Text(
                              state.personalityProfile.isEmpty
                                  ? 'Réponds à 8 questions pour que Pigio te connaisse mieux'
                                  : '${state.personalityProfile.length * 100 ~/ 8}% complété — ${state.personalityProfile.values.fold(0, (s, v) => s + v.length)} réponses',
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
              const SizedBox(height: 32),

              // ── SPEECH ──
              _sectionTitle("PAROLE", theme),
              const SizedBox(height: 12),
              _toggleRow(
                theme,
                icon: "🔇",
                label: "Mode silencieux",
                subtitle: "Pigio reste visible mais ne montre plus de bulles",
                value: state.mascotSilent,
                onChanged: (v) => state.setMascotSilent(v),
              ),
              const SizedBox(height: 12),
              _toggleRow(
                theme,
                icon: "🔒",
                label: "Mode privé",
                subtitle: "Pigio montre uniquement des émojis, pas de texte",
                value: state.mascotPrivacyMode,
                onChanged: (v) => state.setMascotPrivacyMode(v),
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
                        Text("Bavardage", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _chattinessChip(theme, state, 0, "Discret"),
                        const SizedBox(width: 8),
                        _chattinessChip(theme, state, 1, "Normal"),
                        const SizedBox(width: 8),
                        _chattinessChip(theme, state, 2, "Bavard"),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── APPEARANCE ──
              _sectionTitle("APPARENCE", theme),
              const SizedBox(height: 12),
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
                        const Text("🎨", style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Text("Couleur de l'écharpe", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: scarfColors.map((c) {
                        final isSelected = state.mascotScarfColor.toARGB32() == c.toARGB32();
                        return GestureDetector(
                          onTap: () => state.setMascotScarfColor(c),
                          child: Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? theme.primary : theme.divider,
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 8)]
                                  : null,
                            ),
                            child: isSelected
                                ? Icon(Icons.check, color: c.computeLuminance() > 0.5 ? Colors.black87 : Colors.white, size: 20)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
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

}
