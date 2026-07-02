import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async' as async_lib show Timer;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import '../config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import '../models/app_models.dart';
import '../models/user_badge.dart';
import '../../features/invites/state/invite_commands.dart';
import '../../features/invites/state/invite_mappers.dart';
import '../../features/invites/state/invite_resolution.dart';
import '../../features/invites/state/invite_sync.dart';
import '../../features/notifications/state/notifications_coordinator.dart';
import '../../services/invitation_service.dart';
import '../../services/notification_service.dart';
import '../../services/fcm_service.dart';
import '../../services/pigio_voice.dart';
import '../../services/soft_reminder_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/pigio_logger.dart';
import '../../services/analytics_service.dart';
import '../../services/backup_service.dart';
import '../../services/churn_score_service.dart';
import '../../services/review_service.dart';
import '../../services/weather_service.dart';
import '../../services/mascot_outfit_engine.dart';
import '../../services/subscription_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export '../models/app_models.dart'; // re-export so existing imports of app_state.dart still get models

part 'app_state_settings.dart';
part 'app_state_cloud_sync.dart';
part 'app_state_contacts.dart';
part 'app_state_invites.dart';
part 'app_state_profile.dart';
part 'app_state_profile_sync.dart';
part 'app_state_wishes.dart';
part 'app_state_events.dart';
part 'app_state_sizes.dart';
part 'app_state_notifications.dart';
part 'app_state_account.dart';
part 'app_state_gift_pots.dart';
part 'app_state_polls.dart';

// Sentinel used by updateWish to distinguish "clear field" from "leave unchanged".
const String clearUrlSentinel = '__CLEAR__';

/// Part of the day — drives auto-theme, mascot behavior, and greetings.
enum Daypart { night, earlyMorning, morning, midday, afternoon, evening }

// ─────────────────────────────────────────────────────────────────────────────
// Core State Host
// ─────────────────────────────────────────────────────────────────────────────

class PigioAppState extends ChangeNotifier {
  // ── API / Storage Keys ────────────────────────────────────────────────────
  static const String _inviteApiBaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String _localeKey               = 'pigio_locale';
  static const String _themeKey                = 'pigio_theme';
  static const String _wishesKey               = 'pigio_wishes';
  static const String _contactsKey             = 'pigio_contacts';
  static const String _groupsKey               = 'pigio_groups';
  static const String _eventsKey               = 'pigio_events';
  static const String _sizesKey                = 'pigio_sizes';
  static const String _profileKey              = 'pigio_profile';
  static const String _unseenLogsKey           = 'pigio_unseen_logs';
  static const String _activityLogsKey         = 'pigio_activity_logs';
  static const String _recentProfilesKey       = 'pigio_recent_profiles';
  static const String _pendingInvitesKey       = 'pigio_invites';
  static const String _legacyPendingInvitesKey = 'pigio_pending_invites';
  static const String _mascotSilentKey         = 'pigio_mascot_silent';
  static const String _mascotVisibleKey        = 'pigio_mascot_visible';
  static const String _mascotSoundEnabledKey   = 'pigio_mascot_sound_enabled';
  static const String _mascotReducedMotionKey  = 'pigio_mascot_reduced_motion';
  static const String _mascotChattinessKey     = 'pigio_mascot_chattiness';
  static const String _mascotScarfColorKey     = 'pigio_mascot_scarf_color';
  static const String _mascotCornerKey         = 'pigio_mascot_corner';
  static const String _mascotPrivacyKey        = 'pigio_mascot_privacy';
  static const String _mascotBondXpKey         = 'pigio_mascot_bond_xp';
  static const String _mascotLastOpenKey        = 'pigio_mascot_last_open';
  static const String _surpriseModeKey         = 'pigio_surprise_mode';
  static const String _contactsConsentGivenKey = 'pigio_contacts_consent_given';
  static const String _activeOutfitKey         = 'pigio_active_outfit';
  static const String _unlockedClothingKey     = 'pigio_unlocked_clothing';
  static const String _favoriteClothingKey    = 'pigio_favorite_clothing';
  static const String _outfitPresetsKey       = 'pigio_outfit_presets';
  static const String _syncKeyKey              = 'pigio_sync_key';
  static const String _onboardingCompletedKey  = 'pigio_onboarding_completed';
  static const String _personalityProfileKey   = 'pigio_personality_profile';
  static const String _wizzKey                 = 'pigio_wizz_history';
  static const String _wizzEffectModeKey       = 'pigio_wizz_effect_mode';
  static const String _notificationsKey        = 'pigio_notifications';
  static const String _giftPotsKey             = 'pigio_gift_pots';
  static const String _pollsKey               = 'pigio_polls';
  static const String _lastAuthUserIdKey       = 'pigio_last_auth_user_id';
  static const String _mascotMemoriesKey        = 'pigio_mascot_memories';
  static const String _mascotLastDailyBonusKey  = 'pigio_mascot_last_daily_bonus';
  static const String _loginStreakKey            = 'pigio_login_streak';
  static const String _lastOutfitDismissKey     = 'pigio_last_outfit_dismiss';
  static const String _lastReengagePushKey      = 'pigio_last_reengage_push';
  static const String _lastStaleCircleNudgeKey  = 'pigio_last_stale_circle_nudge';
  static const String _outfitColorsKey          = 'pigio_outfit_colors';
  static const String _completedCombosKey       = 'pigio_completed_combos';
  static const String _collectionMilestonesKey  = 'pigio_collection_milestones';
  static const String _dailyChallengeKey        = 'pigio_daily_challenge_completed';
  static const String _unlockedBadgesKey        = 'pigio_unlocked_badges';
  static const String _userMoodKey              = 'pigio_user_mood';
  static const String _userMoodDateKey          = 'pigio_user_mood_date';
  static const String _weatherEffectsKey         = 'pigio_weather_effects';
  static const String _autoThemeKey              = 'pigio_auto_theme';
  static const String _notificationPrefsKey       = 'pigio_notification_prefs';

  // ── Fields ────────────────────────────────────────────────────────────────
  Locale _locale = const Locale('fr');
  PigioThemeVariant _themeVariant = PigioThemeVariant.light;
  bool _isBirthday = false;
  UserProfile _profile = const UserProfile(name: 'You', handle: '@you', memberSince: 2024);
  int _currentTabIndex  = 0;
  int _contactsSubIndex = 0;

  // Outfit
  Map<ClothingSlot, String?> _activeOutfit = {};
  List<String> _unlockedClothing = [];
  List<String> _unlockedBadges = [];
  ClothingRequest? _currentClothingRequest;
  final List<Map<ClothingSlot, String?>> _outfitHistory = [];
  List<String> _favoriteClothing = [];
  List<OutfitPreset> _outfitPresets = [];
  Map<String, int> _outfitColors = {}; // itemId → color ARGB32
  async_lib.Timer? _saveDebounce;

