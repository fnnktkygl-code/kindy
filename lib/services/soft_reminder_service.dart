import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/services/notification_service.dart';

class SoftReminderService {
  /// Checks for upcoming events and generates local in-app notifications (soft reminders)
  /// for events happening in exactly 7 days or 3 days.
  static void checkUpcomingEvents(PigioAppState state) {
    if (state.events.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool stateChanged = false;

    for (final event in state.events) {
      final daysUntil = event.date.difference(today).inDays;
      
      if (daysUntil == 7 || daysUntil == 3 || daysUntil == 1) {
        final reminderId = 'reminder_${event.id}_$daysUntil';
        
        // Check if we already sent this reminder
        final alreadySent = state.notifications.any((n) => n.id == reminderId);
        
        if (!alreadySent) {
          final isFr = state.locale.languageCode == 'fr';
          final daysStr = daysUntil == 1 
              ? (isFr ? 'demain' : 'tomorrow')
              : (isFr ? 'dans $daysUntil jours' : 'in $daysUntil days');
              
          final notif = PigioNotification(
            id: reminderId,
            senderId: 'system',
            senderName: 'Kindy',
            type: 'reminder',
            message: isFr 
                ? 'L\'événement "${event.title}" est $daysStr ! Avez-vous préparé un cadeau ?'
                : 'The event "${event.title}" is $daysStr! Do you have a gift ready?',
            createdAt: now,
          );
          
          state.addNotification(notif);
          stateChanged = true;
        }
      }
    }
  }
}
