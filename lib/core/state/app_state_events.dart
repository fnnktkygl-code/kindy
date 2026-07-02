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
    String? groupId,
    bool notificationsEnabled = true,
    List<int> reminderThresholds = const [7, 3, 1],
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
      groupId: groupId,
      notificationsEnabled: notificationsEnabled,
      reminderThresholds: reminderThresholds,
    ));
    notifyListeners();
    _saveData();
    _pushToCloud();
  }

  void updateEvent({
    required String id,
    String? title,
    DateTime? date,
    String? typeEn,
    String? typeFr,
    String? emoji,
    Color? color,
    bool? isRecurring,
    String? contactId,
    String? groupId,
    bool? notificationsEnabled,
    List<int>? reminderThresholds,
    DateTime? mutedUntil,
  }) {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _events[idx] = _events[idx].copyWith(
      title: title,
      date: date,
      typeEn: typeEn,
      typeFr: typeFr,
      emoji: emoji,
      color: color,
      isRecurring: isRecurring,
      contactId: contactId,
      groupId: groupId,
      notificationsEnabled: notificationsEnabled,
      reminderThresholds: reminderThresholds,
      mutedUntil: mutedUntil,
    );
    notifyListeners();
    _saveData();
    _pushToCloud();
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    notifyListeners();
    _saveData();
    _pushToCloud();
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
          } catch (e) {
            log.warn('Events', 'Invalid birthdate format for contact ${c.id}', e);
          }
        }
      }
    }

    final all = [..._events, ...birthdayEvents];
    all.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return all.take(limit).toList();
  }

  // ─── Notification Preferences ───────────────────────────────────────────────

  /// Update global notification preferences map.
  void updateNotificationPrefs(Map<String, dynamic> prefs) {
    _notificationPrefs = {..._notificationPrefs, ...prefs};
    notifyListeners();
    _saveData();
    _pushToCloud();
  }

  /// Mute a specific event by ID.
  void muteEvent(String eventId) {
    final mutedIds = List<String>.from(
      (_notificationPrefs['mutedEventIds'] as List<dynamic>?) ?? [],
    );
    if (!mutedIds.contains(eventId)) {
      mutedIds.add(eventId);
      _notificationPrefs['mutedEventIds'] = mutedIds;
      notifyListeners();
      _saveData();
      _pushToCloud();
    }
  }

  /// Unmute a specific event by ID.
  void unmuteEvent(String eventId) {
    final mutedIds = List<String>.from(
      (_notificationPrefs['mutedEventIds'] as List<dynamic>?) ?? [],
    );
    if (mutedIds.remove(eventId)) {
      _notificationPrefs['mutedEventIds'] = mutedIds;
      notifyListeners();
      _saveData();
      _pushToCloud();
    }
  }

  /// Mute a specific contact's birthday reminders.
  void muteContact(String contactId) {
    final mutedIds = List<String>.from(
      (_notificationPrefs['mutedContactIds'] as List<dynamic>?) ?? [],
    );
    if (!mutedIds.contains(contactId)) {
      mutedIds.add(contactId);
      _notificationPrefs['mutedContactIds'] = mutedIds;
      notifyListeners();
      _saveData();
      _pushToCloud();
    }
  }

  /// Unmute a specific contact's birthday reminders.
  void unmuteContact(String contactId) {
    final mutedIds = List<String>.from(
      (_notificationPrefs['mutedContactIds'] as List<dynamic>?) ?? [],
    );
    if (mutedIds.remove(contactId)) {
      _notificationPrefs['mutedContactIds'] = mutedIds;
      notifyListeners();
      _saveData();
      _pushToCloud();
    }
  }

  /// Set the default reminder thresholds.
  void setDefaultThresholds(List<int> thresholds) {
    _notificationPrefs['defaultThresholds'] = thresholds;
    notifyListeners();
    _saveData();
    _pushToCloud();
  }

  /// Toggle global mute for all reminders.
  void setGlobalMute(bool muted) {
    _notificationPrefs['globalMute'] = muted;
    notifyListeners();
    _saveData();
    _pushToCloud();
  }

  /// Whether global mute is active.
  bool get isGlobalMuted => _notificationPrefs['globalMute'] as bool? ?? false;

  /// Current default thresholds.
  List<int> get defaultThresholds {
    final raw = _notificationPrefs['defaultThresholds'] as List<dynamic>?;
    return raw?.map((e) => (e as num).toInt()).toList() ?? [7, 3, 1];
  }

  /// List of muted event IDs.
  List<String> get mutedEventIds =>
      List<String>.from((_notificationPrefs['mutedEventIds'] as List<dynamic>?) ?? []);

  /// List of muted contact IDs.
  List<String> get mutedContactIds =>
      List<String>.from((_notificationPrefs['mutedContactIds'] as List<dynamic>?) ?? []);
}

