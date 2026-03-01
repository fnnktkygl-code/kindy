import 'dart:async';
import 'dart:convert';
import 'dart:async' as async_lib show Timer;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../config/constants.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import '../models/app_models.dart';
import '../../features/invites/state/invite_commands.dart';
import '../../features/invites/state/invite_mappers.dart';
import '../../features/invites/state/invite_resolution.dart';
import '../../features/invites/state/invite_sync.dart';
import '../../features/notifications/state/notifications_coordinator.dart';
import '../../services/invitation_service.dart';
import '../../services/notification_service.dart';
import '../../services/fcm_service.dart';

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
  static const String _mascotChattinessKey     = 'pigio_mascot_chattiness';
  static const String _mascotScarfColorKey     = 'pigio_mascot_scarf_color';
  static const String _mascotCornerKey         = 'pigio_mascot_corner';
  static const String _mascotPrivacyKey        = 'pigio_mascot_privacy';
  static const String _surpriseModeKey         = 'pigio_surprise_mode';
  static const String _contactsConsentGivenKey = 'pigio_contacts_consent_given';
  static const String _activeOutfitKey         = 'pigio_active_outfit';
  static const String _unlockedClothingKey     = 'pigio_unlocked_clothing';
  static const String _syncKeyKey              = 'pigio_sync_key';
  static const String _onboardingCompletedKey  = 'pigio_onboarding_completed';
  static const String _personalityProfileKey   = 'pigio_personality_profile';
  static const String _wizzKey                 = 'pigio_wizz_history';
  static const String _wizzEffectModeKey       = 'pigio_wizz_effect_mode';
  static const String _notificationsKey        = 'pigio_notifications';
  static const String _giftPotsKey             = 'pigio_gift_pots';
  static const String _pollsKey               = 'pigio_polls';

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
  ClothingRequest? _currentClothingRequest;

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

  // Services
  final InvitationService _invitationService =
      InvitationService(baseApiUrl: _inviteApiBaseUrl);
  late final NotificationService _notificationService =
      NotificationService(baseApiUrl: _inviteApiBaseUrl);
  late final NotificationsCoordinator _notificationsCoordinator =
      NotificationsCoordinator(
        apiBaseUrl: _inviteApiBaseUrl,
        notificationService: _notificationService,
      );
  static const Uuid _uuid = Uuid();
  static const _secureStorage = FlutterSecureStorage();

  // Periodic sync timer
  async_lib.Timer? _syncTimer;

  // Mascot / UX flags
  bool         _mascotSilent         = false;
  int          _mascotChattiness     = 1;
  Color        _mascotScarfColor     = const Color(0xFFFFD54F);
  String       _mascotDefaultCorner  = 'left';
  bool         _mascotPrivacyMode    = false;
  bool         _surpriseMode         = true;
  bool         _contactsConsentGiven = false;
  MascotMoment _mascotMoment         = MascotMoment.none;
  bool         _busyMonthInsightShown = false;

  // Sync / onboarding
  String _syncKey            = '';
  bool   _syncEnabled        = false;
  bool   _onboardingCompleted = false;

  // Personality / Wizz
  Map<String, List<String>> _personalityProfile = {};
  Map<String, String>       _wizzHistory         = {};
  WizzEffectMode            _wizzEffectMode      = WizzEffectMode.phase1;

  // Ready signal for deep-link handling
  final Completer<void> _readyCompleter = Completer<void>();
  Future<void> get ready => _readyCompleter.future;

  // ── Constructor / Dispose ─────────────────────────────────────────────────
  PigioAppState() {
    _loadData();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
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

  List<Wish>              get wishes                  => _wishes;
  List<ContactProfile>    get contacts                => _contacts;
  List<CircleGroup>       get groups                  => _groups;
  List<Event>             get events                  => _events;
  List<SizeProfile>       get sizes                   => _sizes;
  List<GiftPot>           get giftPots                => _giftPots;
  List<GroupPoll>         get polls                   => _polls;
  UserProfile             get profile                 => _profile;
  List<ActivityLog>       get activityLogs            => _activityLogs;
  int                     get unseenLogsCount         => _unseenLogsCount;
  List<String>            get recentProfiles          => _recentProfiles;
  List<PendingInvite>     get pendingInvites          => _pendingInvites;
  String?                 get inviteFocusContactId    => _inviteFocusContactId;
  List<PigioNotification> get notifications           => _notifications;
  int                     get unseenNotificationsCount => _unseenNotificationsCount;

  bool         get mascotSilent          => _mascotSilent;
  int          get mascotChattiness      => _mascotChattiness;
  Color        get mascotScarfColor      => _mascotScarfColor;
  String       get mascotDefaultCorner   => _mascotDefaultCorner;
  bool         get mascotPrivacyMode     => _mascotPrivacyMode;
  bool         get surpriseMode          => _surpriseMode;
  bool         get contactsConsentGiven  => _contactsConsentGiven;
  MascotMoment get mascotMoment          => _mascotMoment;
  String       get syncKey               => _syncKey;
  bool         get syncEnabled           => _syncEnabled;
  bool         get onboardingCompleted   => _onboardingCompleted;
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
  Map<ClothingSlot, String?> get activeOutfit => _activeOutfit;
  List<String> get unlockedClothing => _unlockedClothing;
  ClothingRequest? get currentClothingRequest => _currentClothingRequest;

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _newId() => _uuid.v4();
  void _invalidateWishCache() => _wishCache = null;

  /// Instance-level accessor so extension part files can reference the API URL
  /// without needing to qualify the private static member.
  String get _apiBaseUrl => _inviteApiBaseUrl;

  // ── Persistence ───────────────────────────────────────────────────────────
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey,   _locale.languageCode);
    await prefs.setString(_themeKey,    _themeVariant.name);
    await prefs.setString(_wishesKey,    jsonEncode(_wishes.map((w) => w.toMap()).toList()));
    // PII — contacts, profile, invites stored encrypted in secure storage
    await _secureStorage.write(key: _contactsKey,  value: jsonEncode(_contacts.map((m) => m.toMap()).toList()));
    await prefs.setString(_groupsKey,    jsonEncode(_groups.map((g) => g.toMap()).toList()));
    await prefs.setString(_eventsKey,    jsonEncode(_events.map((e) => e.toMap()).toList()));
    await prefs.setString(_sizesKey,     jsonEncode(_sizes.map((s) => s.toMap()).toList()));
    await prefs.setString(_giftPotsKey,  jsonEncode(_giftPots.map((p) => p.toMap()).toList()));
    await prefs.setString(_pollsKey,    jsonEncode(_polls.map((p) => p.toMap()).toList()));
    await _secureStorage.write(key: _profileKey, value: jsonEncode(_profile.toMap()));
    await prefs.setInt(_unseenLogsKey,   _unseenLogsCount);
    await _secureStorage.write(key: _activityLogsKey, value: jsonEncode(_activityLogs.map((a) => a.toMap()).toList()));
    await prefs.setStringList(_recentProfilesKey, _recentProfiles);
    await _secureStorage.write(key: _pendingInvitesKey, value: jsonEncode(_pendingInvites.map((i) => i.toMap()).toList()));
    // Notifications — stored in secure storage to protect message content
    await _secureStorage.write(key: _notificationsKey, value: jsonEncode(_notifications.map((n) => n.toMap()).toList()));
    await prefs.setInt('pigio_unseen_notifications', _unseenNotificationsCount);
    // Mascot
    await prefs.setBool(_mascotSilentKey,        _mascotSilent);
    await prefs.setInt(_mascotChattinessKey,     _mascotChattiness);
    await prefs.setInt(_mascotScarfColorKey,     _mascotScarfColor.toARGB32());
    await prefs.setBool(_mascotPrivacyKey,       _mascotPrivacyMode);
    await prefs.setBool(_surpriseModeKey,        _surpriseMode);
    await prefs.setBool(_contactsConsentGivenKey, _contactsConsentGiven);
    // Outfit
    final outfitMap = _activeOutfit.map((k, v) => MapEntry(k.name, v));
    await prefs.setString(_activeOutfitKey,      jsonEncode(outfitMap));
    await prefs.setStringList(_unlockedClothingKey, _unlockedClothing);
    // Sync / onboarding — sync key stored in secure storage (not SharedPreferences)
    if (_syncKey.isNotEmpty) {
      await _secureStorage.write(key: _syncKeyKey, value: _syncKey);
    }
    await prefs.setBool('pigio_sync_enabled', _syncEnabled);
    await prefs.setBool(_onboardingCompletedKey, _onboardingCompleted);
    // Personality
    if (_personalityProfile.isNotEmpty) {
      await prefs.setString(_personalityProfileKey, jsonEncode(_personalityProfile));
    }
    // Wizz
    if (_wizzHistory.isNotEmpty) {
      await prefs.setString(_wizzKey, jsonEncode(_wizzHistory));
    }
    await prefs.setString(_wizzEffectModeKey, _wizzEffectMode.name);
    // Cloud push (fire-and-forget)
    if (_syncEnabled && _syncKey.isNotEmpty) {
      Future.microtask(() => _pushToCloud());
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Fetch all secure storage values in parallel — avoids up to 30s of
    // sequential reads (6 keys × 5s timeout each).
    final secureValues = await Future.wait([
      _secureRead(_contactsKey),        // [0]
      _secureRead(_profileKey),          // [1]
      _secureRead(_activityLogsKey),     // [2]
      _secureRead(_pendingInvitesKey),   // [3]
      _secureRead(_notificationsKey),    // [4]
      _secureRead(_syncKeyKey),          // [5]
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
      } catch (_) {}
    }

    _unlockedClothing = prefs.getStringList(_unlockedClothingKey) ?? [];

    _wishes  ..clear()..addAll(_decodeList(_wishesKey,   prefs).map(Wish.fromMap));
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
        await _secureStorage.write(key: _contactsKey, value: legacyContacts);
        await prefs.remove(_contactsKey);
      }
    }
    _groups  ..clear()..addAll(_decodeList(_groupsKey,   prefs).map(CircleGroup.fromMap));

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

    _events  ..clear()..addAll(_decodeList(_eventsKey, prefs).map(Event.fromMap));
    _sizes   ..clear()..addAll(_decodeList(_sizesKey,  prefs).map(SizeProfile.fromMap));
    _giftPots..clear()..addAll(_decodeList(_giftPotsKey, prefs).map(GiftPot.fromMap));
    _polls   ..clear()..addAll(_decodeList(_pollsKey, prefs).map(GroupPoll.fromMap));

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
          await _secureStorage.write(key: _profileKey, value: profileRaw);
          await prefs.remove(_profileKey);
        }
      } catch (_) {}
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
        await _secureStorage.write(key: _activityLogsKey, value: legacyLogs);
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
        await _secureStorage.write(key: _pendingInvitesKey, value: legacyInvites);
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
        await _secureStorage.write(key: _notificationsKey, value: legacyNotifs);
        await prefs.remove(_notificationsKey);
      }
    }
    _unseenNotificationsCount =
        prefs.getInt('pigio_unseen_notifications') ?? 0;

    // Mascot
    _mascotSilent       = prefs.getBool(_mascotSilentKey) ?? false;
    _mascotChattiness   = prefs.getInt(_mascotChattinessKey) ?? 1;
    final scarfVal = prefs.getInt(_mascotScarfColorKey);
    if (scarfVal != null) _mascotScarfColor = Color(scarfVal);
    _mascotDefaultCorner = prefs.getString(_mascotCornerKey) ?? 'left';
    _mascotPrivacyMode  = prefs.getBool(_mascotPrivacyKey) ?? false;
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
        await _secureStorage.write(key: _syncKeyKey, value: legacySyncKey);
        await prefs.remove(_syncKeyKey);
      }
    }
    _syncEnabled       = prefs.getBool('pigio_sync_enabled') ?? false;
    _onboardingCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;

    // Personality profile
    final personalityRaw = prefs.getString(_personalityProfileKey);
    if (personalityRaw != null && personalityRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(personalityRaw);
        if (decoded is Map<String, dynamic>) {
          _personalityProfile = decoded.map(
              (k, v) => MapEntry(k, v is List ? v.cast<String>() : <String>[]));  
        }
      } catch (_) {}
    }

    // Wizz history
    final wizzRaw = prefs.getString(_wizzKey);
    if (wizzRaw != null && wizzRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(wizzRaw);
        if (decoded is Map<String, dynamic>) {
          _wizzHistory = decoded.cast<String, String>();
        }
      } catch (_) {}
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

    _syncTimer?.cancel();
    _syncTimer = async_lib.Timer.periodic(const Duration(seconds: 30), (_) {
      _syncPendingInvitesFromServer();
      _pullContactProfiles();
      _pushOwnContactProfile();
      _pullNotifications();
    });
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

  List<Map<String, dynamic>> _decodeList(
      String key, SharedPreferences prefs) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
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
}
