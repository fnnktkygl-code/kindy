import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pigio_app/core/models/app_models.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/screens/mascot/mascot_settings_screen.dart';
import 'package:pigio_app/services/weather_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpLab(
    WidgetTester tester, {
    WeatherData? weather,
    WeatherData? overrideWeather,
    required ValueChanged<bool> onToggleTestMode,
    required ValueChanged<String> onConditionSelected,
    required ValueChanged<double> onTemperatureChanged,
    required ValueChanged<bool> onDayModeChanged,
    required VoidCallback onRefreshLive,
    required VoidCallback onUseLiveWeather,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 520,
              child: MascotWeatherLabCard(
                theme: PigioThemes.fromVariant(PigioThemeVariant.light),
                fr: true,
                weather: weather,
                overrideWeather: overrideWeather,
                outfit: const {
                  ClothingSlot.accessory: 'acc_umbrella',
                  ClothingSlot.top: 'top_raincoat',
                },
                outfitColors: const {},
                onToggleTestMode: onToggleTestMode,
                onConditionSelected: onConditionSelected,
                onTemperatureChanged: onTemperatureChanged,
                onDayModeChanged: onDayModeChanged,
                onRefreshLive: onRefreshLive,
                onUseLiveWeather: onUseLiveWeather,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('Mascot weather lab', () {
    testWidgets('renders weather lab controls', (tester) async {
      await pumpLab(
        tester,
        weather: WeatherData(
          temperature: 21,
          condition: 'cloudy',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 10),
        ),
        onToggleTestMode: (_) {},
        onConditionSelected: (_) {},
        onTemperatureChanged: (_) {},
        onDayModeChanged: (_) {},
        onRefreshLive: () {},
        onUseLiveWeather: () {},
      );

      expect(find.text('Laboratoire meteo Pigio'), findsOneWidget);
      expect(find.text('Mode test meteo'), findsOneWidget);
      expect(find.text('Rafraichir la vraie meteo'), findsOneWidget);
      expect(find.text('Revenir au reel'), findsOneWidget);
      expect(find.text('Pluie'), findsOneWidget);
      expect(find.text('Neige'), findsOneWidget);
      expect(find.text('Apercu direct'), findsOneWidget);
      expect(find.textContaining('Pluie '), findsOneWidget);
      expect(find.textContaining('Pose '), findsOneWidget);
    });

    testWidgets('condition chips update the weather override', (tester) async {
      String? selectedCondition;

      await pumpLab(
        tester,
        weather: WeatherData(
          temperature: 22,
          condition: 'sunny',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 10),
        ),
        overrideWeather: WeatherData(
          temperature: 22,
          condition: 'sunny',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 10),
        ),
        onToggleTestMode: (_) {},
        onConditionSelected: (value) => selectedCondition = value,
        onTemperatureChanged: (_) {},
        onDayModeChanged: (_) {},
        onRefreshLive: () {},
        onUseLiveWeather: () {},
      );

      await tester.tap(find.text('Neige'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(selectedCondition, 'snow');

      await tester.tap(find.text('Orage'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(selectedCondition, 'storm');
    });

    testWidgets('return to live weather clears override', (tester) async {
      var useLiveTapped = false;

      await pumpLab(
        tester,
        weather: WeatherData(
          temperature: 5,
          condition: 'rain',
          isDay: false,
          fetchedAt: DateTime(2026, 3, 8, 22),
        ),
        overrideWeather: WeatherData(
          temperature: 5,
          condition: 'rain',
          isDay: false,
          fetchedAt: DateTime(2026, 3, 8, 22),
        ),
        onToggleTestMode: (_) {},
        onConditionSelected: (_) {},
        onTemperatureChanged: (_) {},
        onDayModeChanged: (_) {},
        onRefreshLive: () {},
        onUseLiveWeather: () => useLiveTapped = true,
      );

      await tester.ensureVisible(find.text('Revenir au reel'));
      await tester.tap(find.text('Revenir au reel'));
      await tester.pump();

      expect(useLiveTapped, isTrue);
    });
  });
}