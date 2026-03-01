// ─── Pigio Data Models ──────────────────────────────────────────────────────
// All enums and immutable data classes used across the app.
// This file is a standalone library so it can be imported independently,
// and is also re-exported by app_state.dart for backwards compatibility.

import 'package:flutter/material.dart';

// ─── Enums ──────────────────────────────────────────────────────────────────

enum WishPriority { low, medium, high }
enum WishPriceRange { budget, mid, premium }
enum MascotMoment {
  none,
  firstWish,
  wishReserved,
  birthdaySoon,
  concierge,
  yearlyWrapped,
  circleStale,
  busyMonth,
  inviteSent,
  inviteAccepted,
  quizCompleted,
}
enum ContactStatus { local, invited, pending, joined }

/// Reason why sending an invite to a contact is currently not permitted.
enum InviteBlockReason {
  /// Contact has already accepted a Pigio invite and is fully connected.
  alreadyJoined,
  /// A non-expired invite token is already in flight to this contact.
  pendingActive,
  /// This is a locally-managed profile — it has no Pigio identity to invite.
  managedProfile,
}
enum InviteChannel { sms, whatsApp, copyLink, backendDispatch }
enum PendingInviteState { pending, accepted, expired, revoked }
enum ClothingSlot { hat, glasses, top, scarf, shoes, accessory }
enum TrustLevel { family, friend, public_ }
enum WizzEffectMode { phase1, phase2 }
enum GiftPotMode { amount, share }
enum GiftPotStatus { open, closed, completed }

// ─── Clothing Models ─────────────────────────────────────────────────────────

class ClothingItem {
  final String id;
  final String name;
  final String emoji;
  final ClothingSlot slot;
  final bool isUnlocked;
  final String? unlockHint;

  const ClothingItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.slot,
    this.isUnlocked = true,
    this.unlockHint,
  });
}

class ClothingRequest {
  final ClothingItem item;
  final String bubbleTextEn;
  final String bubbleTextFr;
  final String contextHint;

  const ClothingRequest({
    required this.item,
    required this.bubbleTextEn,
    required this.bubbleTextFr,
    required this.contextHint,
  });
}

// ─── Wish ────────────────────────────────────────────────────────────────────

class Wish {
  final String id;
  final String title;
  final String emoji;
  final String? url;
  final String? imageUrl;
  final DateTime addedAt;
  final String? reservedById;
  final String? contactId; // null = Main User's wish
  final WishPriority priority;
  final WishPriceRange? priceRange;
  final String? notes;
  final String? giftPotId;

  Wish({
    required this.id,
    required this.title,
    this.emoji = '🎁',
    this.url,
    this.imageUrl,
    DateTime? addedAt,
    this.reservedById,
    this.contactId,
    this.priority = WishPriority.medium,
    this.priceRange,
    this.notes,
    this.giftPotId,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'url': url,
        'imageUrl': imageUrl,
        'addedAt': addedAt.toIso8601String(),
        'reservedById': reservedById,
        'contactId': contactId,
        'priority': priority.name,
        'priceRange': priceRange?.name,
        'notes': notes,
        'giftPotId': giftPotId,
      };

  factory Wish.fromMap(Map<String, dynamic> map) => Wish(
        id: map['id'] as String,
        title: map['title'] as String,
        emoji: (map['emoji'] as String?) ?? '🎁',
        url: map['url'] as String?,
        imageUrl: map['imageUrl'] as String?,
        addedAt: map['addedAt'] != null ? DateTime.tryParse(map['addedAt'].toString()) : null,
        reservedById: map['reservedById'] as String?,
        contactId: map['contactId'] as String?,
        priority: WishPriority.values.firstWhere(
          (e) => e.name == map['priority'],
          orElse: () => WishPriority.medium,
        ),
        priceRange: map['priceRange'] != null
            ? WishPriceRange.values.firstWhere(
                (e) => e.name == map['priceRange'],
                orElse: () => WishPriceRange.budget,
              )
            : null,
        notes: map['notes'] as String?,
        giftPotId: map['giftPotId'] as String?,
      );
}

// ─── ContactProfile ──────────────────────────────────────────────────────────

class ContactProfile {
  final String id;
  final String name;
  final String role;
  final String avatarName;
  final Color color;
  final TrustLevel trustLevel;
  final String? birthdate;
  final String? address;
  final String? mondialRelayPoint;
  final bool hideBirthdate;
  final bool hideAddress;
  final bool hideMondialRelay;
  final String? avatarIcon;
  final Color? avatarColor;
  final bool managedProfile;
  final ContactStatus status;
  /// Key to push OWN profile updates to (so this contact can pull them).
  final String? profilePushKey;
  /// Key to pull THIS CONTACT's profile updates from.
  final String? profilePullKey;
  /// FCM device token for real push notifications.
  final String? fcmToken;

