import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'pigio_painter.dart';
import 'ui_widgets.dart';
import 'package:pigio_app/screens/mascot/mascot_settings_screen.dart';
import 'package:pigio_app/screens/mascot/mascot_wardrobe_screen.dart';
import '../../services/ai_service.dart';
import '../../services/mascot_outfit_engine.dart';

// ─── INSIGHT MODEL ───────────────────────────────────────────────────────────
class _Insight {
  final PigMood mood;
  final String fr;
  final String en;
  final bool triggersAI;

  const _Insight({
    required this.mood,
    required this.fr,
    required this.en,
    this.triggersAI = false,
  });
}

// ─── CONTEXTUAL INSIGHT ENGINE ───────────────────────────────────────────────
class _InsightEngine {
  static final _rng = math.Random();

  static _Insight pick(
    PigioAppState state,
    int tabIndex,
    void Function(Future<String?> Function(PigioAppState)) triggerAI,
  ) {
    final now = DateTime.now();

    // ── 1. INSTANT FEEDBACK MOMENTS (Highest Priority) ───────────────────────
    if (state.mascotMoment == MascotMoment.firstWish) {
      Future.microtask(state.clearMascotMoment);
      return const _Insight(
        mood: PigMood.celebrating,
        fr: "Premier vœu ! 🎁 C'est le début du bonheur !",
        en: "First wish added! 🎁 The start of something great!",
      );
    }
    if (state.mascotMoment == MascotMoment.wishReserved) {
      Future.microtask(state.clearMascotMoment);
      return const _Insight(
        mood: PigMood.thumbsUp,
        fr: "Cadeau réservé ! 🤫 Chut, c'est un secret...",
        en: "Gift reserved! 🤫 Shhh, it's a secret...",
      );
    }
    if (state.mascotMoment == MascotMoment.inviteAccepted) {
      Future.microtask(state.clearMascotMoment);
      return const _Insight(
        mood: PigMood.excited,
        fr: "Invitation acceptée ! 🎉 Ton cercle grandit !",
        en: "Invite accepted! 🎉 Your circle is growing!",
      );
    }
    if (state.mascotMoment == MascotMoment.quizCompleted) {
      Future.microtask(state.clearMascotMoment);
      return const _Insight(
        mood: PigMood.celebrating,
        fr: "Merci ! Je te connais mieux — je vais mieux aider tes proches 🎁",
        en: "Thanks! Now I know you better — I'll help your circle gift you perfectly 🎁",
      );
    }

    // ── 2. CLOTHING REQUESTS (Outfit Engine override) ────────────────────────
    if (state.currentClothingRequest != null) {
      final req = state.currentClothingRequest!;
      return _Insight(
        mood: PigMood.excited,
        fr: req.bubbleTextFr,
        en: req.bubbleTextEn,
      );
    }

    // ── 3. URGENT BIRTHDAYS (Today only) ─────────────────────────────────────
    for (final contact in state.contacts) {
      final bd = _parseBirthdate(contact.birthdate);
      if (bd != null) {
        final next = _nextOccurrence(bd, now);
        if (next.difference(DateTime(now.year, now.month, now.day)).inDays == 0) {
          return _Insight(
            mood: PigMood.celebrating,
            fr: "C'est l'anniversaire de ${contact.name} ! 🎂🎉",
            en: "It's ${contact.name}'s birthday today! 🎂🎉",
          );
        }
      }
    }

    // ── 4. TAB-SPECIFIC PRIORITY (Contextual Logic) ──────────────────────────
    // We move this HIGHER so Pigio changes expression based on the page more often.
    final wishCount = state.wishes.where((w) => w.contactId == null).length;
    final contactCount = state.contacts.length;

    switch (tabIndex) {
      case 1: // WISHES TAB
        if (wishCount == 0) {
          return const _Insight(
            mood: PigMood.searching,
            fr: "Ta liste est vide ! 🎁 Ajoute ton premier vœu.",
            en: "Your list is empty! 🎁 Add your first wish.",
          );
        }
        break;
      case 2: // WARDROBE/SIZES TAB
        if (state.sizes.isEmpty) {
          return const _Insight(
            mood: PigMood.thinking,
            fr: "Pas de tailles ? 📏 Ajoute-les pour des cadeaux parfaits !",
            en: "No sizes yet? 📏 Add them for perfectly fitting gifts!",
          );
        }
        // Check for stale sizes specific to this tab
        final stale = state.sizes.where((s) => s.contactId == null && now.difference(s.updatedAt).inDays > 120).toList();
        if (stale.isNotEmpty) {
          return const _Insight(
            mood: PigMood.searching,
            fr: "Tes tailles datent un peu... 📏 Un petit rafraîchissement ?",
            en: "Your sizes are a bit old... 📏 Time for an update?",
          );
        }
        break;
      case 3: // CONTACTS TAB
        if (contactCount == 0) {
          return const _Insight(
            mood: PigMood.waving,
            fr: "Tout seul ? 👥 Invite ta famille et tes amis !",
            en: "All alone? 👥 Invite your family and friends!",
          );
        }
        break;
    }

    // ── 5. SECONDARY GLOBAL ALERTS (Birthdays, Stale Data) ───────────────────
    // Check birthdays within 7 days
    for (final contact in state.contacts) {
      final bd = _parseBirthdate(contact.birthdate);
      if (bd != null) {
        final diff = _nextOccurrence(bd, now).difference(DateTime(now.year, now.month, now.day)).inDays;
        final hasGift = state.wishes.any((w) => w.contactId == contact.id && w.reservedById != null);
        if (diff > 0 && diff <= 7 && !hasGift) {
          triggerAI((st) => AiService.generateGiftConcierge(contact, personalityContext: st.personalityProfileSummary));
          return _Insight(
            mood: PigMood.excited,
            fr: "Anniv de ${contact.name} dans $diff jours ! 🎁 Une idée ?",
            en: "${contact.name}'s bday in $diff days! 🎁 Any ideas?",
            triggersAI: true,
          );
        }
      }
    }

    // ── 6. GENERAL TAB-SPECIFIC MESSAGES (Fallback within Tab) ───────────────
    return _tabInsightFallback(tabIndex, state, now);
  }

