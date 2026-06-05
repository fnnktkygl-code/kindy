import 'dart:math' as math;
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/shared/widgets/pigio_painter.dart';
import 'ai_service.dart';
import 'mascot_outfit_engine.dart';

// ─── INSIGHT MODEL ───────────────────────────────────────────────────────────

class MascotInsight {
  final PigMood mood;
  final String fr;
  final String en;
  final bool triggersAI;
  final String? actionLabelFr;
  final String? actionLabelEn;
  final void Function(PigioAppState)? action;
  final String? actionKey;
  /// Side-effect action to execute AFTER the insight is consumed (not during pick).
  final void Function()? postAction;
  /// AI task to trigger after display (caller should invoke this, not engine).
  final Future<String?> Function(PigioAppState)? aiTask;

  const MascotInsight({
    required this.mood,
    required this.fr,
    required this.en,
    this.triggersAI = false,
    this.actionLabelFr,
    this.actionLabelEn,
    this.action,
    this.actionKey,
    this.postAction,
    this.aiTask,
  });
}

// ─── CONTEXTUAL INSIGHT ENGINE ───────────────────────────────────────────────

class MascotInsightEngine {
  static final _rng = math.Random();

  /// Tabs already greeted this session (one welcome per tab per app launch).
  static final Set<int> _greetedTabs = {};

  /// Nearest birthday cache to avoid O(n) iteration per call.
  static String? _cachedBirthdayContactId;
  static int? _cachedBirthdayDiff;
  static DateTime? _birthdayCacheTime;