  // Data
  final List<Wish>              _wishes               = [];
  Map<String?, List<Wish>>?     _wishCache;
  final List<ContactProfile>    _contacts             = [];
  final List<CircleGroup>       _groups               = [];
  final List<Event>             _events               = [];
  final List<SizeProfile>       _sizes                = [];
  final List<GiftPot>           _giftPots             = [];
  final List<GroupPoll>         _polls                = [];
  final List<ActivityLog>       _activityLogs         = [];
  int                           _unseenLogsCount      = 0;
  final List<String>            _recentProfiles       = [];
  final List<PendingInvite>     _pendingInvites       = [];
  String?                       _inviteFocusContactId;
  final List<PigioNotification> _notifications        = [];
  int                           _unseenNotificationsCount = 0;
  final Map<String, DateTime>   _notificationCooldowns = {};
  final Set<String>             _consumedWizzNotificationIds = <String>{};
  final Set<String>             _consumedWizzHapticNotificationIds = <String>{};
  int                           _globalWizzNonce = 0;
  bool                          _appIsForeground = true;
  bool                          _pendingWizzShakeOnForeground = false;

  // Services
  final InvitationService _invitationService =
      InvitationService(
        baseApiUrl: _inviteApiBaseUrl,
        authTokenProvider: () async =>
            Supabase.instance.client.auth.currentSession?.accessToken,
      );
  late final NotificationService _notificationService =
      NotificationService(
        baseApiUrl: _inviteApiBaseUrl,
        authTokenProvider: () async =>
            Supabase.instance.client.auth.currentSession?.accessToken,
      );
  late final NotificationsCoordinator _notificationsCoordinator =
      NotificationsCoordinator(
        apiBaseUrl: _inviteApiBaseUrl,
        notificationService: _notificationService,
      );
  final AudioPlayer _wizzAudioPlayer = AudioPlayer();
  Uint8List? _wizzSoundBytes;
  String? _wizzSoundTempPath;
  static const Uuid _uuid = Uuid();
  static const _secureStorage = FlutterSecureStorage();

  // Periodic fallback sync timer (5 min; primary sync is via Realtime WebSocket)
  async_lib.Timer? _syncTimer;
  // Weather refresh timer — separate cadence (20 min, best-practice for weather APIs)
  async_lib.Timer? _weatherTimer;
  Daypart? _lastAppliedDaypart;

  // Supabase Realtime subscription for instant sync signals
  RealtimeChannel? _realtimeChannel;

  // Mascot / UX flags
  bool         _mascotVisible        = true;
  bool         _mascotSilent         = false;
  bool         _mascotSoundEnabled   = true;
  int          _mascotChattiness     = 1;
  Color        _mascotScarfColor     = const Color(0xFFFFD54F);
  String       _mascotDefaultCorner  = 'left';
  bool         _mascotReducedMotion  = false;
  bool         _mascotPrivacyMode    = false;
  bool         _surpriseMode         = true;
  bool         _contactsConsentGiven = false;
  MascotMoment _mascotMoment         = MascotMoment.none;
  bool         _busyMonthInsightShown = false;
  int          _mascotBondXp         = 0;
  DateTime     _mascotLastOpen       = DateTime.now();
  int          _mascotAbsenceDays    = 0;
  WeatherData? _currentWeather;
  bool         _weatherEffectsEnabled = true;
  bool         _autoTheme            = false;
  List<MascotMemory> _mascotMemories = [];
  DateTime? _mascotLastDailyBonus;
  int        _loginStreak           = 0;
  DateTime? _lastOutfitDismiss;
  DateTime? _lastReengagePush;
  Set<String> _completedCombos      = {};
  Set<String> _collectionMilestones = {};
  String? _dailyChallengeCompleted; // date string 'yyyy-MM-dd' of last completed challenge
  String? _userMood; // happy, neutral, sad, energetic, tired
  String? _userMoodDate; // date string 'yyyy-MM-dd'
  bool _moodCheckInPending = false;
  DateTime? _lastStaleCircleNudge;

  // Monetization


  // Sync / onboarding
  String _syncKey            = '';
  bool   _syncEnabled        = false;
  bool   _onboardingCompleted = false;

  // E2E Backup
  String _backupSalt       = ''; // base64-encoded salt (non-secret, stored in SharedPrefs)
  String _backupLookupKey  = ''; // SHA-256(phrase) used as sync_key on server
  Uint8List? _derivedKey;         // AES-256 key — memory-only cache, never persisted
  static const String _backupSaltKey      = 'pigio_backup_salt';
  static const String _backupLookupKeyKey = 'pigio_backup_lookup_key';

  // Personality / Wizz
  Map<String, List<String>> _personalityProfile = {};
  Map<String, String>       _wizzHistory         = {};
  WizzEffectMode            _wizzEffectMode      = WizzEffectMode.phase1;

  // Notification preferences (synced to cloud for edge function)
  Map<String, dynamic>      _notificationPrefs   = {};

  // Ready signal for deep-link handling
  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;

  // ── Constructor / Dispose ─────────────────────────────────────────────────
  PigioAppState() {
    _loadData();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _syncTimer?.cancel();
    _weatherTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _wizzAudioPlayer.dispose();
    _invitationService.dispose();
    super.dispose();
  }

  // ── Plain Getters ──────────────────────────────────────────────────────────
  Locale            get locale            => _locale;
  PigioThemeVariant get themeVariant      => _themeVariant;
  PigioThemeData    get currentTheme      => PigioThemes.fromVariant(_themeVariant);
  bool              get isBirthday        => _isBirthday;
  int               get currentTabIndex   => _currentTabIndex;
  int               get contactsSubIndex  => _contactsSubIndex;

  List<Wish>              get wishes                  => List.unmodifiable(_wishes);
  List<ContactProfile>    get contacts                => List.unmodifiable(_contacts);
  List<CircleGroup>       get groups                  => List.unmodifiable(_groups);
  List<Event>             get events                  => List.unmodifiable(_events);
  List<SizeProfile>       get sizes                   => List.unmodifiable(_sizes);
  List<GiftPot>           get giftPots                => List.unmodifiable(_giftPots);
  List<GroupPoll>         get polls                   => List.unmodifiable(_polls);
  UserProfile             get profile                 => _profile;
  List<ActivityLog>       get activityLogs            => List.unmodifiable(_activityLogs);
  int                     get unseenLogsCount         => _unseenLogsCount;
  List<String>            get recentProfiles          => List.unmodifiable(_recentProfiles);
  List<PendingInvite>     get pendingInvites          => List.unmodifiable(_pendingInvites);
  String?                 get inviteFocusContactId    => _inviteFocusContactId;
  List<PigioNotification> get notifications           => List.unmodifiable(_notifications);
  int                     get unseenNotificationsCount => _unseenNotificationsCount;
  Map<String, dynamic>    get notificationPrefs     => Map.unmodifiable(_notificationPrefs);

