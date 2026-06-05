import 'dart:math';

/// Wraps notification text in Pigio's playful voice.
/// Used by FCM + in-app notifications for consistent character.
class PigioVoice {
  static final _rng = Random();

  /// Pigio-style prefix for titles
  static String title(String originalTitle) => '🐧 $originalTitle';

  /// Wraps body text with Pigio's personality: adds emoji seasoning,
  /// playful suffix, and occasional French flair.
  static String body(String originalBody, {String lang = 'fr'}) {
    final suffix = _pick(lang == 'fr' ? _suffixesFr : _suffixesEn);
    return '$originalBody $suffix';
  }

  /// Generate a bond-level appropriate greeting for a push notification.
  static String bondGreeting(int bondLevel, {String lang = 'fr'}) {
    if (lang == 'fr') {
      switch (bondLevel) {
        case 0: return _pick(const ['Coucou ! 👋', 'Salut ! 🐧', 'Ohé ! 👋']);
        case 1: return _pick(const ['Salut, copain ! 🤝', 'Hé, on se connaît ! 🤝', 'Re-coucou ! 🐧']);
        case 2: return _pick(const ['Hey l\'ami(e) ! 💛', 'Mon pote ! 💛', 'Salut l\'artiste ! 🌟']);
        case 3: return _pick(const ['Mon BFF ! 🌟', 'Meilleur ami(e) ! ✨', 'Mon préféré(e) ! 🌟']);
        case 4: return _pick(const ['Mon âme sœur ! 💕', 'Mon tout ! 💕', 'Toi et moi pour toujours ! 💕']);
        default: return 'Hey ! 🐧';
      }
    } else {
      switch (bondLevel) {
        case 0: return _pick(const ['Hey there! 👋', 'Hello! 🐧', 'Hi! 👋']);
        case 1: return _pick(const ['Hi buddy! 🤝', 'Hey, I know you! 🤝', 'Hey again! 🐧']);
        case 2: return _pick(const ['Hey friend! 💛', 'My pal! 💛', 'Hey superstar! 🌟']);
        case 3: return _pick(const ['BFF! 🌟', 'Best friend! ✨', 'My favorite! 🌟']);
        case 4: return _pick(const ['Soulmate! 💕', 'My everything! 💕', 'You and me forever! 💕']);
        default: return 'Hey! 🐧';
      }
    }
  }

  static T _pick<T>(List<T> list) => list[_rng.nextInt(list.length)];

  static const _suffixesFr = [
    '🐧✨', '— Pigio', '💛🐧', '🎁✨',
    '— ton Pigio préféré 🐧', '🌟',
    '— bisou de Pigio 💋🐧', '🎯✨',
    '— Pigio veille sur toi 👀🐧', '🫶',
  ];
  static const _suffixesEn = [
    '🐧✨', '— Pigio', '💛🐧', '🎁✨',
    '— your favorite Pigio 🐧', '🌟',
    '— kiss from Pigio 💋🐧', '🎯✨',
    '— Pigio\'s got your back 👀🐧', '🫶',
  ];
}
