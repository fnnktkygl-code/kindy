import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pigio_app/services/notification_service.dart';
import 'package:pigio_app/core/models/app_models.dart';

void main() {
  group('Wish', () {
    test('toMap/fromMap round-trips correctly', () {
      final wish = Wish(
        id: 'w1',
        title: 'Lego Star Wars',
        emoji: '🧱',
        url: 'https://example.com',
        imageUrl: 'https://example.com/img.png',
        priority: WishPriority.high,
        priceRange: WishPriceRange.premium,
        notes: 'UCS version',
        giftPotId: 'pot1',
        reservedById: 'u2',
        contactId: 'c1',
      );

      final map = wish.toMap();
      final restored = Wish.fromMap(map);

      expect(restored.id, wish.id);
      expect(restored.title, wish.title);
      expect(restored.emoji, wish.emoji);
      expect(restored.url, wish.url);
      expect(restored.imageUrl, wish.imageUrl);
      expect(restored.priority, WishPriority.high);
      expect(restored.priceRange, WishPriceRange.premium);
      expect(restored.notes, 'UCS version');
      expect(restored.giftPotId, 'pot1');
      expect(restored.reservedById, 'u2');
      expect(restored.contactId, 'c1');
    });

    test('fromMap handles missing optional fields gracefully', () {
      final wish = Wish.fromMap({'id': 'w2', 'title': 'Book'});

      expect(wish.id, 'w2');
      expect(wish.title, 'Book');
      expect(wish.emoji, '🎁');
      expect(wish.url, isNull);
      expect(wish.priority, WishPriority.medium);
      expect(wish.priceRange, isNull);
    });

    test('fromMap handles completely empty map', () {
      final wish = Wish.fromMap({});
      expect(wish.id, '');
      expect(wish.title, '');
      expect(wish.emoji, '🎁');
    });
  });

  group('ContactProfile', () {
    test('toMap/fromMap round-trips correctly', () {
      final contact = ContactProfile(
        id: 'c1',
        name: 'Alice',
        role: 'Sister',
        avatarName: 'cat',
        color: const Color(0xFF42A5F5),
        trustLevel: TrustLevel.family,
        birthdate: '15/03/1990',
        status: ContactStatus.joined,
        profilePushKey: 'push_key_1',
        profilePullKey: 'pull_key_1',
        fcmToken: 'token_abc',
      );

      final map = contact.toMap();
      final restored = ContactProfile.fromMap(map);

      expect(restored.id, contact.id);
      expect(restored.name, 'Alice');
      expect(restored.role, 'Sister');
      expect(restored.trustLevel, TrustLevel.family);
      expect(restored.isFamily, isTrue);
      expect(restored.status, ContactStatus.joined);
      expect(restored.profilePushKey, 'push_key_1');
      expect(restored.profilePullKey, 'pull_key_1');
      expect(restored.fcmToken, 'token_abc');
    });

    test('copyWith preserves sentinel pattern for nullable keys', () {
      final contact = ContactProfile(
        id: 'c1',
        name: 'Bob',
        role: 'Friend',
        avatarName: 'dog',
        color: Colors.red,
        profilePushKey: 'key1',
      );

      // Explicitly clear profilePushKey
      final cleared = contact.copyWith(profilePushKey: null);
      expect(cleared.profilePushKey, isNull);

      // Leave profilePushKey unchanged (using sentinel default)
      final unchanged = contact.copyWith(name: 'Bob2');
      expect(unchanged.profilePushKey, 'key1');
      expect(unchanged.name, 'Bob2');
    });

    test('fromMap falls back to friend trustLevel for legacy isFamily', () {
      final map = {
        'id': 'c2',
        'name': 'Charlie',
        'role': 'Uncle',
        'avatarName': 'lion',
        'color': 0xFF000000,
        'isFamily': true,
      };
      final contact = ContactProfile.fromMap(map);
      expect(contact.trustLevel, TrustLevel.family);
    });
  });

  group('SizeProfile', () {
    test('toMap/fromMap round-trips correctly', () {
      final size = SizeProfile(
        categoryKey: 'shoes',
        values: {'eu': '43', 'us': '10'},
        fitKey: 'regular',
        updatedAt: DateTime(2025, 1, 15),
        contactId: 'c1',
      );

      final map = size.toMap();
      final restored = SizeProfile.fromMap(map);

      expect(restored.categoryKey, 'shoes');
      expect(restored.values['eu'], '43');
      expect(restored.values['us'], '10');
      expect(restored.fitKey, 'regular');
      expect(restored.contactId, 'c1');
    });
  });

  group('PigioNotification', () {
    test('toMap/fromMap round-trips correctly', () {
      final notif = PigioNotification(
        id: 'n1',
        type: 'wizz',
        senderId: 'u1',
        senderName: 'Alice',
        message: 'You got a wizz',
        createdAt: DateTime(2025, 6, 1, 12, 0),
        read: true,
      );

      final map = notif.toMap();
      final restored = PigioNotification.fromMap(map);

      expect(restored.id, 'n1');
      expect(restored.type, 'wizz');
      expect(restored.senderId, 'u1');
      expect(restored.senderName, 'Alice');
      expect(restored.message, 'You got a wizz');
      expect(restored.read, isTrue);
      expect(restored.emoji, '⚡');
    });

    test('fromMap handles missing fields gracefully', () {
      final notif = PigioNotification.fromMap({});
      expect(notif.id, '');
      expect(notif.type, 'unknown');
      expect(notif.read, isFalse);
    });

    test('copyWith toggles read status', () {
      final notif = PigioNotification(
        id: 'n2',
        type: 'wizz',
        senderId: 'u1',
        senderName: 'Bob',
        message: 'test',
        createdAt: DateTime.now(),
      );
      expect(notif.read, isFalse);
      final read = notif.copyWith(read: true);
      expect(read.read, isTrue);
      expect(read.id, 'n2');
    });
  });

  group('Enums', () {
    test('MascotMoment has all expected values', () {
      expect(MascotMoment.values, contains(MascotMoment.none));
      expect(MascotMoment.values, contains(MascotMoment.circleStale));
      expect(MascotMoment.values, contains(MascotMoment.yearlyWrapped));
      expect(MascotMoment.values, contains(MascotMoment.busyMonth));
    });

    test('ContactStatus has all expected values', () {
      expect(ContactStatus.values, contains(ContactStatus.local));
      expect(ContactStatus.values, contains(ContactStatus.invited));
      expect(ContactStatus.values, contains(ContactStatus.pending));
      expect(ContactStatus.values, contains(ContactStatus.joined));
    });
  });
}
