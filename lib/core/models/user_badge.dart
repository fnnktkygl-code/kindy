enum BadgeTrigger {
  coordinator, // Première cagnotte remplie à 100%
  antiDuplicate, // A réservé un article avant qu'un autre ne le fasse
  responsive, // A répondu à une invitation en moins de 24h
  generous, // A contribué à 5 cagnottes
  organizer, // A créé 3 événements
  fullCircle, // Tous les membres d'un cercle ont répondu
}

class UserBadge {
  final String id;
  final String titleFr;
  final String titleEn;
  final String emoji;
  final String descriptionFr;
  final String descriptionEn;
  final BadgeTrigger trigger;

  const UserBadge({
    required this.id,
    required this.titleFr,
    required this.titleEn,
    required this.emoji,
    required this.descriptionFr,
    required this.descriptionEn,
    required this.trigger,
  });

  static const List<UserBadge> catalog = [
    UserBadge(
      id: 'badge_coordinator',
      titleFr: 'Coordinateur',
      titleEn: 'Coordinator',
      emoji: '🎯',
      descriptionFr: 'Première cagnotte remplie à 100%',
      descriptionEn: 'First gift pot filled to 100%',
      trigger: BadgeTrigger.coordinator,
    ),
    UserBadge(
      id: 'badge_anti_duplicate',
      titleFr: 'Anti-doublon',
      titleEn: 'Duplicate-free',
      emoji: '🛡️',
      descriptionFr: 'A réservé un article avant qu\'un autre ne le fasse',
      descriptionEn: 'Reserved an item before someone else could duplicate it',
      trigger: BadgeTrigger.antiDuplicate,
    ),
    UserBadge(
      id: 'badge_responsive',
      titleFr: 'Réactif',
      titleEn: 'Responsive',
      emoji: '⚡',
      descriptionFr: 'A répondu à une invitation en moins de 24h',
      descriptionEn: 'Responded to an invitation in under 24h',
      trigger: BadgeTrigger.responsive,
    ),
    UserBadge(
      id: 'badge_generous',
      titleFr: 'Généreux',
      titleEn: 'Generous',
      emoji: '💝',
      descriptionFr: 'A contribué à 5 cagnottes',
      descriptionEn: 'Contributed to 5 gift pots',
      trigger: BadgeTrigger.generous,
    ),
    UserBadge(
      id: 'badge_organizer',
      titleFr: 'Organisateur',
      titleEn: 'Organizer',
      emoji: '📋',
      descriptionFr: 'A créé 3 événements',
      descriptionEn: 'Created 3 events',
      trigger: BadgeTrigger.organizer,
    ),
    UserBadge(
      id: 'badge_full_circle',
      titleFr: 'Cercle complet',
      titleEn: 'Full Circle',
      emoji: '🤝',
      descriptionFr: 'Tous les membres d\'un cercle ont répondu',
      descriptionEn: 'All members of a circle have responded',
      trigger: BadgeTrigger.fullCircle,
    ),
  ];
}
