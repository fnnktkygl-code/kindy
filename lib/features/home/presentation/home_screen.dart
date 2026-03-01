import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import '../../../shared/widgets/ui_widgets.dart';
import 'package:pigio_app/screens/contacts/sheets/add_profile_sheet.dart';
import 'package:pigio_app/features/contacts/presentation/contact_profile_screen.dart';
import 'package:pigio_app/screens/activity/activity_history_screen.dart';
import 'package:pigio_app/screens/wishes/sheets/wish_editor_sheet.dart';
import 'package:pigio_app/screens/events/sheets/add_event_sheet.dart';
import 'package:pigio_app/screens/groups/sheets/add_group_sheet.dart';
import '../../../shared/widgets/invite_bottom_sheet.dart';
import 'widgets/home_header.dart';
import 'widgets/home_upcoming_section.dart';
import 'widgets/home_quick_actions_section.dart';
import 'widgets/home_network_section.dart';
import 'widgets/home_family_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PigioAppState>(context);
    final theme = context.pt;
    final lang = state.locale.languageCode;
    final events = state.getUpcomingEvents();


    return Scaffold(
      backgroundColor: theme.scaffold,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeHeader(
                displayName: state.profile.name,
                avatarIcon: state.profile.avatarIcon,
                avatarColor: state.profile.avatarColor,
                unseenLogsCount: state.unseenLogsCount,
                theme: theme,
                onOpenDrawer: () => Scaffold.of(context).openDrawer(),
                onOpenActivity: () {
                  final currentCount = state.unseenLogsCount;
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityHistoryScreen(initialUnseenCount: currentCount)));
                  state.clearUnseenLogs();
                },
              ),
              HomeUpcomingSection(
                events: events,
                lang: lang,
                theme: theme,
                buildEventCountdown: (days, isFirst, isToday, isTomorrow, event) =>
                    _buildEventCountdown(days, isFirst, isToday, isTomorrow, event, theme, lang, context),
              ),

                HomeQuickActionsSection(
                  theme: theme,
                  onAddWish: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => WishEditorSheet(contactId: null, state: state),
                  ),
                  onAddEvent: () => showAddEventSheet(context),
                  onAddContact: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddProfileSheet(),
                  ),
                  onInvite: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const InviteBottomSheet(),
                  ),
                  onAddGroup: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddGroupSheet(),
                  ),
                ),

                HomeNetworkSection(
                  state: state,
                  theme: theme,
                  onSeeAllContacts: () {
                    state.setContactsSubIndex(0);
                    state.setTabIndex(3);
                  },
                  onManageGroups: () {
                    state.setContactsSubIndex(1);
                    state.setTabIndex(3);
                  },
                  onCreateContact: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddProfileSheet(),
                  ),
                  onInviteContact: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const InviteBottomSheet(),
                  ),
                  onCreateGroup: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const AddGroupSheet(),
                  ),
                  onOpenContact: (contact) {
                    state.recordProfileView(contact.id);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ContactProfileScreen(contact: contact)));
                  },
                  onInviteToGroup: (group) => _showInviteToGroupSheet(context, group, state, theme),
                ),
                const SizedBox(height: 20),
                HomeFamilySection(
                  state: state,
                  theme: theme,
                  onOpenSummary: (contact) => _showContactSummary(context, contact, state, theme),
                  onSeeAllMembers: () {
                    state.setContactsSubIndex(0);
                    state.setTabIndex(3);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── EVENT COUNTDOWN DISPLAY ─────────────────────────────────────────────

  /// Returns a human-layered countdown widget based on how many days remain.
  Widget _buildEventCountdown(
    int days,
    bool isFirst,
    bool isToday,
    bool isTomorrow,
    Event e,
    PigioThemeData theme,
    String lang,
    BuildContext context,
  ) {
    final Color accentColor = isFirst ? theme.onAccent : e.color;
    final Color mutedColor = isFirst ? theme.onAccent.withValues(alpha: 0.6) : theme.mid;
    final bool isFr = lang == 'fr';

    // ── TODAY ──────────────────────────────────────────────────────────────
    if (isToday) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🎉",
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(
            isFr ? "C'est aujourd'hui !" : "It's today!",
            style: fw(size: 13, w: FontWeight.w900, color: accentColor, height: 1.2),
          ),
        ],
      );
    }

    // ── TOMORROW ──────────────────────────────────────────────────────────
    if (isTomorrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFr ? "Demain !" : "Tomorrow!",
            style: fw(size: 22, w: FontWeight.w900, color: accentColor),
          ),
          Text(
            isFr ? "⚡ Prépare-toi" : "⚡ Get ready",
            style: fw(size: 11, color: mutedColor),
          ),
        ],
      );
    }

    // ── VERY SOON (2–6 days) ───────────────────────────────────────────────
    if (days <= 6) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text("$days", style: fw(size: 30, w: FontWeight.w900, color: accentColor)),
              const SizedBox(width: 4),
              Text(isFr ? "j." : "d.", style: fw(size: 14, w: FontWeight.w700, color: mutedColor)),
            ],
          ),
          Text(
            isFr ? "🔥 Bientôt !" : "🔥 Coming up!",
            style: fw(size: 11, color: mutedColor),
          ),
        ],
      );
    }

    // ── NEARBY (7–14 days) ─────────────────────────────────────────────────
    if (days <= 14) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text("$days", style: fw(size: 30, w: FontWeight.w900, color: accentColor)),
              const SizedBox(width: 4),
              Text(isFr ? "jours" : "days", style: fw(size: 13, w: FontWeight.w600, color: mutedColor)),
            ],
          ),
          Text(
            isFr ? "📅 Cette semaine" : "📅 This week",
            style: fw(size: 11, color: mutedColor),
          ),
        ],
      );
    }

    // ── APPROACHING (15–59 days) ───────────────────────────────────────────
    if (days <= 59) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text("$days", style: fw(size: 30, w: FontWeight.w900, color: accentColor)),
          const SizedBox(width: 4),
          Text(isFr ? "jours" : "days", style: fw(size: 13, w: FontWeight.w600, color: mutedColor)),
        ],
      );
    }

    // ── FAR (60–179 days → show weeks) ────────────────────────────────────
    if (days <= 179) {
      final weeks = (days / 7).round();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text("$weeks", style: fw(size: 30, w: FontWeight.w900, color: accentColor)),
          const SizedBox(width: 4),
          Text(isFr ? "sem." : "wks", style: fw(size: 13, w: FontWeight.w600, color: mutedColor)),
        ],
      );
    }

    // ── VERY FAR (180+ days → show months) ────────────────────────────────
    final months = (days / 30.5).round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text("$months", style: fw(size: 30, w: FontWeight.w900, color: accentColor)),
        const SizedBox(width: 4),
        Text(isFr ? "mois" : "mo.", style: fw(size: 13, w: FontWeight.w600, color: mutedColor)),
      ],
    );
  }

  void _showInviteToGroupSheet(BuildContext context, CircleGroup group, PigioAppState state, PigioThemeData theme) {
    final nonMembers = state.contacts.where((c) => !group.contactIds.contains(c.id)).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        decoration: BoxDecoration(color: theme.sheet, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.light.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(group.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(child: Text("Inviter dans ${group.name}", style: fw(size: 18, w: FontWeight.w900, color: theme.ink))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              nonMembers.isEmpty ? "Tous vos contacts sont déjà membres." : "Ajoute un contact existant ou invite quelqu'un de nouveau.",
              style: fw(size: 13, color: theme.mid),
            ),
            const SizedBox(height: 20),
            // Invite new person button
            PigioButton(
              label: "📩  Inviter un nouveau proche",
              color: theme.primary,
              textColor: theme.onAccent,
              height: 52,
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const InviteBottomSheet(),
                );
              },
            ),
            if (nonMembers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text("Ou depuis vos contacts :", style: fw(size: 12, w: FontWeight.w700, color: theme.mid)),
              const SizedBox(height: 8),
              ...nonMembers.take(5).map((c) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: PigioAvatar(name: c.name, size: 42, avatarIcon: c.avatarIcon, avatarColor: c.avatarColor, ringColor: c.color),
                title: Text(c.name, style: fw(size: 14, w: FontWeight.w700, color: theme.ink)),
                subtitle: Text(c.role, style: fw(size: 12, color: theme.mid)),
                trailing: GestureDetector(
                  onTap: () {
                    state.addContactToGroup(group.id, c.id);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: theme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text("Ajouter", style: fw(size: 12, w: FontWeight.w800, color: theme.success)),
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  void _showContactSummary(BuildContext context, ContactProfile contact, PigioAppState state, PigioThemeData theme) {
    final sizes = state.getVisibleSizesFor(contact.id, viewerTrustLevel: contact.trustLevel);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: theme.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.light.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                PigioAvatar(
                  name: contact.avatarName,
                  size: 64,
                  ringColor: contact.color,
                  avatarIcon: contact.avatarIcon,
                  avatarColor: contact.avatarColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(contact.name, style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
                          if (contact.isFamily) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.verified_user, size: 18, color: theme.success),
                          ]
                        ],
                      ),
                      Text(contact.role, style: fw(size: 14, w: FontWeight.w600, color: theme.mid)),
                    ],
                  ),
                ),
                if (contact.birthdate != null && !contact.hideBirthdate)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: theme.accent2.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        const Text("🎂", style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(contact.birthdate!, style: fw(size: 11, w: FontWeight.w800, color: theme.accent2)),
                      ],
                    ),
                  )
              ],
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(child: _summaryCard(ctx, "Hauts", _getVal(sizes, 'clothes'), theme.primary)),
                const SizedBox(width: 12),
                Expanded(child: _summaryCard(ctx, "Bas", _getVal(sizes, 'bottoms'), theme.success)),
                const SizedBox(width: 12),
                Expanded(child: _summaryCard(ctx, "Pieds", _getVal(sizes, 'shoes'), theme.accent3)),
              ],
            ),
            const SizedBox(height: 32),
            PigioButton(
              label: "Voir le profil complet",
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ContactProfileScreen(contact: contact)));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getVal(List<SizeProfile> profiles, String key) {
    final p = profiles.where((s) => s.categoryKey == key).firstOrNull;
    if (p == null) return "-";

    List<String> values = [];
    if (key == 'clothes') {
      if (p.values['standard'] != null) values.add(p.values['standard']!);
      if (p.values['eu_clothes'] != null) values.add(p.values['eu_clothes']!);
    } else if (key == 'bottoms') {
      if (p.values['eu_bottoms'] != null) values.add(p.values['eu_bottoms']!);
      if (p.values['us_waist'] != null && p.values['us_length'] != null) {
        values.add("W${p.values['us_waist']} L${p.values['us_length']}");
      } else if (p.values['us_waist'] != null) {
        values.add("W${p.values['us_waist']}");
      }
      if (p.values['standard'] != null) values.add(p.values['standard']!);
    } else if (key == 'shoes') {
      if (p.values['eu_shoes'] != null) values.add(p.values['eu_shoes']!);
      if (p.values['cm_shoes'] != null) values.add("${p.values['cm_shoes']}cm");
    }

    return values.isEmpty ? "-" : values.join(" • ");
  }

  Widget _summaryCard(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(label, style: fw(size: 10, w: FontWeight.w800, color: color)),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: fw(size: value.length > 8 ? 10 : 14, w: FontWeight.w900, color: context.pt.ink),
          ),
        ],
      ),
    );
  }
}
