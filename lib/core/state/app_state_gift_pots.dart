part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Gift Pot (Cagnotte) Management ─────────────────────────────────────────

extension GiftPotsExtension on PigioAppState {
  // ── Queries ───────────────────────────────────────────────────────────────

  List<GiftPot> getMyCreatedPots() =>
      _giftPots.where((p) => p.creatorId == 'self').toList();

  List<GiftPot> getPotsForContribution() =>
      _giftPots.where((p) => p.creatorId != 'self').toList();

  List<GiftPot> getPotsForRecipient(String contactId) =>
      _giftPots.where((p) => p.recipientContactId == contactId).toList();

  List<GiftPot> get activePots =>
      _giftPots.where((p) => p.status == GiftPotStatus.open).toList();

  GiftPot? getPotById(String potId) =>
      _giftPots.where((p) => p.id == potId).firstOrNull;

  GiftPot? getPotForWish(String wishId) =>
      _giftPots.where((p) => p.wishId == wishId).firstOrNull;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  void createGiftPot({
    required String title,
    String emoji = '🎁',
    String? description,
    String? wishId,
    required String recipientContactId,
    required GiftPotMode mode,
    required double targetAmount,
    bool isSurprise = true,
    List<String> invitedContactIds = const [],
    String? imageUrl,
  }) {
    final potId = _newId();
    _giftPots.add(GiftPot(
      id: potId,
      creatorId: 'self',
      title: title,
      emoji: emoji,
      description: description,
      wishId: wishId,
      recipientContactId: recipientContactId,
      mode: mode,
      targetAmount: targetAmount,
      isSurprise: isSurprise,
      invitedContactIds: invitedContactIds,
      imageUrl: imageUrl,
    ));

    // Link the wish if provided
    if (wishId != null) {
      final idx = _wishes.indexWhere((w) => w.id == wishId);
      if (idx >= 0) {
        final w = _wishes[idx];
        _wishes[idx] = Wish(
          id: w.id,
          title: w.title,
          emoji: w.emoji,
          url: w.url,
          imageUrl: w.imageUrl,
          addedAt: w.addedAt,
          contactId: w.contactId,
          reservedById: w.reservedById,
          priority: w.priority,
          priceRange: w.priceRange,
          notes: w.notes,
          giftPotId: potId,
        );
        _invalidateWishCache();
      }
    }

    notifyListeners();
    _saveData();
    logActivity('Cagnotte créée : $title', '🎉',
        contactId: recipientContactId);
    awardMascotProgress(
      10,
      emoji: '🤝',
      titleFr: 'Cagnotte lancee avec Pigio',
      titleEn: 'Gift pot launched with Pigio',
    );

    // Notify invited contacts (exclude recipient if surprise)
    for (final contactId in invitedContactIds) {
      if (isSurprise && contactId == recipientContactId) continue;
      Future.microtask(() => _sendNotificationToContact(
            contactId,
            'pot_invite',
            '${_profile.name} vous invite à participer : $title',
          ));
    }
  }

  void markParticipantPaid({
    required String potId,
    required String contactId,
    required double amount,
    String? message,
  }) {
    final idx = _giftPots.indexWhere((p) => p.id == potId);
    if (idx < 0) return;
    final pot = _giftPots[idx];
    // If already paid, remove old contribution first
    final existingContributions = List<GiftContribution>.from(pot.contributions)
      ..removeWhere((c) => c.contributorId == contactId);

    final contactName = _contacts
            .where((c) => c.id == contactId)
            .firstOrNull
            ?.name ??
        contactId;

    existingContributions.add(GiftContribution(
      id: _newId(),
      potId: potId,
      contributorId: contactId,
      contributorName: contactName,
      amount: amount,
      message: message,
    ));

    _giftPots[idx] = GiftPot(
      id: pot.id,
      creatorId: pot.creatorId,
      title: pot.title,
      emoji: pot.emoji,
      description: pot.description,
      wishId: pot.wishId,
      recipientContactId: pot.recipientContactId,
      mode: pot.mode,
      status: pot.status,
      targetAmount: pot.targetAmount,
      isSurprise: pot.isSurprise,
      invitedContactIds: pot.invitedContactIds,
      contributions: existingContributions,
      createdAt: pot.createdAt,
      completedAt: pot.completedAt,
      imageUrl: pot.imageUrl,
    );

    notifyListeners();
    _saveData();
    logActivity(
        'Paiement de ${amount.toStringAsFixed(0)}€ enregistré pour ${pot.title}',
        '💰',
        contactId: contactId);
  }

