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
import 'package:pigio_app/services/mascot_outfit_engine.dart';
import 'package:pigio_app/services/weather_service.dart';

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
              const SizedBox(height: 16),
              MascotWeatherLabCard(
                theme: theme,
                fr: fr,
                weather: state.currentWeather,
                overrideWeather: state.weatherTestOverride,
                outfit: state.activeOutfit,
                outfitColors: state.outfitColors,
                onToggleTestMode: (v) {
                  if (v) {
                    final weather = state.currentWeather;
                    state.setWeatherTestOverride(
                      WeatherData(
                        temperature: state.weatherTestOverride?.temperature ?? weather?.temperature ?? 22,
                        condition: state.weatherTestOverride?.condition ?? weather?.condition ?? 'sunny',
                        isDay: state.weatherTestOverride?.isDay ?? weather?.isDay ?? true,
                        fetchedAt: DateTime.now(),
                      ),
                    );
                  } else {
                    state.clearWeatherTestOverride();
                  }
                },
                onConditionSelected: (condition) => state.updateWeatherTestOverride(condition: condition),
                onTemperatureChanged: (value) => state.updateWeatherTestOverride(temperature: value),
                onDayModeChanged: (value) => state.updateWeatherTestOverride(isDay: value),
                onRefreshLive: () => state.fetchWeather(),
                onUseLiveWeather: () {
                  state.clearWeatherTestOverride();
                  state.fetchWeather();
                },
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

class MascotWeatherLabCard extends StatelessWidget {
  final PigioThemeData theme;
  final bool fr;
  final WeatherData? weather;
  final WeatherData? overrideWeather;
  final Map<ClothingSlot, String?> outfit;
  final Map<String, int> outfitColors;
  final ValueChanged<bool> onToggleTestMode;
  final ValueChanged<String> onConditionSelected;
  final ValueChanged<double> onTemperatureChanged;
  final ValueChanged<bool> onDayModeChanged;
  final VoidCallback onRefreshLive;
  final VoidCallback onUseLiveWeather;

  const MascotWeatherLabCard({
    super.key,
    required this.theme,
    required this.fr,
    required this.weather,
    required this.overrideWeather,
    required this.outfit,
    required this.outfitColors,
    required this.onToggleTestMode,
    required this.onConditionSelected,
    required this.onTemperatureChanged,
    required this.onDayModeChanged,
    required this.onRefreshLive,
    required this.onUseLiveWeather,
  });

  bool get weatherTestMode => overrideWeather != null;

  @override
  Widget build(BuildContext context) {
    final activeCondition = overrideWeather?.condition ?? weather?.condition ?? 'sunny';
    final activeTemp = overrideWeather?.temperature ?? weather?.temperature ?? 22;
    final activeIsDay = overrideWeather?.isDay ?? weather?.isDay ?? true;
    final activeWeather = WeatherData(
      temperature: activeTemp,
      condition: activeCondition,
      isDay: activeIsDay,
      fetchedAt: overrideWeather?.fetchedAt ?? weather?.fetchedAt ?? DateTime.now(),
    );
    final protection = MascotOutfitEngine.weatherProtectionFor(outfit);
    final exposure = _weatherExposureFor(activeWeather, protection);
    final pose = _weatherPoseFor(activeWeather, protection);
    final mood = _weatherMoodFor(activeWeather, protection);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌦️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(fr ? 'Laboratoire meteo Pigio' : 'Pigio weather lab', style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            weatherTestMode
                ? (fr ? 'Mode test actif : Pigio suit la meteo simulee ci-dessous.' : 'Test mode is active: Pigio follows the simulated weather below.')
                : (fr ? 'Utilise la vraie meteo ou force pluie, neige, soleil, chaleur et orage.' : 'Use real weather or force rain, snow, sun, heat, and storm.'),
            style: fw(size: 12, color: theme.mid),
          ),
          const SizedBox(height: 12),
          _toggleRow(
            icon: weatherTestMode ? '🧪' : '🌍',
            label: fr ? 'Mode test meteo' : 'Weather test mode',
            subtitle: fr ? 'Remplace temporairement la vraie meteo pour tester Pigio' : 'Temporarily replace live weather to test Pigio',
            value: weatherTestMode,
            onChanged: onToggleTestMode,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _weatherChip(activeCondition, 'sunny', '☀️', fr ? 'Soleil' : 'Sunny'),
              _weatherChip(activeCondition, 'cloudy', '⛅', fr ? 'Nuages' : 'Cloudy'),
              _weatherChip(activeCondition, 'rain', '🌧️', fr ? 'Pluie' : 'Rain'),
              _weatherChip(activeCondition, 'snow', '❄️', fr ? 'Neige' : 'Snow'),
              _weatherChip(activeCondition, 'storm', '⛈️', fr ? 'Orage' : 'Storm'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.primary.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fr ? 'Apercu direct' : 'Live preview', style: fw(size: 13, w: FontWeight.w800, color: theme.ink)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 110,
                      height: 130,
                      decoration: BoxDecoration(
                        color: theme.card,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: PigioWidget(
                          mood: mood,
                          pose: pose,
                          size: 78,
                          outfit: outfit,
                          outfitColors: outfitColors,
                          weatherCondition: activeCondition,
                          weatherExposure: exposure,
                          weatherIsDay: activeIsDay,
                          weatherTemperature: activeTemp,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _metricChip(fr ? 'Pluie' : 'Rain', '${(protection.rainCoverage * 100).round()}%', '🌧️'),
                          _metricChip(fr ? 'Neige' : 'Snow', '${(protection.snowCoverage * 100).round()}%', '❄️'),
                          _metricChip(fr ? 'Soleil' : 'Sun', '${(protection.sunCoverage * 100).round()}%', '☀️'),
                          _metricChip(fr ? 'Exposition' : 'Exposure', '${(exposure * 100).round()}%', '🎯'),
                          _metricChip(fr ? 'Pose' : 'Pose', _poseLabel(fr, pose), '🕺'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            fr ? 'Temperature : ${activeTemp.round()}°C' : 'Temperature: ${activeTemp.round()}°C',
            style: fw(size: 13, w: FontWeight.w700, color: theme.ink),
          ),
          Slider(
            value: activeTemp.clamp(-10, 40),
            min: -10,
            max: 40,
            divisions: 50,
            label: '${activeTemp.round()}°C',
            activeColor: theme.primary,
            onChanged: weatherTestMode ? onTemperatureChanged : null,
          ),
          const SizedBox(height: 4),
          _toggleRow(
            icon: activeIsDay ? '🌞' : '🌙',
            label: fr ? 'Jour / nuit' : 'Day / night',
            subtitle: fr ? 'Change les effets de soleil pour tester Pigio' : 'Change sunlight effects to test Pigio',
            value: activeIsDay,
            onChanged: weatherTestMode ? onDayModeChanged : (_) {},
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _labButton(
                  label: fr ? 'Rafraichir la vraie meteo' : 'Refresh live weather',
                  background: theme.surface,
                  foreground: theme.ink,
                  onTap: onRefreshLive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _labButton(
                  label: fr ? 'Revenir au reel' : 'Use live weather',
                  background: theme.primary,
                  foreground: theme.onAccent,
                  onTap: onUseLiveWeather,
                ),
              ),
            ],
          ),
          if (weather != null) ...[
            const SizedBox(height: 12),
            Text(
              fr
                  ? 'Meteo active : ${_conditionLabel(fr, weather!.condition)} • ${weather!.temperature.round()}°C • ${weather!.isDay ? 'jour' : 'nuit'}'
                  : 'Active weather: ${_conditionLabel(fr, weather!.condition)} • ${weather!.temperature.round()}°C • ${weather!.isDay ? 'day' : 'night'}',
              style: fw(size: 12, color: theme.mid),
            ),
          ],
        ],
      ),
    );
  }

  PigPose _weatherPoseFor(WeatherData weather, WeatherProtectionProfile protection) {
    if (protection.hasUmbrella && (weather.condition == 'rain' || weather.condition == 'storm')) {
      return PigPose.umbrellaBrace;
    }
    if ((weather.condition == 'snow' || weather.temperature <= 4) && protection.snowCoverage >= 0.7) {
      return PigPose.coldTucked;
    }
    if (weather.temperature >= 29 && protection.sunCoverage >= 0.8) {
      return PigPose.sunRelaxed;
    }
    return PigPose.normal;
  }

  double _weatherExposureFor(WeatherData weather, WeatherProtectionProfile protection) {
    switch (weather.condition) {
      case 'storm':
        return (1 - protection.stormCoverage).clamp(0.0, 1.0);
      case 'rain':
        return (1 - protection.rainCoverage).clamp(0.0, 1.0);
      case 'snow':
        return (1 - protection.snowCoverage).clamp(0.0, 1.0);
      case 'sunny':
      case 'cloudy':
        if (weather.isDay && weather.temperature >= 29) {
          final heatFactor = ((weather.temperature - 29) / 9).clamp(0.2, 1.0);
          return ((1 - protection.sunCoverage) * heatFactor).clamp(0.0, 1.0);
        }
        return 0.0;
      default:
        return 0.0;
    }
  }

  PigMood _weatherMoodFor(WeatherData weather, WeatherProtectionProfile protection) {
    if (weather.condition == 'storm' && protection.stormCoverage < 0.7) return PigMood.sad;
    if (weather.condition == 'storm' && protection.stormCoverage >= 0.9) return PigMood.thinking;
    if (weather.condition == 'rain' && protection.rainCoverage < 0.65) return PigMood.sad;
    if (weather.condition == 'rain' && protection.rainCoverage >= 0.88) return PigMood.thinking;
    if (weather.condition == 'snow' && protection.snowCoverage < 0.65) return PigMood.sad;
    if (weather.condition == 'snow' && protection.snowCoverage >= 0.88) return PigMood.love;
    if (weather.temperature > 28 && protection.sunCoverage < 0.55) return PigMood.sad;
    if (weather.temperature > 28 && protection.sunCoverage >= 0.82) return PigMood.thumbsUp;
    return PigMood.normal;
  }

  String _poseLabel(bool fr, PigPose pose) {
    switch (pose) {
      case PigPose.coldTucked:
        return fr ? 'Tasse' : 'Tucked';
      case PigPose.sunRelaxed:
        return fr ? 'Detendu' : 'Relaxed';
      case PigPose.umbrellaBrace:
        return fr ? 'Sous parapluie' : 'Umbrella';
      case PigPose.normal:
        return fr ? 'Normal' : 'Normal';
    }
  }

  Widget _metricChip(String label, String value, String emoji) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text('$label $value', style: fw(size: 11, w: FontWeight.w700, color: theme.ink)),
        ],
      ),
    );
  }

  Widget _toggleRow({
    required String icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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

  Widget _weatherChip(String activeCondition, String condition, String emoji, String label) {
    final active = activeCondition == condition;
    return GestureDetector(
      onTap: weatherTestMode ? () => onConditionSelected(condition) : null,
      child: Opacity(
        opacity: weatherTestMode ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? theme.primary.withValues(alpha: 0.14) : theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? theme.primary : theme.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(label, style: fw(size: 12, w: FontWeight.w700, color: active ? theme.primary : theme.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labButton({
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.primary.withValues(alpha: 0.12)),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: fw(size: 13, w: FontWeight.w800, color: foreground),
            ),
          ),
        ),
      ),
    );
  }

  String _conditionLabel(bool fr, String condition) {
    switch (condition) {
      case 'sunny':
        return fr ? 'soleil' : 'sunny';
      case 'cloudy':
        return fr ? 'nuageux' : 'cloudy';
      case 'rain':
        return fr ? 'pluie' : 'rain';
      case 'snow':
        return fr ? 'neige' : 'snow';
      case 'storm':
        return fr ? 'orage' : 'storm';
      default:
        return condition;
    }
  }
}