  static _Insight _tabInsightFallback(int tab, PigioAppState state, DateTime now) {
    switch (tab) {
      case 0: // HOME
        final greetings = _timeGreetings(now.hour, state.profile.name);
        return _pick(greetings);
      case 1: // WISHES
        final highPriority = state.wishes.where((w) => w.contactId == null && w.priority == WishPriority.high).length;
        if (highPriority > 0) {
          return _Insight(
            mood: PigMood.love,
            fr: "Tu as $highPriority vœux prioritaires ! 🔥 J'espère qu'ils arriveront vite.",
            en: "You have $highPriority top wishes! 🔥 Hope they arrive soon.",
          );
        }
        return const _Insight(
          mood: PigMood.thumbsUp,
          fr: "Ta liste d'envies est prête ! ✨ N'hésite pas à la partager.",
          en: "Your wish list is ready! ✨ Don't forget to share it.",
        );
      case 2: // WARDROBE
        final sizeCount = state.sizes.where((s) => s.contactId == null).length;
        return _Insight(
          mood: PigMood.thumbsUp,
          fr: "$sizeCount catégories de tailles enregistrées. ✅ Propre !",
          en: "$sizeCount size categories saved. ✅ Looking good!",
        );
      case 3: // CONTACTS
        final familyCount = state.contacts.where((c) => c.isFamily).length;
        return _Insight(
          mood: PigMood.love,
          fr: "Déjà $familyCount membres dans ta famille ! 💛 Belle équipe.",
          en: "$familyCount family members joined! 💛 Great team.",
        );
      default:
        return _timeGreetings(now.hour, state.profile.name).first;
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────
  static DateTime? _parseBirthdate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('/');
    if (parts.length < 2) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (d == null || m == null) return null;
    return DateTime(2000, m, d); // Standard base year
  }

  static DateTime _nextOccurrence(DateTime date, DateTime now) {
    DateTime next = DateTime(now.year, date.month, date.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, date.month, date.day);
    }
    return next;
  }