  void addContribution({
    required String potId,
    required double amount,
    String? message,
  }) {
    final idx = _giftPots.indexWhere((p) => p.id == potId);
    if (idx < 0) return;
    final pot = _giftPots[idx];

    final newContributions = List<GiftContribution>.from(pot.contributions)
      ..add(GiftContribution(
        id: _newId(),
        potId: potId,
        contributorId: 'self',
        contributorName: _profile.name,
        amount: amount,
        message: message,
      ));

    _giftPots[idx] = GiftPot(
      id: pot.id,
      creatorId: pot.creatorId,
      title: pot.title,
      emoji: pot.emoji,
      description: pot.description,
      wishId: pot.wishId,
      recipientContactId: pot.recipientContactId,
      mode: pot.mode,
      status: pot.status,
      targetAmount: pot.targetAmount,
      isSurprise: pot.isSurprise,
      invitedContactIds: pot.invitedContactIds,
      contributions: newContributions,
      createdAt: pot.createdAt,
      completedAt: pot.completedAt,
      imageUrl: pot.imageUrl,
    );

    notifyListeners();
    _saveData();
    logActivity(
        'Contribution de ${amount.toStringAsFixed(0)}€ pour ${pot.title}',
        '💰');
  }

  void updateGiftPot(
    String potId, {
    String? title,
    double? targetAmount,
    GiftPotStatus? status,
    List<String>? invitedContactIds,
    bool? isSurprise,
  }) {
    final idx = _giftPots.indexWhere((p) => p.id == potId);
    if (idx < 0) return;
    final pot = _giftPots[idx];

    _giftPots[idx] = GiftPot(
      id: pot.id,
      creatorId: pot.creatorId,
      title: title ?? pot.title,
      emoji: pot.emoji,
      description: pot.description,
      wishId: pot.wishId,
      recipientContactId: pot.recipientContactId,
      mode: pot.mode,
      status: status ?? pot.status,
      targetAmount: targetAmount ?? pot.targetAmount,
      isSurprise: isSurprise ?? pot.isSurprise,
      invitedContactIds: invitedContactIds ?? pot.invitedContactIds,
      contributions: pot.contributions,
      createdAt: pot.createdAt,
      completedAt: status == GiftPotStatus.completed
          ? DateTime.now()
          : pot.completedAt,
      imageUrl: pot.imageUrl,
    );

    notifyListeners();
    _saveData();

    // Notify contributors when pot is completed
    if (status == GiftPotStatus.completed) {
      for (final contactId in pot.invitedContactIds) {
        Future.microtask(() => _sendNotificationToContact(
              contactId,
              'pot_completed',
              'La cagnotte « ${pot.title} » est terminée ! 🎊',
            ));
      }
    }
  }

  void deleteGiftPot(String potId) {
    final pot = _giftPots.where((p) => p.id == potId).firstOrNull;
    _giftPots.removeWhere((p) => p.id == potId);

    // Unlink wish if any
    if (pot?.wishId != null) {
      final wIdx = _wishes.indexWhere((w) => w.id == pot!.wishId);
      if (wIdx >= 0) {
        final w = _wishes[wIdx];
        _wishes[wIdx] = Wish(
          id: w.id,
          title: w.title,
          emoji: w.emoji,
          url: w.url,
          imageUrl: w.imageUrl,
          addedAt: w.addedAt,
          contactId: w.contactId,
          reservedById: w.reservedById,
          priority: w.priority,
          priceRange: w.priceRange,
          notes: w.notes,
          giftPotId: null,
        );
        _invalidateWishCache();
      }
    }

    notifyListeners();
    _saveData();
    if (pot != null) {
      logActivity('Cagnotte supprimée : ${pot.title}', '🗑️');
    }
  }
}