  // Backward-compatible computed getters
  bool get isFamily => trustLevel == TrustLevel.family;
  bool get isManaged => managedProfile;

  static const Object _sentinel = Object();

  ContactProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarName,
    required this.color,
    this.trustLevel = TrustLevel.friend,
    this.birthdate,
    this.address,
    this.mondialRelayPoint,
    this.hideBirthdate = false,
    this.hideAddress = false,
    this.hideMondialRelay = false,
    this.avatarIcon,
    this.avatarColor,
    this.managedProfile = true,
    this.status = ContactStatus.local,
    this.profilePushKey,
    this.profilePullKey,
    this.fcmToken,
  });

  ContactProfile copyWith({
    String? id,
    String? name,
    String? role,
    String? avatarName,
    Color? color,
    TrustLevel? trustLevel,
    String? birthdate,
    String? address,
    String? mondialRelayPoint,
    bool? hideBirthdate,
    bool? hideAddress,
    bool? hideMondialRelay,
    String? avatarIcon,
    Color? avatarColor,
    bool? managedProfile,
    ContactStatus? status,
    Object? profilePushKey = _sentinel,
    Object? profilePullKey = _sentinel,
    Object? fcmToken = _sentinel,
  }) {
    return ContactProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarName: avatarName ?? this.avatarName,
      color: color ?? this.color,
      trustLevel: trustLevel ?? this.trustLevel,
      birthdate: birthdate ?? this.birthdate,
      address: address ?? this.address,
      mondialRelayPoint: mondialRelayPoint ?? this.mondialRelayPoint,
      hideBirthdate: hideBirthdate ?? this.hideBirthdate,
      hideAddress: hideAddress ?? this.hideAddress,
      hideMondialRelay: hideMondialRelay ?? this.hideMondialRelay,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      avatarColor: avatarColor ?? this.avatarColor,
      managedProfile: managedProfile ?? this.managedProfile,
      status: status ?? this.status,
      profilePushKey:
          profilePushKey == _sentinel ? this.profilePushKey : profilePushKey as String?,
      profilePullKey:
          profilePullKey == _sentinel ? this.profilePullKey : profilePullKey as String?,
      fcmToken: fcmToken == _sentinel ? this.fcmToken : fcmToken as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'role': role,
        'avatarName': avatarName,
        'color': color.toARGB32(),
        'trustLevel': trustLevel.name,
        'birthdate': birthdate,
        'address': address,
        'mondialRelayPoint': mondialRelayPoint,
        'hideBirthdate': hideBirthdate,
        'hideAddress': hideAddress,
        'hideMondialRelay': hideMondialRelay,
        'avatarIcon': avatarIcon,
        'avatarColor': avatarColor?.toARGB32(),
        'managedProfile': managedProfile,
        'status': status.name,
        'profilePushKey': profilePushKey,
        'profilePullKey': profilePullKey,
        'fcmToken': fcmToken,
      };

  factory ContactProfile.fromMap(Map<String, dynamic> map) {
    TrustLevel trust = TrustLevel.friend;
    if (map['trustLevel'] != null) {
      trust = TrustLevel.values.firstWhere(
        (e) => e.name == map['trustLevel'],
        orElse: () => TrustLevel.friend,
      );
    } else if (map['isFamily'] == true) {
      trust = TrustLevel.family;
    }
    return ContactProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      role: map['role'] as String,
      avatarName: map['avatarName'] as String,
      color: Color(map['color'] as int),
      trustLevel: trust,
      birthdate: map['birthdate'] as String?,
      address: map['address'] as String?,
      mondialRelayPoint: map['mondialRelayPoint'] as String?,
      hideBirthdate: map['hideBirthdate'] as bool? ?? false,
      hideAddress: map['hideAddress'] as bool? ?? false,
      hideMondialRelay: map['hideMondialRelay'] as bool? ?? false,
      avatarIcon: map['avatarIcon'] as String?,
      avatarColor:
          map['avatarColor'] != null ? Color(map['avatarColor'] as int) : null,
      managedProfile:
          map['managedProfile'] as bool? ?? map['isManaged'] as bool? ?? true,
      status: map['status'] != null
          ? ContactStatus.values.firstWhere(
              (e) => e.name == map['status'],
              orElse: () => ContactStatus.local,
            )
          : (map['inviteStatus'] == 'joined'
              ? ContactStatus.joined
              : (map['inviteStatus'] == 'invited'
                  ? ContactStatus.invited
                  : ContactStatus.local)),
      profilePushKey: map['profilePushKey'] as String?,
      profilePullKey: map['profilePullKey'] as String?,
      fcmToken: map['fcmToken'] as String?,
    );
  }
}