  /// Pick the best insight. Side-effects are returned as [postAction] and [aiTask]
  /// on the result — the CALLER is responsible for executing them, not this method.
  static MascotInsight pick(PigioAppState state, int tabIndex) {
    final now = DateTime.now();

    // ── 0. FIRST-OPEN INTRODUCTION (Absolute highest priority) ────────────────
    if (state.mascotMoment == MascotMoment.firstOpen) {
      final n = state.profile.name.isEmpty ? '' : ' ${state.profile.name}';
      return MascotInsight(
        mood: PigMood.waving,
        fr: "Salut$n ! 👋 Moi c'est Pigio, ton compagnon de cadeaux ! Fais le quiz pour que je te connaisse mieux !",
        en: "Hey$n! 👋 I'm Pigio, your gifting companion! Take the quiz so I can get to know you!",
        actionLabelFr: 'Me découvrir',
        actionLabelEn: 'Get to know me',
        actionKey: 'open_quiz',
        postAction: state.clearMascotMoment,
      );
    }

    // ── 1. INSTANT FEEDBACK MOMENTS (Highest Priority) ───────────────────────
    if (state.mascotMoment == MascotMoment.firstWish) {
      return _pick([
        MascotInsight(
          mood: PigMood.celebrating,
          fr: "Premier vœu ! 🎁 C'est le début du bonheur !",
          en: "First wish added! 🎁 The start of something great!",
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.excited,
          fr: "Yeees ! 🎉 Ton premier vœu est en place ! On continue ?",
          en: "Yeees! 🎉 Your first wish is in! Shall we keep going?",
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.love,
          fr: "C'est parti ! 🌟 Ton premier vœu, le début d'une belle liste !",
          en: "Here we go! 🌟 Your first wish — the start of a great list!",
          postAction: state.clearMascotMoment,
        ),
      ]);
    }
    if (state.mascotMoment == MascotMoment.wishReserved) {
      return _pick([
        MascotInsight(
          mood: PigMood.thumbsUp,
          fr: "Cadeau réservé ! 🤫 Chut, c'est un secret...",
          en: "Gift reserved! 🤫 Shhh, it's a secret...",
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.love,
          fr: "Ohhh, quel geste ! 💝 Tu vas faire un heureux...",
          en: "Ohhh, what a gesture! 💝 You're going to make someone's day...",
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.excited,
          fr: "C'est noté, motus ! 🤐 Ce cadeau va être parfait.",
          en: "Noted, lips sealed! 🤐 This gift is going to be perfect.",
          postAction: state.clearMascotMoment,
        ),
      ]);
    }
    if (state.mascotMoment == MascotMoment.inviteAccepted) {
      return _pick([
        MascotInsight(
          mood: PigMood.excited,
          fr: "Invitation acceptée ! 🎉 Ton cercle grandit !",
          en: "Invite accepted! 🎉 Your circle is growing!",
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.celebrating,
          fr: "Un nouveau proche sur Pigio ! 🥳 On fait la fête !",
          en: "A new person on Pigio! 🥳 Time to celebrate!",
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.love,
          fr: "Bienvenue dans le cercle ! 💛 Les surprises vont pleuvoir.",
          en: "Welcome to the circle! 💛 Surprises are coming.",
          postAction: state.clearMascotMoment,
        ),
      ]);
    }
    if (state.mascotMoment == MascotMoment.inviteSent) {
      return _pick([
        MascotInsight(
          mood: PigMood.thumbsUp,
          fr: "Invitation envoyée ! 📩 J'espère que ton proche rejoint vite Pigio.",
          en: "Invite sent! 📩 Hope your person joins Pigio soon.",
          actionLabelFr: 'Voir mon cercle',
          actionLabelEn: 'Open my circle',
          action: (st) => st.setTabIndex(3),
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.waving,
          fr: "C'est envoyé ! 💌 Croisons les doigts pour une réponse rapide !",
          en: "Sent! 💌 Fingers crossed for a quick reply!",
          actionLabelFr: 'Voir mon cercle',
          actionLabelEn: 'Open my circle',
          action: (st) => st.setTabIndex(3),
          postAction: state.clearMascotMoment,
        ),
      ]);
    }
    if (state.mascotMoment == MascotMoment.quizCompleted) {
      return _pick([
        MascotInsight(
          mood: PigMood.celebrating,
          fr: "Merci ! Je te connais mieux maintenant 🤗",
          en: "Thanks! Now I know you even better 🤗",
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.love,
          fr: "Wow, j'en sais plus sur toi ! 💛 On va faire une super équipe.",
          en: "Wow, I know more about you now! 💛 We'll make a great team.",
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.excited,
          fr: "Quiz terminé ! 🧠 Mes suggestions vont être bien meilleures.",
          en: "Quiz done! 🧠 My suggestions are about to get way better.",
          postAction: state.clearMascotMoment,
        ),
      ]);
    }
    if (state.mascotMoment == MascotMoment.bondLevelUp) {
      final emoji = state.mascotBondEmoji;
      final title = state.mascotBondTitle;
      final stageEmoji = state.mascotStageEmoji;
      final stageFr = state.mascotStageName;
      final stageEn = state.mascotStageNameEn;
      return _pick([
        MascotInsight(
          mood: PigMood.celebrating,
          fr: "ÉVOLUTION ! $stageEmoji Je suis maintenant $stageFr ! $emoji « $title » 🎉",
          en: "EVOLUTION! $stageEmoji I'm now $stageEn! $emoji \"$title\" 🎉",
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.love,
          fr: "$stageEmoji $stageFr ! Notre lien grandit — $emoji $title ! 💛",
          en: "$stageEmoji $stageEn! Our bond is growing — $emoji $title! 💛",
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.excited,
          fr: "$stageEmoji $stageFr ! Regarde comme j'ai changé ! $emoji $title 🚀",
          en: "$stageEmoji $stageEn! Look how I've changed! $emoji $title 🚀",
          postAction: state.clearMascotMoment,
        ),
      ]);
    }
    if (state.mascotMoment == MascotMoment.achievementUnlocked) {
      return _pick([
        MascotInsight(
          mood: PigMood.celebrating,
          fr: "Succès débloqué ! 🏆 Un nouvel accessoire t'attend dans la garde-robe !",
          en: "Achievement unlocked! 🏆 A new accessory awaits in the wardrobe!",
          actionLabelFr: 'Voir la garde-robe',
          actionLabelEn: 'Open wardrobe',
          action: (st) => st.setTabIndex(2),
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.excited,
          fr: "Bravo ! 🎖️ Tu as débloqué quelque chose de nouveau ! Viens voir !",
          en: "Bravo! 🎖️ You unlocked something new! Come check it out!",
          actionLabelFr: 'Découvrir',
          actionLabelEn: 'Discover',
          action: (st) => st.setTabIndex(2),
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.love,
          fr: "Oh ! ✨ Nouvel item débloqué ! J'ai hâte de l'essayer !",
          en: "Oh! ✨ New item unlocked! I can't wait to try it on!",
          actionLabelFr: 'Essayer',
          actionLabelEn: 'Try it on',
          action: (st) => st.setTabIndex(2),
          postAction: state.clearMascotMoment,
        ),
      ]);
    }
    if (state.mascotMoment == MascotMoment.busyMonth) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final busyContacts = state.events
          .where((e) {
            final occurrence = e.getOccurrenceForYear(nextMonth.year);
            return occurrence.month == nextMonth.month && e.contactId != null;
          })
          .map((e) => e.contactId)
          .whereType<String>()
          .toSet()
          .map((contactId) => state.contacts.where((c) => c.id == contactId).firstOrNull?.name)
          .whereType<String>()
          .take(3)
          .toList();
      final names = busyContacts.join(', ');
      return _pick([
        MascotInsight(
          mood: PigMood.thinking,
          fr: names.isEmpty
              ? "Quelques dates le mois prochain 📅"
              : "Des dates arrivent pour $names le mois prochain 📅",
          en: names.isEmpty
              ? "A few dates coming up next month 📅"
              : "Some dates coming up for $names next month 📅",
          actionLabelFr: 'Voir le calendrier',
          actionLabelEn: 'See calendar',
          action: (st) => st.setTabIndex(1),
          actionKey: 'open_wish_editor',
          postAction: state.clearMascotMoment,
        ),
        MascotInsight(
          mood: PigMood.waving,
          fr: names.isEmpty
              ? "Le mois prochain sera animé 🎉 Jette un œil au calendrier si tu veux."
              : "$names a des dates le mois prochain 🎉",
          en: names.isEmpty
              ? "Next month will be lively 🎉 Check the calendar if you'd like."
              : "$names has dates coming next month 🎉",
          actionLabelFr: 'Voir les dates',
          actionLabelEn: 'See dates',
          action: (st) => st.setTabIndex(1),
          actionKey: 'open_wish_editor',
          postAction: state.clearMascotMoment,
        ),
      ]);
    }
    if (state.mascotMoment == MascotMoment.circleStale) {
      state.clearMascotMoment();
    }

