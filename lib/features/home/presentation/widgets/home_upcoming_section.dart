import 'package:flutter/material.dart';
import '../../../../shared/widgets/ui_widgets.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/i18n/i18n.dart';
import 'package:kindy/core/theme/pigio_theme.dart';

typedef EventCountdownBuilder = Widget Function(
  int days,
  bool isFirst,
  bool isToday,
  bool isTomorrow,
  Event event,
);

class HomeUpcomingSection extends StatelessWidget {
  final List<Event> events;
  final String lang;
  final PigioThemeData theme;
  final EventCountdownBuilder buildEventCountdown;

  const HomeUpcomingSection({
    super.key,
    required this.events,
    required this.lang,
    required this.theme,
    required this.buildEventCountdown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(t(context, 'upcoming'), style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.divider),
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: theme.card, shape: BoxShape.circle, boxShadow: [BoxShadow(color: theme.shadow, blurRadius: 10)]),
                    child: const Center(child: Text("🗓", style: TextStyle(fontSize: 30))),
                  ),
                  const SizedBox(height: 16),
                  Text(t(context, 'no_events_title'), style: fw(size: 18, w: FontWeight.w800, color: theme.ink)),
                  const SizedBox(height: 8),
                  Text(t(context, 'no_events_sub'), textAlign: TextAlign.center, style: fw(size: 14, w: FontWeight.w600, color: theme.mid, height: 1.4)),
                ],
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: events.map((e) {
                final bool isFirst = events.indexOf(e) == 0;
                final int days = e.daysRemaining;
                final bool isToday = days == 0;
                final bool isTomorrow = days == 1;

                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isFirst ? e.color : theme.card,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: isFirst ? e.color.withValues(alpha: 0.35) : theme.shadow,
                        blurRadius: isToday ? 24 : 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: isFirst
                        ? (isToday ? Border.all(color: theme.onAccent.withValues(alpha: 0.35), width: 2) : null)
                        : Border.all(color: isToday ? e.color.withValues(alpha: 0.45) : theme.divider, width: isToday ? 2 : 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PigioBadge(
                        label: lang == 'fr' ? e.typeFr : e.typeEn,
                        color: isFirst ? theme.onAccent : e.color,
                        bg: isFirst ? theme.onAccent.withValues(alpha: 0.22) : e.color.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 12),
                      Text(e.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      Text(e.title, style: fw(size: 16, w: FontWeight.w800, color: isFirst ? theme.onAccent : theme.ink), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      buildEventCountdown(days, isFirst, isToday, isTomorrow, e),
                      const SizedBox(height: 10),
                      if (isToday)
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isFirst ? theme.onAccent.withValues(alpha: 0.4) : e.color.withValues(alpha: 0.25),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: isFirst ? theme.onAccent : e.color,
                              ),
                            ),
                          ),
                        )
                      else
                        PigioProgressBar(pct: e.percent, color: isFirst ? theme.onAccent.withValues(alpha: 0.8) : e.color, height: 8),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}