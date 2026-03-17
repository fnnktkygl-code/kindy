import 'dart:math' as math;
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/shared/widgets/pigio_painter.dart';
import 'weather_service.dart';

final _rng = math.Random();

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
    const ClothingItem(id: 'acc_friendship', name: 'Bracelet d\'amitié', emoji: '🤝', slot: ClothingSlot.accessory, rarity: ItemRarity.rare, isUnlocked: false, unlockHint: 'Fais accepter ta première invitation', tags: ['amitié', 'social']),
    const ClothingItem(id: 'hat_ambassador', name: 'Couronne d\'ambassadeur', emoji: '🫅', slot: ClothingSlot.hat, rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Fais accepter 5 invitations', tags: ['social', 'ambassadeur']),
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

  /// Pick a random (fr, en) pair from parallel lists.
  static ({String fr, String en}) _pickPair(List<String> frs, List<String> ens) {
    final i = _rng.nextInt(frs.length);
    return (fr: frs[i], en: ens[i]);
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

  // ─── WEATHER REACTION HELPERS ────────────────────────────────────────────────
  // Single source of truth for pose, exposure and mood based on weather +
  // outfit protection. Used by mascot overlay, weather lab, and tests.

  static PigPose weatherPoseFor(WeatherData? weather, WeatherProtectionProfile protection) {
    if (weather == null) return PigPose.normal;
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

  static double weatherExposureFor(WeatherData? weather, WeatherProtectionProfile protection) {
    if (weather == null) return 0.0;
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

  static PigMood? weatherMoodFor(WeatherData? weather, WeatherProtectionProfile protection) {
    if (weather == null) return null;
    if (weather.condition == 'storm' && protection.stormCoverage < 0.7) return PigMood.sad;
    if (weather.condition == 'storm' && protection.stormCoverage >= 0.9) return PigMood.thinking;
    if (weather.condition == 'rain' && protection.rainCoverage < 0.65) return PigMood.sad;
    if (weather.condition == 'rain' && protection.rainCoverage >= 0.88) return PigMood.thinking;
    if (weather.condition == 'snow' && protection.snowCoverage < 0.65) return PigMood.sad;
    if (weather.condition == 'snow' && protection.snowCoverage >= 0.88) return PigMood.love;
    if (weather.temperature > 28 && protection.sunCoverage < 0.55) return PigMood.sad;
    if (weather.temperature > 28 && protection.sunCoverage >= 0.82) return PigMood.thumbsUp;
    return null;
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
        final t = _pickPair(
          ["Ouh la, quel orage ⛈️ Vite, il me faut un vrai abri !", "La foudre gronde ! ⚡ Vite, protège-moi !", "Tempête en vue ⛈️ Mon parapluie, pitié !"],
          ["Whoa, that's a storm ⛈️ I need proper cover, quick!", "Thunder's rumbling! ⚡ Quick, protect me!", "Storm incoming ⛈️ My umbrella, please!"],
        );
        final request = _firstUnlockedRequest(
          const ['acc_umbrella', 'top_raincoat', 'top_windbreaker'],
          isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Orage ⛈️',
        );
        if (request != null) return request;
      }
      if (!protection.hasStormShell) {
        final t = _pickPair(
          ["Le vent me fouette de côté 🌬️ Il me faut une couche coupe-pluie !", "Ça souffle fort ! 🌬️ Un coupe-vent, viiite !"],
          ["The wind is whipping sideways 🌬️ I need a weather shell!", "It's blowing hard! 🌬️ A windbreaker, pleease!"],
        );
        final request = _firstUnlockedRequest(
          const ['top_raincoat', 'top_windbreaker'],
          isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Orage ⛈️',
        );
        if (request != null) return request;
      }
      if (!protection.hasWaterproofShoes) {
        final t = _pickPair(
          ["Les flaques arrivent jusqu'à mes pattes 🌧️ Mes bottes !", "Splash splash ! 💦 Mes pieds sont trempés !"],
          ["The puddles are reaching my feet 🌧️ My boots!", "Splash splash! 💦 My feet are soaked!"],
        );
        final request = _firstUnlockedRequest(
          const ['shoes_boots'],
          isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Orage ⛈️',
        );
        if (request != null) return request;
      }
    }

    if (weather.condition == 'rain') {
      if (protection.rainCoverage < 0.74) {
        final t = _pickPair(
          ["Il pleut dehors 🌧️ Je veux rester bien au sec !", "Gouttes en approche ! 🌧️ Vite, quelque chose pour me couvrir !", "Plic ploc ! 💧 Je vais finir trempé si on fait rien !"],
          ["It's raining outside 🌧️ I want to stay dry!", "Drops incoming! 🌧️ Quick, something to cover me!", "Drip drop! 💧 I'll be drenched if we don't act!"],
        );
        final request = _firstUnlockedRequest(
          const ['acc_umbrella', 'top_raincoat', 'top_windbreaker'],
          isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Il pleut 🌧️',
        );
        if (request != null) return request;
      }
      if (weather.temperature <= 8 && !protection.hasWaterproofShoes) {
        final t = _pickPair(
          ["Pluie froide = pattes mouillées 🥾 Vite, mes bottes !", "Mes petites pattes gèlent dans les flaques ! 🥶🥾"],
          ["Cold rain means wet feet 🥾 Quick, my boots!", "My little feet are freezing in the puddles! 🥶🥾"],
        );
        final request = _firstUnlockedRequest(
          const ['shoes_boots'],
          isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Pluie froide 🌧️',
        );
        if (request != null) return request;
      }
    }

    if (weather.condition == 'snow') {
      if (!protection.hasWarmScarf) {
        final t = _pickPair(
          ["Il neige ! ❄️ Vite, mon écharpe !", "Brrr, des flocons partout ! 🌨️ Mon écharpe, s'il te plaît !", "La neige me chatouille le cou ! ❄️ Vite, une écharpe !"],
          ["It's snowing! ❄️ Quick, my scarf!", "Brrr, snowflakes everywhere! 🌨️ My scarf, please!", "Snow is tickling my neck! ❄️ Quick, a scarf!"],
        );
        final request = _firstUnlockedRequest(
          const ['top_scarf_thick'],
          isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Il neige ❄️',
        );
        if (request != null) return request;
      }
      if (!protection.hasWinterHat) {
        final t = _pickPair(
          ["La neige pique ma tête 🥶 Mon bonnet, vite !", "Ma tête gèle ! 🧊 Un bonnet bien chaud ?", "Flocons sur le crâne ! ❄️ Mon bonnet !"],
          ["The snow is freezing my head 🥶 My beanie, quick!", "My head is freezing! 🧊 A warm beanie?", "Snowflakes on my head! ❄️ My beanie!"],
        );
        final request = _firstUnlockedRequest(
          const ['hat_winter'],
          isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Il neige ❄️',
        );
        if (request != null) return request;
      }
      if (weather.temperature <= 0 && !protection.hasWaterproofShoes) {
        final t = _pickPair(
          ["La neige fond sous mes pieds ❄️ J'ai besoin de bottes !", "Mes pattes s'enfoncent dans la neige ! 🥾 Des bottes !"],
          ["Snow is melting under my feet ❄️ I need boots!", "My feet are sinking in the snow! 🥾 Boots!"],
        );
        final request = _firstUnlockedRequest(
          const ['shoes_boots'],
          isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Neige humide ❄️',
        );
        if (request != null) return request;
      }
    }

    if (weather.temperature < 5 && !protection.hasWinterHat) {
      final t = _pickPair(
        ["Brrr il fait ${weather.temperature.round()}°C 🥶 Il me faut une couche chaude !", "${weather.temperature.round()}°C dehors ! 🧊 Mon bonnet, vite !", "Je grelotte ! 🥶 Il fait ${weather.temperature.round()}°C et je suis à plumes !"],
        ["Brrr it's ${weather.temperature.round()}°C 🥶 I need something warm!", "${weather.temperature.round()}°C outside! 🧊 My beanie, quick!", "I'm shivering! 🥶 It's ${weather.temperature.round()}°C and I'm all feathers!"],
      );
      final request = _firstUnlockedRequest(
        const ['hat_winter', 'top_scarf_thick'],
        isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Froid polaire ❄️',
      );
      if (request != null) return request;
    }

    if (weather.temperature > 25 && weather.condition == 'sunny' && weather.isDay && !protection.hasSunglasses) {
      final t = _pickPair(
        ["Ça tape aujourd'hui ! 😎 Vite, mes lunettes !", "Soleil en pleine face ! ☀️ Mes lunettes, s'il te plaît !", "Aaah mes yeux ! 😎 Il me faut des lunettes de soleil !"],
        ["It's scorching today! 😎 Quick, my sunglasses!", "Sun straight in my face! ☀️ My sunglasses, please!", "Aaah my eyes! 😎 I need sunglasses!"],
      );
      final request = _firstUnlockedRequest(
        const ['glasses_sun'],
        isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Grand soleil ☀️',
      );
      if (request != null) return request;
    }

    if (weather.temperature > 32 && !protection.hasBreathableTop) {
      final t = _pickPair(
        ["Il fait trop chaud 🌡️ Il me faut une tenue légère !", "Je fonds ! 🫠 Vite, un haut léger !", "${weather.temperature.round()}°C ! 🔥 Je suis un pingouin, pas un cactus !"],
        ["It's way too hot 🌡️ I need a lighter top!", "I'm melting! 🫠 Quick, a lighter top!", "${weather.temperature.round()}°C! 🔥 I'm a penguin, not a cactus!"],
      );
      final request = _firstUnlockedRequest(
        const ['top_hawaiian', 'top_linen'],
        isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Canicule 🌡️',
      );
      if (request != null) return request;
    }

    if (weather.temperature > 30 && weather.isDay && !protection.hasSunHat) {
      final t = _pickPair(
        ["Le soleil tape sur ma tête ☀️ J'ai besoin d'un chapeau !", "Mon crâne chauffe ! ☀️ Un chapeau, vite !", "Coup de soleil en approche ! 🌞 Un chapeau s'il te plaît !"],
        ["The sun is hitting my head ☀️ I need a hat!", "My head is heating up! ☀️ A hat, quick!", "Sunburn incoming! 🌞 A hat please!"],
      );
      final request = _firstUnlockedRequest(
        const ['hat_straw', 'hat_bucket'],
        isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Soleil fort ☀️',
      );
      if (request != null) return request;
    }

    if (weather.temperature > 34 && !protection.hasSandals) {
      final t = _pickPair(
        ["Mes pieds cuisent sur le sol 🩴 Des chaussures d'été, vite !", "Aïe aïe le sol brûle ! 🔥 Des sandales, pitié !", "Le sol est une poêle ! 🍳 Des tongs, vite !"],
        ["My feet are roasting on the ground 🩴 Summer shoes, quick!", "Ouch the ground is burning! 🔥 Sandals, please!", "The ground is a frying pan! 🍳 Flip-flops, quick!"],
      );
      final request = _firstUnlockedRequest(
        const ['shoes_sandals', 'shoes_flipflops'],
        isUnlocked: isUnlocked, bubbleTextFr: t.fr, bubbleTextEn: t.en, contextHint: 'Chaleur au sol 🌞',
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
    final newUnlocks = checkAchievements(state);
    if (newUnlocks.isNotEmpty && state.mascotMoment == MascotMoment.none) {
      state.setMascotMoment(MascotMoment.achievementUnlocked);
    }

    // 1. Events — User's birthday
    if (state.profile.birthdate != null && state.profile.birthdate!.isNotEmpty) {
      final parts = state.profile.birthdate!.split('/');
      if (parts.length >= 2) {
        if (int.tryParse(parts[0]) == now.day && int.tryParse(parts[1]) == now.month) {
          if (!state.activeOutfit.containsValue('hat_birthday') && isItemUnlocked('hat_birthday', state)) {
            final bt = _pickPair(
              ["C'est ton anniversaire ! Mets-moi ma couronne 👑", "JOYEUX ANNIVERSAIRE ! 🎂 Ma couronne, vite !", "Ton jour spécial ! 🥳 Je veux être aussi chic que toi !"],
              ["It's your birthday! Give me my crown 👑", "HAPPY BIRTHDAY! 🎂 My crown, quick!", "Your special day! 🥳 I want to look as fabulous as you!"],
            );
            final r = _safeRequest('hat_birthday',
              bubbleTextFr: bt.fr, bubbleTextEn: bt.en, contextHint: "Ton anniversaire 🎂",
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
        final bt = _pickPair(
          ["Bientôt Noël ! Je peux avoir mon bonnet ? 🎅", "Ho ho ho ! 🎄 Mon bonnet de Noël, s'il te plaît !", "C'est la saison ! 🎅 Je veux mon look festif !"],
          ["Christmas soon! Can I have my hat? 🎅", "Ho ho ho! 🎄 My Christmas hat, please!", "Tis the season! 🎅 I want my festive look!"],
        );
        final r = _safeRequest('hat_santa',
          bubbleTextFr: bt.fr, bubbleTextEn: bt.en, contextHint: "Période de Noël 🎄",
        );
        if (r != null) return r;
      }
    }
    // Halloween (Oct 25+)
    if (now.month == 10 && now.day >= 25) {
      if (!state.activeOutfit.containsValue('acc_pumpkin')) {
        final bt = _pickPair(
          ["Des bonbons ou un sort ! 🎃", "Bou ! 👻 Tu m'as fait peur ! Enfin... moi je fais peur à personne.", "Halloween mode activé ! 🎃 Ma citrouille !"],
          ["Trick or treat! 🎃", "Boo! 👻 You scared me! Well... I don't scare anyone.", "Halloween mode activated! 🎃 My pumpkin!"],
        );
        final r = _safeRequest('acc_pumpkin',
          bubbleTextFr: bt.fr, bubbleTextEn: bt.en, contextHint: "Halloween 🦇",
        );
        if (r != null) return r;
      }
    }
    // Valentine's Day (Feb 10-15)
    if (now.month == 2 && now.day >= 10 && now.day <= 15) {
      if (!state.activeOutfit.containsValue('glasses_heart')) {
        final bt = _pickPair(
          ["De l'amour dans l'air 💕", "Saint Valentin ! 💘 Mes lunettes cœur, s'il te plaît !", "L'amour est partout ! 💕 Mes yeux doivent briller !"],
          ["Love is in the air 💕", "Valentine's Day! 💘 My heart glasses, please!", "Love is everywhere! 💕 My eyes need to sparkle!"],
        );
        final r = _safeRequest('glasses_heart',
          bubbleTextFr: bt.fr, bubbleTextEn: bt.en, contextHint: "Saint Valentin 💘",
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
        final bt = _pickPair(
          ["Bonne année ! 🎉 Chapeau de fête !", "3, 2, 1... 🥂 Mon chapeau de fête, vite !", "Nouvelle année, nouveau look ! 🎆 Mon chapeau !"],
          ["Happy New Year! 🎉 Party hat!", "3, 2, 1... 🥂 My party hat, quick!", "New year, new look! 🎆 My hat!"],
        );
        final r = _safeRequest('hat_party',
          bubbleTextFr: bt.fr, bubbleTextEn: bt.en, contextHint: "Nouvel An 🎆",
        );
        if (r != null) return r;
      }
    }
    // Easter — computed via Anonymous Gregorian algorithm (Q13)
    final easter = _computeEaster(now.year);
    final daysToEaster = easter.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (daysToEaster >= -2 && daysToEaster <= 7) {
      if (!state.activeOutfit.containsValue('acc_egg')) {
        final bt = _pickPair(
          ["Joyeuses Pâques ! 🐣 Mon œuf en chocolat !", "Le lapin est passé ? 🐰 Mon œuf, vite !", "Pâques ! 🥚 Je veux mon accessoire chocolaté !"],
          ["Happy Easter! 🐣 My chocolate egg!", "Did the bunny come? 🐰 My egg, quick!", "Easter! 🥚 I want my chocolatey accessory!"],
        );
        final r = _safeRequest('acc_egg',
          bubbleTextFr: bt.fr, bubbleTextEn: bt.en, contextHint: "Pâques 🥚",
        );
        if (r != null) return r;
      }
    }
    // Mother's Day (last Sunday of May, approximate: May 25-31)
    if (now.month == 5 && now.day >= 25) {
      if (!state.activeOutfit.containsValue('acc_flowers')) {
        final bt = _pickPair(
          ["Bonne fête des mères ! 💐", "C'est la fête des mamans ! 🌷 Mes fleurs, s'il te plaît !", "Journée spéciale ! 💐 Un bouquet pour l'occasion !"],
          ["Happy Mother's Day! 💐", "It's Mom's Day! 🌷 My flowers, please!", "Special day! 💐 A bouquet for the occasion!"],
        );
        final r = _safeRequest('acc_flowers',
          bubbleTextFr: bt.fr, bubbleTextEn: bt.en, contextHint: "Fête des mères 💐",
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
        final bt = _pickPair(
          ["Quelle heure est-il ? 🥱 Pyjama time...", "Bâille... 😴 C'est l'heure du pyjama !", "Zzz... 🌙 Allez, mon pyjama douillet !"],
          ["What time is it? 🥱 Pyjama time...", "Yawns... 😴 It's pyjama o'clock!", "Zzz... 🌙 Come on, my cozy pyjamas!"],
        );
        final r = _safeRequest('top_pyjama',
          bubbleTextFr: bt.fr, bubbleTextEn: bt.en, contextHint: "Tard la nuit 🌙",
        );
        if (r != null) return r;
       }
    }
    // Quiet afternoon → reading glasses
    if (now.hour >= 14 && now.hour <= 16 && now.weekday >= 6) {
      if (!state.activeOutfit.containsValue('glasses_reading')) {
        final bt = _pickPair(
          ["Un bon moment pour bouquiner ! 📚", "Week-end calme... 📖 Mes lunettes de lecture ?", "Mode détente activé ! 📚 Un bon livre et mes lunettes."],
          ["Good time for a read! 📚", "Quiet weekend... 📖 My reading glasses?", "Chill mode on! 📚 A good book and my glasses."],
        );
        final r = _safeRequest('glasses_reading',
          bubbleTextFr: bt.fr, bubbleTextEn: bt.en, contextHint: "Moment lecture 📖",
        );
        if (r != null) return r;
      }
    }

    // 5. Milestones
    if (state.contacts.length >= 10 && isItemUnlocked('acc_star', state)) {
      if (!state.activeOutfit.containsValue('acc_star')) {
        final bt = _pickPair(
          ["10 contacts ! Tu es une star ⭐", "10 proches sur Pigio ! 🌟 Tu mérites une étoile !", "Waouh, 10 contacts ! ⭐ Mets-moi mon étoile !"],
          ["10 contacts! You're a star ⭐", "10 people on Pigio! 🌟 You deserve a star!", "Wow, 10 contacts! ⭐ Give me my star!"],
        );
        final r = _safeRequest('acc_star',
          bubbleTextFr: bt.fr, bubbleTextEn: bt.en, contextHint: "10 contacts atteints 🌟",
        );
        if (r != null) return r;
      }
    }

    // 6. Smart combo suggestion
    final comboItem = suggestCombo(state);
    if (comboItem != null) {
      final ct = _pickPair(
        ["Et si tu ajoutais ${comboItem.emoji} ${comboItem.name} ? Ça irait bien ensemble !", "J'ai une idée ! ✨ ${comboItem.emoji} ${comboItem.name} compléterait parfaitement ton look !", "Combo parfait ! ${comboItem.emoji} ${comboItem.name} + ta tenue actuelle = 🔥"],
        ["How about adding ${comboItem.emoji} ${comboItem.name}? It would go great together!", "I have an idea! ✨ ${comboItem.emoji} ${comboItem.name} would complete your look perfectly!", "Perfect combo! ${comboItem.emoji} ${comboItem.name} + your current outfit = 🔥"],
      );
      return ClothingRequest(
        item: comboItem,
        bubbleTextFr: ct.fr, bubbleTextEn: ct.en, contextHint: "Combo suggéré ✨",
      );
    }

    // 7. Personality-based suggestion
    final personalityItem = personalitySuggestion(state);
    if (personalityItem != null) {
      final pt = _pickPair(
        ["D'après ton profil, ${personalityItem.emoji} ${personalityItem.name} te correspond bien !", "Je te connais ! 🧠 ${personalityItem.emoji} ${personalityItem.name}, c'est tellement toi !", "Suggestion perso : ${personalityItem.emoji} ${personalityItem.name} ! Ça te ressemble. 🎭"],
        ["Based on your profile, ${personalityItem.emoji} ${personalityItem.name} suits you!", "I know you! 🧠 ${personalityItem.emoji} ${personalityItem.name} is so you!", "Personal pick: ${personalityItem.emoji} ${personalityItem.name}! It's very you. 🎭"],
      );
      return ClothingRequest(
        item: personalityItem,
        bubbleTextFr: pt.fr, bubbleTextEn: pt.en, contextHint: "Ton style perso 🎭",
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