    // ── 2. CLOTHING REQUESTS (Outfit Engine override) ────────────────────────
    if (state.currentClothingRequest != null) {
      final req = state.currentClothingRequest!;
      return MascotInsight(
        mood: PigMood.excited,
        fr: req.bubbleTextFr,
        en: req.bubbleTextEn,
      );
    }

    // ── 3. RETURN MOOD — warm welcome back, no guilt ────────────────────────
    final absenceDays = state.mascotAbsenceDays;
    if (absenceDays >= 3) {
      final n = state.profile.name.isEmpty ? '' : ' ${state.profile.name}';
      return _pick([
        MascotInsight(mood: PigMood.waving, fr: "Coucou$n ! 👋 Contente de te revoir !", en: "Hey$n! 👋 Great to see you!"),
        MascotInsight(mood: PigMood.love, fr: "Oh$n ! 🐧💛 Ça fait plaisir !", en: "Oh$n! 🐧💛 Good to have you back!"),
        MascotInsight(mood: PigMood.excited, fr: "Hey$n ! 🎉 Quoi de neuf ?", en: "Hey$n! 🎉 What's new?"),
      ]);
    } else if (absenceDays >= 1) {
      final n = state.profile.name.isEmpty ? '' : ' ${state.profile.name}';
      return _pick([
        MascotInsight(mood: PigMood.excited, fr: "Te revoilà$n ! 🎉 Content de te revoir !", en: "You're back$n! 🎉 So happy to see you!"),
        MascotInsight(mood: PigMood.waving, fr: "Hey$n ! 👋 Quoi de neuf ?", en: "Hey$n! 👋 What's new?"),
        MascotInsight(mood: PigMood.love, fr: "Coucou$n ! 🐧💛", en: "Hi$n! 🐧💛"),
      ]);
    }

    // ── 4. URGENT BIRTHDAYS (Today only) — uses cached computation ───────────
    _refreshBirthdayCache(state, now);
    if (_cachedBirthdayDiff == 0 && _cachedBirthdayContactId != null) {
      final contact = state.contacts.where((c) => c.id == _cachedBirthdayContactId).firstOrNull;
      if (contact != null) {
        return _pick([
          MascotInsight(mood: PigMood.celebrating, fr: "C'est l'anniversaire de ${contact.name} ! 🎂🎉", en: "It's ${contact.name}'s birthday today! 🎂🎉"),
          MascotInsight(mood: PigMood.excited, fr: "🎂 Happy birthday ${contact.name} ! 🎉", en: "🎂 Happy birthday ${contact.name}! 🎉"),
          MascotInsight(mood: PigMood.love, fr: "Jour spécial pour ${contact.name} aujourd'hui ! 🥳💛", en: "Special day for ${contact.name} today! 🥳💛"),
        ]);
      }
    }

    // ── 5. TAB-SPECIFIC PRIORITY (Contextual Logic) ──────────────────────────
    final wishCount = state.wishes.where((w) => w.contactId == null).length;
    final contactCount = state.contacts.length;