  static T _pick<T>(List<T> list) => list[_rng.nextInt(list.length)];

  static List<_Insight> _timeGreetings(int hour, String name) {
    final n = name.isEmpty ? '' : ' $name';
    if (hour < 9) {
      return [
        _Insight(mood: PigMood.waving, fr: "Coucou$n ! ☀️ Prêt pour une belle journée ?", en: "Hey$n! ☀️ Ready for a great day?"),
        _Insight(mood: PigMood.excited, fr: "Tôt debout$n ! 🐦 On cherche des cadeaux ?", en: "Early bird$n! 🐦 Looking for gifts?"),
      ];
    } else if (hour < 12) {
      return [
        _Insight(mood: PigMood.waving, fr: "Bonjour$n ! 🌟 Quoi de neuf dans ton Réseau ?", en: "Morning$n! 🌟 What's new in your Network?"),
        _Insight(mood: PigMood.thumbsUp, fr: "Belle matinée ! 🎁 N'oublie pas de vérifier tes envies.", en: "Good morning! 🎁 Don't forget to check your wishes."),
      ];
    } else if (hour < 14) {
      return [
        _Insight(mood: PigMood.love, fr: "Bon appétit$n ! 🍽️", en: "Enjoy your lunch$n! 🍽️"),
      ];
    } else if (hour < 18) {
      return [
        _Insight(mood: PigMood.excited, fr: "Bon après-midi ! 🎯 On avance sur tes cercles ?", en: "Good afternoon! 🎯 Progressing on your circles?"),
        _Insight(mood: PigMood.searching, fr: "Une idée de vœu à ajouter$n ? 💡", en: "Any wish idea to add$n? 💡"),
      ];
    } else {
      return [
        _Insight(mood: PigMood.waving, fr: "Bonne soirée$n ! 🌙 Pigio veille sur tes vœux.", en: "Good evening$n! 🌙 Pigio is watching your wishes."),
      ];
    }
  }
}

// ─── DRAGGABLE MASCOT ────────────────────────────────────────────────────────
class DraggableMascot extends StatefulWidget {
  final int tabIndex;
  const DraggableMascot({super.key, this.tabIndex = 0});

  @override
  State<DraggableMascot> createState() => _DraggableMascotState();
}

class _DraggableMascotState extends State<DraggableMascot> with TickerProviderStateMixin {
  double left = 14;
  double bottom = 90;

  bool hidden = false;
  bool bubble = false;
  bool menu = false;
  bool isDragging = false;

  String? _dynamicMsg;
  bool _isGeneratingDynamic = false;
  DateTime? _lastBubbleTime;

  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;
  late AnimationController _wiggleCtrl;
  late Animation<double> _wiggleAnim;
  late AnimationController _sleepCtrl;
  late Animation<double> _sleepFade;
  late Animation<double> _sleepFloat;
  late AnimationController _burstCtrl;

  bool _isIdle = false;
  Timer? _idleTimer;

  _Insight? _cachedInsight;
  int? _cachedTabIndex;

