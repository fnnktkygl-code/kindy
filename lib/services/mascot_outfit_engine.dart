import 'package:pigio_app/core/state/app_state.dart';
import 'weather_service.dart';

// ─── ACHIEVEMENT DEFINITIONS ──────────────────────────────────────────────────
class Achievement {
  final String id;
  final String unlockItemId;
  final String hintFr;
  final String hintEn;
  final bool Function(PigioAppState state) check;

  const Achievement({
    required this.id,
    required this.unlockItemId,
    required this.hintFr,
    required this.hintEn,
    required this.check,
  });
}

// ─── SMART COMBO DEFINITIONS ──────────────────────────────────────────────────
class OutfitCombo {
  final String nameFr;
  final String nameEn;
  final List<String> itemIds;
  final List<String> tags;

  const OutfitCombo({
    required this.nameFr,
    required this.nameEn,
    required this.itemIds,
    this.tags = const [],
  });
}

class WeatherProtectionProfile {
  final bool hasUmbrella;
  final bool hasRaincoat;
  final bool hasWindbreaker;
  final bool hasWinterHat;
  final bool hasWarmScarf;
  final bool hasSunglasses;
  final bool hasStrawHat;
  final bool hasBucketHat;
  final bool hasHawaiianShirt;
  final bool hasLinenShirt;
  final bool hasWaterproofShoes;
  final bool hasSandals;

  const WeatherProtectionProfile({
    required this.hasUmbrella,
    required this.hasRaincoat,
    required this.hasWindbreaker,
    required this.hasWinterHat,
    required this.hasWarmScarf,
    required this.hasSunglasses,
    required this.hasStrawHat,
    required this.hasBucketHat,
    required this.hasHawaiianShirt,
    required this.hasLinenShirt,
    required this.hasWaterproofShoes,
    required this.hasSandals,
  });

  bool get hasRainShell => hasRaincoat || hasWindbreaker;
  bool get hasStormShell => hasRaincoat || hasWindbreaker;
  bool get hasSunHat => hasStrawHat || hasBucketHat;
  bool get hasBreathableTop => hasHawaiianShirt || hasLinenShirt;

  double get rainCoverage {
    if (hasUmbrella && hasRaincoat) return 1.0;
    if (hasUmbrella && hasWindbreaker) return 0.94;
    if (hasUmbrella) return 0.74;
    if (hasRaincoat) return 0.64;
    if (hasWindbreaker) return 0.42;
    return 0.0;
  }

  double get stormCoverage {
    if (hasUmbrella && hasRaincoat && hasWaterproofShoes) return 1.0;
    if (hasUmbrella && hasRaincoat) return 0.92;
    if (hasUmbrella && hasWindbreaker) return 0.82;
    if (hasRaincoat && hasWaterproofShoes) return 0.7;
    if (hasUmbrella) return 0.55;
    if (hasRainShell) return 0.45;
    return 0.0;
  }

  double get snowCoverage {
    double score = 0.0;
    if (hasWinterHat) score += 0.34;
    if (hasWarmScarf) score += 0.34;
    if (hasWaterproofShoes) score += 0.22;
    if (hasRaincoat) score += 0.1;
    return score.clamp(0.0, 1.0);
  }

  double get sunCoverage {
    double score = 0.0;
    if (hasSunglasses) score += 0.34;
    if (hasSunHat) score += 0.33;
    if (hasBreathableTop) score += 0.23;
    if (hasSandals) score += 0.1;
    return score.clamp(0.0, 1.0);
  }
}