// ─── CircleGroup ─────────────────────────────────────────────────────────────

class CircleGroup {
  final String id;
  final String name;
  final String emoji;
  final List<String> contactIds;
  final bool isSystem;
  final TrustLevel trustLevel;
  final List<String> pendingInviteIds;

  CircleGroup({
    required this.id,
    required this.name,
    required this.emoji,
    required this.contactIds,
    this.isSystem = false,
    this.trustLevel = TrustLevel.friend,
    this.pendingInviteIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'contactIds': contactIds,
        'isSystem': isSystem,
        'trustLevel': trustLevel.name,
        'pendingInviteIds': pendingInviteIds,
      };

  factory CircleGroup.fromMap(Map<String, dynamic> map) {
    final isOldFamille = map['name'] == 'Famille';
    final rawStatuses =
        Map<String, dynamic>.from((map['memberInviteStatus'] as Map?) ?? const {});
    final migratedPending = rawStatuses.entries
        .where((entry) => entry.value == 'invited')
        .map((entry) => entry.key)
        .toList();
    return CircleGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String? ?? '👥',
      contactIds: List<String>.from(map['contactIds'] ?? []),
      isSystem: (map['isSystem'] as bool?) ?? isOldFamille,
      trustLevel: map['trustLevel'] != null
          ? TrustLevel.values.firstWhere(
              (e) => e.name == map['trustLevel'],
              orElse: () => TrustLevel.friend,
            )
          : (isOldFamille ? TrustLevel.family : TrustLevel.friend),
      pendingInviteIds: map['pendingInviteIds'] != null
          ? List<String>.from(map['pendingInviteIds'])
          : migratedPending,
    );
  }
}

// ─── PendingInvite ───────────────────────────────────────────────────────────

class PendingInvite {
  final String id;
  final String tokenId;
  final String inviterId;
  final String contactId;
  final String? groupId;
  final InviteChannel channel;
  final PendingInviteState state;
  final DateTime sentAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;

