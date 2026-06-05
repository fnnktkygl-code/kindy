import 'package:flutter_test/flutter_test.dart';
import 'package:kindy/features/notifications/state/notifications_coordinator.dart';
import 'package:kindy/services/notification_service.dart';

void main() {
  late NotificationsCoordinator coordinator;

  setUp(() {
    coordinator = NotificationsCoordinator(
      apiBaseUrl: 'https://test.supabase.co/functions/v1',
      notificationService: _FakeNotificationService(),
    );
  });

  group('cooldownForType', () {
    test('wizz and invite_accepted have zero cooldown', () {
      expect(coordinator.cooldownForType('wizz'), Duration.zero);
      expect(coordinator.cooldownForType('invite_accepted'), Duration.zero);
    });

    test('wish types have 3-hour cooldown', () {
      const expected = Duration(hours: 3);
      expect(coordinator.cooldownForType('wish_added'), expected);
      expect(coordinator.cooldownForType('wish_updated'), expected);
      expect(coordinator.cooldownForType('wish_reserved'), expected);
    });

    test('profile & sizes have 12-hour cooldown', () {
      const expected = Duration(hours: 12);
      expect(coordinator.cooldownForType('profile_updated'), expected);
      expect(coordinator.cooldownForType('sizes_updated'), expected);
    });

    test('unknown type falls back to 6 hours', () {
      expect(coordinator.cooldownForType('unknown'), const Duration(hours: 6));
    });
  });

  group('shouldSendToContact', () {
    test('allows first send for eligible type', () {
      final cooldowns = <String, DateTime>{};
      final result = coordinator.shouldSendToContact(
        contactId: 'c1',
        type: 'wish_added',
        cooldowns: cooldowns,
      );
      expect(result, isTrue);
      expect(cooldowns, contains('c1|wish_added'));
    });

    test('blocks send within cooldown window', () {
      final cooldowns = <String, DateTime>{
        'c1|wish_added': DateTime.now(),
      };
      final result = coordinator.shouldSendToContact(
        contactId: 'c1',
        type: 'wish_added',
        cooldowns: cooldowns,
      );
      expect(result, isFalse);
    });

    test('allows send after cooldown expires', () {
      final cooldowns = <String, DateTime>{
        'c1|wish_added': DateTime.now().subtract(const Duration(hours: 4)),
      };
      final result = coordinator.shouldSendToContact(
        contactId: 'c1',
        type: 'wish_added',
        cooldowns: cooldowns,
      );
      expect(result, isTrue);
    });

    test('zero-cooldown types always send', () {
      final cooldowns = <String, DateTime>{
        'c1|wizz': DateTime.now(),
      };
      final result = coordinator.shouldSendToContact(
        contactId: 'c1',
        type: 'wizz',
        cooldowns: cooldowns,
      );
      expect(result, isTrue);
    });

    test('rejects non-eligible type', () {
      final cooldowns = <String, DateTime>{};
      final result = coordinator.shouldSendToContact(
        contactId: 'c1',
        type: 'fake_type',
        cooldowns: cooldowns,
      );
      expect(result, isFalse);
    });

    test('independent cooldowns per contact', () {
      final cooldowns = <String, DateTime>{
        'c1|wish_added': DateTime.now(),
      };
      // Same type but different contact, should be allowed
      final result = coordinator.shouldSendToContact(
        contactId: 'c2',
        type: 'wish_added',
        cooldowns: cooldowns,
      );
      expect(result, isTrue);
    });
  });

  group('mergePulledNotifications', () {
    test('inserts new notifications and deduplicates', () {
      final target = <PigioNotification>[];
      final existingIds = <String>{};
      final pulled = [
        PigioNotification(
          id: 'n1',
          type: 'wizz',
          senderId: 'u1',
          senderName: 'Alice',
          message: 'You got a wizz',
          createdAt: DateTime.now(),
        ),
        PigioNotification(
          id: 'n2',
          type: 'invite_accepted',
          senderId: 'u2',
          senderName: 'Bob',
          message: 'Accepted',
          createdAt: DateTime.now(),
        ),
      ];

      final inserted = coordinator.mergePulledNotifications(
        target: target,
        pulled: pulled,
        existingIds: existingIds,
      );

      expect(inserted, 2);
      expect(target.length, 2);
      // Inserted at front, so n2 is first (inserted second → position 0)
      expect(target[0].id, 'n2');
      expect(target[1].id, 'n1');
    });

    test('skips already-known notifications', () {
      final target = <PigioNotification>[];
      final existingIds = <String>{'n1'};
      final pulled = [
        PigioNotification(
          id: 'n1',
          type: 'wizz',
          senderId: 'u1',
          senderName: 'Alice',
          message: 'Duplicate',
          createdAt: DateTime.now(),
        ),
      ];

      final inserted = coordinator.mergePulledNotifications(
        target: target,
        pulled: pulled,
        existingIds: existingIds,
      );

      expect(inserted, 0);
      expect(target, isEmpty);
    });
  });
}

/// Minimal fake so the coordinator can be constructed without a real HTTP client.
class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super(baseApiUrl: 'https://test.local');

  @override
  Future<List<PigioNotification>> pullNotifications(String pullKey) async => [];

  @override
  Future<bool> pushNotification({
    required String pushKey,
    required List<PigioNotification> notifications,
  }) async => true;
}