  @override
  void initState() {
    super.initState();
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

    _resetIdleTimer();

    Future.delayed(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      final state = Provider.of<PigioAppState>(context, listen: false);
      final outfitReq = await MascotOutfitEngine.evaluateContext(state);
      if (mounted && outfitReq != null) state.setClothingRequest(outfitReq);

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

  void _triggerWiggle() => _wiggleCtrl.forward(from: 0.0);

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
      setState(() => _isIdle = false);
      _sleepCtrl.reset();
    }
    _idleTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && !hidden && !bubble && !menu) {
        setState(() => _isIdle = true);
        _sleepCtrl.repeat();
      }
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _floatCtrl.dispose();
    _wiggleCtrl.dispose();
    _sleepCtrl.dispose();
    _burstCtrl.dispose();
    super.dispose();
  }

  void _triggerAI(Future<String?> Function(PigioAppState) task, PigioAppState state) {
    if (_isGeneratingDynamic || _dynamicMsg != null) return;
    Future.microtask(() async {
      if (!mounted) return;
      setState(() => _isGeneratingDynamic = true);
      final raw = await task(state);
      if (mounted) {
        setState(() {
          _dynamicMsg = raw != null ? _firstSentence(raw) : null;
          _isGeneratingDynamic = false;
        });
      }
    });
  }

  String _firstSentence(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'\*+'), '').replaceAll(RegExp(r'#+\s*'), '').replaceAll(RegExp(r'- '), '').trim();
    final match = RegExp(r'^(.{10,90}?[.!?🎁🎂🎉🎄💡📅📏👀✨💛])').firstMatch(cleaned);
    if (match != null) return match.group(1)!.trim();
    return cleaned.length > 90 ? '${cleaned.substring(0, 88)}…' : cleaned;
  }

  _Insight _getInsight(PigioAppState state) {
    if (_cachedInsight != null && _cachedTabIndex == widget.tabIndex) return _cachedInsight!;
    final insight = _InsightEngine.pick(state, widget.tabIndex, (task) => _triggerAI(task, state));
    _cachedInsight = insight;
    _cachedTabIndex = widget.tabIndex;
    return insight;
  }

  @override
  Widget build(BuildContext context) {
    if (hidden) return _buildMiniRestorer();

    final state = Provider.of<PigioAppState>(context);
    final insight = _getInsight(state);
    final lang = state.locale.languageCode;

    final rawMsg = _dynamicMsg ?? (lang == 'fr' ? insight.fr : insight.en);
    final msg = state.mascotPrivacyMode ? rawMsg.replaceAll(RegExp(r'''[a-zA-ZÀ-ÿ0-9.,!?'"()\-:;]'''), '').trim() : rawMsg;

    final size = MediaQuery.of(context).size;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (bubble && !isDragging && msg.isNotEmpty)
          AnimatedPositioned(
            duration: Duration.zero,
            bottom: bottom + 100,
            left: left < size.width / 2 ? left : null,
            right: left >= size.width / 2 ? (size.width - left - 80) : null,
            child: SpeechBubble(
              msg: msg,
              isLoading: _isGeneratingDynamic && _dynamicMsg == null,
              side: left < size.width / 2 ? "left" : "right",
              onClose: () => setState(() => bubble = false),
            ),
          ),
        if (menu && !isDragging)
          AnimatedPositioned(
            duration: Duration.zero,
            bottom: bottom + 100,
            left: left < size.width / 2 ? left : null,
            right: left >= size.width / 2 ? (size.width - left - 80) : null,
            child: _buildMenu(context),
          ),
        AnimatedPositioned(
          duration: isDragging ? Duration.zero : const Duration(milliseconds: 700),
          curve: isDragging ? Curves.linear : Curves.elasticOut,
          left: left,
          bottom: bottom,
          child: GestureDetector(
            onPanStart: (d) {
              _resetIdleTimer();
              setState(() { isDragging = true; bubble = false; menu = false; });
            },
            onPanUpdate: (d) {
              _resetIdleTimer();
              setState(() {
                left = (left + d.delta.dx).clamp(0.0, size.width - 80);
                bottom = (bottom - d.delta.dy).clamp(76.0, size.height - 150);
              });
            },
            onPanEnd: (d) {
              setState(() {
                isDragging = false;
                left = (left < size.width / 2) ? 20 : size.width - 100;
              });
              _triggerWiggle();
              _burstCtrl.forward(from: 0.0);
              _resetIdleTimer();
            },
            onTap: () {
              _resetIdleTimer();
              if (menu) { setState(() => menu = false); } else {
                _triggerWiggle();
                setState(() { _cachedInsight = null; _cachedTabIndex = null; _dynamicMsg = null; bubble = !bubble; });
              }
            },
            onLongPress: () { _resetIdleTimer(); setState(() { bubble = false; menu = true; }); _triggerWiggle(); },
            child: AnimatedScale(
              scale: isDragging ? 1.12 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  if (_isIdle)
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
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(left: 40 - p * 40, top: 40 - p * 30, child: Opacity(opacity: 1 - p, child: const Text("✨", style: TextStyle(fontSize: 14)))),
                          Positioned(left: 40 + p * 30, top: 40 - p * 40, child: Opacity(opacity: 1 - p, child: const Text("✨", style: TextStyle(fontSize: 18)))),
                        ],
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: Listenable.merge([_floatAnim, _wiggleAnim]),
                    builder: (ctx, child) => Transform.translate(
                      offset: Offset(0, isDragging ? 0 : _floatAnim.value),
                      child: Transform.rotate(angle: _wiggleAnim.value, child: child),
                    ),
                    child: PigioWidget(
                      mood: _isIdle ? PigMood.thinking : insight.mood,
                      size: 80,
                      scarfColor: state.mascotScarfColor,
                      contactCount: state.contacts.length,
                      reservedCount: state.wishes.where((w) => w.reservedById != null).length,
                      outfit: state.activeOutfit,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniRestorer() {
    final theme = context.pt;
    return Positioned(
      bottom: 86, right: 14,
      child: GestureDetector(
        onTap: () {
          setState(() { hidden = false; bottom = 90; left = MediaQuery.of(context).size.width - 94; });
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
                  child: PigioWidget(mood: PigMood.searching, size: 72, outfit: context.watch<PigioAppState>().activeOutfit),
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
    final lang = Provider.of<PigioAppState>(context).locale.languageCode;
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
          _menuItem("💬", lang == 'fr' ? "Dire bonjour" : "Say hello", () {
            setState(() { menu = false; _cachedInsight = null; _cachedTabIndex = null; _dynamicMsg = null; bubble = true; });
            _triggerWiggle();
          }),
          Divider(color: theme.divider, height: 1),
          _menuItem("👕", lang == 'fr' ? "Habiller Pigio" : "Dress Pigio", () {
            setState(() => menu = false);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MascotWardrobeScreen()));
          }),
          Divider(color: theme.divider, height: 1),
          _menuItem("⚙️", lang == 'fr' ? "Réglages Pigio" : "Pigio Settings", () {
            setState(() => menu = false);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MascotSettingsScreen()));
          }),
          Divider(color: theme.divider, height: 1),
          _menuItem("👋", lang == 'fr' ? "Masquer Pigio" : "Hide Pigio", () => setState(() => hidden = true), isDestructive: true),
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

  const SpeechBubble({
    super.key,
    required this.msg,
    required this.side,
    required this.onClose,
    this.isLoading = false,
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
  List<Color> _getConfettiColors(PigioThemeData theme) => [theme.warning, theme.accent2, theme.primary, theme.success, theme.accent3, theme.error];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
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
                  top: math.Random().nextDouble() * 400,
                  left: math.Random().nextDouble() * MediaQuery.of(context).size.width,
                  child: Transform.rotate(angle: math.Random().nextDouble(), child: Container(width: 8, height: 8, color: _getConfettiColors(theme)[i % _getConfettiColors(theme).length])),
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
                      PigioWidget(mood: PigMood.celebrating, size: 140, outfit: context.watch<PigioAppState>().activeOutfit),
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
