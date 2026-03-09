part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Wish Management ─────────────────────────────────────────────────────────

extension WishesExtension on PigioAppState {
  void addWish({
    required String title,
    String emoji = '🎁',
    String? url,
    String? imageUrl,
    String? contactId,
    WishPriority priority = WishPriority.medium,
    WishPriceRange? priceRange,
    String? notes,
  }) {
    final isFirstOwnWish = contactId == null && getWishesFor(null).isEmpty;
    _wishes.add(Wish(
      id: _newId(),
      title: title,
      emoji: emoji,
      url: url,
      imageUrl: imageUrl,
      contactId: contactId,
      priority: priority,
      priceRange: priceRange,
      notes: notes,
    ));
    _invalidateWishCache();
    notifyListeners();
    _saveData();
    logActivity('Envie ajoutée : $title', emoji, contactId: contactId);
    if (contactId == null) {
      awardMascotProgress(
        isFirstOwnWish ? 12 : 6,
        emoji: isFirstOwnWish ? '🎁' : null,
        titleFr: isFirstOwnWish ? 'Premiere envie ajoutee' : null,
        titleEn: isFirstOwnWish ? 'First wish added' : null,
      );

      // Notify contacts about new wish (only for own wishes)
      Future.microtask(() => _sendNotificationToContacts(
            'wish_added',
            '${_profile.name} a ajouté une envie : $title',
          ));
    }
  }

  void updateWish(
    String id, {
    String? title,
    String? url = clearUrlSentinel,
    String? imageUrl = clearUrlSentinel,
    String? contactId,
    WishPriority? priority,
    WishPriceRange? priceRange,
    String? notes,
  }) {
    final idx = _wishes.indexWhere((w) => w.id == id);
    if (idx >= 0) {
      final current = _wishes[idx];
      _wishes[idx] = Wish(
        id: current.id,
        title: title ?? current.title,
        emoji: current.emoji,
        url: url == clearUrlSentinel ? current.url : url,
        imageUrl: imageUrl == clearUrlSentinel ? current.imageUrl : imageUrl,
        addedAt: current.addedAt,
        contactId: contactId ?? current.contactId,
        reservedById: current.reservedById,
        priority: priority ?? current.priority,
        priceRange: priceRange ?? current.priceRange,
        notes: notes ?? current.notes,
        giftPotId: current.giftPotId,
      );
      _invalidateWishCache();
      notifyListeners();
      _saveData();
    }
  }

  void deleteWish(String id) {
    final wish = _wishes.where((w) => w.id == id).firstOrNull;
    _wishes.removeWhere((w) => w.id == id);
    _invalidateWishCache();
    notifyListeners();
    _saveData();
    if (wish != null) logActivity('Envie supprimée : ${wish.title}', '🗑️');
  }

  void undoDeleteWish(Wish wish) {
    _wishes.add(wish);
    _invalidateWishCache();
    notifyListeners();
    _saveData();
  }

  void toggleReserveWish(String wishId, String reserveeId) {
    final idx = _wishes.indexWhere((w) => w.id == wishId);
    if (idx >= 0) {
      final current = _wishes[idx];
      final nextReservedById = current.reservedById == reserveeId ? null : reserveeId;
      _wishes[idx] = Wish(
        id: current.id,
        title: current.title,
        emoji: current.emoji,
        url: current.url,
        imageUrl: current.imageUrl,
        addedAt: current.addedAt,
        contactId: current.contactId,
        reservedById: nextReservedById,
        priority: current.priority,
        priceRange: current.priceRange,
        notes: current.notes,
        giftPotId: current.giftPotId,
      );
      _invalidateWishCache();
      notifyListeners();
      _saveData();
      if (nextReservedById != null) {
        setMascotMoment(MascotMoment.wishReserved);
        awardMascotProgress(
          8,
          emoji: '🤫',
          titleFr: 'Cadeau reserve sans doublon',
          titleEn: 'Gift reserved without duplicates',
        );
      }
    }
  }

  /// Returns active (not archived) wishes for a contact (null = main user). Uses O(1) cache.
  List<Wish> getWishesFor(String? contactId) {
    _wishCache ??= {};
    if (_wishCache!.containsKey(contactId)) return _wishCache![contactId]!;

    final twelveMonthsAgo = DateTime.now().subtract(const Duration(days: 365));
    final result = _wishes.where((w) {
      return w.contactId == contactId && w.addedAt.isAfter(twelveMonthsAgo);
    }).toList();

    _wishCache![contactId] = result;
    return result;
  }

  /// Returns wishes that are >12 months old.
  List<Wish> getArchivedWishesFor(String? contactId) {
    final twelveMonthsAgo = DateTime.now().subtract(const Duration(days: 365));
    return _wishes.where((w) {
      return w.contactId == contactId && w.addedAt.isBefore(twelveMonthsAgo);
    }).toList();
  }

  /// Checks if the specific contact added a wish in the current month/year.
  bool hasAddedWishThisMonth(String? contactId) {
    final now = DateTime.now();
    return _wishes.any((w) {
      return w.contactId == contactId &&
          w.addedAt.year == now.year &&
          w.addedAt.month == now.month;
    });
  }
}
