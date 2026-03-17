import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'pigio_painter.dart';
import 'ui_widgets.dart';
import 'package:pigio_app/screens/mascot/mascot_settings_screen.dart';
import 'package:pigio_app/screens/mascot/mascot_wardrobe_screen.dart';
import 'package:pigio_app/screens/mascot/know_thyself_screen.dart';
import 'package:pigio_app/screens/wishes/sheets/wish_editor_sheet.dart';
import 'package:pigio_app/shared/widgets/invite_bottom_sheet.dart';
import '../../services/ai_service.dart';
import '../../services/mascot_insight_engine.dart';
import '../../services/mascot_outfit_engine.dart';
import '../../services/mascot_sound_service.dart';
import '../../services/weather_service.dart';

// ─── ERROR BOUNDARY ─────────────────────────────────────────────────────────
/// Wraps the mascot in an error boundary so a crash in the mascot engine
/// never takes down the host screen (tab bar, navigation, child screens).
class SafeDraggableMascot extends StatefulWidget {
  final int tabIndex;
  const SafeDraggableMascot({super.key, this.tabIndex = 0});

  @override
  State<SafeDraggableMascot> createState() => _SafeDraggableMascotState();
}

class _SafeDraggableMascotState extends State<SafeDraggableMascot> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) return const SizedBox.shrink();

    return _MascotErrorCatcher(
      onError: () {
        if (mounted) setState(() => _hasError = true);
      },
      child: DraggableMascot(tabIndex: widget.tabIndex),
    );
  }
}

class _MascotErrorCatcher extends StatefulWidget {
  final Widget child;
  final VoidCallback onError;
  const _MascotErrorCatcher({required this.child, required this.onError});

  @override
  State<_MascotErrorCatcher> createState() => _MascotErrorCatcherState();
}

class _MascotErrorCatcherState extends State<_MascotErrorCatcher> {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Attach a Flutter error handler scoped to this widget subtree
    FlutterError.onError = (FlutterErrorDetails details) {
      // Only catch errors from the mascot painter / overlay
      final isOurs = details.library == 'rendering library' ||
          details.stack.toString().contains('mascot_overlay') ||
          details.stack.toString().contains('pigio_painter');
      if (isOurs) {
        debugPrint('Mascot error caught: ${details.exception}');
        widget.onError();
      } else {
        FlutterError.presentError(details);
      }
    };
  }

  @override
  void dispose() {
    FlutterError.onError = FlutterError.presentError;
    super.dispose();
  }
}

// ─── DRAGGABLE MASCOT ────────────────────────────────────────────────────────
class DraggableMascot extends StatefulWidget {
  final int tabIndex;
  const DraggableMascot({super.key, this.tabIndex = 0});

  @override
  State<DraggableMascot> createState() => _DraggableMascotState();
}

class _DraggableMascotState extends State<DraggableMascot> with TickerProviderStateMixin, WidgetsBindingObserver {
  double left = 14;
  double bottom = 90;
  bool _seededPosition = false;
  bool _reducedMotion = false;

  bool hidden = false;
  bool bubble = false;
  bool menu = false;
  bool isDragging = false;

  String? _dynamicMsg;
  bool _isGeneratingDynamic = false;
  DateTime? _lastBubbleTime;
  bool _dailyBonusClaimed = false;
  Timer? _dynamicMsgClearTimer;  // P0-3: auto-clear stale dynamic messages

  // ── Emotion continuity: mood decays over 10s instead of resetting on tab change ──
  PigMood? _moodStackMood;
  DateTime? _moodStackExpiry;

  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;
  late AnimationController _wiggleCtrl;
  late Animation<double> _wiggleAnim;
  late AnimationController _sleepCtrl;
  late Animation<double> _sleepFade;
  late Animation<double> _sleepFloat;
  late AnimationController _burstCtrl;
  late AnimationController _breathCtrl;
  late Animation<double> _breathAnim;
  late AnimationController _squashCtrl;
  late Animation<double> _squashX;
  late Animation<double> _squashY;

  late AnimationController _weatherCtrl;

  int _tapCount = 0;
  DateTime? _lastTapTime;
  PigMood? _tempMoodOverride;
  Offset? _dragGlobalPos; // For real finger-following eyes

  // Easter eggs
  int _dragFlipCount = 0;
  double _lastDragDx = 0;
  bool _isDizzy = false;
  late AnimationController _spinCtrl;
  late Animation<double> _spinAnim;

  final MascotSoundService _sound = MascotSoundService.instance;
  static final _rng = math.Random();

  bool _isIdle = false;
  Timer? _idleTimer;

  // Accelerometer tilt physics
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _tiltX = 0; // phone tilt on X axis (left-right)
  // _tiltY intentionally not stored — Y-axis disabled (constant gravity offset).
  Timer? _tiltTimer;

  MascotInsight? _cachedInsight;
  int? _cachedTabIndex;
  String? _cachedInsightSignature;
  DateTime? _cachedInsightAt;
  String? _lastWeatherReactionSignature;
  String? _lastExecutedInsightSignature;  // P1-8: dedup gate for insight side-effects
  late Listenable _mergedAnimations;  // Pre-computed merged listenable
  
  int _lastWizzNonce = 0;

