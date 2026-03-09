part of 'app_state.dart';
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

// ─── Size Profile Management ──────────────────────────────────────────────────

extension SizesExtension on PigioAppState {
  /// Own size profiles sorted by most recently updated.
  List<SizeProfile> get recentSizeUpdates {
    final copy = _sizes.where((s) => s.contactId == null).toList();
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }

  /// All size profiles for a given contact (null = own profile).
  List<SizeProfile> getSizesFor(String? contactId) {
    return _sizes.where((s) => s.contactId == contactId).toList();
  }

  bool _canSeeSizeProfile(SizeProfile profile, TrustLevel viewerTrustLevel) {
    // For exchanged contact profiles, show all sizes unless explicitly limited.
    if (profile.contactId != null) {
      return profile.visibilityKey != 'limited_view';
    }

    switch (profile.visibilityKey) {
      case 'full_access':
        return viewerTrustLevel == TrustLevel.family;
      case 'general_access':
        return viewerTrustLevel == TrustLevel.family ||
            viewerTrustLevel == TrustLevel.friend;
      case 'limited_view':
        return false;
      default:
        return true;
    }
  }

  /// Returns sizes visible to a viewer with the given trust level.
  List<SizeProfile> getVisibleSizesFor(
    String? contactId, {
    required TrustLevel viewerTrustLevel,
  }) {
    return _sizes
        .where((s) => s.contactId == contactId)
        .where((s) => _canSeeSizeProfile(s, viewerTrustLevel))
        .toList();
  }

  /// Save or update a size profile for [contactId] (null = own profile).
  void saveSizeProfile(
    String categoryKey,
    Map<String, String> values, {
    String? contactId,
    String? fitKey,
    String visibilityKey = 'general_access',
  }) {
    final hadExisting = _sizes.any(
      (s) => s.categoryKey == categoryKey && s.contactId == contactId,
    );
    final cleanValues = <String, String>{};
    for (final entry in values.entries) {
      final v = entry.value.trim();
      if (v.isNotEmpty) cleanValues[entry.key] = v;
    }
    if (cleanValues.isEmpty) return;

    final profile = SizeProfile(
      contactId: contactId,
      categoryKey: categoryKey,
      values: cleanValues,
      fitKey: fitKey,
      visibilityKey: visibilityKey,
      updatedAt: DateTime.now(),
    );

    final idx = _sizes.indexWhere(
        (s) => s.categoryKey == categoryKey && s.contactId == contactId);
    if (idx >= 0) {
      // Merge values to avoid losing existing sections
      final existingValues = Map<String, String>.from(_sizes[idx].values);
      existingValues.addAll(cleanValues);

      _sizes[idx] = SizeProfile(
        contactId: contactId,
        categoryKey: categoryKey,
        values: existingValues,
        fitKey: fitKey ?? _sizes[idx].fitKey,
        visibilityKey: visibilityKey,
        updatedAt: DateTime.now(),
      );
    } else {
      _sizes.add(profile);
    }

    notifyListeners();
    _saveData();

    // If own sizes changed, push to all contacts
    if (contactId == null) {
      Future.microtask(_pushOwnContactProfile);
      Future.microtask(() => _sendNotificationToContacts(
            'sizes_updated',
            '${_profile.name} a mis à jour ses tailles.',
          ));
      awardMascotProgress(
        hadExisting ? 3 : 7,
        emoji: hadExisting ? null : '📏',
        titleFr: hadExisting ? null : 'Premiere taille enregistree',
        titleEn: hadExisting ? null : 'First size profile saved',
      );
    }
  }
}
