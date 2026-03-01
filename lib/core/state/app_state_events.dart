part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Event Management ─────────────────────────────────────────────────────────

extension EventsExtension on PigioAppState {
  void addEvent({
    required String title,
    required DateTime date,
    String typeEn = 'Event',
    String typeFr = 'Événement',
    String emoji = '🎉',
    Color color = const Color(0xFF6C5CE7),
    bool isRecurring = false,
    String? contactId,
  }) {
    _events.add(Event(
      id: _newId(),
      title: title,
      typeEn: typeEn,
      typeFr: typeFr,
      date: date,
      isRecurring: isRecurring,
      emoji: emoji,
      color: color,
      contactId: contactId,
    ));
    notifyListeners();
    _saveData();
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
    _saveData();
  }

  /// Returns events sorted by daysRemaining (closest first), up to [limit].
  /// Auto-generates birthday events from contacts that have birthdates set.
  List<Event> getUpcomingEvents({int limit = 10}) {
    final birthdayEvents = <Event>[];
    for (final c in _contacts) {
      if (c.birthdate != null && c.birthdate!.isNotEmpty) {
        final alreadyExists =
            _events.any((e) => e.contactId == c.id && e.typeEn == 'Birthday');
        if (!alreadyExists) {
          try {
            final parts = c.birthdate!.split('/');
            if (parts.length >= 2) {
              final day = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final year = parts.length > 2
                  ? int.parse(parts[2])
                  : DateTime.now().year;
              birthdayEvents.add(Event(
                id: 'birthday_${c.id}',
                title: c.name,
                typeEn: 'Birthday',
                typeFr: 'Anniversaire',
                date: DateTime(year, month, day),
                isRecurring: true,
                emoji: '🎂',
                color: const Color(0xFFFD79A8),
                contactId: c.id,
              ));
            }
          } catch (_) {
            // Invalid date format, skip
          }
        }
      }
    }

    final all = [..._events, ...birthdayEvents];
    all.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return all.take(limit).toList();
  }
}