  bool         get mascotVisible         => _mascotVisible;
  bool         get mascotSilent          => _mascotSilent;
  bool         get mascotSoundEnabled    => _mascotSoundEnabled;
  int          get mascotChattiness      => _mascotChattiness;
  Color        get mascotScarfColor      => _mascotScarfColor;
  Map<String, int> get outfitColors       => Map.unmodifiable(_outfitColors);
  String       get mascotDefaultCorner   => _mascotDefaultCorner;
  bool         get mascotReducedMotion   => _mascotReducedMotion;
  bool         get mascotPrivacyMode     => _mascotPrivacyMode;
  List<MascotMemory> get mascotMemories  => _mascotMemories;
  DateTime?    get mascotLastDailyBonus  => _mascotLastDailyBonus;
  int          get loginStreak          => _loginStreak;
  DateTime?    get lastOutfitDismiss     => _lastOutfitDismiss;
  DateTime?    get lastReengagePush      => _lastReengagePush;
  Set<String>  get completedCombos      => Set.unmodifiable(_completedCombos);
  Set<String>  get collectionMilestones => Set.unmodifiable(_collectionMilestones);
  String?      get dailyChallengeCompleted => _dailyChallengeCompleted;
  String?      get userMood               => _userMood;
  String?      get userMoodDate           => _userMoodDate;
  bool         get moodCheckInPending     => _moodCheckInPending;
  bool         get surpriseMode          => _surpriseMode;
  bool         get contactsConsentGiven  => _contactsConsentGiven;
  MascotMoment get mascotMoment          => _mascotMoment;
  int          get mascotBondXp          => _mascotBondXp;
  WeatherData? get currentWeather        => _currentWeather;
  bool         get weatherEffectsEnabled => _weatherEffectsEnabled;
  bool         get autoTheme             => _autoTheme;

  // Subscription
  bool         get isPremium            => SubscriptionService.isPremium;
  DateTime?    get plusExpirationDate   => SubscriptionService.plusExpirationDate;

  /// Current part of the day based on the local hour.
  Daypart get currentDaypart {
    final h = DateTime.now().hour;
    if (h < 6)  return Daypart.night;
    if (h < 9)  return Daypart.earlyMorning;
    if (h < 12) return Daypart.morning;
    if (h < 14) return Daypart.midday;
    if (h < 18) return Daypart.afternoon;
    if (h < 21) return Daypart.evening;
    return Daypart.night;
  }

  /// Bond level: 0-4 based on XP thresholds.
  /// 0 = Stranger, 1 = Acquaintance, 2 = Friend, 3 = Best Friend, 4 = Soulmate
  int get mascotBondLevel {
    if (_mascotBondXp >= 500) return 4;
    if (_mascotBondXp >= 200) return 3;
    if (_mascotBondXp >= 50)  return 2;
    if (_mascotBondXp >= 10)  return 1;
    return 0;
  }

  /// Visual growth stage for PigioPainter.
  /// 0 = Egg (0-9), 1 = Chick (10-49), 2 = Juvenile (50-199), 3 = Adult (200-499), 4 = Elder (500+)
  int get mascotStage => mascotBondLevel;

  String get mascotStageName {
    const names = ['Œuf', 'Poussin', 'Juvénile', 'Adulte', 'Aîné'];
    return names[mascotStage.clamp(0, names.length - 1)];
  }

  String get mascotStageNameEn {
    const names = ['Egg', 'Chick', 'Juvenile', 'Adult', 'Elder'];
    return names[mascotStage.clamp(0, names.length - 1)];
  }

  String get mascotStageEmoji {
    const emojis = ['🥚', '🐣', '🐧', '🎩', '👑'];
    return emojis[mascotStage.clamp(0, emojis.length - 1)];
  }

  String get mascotBondTitle {
    switch (mascotBondLevel) {
      case 0: return 'Stranger';
      case 1: return 'Acquaintance';
      case 2: return 'Friend';
      case 3: return 'Best Friend';
      case 4: return 'Soulmate';
      default: return 'Stranger';
    }
  }

  String get mascotBondEmoji {
    switch (mascotBondLevel) {
      case 0: return '🤝';
      case 1: return '👋';
      case 2: return '🤗';
      case 3: return '💛';
      case 4: return '💎';
      default: return '🤝';
    }
  }

  void incrementMascotBond([int xp = 1]) {
    _mascotBondXp += xp;
    AnalyticsService.mascotInteraction('bond_increment');
    notifyListeners();
    _saveData();
  }

  /// How many days since the user last opened the app.
  int get mascotAbsenceDays => _mascotAbsenceDays;

  /// Mood Pigio should show on return:
  /// >3 days absent = sad/lonely, >1 day = excited to see you, same day = normal
  String get mascotReturnMood {
    if (_mascotAbsenceDays >= 3) return 'sad';
    if (_mascotAbsenceDays >= 1) return 'excited';
    return 'normal';
  }
  String       get syncKey               => _syncKey;
  bool         get syncEnabled           => _syncEnabled;
  bool         get onboardingCompleted   => _onboardingCompleted;
  bool         get needsOnboarding => !_onboardingCompleted;
  String       get backupSalt            => _backupSalt;
  String       get backupLookupKey       => _backupLookupKey;
  Uint8List?   get derivedKey            => _derivedKey;
  Map<String, List<String>> get personalityProfile => _personalityProfile;
  WizzEffectMode get wizzEffectMode => _wizzEffectMode;
  int            get globalWizzNonce => _globalWizzNonce;

  /// Compact human-readable summary of the user's personality for AI prompts.
  String get personalityProfileSummary {
    if (_personalityProfile.isEmpty) return '';
    return _personalityProfile.entries
        .map((e) => '${e.key}: ${e.value.join(', ')}')
        .join(' | ');
  }

  /// Number of activity logs from the last 7 days.
  int get unreadActivityCount {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _activityLogs.where((a) => a.timestamp.isAfter(cutoff)).length;
  }

  // Outfit getters (used by mascot & wardrobe screens)
  Map<ClothingSlot, String?> get activeOutfit        => _activeOutfit;
  List<String> get unlockedClothing       => _unlockedClothing;
  List<String> get unlockedBadges         => _unlockedBadges;
  ClothingRequest? get currentClothingRequest => _currentClothingRequest;
  List<String> get favoriteClothing => _favoriteClothing;
  List<OutfitPreset> get outfitPresets => _outfitPresets;
  bool get canUndoOutfit => _outfitHistory.isNotEmpty;

  // ── Badges ─────────────────────────────────────────────────────────────────

