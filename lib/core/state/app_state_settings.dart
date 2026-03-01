part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Settings, Mascot, UI State, Onboarding, Wizz, Outfit ───────────────────

extension SettingsExtension on PigioAppState {
  // ── Locale & Theme ─────────────────────────────────────────────────────────

  void setLocale(Locale locale) {
    if (_locale != locale) {
      _locale = locale;
      notifyListeners();
      _saveData();
    }
  }

  void setTheme(PigioThemeVariant variant) {
    if (_themeVariant != variant) {
      _themeVariant = variant;
      notifyListeners();
      _saveData();
    }
  }

  // ── Mascot API ────────────────────────────────────────────────────────────

  void setMascotSilent(bool val) {
    _mascotSilent = val;
    notifyListeners();
    _saveData();
  }

  void setMascotChattiness(int val) {
    _mascotChattiness = val.clamp(0, 2);
    notifyListeners();
    _saveData();
  }

  void setMascotScarfColor(Color val) {
    _mascotScarfColor = val;
    notifyListeners();
    _saveData();
  }

  void setMascotDefaultCorner(String val) {
    _mascotDefaultCorner = val;
    notifyListeners();
    _saveData();
  }

  void setMascotPrivacyMode(bool val) {
    _mascotPrivacyMode = val;
    notifyListeners();
    _saveData();
  }

  void setMascotMoment(MascotMoment m) {
    _mascotMoment = m;
    notifyListeners();
  }

  void clearMascotMoment() {
    _mascotMoment = MascotMoment.none;
    notifyListeners();
  }

  // ── Outfit Engine ──────────────────────────────────────────────────────────

  void equipClothing(ClothingSlot slot, String? itemId) {
    _activeOutfit[slot] = itemId;
    notifyListeners();
    _saveData();
  }

  void unequipClothing(ClothingSlot slot) {
    _activeOutfit.remove(slot);
    notifyListeners();
    _saveData();
  }

  void unlockClothing(String itemId) {
    if (!_unlockedClothing.contains(itemId)) {
      _unlockedClothing.add(itemId);
      notifyListeners();
      _saveData();
    }
  }

  void setClothingRequest(ClothingRequest? req) {
    _currentClothingRequest = req;
    notifyListeners();
  }

  void clearOutfit() {
    _activeOutfit.clear();
    notifyListeners();
    _saveData();
  }

  // ── Privacy & Consent ──────────────────────────────────────────────────────

  void setSurpriseMode(bool val) {
    _surpriseMode = val;
    notifyListeners();
    _saveData();
  }

  void setContactsConsentGiven(bool val) {
    _contactsConsentGiven = val;
    notifyListeners();
    _saveData();
  }

  // ── Onboarding & Personality ───────────────────────────────────────────────

  void completeOnboarding() {
    _onboardingCompleted = true;
    notifyListeners();
    _saveData();
  }

  Future<void> resetOnboardingForDebug() async {
    _onboardingCompleted = false;
    notifyListeners();
    await _saveData();
  }

  void savePersonalityProfile(Map<String, List<String>> answers) {
    _personalityProfile = Map<String, List<String>>.from(answers);
    notifyListeners();
    _saveData();
  }

  // ── Birthday & Tab Navigation ──────────────────────────────────────────────

  void setBirthday(bool value) {
    if (_isBirthday != value) {
      _isBirthday = value;
      notifyListeners();
    }
  }

  void setTabIndex(int index) {
    if (_currentTabIndex != index) {
      _currentTabIndex = index;
      notifyListeners();
    }
  }

  void setContactsSubIndex(int index) {
    if (_contactsSubIndex != index) {
      _contactsSubIndex = index;
      notifyListeners();
    }
  }

  // ── Wizz ───────────────────────────────────────────────────────────────────

  DateTime? lastWizzFor(String contactId) {
    final s = _wizzHistory[contactId];
    return s != null ? DateTime.tryParse(s) : null;
  }

