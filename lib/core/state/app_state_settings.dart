part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Settings, Mascot, UI State, Onboarding, Wizz, Outfit ───────────────────

extension SettingsExtension on PigioAppState {
  // ── Locale & Theme ─────────────────────────────────────────────────────────

  void _trimMascotMemories() {
    if (_mascotMemories.length > 50) {
      _mascotMemories = _mascotMemories.sublist(0, 50);
    }
  }

  void awardMascotProgress(
    int xp, {
    String? emoji,
    String? titleFr,
    String? titleEn,
  }) {
    if (xp <= 0 && emoji == null) return;
    final previousLevel = mascotBondLevel;
    _mascotBondXp += xp;

    if (emoji != null && titleFr != null && titleEn != null) {
      _mascotMemories.insert(
        0,
        MascotMemory(
          id: _newId(),
          emoji: emoji,
          titleFr: titleFr,
          titleEn: titleEn,
          timestamp: DateTime.now(),
        ),
      );
    }

    if (mascotBondLevel > previousLevel) {
      final titlesFr = ['Nouvelle rencontre', 'On se connait mieux', 'On devient amis', 'Lien tres fort'];
      final titlesEn = ['New connection', 'Getting closer', 'We are becoming friends', 'Strong bond unlocked'];
      final levelIndex = (mascotBondLevel - 1).clamp(0, titlesFr.length - 1);
      _mascotMemories.insert(
        0,
        MascotMemory(
          id: _newId(),
          emoji: mascotBondEmoji,
          titleFr: titlesFr[levelIndex],
          titleEn: titlesEn[levelIndex],
          timestamp: DateTime.now(),
        ),
      );
      _mascotMoment = MascotMoment.bondLevelUp;
      ReviewService.tryPrompt(); // High-value moment: bond grew stronger
    }

    _trimMascotMemories();
    notifyListeners();
    _saveData();
  }

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

  void setMascotVisible(bool val) {
    _mascotVisible = val;
    notifyListeners();
    _saveData();
  }

  void setMascotSilent(bool val) {
    _mascotSilent = val;
    notifyListeners();
    _saveData();
  }

  void setMascotSoundEnabled(bool val) {
    _mascotSoundEnabled = val;
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
    // Also mirror into outfitColors so scarf uses the universal system
    _outfitColors['scarf'] = val.toARGB32();
    notifyListeners();
    _saveData();
  }

  void setOutfitItemColor(String itemId, Color color) {
    _outfitColors[itemId] = color.toARGB32();
    // Keep legacy scarf color in sync
    if (itemId == 'scarf') _mascotScarfColor = color;
    notifyListeners();
    _saveData();
  }

  Color? getOutfitItemColor(String itemId) {
    final argb = _outfitColors[itemId];
    return argb != null ? Color(argb) : null;
  }

  void setMascotDefaultCorner(String val) {
    _mascotDefaultCorner = val;
    notifyListeners();
    _saveData();
  }

  void setMascotReducedMotion(bool val) {
    _mascotReducedMotion = val;
    notifyListeners();
    _saveData();
  }

  void setMascotPrivacyMode(bool val) {
    _mascotPrivacyMode = val;
    notifyListeners();
    _saveData();
  }

  void setWeatherEffectsEnabled(bool val) {
    _weatherEffectsEnabled = val;
    notifyListeners();
    _saveData();
  }