  /// Checks if a badge trigger is met. If so, unlocks the badge and notifies.
  /// Needs to be called with a callback to show the unlock dialog in the UI.
  void checkBadgeTrigger(BadgeTrigger trigger, {void Function(UserBadge badge)? onUnlocked}) {
    final badge = UserBadge.catalog.firstWhere((b) => b.trigger == trigger, orElse: () => throw Exception('Unknown badge'));
    if (_unlockedBadges.contains(badge.id)) return; // Already unlocked

    _unlockedBadges.add(badge.id);
    AnalyticsService.log('badge_unlocked', {'badge_id': badge.id});
    notifyListeners();
    _saveData();

    if (onUnlocked != null) {
      onUnlocked(badge);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _newId() => _uuid.v4();
  void _invalidateWishCache() => _wishCache = null;

  /// Instance-level accessor so extension part files can reference the API URL
  /// without needing to qualify the private static member.
  String get _apiBaseUrl => _inviteApiBaseUrl;

  // ── Persistence ───────────────────────────────────────────────────────────

  /// Bulk restore from a decrypted E2E backup.
  /// Called by BackupService.deserializeIntoState().
  void restoreFromBackup({
    required List<ContactProfile> contacts,
    required List<CircleGroup> groups,
    required List<Wish> wishes,
    required List<Event> events,
    required List<SizeProfile> sizes,
    required List<GiftPot> giftPots,
    required List<GroupPoll> polls,
    required List<PendingInvite> pendingInvites,
    required List<ActivityLog> activityLogs,
    required List<PigioNotification> notifications,
    UserProfile? profile,
  }) {
    // Merge by ID so we don't lose any local data that isn't in the backup
    _mergeById<ContactProfile>(_contacts, contacts, (c) => c.id);
    _mergeById<CircleGroup>(_groups, groups, (g) => g.id);
    _mergeById<Wish>(_wishes, wishes, (w) => w.id);
    _mergeById<Event>(_events, events, (e) => e.id);
    _mergeById<SizeProfile>(_sizes, sizes, (s) => '${s.contactId}_${s.categoryKey}');
    _mergeById<GiftPot>(_giftPots, giftPots, (p) => p.id);
    _mergeById<GroupPoll>(_polls, polls, (p) => p.id);
    _mergeById<PendingInvite>(_pendingInvites, pendingInvites, (i) => i.id);
    _mergeById<ActivityLog>(_activityLogs, activityLogs, (a) => a.id);
    _mergeById<PigioNotification>(_notifications, notifications, (n) => n.id);

    if (profile != null) _profile = profile;

    _invalidateWishCache();
    notifyListeners();
    _saveData();
  }

  /// Debounced save — coalesces rapid mutations into a single write after 500ms.
  void _saveData() {
    _saveDebounce?.cancel();
    _saveDebounce = async_lib.Timer(const Duration(milliseconds: 500), _saveDataNow);
  }

  /// Immediate persistence — use only when the caller needs a guaranteed write
  /// (e.g. enableSync, account wipe, signOut).
  Future<void> _saveDataNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey,   _locale.languageCode);
    await prefs.setString(_themeKey,    _themeVariant.name);
    // All personal / financial data stored encrypted via FlutterSecureStorage.
    await _secureWrite(key: _wishesKey,    value: jsonEncode(_wishes.map((w) => w.toMap()).toList()));
    await _secureWrite(key: _contactsKey,  value: jsonEncode(_contacts.map((m) => m.toMap()).toList()));
    await _secureWrite(key: _groupsKey,    value: jsonEncode(_groups.map((g) => g.toMap()).toList()));
    await _secureWrite(key: _eventsKey,    value: jsonEncode(_events.map((e) => e.toMap()).toList()));
    await _secureWrite(key: _sizesKey,     value: jsonEncode(_sizes.map((s) => s.toMap()).toList()));
    await _secureWrite(key: _giftPotsKey,  value: jsonEncode(_giftPots.map((p) => p.toMap()).toList()));
    await _secureWrite(key: _pollsKey,    value: jsonEncode(_polls.map((p) => p.toMap()).toList()));
    await _secureWrite(key: _profileKey, value: jsonEncode(_profile.toMap()));
    await prefs.setInt(_unseenLogsKey,   _unseenLogsCount);
    await _secureWrite(key: _activityLogsKey, value: jsonEncode(_activityLogs.map((a) => a.toMap()).toList()));
    await prefs.setStringList(_recentProfilesKey, _recentProfiles);
    await _secureWrite(key: _pendingInvitesKey, value: jsonEncode(_pendingInvites.map((i) => i.toMap()).toList()));
    // Notifications — stored in secure storage to protect message content
    await _secureWrite(key: _notificationsKey, value: jsonEncode(_notifications.map((n) => n.toMap()).toList()));
    await prefs.setInt('pigio_unseen_notifications', _unseenNotificationsCount);
    // Notification preferences — stored encrypted
    await _secureWrite(key: _notificationPrefsKey, value: jsonEncode(_notificationPrefs));
    // Mascot
    await prefs.setBool(_mascotVisibleKey,       _mascotVisible);
    await prefs.setBool(_mascotSilentKey,        _mascotSilent);
    await prefs.setBool(_mascotSoundEnabledKey,  _mascotSoundEnabled);
    await prefs.setInt(_mascotChattinessKey,     _mascotChattiness);
    await prefs.setInt(_mascotScarfColorKey,     _mascotScarfColor.toARGB32());
    await prefs.setString(_mascotCornerKey,      _mascotDefaultCorner);
    await prefs.setBool(_mascotReducedMotionKey, _mascotReducedMotion);
    await prefs.setBool(_mascotPrivacyKey,       _mascotPrivacyMode);
    await prefs.setBool(_weatherEffectsKey,      _weatherEffectsEnabled);
    await prefs.setBool(_autoThemeKey,           _autoTheme);
    await prefs.setInt(_mascotBondXpKey,          _mascotBondXp);
    await prefs.setString(_mascotLastOpenKey,      DateTime.now().toIso8601String());
    await prefs.setBool(_surpriseModeKey,        _surpriseMode);
    await prefs.setBool(_contactsConsentGivenKey, _contactsConsentGiven);
    // Mascot memories & daily bonus
    if (_mascotMemories.isNotEmpty) {
      await prefs.setString(_mascotMemoriesKey, jsonEncode(_mascotMemories.map((m) => m.toMap()).toList()));
    }
    if (_mascotLastDailyBonus != null) {
      await prefs.setString(_mascotLastDailyBonusKey, _mascotLastDailyBonus!.toIso8601String());
    }
    await prefs.setInt(_loginStreakKey, _loginStreak);
    await prefs.setStringList(_completedCombosKey, _completedCombos.toList());
    await prefs.setStringList(_collectionMilestonesKey, _collectionMilestones.toList());
    if (_dailyChallengeCompleted != null) {
      await prefs.setString(_dailyChallengeKey, _dailyChallengeCompleted!);
    }
    if (_userMood != null) await prefs.setString(_userMoodKey, _userMood!);
    if (_userMoodDate != null) await prefs.setString(_userMoodDateKey, _userMoodDate!);
    if (_lastOutfitDismiss != null) {
      await prefs.setString(_lastOutfitDismissKey, _lastOutfitDismiss!.toIso8601String());
    }
    if (_lastReengagePush != null) {
      await prefs.setString(_lastReengagePushKey, _lastReengagePush!.toIso8601String());
    }
    if (_lastStaleCircleNudge != null) {
      await prefs.setString(_lastStaleCircleNudgeKey, _lastStaleCircleNudge!.toIso8601String());
    }
    // Outfit
    final outfitMap = _activeOutfit.map((k, v) => MapEntry(k.name, v));
    await prefs.setString(_activeOutfitKey,      jsonEncode(outfitMap));
    await prefs.setStringList(_unlockedClothingKey, _unlockedClothing);
    await prefs.setStringList(_favoriteClothingKey, _favoriteClothing);
    await prefs.setStringList(_unlockedBadgesKey, _unlockedBadges);
    await prefs.setString(_outfitColorsKey, jsonEncode(_outfitColors));
    await prefs.setString(_outfitPresetsKey, jsonEncode(_outfitPresets.map((p) => p.toMap()).toList()));
    // Sync / onboarding — sync key stored in secure storage (not SharedPreferences)
    if (_syncKey.isNotEmpty) {
      await _secureWrite(key: _syncKeyKey, value: _syncKey);
    }
    await prefs.setBool('pigio_sync_enabled', _syncEnabled);
    // E2E Backup salt & lookup key (non-secret, stored in SharedPreferences)
    if (_backupSalt.isNotEmpty) {
      await prefs.setString(_backupSaltKey, _backupSalt);
    }
    if (_backupLookupKey.isNotEmpty) {
      await prefs.setString(_backupLookupKeyKey, _backupLookupKey);
    }
    await prefs.setBool(_onboardingCompletedKey, _onboardingCompleted);
    // Personality — encrypted (behavioural PII)
    if (_personalityProfile.isNotEmpty) {
      await _secureWrite(key: _personalityProfileKey, value: jsonEncode(_personalityProfile));
    }
    // Wizz
    if (_wizzHistory.isNotEmpty) {
      await prefs.setString(_wizzKey, jsonEncode(_wizzHistory));
    }
    await prefs.setString(_wizzEffectModeKey, _wizzEffectMode.name);
    // Cloud push (fire-and-forget)
    if (_syncEnabled) {
      if (_backupLookupKey.isNotEmpty && _derivedKey != null) {
        Future.microtask(() => _pushE2EBackup());
      } else if (_syncKey.isNotEmpty) {
        Future.microtask(() => _pushToCloud());
      }
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Fetch all secure storage values in parallel — avoids up to 30s of
    // sequential reads (12 keys × 5s timeout each).
    final secureValues = await Future.wait([
      _secureRead(_contactsKey),        // [0]
      _secureRead(_profileKey),          // [1]
      _secureRead(_activityLogsKey),     // [2]
      _secureRead(_pendingInvitesKey),   // [3]
      _secureRead(_notificationsKey),    // [4]
      _secureRead(_syncKeyKey),          // [5]
      _secureRead(_wishesKey),           // [6]
      _secureRead(_groupsKey),           // [7]
      _secureRead(_eventsKey),           // [8]
      _secureRead(_sizesKey),            // [9]
      _secureRead(_giftPotsKey),         // [10]
      _secureRead(_pollsKey),            // [11]
      _secureRead(_personalityProfileKey), // [12]
      _secureRead(_notificationPrefsKey),   // [13]
    ]);

    final localeCode = prefs.getString(_localeKey);
    if (localeCode != null && localeCode.isNotEmpty) {
      _locale = Locale(localeCode);
    }

    final themeRaw = prefs.getString(_themeKey);
    if (themeRaw != null) {
      _themeVariant = PigioThemeVariant.values.firstWhere(
        (v) => v.name == themeRaw,
        orElse: () => PigioThemeVariant.light,
      );
    }

    final outfitRaw = prefs.getString(_activeOutfitKey);
    if (outfitRaw != null && outfitRaw.isNotEmpty) {
      try {
        final raw = jsonDecode(outfitRaw);
        if (raw is Map<String, dynamic>) {
          _activeOutfit = {};
          raw.forEach((k, v) {
            final slot = ClothingSlot.values.firstWhere(
                (s) => s.name == k, orElse: () => ClothingSlot.accessory);
            if (v is String) _activeOutfit[slot] = v;
          });
        }
      } catch (e) {
        log.warn('AppState', 'Failed to decode active outfit', e);
      }
    }

    _unlockedClothing = prefs.getStringList(_unlockedClothingKey) ?? [];
    _unlockedBadges = prefs.getStringList(_unlockedBadgesKey) ?? [];
    _favoriteClothing = prefs.getStringList(_favoriteClothingKey) ?? [];
    final presetsRaw = prefs.getString(_outfitPresetsKey);
    if (presetsRaw != null && presetsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(presetsRaw) as List;
        _outfitPresets = decoded.map((e) => OutfitPreset.fromMap(e as Map<String, dynamic>)).toList();
      } catch (e) {
        log.warn('AppState', 'Failed to decode outfit presets', e);
      }
    }

    // Wishes — read from secure storage; migrate from SharedPreferences on first run
    final secureWishesRaw = secureValues[6];
    if (secureWishesRaw != null && secureWishesRaw.isNotEmpty) {
      _wishes..clear()..addAll(_decodeListFromString(secureWishesRaw).map(Wish.fromMap));
    } else {
      final legacyWishes = prefs.getString(_wishesKey);
      if (legacyWishes != null && legacyWishes.isNotEmpty) {
        _wishes..clear()..addAll(_decodeListFromString(legacyWishes).map(Wish.fromMap));
        await _secureWrite(key: _wishesKey, value: legacyWishes);
        await prefs.remove(_wishesKey);
      }
    }
    // Contacts stored in secure storage — migrate from SharedPreferences on first run
    final secureContactsRaw = secureValues[0];
    if (secureContactsRaw != null && secureContactsRaw.isNotEmpty) {
      _contacts.clear();
      _contacts.addAll(_decodeListFromString(secureContactsRaw).map(ContactProfile.fromMap));
    } else {
      final legacyContacts = prefs.getString(_contactsKey);
      if (legacyContacts != null && legacyContacts.isNotEmpty) {
        _contacts.clear();
        _contacts.addAll(_decodeListFromString(legacyContacts).map(ContactProfile.fromMap));
        await _secureWrite(key: _contactsKey, value: legacyContacts);
        await prefs.remove(_contactsKey);
      }
    }
    // Groups — read from secure storage; migrate from SharedPreferences on first run
    final secureGroupsRaw = secureValues[7];
    if (secureGroupsRaw != null && secureGroupsRaw.isNotEmpty) {
      _groups..clear()..addAll(_decodeListFromString(secureGroupsRaw).map(CircleGroup.fromMap));
    } else {
      final legacyGroups = prefs.getString(_groupsKey);
      if (legacyGroups != null && legacyGroups.isNotEmpty) {
        _groups..clear()..addAll(_decodeListFromString(legacyGroups).map(CircleGroup.fromMap));
        await _secureWrite(key: _groupsKey, value: legacyGroups);
        await prefs.remove(_groupsKey);
      }
    }

    // Ensure Famille group always exists
    if (!_groups.any((g) => g.isSystem &&
        (g.name == 'Famille' || g.id == 'famille_default'))) {
      _groups.insert(0, CircleGroup(
        id: 'famille_default',
        name: 'Famille',
        emoji: '🏠',
        contactIds: _contacts.where((c) => c.isFamily).map((c) => c.id).toList(),
        isSystem: true,
        trustLevel: TrustLevel.family,
        pendingInviteIds: const [],
      ));
    }

    // Events — read from secure storage; migrate from SharedPreferences on first run
    final secureEventsRaw = secureValues[8];
    if (secureEventsRaw != null && secureEventsRaw.isNotEmpty) {
      _events..clear()..addAll(_decodeListFromString(secureEventsRaw).map(Event.fromMap));
    } else {
      final legacyEvents = prefs.getString(_eventsKey);
      if (legacyEvents != null && legacyEvents.isNotEmpty) {
        _events..clear()..addAll(_decodeListFromString(legacyEvents).map(Event.fromMap));
        await _secureWrite(key: _eventsKey, value: legacyEvents);
        await prefs.remove(_eventsKey);
      }
    }
    // Sizes — read from secure storage; migrate from SharedPreferences on first run
    final secureSizesRaw = secureValues[9];
    if (secureSizesRaw != null && secureSizesRaw.isNotEmpty) {
      _sizes..clear()..addAll(_decodeListFromString(secureSizesRaw).map(SizeProfile.fromMap));
    } else {
      final legacySizes = prefs.getString(_sizesKey);
      if (legacySizes != null && legacySizes.isNotEmpty) {
        _sizes..clear()..addAll(_decodeListFromString(legacySizes).map(SizeProfile.fromMap));
        await _secureWrite(key: _sizesKey, value: legacySizes);
        await prefs.remove(_sizesKey);
      }
    }
    // Gift Pots — read from secure storage; migrate from SharedPreferences on first run
    final secureGiftPotsRaw = secureValues[10];
    if (secureGiftPotsRaw != null && secureGiftPotsRaw.isNotEmpty) {
      _giftPots..clear()..addAll(_decodeListFromString(secureGiftPotsRaw).map(GiftPot.fromMap));
    } else {
      final legacyGiftPots = prefs.getString(_giftPotsKey);
      if (legacyGiftPots != null && legacyGiftPots.isNotEmpty) {
        _giftPots..clear()..addAll(_decodeListFromString(legacyGiftPots).map(GiftPot.fromMap));
        await _secureWrite(key: _giftPotsKey, value: legacyGiftPots);
        await prefs.remove(_giftPotsKey);
      }
    }
    // Polls — read from secure storage; migrate from SharedPreferences on first run
    final securePollsRaw = secureValues[11];
    if (securePollsRaw != null && securePollsRaw.isNotEmpty) {
      _polls..clear()..addAll(_decodeListFromString(securePollsRaw).map(GroupPoll.fromMap));
    } else {
      final legacyPolls = prefs.getString(_pollsKey);
      if (legacyPolls != null && legacyPolls.isNotEmpty) {
        _polls..clear()..addAll(_decodeListFromString(legacyPolls).map(GroupPoll.fromMap));
        await _secureWrite(key: _pollsKey, value: legacyPolls);
        await prefs.remove(_pollsKey);
      }
    }

    // Profile stored in secure storage — migrate from SharedPreferences on first run
    final secureProfileRaw = secureValues[1];
    final profileRaw = secureProfileRaw ?? prefs.getString(_profileKey);
    if (profileRaw != null && profileRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(profileRaw);
        if (decoded is Map<String, dynamic>) {
          _profile = UserProfile.fromMap(decoded);
        }
        if (secureProfileRaw == null) {
          await _secureWrite(key: _profileKey, value: profileRaw);
          await prefs.remove(_profileKey);
        }
      } catch (e) {
        log.warn('AppState', 'Failed to decode user profile', e);
      }
    }

