import 'dart:math' as math;
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/shared/widgets/pigio_painter.dart';
import 'ai_service.dart';

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

  /// Nearest birthday cache to avoid O(n) iteration per call.
  static String? _cachedBirthdayContactId;
  static int? _cachedBirthdayDiff;
  static DateTime? _birthdayCacheTime;

  /// Pick the best insight. Side-effects are returned as [postAction] and [aiTask]
  /// on the result — the CALLER is responsible for executing them, not this method.
  static MascotInsight pick(PigioAppState state, int tabIndex) {
    final now = DateTime.now();

    // ── 1. INSTANT FEEDBACK MOMENTS (Highest Priority) ───────────────────────
    if (state.mascotMoment == MascotMoment.firstWish) {
      return MascotInsight(
        mood: PigMood.celebrating,
        fr: "Premier vœu ! 🎁 C'est le début du bonheur !",
        en: "First wish added! 🎁 The start of something great!",
        postAction: state.clearMascotMoment,
      );
    }
    if (state.mascotMoment == MascotMoment.wishReserved) {
      return MascotInsight(
        mood: PigMood.thumbsUp,
        fr: "Cadeau réservé ! 🤫 Chut, c'est un secret...",
        en: "Gift reserved! 🤫 Shhh, it's a secret...",
        postAction: state.clearMascotMoment,
      );
    }
    if (state.mascotMoment == MascotMoment.inviteAccepted) {
      return MascotInsight(
        mood: PigMood.excited,
        fr: "Invitation acceptée ! 🎉 Ton cercle grandit !",
        en: "Invite accepted! 🎉 Your circle is growing!",
        postAction: state.clearMascotMoment,
      );
    }
    if (state.mascotMoment == MascotMoment.inviteSent) {
      return MascotInsight(
        mood: PigMood.thumbsUp,
        fr: "Invitation envoyee ! 📩 J'espere que ton proche rejoint vite Pigio.",
        en: "Invite sent! 📩 Hope your person joins Pigio soon.",
        actionLabelFr: 'Voir mon cercle',
        actionLabelEn: 'Open my circle',
        action: (st) => st.setTabIndex(3),
        postAction: state.clearMascotMoment,
      );
    }
    if (state.mascotMoment == MascotMoment.quizCompleted) {
      return MascotInsight(
        mood: PigMood.celebrating,
        fr: "Merci ! Je te connais mieux maintenant 🤗",
        en: "Thanks! Now I know you even better 🤗",
        postAction: state.clearMascotMoment,
      );
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
      return MascotInsight(
        mood: PigMood.thinking,
        fr: names.isEmpty
            ? "Le mois prochain s'annonce charge 📅 On prepare quelques cadeaux d'avance ?"
            : "Le mois prochain sera dense pour $names 📅 On prend de l'avance ?",
        en: names.isEmpty
            ? "Next month looks busy 📅 Want to prep a few gifts ahead of time?"
            : "Next month will be busy for $names 📅 Want to get ahead?",
        actionLabelFr: 'Preparer mes cadeaux',
        actionLabelEn: 'Prep gifts',
        action: (st) => st.setTabIndex(1),
        actionKey: 'open_wish_editor',
        postAction: state.clearMascotMoment,
      );
    }
    if (state.mascotMoment == MascotMoment.circleStale) {
      final staleNames = state.contacts
          .where((c) =>
              c.status == ContactStatus.joined &&
              !state.wishes.any((w) => w.contactId == c.id) &&
              !state.sizes.any((s) => s.contactId == c.id))
          .map((c) => c.name)
          .take(3)
          .toList();
      final names = staleNames.join(', ');
      return MascotInsight(
        mood: PigMood.thinking,
        fr: "Ton cercle s'endort 💤 $names n'a pas encore de liste. Un petit rappel ?",
        en: "Your circle is sleepy 💤 $names hasn't set up a list yet. A gentle nudge?",
        actionLabelFr: 'Voir mon cercle',
        actionLabelEn: 'Open my circle',
        action: (st) => st.setTabIndex(3),
        postAction: state.clearMascotMoment,
      );
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

    // ── 3. RETURN MOOD — greet based on absence duration ─────────────────────
    final absenceDays = state.mascotAbsenceDays;
    if (absenceDays >= 3) {
      final n = state.profile.name.isEmpty ? '' : ' ${state.profile.name}';
      return MascotInsight(
        mood: PigMood.sad,
        fr: "Tu m'as manqué$n... 😢 Ça fait $absenceDays jours !",
        en: "I missed you$n... 😢 It's been $absenceDays days!",
      );
    } else if (absenceDays >= 1) {
      final n = state.profile.name.isEmpty ? '' : ' ${state.profile.name}';
      return MascotInsight(
        mood: PigMood.excited,
        fr: "Te revoilà$n ! 🎉 Content de te revoir !",
        en: "You're back$n! 🎉 So happy to see you!",
      );
    }

    // ── 4. URGENT BIRTHDAYS (Today only) — uses cached computation ───────────
    _refreshBirthdayCache(state, now);
    if (_cachedBirthdayDiff == 0 && _cachedBirthdayContactId != null) {
      final contact = state.contacts.where((c) => c.id == _cachedBirthdayContactId).firstOrNull;
      if (contact != null) {
        return MascotInsight(
          mood: PigMood.celebrating,
          fr: "C'est l'anniversaire de ${contact.name} ! 🎂🎉",
          en: "It's ${contact.name}'s birthday today! 🎂🎉",
        );
      }
    }

    // ── 5. TAB-SPECIFIC PRIORITY (Contextual Logic) ──────────────────────────
    final wishCount = state.wishes.where((w) => w.contactId == null).length;
    final contactCount = state.contacts.length;

    switch (tabIndex) {
      case 1: // WISHES TAB
        if (wishCount == 0) {
          return const MascotInsight(
            mood: PigMood.searching,
            fr: "Ta liste attend tes premières envies ✨",
            en: "Your list is waiting for your first ideas ✨",
            actionLabelFr: 'Ajouter une envie',
            actionLabelEn: 'Add a wish',
            actionKey: 'open_wish_editor',
          );
        }
        break;
      case 2: // WARDROBE/SIZES TAB
        if (state.sizes.isEmpty) {
          return const MascotInsight(
            mood: PigMood.thinking,
            fr: "Pas de tailles ? 📏 Ajoute-les quand tu veux.",
            en: "No sizes yet? 📏 Add them when you're ready.",
            actionLabelFr: 'Ouvrir mes tailles',
            actionLabelEn: 'Open sizes',
            action: _goToSizesTab,
          );
        }
        final stale = state.sizes.where((s) => s.contactId == null && now.difference(s.updatedAt).inDays > 120).toList();
        if (stale.isNotEmpty) {
          return const MascotInsight(
            mood: PigMood.searching,
            fr: "Tes tailles datent un peu... 📏 Un petit rafraîchissement ?",
            en: "Your sizes are a bit old... 📏 Time for an update?",
            actionLabelFr: 'Mettre a jour',
            actionLabelEn: 'Update sizes',
            action: _goToSizesTab,
          );
        }
        break;
      case 3: // CONTACTS TAB
        if (contactCount == 0) {
          return const MascotInsight(
            mood: PigMood.waving,
            fr: "Tout seul ? 👥 Invite ta famille et tes amis !",
            en: "All alone? 👥 Invite your family and friends!",
            actionLabelFr: 'Inviter',
            actionLabelEn: 'Invite',
            actionKey: 'open_invite_sheet',
          );
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

    // ── 7. GENERAL TAB-SPECIFIC MESSAGES (Fallback within Tab) ───────────────
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

  static MascotInsight _tabInsightFallback(int tab, PigioAppState state, DateTime now) {
    switch (tab) {
      case 0: // HOME
        final greetings = _timeGreetings(now.hour, state.profile.name);
        return _pick(greetings);
      case 1: // WISHES
        final highPriority = state.wishes.where((w) => w.contactId == null && w.priority == WishPriority.high).length;
        if (highPriority > 0) {
          return MascotInsight(
            mood: PigMood.love,
            fr: "Tu as $highPriority vœux prioritaires ! 🔥 J'espère qu'ils arriveront vite.",
            en: "You have $highPriority top wishes! 🔥 Hope they arrive soon.",
          );
        }
        return const MascotInsight(
          mood: PigMood.thumbsUp,
          fr: "Ta liste d'envies est prête ! ✨ N'hésite pas à la partager.",
          en: "Your wish list is ready! ✨ Don't forget to share it.",
        );
      case 2: // WARDROBE
        final sizeCount = state.sizes.where((s) => s.contactId == null).length;
        return MascotInsight(
          mood: PigMood.thumbsUp,
          fr: "$sizeCount catégories de tailles enregistrées. ✅ Propre !",
          en: "$sizeCount size categories saved. ✅ Looking good!",
        );
      case 3: // CONTACTS
        final familyCount = state.contacts.where((c) => c.isFamily).length;
        return MascotInsight(
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
    if (hour < 9) {
      return [
        MascotInsight(mood: PigMood.waving, fr: "Coucou$n ! ☀️ Prêt pour une belle journée ?", en: "Hey$n! ☀️ Ready for a great day?"),
        MascotInsight(mood: PigMood.excited, fr: "Tôt debout$n ! 🐦 Belle énergie ce matin !", en: "Early bird$n! 🐦 Great energy this morning!"),
      ];
    } else if (hour < 12) {
      return [
        MascotInsight(mood: PigMood.waving, fr: "Bonjour$n ! 🌟 Quoi de neuf dans ton Réseau ?", en: "Morning$n! 🌟 What's new in your Network?"),
        MascotInsight(mood: PigMood.thumbsUp, fr: "Belle matinée$n ! ☀️ Bonne humeur au programme.", en: "Beautiful morning$n! ☀️ Good vibes today."),
      ];
    } else if (hour < 14) {
      return [
        MascotInsight(mood: PigMood.love, fr: "Bon appétit$n ! 🍽️", en: "Enjoy your lunch$n! 🍽️"),
      ];
    } else if (hour < 18) {
      return [
        MascotInsight(mood: PigMood.excited, fr: "Bon après-midi$n ! 🎯 Ça roule ?", en: "Good afternoon$n! 🎯 How's it going?"),
        MascotInsight(mood: PigMood.searching, fr: "Un moment tranquille$n ? 😌 Profite bien !", en: "A quiet moment$n? 😌 Enjoy it!"),
      ];
    } else {
      return [
        MascotInsight(mood: PigMood.waving, fr: "Bonne soirée$n ! 🌙 Repose-toi bien.", en: "Good evening$n! 🌙 Have a restful night."),
      ];
    }
  }
}
