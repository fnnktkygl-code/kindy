import 'dart:math' as math;
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/shared/widgets/pigio_painter.dart';
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

// ─── DAILY CHALLENGE ─────────────────────────────────────────────────────────
class DailyChallenge {
  final String id;
  final String titleFr;
  final String titleEn;
  final List<String> requiredTags;
  final ItemRarity? requiredRarity;

  const DailyChallenge({
    required this.id,
    required this.titleFr,
    required this.titleEn,
    this.requiredTags = const [],
    this.requiredRarity,
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
    // ═══════════════════════════════════════════════════════════════════
    // HATS (25 items)
    // ═══════════════════════════════════════════════════════════════════
    const ClothingItem(id: 'hat_winter', name: 'Bonnet d\'hiver', emoji: '🥶', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_winter.png', tags: ['hiver', 'froid']),
    const ClothingItem(id: 'hat_straw', name: 'Chapeau de paille', emoji: '🌾', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_straw.png', tags: ['été', 'soleil']),
    const ClothingItem(id: 'hat_bucket', name: 'Bob anti-UV', emoji: '🪣', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_bucket.png', tags: ['été', 'soleil', 'pluie']),
    const ClothingItem(id: 'hat_birthday', name: 'Couronne', emoji: '👑', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_birthday.png', rarity: ItemRarity.rare, isUnlocked: false, unlockHint: 'Remplis ton profil anniversaire', tags: ['fête', 'anniversaire']),
    const ClothingItem(id: 'hat_santa', name: 'Bonnet de Noël', emoji: '🎅', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_santa.png', rarity: ItemRarity.uncommon, season: 'winter', tags: ['noël', 'hiver']),
    const ClothingItem(id: 'hat_witch', name: 'Sorcière', emoji: '🧙', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_witch.png', rarity: ItemRarity.uncommon, season: 'autumn', tags: ['halloween']),
    const ClothingItem(id: 'hat_party', name: 'Chapeau de fête', emoji: '🥳', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_party.png', rarity: ItemRarity.uncommon, tags: ['fête', 'nouvel an']),
    const ClothingItem(id: 'hat_nightcap', name: 'Bonnet de nuit', emoji: '🌙', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_nightcap.png', rarity: ItemRarity.uncommon, isUnlocked: false, unlockHint: 'Atteins le niveau d\'amitié "Ami"', tags: ['nuit', 'cozy']),
    const ClothingItem(id: 'hat_detective', name: 'Chapeau détective', emoji: '🔍', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_detective.png', rarity: ItemRarity.rare, isUnlocked: false, unlockHint: 'Atteins le niveau d\'amitié "BFF"', tags: ['mystère', 'spécial']),
    const ClothingItem(id: 'hat_ambassador', name: 'Couronne d\'ambassadeur', emoji: '🫅', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_ambassador.png', rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Fais accepter 5 invitations', tags: ['social', 'ambassadeur']),
    const ClothingItem(id: 'hat_heart', name: 'Serre-tête cœur', emoji: '💝', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_heart.png', rarity: ItemRarity.rare, isUnlocked: false, unlockHint: 'Partage tes tailles avec tes proches', tags: ['amour', 'social']),
    const ClothingItem(id: 'hat_crown_diamond', name: 'Couronne de diamants', emoji: '💎', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_crown_diamond.png', rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['luxe', 'premium']),
    const ClothingItem(id: 'hat_astronaut', name: 'Casque d\'astronaute', emoji: '🚀', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_astronaut.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['espace', 'premium']),
    // New hats
    const ClothingItem(id: 'hat_beret', name: 'Béret français', emoji: '🎨', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_beret.png', tags: ['france', 'artiste']),
    const ClothingItem(id: 'hat_baseball', name: 'Casquette', emoji: '🧢', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_baseball.png', tags: ['sport', 'casual']),
    const ClothingItem(id: 'hat_fedora', name: 'Fedora', emoji: '🎩', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_fedora.png', rarity: ItemRarity.uncommon, tags: ['chic', 'mystère']),
    const ClothingItem(id: 'hat_pirate', name: 'Chapeau de pirate', emoji: '🏴‍☠️', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_pirate.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['aventure', 'premium']),
    const ClothingItem(id: 'hat_chef', name: 'Toque de chef', emoji: '👨‍🍳', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_chef.png', rarity: ItemRarity.uncommon, tags: ['cuisine', 'fun']),
    const ClothingItem(id: 'hat_viking', name: 'Casque viking', emoji: '⚔️', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_viking.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.premium, tags: ['aventure', 'premium']),
    const ClothingItem(id: 'hat_halo', name: 'Auréole', emoji: '😇', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_halo.png', rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Offre un Pigio+ à un proche', tags: ['ange', 'spécial']),
    const ClothingItem(id: 'hat_flower_crown', name: 'Couronne de fleurs', emoji: '🌺', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_flower_crown.png', rarity: ItemRarity.uncommon, season: 'spring', tags: ['printemps', 'nature']),
    const ClothingItem(id: 'hat_headband', name: 'Bandeau sport', emoji: '💪', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_headband.png', tags: ['sport', 'énergie']),
    const ClothingItem(id: 'hat_turban', name: 'Turban festif', emoji: '🪶', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_turban.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['chic', 'premium']),
    const ClothingItem(id: 'hat_tiara', name: 'Diadème', emoji: '👸', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_tiara.png', rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['luxe', 'premium']),
    const ClothingItem(id: 'hat_earmuffs', name: 'Cache-oreilles', emoji: '🎧', slot: ClothingSlot.hat, imageAsset: 'assets/wardrobe/hats/hat_earmuffs.png', tags: ['hiver', 'cozy']),

    // ═══════════════════════════════════════════════════════════════════
    // GLASSES (25 items)
    // ═══════════════════════════════════════════════════════════════════
    const ClothingItem(id: 'glasses_sun', name: 'Lunettes de soleil', emoji: '🕶️', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_sun.png', tags: ['été', 'soleil']),
    const ClothingItem(id: 'glasses_heart', name: 'Lunettes cœur', emoji: '💕', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_heart.png', rarity: ItemRarity.uncommon, tags: ['amour', 'valentin']),
    const ClothingItem(id: 'glasses_reading', name: 'Lunettes lecture', emoji: '👓', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_reading.png', tags: ['calme', 'lecture']),
    const ClothingItem(id: 'glasses_star', name: 'Lunettes étoile', emoji: '⭐', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_star.png', rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Atteins 30 jours de suite', tags: ['magique', 'spécial']),
    const ClothingItem(id: 'glasses_monocle', name: 'Monocle doré', emoji: '🧐', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_monocle.png', rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['chic', 'premium']),
    const ClothingItem(id: 'glasses_vr', name: 'Casque VR', emoji: '🥽', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_vr.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['tech', 'premium']),
    // New glasses
    const ClothingItem(id: 'glasses_round', name: 'Rondes vintage', emoji: '🔵', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_round.png', tags: ['rétro', 'chic']),
    const ClothingItem(id: 'glasses_cat_eye', name: 'Cat eye', emoji: '🐱', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_cat_eye.png', rarity: ItemRarity.uncommon, tags: ['chic', 'rétro']),
    const ClothingItem(id: 'glasses_ski', name: 'Masque de ski', emoji: '⛷️', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_ski.png', tags: ['hiver', 'sport']),
    const ClothingItem(id: 'glasses_3d', name: 'Lunettes 3D', emoji: '🎬', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_3d.png', rarity: ItemRarity.uncommon, tags: ['fun', 'cinéma']),
    const ClothingItem(id: 'glasses_steampunk', name: 'Lunettes steampunk', emoji: '⚙️', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_steampunk.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['steampunk', 'premium']),
    const ClothingItem(id: 'glasses_swim', name: 'Lunettes de piscine', emoji: '🏊', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_swim.png', tags: ['été', 'sport']),
    const ClothingItem(id: 'glasses_neon', name: 'Néon LED', emoji: '💡', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_neon.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['fête', 'premium']),
    const ClothingItem(id: 'glasses_pixel', name: 'Pixel deal-with-it', emoji: '🟩', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_pixel.png', rarity: ItemRarity.uncommon, tags: ['meme', 'fun']),
    const ClothingItem(id: 'glasses_rose', name: 'Teintées rose', emoji: '🌸', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_rose.png', tags: ['rétro', 'fun']),
    const ClothingItem(id: 'glasses_aviator', name: 'Aviateur', emoji: '✈️', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_aviator.png', rarity: ItemRarity.uncommon, tags: ['chic', 'voyage']),
    const ClothingItem(id: 'glasses_shield', name: 'Visière sport', emoji: '🏃', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_shield.png', tags: ['sport', 'énergie']),
    const ClothingItem(id: 'glasses_opera', name: 'Masque vénitien', emoji: '🎭', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_opera.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.premium, tags: ['gala', 'premium']),
    const ClothingItem(id: 'glasses_nerd', name: 'Lunettes nerd', emoji: '🤓', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_nerd.png', tags: ['geek', 'lecture']),
    const ClothingItem(id: 'glasses_half_moon', name: 'Demi-lune', emoji: '🌓', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_half_moon.png', rarity: ItemRarity.uncommon, tags: ['sagesse', 'mystère']),
    const ClothingItem(id: 'glasses_butterfly', name: 'Papillon XL', emoji: '🦋', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_butterfly.png', rarity: ItemRarity.uncommon, tags: ['chic', 'été']),
    const ClothingItem(id: 'glasses_eye_patch', name: 'Cache-œil', emoji: '🏴‍☠️', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_eye_patch.png', rarity: ItemRarity.uncommon, tags: ['pirate', 'aventure']),
    const ClothingItem(id: 'glasses_cyberpunk', name: 'Visière cyber', emoji: '🤖', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_cyberpunk.png', rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['futur', 'premium']),
    const ClothingItem(id: 'glasses_disco', name: 'Lunettes disco', emoji: '🪩', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_disco.png', rarity: ItemRarity.uncommon, tags: ['fête', 'rétro']),
    const ClothingItem(id: 'glasses_loupe', name: 'Loupe détective', emoji: '🔎', slot: ClothingSlot.glasses, imageAsset: 'assets/wardrobe/glasses/glasses_loupe.png', rarity: ItemRarity.rare, isUnlocked: false, unlockHint: 'Atteins le niveau d\'amitié "BFF"', tags: ['mystère', 'spécial']),

    // ═══════════════════════════════════════════════════════════════════
    // TOPS (25 items)
    // ═══════════════════════════════════════════════════════════════════
    const ClothingItem(id: 'top_raincoat', name: 'Imperméable', emoji: '🧥', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_raincoat.png', tags: ['pluie', 'automne']),
    const ClothingItem(id: 'top_windbreaker', name: 'Coupe-vent', emoji: '🌬️', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_windbreaker.png', tags: ['pluie', 'vent', 'mi-saison']),
    const ClothingItem(id: 'top_scarf_thick', name: 'Écharpe polaire', emoji: '🧣', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_scarf_thick.png', tags: ['hiver', 'froid']),
    const ClothingItem(id: 'top_hawaiian', name: 'Chemise hawaïenne', emoji: '🏖️', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_hawaiian.png', tags: ['été', 'vacances']),
    const ClothingItem(id: 'top_linen', name: 'Chemise de lin', emoji: '🌤️', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_linen.png', tags: ['été', 'respirant', 'soleil']),
    const ClothingItem(id: 'top_pyjama', name: 'Pyjama', emoji: '🥱', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_pyjama.png', tags: ['nuit', 'cozy']),
    const ClothingItem(id: 'top_golden', name: 'Veste dorée', emoji: '✨', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_golden.png', rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Ajoute des vœux pour 5 proches différents', tags: ['chic', 'or', 'spécial']),
    const ClothingItem(id: 'top_tuxedo', name: 'Smoking', emoji: '🤵', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_tuxedo.png', rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['chic', 'gala', 'premium']),
    // New tops
    const ClothingItem(id: 'top_hoodie', name: 'Sweat à capuche', emoji: '🧥', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_hoodie.png', tags: ['casual', 'cozy']),
    const ClothingItem(id: 'top_vest', name: 'Gilet matelassé', emoji: '🦺', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_vest.png', tags: ['mi-saison', 'sport']),
    const ClothingItem(id: 'top_turtleneck', name: 'Col roulé', emoji: '🫁', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_turtleneck.png', tags: ['hiver', 'chic']),
    const ClothingItem(id: 'top_tank', name: 'Débardeur', emoji: '💪', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_tank.png', tags: ['été', 'sport']),
    const ClothingItem(id: 'top_blazer', name: 'Blazer', emoji: '👔', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_blazer.png', rarity: ItemRarity.uncommon, tags: ['chic', 'bureau']),
    const ClothingItem(id: 'top_overalls', name: 'Salopette', emoji: '👷', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_overalls.png', tags: ['casual', 'fun']),
    const ClothingItem(id: 'top_sweater', name: 'Pull tricoté', emoji: '🧶', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_sweater.png', tags: ['hiver', 'cozy']),
    const ClothingItem(id: 'top_poncho', name: 'Poncho', emoji: '🏔️', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_poncho.png', rarity: ItemRarity.uncommon, tags: ['voyage', 'pluie']),
    const ClothingItem(id: 'top_kimono', name: 'Kimono', emoji: '🎎', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_kimono.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['élégant', 'premium']),
    const ClothingItem(id: 'top_lab_coat', name: 'Blouse de labo', emoji: '🔬', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_lab_coat.png', rarity: ItemRarity.uncommon, tags: ['science', 'fun']),
    const ClothingItem(id: 'top_apron', name: 'Tablier', emoji: '🍰', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_apron.png', tags: ['cuisine', 'fun']),
    const ClothingItem(id: 'top_sailor', name: 'Marinière', emoji: '⚓', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_sailor.png', tags: ['mer', 'france']),
    const ClothingItem(id: 'top_varsity', name: 'Blouson varsity', emoji: '🏈', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_varsity.png', rarity: ItemRarity.uncommon, tags: ['sport', 'casual']),
    const ClothingItem(id: 'top_denim', name: 'Veste en jean', emoji: '👖', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_denim.png', tags: ['casual', 'mi-saison']),
    const ClothingItem(id: 'top_leather', name: 'Perfecto cuir', emoji: '🏍️', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_leather.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.premium, tags: ['rock', 'premium']),
    const ClothingItem(id: 'top_cardigan', name: 'Cardigan', emoji: '🧵', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_cardigan.png', tags: ['cozy', 'automne']),
    const ClothingItem(id: 'top_jersey', name: 'Maillot de foot', emoji: '⚽', slot: ClothingSlot.top, imageAsset: 'assets/wardrobe/tops/top_jersey.png', rarity: ItemRarity.uncommon, tags: ['sport', 'fun']),

    // ═══════════════════════════════════════════════════════════════════
    // SCARVES (25 items) — new category, fills the scarf slot
    // ═══════════════════════════════════════════════════════════════════
    const ClothingItem(id: 'scarf_classic', name: 'Écharpe classique', emoji: '🧣', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_classic.png', tags: ['hiver', 'basique']),
    const ClothingItem(id: 'scarf_silk', name: 'Foulard en soie', emoji: '🎀', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_silk.png', rarity: ItemRarity.uncommon, tags: ['chic', 'élégant']),
    const ClothingItem(id: 'scarf_plaid', name: 'Écharpe écossaise', emoji: '🏴󠁧󠁢󠁳󠁣󠁴󠁿', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_plaid.png', tags: ['hiver', 'rétro']),
    const ClothingItem(id: 'scarf_infinity', name: 'Snood', emoji: '♾️', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_infinity.png', tags: ['hiver', 'cozy']),
    const ClothingItem(id: 'scarf_bandana', name: 'Bandana', emoji: '🤠', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_bandana.png', tags: ['casual', 'aventure']),
    const ClothingItem(id: 'scarf_bow', name: 'Lavallière', emoji: '🎗️', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_bow.png', rarity: ItemRarity.uncommon, tags: ['chic', 'rétro']),
    const ClothingItem(id: 'scarf_fur', name: 'Col en fausse fourrure', emoji: '🦊', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_fur.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['luxe', 'premium']),
    const ClothingItem(id: 'scarf_knit', name: 'Écharpe tricotée', emoji: '🧶', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_knit.png', tags: ['cozy', 'automne']),
    const ClothingItem(id: 'scarf_chain', name: 'Chaîne dorée', emoji: '⛓️', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_chain.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.premium, tags: ['luxe', 'premium']),
    const ClothingItem(id: 'scarf_lei', name: 'Collier de fleurs', emoji: '🌺', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_lei.png', rarity: ItemRarity.uncommon, season: 'summer', tags: ['été', 'tropical']),
    const ClothingItem(id: 'scarf_medal', name: 'Médaille d\'or', emoji: '🏅', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_medal.png', rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Complète 10 défis quotidiens', tags: ['sport', 'spécial']),
    const ClothingItem(id: 'scarf_pearls', name: 'Collier de perles', emoji: '📿', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_pearls.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['chic', 'premium']),
    const ClothingItem(id: 'scarf_tie', name: 'Cravate', emoji: '👔', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_tie.png', tags: ['bureau', 'chic']),
    const ClothingItem(id: 'scarf_garland', name: 'Guirlande lumineuse', emoji: '🎄', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_garland.png', rarity: ItemRarity.uncommon, season: 'winter', tags: ['noël', 'fête']),
    const ClothingItem(id: 'scarf_pendant', name: 'Pendentif cristal', emoji: '💠', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_pendant.png', rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['luxe', 'premium']),
    const ClothingItem(id: 'scarf_headphones', name: 'Casque audio', emoji: '🎧', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_headphones.png', tags: ['musique', 'casual']),
    const ClothingItem(id: 'scarf_whistle', name: 'Sifflet d\'arbitre', emoji: '📯', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_whistle.png', rarity: ItemRarity.uncommon, tags: ['sport', 'fun']),
    const ClothingItem(id: 'scarf_stethoscope', name: 'Stéthoscope', emoji: '🩺', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_stethoscope.png', rarity: ItemRarity.uncommon, tags: ['science', 'fun']),
    const ClothingItem(id: 'scarf_camera', name: 'Appareil photo', emoji: '📸', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_camera.png', tags: ['voyage', 'art']),
    const ClothingItem(id: 'scarf_feather_boa', name: 'Boa à plumes', emoji: '🪶', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_feather_boa.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['fête', 'premium']),
    const ClothingItem(id: 'scarf_necklace_star', name: 'Pendentif étoile', emoji: '⭐', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_necklace_star.png', rarity: ItemRarity.uncommon, tags: ['magique', 'chic']),
    const ClothingItem(id: 'scarf_lanyard', name: 'Badge VIP', emoji: '🪪', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_lanyard.png', rarity: ItemRarity.rare, isUnlocked: false, unlockHint: 'Fais accepter 3 invitations', tags: ['social', 'spécial']),
    const ClothingItem(id: 'scarf_cape_mini', name: 'Mini-cape', emoji: '🦸', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_cape_mini.png', rarity: ItemRarity.uncommon, tags: ['héros', 'fun']),
    const ClothingItem(id: 'scarf_rainbow', name: 'Écharpe arc-en-ciel', emoji: '🌈', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_rainbow.png', tags: ['couleur', 'fun']),
    const ClothingItem(id: 'scarf_dog_tag', name: 'Plaque militaire', emoji: '🪖', slot: ClothingSlot.scarf, imageAsset: 'assets/wardrobe/scarves/scarf_dog_tag.png', rarity: ItemRarity.uncommon, tags: ['aventure', 'tough']),

    // ═══════════════════════════════════════════════════════════════════
    // SHOES (25 items)
    // ═══════════════════════════════════════════════════════════════════
    const ClothingItem(id: 'shoes_boots', name: 'Bottes de pluie', emoji: '🥾', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_boots.png', tags: ['pluie', 'automne']),
    const ClothingItem(id: 'shoes_flipflops', name: 'Tongs', emoji: '🩴', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_flipflops.png', tags: ['été', 'plage']),
    const ClothingItem(id: 'shoes_sandals', name: 'Sandales', emoji: '👡', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_sandals.png', tags: ['été', 'soleil', 'ville']),
    const ClothingItem(id: 'shoes_slippers', name: 'Chaussons', emoji: '🧦', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_slippers.png', tags: ['cozy', 'nuit']),
    const ClothingItem(id: 'shoes_golden', name: 'Baskets dorées', emoji: '👟', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_golden.png', rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Atteins 50 vœux enregistrés', tags: ['or', 'spécial']),
    const ClothingItem(id: 'shoes_crystal', name: 'Chaussures de cristal', emoji: '✨', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_crystal.png', rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['luxe', 'premium']),
    // New shoes
    const ClothingItem(id: 'shoes_sneakers', name: 'Sneakers', emoji: '👟', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_sneakers.png', tags: ['casual', 'sport']),
    const ClothingItem(id: 'shoes_heels', name: 'Talons hauts', emoji: '👠', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_heels.png', rarity: ItemRarity.uncommon, tags: ['chic', 'gala']),
    const ClothingItem(id: 'shoes_cowboy', name: 'Santiags', emoji: '🤠', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_cowboy.png', rarity: ItemRarity.uncommon, tags: ['aventure', 'country']),
    const ClothingItem(id: 'shoes_ballet', name: 'Chaussons de danse', emoji: '🩰', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_ballet.png', rarity: ItemRarity.uncommon, tags: ['danse', 'élégant']),
    const ClothingItem(id: 'shoes_roller', name: 'Rollers', emoji: '🛼', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_roller.png', rarity: ItemRarity.uncommon, tags: ['sport', 'fun']),
    const ClothingItem(id: 'shoes_ice_skates', name: 'Patins à glace', emoji: '⛸️', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_ice_skates.png', rarity: ItemRarity.uncommon, season: 'winter', tags: ['hiver', 'sport']),
    const ClothingItem(id: 'shoes_crocs', name: 'Sabots', emoji: '🐊', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_crocs.png', tags: ['casual', 'fun']),
    const ClothingItem(id: 'shoes_platform', name: 'Plateformes', emoji: '🏗️', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_platform.png', rarity: ItemRarity.uncommon, tags: ['rétro', 'fun']),
    const ClothingItem(id: 'shoes_moon', name: 'Moon boots', emoji: '🌙', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_moon.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['espace', 'premium']),
    const ClothingItem(id: 'shoes_hiking', name: 'Chaussures de rando', emoji: '🏔️', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_hiking.png', tags: ['nature', 'sport']),
    const ClothingItem(id: 'shoes_loafers', name: 'Mocassins', emoji: '👞', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_loafers.png', tags: ['chic', 'bureau']),
    const ClothingItem(id: 'shoes_combat', name: 'Rangers', emoji: '🪖', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_combat.png', rarity: ItemRarity.uncommon, tags: ['tough', 'aventure']),
    const ClothingItem(id: 'shoes_running', name: 'Running', emoji: '🏃', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_running.png', tags: ['sport', 'énergie']),
    const ClothingItem(id: 'shoes_clogs', name: 'Sabots en bois', emoji: '🪵', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_clogs.png', rarity: ItemRarity.uncommon, tags: ['rétro', 'fun']),
    const ClothingItem(id: 'shoes_fuzzy', name: 'Chaussons peluche', emoji: '🧸', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_fuzzy.png', tags: ['cozy', 'mignon']),
    const ClothingItem(id: 'shoes_ski', name: 'Chaussures de ski', emoji: '⛷️', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_ski.png', rarity: ItemRarity.uncommon, season: 'winter', tags: ['hiver', 'sport']),
    const ClothingItem(id: 'shoes_gladiator', name: 'Sandales gladiateur', emoji: '🏛️', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_gladiator.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['chic', 'premium']),
    const ClothingItem(id: 'shoes_rocket', name: 'Bottes à réaction', emoji: '🚀', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_rocket.png', rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['futur', 'premium']),
    const ClothingItem(id: 'shoes_knight', name: 'Bottes de chevalier', emoji: '⚔️', slot: ClothingSlot.shoes, imageAsset: 'assets/wardrobe/shoes/shoes_knight.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['aventure', 'premium']),

    // ═══════════════════════════════════════════════════════════════════
    // ACCESSORIES (25 items)
    // ═══════════════════════════════════════════════════════════════════
    const ClothingItem(id: 'acc_umbrella', name: 'Parapluie', emoji: '☂️', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_umbrella.png', tags: ['pluie']),
    const ClothingItem(id: 'acc_flowers', name: 'Bouquet', emoji: '💐', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_flowers.png', rarity: ItemRarity.uncommon, tags: ['amour', 'printemps', 'fête']),
    const ClothingItem(id: 'acc_flag', name: 'Drapeau tricolore', emoji: '🇫🇷', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_flag.png', rarity: ItemRarity.rare, season: 'summer', isUnlocked: false, unlockHint: 'Ajoute 5 contacts', tags: ['france', 'fête']),
    const ClothingItem(id: 'acc_pumpkin', name: 'Citrouille', emoji: '🎃', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_pumpkin.png', rarity: ItemRarity.uncommon, season: 'autumn', tags: ['halloween']),
    const ClothingItem(id: 'acc_star', name: 'Étoile magique', emoji: '🌟', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_star.png', rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Atteins 10 contacts', tags: ['magique', 'spécial']),
    const ClothingItem(id: 'acc_egg', name: 'Œuf de Pâques', emoji: '🥚', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_egg.png', rarity: ItemRarity.uncommon, season: 'spring', tags: ['pâques', 'printemps']),
    const ClothingItem(id: 'acc_bowtie', name: 'Nœud papillon', emoji: '🎀', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_bowtie.png', rarity: ItemRarity.uncommon, isUnlocked: false, unlockHint: 'Crée ton premier vœu', tags: ['chic', 'fête']),
    const ClothingItem(id: 'acc_cape', name: 'Cape de super-héros', emoji: '🦸', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_cape.png', rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Réserve 3 vœux pour tes proches', tags: ['héros', 'spécial']),
    const ClothingItem(id: 'acc_friendship', name: 'Bracelet d\'amitié', emoji: '🤝', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_friendship.png', rarity: ItemRarity.rare, isUnlocked: false, unlockHint: 'Fais accepter ta première invitation', tags: ['amitié', 'social']),
    const ClothingItem(id: 'acc_trophy', name: 'Trophée doré', emoji: '🏆', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_trophy.png', rarity: ItemRarity.legendary, isUnlocked: false, unlockHint: 'Atteins 7 jours de suite', tags: ['spécial', 'fête']),
    const ClothingItem(id: 'acc_gift', name: 'Paquet cadeau', emoji: '🎁', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_gift.png', rarity: ItemRarity.rare, isUnlocked: false, unlockHint: 'Crée ta première cagnotte cadeau', tags: ['cadeau', 'social']),
    const ClothingItem(id: 'acc_wand', name: 'Baguette magique', emoji: '🪄', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_wand.png', rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['magique', 'premium']),
    const ClothingItem(id: 'acc_guitar', name: 'Guitare', emoji: '🎸', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_guitar.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['musique', 'premium']),
    // New accessories
    const ClothingItem(id: 'acc_backpack', name: 'Sac à dos', emoji: '🎒', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_backpack.png', tags: ['voyage', 'casual']),
    const ClothingItem(id: 'acc_skateboard', name: 'Skateboard', emoji: '🛹', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_skateboard.png', rarity: ItemRarity.uncommon, tags: ['sport', 'fun']),
    const ClothingItem(id: 'acc_teddy', name: 'Nounours', emoji: '🧸', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_teddy.png', tags: ['cozy', 'mignon']),
    const ClothingItem(id: 'acc_balloon', name: 'Ballon cœur', emoji: '🎈', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_balloon.png', rarity: ItemRarity.uncommon, tags: ['fête', 'amour']),
    const ClothingItem(id: 'acc_lantern', name: 'Lanterne', emoji: '🏮', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_lantern.png', rarity: ItemRarity.uncommon, tags: ['nuit', 'magique']),
    const ClothingItem(id: 'acc_shield', name: 'Bouclier', emoji: '🛡️', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_shield.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['héros', 'premium']),
    const ClothingItem(id: 'acc_book', name: 'Grimoire', emoji: '📖', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_book.png', rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.actionBased, actionKey: "legacy_plume", tags: ['magique', 'premium']),
    const ClothingItem(id: 'acc_crystal_ball', name: 'Boule de cristal', emoji: '🔮', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_crystal_ball.png', rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['magique', 'premium']),
    const ClothingItem(id: 'acc_fishing_rod', name: 'Canne à pêche', emoji: '🎣', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_fishing_rod.png', tags: ['nature', 'calme']),
    const ClothingItem(id: 'acc_paint_palette', name: 'Palette de peintre', emoji: '🎨', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_paint_palette.png', rarity: ItemRarity.uncommon, tags: ['art', 'créatif']),
    const ClothingItem(id: 'acc_sword', name: 'Épée lumineuse', emoji: '⚔️', slot: ClothingSlot.accessory, imageAsset: 'assets/wardrobe/accessories/acc_sword.png', rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['héros', 'premium']),

    // Limited-time seasonal drops (computed dynamically per year)
    ..._seasonalItems(),
  ];

  /// Generates seasonal items with rolling expiration dates based on the current year.
  /// Each item is available for its 3-month season and rolls over yearly.
  static List<ClothingItem> _seasonalItems() {
    final now = DateTime.now();
    final y = now.year;
    // Season boundaries: spring Mar-Jun, summer Jun-Sep, autumn Sep-Dec, winter Dec-Mar
    final seasons = <({String id, String name, String emoji, ClothingSlot slot, List<String> tags, DateTime start, DateTime end})>[
      (id: 'hat_cherry', name: 'Couronne de cerisier', emoji: '🌸', slot: ClothingSlot.hat, tags: ['printemps', 'limité'], start: DateTime(y, 3, 1), end: DateTime(y, 6, 1)),
      (id: 'glasses_summer', name: 'Lunettes tropicales', emoji: '🍉', slot: ClothingSlot.glasses, tags: ['été', 'limité'], start: DateTime(y, 6, 1), end: DateTime(y, 9, 1)),
      (id: 'acc_leaf', name: "Feuille d'automne", emoji: '🍂', slot: ClothingSlot.accessory, tags: ['automne', 'limité'], start: DateTime(y, 9, 1), end: DateTime(y, 12, 1)),
      (id: 'shoes_snow', name: 'Bottes de neige', emoji: '❄️', slot: ClothingSlot.shoes, tags: ['hiver', 'limité'], start: DateTime(y, 12, 1), end: DateTime(y + 1, 3, 1)),
    ];
    // Also include previous winter if we're in Jan-Feb
    if (now.month < 3) {
      seasons.add((id: 'shoes_snow', name: 'Bottes de neige', emoji: '❄️', slot: ClothingSlot.shoes, tags: ['hiver', 'limité'], start: DateTime(y - 1, 12, 1), end: DateTime(y, 3, 1)));
    }
    // Return only items whose season window includes now
    return seasons
        .where((s) => now.isAfter(s.start) || now.isAtSameMomentAs(s.start))
        .where((s) => now.isBefore(s.end))
        .map((s) => ClothingItem(
              id: s.id,
              name: s.name,
              emoji: s.emoji,
              slot: s.slot,
              rarity: ItemRarity.rare,
              tags: s.tags,
              expiresAt: s.end,
            ))
        .toList();
  }

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
    Achievement(
      id: 'achievement_streak_7',
      unlockItemId: 'acc_trophy',
      hintFr: 'Connecte-toi 7 jours de suite',
      hintEn: 'Log in 7 days in a row',
      check: (s) => s.loginStreak >= 7,
    ),
    Achievement(
      id: 'achievement_streak_30',
      unlockItemId: 'glasses_star',
      hintFr: 'Connecte-toi 30 jours de suite',
      hintEn: 'Log in 30 days in a row',
      check: (s) => s.loginStreak >= 30,
    ),
    // Real-world caring achievements (Finch model)
    Achievement(
      id: 'achievement_first_pot',
      unlockItemId: 'acc_gift',
      hintFr: 'Crée ta première cagnotte cadeau',
      hintEn: 'Create your first gift pot',
      check: (s) => s.giftPots.isNotEmpty,
    ),
    Achievement(
      id: 'achievement_wishes_5_contacts',
      unlockItemId: 'top_golden',
      hintFr: 'Ajoute des vœux pour 5 proches différents',
      hintEn: 'Add wishes for 5 different contacts',
      check: (s) => s.wishes
          .where((w) => w.contactId != null)
          .map((w) => w.contactId)
          .toSet()
          .length >= 5,
    ),
    Achievement(
      id: 'achievement_sizes_shared',
      unlockItemId: 'hat_heart',
      hintFr: 'Remplis au moins 3 catégories de tailles',
      hintEn: 'Fill in at least 3 size categories',
      check: (s) => s.sizes.where((sz) => sz.contactId == null).length >= 3,
    ),
    Achievement(
      id: 'achievement_50_wishes',
      unlockItemId: 'shoes_golden',
      hintFr: 'Atteins 50 vœux enregistrés',
      hintEn: 'Reach 50 saved wishes',
      check: (s) => s.wishes.length >= 50,
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

  /// Check if any outfit combos are fully equipped and not yet marked as completed.
  /// Returns list of newly completed combo names (French).
  static List<OutfitCombo> checkCompletedCombos(PigioAppState state) {
    final equipped = state.activeOutfit.values.whereType<String>().toSet();
    final completed = <OutfitCombo>[];
    for (final combo in combos) {
      if (state.completedCombos.contains(combo.nameFr)) continue;
      if (combo.itemIds.every(equipped.contains)) {
        completed.add(combo);
      }
    }
    return completed;
  }

  static ClothingItem? getItem(String id) => catalog.where((c) => c.id == id).firstOrNull;

  static int countForSlot(ClothingSlot? slot) {
    if (slot == null) return catalog.length;
    return catalog.where((c) => c.slot == slot).length;
  }

  // ─── LIMITED-TIME DROPS ────────────────────────────────────────────────────

  /// Returns currently available limited-time items.
  static List<ClothingItem> seasonalDrops(DateTime now) =>
      catalog.where((c) => c.expiresAt != null && c.isAvailable).toList();

  /// Returns limited items expiring within [days].
  static List<ClothingItem> expiringSoon(DateTime now, {int days = 7}) =>
      seasonalDrops(now).where((c) =>
        c.expiresAt!.difference(now).inDays <= days &&
        c.expiresAt!.isAfter(now)).toList();

  // ─── DAILY CHALLENGES ────────────────────────────────────────────────────

  static const List<DailyChallenge> _challenges = [
    DailyChallenge(id: 'cozy_monday', titleFr: 'Lundi cozy — équipe un objet douillet', titleEn: 'Cozy Monday — equip a cozy item', requiredTags: ['cozy', 'nuit']),
    DailyChallenge(id: 'rainy_day', titleFr: 'Jour de pluie — prépare-toi pour l\'averse', titleEn: 'Rainy Day — gear up for rain', requiredTags: ['pluie']),
    DailyChallenge(id: 'sunny_vibes', titleFr: 'Soleil radieux — mets un accessoire d\'été', titleEn: 'Sunny Vibes — equip a summer item', requiredTags: ['été', 'soleil']),
    DailyChallenge(id: 'party_time', titleFr: 'C\'est la fête — habille Pigio pour la soirée', titleEn: 'Party Time — dress Pigio for a party', requiredTags: ['fête']),
    DailyChallenge(id: 'winter_wrap', titleFr: 'Hiver glacial — couvre bien Pigio', titleEn: 'Winter Wrap — bundle Pigio up warm', requiredTags: ['hiver', 'froid']),
    DailyChallenge(id: 'mystery_rare', titleFr: 'Chasseur de raretés — équipe un objet rare+', titleEn: 'Rarity Hunter — equip a rare+ item', requiredRarity: ItemRarity.rare),
    DailyChallenge(id: 'spring_bloom', titleFr: 'Printemps fleuri — un objet de saison', titleEn: 'Spring Bloom — equip a spring item', requiredTags: ['printemps']),
    DailyChallenge(id: 'night_owl', titleFr: 'Noctambule — prépare Pigio pour la nuit', titleEn: 'Night Owl — get Pigio night-ready', requiredTags: ['nuit']),
    DailyChallenge(id: 'beach_day', titleFr: 'Journée plage — ambiance vacances', titleEn: 'Beach Day — holiday vibes', requiredTags: ['plage', 'vacances']),
    DailyChallenge(id: 'love_letter', titleFr: 'Billet doux — un objet plein d\'amour', titleEn: 'Love Letter — equip something lovely', requiredTags: ['amour']),
    DailyChallenge(id: 'legend_day', titleFr: 'Jour légendaire — équipe un objet légendaire', titleEn: 'Legendary Day — equip a legendary item', requiredRarity: ItemRarity.legendary),
    DailyChallenge(id: 'full_outfit', titleFr: 'Tenue complète — remplis 4 emplacements', titleEn: 'Full Outfit — fill 4 slots'),
    DailyChallenge(id: 'autumn_leaves', titleFr: 'Feuilles d\'automne — ambiance automnale', titleEn: 'Autumn Leaves — autumn vibes', requiredTags: ['automne', 'halloween']),
    DailyChallenge(id: 'magic_touch', titleFr: 'Touche magique — un objet spécial', titleEn: 'Magic Touch — equip something magical', requiredTags: ['magique', 'spécial']),
  ];

  /// Deterministic daily challenge based on day-of-year.
  static DailyChallenge todaysChallenge(DateTime now) {
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return _challenges[dayOfYear % _challenges.length];
  }

  /// Whether the current outfit satisfies the given challenge.
  static bool isChallengeMet(DailyChallenge challenge, PigioAppState state) {
    final equipped = state.activeOutfit.values.whereType<String>().toList();

    // Special case: "full_outfit" challenge
    if (challenge.id == 'full_outfit') {
      return equipped.length >= 4;
    }

    // Rarity check
    if (challenge.requiredRarity != null) {
      return equipped.any((id) {
        final item = getItem(id);
        return item != null && item.rarity.index >= challenge.requiredRarity!.index;
      });
    }

    // Tag check — any equipped item matches any required tag
    if (challenge.requiredTags.isNotEmpty) {
      return equipped.any((id) {
        final item = getItem(id);
        return item != null && item.tags.any(challenge.requiredTags.contains);
      });
    }

    return false;
  }

  // ─── COLLECTION PROGRESS ──────────────────────────────────────────────────

  static int get totalItemCount => catalog.length;

  static int unlockedCount(PigioAppState state) =>
      catalog.where((c) => isItemUnlocked(c.id, state)).length;

  static Map<ItemRarity, ({int unlocked, int total})> rarityBreakdown(PigioAppState state) {
    final result = <ItemRarity, ({int unlocked, int total})>{};
    for (final rarity in ItemRarity.values) {
      final items = catalog.where((c) => c.rarity == rarity);
      final unlocked = items.where((c) => isItemUnlocked(c.id, state)).length;
      result[rarity] = (unlocked: unlocked, total: items.length);
    }
    return result;
  }

  static int completedComboCount(PigioAppState state) => state.completedCombos.length;
  static int get totalComboCount => combos.length;

  /// Check and claim collection milestones (25%, 50%, 75%, 100%).
  static void checkCollectionMilestones(PigioAppState state) {
    final percent = (unlockedCount(state) * 100) ~/ totalItemCount;
    for (final threshold in [25, 50, 75, 100]) {
      if (percent >= threshold) {
        final key = 'collection_$threshold';
        if (!state.collectionMilestones.contains(key)) {
          state.claimCollectionMilestone(key, percent: threshold);
        }
      }
    }
  }

  // ─── OUTFIT OF THE DAY ─────────────────────────────────────────────────────

  /// Suggest a full outfit based on weather, combos, and personality.
  /// Returns a map of slot → itemId for each recommended slot.
  static Map<ClothingSlot, String> suggestOutfitOfTheDay(PigioAppState state, {WeatherData? weather}) {
    final result = <ClothingSlot, String>{};
    bool unlocked(String id) => isItemUnlocked(id, state);

    // 1. Weather-driven slot filling
    if (weather != null) {
      if (weather.condition == 'rain' || weather.condition == 'storm') {
        _fillSlot(result, ClothingSlot.accessory, 'acc_umbrella', unlocked);
        _fillSlot(result, ClothingSlot.top, 'top_raincoat', unlocked) ||
            _fillSlot(result, ClothingSlot.top, 'top_windbreaker', unlocked);
        _fillSlot(result, ClothingSlot.shoes, 'shoes_boots', unlocked);
      } else if (weather.condition == 'snow') {
        _fillSlot(result, ClothingSlot.hat, 'hat_winter', unlocked);
        _fillSlot(result, ClothingSlot.top, 'top_scarf_thick', unlocked);
        _fillSlot(result, ClothingSlot.shoes, 'shoes_boots', unlocked);
      } else if (weather.temperature > 28 && weather.isDay) {
        _fillSlot(result, ClothingSlot.glasses, 'glasses_sun', unlocked);
        _fillSlot(result, ClothingSlot.hat, 'hat_straw', unlocked) ||
            _fillSlot(result, ClothingSlot.hat, 'hat_bucket', unlocked);
        _fillSlot(result, ClothingSlot.top, 'top_hawaiian', unlocked) ||
            _fillSlot(result, ClothingSlot.top, 'top_linen', unlocked);
        _fillSlot(result, ClothingSlot.shoes, 'shoes_sandals', unlocked) ||
            _fillSlot(result, ClothingSlot.shoes, 'shoes_flipflops', unlocked);
      } else if (weather.temperature < 5) {
        _fillSlot(result, ClothingSlot.hat, 'hat_winter', unlocked);
        _fillSlot(result, ClothingSlot.top, 'top_scarf_thick', unlocked);
        _fillSlot(result, ClothingSlot.shoes, 'shoes_boots', unlocked);
      }
    }

    // 1.5. Mood-driven bias
    final mood = state.userMood;
    if (mood == 'sad' || mood == 'tired') {
      // Cozy items for negative moods
      _fillSlot(result, ClothingSlot.top, 'top_pyjama', unlocked);
      _fillSlot(result, ClothingSlot.shoes, 'shoes_slippers', unlocked);
      _fillSlot(result, ClothingSlot.glasses, 'glasses_reading', unlocked);
    } else if (mood == 'energetic') {
      // Outdoor/summer items for energetic mood
      _fillSlot(result, ClothingSlot.glasses, 'glasses_sun', unlocked);
      _fillSlot(result, ClothingSlot.top, 'top_hawaiian', unlocked);
      _fillSlot(result, ClothingSlot.shoes, 'shoes_sandals', unlocked);
    }

    // 2. Fill remaining from best matching combo
    for (final combo in combos) {
      if (combo.itemIds.any((id) => result.containsValue(id))) {
        for (final itemId in combo.itemIds) {
          final item = getItem(itemId);
          if (item != null && !result.containsKey(item.slot) && unlocked(itemId)) {
            result[item.slot] = itemId;
          }
        }
        break;
      }
    }

    // 3. Fallback: personality-scored items for unfilled slots
    final scores = personalityScores(state);
    if (scores.isNotEmpty) {
      final sorted = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted) {
        final item = getItem(entry.key);
        if (item != null && !result.containsKey(item.slot) && unlocked(entry.key)) {
          result[item.slot] = entry.key;
        }
      }
    }

    return result;
  }

  static bool _fillSlot(Map<ClothingSlot, String> result, ClothingSlot slot, String itemId, bool Function(String) unlocked) {
    if (result.containsKey(slot)) return false;
    if (!unlocked(itemId)) return false;
    result[slot] = itemId;
    return true;
  }

  /// Check whether an item is unlocked for the user.
  /// Items with `isUnlocked: true` in catalog are always available.
  /// Items with `isUnlocked: false` require the matching achievement or
  /// must be present in `state.unlockedClothing`.
  static bool isItemUnlocked(String itemId, PigioAppState state) {
    final item = getItem(itemId);
    if (item == null) return false;
    // Expired limited-time items are no longer available
    if (!item.isAvailable) return false;
    if (item.isUnlocked) return true;
    if (item.condition == UnlockCondition.premium && state.isPremium) return true;
    if (state.unlockedClothing.contains(itemId)) return true;
    return false;
  }

  /// Get the unlock hint for a locked item (localized).
  static String? getUnlockHint(String itemId, String lang) {
    final item = getItem(itemId);
    if (item?.condition == UnlockCondition.premium) {
      return lang == 'fr' ? 'Exclusif Pigio+' : 'Pigio+ Exclusive';
    }
    final achievement = achievements.where((a) => a.unlockItemId == itemId).firstOrNull;
    if (achievement != null) {
      return lang == 'fr' ? achievement.hintFr : achievement.hintEn;
    }
    if (item?.condition == UnlockCondition.actionBased) {
      return lang == 'fr' ? 'Complétez des actions pour débloquer' : 'Complete actions to unlock';
    }
    return null;
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

  // ─── LEGACY OCCASION PASS ITEMS ─────────────────────────────────────────

  /// Former season-exclusive wardrobe items unlocked through the premium Occasion Pass track.
  /// Now converted to Pigio+ exclusive items.
  static const List<ClothingItem> occasionPassItems = [
    ClothingItem(id: 'hat_tophat_pass', name: 'Haut-de-forme', emoji: '🎩', slot: ClothingSlot.hat, rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.premium, tags: ['pass', 'chic']),
    ClothingItem(id: 'glasses_aviator_pass', name: 'Lunettes aviateur', emoji: '🕶️', slot: ClothingSlot.glasses, rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.premium, tags: ['pass', 'cool']),
    ClothingItem(id: 'scarf_festive_pass', name: 'Écharpe festive', emoji: '🧣', slot: ClothingSlot.scarf, rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.premium, tags: ['pass', 'fête']),
    ClothingItem(id: 'shoes_neon_pass', name: 'Baskets néon', emoji: '👟', slot: ClothingSlot.shoes, rarity: ItemRarity.rare, isUnlocked: false, condition: UnlockCondition.premium, tags: ['pass', 'fun']),
    ClothingItem(id: 'acc_butterfly_pass', name: 'Ailes de papillon', emoji: '🦋', slot: ClothingSlot.accessory, rarity: ItemRarity.legendary, isUnlocked: false, condition: UnlockCondition.premium, tags: ['pass', 'magique']),
  ];
}