  void _openMascotMenu() {
    _resetIdleTimer();
    setState(() {
      bubble = false;
      menu = true;
    });
    _triggerWiggle();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = Provider.of<PigioAppState>(context);
    _sound.setEnabled(state.mascotSoundEnabled);

    if (!_seededPosition) {
      _seededPosition = true;
      final width = MediaQuery.of(context).size.width;
        left = state.mascotDefaultCorner == 'right'
          ? ((width - 94).clamp(0.0, width)).toDouble()
          : 14;
    }

    if (_reducedMotion != state.mascotReducedMotion) {
      _reducedMotion = state.mascotReducedMotion;
      if (_reducedMotion || !state.mascotVisible) {
        _pauseAnimations();
      } else if (!hidden) {
        _resumeAnimations();
      }
    }

    if (!state.mascotVisible) {
      _pauseAnimations();
    } else if (!_reducedMotion && !hidden) {
      _resumeAnimations();
    }

    // P1-6: Weather sync moved from build() to didChangeDependencies()
    _syncWeatherReaction(state);

    // P2-12: Only tick _weatherCtrl when weather effects are actually needed
    final weather = state.weatherEffectsEnabled ? state.currentWeather : null;
    final needsWeatherAnim = !_reducedMotion && weather != null &&
        (weather.condition == 'rain' || weather.condition == 'snow' ||
         weather.temperature > 28 || weather.condition == 'storm');
    if (needsWeatherAnim && !_weatherCtrl.isAnimating) {
      _weatherCtrl.repeat();
    } else if (!needsWeatherAnim && _weatherCtrl.isAnimating) {
      _weatherCtrl.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 0.0).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    _wiggleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _wiggleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.15), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.15), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.15, end: -0.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.1), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 0.0), weight: 20),
    ]).animate(_wiggleCtrl);

    _sleepCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _sleepFade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_sleepCtrl);
    _sleepFloat = Tween<double>(begin: 0, end: -30).animate(CurvedAnimation(parent: _sleepCtrl, curve: Curves.easeOut));

    _burstCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    // Breathing — subtle scale pulse
    _breathCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 1.0, end: 1.02).animate(CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));

    // Squash-stretch on tap
    _squashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _squashX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.92), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.04), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _squashCtrl, curve: Curves.easeOut));
    _squashY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.88), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.1), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 0.96), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.96, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _squashCtrl, curve: Curves.easeOut));

    // P2-12: Don't auto-start — only tick when weather effects are active
    _weatherCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));

    _resetIdleTimer();
    _sound.init();

    // Pre-compute merged listenable once instead of creating it every build
    _mergedAnimations = Listenable.merge([_floatAnim, _wiggleAnim, _breathAnim, _squashCtrl]);

    // Dizzy spin for easter egg
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _spinAnim = Tween<double>(begin: 0.0, end: 2 * 3.14159).animate(CurvedAnimation(parent: _spinCtrl, curve: Curves.easeOut));

    // Accelerometer tilt physics — Pigio slides with gravity (P2: extracted)
    _startAccelerometer();

    Future.delayed(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      final state = Provider.of<PigioAppState>(context, listen: false);
      // Rate-limit outfit suggestions: skip if dismissed < 30 min ago
      if (!state.isOutfitRequestCoolingDown) {
        final outfitReq = await MascotOutfitEngine.evaluateContext(state);
        if (mounted && outfitReq != null) state.setClothingRequest(outfitReq);
      }

      // Daily bond XP bonus (E6) — show feedback when claimed
      if (!_dailyBonusClaimed) {
        _dailyBonusClaimed = state.claimDailyBondBonus();
        if (_dailyBonusClaimed) {
          HapticFeedback.mediumImpact();
          final isFr = state.locale.languageCode == 'fr';
          final bonusFr = [
            '🌟 +10 XP (${state.mascotBondEmoji} ${state.mascotBondTitle})',
            '💛 +10 XP ! (${state.mascotBondEmoji} ${state.mascotBondTitle})',
            '✨ +10 XP pour toi (${state.mascotBondEmoji} ${state.mascotBondTitle})',
          ];
          final bonusEn = [
            '🌟 +10 XP (${state.mascotBondEmoji} ${state.mascotBondTitle})',
            '💛 +10 XP! (${state.mascotBondEmoji} ${state.mascotBondTitle})',
            '✨ +10 XP for you (${state.mascotBondEmoji} ${state.mascotBondTitle})',
          ];
          final idx = _rng.nextInt(bonusFr.length);
          _dynamicMsg = isFr ? bonusFr[idx] : bonusEn[idx];
        }
      }

      // Check birthday-proximity and re-engagement pushes (once per session)
      state.checkBirthdayProximityPush();
      state.checkReengagementPush();

      _triggerWiggle();
      _lastBubbleTime = DateTime.now();
      setState(() => bubble = true);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => bubble = false);
      });
    });
  }

  @override
  void didUpdateWidget(DraggableMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resetIdleTimer();
    if (oldWidget.tabIndex != widget.tabIndex && !hidden) {
      setState(() {
        bubble = false;
        _dynamicMsg = null;
        _cachedInsight = null;
        _cachedTabIndex = null;
      });
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _triggerWiggle();
          final state = Provider.of<PigioAppState>(context, listen: false);
          if (_shouldShowBubble(state)) {
            setState(() => bubble = true);
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) setState(() => bubble = false);
            });
          }
        }
      });
    }
  }

  void _triggerWiggle() {
    if (_reducedMotion) return;
    _wiggleCtrl.forward(from: 0.0);
  }

  String _privacyMessage(PigioAppState state, MascotInsight insight) {
    if (!state.mascotPrivacyMode) {
      return _dynamicMsg ?? (state.locale.languageCode == 'fr' ? insight.fr : insight.en);
    }
    if (_isGeneratingDynamic && _dynamicMsg == null) return '…';
    final clothingEmoji = state.currentClothingRequest?.item.emoji;
    if (clothingEmoji != null) return '$clothingEmoji ✨';
    switch (_activeMoodOverride ?? insight.mood) {
      case PigMood.celebrating:
        return '🎉✨';
      case PigMood.excited:
        return '👀✨';
      case PigMood.thinking:
      case PigMood.searching:
        return '🤔💡';
      case PigMood.thumbsUp:
        return '👍✨';
      case PigMood.love:
        return '💛✨';
      case PigMood.sad:
        return '🥺';
      case PigMood.sleeping:
        return '💤';
      case PigMood.waving:
        return '👋';
      default:
        return '✨';
    }
  }

  bool _shouldShowBubble(PigioAppState state) {
    if (state.mascotSilent) return false;
    final now = DateTime.now();
    final cooldownSec = [8, 4, 2][state.mascotChattiness.clamp(0, 2)];
    if (_lastBubbleTime != null && now.difference(_lastBubbleTime!).inSeconds < cooldownSec) return false;
    _lastBubbleTime = now;
    return true;
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    if (_isIdle && mounted) {
      // Wake-up greeting when coming out of idle
      final isFr = Provider.of<PigioAppState>(context, listen: false).locale.languageCode == 'fr';
      final wakeFr = const ['*bâille* 🥱 Oh, te revoilà !', 'Zzz... hein ? 😴 Ah c\'est toi !', 'Je dormais pas ! 😤 ...bon peut-être un peu.', '*s\'étire* 🐧 Re-coucou !'];
      final wakeEn = const ['*yawns* 🥱 Oh, you\'re back!', 'Zzz... huh? 😴 Oh it\'s you!', 'I wasn\'t sleeping! 😤 ...ok maybe a little.', '*stretches* 🐧 Hey again!'];
      final idx = _rng.nextInt(wakeFr.length);
      setState(() {
        _isIdle = false;
        _dynamicMsg = isFr ? wakeFr[idx] : wakeEn[idx];
        _cachedInsight = null;
        _cachedTabIndex = null;
        bubble = true;
      });
      _sleepCtrl.reset();
      _pushMood(PigMood.waving, duration: const Duration(seconds: 3));
      _dynamicMsgClearTimer?.cancel();
      _dynamicMsgClearTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() { _dynamicMsg = null; bubble = false; });
      });
    }
    _idleTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && !hidden && !bubble && !menu) {
        setState(() => _isIdle = true);
        _sleepCtrl.repeat();
      }
    });
  }

  /// Apply accelerometer tilt as a gravity-like force on Pigio's position.
  void _applyTilt(Timer _) {
    if (!mounted || isDragging || hidden) return;
    // Dead zone: ignore very small tilts (phone resting flat)
    final dx = _tiltX.abs() > 0.5 ? _tiltX * 1.2 : 0.0;
    if (dx == 0) return;

    final size = MediaQuery.of(context).size;
    final newLeft = (left - dx).clamp(0.0, size.width - 80);
    // P1-5: Skip setState if position didn't actually change (< 0.5px)
    if ((newLeft - left).abs() < 0.5) return;

    setState(() {
      left = newLeft;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    _dynamicMsgClearTimer?.cancel();
    _accelSub?.cancel();
    _tiltTimer?.cancel();
    _floatCtrl.dispose();
    _wiggleCtrl.dispose();
    _sleepCtrl.dispose();
    _burstCtrl.dispose();
    _breathCtrl.dispose();
    _squashCtrl.dispose();
    _spinCtrl.dispose();
    _weatherCtrl.dispose();
    super.dispose();
  }

  // ── P1: Pause/resume animations on app lifecycle ─────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseAnimations();
    } else if (state == AppLifecycleState.resumed) {
      _resumeAnimations();
    }
  }

  void _pauseAnimations() {
    _floatCtrl.stop();
    _breathCtrl.stop();
    _weatherCtrl.stop();
    if (_isIdle) _sleepCtrl.stop();
    _stopAccelerometer();
  }

  void _resumeAnimations() {
    if (!hidden && !_reducedMotion) {
      _floatCtrl.repeat(reverse: true);
      _breathCtrl.repeat(reverse: true);
      _weatherCtrl.repeat();
      if (_isIdle) _sleepCtrl.repeat();
      _startAccelerometer();
    }
  }

  // ── P2: Start/stop accelerometer when hidden/shown ───────────────────────
  void _startAccelerometer() {
    if (_reducedMotion) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      _tiltX = 0;
      _tiltTimer?.cancel();
      _tiltTimer = null;
      _accelSub?.cancel();
      _accelSub = null;
      return;
    }
    _accelSub?.cancel();
    try {
      _accelSub = accelerometerEventStream(samplingPeriod: const Duration(milliseconds: 150)).listen((AccelerometerEvent event) {
        _tiltX = event.x;
      });
    } catch (_) {
      // Accelerometer unavailable (simulator / desktop) — fall back to zero tilt.
      _accelSub = null;
    }
    _tiltTimer?.cancel();
    // P1-5: Reduced from 50ms to 150ms to save battery
    _tiltTimer = Timer.periodic(const Duration(milliseconds: 150), _applyTilt);
  }

  void _stopAccelerometer() {
    _accelSub?.cancel();
    _accelSub = null;
    _tiltTimer?.cancel();
    _tiltTimer = null;
  }

  // ── Q15: Mood stack — push a temporary mood that decays over time ────────
  void _pushMood(PigMood mood, {Duration duration = const Duration(seconds: 10)}) {
    _moodStackMood = mood;
    _moodStackExpiry = DateTime.now().add(duration);
  }

  /// Pure getter — no side-effects during build. Expired mood fields are
  /// simply ignored and overwritten by the next [_pushMood] call.
  PigMood? get _activeMoodOverride {
    if (_tempMoodOverride != null) return _tempMoodOverride;
    if (_moodStackMood != null &&
        _moodStackExpiry != null &&
        DateTime.now().isBefore(_moodStackExpiry!)) {
      return _moodStackMood;
    }
    return null;
  }

  void _triggerAI(Future<String?> Function(PigioAppState) task, PigioAppState state) {
    if (_isGeneratingDynamic || _dynamicMsg != null) return;
    Future.microtask(() async {
      if (!mounted) return;

      // Gate: check remaining free concierge credits
      final remaining = await AiService.remainingFreeConcierge();
      if (remaining <= 0) {
        if (!mounted) return;
        final isFr = state.locale.languageCode == 'fr';
        setState(() {
          _dynamicMsg = isFr
              ? "J'ai plein d'idées cadeaux pour toi ! 🎁✨ Passe en Premium pour des suggestions illimitées."
              : "I have tons of gift ideas for you! 🎁✨ Go Premium for unlimited suggestions.";
          _isGeneratingDynamic = false;
        });
        _dynamicMsgClearTimer?.cancel();
        _dynamicMsgClearTimer = Timer(const Duration(seconds: 60), () {
          if (mounted) setState(() => _dynamicMsg = null);
        });
        return;
      }

      setState(() => _isGeneratingDynamic = true);
      final raw = await task(state);
      if (mounted) {
        setState(() {
          _dynamicMsg = raw != null ? _firstSentence(raw) : null;
          _isGeneratingDynamic = false;
        });
        // P0-3: Auto-clear dynamic message after 60s to prevent blocking future AI triggers
        _dynamicMsgClearTimer?.cancel();
        if (_dynamicMsg != null) {
          _dynamicMsgClearTimer = Timer(const Duration(seconds: 60), () {
            if (mounted) setState(() => _dynamicMsg = null);
          });
        }
      }
    });
  }

  String _firstSentence(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'\*+'), '').replaceAll(RegExp(r'#+\s*'), '').replaceAll(RegExp(r'- '), '').trim();
    final match = RegExp(r'^(.{10,90}?[.!?🎁🎂🎉🎄💡📅📏👀✨💛])').firstMatch(cleaned);
    if (match != null) return match.group(1)!.trim();
    // P2-10: Use Characters for emoji-safe truncation to avoid splitting multi-byte chars
    final chars = cleaned.characters;
    return chars.length > 90 ? '${chars.take(88)}…' : cleaned;
  }

  // Weather pose/exposure/mood delegated to MascotOutfitEngine (single source of truth).

  void _syncWeatherReaction(PigioAppState state) {
    if (!state.weatherEffectsEnabled) return;
    final weather = state.currentWeather;
    final signature = [
      weather?.condition ?? 'none',
      weather?.temperature.round() ?? 0,
      weather?.isDay ?? false,
      state.activeOutfit[ClothingSlot.hat] ?? '-',
      state.activeOutfit[ClothingSlot.glasses] ?? '-',
      state.activeOutfit[ClothingSlot.top] ?? '-',
      state.activeOutfit[ClothingSlot.shoes] ?? '-',
      state.activeOutfit[ClothingSlot.accessory] ?? '-',
    ].join('|');

    if (_lastWeatherReactionSignature == signature) return;
    _lastWeatherReactionSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || state.isOutfitRequestCoolingDown) return;
      final nextRequest = await MascotOutfitEngine.evaluateContext(state);
      if (!mounted) return;
      final currentId = state.currentClothingRequest?.item.id;
      final nextId = nextRequest?.item.id;
      if (currentId != nextId) {
        state.setClothingRequest(nextRequest);
        if (nextRequest != null && _shouldShowBubble(state)) {
          setState(() {
            _dynamicMsg = null;
            bubble = true;
          });
        }
      }
    });
  }

  Future<void> _runInsightAction(
    MascotInsight insight,
    PigioAppState state,
  ) async {
    insight.action?.call(state);
    switch (insight.actionKey) {
      case 'open_wish_editor':
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: context.pt.sheet,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          builder: (_) => WishEditorSheet(contactId: null, state: state),
        );
        break;
      case 'open_invite_sheet':
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const InviteBottomSheet(),
        );
        break;
      case 'open_quiz':
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const KnowThyselfScreen()),
          );
        }
        break;
    }
  }

  MascotInsight _getInsight(PigioAppState state) {
    final signature = [
      widget.tabIndex,
      state.contacts.length,
      state.wishes.length,
      state.sizes.length,
      state.mascotMoment.name,
      state.currentClothingRequest == null ? 'no-outfit-req' : 'has-outfit-req',
    ].join('|');

    final isFresh = _cachedInsightAt != null &&
        DateTime.now().difference(_cachedInsightAt!).inSeconds < 20;

    if (_cachedInsight != null &&
        _cachedTabIndex == widget.tabIndex &&
        _cachedInsightSignature == signature &&
        isFresh) {
      return _cachedInsight!;
    }

    final insight = MascotInsightEngine.pick(state, widget.tabIndex);
    // Q12: Defer side-effects to post-frame to avoid notifyListeners during build.
    // P1-8: Only fire side-effects once per unique insight signature.
    if ((insight.postAction != null || insight.aiTask != null) &&
        _lastExecutedInsightSignature != signature) {
      _lastExecutedInsightSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        insight.postAction?.call();
        if (insight.aiTask != null) {
          _triggerAI(insight.aiTask!, state);
        }
      });
    }
    _cachedInsight = insight;
    _cachedTabIndex = widget.tabIndex;
    _cachedInsightSignature = signature;
    _cachedInsightAt = DateTime.now();
    return insight;
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PigioAppState>(context);
    if (!state.mascotVisible) return const SizedBox.shrink();
    if (hidden) return _buildMiniRestorer();

    final insight = _getInsight(state);
    final lang = state.locale.languageCode;
    final actionLabel = lang == 'fr' ? insight.actionLabelFr : insight.actionLabelEn;
    // P1-6: _syncWeatherReaction moved to didChangeDependencies()

    // --- WIZZ REACTION LOGIC ---
    if (_lastWizzNonce != state.globalWizzNonce) {
      _lastWizzNonce = state.globalWizzNonce;
      // Trigger dizzy effect when a Wizz is received!
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _sound.playWhoosh();
        _spinCtrl.forward(from: 0.0);
        _pushMood(PigMood.dizzy, duration: const Duration(seconds: 3));
        final isFr = state.locale.languageCode == 'fr';
        final wizzFr = const ['Whoaaaa ! 🌀 Ça tourne !', 'WIZZZZ ! 😵‍💫 Qui a fait ça ?!', 'Aïe aïe aïe ! 🌪️ Ma tête !', 'Hé oh ! 😵 Doucement !'];
        final wizzEn = const ['Whoaaaa! 🌀 Everything\'s spinning!', 'WIZZZZ! 😵‍💫 Who did that?!', 'Ow ow ow! 🌪️ My head!', 'Hey! 😵 Easy there!'];
        final idx = _rng.nextInt(wizzFr.length);
        setState(() {
          _dynamicMsg = isFr ? wizzFr[idx] : wizzEn[idx];
          _cachedInsight = null;
          _cachedTabIndex = null;
          bubble = true;
        });
        _dynamicMsgClearTimer?.cancel();
        _dynamicMsgClearTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() { _dynamicMsg = null; bubble = false; });
        });
      });
    }

    final msg = _privacyMessage(state, insight);

    final size = MediaQuery.of(context).size;
    
    final rawWeather = state.currentWeather;
    // When weather effects are off, suppress visual weather (but keep data for weather lab)
    final weather = state.weatherEffectsEnabled ? rawWeather : null;
    final protection = MascotOutfitEngine.weatherProtectionFor(state.activeOutfit);
    final hasUmbrella = protection.hasUmbrella;
    final hasRainProtection = protection.rainCoverage >= 0.72;
    final hasSnowProtection = protection.snowCoverage >= 0.65;
    final hasSunProtection = protection.sunCoverage >= 0.6;
    final weatherPose = MascotOutfitEngine.weatherPoseFor(weather, protection);
    final weatherExposure = MascotOutfitEngine.weatherExposureFor(weather, protection);
    final mascotCenter = Offset(left + 40, size.height - bottom - 52);

    PigMood computedMood = _isIdle ? PigMood.sleeping : (bubble ? insight.mood : PigMood.normal);
    if (!_isIdle && !bubble && _activeMoodOverride == null && weather != null) {
      final weatherMood = MascotOutfitEngine.weatherMoodFor(weather, protection);
      if (weatherMood != null) computedMood = weatherMood;
    }
    final effectiveMood = _activeMoodOverride ?? computedMood;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (!_reducedMotion && weather != null && (weather.condition == 'rain' || weather.condition == 'snow' || weather.temperature > 28 || weather.condition == 'storm'))
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _weatherCtrl,
                    builder: (context, child) => CustomPaint(
                      painter: WeatherPainter(
                        weather: weather,
                        animationValue: _weatherCtrl.value,
                        mascotCenter: mascotCenter,
                        hasUmbrella: hasUmbrella,
                        hasRainProtection: hasRainProtection,
                        hasSnowProtection: hasSnowProtection,
                        hasSunProtection: hasSunProtection,
                        rainCoverage: weather.condition == 'storm' ? protection.stormCoverage : protection.rainCoverage,
                        snowCoverage: protection.snowCoverage,
                        sunCoverage: protection.sunCoverage,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (bubble && !isDragging && msg.isNotEmpty)
          Positioned(
            bottom: bottom + 100,
            left: left < size.width / 2 ? left : null,
            right: left >= size.width / 2 ? (size.width - left - 80) : null,
            child: SpeechBubble(
              msg: msg,
              isLoading: _isGeneratingDynamic && _dynamicMsg == null,
              side: left < size.width / 2 ? "left" : "right",
              onClose: () {
                // Q14: If closing bubble with active outfit request, record cooldown
                if (state.currentClothingRequest != null) {
                  state.dismissOutfitRequest();
                }
                setState(() => bubble = false);
              },
              onQuickEquip: state.currentClothingRequest != null ? () {
                HapticFeedback.mediumImpact();
                final req = state.currentClothingRequest!;
                state.equipClothing(req.item.slot, req.item.id);
                state.setClothingRequest(null);
                _triggerWiggle();
                setState(() => bubble = false);
              } : null,
              quickEquipLabel: state.currentClothingRequest != null
                  ? (lang == 'fr' ? 'Essayer ${state.currentClothingRequest!.item.emoji}' : 'Try ${state.currentClothingRequest!.item.emoji}')
                  : null,
              onAction: state.currentClothingRequest == null && (insight.action != null || insight.actionKey != null) ? () {
                HapticFeedback.selectionClick();
                setState(() => bubble = false);
                _runInsightAction(insight, state);
              } : null,
              actionLabel: state.currentClothingRequest == null ? actionLabel : null,
            ),
          ),
        if (menu && !isDragging)
          Positioned(
            bottom: bottom + 100,
            left: left < size.width / 2 ? left : null,
            right: left >= size.width / 2 ? (size.width - left - 80) : null,
            child: _buildMenu(context),
          ),
        AnimatedPositioned(
          duration: isDragging ? Duration.zero : Duration(milliseconds: _reducedMotion ? 180 : 700),
          curve: isDragging ? Curves.linear : (_reducedMotion ? Curves.easeOut : Curves.elasticOut),
          left: left,
          bottom: bottom,
          child: GestureDetector(
            onPanStart: (d) {
              _resetIdleTimer();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() { isDragging = true; bubble = false; menu = false; });
              });
            },
            onPanUpdate: (d) {
              _resetIdleTimer();
              _dragGlobalPos = d.globalPosition;
              // Easter egg: detect rapid direction flips
              if (d.delta.dx != 0 && (_lastDragDx * d.delta.dx < 0)) {
                _dragFlipCount++;
                if (_dragFlipCount >= 5 && !_isDizzy) {
                  _isDizzy = true;
                  if (!_reducedMotion) _spinCtrl.forward(from: 0.0);
                  _sound.playGiggle();
                  HapticFeedback.heavyImpact();
                  _pushMood(PigMood.embarrassed, duration: const Duration(seconds: 3));
                  final isFr = Provider.of<PigioAppState>(context, listen: false).locale.languageCode == 'fr';
                  final dizzyFr = const ['Wooooh... 🌀 La tête me tourne !', 'Doucement ! 😵 Je suis un pingouin, pas une toupie !', 'Ça tourne trop vite ! 🫨 Repose-moi !', 'Hé ! 😵‍💫 Tu veux me transformer en hélicoptère ?'];
                  final dizzyEn = const ['Wooooh... 🌀 My head is spinning!', 'Easy! 😵 I\'m a penguin, not a spinning top!', 'Too fast! 🫨 Put me down!', 'Hey! 😵‍💫 Trying to turn me into a helicopter?'];
                  setState(() {
                    _dynamicMsg = isFr ? dizzyFr[_rng.nextInt(dizzyFr.length)] : dizzyEn[_rng.nextInt(dizzyEn.length)];
                    _cachedInsight = null;
                    _cachedTabIndex = null;
                    bubble = true;
                  });
                  _dynamicMsgClearTimer?.cancel();
                  _dynamicMsgClearTimer = Timer(const Duration(seconds: 3), () {
                    if (mounted) setState(() { _dynamicMsg = null; bubble = false; _isDizzy = false; });
                  });
                  _dragFlipCount = 0;
                }
              }
              _lastDragDx = d.delta.dx;
              setState(() {
                left = (left + d.delta.dx).clamp(0.0, size.width - 80);
                bottom = (bottom - d.delta.dy).clamp(76.0, size.height - 200);
              });
            },
            onPanEnd: (d) {
              _triggerWiggle();
              _burstCtrl.forward(from: 0.0);
              _resetIdleTimer();
              _dragGlobalPos = null;
              _dragFlipCount = 0;
              _lastDragDx = 0;
              _sound.playWhoosh();
              HapticFeedback.mediumImpact();
              // Apply momentum: coast a bit with velocity before stopping naturally
              final vx = d.velocity.pixelsPerSecond.dx;
              final momentumX = (vx * 0.08).clamp(-80.0, 80.0);
              final projected = left + momentumX;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  isDragging = false;
                  left = projected.clamp(0.0, size.width - 80);
                });
              });
            },
            onTap: () {
              _resetIdleTimer();
              // Squash-stretch on every tap
              _squashCtrl.forward(from: 0.0);
              _sound.playTap();
              HapticFeedback.lightImpact();
              // Rapid tap detection — 3 taps in 2s = tickle
              final now = DateTime.now();
              if (_lastTapTime != null && now.difference(_lastTapTime!).inMilliseconds < 2000) {
                _tapCount++;
              } else {
                _tapCount = 1;
              }
              _lastTapTime = now;
              if (_tapCount >= 3) {
                _tapCount = 0;
                _burstCtrl.forward(from: 0.0);
                _sound.playGiggle();
                HapticFeedback.heavyImpact();
                HapticFeedback.selectionClick();
                _pushMood(PigMood.excited, duration: const Duration(seconds: 2));
                final isFr = Provider.of<PigioAppState>(context, listen: false).locale.languageCode == 'fr';
                final tickleLines = isFr
                    ? const ['Hahaha arrête ! 😆🐧', 'Ça chatouille ! 🤣', 'Hihihi pas là ! 😂', 'Encore ! Encore ! 🤭', 'Stoooop je vais tomber ! 😆']
                    : const ['Hahaha stop it! 😆🐧', 'That tickles! 🤣', 'Hehehe not there! 😂', 'Again! Again! 🤭', 'Stoooop I\'ll fall over! 😆'];
                setState(() {
                  _dynamicMsg = tickleLines[_rng.nextInt(tickleLines.length)];
                  _cachedInsight = null;
                  _cachedTabIndex = null;
                  bubble = true;
                });
                _dynamicMsgClearTimer?.cancel();
                _dynamicMsgClearTimer = Timer(const Duration(seconds: 3), () {
                  if (mounted) setState(() { _dynamicMsg = null; bubble = false; });
                });
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (menu) {
                  setState(() => menu = false);
                } else {
                  _triggerWiggle();
                  setState(() { _cachedInsight = null; _cachedTabIndex = null; _dynamicMsg = null; bubble = !bubble; });
                  if (bubble) _sound.playPop();
                }
              });
            },
            onLongPressStart: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _openMascotMenu();
            }),
            child: Container(
              decoration: state.currentTheme.isDark ? BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ) : null,
              child: AnimatedScale(
              scale: isDragging && !_reducedMotion ? 1.12 : 1.0,
              duration: Duration(milliseconds: _reducedMotion ? 120 : 200),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  if (_isIdle && !_reducedMotion)
                    AnimatedBuilder(
                      animation: _sleepCtrl,
                      builder: (context, child) => Positioned(
                        top: _sleepFloat.value - 20, right: 10,
                        child: Opacity(opacity: _sleepFade.value, child: const Text("💤", style: TextStyle(fontSize: 24))),
                      ),
                    ),
                  AnimatedBuilder(
                    animation: _burstCtrl,
                    builder: (context, child) {
                      if (!_burstCtrl.isAnimating) return const SizedBox.shrink();
                      final p = _burstCtrl.value;
                      return SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(left: 40 - p * 40, top: 40 - p * 30, child: Opacity(opacity: 1 - p, child: const Text("✨", style: TextStyle(fontSize: 14)))),
                            Positioned(left: 40 + p * 30, top: 40 - p * 40, child: Opacity(opacity: 1 - p, child: const Text("✨", style: TextStyle(fontSize: 18)))),
                            Positioned(left: 20 - p * 25, top: 30 - p * 20, child: Opacity(opacity: 1 - p, child: const Text("🎉", style: TextStyle(fontSize: 12)))),
                            Positioned(left: 60 + p * 20, top: 25 - p * 35, child: Opacity(opacity: 1 - p, child: const Text("💛", style: TextStyle(fontSize: 10)))),
                            Positioned(left: 30 + p * 35, top: 50 - p * 45, child: Opacity(opacity: 1 - p, child: const Text("⭐", style: TextStyle(fontSize: 11)))),
                          ],
                        ),
                      );
                    },
                  ),
                  // E8: Evolution glow — visible aura at bond level 2+, sparkle at level 4+
                  if (state.mascotBondLevel >= 2 && !_reducedMotion)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _breathAnim,
                          builder: (ctx, _) {
                            final glowIntensity = (state.mascotBondLevel - 1) * 0.08;
                            final breathScale = 0.9 + _breathAnim.value * 0.1;
                            return Transform.scale(
                              scale: breathScale,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (state.mascotBondLevel >= 4
                                          ? const Color(0xFFFFD700)
                                          : const Color(0xFFFFC107)).withValues(alpha: glowIntensity),
                                      blurRadius: 24 + state.mascotBondLevel * 4.0,
                                      spreadRadius: 8 + state.mascotBondLevel * 2.0,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  AnimatedBuilder(
                    animation: _mergedAnimations,
                    builder: (ctx, child) {
                      // Corner peek: tilt when near screen edge
                      final edgeTilt = !_reducedMotion && isDragging
                        ? (left < 15 ? 0.15 : (left > size.width - 95 ? -0.15 : 0.0))
                        : 0.0;
                      // Upside-down flip when dragged to very top
                      final flipAngle = (!_reducedMotion && isDragging && bottom > size.height - 170) ? 3.14159 : 0.0;
                      // Dizzy spin
                      final dizzyAngle = !_reducedMotion && _isDizzy ? _spinAnim.value : 0.0;
                      return Transform.translate(
                        offset: Offset(0, isDragging || _reducedMotion ? 0 : _floatAnim.value),
                        child: Transform.rotate(
                          angle: _wiggleAnim.value + edgeTilt + flipAngle + dizzyAngle,
                          child: Transform(
                            alignment: Alignment.bottomCenter,
                            transform: Matrix4.diagonal3Values(
                              _breathAnim.value * _squashX.value,
                              _breathAnim.value * _squashY.value,
                              1.0,
                            ),
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      scale: effectiveMood == PigMood.waving ? 1.03 : 1.0,
                      child: PigioWidget(
                        mood: effectiveMood,
                        pose: weatherPose,
                        weatherCondition: weather?.condition,
                        weatherExposure: weatherExposure,
                        weatherIsDay: weather?.isDay ?? true,
                        weatherTemperature: weather?.temperature ?? 0,
                        size: 80,
                        scarfColor: state.mascotScarfColor,
                        contactCount: state.contacts.length,
                        reservedCount: state.wishes.where((w) => w.reservedById != null).length,
                        outfit: state.activeOutfit,
                        outfitColors: state.outfitColors,
                        isTalking: bubble && !_isIdle,
                        lookOffsetX: _dragGlobalPos != null
                          ? (((_dragGlobalPos!.dx - left - 40) / 100).clamp(-1.0, 1.0))
                          : (left < size.width / 2 ? 0.5 : -0.5),
                      ),
                    ),
                  ),
                  // ── Bond level badge ──
                  Positioned(
                    bottom: -10, right: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                      ),
                      child: Text(
                        state.mascotBondEmoji,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniRestorer() {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final width = MediaQuery.of(context).size.width;
    return Positioned(
      bottom: 86,
      right: state.mascotDefaultCorner == 'right' ? 14 : null,
      left: state.mascotDefaultCorner == 'left' ? 14 : null,
      child: GestureDetector(
        onTap: () {
          setState(() {
            hidden = false;
            bottom = 90;
            left = state.mascotDefaultCorner == 'right'
                ? ((width - 94).clamp(0.0, width)).toDouble()
                : 14;
          });
          _resumeAnimations();
          _triggerWiggle();
        },
        child: Column(
          children: [
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF9AADD8), Color(0xFF6A7BA8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                border: Border.all(color: theme.divider, width: 2.5),
                boxShadow: [BoxShadow(color: theme.ink.withValues(alpha: 0.26), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: ClipOval(
                child: Transform.translate(
                  offset: const Offset(0, 10),
                  child: PigioWidget(mood: PigMood.searching, size: 72, outfit: state.activeOutfit, outfitColors: state.outfitColors),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text("Pigio", style: fw(size: 9, w: FontWeight.w800, color: theme.mid)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context);
    final lang = state.locale.languageCode;

    // Bond level progress
    final xp = state.mascotBondXp;
    final level = state.mascotBondLevel;
    final nextThreshold = const [10, 50, 200, 500][level.clamp(0, 3)];
    final prevThreshold = level == 0 ? 0 : const [0, 10, 50, 200][level.clamp(0, 3)];
    final progress = level >= 4 ? 1.0 : ((xp - prevThreshold) / (nextThreshold - prevThreshold)).clamp(0.0, 1.0);

    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.scaffold,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: theme.shadow, blurRadius: 18, offset: const Offset(0, 6))],
        border: Border.all(color: theme.divider),
      ),
      child: Column(
        children: [
          // Bond level indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(state.mascotBondEmoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.mascotBondTitle,
                        style: fw(size: 12, w: FontWeight.w800, color: theme.ink),
                      ),
                    ),
                    Text(
                      '$xp XP',
                      style: fw(size: 10, w: FontWeight.w700, color: theme.mid),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: theme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: theme.divider, height: 1),
          _menuItem("💬", lang == 'fr' ? "Dire bonjour" : "Say hello", () {
            setState(() { menu = false; _cachedInsight = null; _cachedTabIndex = null; _dynamicMsg = null; bubble = true; });
            _triggerWiggle();
          }),
          Divider(color: theme.divider, height: 1),
          _menuItem("👕", lang == 'fr' ? "Habiller Pigio" : "Dress Pigio", () {
            setState(() => menu = false);
            // Delay navigation to avoid MouseTracker re-entrant issue on macOS
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final reqSlot = Provider.of<PigioAppState>(context, listen: false).currentClothingRequest?.item.slot;
              Navigator.push(context, MaterialPageRoute(builder: (_) => MascotWardrobeScreen(initialSlot: reqSlot)));
            });
          }),
          Divider(color: theme.divider, height: 1),
          _menuItem("⚙️", lang == 'fr' ? "Réglages Pigio" : "Pigio Settings", () {
            setState(() => menu = false);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MascotSettingsScreen()));
            });
          }),
          Divider(color: theme.divider, height: 1),
          _menuItem("👋", lang == 'fr' ? "Minimiser Pigio" : "Minimize Pigio", () { setState(() => hidden = true); _pauseAnimations(); }),
        ],
      ),
    );
  }

  Widget _menuItem(String icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    final theme = context.pt;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Text(label, style: fw(size: 13, w: FontWeight.w700, color: isDestructive ? theme.error : theme.ink)),
          ],
        ),
      ),
    );
  }
}