// ─── MAIN ENGINE ──────────────────────────────────────────────────────────────
class MascotOutfitEngine {
  static final List<ClothingItem> catalog = [
    // Hats
    const ClothingItem(id: 'hat_winter', name: 'Bonnet d\'hiver', emoji: '🥶', slot: ClothingSlot.hat, tags: ['hiver', 'froid']),
    const ClothingItem(id: 'hat_straw', name: 'Chapeau de paille', emoji: '🌾', slot: ClothingSlot.hat, tags: ['été', 'soleil']),
    const ClothingItem(id: 'hat_bucket', name: 'Bob anti-UV', emoji: '🪣', slot: ClothingSlot.hat, tags: ['été', 'soleil', 'pluie']),
    const ClothingItem(id: 'hat_birthday', name: 'Couronne', emoji: '👑', slot: ClothingSlot.hat, rarity: ItemRarity.rare, isUnlocked: false, unlockHint: 'Remplis ton profil anniversaire', tags: ['fête', 'anniversaire']),
    const ClothingItem(id: 'hat_santa', name: 'Bonnet de Noël', emoji: '🎅', slot: ClothingSlot.hat, rarity: ItemRarity.uncommon, season: 'winter', tags: ['noël', 'hiver']),
    const ClothingItem(id: 'hat_witch', name: 'Sorcière', emoji: '🧙', slot: ClothingSlot.hat, rarity: ItemRarity.uncommon, season: 'autumn', tags: ['halloween']),
    const ClothingItem(id: 'hat_party', name: 'Chapeau de fête', emoji: '🥳', slot: ClothingSlot.hat, rarity: ItemRarity.uncommon, tags: ['fête', 'nouvel an']),
    const ClothingItem(id: 'hat_nightcap', name: 'Bonnet de nuit', emoji: '🌙', slot: ClothingSlot.hat, rarity: ItemRarity.uncommon, isUnlocked: false, unlockHint: 'Atteins le niveau d\'amitié "Ami"', tags: ['nuit', 'cozy']),
    const ClothingItem(id: 'hat_detective', name: 'Chapeau détective', emoji: '🔍', slot: ClothingSlot.hat, rarity: ItemRarity.rare, isUnlocked: false, unlockHint: 'Atteins le niveau d\'amitié "BFF"', tags: ['mystère', 'spécial']),
    // Glasses
    const ClothingItem(id: 'glasses_sun', name: 'Lunettes de soleil', emoji: '🕶️', slot: ClothingSlot.glasses, tags: ['été', 'soleil']),
    const ClothingItem(id: 'glasses_heart', name: 'Lunettes cœur', emoji: '💕', slot: ClothingSlot.glasses, rarity: ItemRarity.uncommon, tags: ['amour', 'valentin']),
    const ClothingItem(id: 'glasses_reading', name: 'Lunettes lecture', emoji: '👓', slot: ClothingSlot.glasses, tags: ['calme', 'lecture']),
    // Tops
    const ClothingItem(id: 'top_raincoat', name: 'Imperméable', emoji: '🧥', slot: ClothingSlot.top, tags: ['pluie', 'automne']),
    const ClothingItem(id: 'top_windbreaker', name: 'Coupe-vent', emoji: '🌬️', slot: ClothingSlot.top, tags: ['pluie', 'vent', 'mi-saison']),
    const ClothingItem(id: 'top_scarf_thick', name: 'Écharpe polaire', emoji: '🧣', slot: ClothingSlot.top, tags: ['hiver', 'froid']),
    const ClothingItem(id: 'top_hawaiian', name: 'Chemise hawaïenne', emoji: '🏖️', slot: ClothingSlot.top, tags: ['été', 'vacances']),
    const ClothingItem(id: 'top_linen', name: 'Chemise de lin', emoji: '🌤️', slot: ClothingSlot.top, tags: ['été', 'respirant', 'soleil']),
    const ClothingItem(id: 'top_pyjama', name: 'Pyjama', emoji: '🥱', slot: ClothingSlot.top, tags: ['nuit', 'cozy']),
    // Shoes
    const ClothingItem(id: 'shoes_boots', name: 'Bottes de pluie', emoji: '🥾', slot: ClothingSlot.shoes, tags: ['pluie', 'automne']),
    const ClothingItem(id: 'shoes_flipflops', name: 'Tongs', emoji: '🩴', slot: ClothingSlot.shoes, tags: ['été', 'plage']),
    const ClothingItem(id: 'shoes_sandals', name: 'Sandales', emoji: '👡', slot: ClothingSlot.shoes, tags: ['été', 'soleil', 'ville']),
    const ClothingItem(id: 'shoes_slippers', name: 'Chaussons', emoji: '🧦', slot: ClothingSlot.shoes, tags: ['cozy', 'nuit']),
    // Accessories
    const ClothingItem(id: 'acc_umbrella', name: 'Parapluie', emoji: '☂️', slot: ClothingSlot.accessory, tags: ['pluie']),
    const ClothingItem(id: 'acc_flowers', name: 'Bouquet', emoji: '💐', slot: ClothingSlot.accessory, rarity: ItemRarity.uncommon, tags: ['amour', 'printemps', 'fête']),
    const ClothingItem(id: 'acc_flag', name: 'Drapeau tricolore', emoji: '🇫🇷', slot: ClothingSlot.accessory, rarity: ItemRarity.rare, season: 'summer', isUnlocked: false, unlockHint: 'Ajoute 5 contacts', tags: ['france', 'fête']),
    const ClothingItem(id: 'acc_pumpkin', name: 'Citrouille', emoji: '🎃', slot: ClothingSlot.accessory, rarity: ItemRarity.uncommon, season: 'autumn', tags: ['halloween']),
    const ClothingItem(id: 'acc_star', name: 'Étoile magique', emoji: '🌟', slot: ClothingSlot.accessory, rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Atteins 10 contacts', tags: ['magique', 'spécial']),
    const ClothingItem(id: 'acc_egg', name: 'Œuf de Pâques', emoji: '🥚', slot: ClothingSlot.accessory, rarity: ItemRarity.uncommon, season: 'spring', tags: ['pâques', 'printemps']),
    const ClothingItem(id: 'acc_bowtie', name: 'Nœud papillon', emoji: '🎀', slot: ClothingSlot.accessory, rarity: ItemRarity.uncommon, isUnlocked: false, unlockHint: 'Crée ton premier vœu', tags: ['chic', 'fête']),
    const ClothingItem(id: 'acc_cape', name: 'Cape de super-héros', emoji: '🦸', slot: ClothingSlot.accessory, rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Réserve 3 vœux pour tes proches', tags: ['héros', 'spécial']),
  ];

  // ─── ACHIEVEMENTS ───────────────────────────────────────────────────────────
  static final List<Achievement> achievements = [
    Achievement(
      id: 'achievement_birthday_set',
      unlockItemId: 'hat_birthday',
      hintFr: 'Remplis ta date d\'anniversaire',
      hintEn: 'Set your birthday date',
      check: (s) => s.profile.birthdate != null && s.profile.birthdate!.isNotEmpty,
    ),
    Achievement(
      id: 'achievement_5_contacts',
      unlockItemId: 'acc_flag',
      hintFr: 'Ajoute 5 contacts à ton réseau',
      hintEn: 'Add 5 contacts to your network',
      check: (s) => s.contacts.length >= 5,
    ),
    Achievement(
      id: 'achievement_10_contacts',
      unlockItemId: 'acc_star',
      hintFr: 'Atteins 10 contacts dans ton réseau',
      hintEn: 'Reach 10 contacts in your network',
      check: (s) => s.contacts.length >= 10,
    ),
    Achievement(
      id: 'achievement_bond_friend',
      unlockItemId: 'hat_nightcap',
      hintFr: 'Atteins le niveau d\'amitié "Ami" avec Pigio',
      hintEn: 'Reach "Friend" bond level with Pigio',
      check: (s) => s.mascotBondLevel >= 2,
    ),
    Achievement(
      id: 'achievement_bond_bff',
      unlockItemId: 'hat_detective',
      hintFr: 'Atteins le niveau d\'amitié "BFF" avec Pigio',
      hintEn: 'Reach "BFF" bond level with Pigio',
      check: (s) => s.mascotBondLevel >= 3,
    ),
    Achievement(
      id: 'achievement_first_wish',
      unlockItemId: 'acc_bowtie',
      hintFr: 'Crée ton premier vœu',
      hintEn: 'Create your first wish',
      check: (s) => s.wishes.isNotEmpty,
    ),
    Achievement(
      id: 'achievement_3_reserved',
      unlockItemId: 'acc_cape',
      hintFr: 'Réserve 3 vœux pour tes proches',
      hintEn: 'Reserve 3 wishes for your loved ones',
      check: (s) => s.wishes.where((w) => w.reservedById != null).length >= 3,
    ),
  ];

  // ─── SMART COMBOS ──────────────────────────────────────────────────────────
  static const List<OutfitCombo> combos = [
    OutfitCombo(
      nameFr: 'Soirée Pluie',
      nameEn: 'Rainy Day',
      itemIds: ['top_raincoat', 'shoes_boots', 'acc_umbrella'],
      tags: ['pluie', 'automne'],
    ),
    OutfitCombo(
      nameFr: 'Plage & Soleil',
      nameEn: 'Beach & Sun',
      itemIds: ['hat_straw', 'glasses_sun', 'top_hawaiian', 'shoes_flipflops'],
      tags: ['été', 'soleil', 'vacances'],
    ),
    OutfitCombo(
      nameFr: 'Canicule Chic',
      nameEn: 'Heatwave City',
      itemIds: ['hat_bucket', 'glasses_sun', 'top_linen', 'shoes_sandals'],
      tags: ['été', 'soleil', 'ville'],
    ),
    OutfitCombo(
      nameFr: 'Vent & Averses',
      nameEn: 'Wind and Showers',
      itemIds: ['top_windbreaker', 'acc_umbrella', 'shoes_boots'],
      tags: ['pluie', 'vent'],
    ),
    OutfitCombo(
      nameFr: 'Nuit Cozy',
      nameEn: 'Cozy Night',
      itemIds: ['glasses_reading', 'top_pyjama', 'shoes_slippers'],
      tags: ['nuit', 'cozy', 'calme'],
    ),
    OutfitCombo(
      nameFr: 'Grand Froid',
      nameEn: 'Deep Freeze',
      itemIds: ['hat_winter', 'top_scarf_thick', 'shoes_boots'],
      tags: ['hiver', 'froid'],
    ),
    OutfitCombo(
      nameFr: 'Fête Totale',
      nameEn: 'Party Mode',
      itemIds: ['hat_party', 'glasses_heart', 'acc_flowers'],
      tags: ['fête', 'amour'],
    ),
    OutfitCombo(
      nameFr: 'Halloween',
      nameEn: 'Halloween',
      itemIds: ['hat_witch', 'acc_pumpkin'],
      tags: ['halloween'],
    ),
    OutfitCombo(
      nameFr: 'Noël',
      nameEn: 'Christmas',
      itemIds: ['hat_santa', 'top_scarf_thick', 'shoes_boots'],
      tags: ['noël', 'hiver'],
    ),
  ];

  // ─── PERSONALITY → ITEM TAG MAPPING ─────────────────────────────────────────
  static const Map<String, List<String>> _personalityTagMap = {
    // personality.id => tags that match
    'homebody': ['cozy', 'nuit', 'calme', 'lecture'],
    'adventurer': ['été', 'vacances', 'soleil', 'plage'],
    'social': ['fête', 'amour', 'printemps'],
    'creative_p': ['magique', 'spécial', 'halloween'],
    'optimist': ['soleil', 'été', 'fête'],
    'free_spirit': ['vacances', 'plage', 'été'],
    'ambitious': ['france', 'spécial'],
    'curious': ['lecture', 'calme'],
    // experience preferences
    'cozy': ['cozy', 'nuit', 'calme'],
    'explore': ['été', 'vacances', 'soleil'],
    'social_out': ['fête', 'amour'],
    'outdoor': ['été', 'soleil', 'plage', 'automne'],
    // style preferences
    'casual': ['été', 'vacances'],
    'elegant': ['fête', 'amour', 'spécial'],
    'sporty': ['été', 'soleil'],
    'boheme': ['printemps', 'amour'],
    'minimalist': ['calme', 'lecture'],
    'vintage': ['automne', 'hiver'],
    // passions
    'reading': ['lecture', 'calme'],
    'nature': ['printemps', 'automne', 'été'],
    'travel': ['vacances', 'plage', 'soleil'],
  };

  static ClothingItem? getItem(String id) => catalog.where((c) => c.id == id).firstOrNull;

  static int countForSlot(ClothingSlot? slot) {
    if (slot == null) return catalog.length;
    return catalog.where((c) => c.slot == slot).length;
  }

  /// Check whether an item is unlocked for the user.
  /// Items with `isUnlocked: true` in catalog are always available.
  /// Items with `isUnlocked: false` require the matching achievement or
  /// must be present in `state.unlockedClothing`.
  static bool isItemUnlocked(String itemId, PigioAppState state) {
    final item = getItem(itemId);
    if (item == null) return false;
    // E9: Expired limited-time items are no longer available
    if (!item.isAvailable) return false;
    if (item.isUnlocked) return true;
    if (state.unlockedClothing.contains(itemId)) return true;
    return false;
  }

  /// Get the unlock hint for a locked item (localized).
  static String? getUnlockHint(String itemId, String lang) {
    final achievement = achievements.where((a) => a.unlockItemId == itemId).firstOrNull;
    if (achievement == null) return null;
    return lang == 'fr' ? achievement.hintFr : achievement.hintEn;
  }

  /// Check all achievements and auto-unlock any newly earned items.
  /// Returns list of newly unlocked item IDs.
  static List<String> checkAchievements(PigioAppState state) {
    final newlyUnlocked = <String>[];
    for (final achievement in achievements) {
      if (state.unlockedClothing.contains(achievement.unlockItemId)) continue;
      if (achievement.check(state)) {
        state.unlockClothing(achievement.unlockItemId);
        newlyUnlocked.add(achievement.unlockItemId);
      }
    }
    return newlyUnlocked;
  }

  /// Suggest a complementary item based on the currently equipped outfit.
  /// Returns null if no good combo match is found.
  static ClothingItem? suggestCombo(PigioAppState state) {
    final equipped = state.activeOutfit.values.whereType<String>().toSet();
    if (equipped.isEmpty) return null;

    OutfitCombo? bestCombo;
    int bestOverlap = 0;

    for (final combo in combos) {
      final overlap = combo.itemIds.where(equipped.contains).length;
      if (overlap > bestOverlap && overlap < combo.itemIds.length) {
        bestOverlap = overlap;
        bestCombo = combo;
      }
    }

    if (bestCombo == null || bestOverlap == 0) return null;

    // Find the first missing item from the best combo that isn't already equipped
    for (final itemId in bestCombo.itemIds) {
      if (!equipped.contains(itemId)) {
        final item = getItem(itemId);
        if (item != null && isItemUnlocked(itemId, state)) {
          // Don't suggest items for slots already occupied
          if (!state.activeOutfit.containsKey(item.slot)) {
            return item;
          }
        }
      }
    }
    return null;
  }

  /// Get personality-weighted item scores. Returns items sorted by relevance
  /// to the user's personality profile. Higher score = more relevant.
  static Map<String, double> personalityScores(PigioAppState state) {
    final scores = <String, double>{};
    final profile = state.personalityProfile;
    if (profile.isEmpty) return scores;

    // Collect all personality tags the user matches
    final userTags = <String>{};
    for (final entry in profile.entries) {
      for (final answer in entry.value) {
        final mappedTags = _personalityTagMap[answer];
        if (mappedTags != null) userTags.addAll(mappedTags);
      }
    }

    if (userTags.isEmpty) return scores;

    for (final item in catalog) {
      double score = 0;
      for (final tag in item.tags) {
        if (userTags.contains(tag)) score += 1.0;
      }
      if (score > 0) scores[item.id] = score;
    }

    return scores;
  }

  /// Get the best personality-based suggestion for items not currently equipped.
  static ClothingItem? personalitySuggestion(PigioAppState state) {
    final scores = personalityScores(state);
    if (scores.isEmpty) return null;

    final equipped = state.activeOutfit.values.whereType<String>().toSet();

    // Sort by score descending
    final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sorted) {
      if (equipped.contains(entry.key)) continue;
      final item = getItem(entry.key);
      if (item != null && isItemUnlocked(entry.key, state)) {
        if (!state.activeOutfit.containsKey(item.slot)) {
          return item;
        }
      }
    }
    return null;
  }

  /// Null-safe factory — returns null when item ID is missing from catalog.
  static ClothingRequest? _safeRequest(
    String itemId, {
    required String bubbleTextFr,
    required String bubbleTextEn,
    required String contextHint,
  }) {
    final item = getItem(itemId);
    if (item == null) return null;
    return ClothingRequest(
      item: item,
      bubbleTextFr: bubbleTextFr,
      bubbleTextEn: bubbleTextEn,
      contextHint: contextHint,
    );
  }

  static ClothingRequest? _firstUnlockedRequest(
    List<String> itemIds, {
    required bool Function(String itemId) isUnlocked,
    required String bubbleTextFr,
    required String bubbleTextEn,
    required String contextHint,
  }) {
    for (final itemId in itemIds) {
      if (!isUnlocked(itemId)) continue;
      final request = _safeRequest(
        itemId,
        bubbleTextFr: bubbleTextFr,
        bubbleTextEn: bubbleTextEn,
        contextHint: contextHint,
      );
      if (request != null) return request;
    }
    return null;
  }

  static WeatherProtectionProfile weatherProtectionFor(Map<ClothingSlot, String?> activeOutfit) {
    final hat = activeOutfit[ClothingSlot.hat];
    final glasses = activeOutfit[ClothingSlot.glasses];
    final top = activeOutfit[ClothingSlot.top];
    final shoes = activeOutfit[ClothingSlot.shoes];
    final accessory = activeOutfit[ClothingSlot.accessory];
    return WeatherProtectionProfile(
      hasUmbrella: accessory == 'acc_umbrella',
      hasRaincoat: top == 'top_raincoat',
      hasWindbreaker: top == 'top_windbreaker',
      hasWinterHat: hat == 'hat_winter',
      hasWarmScarf: top == 'top_scarf_thick',
      hasSunglasses: glasses == 'glasses_sun',
      hasStrawHat: hat == 'hat_straw',
      hasBucketHat: hat == 'hat_bucket',
      hasHawaiianShirt: top == 'top_hawaiian',
      hasLinenShirt: top == 'top_linen',
      hasWaterproofShoes: shoes == 'shoes_boots',
      hasSandals: shoes == 'shoes_flipflops' || shoes == 'shoes_sandals',
    );
  }

  /// Pure weather-only evaluator used by the main context engine and tests.
  static ClothingRequest? evaluateWeatherRequest({
    required WeatherData weather,
    required Map<ClothingSlot, String?> activeOutfit,
    required bool Function(String itemId) isUnlocked,
  }) {
    final protection = weatherProtectionFor(activeOutfit);

    if (weather.condition == 'storm') {
      if (!protection.hasUmbrella) {
        final request = _firstUnlockedRequest(
          const ['acc_umbrella', 'top_raincoat', 'top_windbreaker'],
          isUnlocked: isUnlocked,
          bubbleTextFr: "Ouh la, quel orage ⛈️ Vite, il me faut un vrai abri !",
          bubbleTextEn: "Whoa, that's a storm ⛈️ I need proper cover, quick!",
          contextHint: 'Orage ⛈️',
        );
        if (request != null) return request;
      }
      if (!protection.hasStormShell) {
        final request = _firstUnlockedRequest(
          const ['top_raincoat', 'top_windbreaker'],
          isUnlocked: isUnlocked,
          bubbleTextFr: "Le vent me fouette de côté 🌬️ Il me faut une couche coupe-pluie !",
          bubbleTextEn: "The wind is whipping sideways 🌬️ I need a weather shell!",
          contextHint: 'Orage ⛈️',
        );
        if (request != null) return request;
      }
      if (!protection.hasWaterproofShoes) {
        final request = _firstUnlockedRequest(
          const ['shoes_boots'],
          isUnlocked: isUnlocked,
          bubbleTextFr: "Les flaques arrivent jusqu'à mes pattes 🌧️ Mes bottes !",
          bubbleTextEn: "The puddles are reaching my feet 🌧️ My boots!",
          contextHint: 'Orage ⛈️',
        );
        if (request != null) return request;
      }
    }

    if (weather.condition == 'rain') {
      if (protection.rainCoverage < 0.74) {
        final request = _firstUnlockedRequest(
          const ['acc_umbrella', 'top_raincoat', 'top_windbreaker'],
          isUnlocked: isUnlocked,
          bubbleTextFr: "Il pleut dehors 🌧️ Je veux rester bien au sec !",
          bubbleTextEn: "It's raining outside 🌧️ I want to stay dry!",
          contextHint: 'Il pleut 🌧️',
        );
        if (request != null) return request;
      }
      if (weather.temperature <= 8 && !protection.hasWaterproofShoes) {
        final request = _firstUnlockedRequest(
          const ['shoes_boots'],
          isUnlocked: isUnlocked,
          bubbleTextFr: "Pluie froide = pattes mouillées 🥾 Vite, mes bottes !",
          bubbleTextEn: "Cold rain means wet feet 🥾 Quick, my boots!",
          contextHint: 'Pluie froide 🌧️',
        );
        if (request != null) return request;
      }
    }

    if (weather.condition == 'snow') {
      if (!protection.hasWarmScarf) {
        final request = _firstUnlockedRequest(
          const ['top_scarf_thick'],
          isUnlocked: isUnlocked,
          bubbleTextFr: "Il neige ! ❄️ Vite, mon écharpe !",
          bubbleTextEn: "It's snowing! ❄️ Quick, my scarf!",
          contextHint: 'Il neige ❄️',
        );
        if (request != null) return request;
      }
      if (!protection.hasWinterHat) {
        final request = _firstUnlockedRequest(
          const ['hat_winter'],
          isUnlocked: isUnlocked,
          bubbleTextFr: "La neige pique ma tête 🥶 Mon bonnet, vite !",
          bubbleTextEn: "The snow is freezing my head 🥶 My beanie, quick!",
          contextHint: 'Il neige ❄️',
        );
        if (request != null) return request;
      }
      if (weather.temperature <= 0 && !protection.hasWaterproofShoes) {
        final request = _firstUnlockedRequest(
          const ['shoes_boots'],
          isUnlocked: isUnlocked,
          bubbleTextFr: "La neige fond sous mes pieds ❄️ J'ai besoin de bottes !",
          bubbleTextEn: "Snow is melting under my feet ❄️ I need boots!",
          contextHint: 'Neige humide ❄️',
        );
        if (request != null) return request;
      }
    }

    if (weather.temperature < 5 && !protection.hasWinterHat) {
      final request = _firstUnlockedRequest(
        const ['hat_winter', 'top_scarf_thick'],
        isUnlocked: isUnlocked,
        bubbleTextFr: "Brrr il fait ${weather.temperature.round()}°C 🥶 Il me faut une couche chaude !",
        bubbleTextEn: "Brrr it's ${weather.temperature.round()}°C 🥶 I need something warm!",
        contextHint: 'Froid polaire ❄️',
      );
      if (request != null) return request;
    }

    if (weather.temperature > 25 && weather.condition == 'sunny' && weather.isDay && !protection.hasSunglasses) {
      final request = _firstUnlockedRequest(
        const ['glasses_sun'],
        isUnlocked: isUnlocked,
        bubbleTextFr: "Ça tape aujourd'hui ! 😎 Vite, mes lunettes !",
        bubbleTextEn: "It's scorching today! 😎 Quick, my sunglasses!",
        contextHint: 'Grand soleil ☀️',
      );
      if (request != null) return request;
    }

    if (weather.temperature > 32 && !protection.hasBreathableTop) {
      final request = _firstUnlockedRequest(
        const ['top_hawaiian', 'top_linen'],
        isUnlocked: isUnlocked,
        bubbleTextFr: "Il fait trop chaud 🌡️ Il me faut une tenue légère !",
        bubbleTextEn: "It's way too hot 🌡️ I need a lighter top!",
        contextHint: 'Canicule 🌡️',
      );
      if (request != null) return request;
    }

    if (weather.temperature > 30 && weather.isDay && !protection.hasSunHat) {
      final request = _firstUnlockedRequest(
        const ['hat_straw', 'hat_bucket'],
        isUnlocked: isUnlocked,
        bubbleTextFr: "Le soleil tape sur ma tête ☀️ J'ai besoin d'un chapeau !",
        bubbleTextEn: "The sun is hitting my head ☀️ I need a hat!",
        contextHint: 'Soleil fort ☀️',
      );
      if (request != null) return request;
    }

    if (weather.temperature > 34 && !protection.hasSandals) {
      final request = _firstUnlockedRequest(
        const ['shoes_sandals', 'shoes_flipflops'],
        isUnlocked: isUnlocked,
        bubbleTextFr: "Mes pieds cuisent sur le sol 🩴 Des chaussures d'été, vite !",
        bubbleTextEn: "My feet are roasting on the ground 🩴 Summer shoes, quick!",
        contextHint: 'Chaleur au sol 🌞',
      );
      if (request != null) return request;
    }

    return null;
  }

  // ─── CONTEXT EVALUATION ─────────────────────────────────────────────────────
  static Future<ClothingRequest?> evaluateContext(PigioAppState state) async {
    final now = DateTime.now();
    final weather = state.currentWeather ?? await WeatherService.fetchCurrent();

    // 0. Auto-unlock achievements
    checkAchievements(state);

    // 1. Events — User's birthday
    if (state.profile.birthdate != null && state.profile.birthdate!.isNotEmpty) {
      final parts = state.profile.birthdate!.split('/');
      if (parts.length >= 2) {
        if (int.tryParse(parts[0]) == now.day && int.tryParse(parts[1]) == now.month) {
          if (!state.activeOutfit.containsValue('hat_birthday') && isItemUnlocked('hat_birthday', state)) {
            final r = _safeRequest('hat_birthday',
              bubbleTextFr: "C'est ton anniversaire ! Mets-moi ma couronne 👑",
              bubbleTextEn: "It's your birthday! Give me my crown 👑",
              contextHint: "Ton anniversaire 🎂",
            );
            if (r != null) return r;
          }
        }
      }
    }

    // 2. Holidays
    // Christmas (December)
    if (now.month == 12 && now.day >= 1) {
      if (!state.activeOutfit.containsValue('hat_santa')) {
        final r = _safeRequest('hat_santa',
          bubbleTextFr: "Bientôt Noël ! Je peux avoir mon bonnet ? 🎅",
          bubbleTextEn: "Christmas soon! Can I have my hat? 🎅",
          contextHint: "Période de Noël 🎄",
        );
        if (r != null) return r;
      }
    }
    // Halloween (Oct 25+)
    if (now.month == 10 && now.day >= 25) {
      if (!state.activeOutfit.containsValue('acc_pumpkin')) {
        final r = _safeRequest('acc_pumpkin',
          bubbleTextFr: "Des bonbons ou un sort ! 🎃",
          bubbleTextEn: "Trick or treat! 🎃",
          contextHint: "Halloween 🦇",
        );
        if (r != null) return r;
      }
    }
    // Valentine's Day (Feb 10-15)
    if (now.month == 2 && now.day >= 10 && now.day <= 15) {
      if (!state.activeOutfit.containsValue('glasses_heart')) {
        final r = _safeRequest('glasses_heart',
          bubbleTextFr: "De l'amour dans l'air 💕",
          bubbleTextEn: "Love is in the air 💕",
          contextHint: "Saint Valentin 💘",
        );
        if (r != null) return r;
      }
    }
    // Bastille Day (July 14)
    if (now.month == 7 && now.day >= 12 && now.day <= 15) {
      if (!state.activeOutfit.containsValue('acc_flag') && isItemUnlocked('acc_flag', state)) {
        final r = _safeRequest('acc_flag',
          bubbleTextFr: "Vive la France ! 🇫🇷 Mon drapeau s'il te plaît !",
          bubbleTextEn: "Vive la France! 🇫🇷 My flag please!",
          contextHint: "Fête nationale 🇫🇷",
        );
        if (r != null) return r;
      }
    }
    // New Year's Eve/Day (Dec 31 - Jan 2)
    if ((now.month == 12 && now.day == 31) || (now.month == 1 && now.day <= 2)) {
      if (!state.activeOutfit.containsValue('hat_party')) {
        final r = _safeRequest('hat_party',
          bubbleTextFr: "Bonne année ! 🎉 Chapeau de fête !",
          bubbleTextEn: "Happy New Year! 🎉 Party hat!",
          contextHint: "Nouvel An 🎆",
        );
        if (r != null) return r;
      }
    }
    // Easter — computed via Anonymous Gregorian algorithm (Q13)
    final easter = _computeEaster(now.year);
    final daysToEaster = easter.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (daysToEaster >= -2 && daysToEaster <= 7) {
      if (!state.activeOutfit.containsValue('acc_egg')) {
        final r = _safeRequest('acc_egg',
          bubbleTextFr: "Joyeuses Pâques ! 🐣 Mon œuf en chocolat !",
          bubbleTextEn: "Happy Easter! 🐣 My chocolate egg!",
          contextHint: "Pâques 🥚",
        );
        if (r != null) return r;
      }
    }
    // Mother's Day (last Sunday of May, approximate: May 25-31)
    if (now.month == 5 && now.day >= 25) {
      if (!state.activeOutfit.containsValue('acc_flowers')) {
        final r = _safeRequest('acc_flowers',
          bubbleTextFr: "Bonne fête des mères ! 💐",
          bubbleTextEn: "Happy Mother's Day! 💐",
          contextHint: "Fête des mères 💐",
        );
        if (r != null) return r;
      }
    }

    // 3. Weather
    if (weather != null) {
      final weatherRequest = evaluateWeatherRequest(
        weather: weather,
        activeOutfit: state.activeOutfit,
        isUnlocked: (itemId) => isItemUnlocked(itemId, state),
      );
      if (weatherRequest != null) return weatherRequest;
    }

    // 4. Time of day
    if (now.hour >= 23 || now.hour < 5) {
       if (!state.activeOutfit.containsValue('top_pyjama')) {
        final r = _safeRequest('top_pyjama',
          bubbleTextFr: "Quelle heure est-il ? 🥱 Pyjama time...",
          bubbleTextEn: "What time is it? 🥱 Pyjama time...",
          contextHint: "Tard la nuit 🌙",
        );
        if (r != null) return r;
       }
    }
    // Quiet afternoon → reading glasses
    if (now.hour >= 14 && now.hour <= 16 && now.weekday >= 6) {
      if (!state.activeOutfit.containsValue('glasses_reading')) {
        final r = _safeRequest('glasses_reading',
          bubbleTextFr: "Un bon moment pour bouquiner ! 📚",
          bubbleTextEn: "Good time for a read! 📚",
          contextHint: "Moment lecture 📖",
        );
        if (r != null) return r;
      }
    }

    // 5. Milestones
    if (state.contacts.length >= 10 && isItemUnlocked('acc_star', state)) {
      if (!state.activeOutfit.containsValue('acc_star')) {
        final r = _safeRequest('acc_star',
          bubbleTextFr: "10 contacts ! Tu es une star ⭐",
          bubbleTextEn: "10 contacts! You're a star ⭐",
          contextHint: "10 contacts atteints 🌟",
        );
        if (r != null) return r;
      }
    }

    // 6. Smart combo suggestion
    final comboItem = suggestCombo(state);
    if (comboItem != null) {
      return ClothingRequest(
        item: comboItem,
        bubbleTextFr: "Et si tu ajoutais ${comboItem.emoji} ${comboItem.name} ? Ça irait bien ensemble !",
        bubbleTextEn: "How about adding ${comboItem.emoji} ${comboItem.name}? It would go great together!",
        contextHint: "Combo suggéré ✨",
      );
    }

    // 7. Personality-based suggestion
    final personalityItem = personalitySuggestion(state);
    if (personalityItem != null) {
      return ClothingRequest(
        item: personalityItem,
        bubbleTextFr: "D'après ton profil, ${personalityItem.emoji} ${personalityItem.name} te correspond bien !",
        bubbleTextEn: "Based on your profile, ${personalityItem.emoji} ${personalityItem.name} suits you!",
        contextHint: "Ton style perso 🎭",
      );
    }

    return null;
  }

  /// Q13: Anonymous Gregorian Easter algorithm
  /// Returns Easter Sunday for the given year.
  static DateTime _computeEaster(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }
}