  void setAutoTheme(bool val) {
    _autoTheme = val;
    notifyListeners();
    _saveData();
    if (val) _checkDaypartAutoTheme();
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

  // ── Daily Bond XP Bonus ────────────────────────────────────────────────────

  /// Returns true + grants 10 XP if this is the first interaction today.
  bool claimDailyBondBonus() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_mascotLastDailyBonus != null) {
      final lastDate = DateTime(_mascotLastDailyBonus!.year, _mascotLastDailyBonus!.month, _mascotLastDailyBonus!.day);
      if (!lastDate.isBefore(today)) return false; // already claimed today
      // Track consecutive days: if yesterday, increment; otherwise reset.
      final yesterday = today.subtract(const Duration(days: 1));
      if (lastDate == yesterday) {
        _loginStreak++;
      } else {
        _loginStreak = 1;
      }
    } else {
      _loginStreak = 1;
    }
    _mascotLastDailyBonus = now;
    awardMascotProgress(
      10,
      emoji: '🌟',
      titleFr: 'Bonus quotidien réclamé ! +10 XP',
      titleEn: 'Daily bonus claimed! +10 XP',
    );
    if (_loginStreak == 7) ReviewService.tryPrompt(); // 7-day streak = engaged user
    return true;
  }

  // ── Mascot Memories ────────────────────────────────────────────────────────

  void addMemory({required String emoji, required String titleFr, required String titleEn}) {
    _mascotMemories.insert(0, MascotMemory(
      id: _newId(),
      emoji: emoji,
      titleFr: titleFr,
      titleEn: titleEn,
      timestamp: DateTime.now(),
    ));
    _trimMascotMemories();
    notifyListeners();
    _saveData();
  }

  // ── Outfit Dismiss Rate Limiting ───────────────────────────────────────────

  void dismissOutfitRequest() {
    _currentClothingRequest = null;
    _lastOutfitDismiss = DateTime.now();
    notifyListeners();
    _saveData();
  }

  /// True if an outfit request was dismissed less than 30 minutes ago.
  bool get isOutfitRequestCoolingDown {
    if (_lastOutfitDismiss == null) return false;
    return DateTime.now().difference(_lastOutfitDismiss!).inMinutes < 30;
  }

  // ── Re-engagement Push Tracking ────────────────────────────────────────────

  void markReengagePushSent() {
    _lastReengagePush = DateTime.now();
    _saveData();
  }

  /// E7: Schedule a self-push re-engagement notification if user has been away 2+ days.
  /// Only fires once per 48h. Uses the user's own FCM token.
  /// Enhanced with churn scoring: at-risk users get high-value contextual pushes
  /// (upcoming birthday, gift ideas) instead of generic re-engagement.
  Future<void> checkReengagementPush() async {
    if (_mascotAbsenceDays < 2) return;
    if (_lastReengagePush != null && DateTime.now().difference(_lastReengagePush!).inHours < 48) return;
    final token = _profile.fcmToken;
    if (token == null || token.isEmpty) return;

    // Try churn-aware preemptive push first (high-value, contextual)
    final churnPush = ChurnScoreService.getPreemptivePush(this);
    final String title;
    final String body;
    final String type;

    if (churnPush != null) {
      title = churnPush.title;
      body = churnPush.body;
      type = churnPush.type;
    } else {
      // Fallback to warm generic message
      final lang = _locale.languageCode;
      title = PigioVoice.bondGreeting(mascotBondLevel, lang: lang);
      body = lang == 'fr'
          ? 'Pigio est là quand tu veux ! 🐧💛'
          : 'Pigio is here whenever you want! 🐧💛';
      type = 'mascot_reengage';
    }

    try {
      await FcmService.sendPush(
        baseUrl: _apiBaseUrl,
        fcmToken: token,
        title: title,
        body: body,
        type: type,
        userJwt: Supabase.instance.client.auth.currentSession?.accessToken,
      );
      markReengagePushSent();
    } catch (e) {
      log.warn('Settings', 'Re-engagement push failed', e);
    }
  }

  // ── Birthday-Proximity Smart Push ──────────────────────────────────────────

  /// Check for upcoming birthdays (3 days out) and send a contextual push
  /// to the user. Only sends one push per birthday per year.
  Future<void> checkBirthdayProximityPush() async {
    final token = _profile.fcmToken;
    if (token == null || token.isEmpty) return;

    final now = DateTime.now();
    final lang = _locale.languageCode;

    for (final contact in _contacts) {
      if (contact.birthdate == null || contact.birthdate!.isEmpty) continue;

      final birthday = _parseNextBirthday(contact.birthdate!, now);
      if (birthday == null) continue;

      final daysUntil = birthday.difference(now).inDays;
      if (daysUntil < 0 || daysUntil > 3) continue;

      // Deduplicate: one push per contact per year
      final dedupeKey = 'pigio_bday_push_${contact.id}_${now.year}';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(dedupeKey) == true) continue;
      await prefs.setBool(dedupeKey, true);

      final title = lang == 'fr'
          ? '🎂 Anniversaire à venir'
          : '🎂 Upcoming birthday';
      final body = daysUntil == 0
          ? (lang == 'fr'
              ? "C'est l'anniversaire de ${contact.name} aujourd'hui !"
              : "It's ${contact.name}'s birthday today!")
          : (lang == 'fr'
              ? "L'anniversaire de ${contact.name} est dans $daysUntil jour${daysUntil > 1 ? 's' : ''}"
              : "${contact.name}'s birthday is in $daysUntil day${daysUntil > 1 ? 's' : ''}");

      try {
        await FcmService.sendPush(
          baseUrl: _apiBaseUrl,
          fcmToken: token,
          title: title,
          body: body,
          type: 'birthday_reminder',
          userJwt: Supabase.instance.client.auth.currentSession?.accessToken,
        );
      } catch (e) {
        log.warn('Settings', 'Birthday push failed for ${contact.name}', e);
      }
    }
  }

  /// Parse a DD/MM/YYYY or DD/MM birthdate and return the next occurrence.
  DateTime? _parseNextBirthday(String birthdate, DateTime now) {
    try {
      final parts = birthdate.split('/');
      if (parts.length < 2) return null;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      var next = DateTime(now.year, month, day);
      if (next.isBefore(now.subtract(const Duration(days: 1)))) {
        next = DateTime(now.year + 1, month, day);
      }
      return next;
    } catch (_) {
      return null;
    }
  }

  void _pushOutfitHistory() {
    _outfitHistory.add(Map<ClothingSlot, String?>.from(_activeOutfit));
    if (_outfitHistory.length > 3) _outfitHistory.removeAt(0);
  }

  void equipClothing(ClothingSlot slot, String? itemId) {
    _pushOutfitHistory();
    _activeOutfit[slot] = itemId;
    notifyListeners();
    _saveData();
  }

  void unequipClothing(ClothingSlot slot) {
    _pushOutfitHistory();
    _activeOutfit.remove(slot);
    notifyListeners();
    _saveData();
  }

  void undoOutfit() {
    if (_outfitHistory.isEmpty) return;
    _activeOutfit = Map<ClothingSlot, String?>.from(_outfitHistory.removeLast());
    notifyListeners();
    _saveData();
  }

  void unlockClothing(String itemId) {
    if (!_unlockedClothing.contains(itemId)) {
      _unlockedClothing.add(itemId);
      AnalyticsService.wardrobeUnlock(itemId);
      notifyListeners();
      _saveData();
    }
  }

  void setClothingRequest(ClothingRequest? req) {
    _currentClothingRequest = req;
    notifyListeners();
  }

  void clearOutfit() {
    _pushOutfitHistory();
    _activeOutfit.clear();
    notifyListeners();
    _saveData();
  }

  // ── Favorites ────────────────────────────────────────────────────────────

  void toggleFavoriteClothing(String itemId) {
    if (_favoriteClothing.contains(itemId)) {
      _favoriteClothing.remove(itemId);
    } else {
      _favoriteClothing.add(itemId);
    }
    notifyListeners();
    _saveData();
  }

  bool isClothingFavorite(String itemId) => _favoriteClothing.contains(itemId);

  // ── Outfit Presets ───────────────────────────────────────────────────────

  void saveOutfitPreset(String name, String emoji) {
    if (_outfitPresets.length >= 5) _outfitPresets.removeAt(0);
    _outfitPresets.add(OutfitPreset(
      id: _newId(),
      name: name,
      emoji: emoji,
      outfit: Map<ClothingSlot, String?>.from(_activeOutfit),
    ));
    notifyListeners();
    _saveData();
  }

  void loadOutfitPreset(OutfitPreset preset) {
    _pushOutfitHistory();
    _activeOutfit = Map<ClothingSlot, String?>.from(preset.outfit);
    notifyListeners();
    _saveData();
  }

  void deleteOutfitPreset(String id) {
    _outfitPresets.removeWhere((p) => p.id == id);
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
    // Trigger Pigio's first-open introduction if the quiz hasn't been completed yet
    if (_personalityProfile.isEmpty) {
      _mascotMoment = MascotMoment.firstOpen;
    }
    notifyListeners();
    _saveData();
    // Also persist per-user so returning users skip onboarding after sign-out.
    _savePerUserState();
  }

  /// Persist onboarding flag + profile data keyed by user ID so they survive sign-out.
  Future<void> _savePerUserState() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${PigioAppState._onboardingCompletedKey}_$userId', true);
    await prefs.setString(
      '${PigioAppState._profileKey}_$userId',
      jsonEncode(_profile.toMap()),
    );
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

  /// Short cooldown per contact — MSN-style: fast enough to feel fun,
  /// long enough not to firehose push notifications.
  static const _wizzCooldown = Duration(minutes: 2);

  bool canWizz(String contactId) {
    final last = lastWizzFor(contactId);
    if (last == null) return true;
    return DateTime.now().difference(last) >= _wizzCooldown;
  }

  /// Returns the remaining cooldown duration, or [Duration.zero] if ready.
  Duration wizzCooldownRemaining(String contactId) {
    final last = lastWizzFor(contactId);
    if (last == null) return Duration.zero;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= _wizzCooldown) return Duration.zero;
    return _wizzCooldown - elapsed;
  }

  void setWizzEffectMode(WizzEffectMode mode) {
    if (_wizzEffectMode != mode) {
      _wizzEffectMode = mode;
      notifyListeners();
      _saveData();
    }
  }

  void sendWizz(String contactId, {String? reasonLabel, String? reasonSubtitle}) {
    _wizzHistory[contactId] = DateTime.now().toIso8601String();
    notifyListeners();
    _saveData();
    final contact = _contacts.where((c) => c.id == contactId).firstOrNull;
    if (contact != null) {
      final wizzObject = (reasonLabel != null && reasonLabel.trim().isNotEmpty)
          ? reasonLabel.trim()
          : 'Mise à jour de profil';
      final detail = (reasonSubtitle != null && reasonSubtitle.trim().isNotEmpty)
          ? ' — ${reasonSubtitle.trim()}'
          : '';
      final message = '${_profile.name} t\'a envoyé un Wizz ⚡ · Objet: $wizzObject$detail';
      Future.microtask(() => _sendNotificationToContact(
            contactId,
            'wizz',
            message,
          ));
      logActivity('Wizz envoyé à ${contact.name} ($wizzObject)', '⚡', contactId: contactId);
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