class SpeechBubble extends StatelessWidget {
  final String msg;
  final String side;
  final bool isLoading;
  final VoidCallback onClose;
  final VoidCallback? onQuickEquip;
  final String? quickEquipLabel;
  final VoidCallback? onAction;
  final String? actionLabel;

  const SpeechBubble({
    super.key,
    required this.msg,
    required this.side,
    required this.onClose,
    this.isLoading = false,
    this.onQuickEquip,
    this.quickEquipLabel,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    return Container(
      constraints: const BoxConstraints(maxWidth: 210, minWidth: 140),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: theme.sheet,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: theme.shadow, blurRadius: 32, offset: const Offset(0, 8))],
        border: Border.all(color: theme.divider, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: isLoading ? _LoadingDots(color: theme.mid) : Text(msg, style: fw(size: 12, w: FontWeight.w700, color: theme.ink, height: 1.4)),
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  margin: const EdgeInsets.only(left: 6, top: 2),
                  width: 18, height: 18,
                  decoration: BoxDecoration(color: theme.surface, shape: BoxShape.circle),
                  child: Center(child: Icon(Icons.close, size: 10, color: theme.mid)),
                ),
              ),
            ],
          ),
          if (onQuickEquip != null || onAction != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onQuickEquip != null)
                  GestureDetector(
                    onTap: onQuickEquip,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        quickEquipLabel ?? 'Essayer',
                        style: fw(size: 11, w: FontWeight.w800, color: theme.primary),
                      ),
                    ),
                  ),
                if (onAction != null)
                  GestureDetector(
                    onTap: onAction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.accent2.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.accent2.withValues(alpha: 0.32)),
                      ),
                      child: Text(
                        actionLabel ?? 'Open',
                        style: fw(size: 11, w: FontWeight.w800, color: theme.accent2),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingDots extends StatefulWidget {
  final Color color;
  const _LoadingDots({required this.color});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = (i / 3);
            final t = ((_ctrl.value + offset) % 1.0);
            final opacity = t < 0.5 ? t * 2 : (1 - t) * 2;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity.clamp(0.2, 1.0),
                child: Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
              ),
            );
          }),
        );
      },
    );
  }
}

class BirthdayOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const BirthdayOverlay({super.key, required this.onClose});

  @override
  State<BirthdayOverlay> createState() => _BirthdayOverlayState();
}

class _BirthdayOverlayState extends State<BirthdayOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  // Pre-computed confetti positions (instead of Random() in build)
  late final List<double> _confettiTop;
  late final List<double> _confettiLeft; // stored as fraction 0-1
  late final List<double> _confettiAngle;
  List<Color> _getConfettiColors(PigioThemeData theme) => [theme.warning, theme.accent2, theme.primary, theme.success, theme.accent3, theme.error];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
    final rng = math.Random(42);
    _confettiTop = List.generate(30, (_) => rng.nextDouble() * 400);
    _confettiLeft = List.generate(30, (_) => rng.nextDouble());
    _confettiAngle = List.generate(30, (_) => rng.nextDouble());
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final lang = Provider.of<PigioAppState>(context).locale.languageCode;
    return Positioned.fill(
      child: FadeTransition(
        opacity: _ctrl,
        child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.accent2, const Color(0xFFFF6BA8)])),
          child: Stack(
            children: [
              ...List.generate(30, (i) => Positioned(
                top: _confettiTop[i],
                left: _confettiLeft[i] * MediaQuery.of(context).size.width,
                child: Transform.rotate(angle: _confettiAngle[i], child: Container(width: 8, height: 8, color: _getConfettiColors(theme)[i % _getConfettiColors(theme).length])),
              ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PigioBadge(label: "🎉", color: theme.onAccent, bg: theme.onAccent.withValues(alpha: 0.25)),
                          IconButton(icon: Icon(Icons.close, color: theme.onAccent), onPressed: widget.onClose),
                        ],
                      ),
                      const Spacer(),
                      PigioWidget(mood: PigMood.celebrating, size: 140, outfit: context.watch<PigioAppState>().activeOutfit, outfitColors: context.watch<PigioAppState>().outfitColors),
                      const SizedBox(height: 30),
                      Text(lang == 'fr' ? "JOYEUX\nANNIVERSAIRE !" : "HAPPY\nBIRTHDAY!", textAlign: TextAlign.center, style: fw(size: 40, w: FontWeight.w900, color: theme.onAccent).copyWith(height: 1.1)),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: theme.onAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: CircleAvatar(radius: 14, backgroundColor: theme.onAccent)))),
                            const SizedBox(height: 8),
                            Text(lang == 'fr' ? "3 amis vous souhaitent une bonne fête !" : "3 friends wish you a happy birthday!", style: fw(size: 12, w: FontWeight.w600, color: theme.onAccent)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      PigioButton(label: lang == 'fr' ? "🎁 Ouvrir carte" : "🎁 Open card", color: theme.onAccent.withValues(alpha: 0.25), onTap: widget.onClose),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeatherPainter extends CustomPainter {
  final WeatherData weather;
  final double animationValue;
  final Offset mascotCenter;
  final bool hasUmbrella;
  final bool hasRainProtection;
  final bool hasSnowProtection;
  final bool hasSunProtection;
  final double rainCoverage;
  final double snowCoverage;
  final double sunCoverage;

  // P3: Pre-allocated Paint objects — avoids GC churn in paint() loop
  static final Paint _rainPaint = Paint()
    ..color = Colors.blueAccent.withValues(alpha: 0.6)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  static final Paint _deflectedRainPaint = Paint()
    ..color = Colors.blueAccent.withValues(alpha: 0.3)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;

  static final Paint _snowPaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.8)
    ..style = PaintingStyle.fill;

  static final Paint _heatPaint = Paint()
    ..color = Colors.orangeAccent.withValues(alpha: 0.1)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

  static final Paint _sunPaint = Paint()
    ..color = const Color(0xFFFFC857).withValues(alpha: 0.92)
    ..style = PaintingStyle.fill;

  static final Paint _sunRayPaint = Paint()
    ..color = const Color(0xFFFFD56B).withValues(alpha: 0.85)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;

  static final Paint _heatAuraPaint = Paint()
    ..color = const Color(0xFFFFA726).withValues(alpha: 0.14)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

  WeatherPainter({
    required this.weather,
    required this.animationValue,
    required this.mascotCenter,
    required this.hasUmbrella,
    required this.hasRainProtection,
    required this.hasSnowProtection,
    required this.hasSunProtection,
    required this.rainCoverage,
    required this.snowCoverage,
    required this.sunCoverage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (weather.condition == 'rain' || weather.condition == 'storm') {
      _drawRain(canvas, size);
    } else if (weather.condition == 'snow') {
      _drawSnow(canvas, size);
    } else if (weather.temperature > 28 || (weather.condition == 'sunny' && weather.isDay)) {
      _drawHeat(canvas, size);
    }
  }

  void _drawRain(Canvas canvas, Size size) {
    final random = math.Random(42); // fixed seed for consistent layout
    final dropCount = weather.condition == 'storm' ? 80 : 40;
    final wind = weather.condition == 'storm' ? 18.0 : 8.0;
    final shieldCenter = mascotCenter.translate(hasUmbrella ? 10 : 0, hasUmbrella ? -90 : -52);
    final shieldRadius = hasUmbrella ? 80.0 : 36.0;
    final exposedSplash = (1 - rainCoverage).clamp(0.0, 1.0);

    for (int i = 0; i < dropCount; i++) {
      final startX = random.nextDouble() * size.width;
      final initialY = (random.nextDouble() * size.height) - 50;
      
      double y = initialY + (animationValue * size.height * 2);
      y = y % (size.height + 50);
      final sway = math.sin((animationValue * math.pi * 2) + i * 0.35) * (weather.condition == 'storm' ? 6 : 3);
      final x = startX + (y / size.height) * wind + sway;

      if (hasRainProtection) {
        if ((Offset(x, y) - shieldCenter).distance < shieldRadius && y < mascotCenter.dy + 38) {
          final angle = math.atan2(y - shieldCenter.dy, x - shieldCenter.dx);
          final deflectLength = hasUmbrella ? 22.0 : 12.0;
          canvas.drawLine(
            Offset(x, y),
            Offset(
              x + math.cos(angle) * deflectLength + wind * 0.15,
              y + math.sin(angle).abs() * 11 + 9,
            ),
            _deflectedRainPaint,
          );
          continue;
        }
      }

      canvas.drawLine(
        Offset(x, y),
        Offset(x - 2 - wind * 0.08, y + 15),
        _rainPaint,
      );

      if (exposedSplash > 0.1 && (x - mascotCenter.dx).abs() < 28 && y > mascotCenter.dy + 10 && y < mascotCenter.dy + 55) {
        canvas.drawCircle(
          Offset(mascotCenter.dx + sway * 0.4, mascotCenter.dy + 47 + random.nextDouble() * 8),
          1.2 + exposedSplash * 1.8,
          _deflectedRainPaint,
        );
      }
    }

    if (exposedSplash > 0.08) {
      final puddlePaint = Paint()
        ..color = Colors.lightBlueAccent.withValues(alpha: 0.1 + exposedSplash * 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: mascotCenter.translate(0, 56),
          width: 54 + exposedSplash * 18,
          height: 10 + exposedSplash * 4,
        ),
        puddlePaint,
      );
    }
  }

  void _drawSnow(Canvas canvas, Size size) {
    final random = math.Random(123);
    final exposedFlakes = (1 - snowCoverage).clamp(0.0, 1.0);
    for (int i = 0; i < 30; i++) {
      final startX = random.nextDouble() * size.width;
      final initialY = (random.nextDouble() * size.height) - 50;
      
      double y = initialY + (animationValue * size.height);
      y = y % (size.height + 50);
      
      final drift = math.sin(animationValue * math.pi * 2 + i) * (12 + exposedFlakes * 8);

      canvas.drawCircle(
        Offset(startX + drift, y),
        random.nextDouble() * 3 + 2,
        _snowPaint,
      );

      if (!hasSnowProtection && (startX + drift - mascotCenter.dx).abs() < 26 && (y - mascotCenter.dy).abs() < 34) {
        canvas.drawCircle(
          Offset(startX + drift, y),
          3.5,
          Paint()..color = Colors.white.withValues(alpha: 0.95),
        );
      }
    }

    if (exposedFlakes > 0.08) {
      final accumulationPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.24 + exposedFlakes * 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: mascotCenter.translate(0, 56),
          width: 46 + exposedFlakes * 20,
          height: 8 + exposedFlakes * 4,
        ),
        accumulationPaint,
      );
    }
  }

  void _drawHeat(Canvas canvas, Size size) {
    if (weather.isDay) {
      final sunCenter = Offset(size.width - 64, 72);
      for (int i = 0; i < 10; i++) {
        final angle = (math.pi * 2 / 10) * i + animationValue * 0.4;
        final inner = Offset(
          sunCenter.dx + math.cos(angle) * 28,
          sunCenter.dy + math.sin(angle) * 28,
        );
        final outer = Offset(
          sunCenter.dx + math.cos(angle) * 44,
          sunCenter.dy + math.sin(angle) * 44,
        );
        canvas.drawLine(inner, outer, _sunRayPaint);
      }
      canvas.drawCircle(sunCenter, 22, _sunPaint);
    }

    final waveOffset = math.sin(animationValue * math.pi * 4) * 5;
    canvas.drawRect(
      Rect.fromLTWH(-20, size.height - 40 + waveOffset, size.width + 40, 60),
      _heatPaint,
    );

    final shimmerPaint = Paint()
      ..color = const Color(0xFFFFB74D).withValues(alpha: 0.06 + (1 - sunCoverage) * 0.08)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      final x = mascotCenter.dx - 18 + i * 12;
      final offset = math.sin(animationValue * math.pi * 4 + i) * 6;
      canvas.drawLine(
        Offset(x, mascotCenter.dy - 18 + offset),
        Offset(x + 3, mascotCenter.dy + 24 + offset),
        shimmerPaint,
      );
    }

    if (!hasSunProtection) {
      canvas.drawCircle(mascotCenter.translate(0, -8), 34 + (1 - sunCoverage) * 14, _heatAuraPaint);
    }
  }

  @override
  bool shouldRepaint(covariant WeatherPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.weather.condition != weather.condition ||
           oldDelegate.weather.temperature != weather.temperature ||
           oldDelegate.weather.isDay != weather.isDay ||
           oldDelegate.mascotCenter != mascotCenter ||
           oldDelegate.hasUmbrella != hasUmbrella ||
           oldDelegate.hasRainProtection != hasRainProtection ||
           oldDelegate.hasSnowProtection != hasSnowProtection ||
           oldDelegate.hasSunProtection != hasSunProtection ||
           oldDelegate.rainCoverage != rainCoverage ||
           oldDelegate.snowCoverage != snowCoverage ||
           oldDelegate.sunCoverage != sunCoverage;
  }
}