  PendingInvite({
    required this.id,
    required this.tokenId,
    required this.inviterId,
    required this.contactId,
    this.groupId,
    required this.channel,
    this.state = PendingInviteState.pending,
    required this.sentAt,
    required this.expiresAt,
    this.acceptedAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  PendingInvite copyWith({
    PendingInviteState? state,
    DateTime? acceptedAt,
    DateTime? expiresAt,
    String? contactId,
  }) {
    return PendingInvite(
      id: id,
      tokenId: tokenId,
      inviterId: inviterId,
      contactId: contactId ?? this.contactId,
      groupId: groupId,
      channel: channel,
      state: state ?? this.state,
      sentAt: sentAt,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'tokenId': tokenId,
        'inviterId': inviterId,
        'contactId': contactId,
        'groupId': groupId,
        'channel': channel.name,
        'state': state.name,
        'sentAt': sentAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'acceptedAt': acceptedAt?.toIso8601String(),
      };

  factory PendingInvite.fromMap(Map<String, dynamic> map) => PendingInvite(
        id: map['id'] as String,
        tokenId: map['tokenId'] as String,
        inviterId: map['inviterId'] as String,
        contactId: map['contactId'] as String,
        groupId: map['groupId'] as String?,
        channel: InviteChannel.values.firstWhere(
          (e) => e.name == map['channel'],
          orElse: () => InviteChannel.copyLink,
        ),
        state: PendingInviteState.values.firstWhere(
          (e) => e.name == map['state'],
          orElse: () => PendingInviteState.pending,
        ),
        sentAt: DateTime.tryParse(map['sentAt']?.toString() ?? '') ?? DateTime.now(),
        expiresAt: DateTime.tryParse(map['expiresAt']?.toString() ?? '') ?? DateTime.now(),
        acceptedAt: map['acceptedAt'] != null
            ? DateTime.tryParse(map['acceptedAt'].toString())
            : null,
      );
}

// ─── Event ───────────────────────────────────────────────────────────────────

class Event {
  final String id;
  final String title;
  final String typeEn;
  final String typeFr;
  final DateTime date;
  final bool isRecurring;
  final String emoji;
  final Color color;
  final double percent;
  final String? contactId;
  final String? groupId;

  Event({
    required this.id,
    required this.title,
    required this.typeEn,
    required this.typeFr,
    required this.date,
    this.isRecurring = false,
    required this.emoji,
    required this.color,
    this.percent = 0.0,
    this.contactId,
    this.groupId,
  });

  DateTime getOccurrenceForYear(int targetYear) {
    if (!isRecurring) return date;
    int targetDay = date.day;
    if (date.month == 2 && date.day == 29) {
      final isLeap = (targetYear % 4 == 0) &&
          ((targetYear % 100 != 0) || (targetYear % 400 == 0));
      if (!isLeap) targetDay = 28;
    }
    return DateTime(targetYear, date.month, targetDay);
  }

  int get daysRemaining {
    final now = DateTime.now();
    DateTime nextDate = date;
    if (isRecurring) {
      nextDate = getOccurrenceForYear(now.year);
      if (nextDate.isBefore(DateTime(now.year, now.month, now.day))) {
        nextDate = getOccurrenceForYear(now.year + 1);
      }
    }
    return nextDate.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'typeEn': typeEn,
        'typeFr': typeFr,
        'date': date.toIso8601String(),
        'isRecurring': isRecurring,
        'emoji': emoji,
        'color': color.toARGB32(),
        'percent': percent,
        'contactId': contactId,
        'groupId': groupId,
      };

  factory Event.fromMap(Map<String, dynamic> map) {
    DateTime eventDate;
    if (map['date'] != null) {
      eventDate = DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now();
    } else {
      final days = map['daysRemaining'] as int? ?? 30;
      eventDate = DateTime.now().add(Duration(days: days));
    }
    return Event(
      id: map['id'] as String,
      title: map['title'] as String,
      typeEn: map['typeEn'] as String,
      typeFr: map['typeFr'] as String,
      date: eventDate,
      isRecurring: map['isRecurring'] as bool? ?? false,
      emoji: map['emoji'] as String,
      color: Color(map['color'] as int),
      percent: (map['percent'] as num?)?.toDouble() ?? 0.0,
      contactId: map['contactId'] as String?,
      groupId: map['groupId'] as String?,
    );
  }
}

// ─── ActivityLog ─────────────────────────────────────────────────────────────

class ActivityLog {
  final String id;
  final String title;
  final String emoji;
  final DateTime timestamp;
  final String? contactId;

  ActivityLog({
    required this.id,
    required this.title,
    required this.emoji,
    required this.timestamp,
    this.contactId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'timestamp': timestamp.toIso8601String(),
        'contactId': contactId,
      };

  factory ActivityLog.fromMap(Map<String, dynamic> map) => ActivityLog(
        id: map['id'] as String,
        title: map['title'] as String,
        emoji: map['emoji'] as String,
        timestamp: DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
        contactId: map['contactId'] as String?,
      );
}

// ─── SizeProfile ─────────────────────────────────────────────────────────────

class SizeProfile {
  final String? contactId; // null for current user
  final String categoryKey;
  final Map<String, String> values;
  final String? fitKey;
  final String visibilityKey;
  final DateTime updatedAt;

  SizeProfile({
    this.contactId,
    required this.categoryKey,
    required this.values,
    this.fitKey,
    this.visibilityKey = 'full_access',
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'contactId': contactId,
        'categoryKey': categoryKey,
        'values': values,
        'fitKey': fitKey,
        'visibilityKey': visibilityKey,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SizeProfile.fromMap(Map<String, dynamic> map) => SizeProfile(
        contactId: map['contactId'] as String?,
        categoryKey: map['categoryKey'] as String,
        values: Map<String, String>.from(map['values'] as Map),
        fitKey: map['fitKey'] as String?,
        visibilityKey: (map['visibilityKey'] as String?) ?? 'full_access',
        updatedAt:
            DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

// ─── UserProfile ─────────────────────────────────────────────────────────────

class UserProfile {
  final String name;
  final String handle;
  final int memberSince;
  final String? birthdate;
  final String? address;
  final String? mondialRelayPoint;
  final bool hideBirthdate;
  final bool hideAddress;
  final bool hideMondialRelay;
  final String? avatarIcon;
  final Color? avatarColor;
  /// FCM device token for real push notifications.
  final String? fcmToken;

  const UserProfile({
    required this.name,
    required this.handle,
    required this.memberSince,
    this.birthdate,
    this.address,
    this.mondialRelayPoint,
    this.hideBirthdate = false,
    this.hideAddress = false,
    this.hideMondialRelay = false,
    this.avatarIcon,
    this.avatarColor,
    this.fcmToken,
  });

  String get firstName {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty ? parts.first : name;
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'handle': handle,
        'memberSince': memberSince,
        'birthdate': birthdate,
        'address': address,
        'mondialRelayPoint': mondialRelayPoint,
        'hideBirthdate': hideBirthdate,
        'hideAddress': hideAddress,
        'hideMondialRelay': hideMondialRelay,
        'avatarIcon': avatarIcon,
        'avatarColor': avatarColor?.toARGB32(),
        'fcmToken': fcmToken,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        name: (map['name'] as String?) ?? 'You',
        handle: (map['handle'] as String?) ?? '@you',
        memberSince: (map['memberSince'] as int?) ?? DateTime.now().year,
        birthdate: map['birthdate'] as String?,
        address: map['address'] as String?,
        mondialRelayPoint: map['mondialRelayPoint'] as String?,
        hideBirthdate: map['hideBirthdate'] as bool? ?? false,
        hideAddress: map['hideAddress'] as bool? ?? false,
        hideMondialRelay: map['hideMondialRelay'] as bool? ?? false,
        avatarIcon: map['avatarIcon'] as String?,
        avatarColor: map['avatarColor'] != null
            ? Color(map['avatarColor'] as int)
            : null,
        fcmToken: map['fcmToken'] as String?,
      );
}

// ─── GiftContribution ───────────────────────────────────────────────────────

class GiftContribution {
  final String id;
  final String potId;
  final String contributorId;
  final String contributorName;
  final double amount;
  final DateTime contributedAt;
  final String? message;

  GiftContribution({
    required this.id,
    required this.potId,
    required this.contributorId,
    required this.contributorName,
    required this.amount,
    DateTime? contributedAt,
    this.message,
  }) : contributedAt = contributedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'potId': potId,
        'contributorId': contributorId,
        'contributorName': contributorName,
        'amount': amount,
        'contributedAt': contributedAt.toIso8601String(),
        'message': message,
      };

  factory GiftContribution.fromMap(Map<String, dynamic> map) =>
      GiftContribution(
        id: map['id'] as String,
        potId: map['potId'] as String,
        contributorId: map['contributorId'] as String,
        contributorName: map['contributorName'] as String,
        amount: (map['amount'] as num).toDouble(),
        contributedAt: map['contributedAt'] != null
            ? DateTime.tryParse(map['contributedAt'].toString())
            : null,
        message: map['message'] as String?,
      );
}

// ─── GiftPot ────────────────────────────────────────────────────────────────

class GiftPot {
  final String id;
  final String creatorId;
  final String title;
  final String emoji;
  final String? description;
  final String? wishId;
  final String recipientContactId;
  final GiftPotMode mode;
  final GiftPotStatus status;
  final double targetAmount;
  final bool isSurprise;
  final List<String> invitedContactIds;
  final List<GiftContribution> contributions;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? imageUrl;

  double get totalContributed =>
      contributions.fold(0.0, (sum, c) => sum + c.amount);
  double get progressPercent =>
      targetAmount > 0 ? (totalContributed / targetAmount).clamp(0.0, 1.0) : 0.0;
  int get contributorCount => contributions.length;
  double get sharePerPerson =>
      invitedContactIds.isNotEmpty
          ? targetAmount / (invitedContactIds.length + 1)
          : targetAmount;

  GiftPot({
    required this.id,
    required this.creatorId,
    required this.title,
    this.emoji = '🎁',
    this.description,
    this.wishId,
    required this.recipientContactId,
    this.mode = GiftPotMode.amount,
    this.status = GiftPotStatus.open,
    required this.targetAmount,
    this.isSurprise = true,
    this.invitedContactIds = const [],
    this.contributions = const [],
    DateTime? createdAt,
    this.completedAt,
    this.imageUrl,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'creatorId': creatorId,
        'title': title,
        'emoji': emoji,
        'description': description,
        'wishId': wishId,
        'recipientContactId': recipientContactId,
        'mode': mode.name,
        'status': status.name,
        'targetAmount': targetAmount,
        'isSurprise': isSurprise,
        'invitedContactIds': invitedContactIds,
        'contributions': contributions.map((c) => c.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'imageUrl': imageUrl,
      };

  factory GiftPot.fromMap(Map<String, dynamic> map) => GiftPot(
        id: map['id'] as String,
        creatorId: map['creatorId'] as String,
        title: map['title'] as String,
        emoji: (map['emoji'] as String?) ?? '🎁',
        description: map['description'] as String?,
        wishId: map['wishId'] as String?,
        recipientContactId: map['recipientContactId'] as String,
        mode: GiftPotMode.values.firstWhere(
          (e) => e.name == map['mode'],
          orElse: () => GiftPotMode.amount,
        ),
        status: GiftPotStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => GiftPotStatus.open,
        ),
        targetAmount: (map['targetAmount'] as num).toDouble(),
        isSurprise: map['isSurprise'] as bool? ?? true,
        invitedContactIds: List<String>.from(map['invitedContactIds'] ?? []),
        contributions: (map['contributions'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .map(GiftContribution.fromMap)
                .toList() ??
            [],
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString())
            : null,
        completedAt: map['completedAt'] != null
            ? DateTime.tryParse(map['completedAt'].toString())
            : null,
        imageUrl: map['imageUrl'] as String?,
      );
}

// ─── GroupPoll ────────────────────────────────────────────────────────────────

class GroupPoll {
  final String id;
  final String groupId;
  final String question;
  final List<String> options;
  final Map<int, List<String>> votes;
  final DateTime createdAt;
  final String createdBy;
  final bool isActive;

  GroupPoll({
    required this.id,
    required this.groupId,
    required this.question,
    required this.options,
    this.votes = const {},
    DateTime? createdAt,
    this.createdBy = 'self',
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalVotes => votes.values.fold(0, (sum, list) => sum + list.length);

  int votesForOption(int index) => votes[index]?.length ?? 0;

  int? voterChoice(String voterId) {
    for (final entry in votes.entries) {
      if (entry.value.contains(voterId)) return entry.key;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'groupId': groupId,
        'question': question,
        'options': options,
        'votes': votes.map((k, v) => MapEntry(k.toString(), v)),
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
        'isActive': isActive,
      };

  factory GroupPoll.fromMap(Map<String, dynamic> map) => GroupPoll(
        id: map['id'] as String,
        groupId: map['groupId'] as String,
        question: map['question'] as String,
        options: List<String>.from(map['options'] ?? []),
        votes: (map['votes'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(int.parse(k), List<String>.from(v)),
            ) ??
            {},
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'].toString())
            : null,
        createdBy: map['createdBy'] as String? ?? 'self',
        isActive: map['isActive'] as bool? ?? true,
      );
}
