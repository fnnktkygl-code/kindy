import 'package:flutter_test/flutter_test.dart';
import 'package:kindy/core/models/app_models.dart';
import 'package:kindy/services/mascot_outfit_engine.dart';
import 'package:kindy/services/weather_service.dart';

void main() {
  group('Mascot weather outfit requests', () {
    test('rain asks for umbrella when Pigio has no rain protection', () {
      final request = MascotOutfitEngine.evaluateWeatherRequest(
        weather: WeatherData(
          temperature: 12,
          condition: 'rain',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 10),
        ),
        activeOutfit: const {},
        isUnlocked: (_) => true,
      );

      expect(request, isNotNull);
      expect(request!.item.id, 'acc_umbrella');
      expect(request.contextHint, 'Il pleut 🌧️');
    });

    test('storm asks for umbrella with storm-specific copy', () {
      final request = MascotOutfitEngine.evaluateWeatherRequest(
        weather: WeatherData(
          temperature: 16,
          condition: 'storm',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 10),
        ),
        activeOutfit: const {},
        isUnlocked: (_) => true,
      );

      expect(request, isNotNull);
      expect(request!.item.id, 'acc_umbrella');
      expect(request.contextHint, 'Orage ⛈️');
    });

    test('snow asks for thick scarf when Pigio lacks winter protection', () {
      final request = MascotOutfitEngine.evaluateWeatherRequest(
        weather: WeatherData(
          temperature: -1,
          condition: 'snow',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 10),
        ),
        activeOutfit: const {},
        isUnlocked: (_) => true,
      );

      expect(request, isNotNull);
      expect(request!.item.id, 'top_scarf_thick');
    });

    test('cold asks for winter hat when scarf is already equipped', () {
      final request = MascotOutfitEngine.evaluateWeatherRequest(
        weather: WeatherData(
          temperature: 1,
          condition: 'cloudy',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 10),
        ),
        activeOutfit: const {
          ClothingSlot.top: 'top_scarf_thick',
        },
        isUnlocked: (_) => true,
      );

      expect(request, isNotNull);
      expect(request!.item.id, 'hat_winter');
    });

    test('hot sunny weather asks for sunglasses first', () {
      final request = MascotOutfitEngine.evaluateWeatherRequest(
        weather: WeatherData(
          temperature: 29,
          condition: 'sunny',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 14),
        ),
        activeOutfit: const {},
        isUnlocked: (_) => true,
      );

      expect(request, isNotNull);
      expect(request!.item.id, 'glasses_sun');
    });

    test('extreme heat asks for hawaiian shirt after sunglasses are already equipped', () {
      final request = MascotOutfitEngine.evaluateWeatherRequest(
        weather: WeatherData(
          temperature: 35,
          condition: 'sunny',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 14),
        ),
        activeOutfit: const {
          ClothingSlot.glasses: 'glasses_sun',
        },
        isUnlocked: (_) => true,
      );

      expect(request, isNotNull);
      expect(request!.item.id, 'top_hawaiian');
    });

    test('extreme heat falls back to linen shirt when hawaiian shirt is unavailable', () {
      final request = MascotOutfitEngine.evaluateWeatherRequest(
        weather: WeatherData(
          temperature: 35,
          condition: 'sunny',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 14),
        ),
        activeOutfit: const {
          ClothingSlot.glasses: 'glasses_sun',
        },
        isUnlocked: (itemId) => itemId != 'top_hawaiian',
      );

      expect(request, isNotNull);
      expect(request!.item.id, 'top_linen');
    });

    test('storm with umbrella still asks for rain shell when Pigio is not fully covered', () {
      final request = MascotOutfitEngine.evaluateWeatherRequest(
        weather: WeatherData(
          temperature: 9,
          condition: 'storm',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 18),
        ),
        activeOutfit: const {
          ClothingSlot.accessory: 'acc_umbrella',
        },
        isUnlocked: (_) => true,
      );

      expect(request, isNotNull);
      expect(request!.item.id, 'top_raincoat');
    });

    test('very hot sun asks for a hat after sunglasses are already equipped', () {
      final request = MascotOutfitEngine.evaluateWeatherRequest(
        weather: WeatherData(
          temperature: 31,
          condition: 'sunny',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 14),
        ),
        activeOutfit: const {
          ClothingSlot.glasses: 'glasses_sun',
        },
        isUnlocked: (_) => true,
      );

      expect(request, isNotNull);
      expect(request!.item.id, 'hat_straw');
    });

    test('weather protection profile reports partial and full coverage correctly', () {
      final partial = MascotOutfitEngine.weatherProtectionFor(const {
        ClothingSlot.accessory: 'acc_umbrella',
      });
      final full = MascotOutfitEngine.weatherProtectionFor(const {
        ClothingSlot.accessory: 'acc_umbrella',
        ClothingSlot.top: 'top_raincoat',
        ClothingSlot.shoes: 'shoes_boots',
      });

      expect(partial.rainCoverage, closeTo(0.74, 0.001));
      expect(partial.stormCoverage, closeTo(0.55, 0.001));
      expect(full.rainCoverage, closeTo(1.0, 0.001));
      expect(full.stormCoverage, closeTo(1.0, 0.001));
    });

    test('returns null when Pigio is already protected for rain', () {
      final request = MascotOutfitEngine.evaluateWeatherRequest(
        weather: WeatherData(
          temperature: 11,
          condition: 'rain',
          isDay: true,
          fetchedAt: DateTime(2026, 3, 8, 10),
        ),
        activeOutfit: const {
          ClothingSlot.accessory: 'acc_umbrella',
        },
        isUnlocked: (_) => true,
      );

      expect(request, isNull);
    });
  });
}