    _unseenLogsCount = prefs.getInt(_unseenLogsKey) ?? 0;

    // Activity logs — read from secure storage, migrate from SharedPreferences if needed
    final secureLogsRaw = secureValues[2];
    if (secureLogsRaw != null && secureLogsRaw.isNotEmpty) {
      _activityLogs.clear();
      _activityLogs.addAll(_decodeListFromString(secureLogsRaw).map(ActivityLog.fromMap));
    } else {
      final legacyLogs = prefs.getString(_activityLogsKey);
      if (legacyLogs != null && legacyLogs.isNotEmpty) {
        _activityLogs.clear();
        _activityLogs.addAll(_decodeListFromString(legacyLogs).map(ActivityLog.fromMap));
        await _secureWrite(key: _activityLogsKey, value: legacyLogs);
        await prefs.remove(_activityLogsKey);
      }
    }

    _recentProfiles..clear()..addAll(prefs.getStringList(_recentProfilesKey) ?? []);

    // PendingInvites stored in secure storage — migrate from SharedPreferences on first run
    final secureInvitesRaw = secureValues[3];
    if (secureInvitesRaw != null && secureInvitesRaw.isNotEmpty) {
      _pendingInvites.clear();
      _pendingInvites.addAll(_decodeListFromString(secureInvitesRaw).map(PendingInvite.fromMap));
    } else {
      final legacyInvites = prefs.getString(_pendingInvitesKey)
          ?? prefs.getString(_legacyPendingInvitesKey);
      if (legacyInvites != null && legacyInvites.isNotEmpty) {
        _pendingInvites.clear();
        _pendingInvites.addAll(_decodeListFromString(legacyInvites).map(PendingInvite.fromMap));
        await _secureWrite(key: _pendingInvitesKey, value: legacyInvites);
        await prefs.remove(_pendingInvitesKey);
        await prefs.remove(_legacyPendingInvitesKey);
      }
    }