    switch (tabIndex) {
      case 1: // WISHES TAB
        if (wishCount == 0) {
          return _pick([
            const MascotInsight(
              mood: PigMood.searching,
              fr: "Ta liste attend tes premières envies ✨",
              en: "Your list is waiting for your first ideas ✨",
              actionLabelFr: 'Ajouter une envie',
              actionLabelEn: 'Add a wish',
              actionKey: 'open_wish_editor',
            ),
            const MascotInsight(
              mood: PigMood.excited,
              fr: "Vide pour l'instant ! 📝 Dis-moi ce qui te ferait plaisir ?",
              en: "Empty for now! 📝 Tell me what would make you happy?",
              actionLabelFr: 'Ma première envie',
              actionLabelEn: 'My first wish',
              actionKey: 'open_wish_editor',
            ),
            const MascotInsight(
              mood: PigMood.thinking,
              fr: "Ta liste est prête quand tu veux 🤔 Pas de pression !",
              en: "Your list is ready when you are 🤔 No rush!",
              actionLabelFr: 'Ajouter',
              actionLabelEn: 'Add one',
              actionKey: 'open_wish_editor',
            ),
          ]);
        }
        break;
      case 2: // WARDROBE/SIZES TAB
        if (state.sizes.isEmpty) {
          return _pick([
            const MascotInsight(
              mood: PigMood.thinking,
              fr: "Pas de tailles ? 📏 Ajoute-les quand tu veux.",
              en: "No sizes yet? 📏 Add them when you're ready.",
              actionLabelFr: 'Ouvrir mes tailles',
              actionLabelEn: 'Open sizes',
              action: _goToSizesTab,
            ),
            const MascotInsight(
              mood: PigMood.waving,
              fr: "Tes proches ne devineront pas ta taille ! 👕 Note-la ici.",
              en: "Your people won't guess your size! 👕 Save it here.",
              actionLabelFr: 'Mes tailles',
              actionLabelEn: 'My sizes',
              action: _goToSizesTab,
            ),
          ]);
        }
        final stale = state.sizes.where((s) => s.contactId == null && now.difference(s.updatedAt).inDays > 120).toList();
        if (stale.isNotEmpty) {
          return _pick([
            const MascotInsight(
              mood: PigMood.searching,
              fr: "Tes tailles datent un peu... 📏 Un petit rafraîchissement ?",
              en: "Your sizes are a bit old... 📏 Time for an update?",
              actionLabelFr: 'Mettre à jour',
              actionLabelEn: 'Update sizes',
              action: _goToSizesTab,
            ),
            const MascotInsight(
              mood: PigMood.thinking,
              fr: "4 mois depuis ta dernière mise à jour 📏 Ça a peut-être changé !",
              en: "4 months since your last update 📏 Things might have changed!",
              actionLabelFr: 'Vérifier',
              actionLabelEn: 'Check now',
              action: _goToSizesTab,
            ),
          ]);
        }
        break;
      case 3: // CONTACTS TAB
        if (contactCount == 0) {
          return _pick([
            const MascotInsight(
              mood: PigMood.waving,
              fr: "Tu peux inviter tes proches ici 👥",
              en: "You can invite your people here 👥",
              actionLabelFr: 'Inviter',
              actionLabelEn: 'Invite',
              actionKey: 'open_invite_sheet',
            ),
            const MascotInsight(
              mood: PigMood.excited,
              fr: "Pigio fonctionne aussi à plusieurs ! 🎁 Envie d'inviter quelqu'un ?",
              en: "Pigio also works with others! 🎁 Want to invite someone?",
              actionLabelFr: 'Inviter',
              actionLabelEn: 'Invite',
              actionKey: 'open_invite_sheet',
            ),
          ]);
        }
        break;
    }

    // ── 6. SECONDARY GLOBAL ALERTS (Birthdays within 7 days) ─────────────────
    if (_cachedBirthdayDiff != null && _cachedBirthdayDiff! > 0 && _cachedBirthdayDiff! <= 7 && _cachedBirthdayContactId != null) {
      final contact = state.contacts.where((c) => c.id == _cachedBirthdayContactId).firstOrNull;
      if (contact != null) {
        final hasGift = state.wishes.any((w) => w.contactId == contact.id && w.reservedById != null);
        if (!hasGift) {
          final diff = _cachedBirthdayDiff!;
          return MascotInsight(
            mood: PigMood.excited,
            fr: "L'anniv de ${contact.name} approche dans $diff jours ! 🎂",
            en: "${contact.name}'s birthday is in $diff days! 🎂",
            triggersAI: true,
            actionLabelFr: 'Preparer une idee',
            actionLabelEn: 'Prep an idea',
            action: (st) => st.setTabIndex(1),
            actionKey: 'open_wish_editor',
            aiTask: (st) => AiService.generateGiftConcierge(contact, personalityContext: st.personalityProfileSummary),
          );
        }
      }
    }

    // ── 7. FIRST-VISIT TAB WELCOME (Once per session) ──────────────────────
    if (!_greetedTabs.contains(tabIndex)) {
      _greetedTabs.add(tabIndex);
      final welcome = _tabWelcome(tabIndex);
      if (welcome != null) return welcome;
    }