  bool canWizz(String contactId) {
    return true;
  }

  void setWizzEffectMode(WizzEffectMode mode) {
    if (_wizzEffectMode != mode) {
      _wizzEffectMode = mode;
      notifyListeners();
      _saveData();
    }
  }

  void sendWizz(String contactId) {
    _wizzHistory[contactId] = DateTime.now().toIso8601String();
    notifyListeners();
    _saveData();
    final contact = _contacts.where((c) => c.id == contactId).firstOrNull;
    if (contact != null) {
      Future.microtask(() => _sendNotificationToContact(
            contactId,
            'wizz',
            '${_profile.name} t\'a envoyé un Wizz ⚡',
          ));
      logActivity('Wizz envoyé à ${contact.name}', '⚡', contactId: contactId);
    }
  }

  // ── Busy Month Insight ─────────────────────────────────────────────────────

  Future<void> evaluateBusyMonth() async {
    if (_mascotPrivacyMode || _mascotSilent) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final String key = 'busy_month_${now.year}_${now.month + 1}';
    if (prefs.getBool(key) == true) return;
    if (_busyMonthInsightShown) return;

    final nextMonthDate = DateTime(now.year, now.month + 1, 1);
    final eventsNextMonth = _events.where((e) {
      final occ = e.getOccurrenceForYear(nextMonthDate.year);
      return occ.month == nextMonthDate.month && e.contactId != null;
    }).toList();

    if (eventsNextMonth.length >= 3) {
      int wishesForEvents = 0;
      List<String> busyNames = [];
      for (var e in eventsNextMonth) {
        final c = _contacts.where((c) => c.id == e.contactId).firstOrNull;
        if (c != null) {
          if (!busyNames.contains(c.name)) busyNames.add(c.name);
          wishesForEvents += _wishes.where((w) => w.contactId == e.contactId).length;
        }
      }
      if (wishesForEvents < eventsNextMonth.length && busyNames.isNotEmpty) {
        _busyMonthInsightShown = true;
        await prefs.setBool(key, true);
        setMascotMoment(MascotMoment.busyMonth);
      }
    }
  }

  // ── Circle Suggestions ─────────────────────────────────────────────────────

  List<CircleGroup> get mascotCircleSuggestions {
    final suggestions = <CircleGroup>[];

    final colleagues = _contacts
        .where((c) =>
            c.role.toLowerCase().contains('collègue') ||
            c.role.toLowerCase().contains('colleague'))
        .toList();
    if (colleagues.length >= 2 &&
        !_groups.any((g) =>
            g.name.toLowerCase() == 'collègues' ||
            g.name.toLowerCase() == 'colleagues')) {
      suggestions.add(CircleGroup(
        id: 'suggest_colleagues',
        name: 'Collègues',
        emoji: '💼',
        contactIds: colleagues.map((c) => c.id).toList(),
      ));
    }

    final friends = _contacts.where((c) => c.trustLevel == TrustLevel.friend).toList();
    if (friends.length >= 3 &&
        !_groups.any((g) => g.name.toLowerCase().contains('amis'))) {
      suggestions.add(CircleGroup(
        id: 'suggest_friends',
        name: 'Amis proches',
        emoji: '🎉',
        contactIds: friends.map((c) => c.id).toList(),
      ));
    }

    final athletes = _contacts
        .where((c) =>
            c.role.toLowerCase().contains('sport') ||
            c.role.toLowerCase().contains('gym') ||
            c.role.toLowerCase().contains('tennis'))
        .toList();
    if (athletes.length >= 2 &&
        !_groups.any((g) => g.name.toLowerCase().contains('sport'))) {
      suggestions.add(CircleGroup(
        id: 'suggest_sport',
        name: 'Sport',
        emoji: '⚽',
        contactIds: athletes.map((c) => c.id).toList(),
      ));
    }

    return suggestions;
  }
}