    // Notifications — read from secure storage, migrate from SharedPreferences if needed
    final secureNotifsRaw = secureValues[4];
    if (secureNotifsRaw != null && secureNotifsRaw.isNotEmpty) {
      _notifications.clear();
      _notifications.addAll(_decodeListFromString(secureNotifsRaw).map(PigioNotification.fromMap));
    } else {
      final legacyNotifs = prefs.getString(_notificationsKey);
      if (legacyNotifs != null && legacyNotifs.isNotEmpty) {
        _notifications.clear();
        _notifications.addAll(_decodeListFromString(legacyNotifs).map(PigioNotification.fromMap));
        await _secureWrite(key: _notificationsKey, value: legacyNotifs);
        await prefs.remove(_notificationsKey);
      }
    }
    _unseenNotificationsCount =
        prefs.getInt('pigio_unseen_notifications') ?? 0;

    // Mascot
    _mascotVisible      = prefs.getBool(_mascotVisibleKey) ?? true;
    _mascotSilent       = prefs.getBool(_mascotSilentKey) ?? false;
    _mascotSoundEnabled = prefs.getBool(_mascotSoundEnabledKey) ?? true;
    _mascotChattiness   = prefs.getInt(_mascotChattinessKey) ?? 1;
    final scarfVal = prefs.getInt(_mascotScarfColorKey);
    if (scarfVal != null) _mascotScarfColor = Color(scarfVal);
    final colorsRaw = prefs.getString(_outfitColorsKey);
    if (colorsRaw != null && colorsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(colorsRaw);
        if (decoded is Map<String, dynamic>) {
          _outfitColors = decoded.map((k, v) => MapEntry(k, v as int));
        }
      } catch (e) {
        log.warn('AppState', 'Failed to decode outfit colors', e);
      }
    }
    
    // Fetch current weather continuously in background without blocking init
    fetchWeather();
    _mascotDefaultCorner = prefs.getString(_mascotCornerKey) ?? 'left';
    _mascotReducedMotion = prefs.getBool(_mascotReducedMotionKey) ?? false;
    _mascotPrivacyMode  = prefs.getBool(_mascotPrivacyKey) ?? false;
    _weatherEffectsEnabled = prefs.getBool(_weatherEffectsKey) ?? true;
    _autoTheme           = prefs.getBool(_autoThemeKey) ?? false;
    // Apply auto-theme on init if enabled
    _checkDaypartAutoTheme();
    _mascotBondXp       = prefs.getInt(_mascotBondXpKey) ?? 0;
    final lastOpenRaw   = prefs.getString(_mascotLastOpenKey);
    if (lastOpenRaw != null) {
      _mascotLastOpen = DateTime.tryParse(lastOpenRaw) ?? DateTime.now();
      _mascotAbsenceDays = DateTime.now().difference(_mascotLastOpen).inDays;

      // Bond XP decay — subtract 5 XP per full week of inactivity (floor 0).
      // Encourages regular engagement without punishing short breaks.
      if (_mascotAbsenceDays >= 7) {
        final weeksAway = _mascotAbsenceDays ~/ 7;
        final decay = weeksAway * 5;
        if (decay > 0 && _mascotBondXp > 0) {
          _mascotBondXp = (_mascotBondXp - decay).clamp(0, _mascotBondXp);
        }
      }
    }
    // Load mascot memories
    final memoriesRaw = prefs.getString(_mascotMemoriesKey);
    if (memoriesRaw != null && memoriesRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(memoriesRaw) as List;
        _mascotMemories = decoded.map((e) => MascotMemory.fromMap(e as Map<String, dynamic>)).toList();
      } catch (e) {
        log.warn('AppState', 'Failed to decode mascot memories', e);
      }
    }
    // Load daily bonus timestamp
    final dailyBonusRaw = prefs.getString(_mascotLastDailyBonusKey);
    if (dailyBonusRaw != null) _mascotLastDailyBonus = DateTime.tryParse(dailyBonusRaw);
    _loginStreak = prefs.getInt(_loginStreakKey) ?? 0;
    _completedCombos = (prefs.getStringList(_completedCombosKey) ?? []).toSet();
    _collectionMilestones = (prefs.getStringList(_collectionMilestonesKey) ?? []).toSet();
    _dailyChallengeCompleted = prefs.getString(_dailyChallengeKey);
    _userMood = prefs.getString(_userMoodKey);
    _userMoodDate = prefs.getString(_userMoodDateKey);
    // Load outfit dismiss timestamp
    final outfitDismissRaw = prefs.getString(_lastOutfitDismissKey);
    if (outfitDismissRaw != null) _lastOutfitDismiss = DateTime.tryParse(outfitDismissRaw);
    // Load re-engagement push timestamp
    final reengageRaw = prefs.getString(_lastReengagePushKey);
    if (reengageRaw != null) _lastReengagePush = DateTime.tryParse(reengageRaw);
    // Load stale circle nudge timestamp
    final staleCircleRaw = prefs.getString(_lastStaleCircleNudgeKey);
    if (staleCircleRaw != null) _lastStaleCircleNudge = DateTime.tryParse(staleCircleRaw);
    // Update last open to now
    await prefs.setString(_mascotLastOpenKey, DateTime.now().toIso8601String());
    _surpriseMode       = prefs.getBool(_surpriseModeKey) ?? true;
    _contactsConsentGiven = prefs.getBool(_contactsConsentGivenKey) ?? false;

    // Sync — read from secure storage; migrate from SharedPreferences if needed
    final secureSyncKey = secureValues[5];
    if (secureSyncKey != null && secureSyncKey.isNotEmpty) {
      _syncKey = secureSyncKey;
    } else {
      // One-time migration: move the key from SharedPreferences to secure storage
      final legacySyncKey = prefs.getString(_syncKeyKey) ?? '';
      if (legacySyncKey.isNotEmpty) {
        _syncKey = legacySyncKey;
        await _secureWrite(key: _syncKeyKey, value: legacySyncKey);
        await prefs.remove(_syncKeyKey);
      }
    }
    _syncEnabled       = prefs.getBool('pigio_sync_enabled') ?? false;
    _onboardingCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;
    // E2E Backup
    _backupSalt      = prefs.getString(_backupSaltKey) ?? '';
    _backupLookupKey = prefs.getString(_backupLookupKeyKey) ?? '';

    // Personality profile — read from secure storage; migrate from SharedPreferences on first run
    final securePersonalityRaw = secureValues[12];
    final personalityRaw = securePersonalityRaw ?? prefs.getString(_personalityProfileKey);
    if (personalityRaw != null && personalityRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(personalityRaw);
        if (decoded is Map<String, dynamic>) {
          _personalityProfile = decoded.map(
              (k, v) => MapEntry(k, v is List ? v.cast<String>() : <String>[]));  
        }
        if (securePersonalityRaw == null) {
          await _secureWrite(key: _personalityProfileKey, value: personalityRaw);
          await prefs.remove(_personalityProfileKey);
        }
      } catch (e) {
        log.warn('AppState', 'Failed to decode personality profile', e);
      }
    }

    // Notification preferences — read from secure storage
    final secureNotifPrefsRaw = secureValues[13];
    if (secureNotifPrefsRaw != null && secureNotifPrefsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(secureNotifPrefsRaw);
        if (decoded is Map<String, dynamic>) {
          _notificationPrefs = decoded;
        }
      } catch (e) {
        log.warn('AppState', 'Failed to decode notification prefs', e);
      }
    }

    // Wizz history
    final wizzRaw = prefs.getString(_wizzKey);
    if (wizzRaw != null && wizzRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(wizzRaw);
        if (decoded is Map<String, dynamic>) {
          _wizzHistory = decoded.cast<String, String>();
        }
      } catch (e) {
        log.warn('AppState', 'Failed to decode Wizz history', e);
      }
    }

    final wizzEffectRaw = prefs.getString(_wizzEffectModeKey);
    if (wizzEffectRaw != null && wizzEffectRaw.isNotEmpty) {
      _wizzEffectMode = WizzEffectMode.values.firstWhere(
        (m) => m.name == wizzEffectRaw,
        orElse: () => WizzEffectMode.phase1,
      );
    }



    _pruneOrphanedIds();
    notifyListeners();

    if (!_readyCompleter.isCompleted) _readyCompleter.complete();

    Future.microtask(() => evaluateBusyMonth());
    Future.microtask(() => _syncPendingInvitesFromServer());
    Future.microtask(() => _pullContactProfiles());
    Future.microtask(() => _pullNotifications());

    // ── Realtime WebSocket subscription ──────────────────────────────
    // Subscribe to sync_signals via Supabase Realtime Postgres Changes.
    // When any edge function inserts a signal for our user_id, we
    // immediately pull the relevant data instead of waiting for a timer.
    _subscribeToRealtimeSignals();

    // Fallback timer: 5 minutes — only fires if WebSocket disconnects or
    // a signal is missed. Primary sync is now driven by Realtime + FCM.
    _syncTimer?.cancel();
    _syncTimer = async_lib.Timer.periodic(const Duration(minutes: 5), (_) {
      _syncPendingInvitesFromServer();
      _pullContactProfiles();
      _pushOwnContactProfile();
      _pullNotifications();
      _checkDaypartAutoTheme();
    });

    // Weather refresh: 20-min cadence (Open-Meteo updates hourly; 15-min cache
    // inside WeatherService means real fetches happen every ~20 min).
    _weatherTimer?.cancel();
    _weatherTimer = async_lib.Timer.periodic(const Duration(minutes: 20), (_) {
      fetchWeather();
    });
  }

  /// Subscribe to Supabase Realtime Postgres Changes on the sync_signals
  /// table. Filtered server-side by RLS (target_user_id = auth.uid()).
  void _subscribeToRealtimeSignals() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return; // Not authenticated — skip Realtime.

    _realtimeChannel = Supabase.instance.client
        .channel('sync_signals')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sync_signals',
          callback: (payload) {
            final signalType =
                payload.newRecord['signal_type'] as String? ?? 'data_changed';
            if (kDebugMode) {
              debugPrint('[Kindy] Realtime signal received: $signalType');
            }
            _handleRealtimeSignal(signalType);
          },
        )
        .subscribe();
  }

  /// React to an incoming Realtime sync signal by pulling the relevant data.
  void _handleRealtimeSignal(String signalType) {
    Future.microtask(() {
      switch (signalType) {
        case 'notification':
          _pullNotifications();
        case 'profile':
          _pullContactProfiles();
        default:
          // Generic data_changed — pull everything.
          _syncPendingInvitesFromServer();
          _pullContactProfiles();
          _pullNotifications();
      }
    });
  }

  /// Refreshes the current weather and holds it in state.
  /// Skips the call entirely when offline. Retries once after 5 s on failure.
  Future<void> fetchWeather() async {
    if (!ConnectivityService.instance.isOnline) return;
    var wData = await WeatherService.fetchCurrent();
    if (wData == null && ConnectivityService.instance.isOnline) {
      await Future<void>.delayed(const Duration(seconds: 5));
      wData = await WeatherService.fetchCurrent();
    }
    if (wData != null && wData != _currentWeather) {
      _currentWeather = wData;
      notifyListeners();
    }
  }

  /// Auto-switch theme based on daypart when [autoTheme] is enabled.
  /// Only triggers a change when the daypart actually transitions.
  void _checkDaypartAutoTheme() {
    if (!_autoTheme) return;
    final dp = currentDaypart;
    if (dp == _lastAppliedDaypart) return;
    _lastAppliedDaypart = dp;
    final wantDark = dp == Daypart.night || dp == Daypart.evening;
    final alreadyDark = _themeVariant == PigioThemeVariant.dark ||
        _themeVariant == PigioThemeVariant.oled;
    if (wantDark && !alreadyDark) {
      _themeVariant = PigioThemeVariant.dark;
      notifyListeners();
      _saveData();
    } else if (!wantDark && alreadyDark) {
      _themeVariant = PigioThemeVariant.light;
      notifyListeners();
      _saveData();
    }
  }

  void _pruneOrphanedIds() {
    final contactIdSet = _contacts.map((c) => c.id).toSet();
    bool changed = false;
    for (int i = 0; i < _groups.length; i++) {
      final pruned =
          _groups[i].contactIds.where(contactIdSet.contains).toList();
      if (pruned.length != _groups[i].contactIds.length) {
        _groups[i] = CircleGroup(
          id: _groups[i].id,
          name: _groups[i].name,
          emoji: _groups[i].emoji,
          contactIds: pruned,
          isSystem: _groups[i].isSystem,
          trustLevel: _groups[i].trustLevel,
          pendingInviteIds: _groups[i]
              .pendingInviteIds
              .where(contactIdSet.contains)
              .toList(),
        );
        changed = true;
      }
    }
    if (changed) _saveData();
  }

  List<Map<String, dynamic>> _decodeListFromString(String raw) {
    if (raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  /// Reads from secure storage with a 5-second timeout.
  /// On macOS the Keychain can hang waiting for a permission dialog that
  /// never surfaces in debug mode; the timeout lets _loadData() proceed.
  Future<String?> _secureRead(String key) async {
    try {
      return await _secureStorage
          .read(key: key)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  /// Best-effort secure write: on macOS debug without keychain entitlement,
  /// flutter_secure_storage can throw -34018. We log failures rather than
  /// silently swallowing them.
  Future<void> _secureWrite({required String key, required String value}) async {
    try {
      await _secureStorage
          .write(key: key, value: value)
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      // Log the failure so it's visible during development and in crash reports.
      if (kDebugMode) {
        debugPrint('[SecureStorage] WRITE FAILED key=$key error=$e');
      }
    }
  }
}