    // ── 8. GENERAL TAB-SPECIFIC MESSAGES (Fallback within Tab) ───────────────
    return _tabInsightFallback(tabIndex, state, now);
  }

  /// Refresh the birthday cache if stale (older than 60 seconds).
  static void _refreshBirthdayCache(PigioAppState state, DateTime now) {
    if (_birthdayCacheTime != null && now.difference(_birthdayCacheTime!).inSeconds < 60) return;
    _birthdayCacheTime = now;
    _cachedBirthdayContactId = null;
    _cachedBirthdayDiff = null;

    int? bestDiff;
    String? bestId;
    final today = DateTime(now.year, now.month, now.day);

    for (final contact in state.contacts) {
      final bd = _parseBirthdate(contact.birthdate);
      if (bd == null) continue;
      final next = _nextOccurrence(bd, now);
      final diff = next.difference(today).inDays;
      if (bestDiff == null || diff < bestDiff) {
        bestDiff = diff;
        bestId = contact.id;
      }
    }
    _cachedBirthdayDiff = bestDiff;
    _cachedBirthdayContactId = bestId;
  }

  /// Track last shown message hash to avoid repeating within 24h.
  static int? _lastPickedHash;
  static DateTime? _lastPickedAt;

  /// One-per-session tab welcome message.
  static MascotInsight? _tabWelcome(int tab) {
    switch (tab) {
      case 1: // WISHES
        return _pick([
          const MascotInsight(mood: PigMood.waving, fr: "Bienvenue dans tes envies ! 🎁 C'est ici que la magie commence.", en: "Welcome to your wishes! 🎁 This is where the magic starts."),
          const MascotInsight(mood: PigMood.excited, fr: "L'onglet envies ! ✨ Dis-moi tout ce qui te fait rêver.", en: "The wishes tab! ✨ Tell me everything you dream about."),
        ]);
      case 2: // WARDROBE / SIZES
        return _pick([
          const MascotInsight(mood: PigMood.thumbsUp, fr: "Ici c'est la garde-robe ! 👔 Tes tailles et mon dressing.", en: "This is the wardrobe! 👔 Your sizes and my closet."),
          const MascotInsight(mood: PigMood.waving, fr: "Bienvenue côté tailles ! 📏 Plus c'est précis, mieux c'est.", en: "Welcome to sizes! 📏 The more precise, the better."),
        ]);
      case 3: // CONTACTS
        return _pick([
          const MascotInsight(mood: PigMood.love, fr: "Ton cercle ! 👥💛 C'est ici que tu gères tes proches.", en: "Your circle! 👥💛 This is where you manage your people."),
          const MascotInsight(mood: PigMood.waving, fr: "L'espace contacts ! 🤝 Invite tes proches pour partager des idées.", en: "The contacts space! 🤝 Invite your people to share ideas."),
        ]);
      default:
        return null; // Home tab doesn't need a welcome (time greeting already handles it)
    }
  }

  static MascotInsight _tabInsightFallback(int tab, PigioAppState state, DateTime now) {
    List<MascotInsight> candidates;
    switch (tab) {
      case 0: // HOME
        candidates = _homeInsights(now.hour, state);
        break;
      case 1: // WISHES
        candidates = _wishInsights(state);
        break;
      case 2: // WARDROBE
        candidates = _wardrobeInsights(state);
        break;
      case 3: // CONTACTS
        candidates = _contactInsights(state);
        break;
      default:
        candidates = _timeGreetings(now.hour, state.profile.name);
    }
    return _pickDeduped(candidates);
  }

  /// Pick a message, avoiding the last-shown message if within 24h.
  static MascotInsight _pickDeduped(List<MascotInsight> list) {
    if (list.length <= 1) return list.first;
    final now = DateTime.now();
    // If last pick was within 24h, filter it out
    if (_lastPickedHash != null && _lastPickedAt != null &&
        now.difference(_lastPickedAt!).inHours < 24) {
      final filtered = list.where((i) => i.fr.hashCode != _lastPickedHash).toList();
      if (filtered.isNotEmpty) {
        final picked = _pick(filtered);
        _lastPickedHash = picked.fr.hashCode;
        _lastPickedAt = now;
        return picked;
      }
    }
    final picked = _pick(list);
    _lastPickedHash = picked.fr.hashCode;
    _lastPickedAt = now;
    return picked;
  }

  static List<MascotInsight> _homeInsights(int hour, PigioAppState state) {
    final greetings = _timeGreetings(hour, state.profile.name);
    final n = state.profile.name.isEmpty ? '' : ' ${state.profile.name}';
    // Delta-based reactions
    final contactCount = state.contacts.length;
    final wishCount = state.wishes.where((w) => w.contactId == null).length;
    final streak = state.loginStreak;
    return [
      ...greetings,
      // Streak celebrations
      if (streak == 7)
        MascotInsight(mood: PigMood.celebrating, fr: "Une semaine ensemble$n ! 🏆 Tu as débloqué le Trophée doré !", en: "A week together$n! 🏆 You unlocked the Golden Trophy!"),
      if (streak == 30)
        MascotInsight(mood: PigMood.celebrating, fr: "Un mois$n ! ⭐ Tu as débloqué les Lunettes étoile !", en: "One month$n! ⭐ You unlocked the Star Glasses!"),
      if (contactCount > 0)
        MascotInsight(mood: PigMood.love, fr: "Ton réseau compte $contactCount proches 💛 C'est chouette !", en: "Your network has $contactCount people 💛 That's awesome!"),
      if (wishCount > 3)
        MascotInsight(mood: PigMood.thumbsUp, fr: "$wishCount envies sur ta liste 🎯 Tu sais ce que tu veux !", en: "$wishCount wishes on your list 🎯 You know what you want!"),
      MascotInsight(
        mood: PigMood.excited,
        fr: "J'ai préparé ta tenue du jour ! 👔 Va voir dans la garde-robe.",
        en: "I prepared your outfit of the day! 👔 Check the wardrobe.",
        actionKey: 'wardrobe',
      ),
      // Limited-time drop awareness
      if (MascotOutfitEngine.seasonalDrops(DateTime.now()).isNotEmpty)
        MascotInsight(mood: PigMood.excited, fr: "Il y a des objets en édition limitée dans la garde-robe ! ⏳", en: "There are limited-edition items in the wardrobe! ⏳", actionKey: 'wardrobe'),
      if (MascotOutfitEngine.expiringSoon(DateTime.now()).isNotEmpty)
        MascotInsight(mood: PigMood.searching, fr: "Dépêche-toi$n ! Des objets limités expirent bientôt ! 🔥", en: "Hurry$n! Limited items expiring soon! 🔥", actionKey: 'wardrobe'),
      MascotInsight(mood: PigMood.thinking, fr: "Un cadeau à trouver$n ? Je peux t'aider ! 🎁", en: "Need to find a gift$n? I can help! 🎁"),
      MascotInsight(mood: PigMood.waving, fr: "Hey$n ! 🐧 Quoi de beau aujourd'hui ?", en: "Hey$n! 🐧 What's good today?"),
      MascotInsight(mood: PigMood.excited, fr: "Bonne humeur$n ! 🌈 Belle journée en vue.", en: "Good vibes$n! 🌈 Looks like a great day."),
      // Mood-aware messages
      if (state.userMood == 'sad')
        MascotInsight(mood: PigMood.love, fr: "💛 Je suis là pour toi$n. Un câlin virtuel ?", en: "💛 I'm here for you$n. Virtual hug?"),
      if (state.userMood == 'tired')
        MascotInsight(mood: PigMood.sleeping, fr: "😴 Repose-toi$n. Tu le mérites.", en: "😴 Take it easy$n. You deserve it."),
      if (state.userMood == 'energetic')
        MascotInsight(mood: PigMood.excited, fr: "⚡ On est en feu$n ! Habille-moi pour l'aventure !", en: "⚡ We're on fire$n! Dress me for adventure!", actionKey: 'wardrobe'),
      if (state.userMood == 'happy')
        MascotInsight(mood: PigMood.celebrating, fr: "😊 Top$n ! Profitons de cette belle énergie !", en: "😊 Awesome$n! Let's ride this good energy!"),
    ];
  }

  static List<MascotInsight> _wishInsights(PigioAppState state) {
    final highPriority = state.wishes.where((w) => w.contactId == null && w.priority == WishPriority.high).length;
    final totalWishes = state.wishes.where((w) => w.contactId == null).length;
    return [
      if (highPriority > 0)
        MascotInsight(mood: PigMood.love, fr: "Tu as $highPriority vœux prioritaires ! 🔥 J'espère qu'ils arriveront vite.", en: "You have $highPriority top wishes! 🔥 Hope they arrive soon."),
      const MascotInsight(mood: PigMood.thumbsUp, fr: "Ta liste d'envies est en forme ! ✨", en: "Your wish list is looking good! ✨"),
      const MascotInsight(mood: PigMood.searching, fr: "Une nouvelle idée ? 💡 Tu peux l'ajouter quand tu veux.", en: "New idea? 💡 You can add it anytime."),
      const MascotInsight(mood: PigMood.thinking, fr: "Des envies pour toutes les occasions 🎁 Bien joué !", en: "Wishes for every occasion 🎁 Well done!"),
      if (totalWishes >= 5)
        MascotInsight(mood: PigMood.excited, fr: "$totalWishes envies déjà ! 🎯 Tu inspires tes proches.", en: "$totalWishes wishes already! 🎯 You're inspiring your people."),
      const MascotInsight(mood: PigMood.waving, fr: "Pense à ajouter des liens ou des photos 📸 Ça aide !", en: "Try adding links or photos 📸 It helps!"),
    ];
  }

  static List<MascotInsight> _wardrobeInsights(PigioAppState state) {
    final sizeCount = state.sizes.where((s) => s.contactId == null).length;
    return [
      MascotInsight(mood: PigMood.thumbsUp, fr: "$sizeCount catégories de tailles enregistrées. ✅ Propre !", en: "$sizeCount size categories saved. ✅ Looking good!"),
      const MascotInsight(mood: PigMood.thinking, fr: "Des tailles à jour = des cadeaux qui vont bien 👔", en: "Up-to-date sizes = gifts that fit perfectly 👔"),
      const MascotInsight(mood: PigMood.searching, fr: "Tu as changé de taille récemment ? 📏 Mets à jour !", en: "Changed size recently? 📏 Time to update!"),
      const MascotInsight(mood: PigMood.waving, fr: "Les tailles, c'est le secret des cadeaux parfaits 🎯", en: "Sizes are the secret to perfect gifts 🎯"),
    ];
  }

  static List<MascotInsight> _contactInsights(PigioAppState state) {
    final familyCount = state.contacts.where((c) => c.isFamily).length;
    final totalContacts = state.contacts.length;
    return [
      MascotInsight(mood: PigMood.love, fr: "Déjà $familyCount membres dans ta famille ! 💛 Belle équipe.", en: "$familyCount family members joined! 💛 Great team."),
      if (totalContacts > 0)
        MascotInsight(mood: PigMood.thumbsUp, fr: "$totalContacts proches dans ton réseau 🤗 Génial !", en: "$totalContacts people in your network 🤗 Great!"),
      const MascotInsight(mood: PigMood.waving, fr: "Invite tes proches pour échanger des idées cadeaux 🎁", en: "Invite your loved ones to share gift ideas 🎁"),
      const MascotInsight(mood: PigMood.excited, fr: "Plus on est de fous, plus on se gâte ! 🥳", en: "The more the merrier! 🥳"),
      const MascotInsight(mood: PigMood.thinking, fr: "Un ami qui rejoint = des idées cadeaux en plus 💡", en: "A friend who joins = more gift ideas 💡"),
    ];
  }

  // ─── HELPERS ────────────────────────────────────────────────────────────
  static DateTime? _parseBirthdate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('/');
    if (parts.length < 2) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (d == null || m == null) return null;
    return DateTime(2000, m, d);
  }

  static DateTime _nextOccurrence(DateTime date, DateTime now) {
    DateTime next = DateTime(now.year, date.month, date.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next = DateTime(now.year + 1, date.month, date.day);
    }
    return next;
  }

  static T _pick<T>(List<T> list) => list[_rng.nextInt(list.length)];

  static void _goToSizesTab(PigioAppState state) => state.setTabIndex(2);

  static List<MascotInsight> _timeGreetings(int hour, String name) {
    final n = name.isEmpty ? '' : ' $name';
    if (hour < 5) {
      // Night owl — playful surprise at seeing the user this late/early
      return [
        MascotInsight(mood: PigMood.sleeping, fr: "*bâille*$n... 🦉 Tu es un vrai oiseau de nuit !", en: "*yawns*$n... 🦉 You're a true night owl!"),
        MascotInsight(mood: PigMood.thinking, fr: "Il est ${hour}h$n... 🌙 On dort pas par ici ?", en: "It's ${hour}am$n... 🌙 No sleeping around here?"),
        MascotInsight(mood: PigMood.love, fr: "Les étoiles brillent$n ✨ Et toi aussi, même à cette heure.", en: "The stars are shining$n ✨ And so are you, even at this hour."),
        MascotInsight(mood: PigMood.waving, fr: "Psst$n ! 🤫 Tout le monde dort sauf nous deux...", en: "Psst$n! 🤫 Everyone's asleep except us two..."),
      ];
    } else if (hour < 7) {
      // Early bird — impressed and energetic
      return [
        MascotInsight(mood: PigMood.excited, fr: "Debout avant tout le monde$n ! 🐦 Quel(le) champion(ne) !", en: "Up before everyone$n! 🐦 What a champion!"),
        MascotInsight(mood: PigMood.thumbsUp, fr: "L'avenir appartient à ceux qui se lèvent tôt$n ! ☀️", en: "The early bird catches the worm$n! ☀️"),
        MascotInsight(mood: PigMood.waving, fr: "Coucou$n ! 🌅 Le soleil se lève et toi aussi !", en: "Hey$n! 🌅 The sun is rising and so are you!"),
        MascotInsight(mood: PigMood.love, fr: "Bonjour$n ! 🌄 Ces moments calmes du matin sont les meilleurs.", en: "Good morning$n! 🌄 These quiet morning moments are the best."),
      ];
    } else if (hour < 9) {
      return [
        MascotInsight(mood: PigMood.waving, fr: "Coucou$n ! ☀️ Prêt pour une belle journée ?", en: "Hey$n! ☀️ Ready for a great day?"),
        MascotInsight(mood: PigMood.excited, fr: "Tôt debout$n ! 🐦 Belle énergie ce matin !", en: "Early bird$n! 🐦 Great energy this morning!"),
        MascotInsight(mood: PigMood.love, fr: "Bonjour$n ! 🌅 Le monde t'appartient ce matin.", en: "Good morning$n! 🌅 The world is yours this morning."),
        MascotInsight(mood: PigMood.thumbsUp, fr: "Debout$n ! ☕ Un café et on attaque !", en: "Rise and shine$n! ☕ Coffee and let's go!"),
      ];
    } else if (hour < 12) {
      return [
        MascotInsight(mood: PigMood.waving, fr: "Bonjour$n ! 🌟 Quoi de neuf dans ton Réseau ?", en: "Morning$n! 🌟 What's new in your Network?"),
        MascotInsight(mood: PigMood.thumbsUp, fr: "Belle matinée$n ! ☀️ Bonne humeur au programme.", en: "Beautiful morning$n! ☀️ Good vibes today."),
        MascotInsight(mood: PigMood.searching, fr: "Salut$n ! 🔍 Des anniversaires à préparer ?", en: "Hi$n! 🔍 Any birthdays coming up?"),
        MascotInsight(mood: PigMood.thinking, fr: "La matinée avance$n ! ⏰ Un vœu à ajouter ?", en: "Morning's moving$n! ⏰ Any wish to add?"),
      ];
    } else if (hour < 14) {
      return [
        MascotInsight(mood: PigMood.love, fr: "Bon appétit$n ! 🍽️", en: "Enjoy your lunch$n! 🍽️"),
        MascotInsight(mood: PigMood.waving, fr: "Pause déjeuner$n ? 🥗 Régale-toi !", en: "Lunch break$n? 🥗 Enjoy!"),
        MascotInsight(mood: PigMood.thumbsUp, fr: "Midi$n ! 🌞 La journée est bien partie.", en: "Noon$n! 🌞 The day is going well."),
      ];
    } else if (hour < 18) {
      return [
        MascotInsight(mood: PigMood.excited, fr: "Bon après-midi$n ! 🎯 Ça roule ?", en: "Good afternoon$n! 🎯 How's it going?"),
        MascotInsight(mood: PigMood.searching, fr: "Un moment tranquille$n ? 😌 Profite bien !", en: "A quiet moment$n? 😌 Enjoy it!"),
        MascotInsight(mood: PigMood.thinking, fr: "L'après-midi file$n... 🕐 Un cadeau à préparer ?", en: "Afternoon's flying$n... 🕐 Any gift to prep?"),
        MascotInsight(mood: PigMood.waving, fr: "Coucou$n ! 👋 Je suis là si tu as besoin.", en: "Hey$n! 👋 I'm here if you need me."),
        MascotInsight(mood: PigMood.love, fr: "Belle journée$n ! 🌤️ De quoi as-tu envie ?", en: "Lovely day$n! 🌤️ What are you wishing for?"),
      ];
    } else if (hour < 23) {
      return [
        MascotInsight(mood: PigMood.waving, fr: "Bonne soirée$n ! 🌙 Repose-toi bien.", en: "Good evening$n! 🌙 Have a restful night."),
        MascotInsight(mood: PigMood.love, fr: "Soirée tranquille$n ? 🛋️ Tu le mérites.", en: "Quiet evening$n? 🛋️ You deserve it."),
        MascotInsight(mood: PigMood.thinking, fr: "Fin de journée$n ! 🌙 Bilan positif j'espère ?", en: "End of the day$n! 🌙 Positive wrap-up?"),
        MascotInsight(mood: PigMood.thumbsUp, fr: "Bonsoir$n ! ✨ À demain pour de nouvelles aventures.", en: "Evening$n! ✨ See you tomorrow for new adventures."),
      ];
    } else {
      // Late night (23:00+) — cozy wind-down with personality
      return [
        MascotInsight(mood: PigMood.sleeping, fr: "Zzz... 😴 Oh, tu es encore là$n ? Moi aussi alors.", en: "Zzz... 😴 Oh, you're still here$n? Then so am I."),
        MascotInsight(mood: PigMood.love, fr: "Nuit nuit$n 🌙💛 Les meilleurs moments sont les plus calmes.", en: "Night night$n 🌙💛 The best moments are the quietest."),
        MascotInsight(mood: PigMood.thinking, fr: "Minuit approche$n... 🕐 Une dernière idée cadeau avant de dormir ?", en: "Midnight's coming$n... 🕐 One last gift idea before bed?"),
        MascotInsight(mood: PigMood.waving, fr: "Toujours debout$n ? 🦉 Moi je tombe de sommeil...", en: "Still up$n? 🦉 I'm falling asleep over here..."),
      ];
    }
  }
}
