import 'package:flutter/material.dart';
import '../../../../shared/widgets/ui_widgets.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';

class GroupBirthdayTimeline extends StatelessWidget {
  final List<ContactProfile> members;

  const GroupBirthdayTimeline({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final upcoming = _getUpcomingBirthdays();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("ANNIVERSAIRES", style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        SizedBox(
          height: 82,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: upcoming.length,
            itemBuilder: (ctx, i) {
              final entry = upcoming[i];
              final isToday = entry.daysUntil == 0;
              final isUrgent = entry.daysUntil <= 7;
              return Container(
                width: 68,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        PigioAvatar(
                          name: entry.contact.name,
                          size: 44,
                          avatarIcon: entry.contact.avatarIcon,
                          avatarColor: entry.contact.avatarColor,
                          ringColor: entry.contact.color,
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isToday
                                  ? theme.warning
                                  : isUrgent
                                      ? theme.accent2
                                      : theme.primary,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [BoxShadow(color: theme.shadow, blurRadius: 3)],
                            ),
                            child: Text(
                              isToday ? "Auj!" : "${entry.daysUntil}j",
                              style: fw(size: 9, w: FontWeight.w900, color: theme.onAccent),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.contact.name.split(' ').first,
                      style: fw(size: 11, w: FontWeight.w700, color: theme.ink),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  List<_BirthdayEntry> _getUpcomingBirthdays() {
    final List<_BirthdayEntry> entries = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final member in members) {
      if (member.birthdate == null || member.hideBirthdate) continue;
      try {
        final parts = member.birthdate!.split('/');
        if (parts.length < 2) continue;
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        if (month < 1 || month > 12 || day < 1 || day > 31) continue;

        // Handle leap year: Feb 29 becomes Feb 28 in non-leap years
        int targetDay = day;
        if (month == 2 && day == 29) {
          final isLeap = (now.year % 4 == 0) && ((now.year % 100 != 0) || (now.year % 400 == 0));
          if (!isLeap) targetDay = 28;
        }

        var nextBirthday = DateTime(now.year, month, targetDay);
        if (nextBirthday.isBefore(today)) {
          final nextYear = now.year + 1;
          final isLeapNext = (nextYear % 4 == 0) && ((nextYear % 100 != 0) || (nextYear % 400 == 0));
          final nextDay = (month == 2 && day == 29 && !isLeapNext) ? 28 : day;
          nextBirthday = DateTime(nextYear, month, nextDay);
        }
        final diff = nextBirthday.difference(today).inDays;
        if (diff <= 90) {
          entries.add(_BirthdayEntry(contact: member, daysUntil: diff));
        }
      } catch (e) {
        debugPrint('[BirthdayTimeline] Invalid birthdate for ${member.name}: ${member.birthdate}');
      }
    }
    entries.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return entries;
  }
}

class _BirthdayEntry {
  final ContactProfile contact;
  final int daysUntil;
  const _BirthdayEntry({required this.contact, required this.daysUntil});
}
