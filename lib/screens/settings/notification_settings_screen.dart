import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<PigioAppState>(context);
    final theme = context.pt;
    final isFr = state.locale.languageCode == 'fr';

    final contacts = state.contacts;
    final events = state.events.where((e) => !e.id.startsWith('birthday_')).toList();
    final mutedContactIds = state.mutedContactIds;
    final mutedEventIds = state.mutedEventIds;
    final defaultThresholds = state.defaultThresholds;

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: AppBar(
        title: Text(
          isFr ? "Notifications & Rappels" : "Notifications & Reminders",
          style: fw(size: 20, w: FontWeight.w800, color: theme.ink),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(PigioDesign.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Global Toggle ──────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(PigioDesign.radiusMedium),
              ),
              child: ListTile(
                leading: Icon(
                  state.isGlobalMuted ? Icons.notifications_off : Icons.notifications_active,
                  color: state.isGlobalMuted ? theme.error : theme.primary,
                ),
                title: Text(
                  isFr ? "Rappels activés" : "Reminders enabled",
                  style: fw(size: 16, w: FontWeight.w700, color: theme.ink),
                ),
                subtitle: Text(
                  isFr
                      ? "Recevez des notifications avant chaque événement"
                      : "Get notified before each event",
                  style: fw(size: 12, color: theme.mid),
                ),
                trailing: Switch(
                  value: !state.isGlobalMuted,
                  activeThumbColor: theme.primary,
                  onChanged: (val) => state.setGlobalMute(!val),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Default Thresholds ─────────────────────────────────────
            _sectionTitle(isFr ? "Seuils par défaut" : "Default thresholds", theme),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: BorderRadius.circular(PigioDesign.radiusMedium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFr ? "Rappeler à" : "Remind at",
                    style: fw(size: 13, w: FontWeight.w600, color: theme.mid),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [7, 3, 1].map((d) {
                      final selected = defaultThresholds.contains(d);
                      final label = isFr ? "$d jour${d > 1 ? 's' : ''} avant" : "$d day${d > 1 ? 's' : ''} before";
                      return FilterChip(
                        label: Text(label, style: fw(size: 13, w: FontWeight.w700, color: selected ? theme.onAccent : theme.ink)),
                        selected: selected,
                        selectedColor: theme.primary,
                        backgroundColor: theme.surface,
                        checkmarkColor: theme.onAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: selected ? theme.primary : theme.divider),
                        ),
                        onSelected: (val) {
                          final newThresholds = List<int>.from(defaultThresholds);
                          if (val) {
                            newThresholds.add(d);
                          } else {
                            newThresholds.remove(d);
                          }
                          newThresholds.sort((a, b) => b.compareTo(a));
                          state.setDefaultThresholds(newThresholds);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Muted Contacts ─────────────────────────────────────────
            if (contacts.isNotEmpty) ...[
              _sectionTitle(isFr ? "Contacts" : "Contacts", theme),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(PigioDesign.radiusMedium),
                ),
                child: Column(
                  children: contacts.map((c) {
                    final isMuted = mutedContactIds.contains(c.id);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c.color.withValues(alpha: 0.2),
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                          style: fw(size: 16, w: FontWeight.w800, color: c.color),
                        ),
                      ),
                      title: Text(c.name, style: fw(size: 14, w: FontWeight.w700, color: theme.ink)),
                      subtitle: c.birthdate != null
                          ? Text(
                              isFr ? "Anniversaire : ${c.birthdate}" : "Birthday: ${c.birthdate}",
                              style: fw(size: 11, color: theme.mid),
                            )
                          : null,
                      trailing: Switch(
                        value: !isMuted,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          if (val) {
                            state.unmuteContact(c.id);
                          } else {
                            state.muteContact(c.id);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Muted Events ───────────────────────────────────────────
            if (events.isNotEmpty) ...[
              _sectionTitle(isFr ? "Événements" : "Events", theme),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(PigioDesign.radiusMedium),
                ),
                child: Column(
                  children: events.map((e) {
                    final isMuted = mutedEventIds.contains(e.id);
                    return ListTile(
                      leading: Text(e.emoji, style: const TextStyle(fontSize: 22)),
                      title: Text(e.title, style: fw(size: 14, w: FontWeight.w700, color: theme.ink)),
                      subtitle: Text(
                        isFr ? e.typeFr : e.typeEn,
                        style: fw(size: 11, color: theme.mid),
                      ),
                      trailing: Switch(
                        value: !isMuted,
                        activeThumbColor: theme.primary,
                        onChanged: (val) {
                          if (val) {
                            state.unmuteEvent(e.id);
                          } else {
                            state.muteEvent(e.id);
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, PigioThemeData theme) {
    return Text(text, style: fw(size: 14, w: FontWeight.w900, color: theme.mid));
  }
}
