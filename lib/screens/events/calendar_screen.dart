import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/services/tooltip_service.dart';
import 'package:pigio_app/shared/widgets/contextual_tip.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';
import 'package:pigio_app/shared/widgets/pigio_painter.dart';
import 'package:pigio_app/screens/events/sheets/add_event_sheet.dart';
import 'package:pigio_app/features/contacts/presentation/contact_profile_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _selectedMonth;
  bool _isMonthView = false;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context);
    final allEvents = state.getUpcomingEvents(limit: 50);

    // Categorize events
    final birthdays = allEvents.where((e) => e.typeEn == 'Birthday').toList();
    final giftOccasions = allEvents.where((e) => e.typeEn != 'Birthday').toList();

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: PigioAppBar(title: "Évènement"),
      body: SafeArea(
        child: Builder(
          builder: (internalContext) => CustomScrollView(
            slivers: [
              // Progressive disclosure: suggest adding contacts when calendar is empty
              if (state.contacts.isEmpty)
                SliverToBoxAdapter(
                  child: ContextualTip(
                    tooltipKey: TooltipService.calendarEmpty,
                    text: 'Ajoutez un proche pour voir ses dates ici',
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
              // Heatmap / Summary Section
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calculate "heat" base on allEvents in the month
                      ...(() {
                        final heatDensity = allEvents.length;
                        Color heatColor1 = theme.accent2.withValues(alpha: 0.15);
                        Color heatColor2 = theme.primary.withValues(alpha: 0.08);
                        
                        if (heatDensity >= 10) {
                           heatColor1 = theme.primary.withValues(alpha: 0.4);
                           heatColor2 = theme.accent1.withValues(alpha: 0.3);
                        } else if (heatDensity >= 5) {
                           heatColor1 = theme.accent2.withValues(alpha: 0.3);
                           heatColor2 = theme.primary.withValues(alpha: 0.2);
                        } else if (heatDensity == 0) {
                           heatColor1 = theme.surface;
                           heatColor2 = theme.surface;
                        }

                        return [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [heatColor1, heatColor2],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: heatDensity >= 5 ? [BoxShadow(color: heatColor1.withValues(alpha: 0.3), blurRadius: 20)] : null,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                _summaryBadge("🎂", "${birthdays.length}", "Anniversaires", theme),
                                const SizedBox(width: 16),
                                _summaryBadge("🎁", "${giftOccasions.length}", "Occasions", theme),
                                const SizedBox(width: 16),
                                _summaryBadge("📅", "${allEvents.length}", "Total", theme),
                              ],
                            ),
                          )
                        ];
                      }()),
                      const SizedBox(height: 24),

                      // Calendar Grid
                      _buildCalendarGrid(theme, allEvents),

                      const SizedBox(height: 32),

                      // Birthdays Section
                      _sectionHeader("🎂  Anniversaires", theme),
                    ],
                  ),
                ),
              ),

              // Birthdays List
              if (birthdays.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _emptyBirthdayState(theme, state, internalContext),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: birthdays.length,
                    itemBuilder: (context, index) => _buildEventCard(birthdays[index], theme, state),
                  ),
                ),

              // Gift Occasions Section Header
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: _sectionHeader("🎁  Occasions d'envies", theme),
                ),
              ),

              // Gift Occasions List
              if (giftOccasions.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _emptyState("Aucun événement pour le moment.\nCréez un événement ci-dessous.", theme),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(
                    itemCount: giftOccasions.length,
                    itemBuilder: (context, index) => _buildEventCard(giftOccasions[index], theme, state),
                  ),
                ),

              // Add Event Section
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 100),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader("➕  Ajouter un événement", theme),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _quickAddChip("🎄 Noël", "Noël", DateTime(DateTime.now().year, 12, 25), true, state, theme, internalContext),
                          _quickAddChip("💖 St-Valentin", "Saint-Valentin", DateTime(DateTime.now().year, 2, 14), true, state, theme, internalContext),
                          _quickAddChip("👩 Fête des Mères", "Fête des Mères", DateTime(DateTime.now().year, 5, 25), true, state, theme, internalContext),
                          _quickAddChip("👨 Fête des Pères", "Fête des Pères", DateTime(DateTime.now().year, 6, 15), true, state, theme, internalContext),
                          _quickAddChip("🎓 Rentrée", "Rentrée", DateTime(DateTime.now().year, 9, 1), true, state, theme, internalContext),
                          _quickAddChip("🎃 Halloween", "Halloween", DateTime(DateTime.now().year, 10, 31), true, state, theme, internalContext),
                        ],
                      ),
                      const SizedBox(height: 20),
                      PigioButton(
                        label: "Créer un événement personnalisé",
                        icon: Icons.add_circle_outline,
                        color: theme.primary,
                        textColor: theme.onAccent,
                        height: 52,
                        fontSize: 15,
                        onTap: () => showAddEventSheet(internalContext, onAdded: () => setState(() {})),
                        fullWidth: true,
                      ),
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

  String _monthName(int month) {
    const m = ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"];
    return m[month - 1];
  }

  Widget _buildCalendarGrid(PigioThemeData theme, List<Event> events) {
    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startWeekday = firstDay.weekday; // 1=Mon

    final eventDays = <int, List<Event>>{};
    for (var e in events) {
      DateTime nextDate = e.date;
      if (e.isRecurring) nextDate = e.getOccurrenceForYear(year);
      if (nextDate.year == year && nextDate.month == month) {
        eventDays.putIfAbsent(nextDate.day, () => []).add(e);
      }
    }

    final today = DateTime.now();
    final isCurrentMonth = today.year == year && today.month == month;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: theme.shadow, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() => _selectedMonth = DateTime(year, month - 1)),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.chevron_left, color: theme.ink, size: 20),
                ),
              ),
              Text("${_monthName(month)} $year", style: fw(size: 18, w: FontWeight.w900, color: theme.ink)),
              GestureDetector(
                onTap: () => setState(() => _selectedMonth = DateTime(year, month + 1)),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.chevron_right, color: theme.ink, size: 20),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _isMonthView = !_isMonthView),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isMonthView ? theme.primary.withValues(alpha: 0.1) : theme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isMonthView ? Icons.calendar_view_month : Icons.calendar_view_week,
                        size: 16,
                        color: _isMonthView ? theme.primary : theme.mid,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isMonthView ? "Mois" : "Semaine",
                        style: fw(size: 12, w: FontWeight.w700, color: _isMonthView ? theme.primary : theme.mid),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isMonthView) ...[
            Row(
              children: ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"].map((d) => Expanded(
                child: Center(child: Text(d, style: fw(size: 11, w: FontWeight.w800, color: theme.light))),
              )).toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
              itemCount: (startWeekday - 1) + daysInMonth,
              itemBuilder: (ctx, index) {
                if (index < startWeekday - 1) return const SizedBox();
                final day = index - (startWeekday - 1) + 1;
                final hasEvent = eventDays.containsKey(day);
                final isToday = isCurrentMonth && today.day == day;
                final eventList = eventDays[day];
                final emoji = eventList != null && eventList.isNotEmpty ? eventList.first.emoji : null;
                return _calendarCell(
                  day, isToday, hasEvent, emoji, theme,
                  eventList: eventList,
                  onTap: eventList != null && eventList.isNotEmpty
                      ? () => _showDayEvents(DateTime(year, month, day), eventList, theme)
                      : null,
                );
              },
            ),
          ] else ...[
            _buildWeekStrip(theme, eventDays, isCurrentMonth, today),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekStrip(PigioThemeData theme, Map<int, List<Event>> eventDays, bool isCurrentMonth, DateTime today) {
    final List<DateTime> weekDays = [];
    if (isCurrentMonth && today.month == _selectedMonth.month) {
      for (int i = -3; i <= 3; i++) {
        weekDays.add(today.add(Duration(days: i)));
      }
    } else {
      final firstOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      for (int i = 0; i < 7; i++) {
        weekDays.add(firstOfMonth.add(Duration(days: i)));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekDays.map((date) {
        final isToday = today.year == date.year && today.month == date.month && today.day == date.day;
        final hasEvent = eventDays.containsKey(date.day) && date.month == _selectedMonth.month;
        final eventList = hasEvent ? eventDays[date.day] : null;
        final firstEventEmoji = (hasEvent && eventList != null && eventList.isNotEmpty) ? eventList.first.emoji : null;
        const weekdaysFr = ["Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"];
        final weekdayName = weekdaysFr[date.weekday % 7];

        return Expanded(
          child: Column(
            children: [
              Text(weekdayName, style: fw(size: 10, w: FontWeight.w800, color: theme.light)),
              const SizedBox(height: 6),
              AspectRatio(
                aspectRatio: 1,
                child: _calendarCell(
                  date.day, isToday, hasEvent, firstEventEmoji, theme,
                  isCompact: true,
                  eventList: eventList,
                  onTap: eventList != null && eventList.isNotEmpty
                      ? () => _showDayEvents(date, eventList, theme)
                      : null,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _calendarCell(int day, bool isToday, bool hasEvent, String? emoji, PigioThemeData theme, {bool isCompact = false, List<Event>? eventList, VoidCallback? onTap}) {
    return Material(
      color: isToday ? theme.primary : hasEvent ? theme.accent2.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: hasEvent && !isToday ? Border.all(color: theme.accent2.withValues(alpha: 0.3)) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "$day",
                // Corrigé: utiliser theme.onAccent à la place de Colors.white pour que ce soit bien lisible si theme.primary est clair
                style: fw(size: isCompact ? 14 : 13, w: isToday || hasEvent ? FontWeight.w800 : FontWeight.w600, color: isToday ? theme.onAccent : hasEvent ? theme.accent2 : theme.ink),
              ),
              if (hasEvent)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(emoji ?? '', style: TextStyle(fontSize: isCompact ? 11 : 10)),
                    if (!isCompact && eventList != null && eventList.length > 1) ...[
                      const SizedBox(width: 2),
                      Text('+${eventList.length - 1}', style: fw(size: 8, w: FontWeight.bold, color: isToday ? theme.onAccent.withValues(alpha: 0.7) : theme.mid)),
                    ]
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryBadge(String emoji, String count, String label, PigioThemeData theme) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            Text(count, style: fw(size: 22, w: FontWeight.w900, color: theme.ink)),
            Text(label, style: fw(size: 11, w: FontWeight.w600, color: theme.mid)),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, PigioThemeData theme) {
    return Text(title, style: fw(size: 20, w: FontWeight.w900, color: theme.ink));
  }

  Widget _emptyBirthdayState(PigioThemeData theme, PigioAppState state, BuildContext internalContext) {
    final missingBdayContacts = state.contacts.where((c) {
      final hasEvent = state.events.any((e) => e.contactId == c.id && e.typeEn == 'Birthday');
      return !hasEvent;
    }).take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          CustomPaint(size: const Size(60, 60), painter: PigioPainter(mood: PigMood.searching, scarfColor: theme.primary)),
          const SizedBox(height: 16),
          Text("Aucun anniversaire !", style: fw(size: 16, w: FontWeight.w800, color: theme.ink)),
          const SizedBox(height: 8),
          Text(
            "Pigio aimerait bien vous rappeler les dates importantes.",
            textAlign: TextAlign.center,
            style: fw(size: 13, w: FontWeight.w600, color: theme.mid, height: 1.4),
          ),
          if (missingBdayContacts.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.card, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Manquant :", style: fw(size: 12, w: FontWeight.w800, color: theme.light)),
                  const SizedBox(height: 10),
                  ...missingBdayContacts.map((c) {
                    // Parse birthdate (DD/MM or DD/MM/YYYY) for pre-fill
                    DateTime? bdayDate;
                    if (c.birthdate != null && c.birthdate!.isNotEmpty) {
                      try {
                        final parts = c.birthdate!.split('/');
                        if (parts.length >= 2) {
                          final day = int.parse(parts[0]);
                          final month = int.parse(parts[1]);
                          final now = DateTime.now();
                          var candidate = DateTime(now.year, month, day);
                          if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
                            candidate = DateTime(now.year + 1, month, day);
                          }
                          bdayDate = candidate;
                        }
                      } catch (e) {
                        debugPrint('[Calendar] Invalid birthdate for ${c.name}: ${c.birthdate}');
                      }
                    }
                    return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(c.name, style: fw(size: 14, w: FontWeight.w700, color: theme.ink)),
                        PigioButton(
                          label: "Ajouter",
                          icon: Icons.add,
                          color: theme.primary.withValues(alpha: 0.1),
                          textColor: theme.primary,
                          height: 32,
                          fontSize: 12,
                          onTap: () => showAddEventSheet(
                            internalContext,
                            initialTitle: c.name,
                            initialEmoji: '🎂',
                            initialDate: bdayDate,
                            initialRecurring: true,
                            initialContactId: c.id,
                            initialTypeEn: 'Birthday',
                            initialTypeFr: 'Anniversaire',
                          ),
                          fullWidth: false,
                        )
                      ]
                    )
                  );
                  }),
                ]
              )
            )
          ]
        ],
      ),
    );
  }

  Widget _emptyState(String text, PigioThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(20)),
      child: Text(text, textAlign: TextAlign.center, style: fw(size: 14, w: FontWeight.w600, color: theme.light, height: 1.5)),
    );
  }

  Widget _buildEventCard(Event e, PigioThemeData theme, PigioAppState state) {
    final days = e.daysRemaining;
    final isUrgent = days <= 7;
    final isSoon = days <= 30;
    Color badgeColor = theme.mid;
    String badgeText = "$days jours";
    if (days == 0) {
      badgeColor = theme.error; badgeText = "Aujourd'hui !";
    } else if (days == 1) {
      badgeColor = theme.error; badgeText = "Demain !";
    } else if (isUrgent) {
      badgeColor = theme.accent2;
    } else if (isSoon) {
      badgeColor = theme.primary;
    }
    String? linkName;
    ContactProfile? linkedContact;
    CircleGroup? linkedGroup;
    
    if (e.groupId != null) {
      linkedGroup = state.groups.where((g) => g.id == e.groupId).firstOrNull;
      if (linkedGroup != null) linkName = "Cercle ${linkedGroup.name}";
    } else if (e.contactId != null) {
      linkedContact = state.contacts.where((c) => c.id == e.contactId).firstOrNull;
      linkName = linkedContact?.name;
    }
    
    return GestureDetector(
      onTap: () {
        // Navigate to linked contact or show group details
        if (linkedContact != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ContactProfileScreen(contact: linkedContact!)),
          );
        } else if (linkedGroup != null) {
          _showGroupDetails(linkedGroup, state, theme);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isUrgent ? badgeColor.withValues(alpha: 0.3) : theme.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(e.emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (linkName != null) ...[
                        Icon(
                          linkedContact != null ? Icons.person : Icons.group,
                          size: 12,
                          color: linkedContact != null ? theme.primary : theme.accent2,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          linkName != null ? "$linkName · ${e.typeFr}" : e.typeFr,
                          style: fw(size: 12, w: FontWeight.w600, color: theme.mid),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(badgeText, style: fw(size: 12, w: FontWeight.w800, color: badgeColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAddChip(String label, String title, DateTime date, bool recurring, PigioAppState state, PigioThemeData theme, BuildContext internalContext) {
    final exists = state.events.any((e) => e.title == title);
    return Material(
      color: exists ? theme.success.withValues(alpha: 0.1) : theme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: exists ? null : () => showAddEventSheet(internalContext, onAdded: () => setState(() {}), initialTitle: title, initialEmoji: label.split(' ').first, initialDate: date, initialRecurring: recurring),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: exists ? theme.success.withValues(alpha: 0.3) : theme.divider)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label, style: fw(size: 13, w: FontWeight.w700, color: exists ? theme.success : theme.ink)), if (exists) ...[const SizedBox(width: 6), Icon(Icons.check, size: 14, color: theme.success)]]),
        ),
      ),
    );
  }

  void _showDayEvents(DateTime date, List<Event> events, PigioThemeData theme) {
    final state = Provider.of<PigioAppState>(context, listen: false);
    const weekdaysFr = ["Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"];
    const monthsFr = ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"];
    final label = "${weekdaysFr[date.weekday % 7]} ${date.day} ${monthsFr[date.month - 1]}";

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: BoxDecoration(
          color: theme.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: theme.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(label, style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
            Text(
              "${events.length} évènement${events.length > 1 ? 's' : ''}",
              style: fw(size: 13, w: FontWeight.w600, color: theme.mid),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: events.map((e) => _buildEventCard(e, theme, state)).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupDetails(CircleGroup group, PigioAppState state, PigioThemeData theme) {
    final members = state.contacts.where((c) => group.contactIds.contains(c.id)).toList();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.sheet,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.accent2.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(group.emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name, style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
                      Text("${members.length} membre${members.length != 1 ? 's' : ''}", style: fw(size: 14, w: FontWeight.w600, color: theme.mid)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text("Membres", style: fw(size: 16, w: FontWeight.w800, color: theme.ink)),
            const SizedBox(height: 12),
            ...members.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ContactProfileScreen(contact: c)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      PigioAvatar(name: c.name, size: 40, avatarIcon: c.avatarIcon, avatarColor: c.avatarColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(c.name, style: fw(size: 15, w: FontWeight.w700, color: theme.ink)),
                      ),
                      Icon(Icons.chevron_right, color: theme.mid, size: 20),
                    ],
                  ),
                ),
              ),
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

