import 'package:pigio_app/core/state/app_state.dart';
import 'weather_service.dart';

class MascotOutfitEngine {
  static final List<ClothingItem> catalog = [
    // Hats
    const ClothingItem(id: 'hat_winter', name: 'Bonnet d\'hiver', emoji: '🥶', slot: ClothingSlot.hat),
    const ClothingItem(id: 'hat_straw', name: 'Chapeau de paille', emoji: '🌾', slot: ClothingSlot.hat),
    const ClothingItem(id: 'hat_birthday', name: 'Couronne', emoji: '👑', slot: ClothingSlot.hat),
    const ClothingItem(id: 'hat_santa', name: 'Bonnet de Noël', emoji: '🎅', slot: ClothingSlot.hat),
    const ClothingItem(id: 'hat_witch', name: 'Sorcière', emoji: '🎃', slot: ClothingSlot.hat),
    // Glasses
    const ClothingItem(id: 'glasses_sun', name: 'Lunettes de soleil', emoji: '🕶️', slot: ClothingSlot.glasses),
    const ClothingItem(id: 'glasses_heart', name: 'Lunettes cœur', emoji: '💕', slot: ClothingSlot.glasses),
    const ClothingItem(id: 'glasses_reading', name: 'Lunettes lecture', emoji: '👓', slot: ClothingSlot.glasses),
    // Tops
    const ClothingItem(id: 'top_raincoat', name: 'Imperméable', emoji: '🧥', slot: ClothingSlot.top),
    const ClothingItem(id: 'top_scarf_thick', name: 'Écharpe polaire', emoji: '🧣', slot: ClothingSlot.top),
    const ClothingItem(id: 'top_hawaiian', name: 'Chemise hawaïenne', emoji: '🏖️', slot: ClothingSlot.top),
    const ClothingItem(id: 'top_pyjama', name: 'Pyjama', emoji: '🥱', slot: ClothingSlot.top),
    // Shoes
    const ClothingItem(id: 'shoes_boots', name: 'Bottes de pluie', emoji: '🥾', slot: ClothingSlot.shoes),
    const ClothingItem(id: 'shoes_flipflops', name: 'Tongs', emoji: '🩴', slot: ClothingSlot.shoes),
    const ClothingItem(id: 'shoes_slippers', name: 'Chaussons', emoji: '🧦', slot: ClothingSlot.shoes),
    // Accessories
    const ClothingItem(id: 'acc_umbrella', name: 'Parapluie', emoji: '☂️', slot: ClothingSlot.accessory),
    const ClothingItem(id: 'acc_flowers', name: 'Bouquet', emoji: '💐', slot: ClothingSlot.accessory),
    const ClothingItem(id: 'acc_flag', name: 'Drapeau tricolore', emoji: '🇫🇷', slot: ClothingSlot.accessory),
    const ClothingItem(id: 'acc_pumpkin', name: 'Citrouille', emoji: '🎃', slot: ClothingSlot.accessory),
    const ClothingItem(id: 'acc_star', name: 'Étoile magique', emoji: '🌟', slot: ClothingSlot.accessory),
  ];

  static ClothingItem? getItem(String id) => catalog.where((c) => c.id == id).firstOrNull;

  static Future<ClothingRequest?> evaluateContext(PigioAppState state) async {
    final now = DateTime.now();
    final weather = await WeatherService.fetchCurrent();

    // 1. Events
    // User's birthday
    if (state.profile.birthdate != null && state.profile.birthdate!.isNotEmpty) {
      final parts = state.profile.birthdate!.split('/');
      if (parts.length >= 2) {
        if (int.tryParse(parts[0]) == now.day && int.tryParse(parts[1]) == now.month) {
          if (!state.activeOutfit.containsValue('hat_birthday')) {
            return ClothingRequest(
              item: getItem('hat_birthday')!, 
              bubbleTextFr: "C'est ton anniversaire ! Mets-moi ma couronne 👑", 
              bubbleTextEn: "It's your birthday! Give me my crown 👑", 
              contextHint: "Ton anniversaire 🎂"
            );
          }
        }
      }
    }

    // Holidays
    if (now.month == 12 && now.day >= 1) {
      if (!state.activeOutfit.containsValue('hat_santa')) {
        return ClothingRequest(
          item: getItem('hat_santa')!, 
          bubbleTextFr: "Bientôt Noël ! Je peux avoir mon bonnet ? 🎅", 
          bubbleTextEn: "Christmas soon! Can I have my hat? 🎅", 
          contextHint: "Période de Noël 🎄"
        );
      }
    }
    if (now.month == 10 && now.day >= 25) {
      if (!state.activeOutfit.containsValue('acc_pumpkin')) {
        return ClothingRequest(
          item: getItem('acc_pumpkin')!, 
          bubbleTextFr: "Des bonbons ou un sort ! 🎃", 
          bubbleTextEn: "Trick or treat! 🎃", 
          contextHint: "Halloween 🦇"
        );
      }
    }
    if (now.month == 2 && now.day >= 10 && now.day <= 15) {
      if (!state.activeOutfit.containsValue('glasses_heart')) {
         return ClothingRequest(
          item: getItem('glasses_heart')!, 
          bubbleTextFr: "De l'amour dans l'air 💕", 
          bubbleTextEn: "Love is in the air 💕", 
          contextHint: "Saint Valentin 💘"
        );
      }
    }

    // 2. Weather
    if (weather != null) {
      if (weather.condition == 'rain' && !state.activeOutfit.containsValue('acc_umbrella') && !state.activeOutfit.containsValue('top_raincoat')) {
         return ClothingRequest(
          item: getItem('acc_umbrella')!, 
          bubbleTextFr: "Il pleut dehors 🌧️ Je veux mon parapluie !", 
          bubbleTextEn: "It's raining outside 🌧️ I need my umbrella!", 
          contextHint: "Il pleut 🌧️"
        );
      }
      if (weather.temperature < 5 && !state.activeOutfit.containsValue('hat_winter')) {
         return ClothingRequest(
          item: getItem('hat_winter')!, 
          bubbleTextFr: "Brrr il fait ${weather.temperature.round()}°C 🥶 Un bonnet ?", 
          bubbleTextEn: "Brrr it's ${weather.temperature.round()}°C 🥶 A hat?", 
          contextHint: "Froid polaire ❄️"
        );
      }
      if (weather.temperature > 25 && weather.condition == 'sunny' && !state.activeOutfit.containsValue('glasses_sun')) {
         return ClothingRequest(
          item: getItem('glasses_sun')!, 
          bubbleTextFr: "Ça tape aujourd'hui ! 😎 Vite, mes lunettes !", 
          bubbleTextEn: "It's scorching today! 😎 Quick, my sunglasses!", 
          contextHint: "Grand soleil ☀️"
        );
      }
    }

    // 3. Time of day
    if (now.hour >= 23 || now.hour < 5) {
       if (!state.activeOutfit.containsValue('top_pyjama')) {
         return ClothingRequest(
          item: getItem('top_pyjama')!, 
          bubbleTextFr: "Quelle heure est-il ? 🥱 Pyjama time...", 
          bubbleTextEn: "What time is it? 🥱 Pyjama time...", 
          contextHint: "Tard la nuit 🌙"
        );
       }
    }

    return null;
  }
}
