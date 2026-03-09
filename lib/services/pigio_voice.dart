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
        case 0: return 'Coucou ! 👋';
        case 1: return 'Salut, copain ! 🤝';
        case 2: return 'Hey l\'ami(e) ! 💛';
        case 3: return 'Mon BFF ! 🌟';
        case 4: return 'Mon âme sœur ! 💕';
        default: return 'Hey ! 🐧';
      }
    } else {
      switch (bondLevel) {
        case 0: return 'Hey there! 👋';
        case 1: return 'Hi buddy! 🤝';
        case 2: return 'Hey friend! 💛';
        case 3: return 'BFF! 🌟';
        case 4: return 'Soulmate! 💕';
        default: return 'Hey! 🐧';
      }
    }
  }

  static T _pick<T>(List<T> list) => list[_rng.nextInt(list.length)];

  static const _suffixesFr = [
    '🐧✨', '— Pigio', '💛🐧', '🎁✨', 
    '— ton Pigio préféré 🐧', '🌟',
  ];
  static const _suffixesEn = [
    '🐧✨', '— Pigio', '💛🐧', '🎁✨',
    '— your favorite Pigio 🐧', '🌟',
  ];
}
