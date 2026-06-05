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
      final stageEmoji = mascotStageEmoji;
      final stageFr = mascotStageName;
      final stageEn = mascotStageNameEn;
      final titlesFr = [
        'Kindy a éclos ! $stageEmoji → $stageFr',
        'Kindy grandit ! $stageEmoji Stade $stageFr',
        'Kindy mûrit ! $stageEmoji Stade $stageFr',
        'Kindy rayonne ! $stageEmoji Stade $stageFr',
      ];
      final titlesEn = [
        'Kindy hatched! $stageEmoji → $stageEn',
        'Kindy is growing! $stageEmoji Stage: $stageEn',
        'Kindy matured! $stageEmoji Stage: $stageEn',
        'Kindy is radiant! $stageEmoji Stage: $stageEn',
      ];
      final levelIndex = (mascotBondLevel - 1).clamp(0, titlesFr.length - 1);
      _mascotMemories.insert(
        0,
        MascotMemory(
          id: _newId(),
          emoji: stageEmoji,
          titleFr: titlesFr[levelIndex],
          titleEn: titlesEn[levelIndex],
          timestamp: DateTime.now(),
        ),
      );
      _mascotMoment = MascotMoment.bondLevelUp;
      HapticFeedback.heavyImpact();
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
    // Advance Occasion Pass on daily login
    advanceOccasionPass();
    // Trigger mood check-in if not yet done today
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (_userMoodDate != todayStr) {
      _moodCheckInPending = true;
    }
    return true;
  }

  void submitMoodCheckIn(String mood) {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _userMood = mood;
    _userMoodDate = todayStr;
    _moodCheckInPending = false;
    // Negative moods get a comfort bonus
    final isNegative = mood == 'sad' || mood == 'tired';
    if (isNegative) {
      awardMascotProgress(5, emoji: '💛', titleFr: 'Kindy est là pour toi. +5 XP', titleEn: 'Kindy is here for you. +5 XP');
    }
    AnalyticsService.log('mood_check_in', {'mood': mood});
    notifyListeners();
    _saveData();
  }

  void dismissMoodCheckIn() {
    _moodCheckInPending = false;
    notifyListeners();
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
          ? 'Kindy est là quand tu veux ! 🐧💛'
          : 'Kindy is here whenever you want! 🐧💛';
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

  void markComboCompleted(String comboNameFr) {
    if (_completedCombos.contains(comboNameFr)) return;
    _completedCombos.add(comboNameFr);
    awardMascotProgress(25, emoji: '🎨', titleFr: 'Combo "$comboNameFr" complété !', titleEn: 'Combo "$comboNameFr" completed!');
    _mascotMoment = MascotMoment.comboCompleted;
    AnalyticsService.log('combo_completed', {'combo': comboNameFr});
    notifyListeners();
    _saveData();
  }

  void claimCollectionMilestone(String milestoneKey, {required int percent}) {
    if (_collectionMilestones.contains(milestoneKey)) return;
    _collectionMilestones.add(milestoneKey);
    awardMascotProgress(15, emoji: '📊', titleFr: 'Collection $percent% complétée !', titleEn: 'Collection $percent% complete!');
    AnalyticsService.log('collection_milestone', {'percent': percent});
    notifyListeners();
    _saveData();
  }

  void completeDailyChallenge() {
    final today = DateTime.now();
    final key = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (_dailyChallengeCompleted == key) return;
    _dailyChallengeCompleted = key;
    awardMascotProgress(15, emoji: '🎯', titleFr: 'Défi du jour relevé !', titleEn: 'Daily challenge completed!');
    _mascotMoment = MascotMoment.challengeCompleted;
    AnalyticsService.log('daily_challenge_completed', {'date': key});
    notifyListeners();
    _saveData();
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
    
    // Sync onboarding state to cloud
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'onboarding_completed': true}),
      );
    }
  }

  /// Persist onboarding flag + profile data keyed by user ID so they survive sign-out.
  Future<void> _savePerUserState() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${PigioAppState._onboardingCompletedKey}_${user.id}', true);
    final profileMap = _profile.toMap();
    await prefs.setString(
      '${PigioAppState._profileKey}_${user.id}',
      jsonEncode(profileMap),
    );
    
    // Also sync the core properties to Supabase auth metadata to survive uninstalls
    Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {
        'onboarding_completed': true,
        'profile': profileMap,
      }),
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

  // ── Wardrobe Push Notifications ───────────────────────────────────────────

  /// Send push for limited-time seasonal drops, streak-at-risk, or daily challenge.
  /// Deduplicates per type per day.
  Future<void> checkWardrobePushes() async {
    final token = _profile.fcmToken;
    if (token == null || token.isEmpty) return;
    if (_mascotPrivacyMode || _mascotSilent) return;

    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final lang = _locale.languageCode;
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Limited-time drop alert (once per season start)
    final seasonal = MascotOutfitEngine.seasonalDrops(now);
    if (seasonal.isNotEmpty) {
      final seasonKey = 'pigio_season_push_${seasonal.first.id}_${now.year}';
      if (prefs.getBool(seasonKey) != true) {
        await prefs.setBool(seasonKey, true);
        try {
          await FcmService.sendPush(
            baseUrl: _apiBaseUrl,
            fcmToken: token,
            title: lang == 'fr' ? '🌟 Nouvel objet saisonnier !' : '🌟 New seasonal item!',
            body: lang == 'fr'
                ? '${seasonal.first.emoji} ${seasonal.first.name} est disponible en édition limitée !'
                : '${seasonal.first.emoji} ${seasonal.first.name} is available as a limited drop!',
            type: 'seasonal_drop',
            userJwt: Supabase.instance.client.auth.currentSession?.accessToken,
          );
        } catch (_) {}
      }
    }

    // 2. Streak-at-risk reminder (if streak >= 3 and last bonus was yesterday)
    if (_loginStreak >= 3 && _mascotLastDailyBonus != null) {
      final lastDay = DateTime(_mascotLastDailyBonus!.year, _mascotLastDailyBonus!.month, _mascotLastDailyBonus!.day);
      final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      if (lastDay == yesterday) {
        final streakKey = 'pigio_streak_push_$todayKey';
        if (prefs.getBool(streakKey) != true) {
          await prefs.setBool(streakKey, true);
          try {
            await FcmService.sendPush(
              baseUrl: _apiBaseUrl,
              fcmToken: token,
              title: lang == 'fr' ? '🔥 Série en danger !' : '🔥 Streak at risk!',
              body: lang == 'fr'
                  ? 'Tu as $_loginStreak jours de suite ! Ouvre Pigio pour continuer.'
                  : 'You\'re on a $_loginStreak-day streak! Open Pigio to keep it going.',
              type: 'streak_risk',
              userJwt: Supabase.instance.client.auth.currentSession?.accessToken,
            );
          } catch (_) {}
        }
      }
    }

    // 3. Daily challenge reminder (late afternoon if not completed)
    if (now.hour >= 16 && _dailyChallengeCompleted != todayKey) {
      final challengeKey = 'pigio_challenge_push_$todayKey';
      if (prefs.getBool(challengeKey) != true) {
        await prefs.setBool(challengeKey, true);
        final challenge = MascotOutfitEngine.todaysChallenge(now);
        try {
          await FcmService.sendPush(
            baseUrl: _apiBaseUrl,
            fcmToken: token,
            title: lang == 'fr' ? '🎯 Défi du jour' : '🎯 Daily Challenge',
            body: lang == 'fr'
                ? '${challenge.titleFr} — 15 XP t\'attendent !'
                : '${challenge.titleEn} — 15 XP awaits!',
            type: 'daily_challenge',
            userJwt: Supabase.instance.client.auth.currentSession?.accessToken,
          );
        } catch (_) {}
      }
    }
  }

  // ── Monetization ─────────────────────────────────────────────────────────

  /// Add Plumes (premium currency). Used for purchases, stipends, bonuses.
  void addPlumes(int amount, {String? reason}) {
    if (amount <= 0) return;
    _plumes += amount;
    if (reason != null) {
      AnalyticsService.log('plumes_earned', {'amount': amount, 'reason': reason});
    }
    notifyListeners();
    _saveData();
  }

  /// Spend Plumes. Returns true if the user had enough, false otherwise.
  bool spendPlumes(int amount) {
    if (amount <= 0 || _plumes < amount) return false;
    _plumes -= amount;
    AnalyticsService.log('plumes_spent', {'amount': amount, 'balance': _plumes});
    notifyListeners();
    _saveData();
    return true;
  }

  /// Called after auth to identify the user with RevenueCat.
  Future<void> identifySubscription(String userId) async {
    await SubscriptionService.identify(userId);
    notifyListeners();
  }

  /// Called on sign-out to reset RevenueCat to anonymous.
  Future<void> logoutSubscription() async {
    await SubscriptionService.logout();
    notifyListeners();
  }

  /// Restore purchases (e.g. after reinstall). Call from settings screen.
  Future<void> restorePurchases() async {
    await SubscriptionService.restorePurchases();
    notifyListeners();
  }

  /// Claim the monthly Plumes stipend for Pigio+ subscribers.
  /// Awards 50 Plumes once per calendar month. Deduplicated via SharedPreferences.
  Future<void> claimMonthlyPlumeStipend() async {
    if (!SubscriptionService.isPremium) return;
    final now = DateTime.now();
    final key = 'pigio_plume_stipend_${now.year}_${now.month}';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);
    addPlumes(50, reason: 'monthly_stipend');
    addMemory(
      emoji: '💎',
      titleFr: 'Allocation mensuelle : +50 Plumes !',
      titleEn: 'Monthly stipend: +50 Plumes!',
    );
  }

  /// Purchase a wardrobe item with Plumes. Returns true if successful.
  bool purchaseWithPlumes(String itemId) {
    final item = MascotOutfitEngine.catalog.where((i) => i.id == itemId).firstOrNull;
    if (item == null || !item.isPlumeItem) return false;
    if (_unlockedClothing.contains(itemId)) return false; // already owned
    if (item.premiumOnly && !SubscriptionService.isPremium) return false;
    if (!spendPlumes(item.plumeCost!)) return false;
    unlockClothing(itemId);
    addMemory(
      emoji: item.emoji,
      titleFr: '${item.name} acheté avec des Plumes !',
      titleEn: '${item.name} purchased with Plumes!',
    );
    return true;
  }

  /// Purchase a Plumes IAP pack via RevenueCat.
  Future<bool> purchasePlumePack(String productId) async {
    final ok = await SubscriptionService.purchasePlumes(productId);
    if (!ok) return false;
    // Map product IDs to Plumes amounts
    int amount;
    switch (productId) {
      case SubscriptionService.kPlumes100:
        amount = 100;
      case SubscriptionService.kPlumes500:
        amount = 500;
      case SubscriptionService.kPlumes1200:
        amount = 1200;
      default:
        amount = 100;
    }
    addPlumes(amount, reason: 'iap_$productId');
    addMemory(
      emoji: '💎',
      titleFr: '+$amount Plumes achetées !',
      titleEn: '+$amount Plumes purchased!',
    );
    return true;
  }

  // ── Occasion Pass (Battle Pass) ──────────────────────────────────────────

  /// Advance the Occasion Pass by 1 level. Awards the tier reward automatically.
  /// Called when the user completes a qualifying action (daily login, wish added, etc.).
  void advanceOccasionPass() {
    final season = MascotOutfitEngine.currentSeason();
    // Reset progress if season changed
    if (_occasionPassSeason != season) {
      _occasionPassSeason = season;
      _occasionPassLevel = 0;
    }
    final maxLevel = MascotOutfitEngine.occasionPassTiers.length;
    if (_occasionPassLevel >= maxLevel) return; // already maxed

    _occasionPassLevel++;
    final tier = MascotOutfitEngine.occasionPassTiers[_occasionPassLevel - 1];

    // Award free-track rewards (Plumes) to everyone
    if (tier.plumes > 0) {
      addPlumes(tier.plumes, reason: 'occasion_pass_lv${tier.level}');
    }

    // Award premium-track rewards only to Pigio+ / Occasion Pass holders
    if (tier.premiumTrack && tier.unlockItemId != null) {
      if (SubscriptionService.isPremium || SubscriptionService.hasOccasionPass) {
        unlockClothing(tier.unlockItemId!);
      }
    }

    addMemory(
      emoji: tier.emoji,
      titleFr: 'Occasion Pass niv. ${tier.level} : ${tier.nameFr}',
      titleEn: 'Occasion Pass lv. ${tier.level}: ${tier.nameEn}',
    );
    AnalyticsService.log('occasion_pass_advance', {'level': _occasionPassLevel, 'season': season});
    notifyListeners();
    _saveData();
  }

  /// Purchase the Occasion Pass (standalone, without full Pigio+).
  Future<bool> purchaseOccasionPass() async {
    final ok = await SubscriptionService.purchaseOccasionPass();
    if (!ok) return false;
    // Retroactively unlock any premium tiers already reached
    for (int i = 0; i < _occasionPassLevel; i++) {
      final tier = MascotOutfitEngine.occasionPassTiers[i];
      if (tier.premiumTrack && tier.unlockItemId != null) {
        unlockClothing(tier.unlockItemId!);
      }
    }
    notifyListeners();
    return true;
  }

  // ── Altruistic Gifting & Guardian System ──────────────────────────────────

  /// Gift a 1-month Pigio+ subscription to another user via RevenueCat IAP.
  /// Returns true if the purchase succeeded.
  Future<bool> giftPigioPlus() async {
    final ok = await SubscriptionService.purchaseGiftSubscription();
    if (!ok) return false;
    _updateGuardianTier();
    addMemory(
      emoji: '🎁',
      titleFr: 'Pigio+ offert à un proche !',
      titleEn: 'Pigio+ gifted to a loved one!',
    );
    awardMascotProgress(20, emoji: '💛', titleFr: 'Cadeau généreux ! +20 XP', titleEn: 'Generous gift! +20 XP');
    AnalyticsService.log('gift_pigio_plus', {});
    return true;
  }

  /// Guardian tiers based on number of gifts given.
  /// '', 'ally' (1+ gifts), 'protector' (3+ gifts), 'superhero' (10+ gifts)
  void _updateGuardianTier() async {
    final prefs = await SharedPreferences.getInstance();
    final giftsKey = 'pigio_gifts_given_count';
    final count = (prefs.getInt(giftsKey) ?? 0) + 1;
    await prefs.setInt(giftsKey, count);

    String newTier;
    if (count >= 10) {
      newTier = 'superhero';
    } else if (count >= 3) {
      newTier = 'protector';
    } else if (count >= 1) {
      newTier = 'ally';
    } else {
      newTier = '';
    }

    if (_guardianTier != newTier) {
      _guardianTier = newTier;
      if (newTier.isNotEmpty) {
        final tierEmojis = {'ally': '🛡️', 'protector': '⚔️', 'superhero': '🦸'};
        final tierNamesFr = {'ally': 'Allié', 'protector': 'Protecteur', 'superhero': 'Super-héros'};
        final tierNamesEn = {'ally': 'Ally', 'protector': 'Protector', 'superhero': 'Superhero'};
        addMemory(
          emoji: tierEmojis[newTier] ?? '🛡️',
          titleFr: 'Nouveau rang Guardian : ${tierNamesFr[newTier]} !',
          titleEn: 'New Guardian rank: ${tierNamesEn[newTier]}!',
        );
      }
      AnalyticsService.log('guardian_tier_changed', {'tier': newTier, 'gifts': count});
      notifyListeners();
      _saveData();
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
