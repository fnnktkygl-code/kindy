import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kindy/core/state/app_state.dart';
import 'analytics_service.dart';

/// Generates and shares a wishlist link that doubles as a growth loop.
/// Recipients see the wishlist on pigio.app with a CTA to create their own.
class WishlistShareService {
  WishlistShareService._();

  /// Share the user's own wishlist as a link.
  /// The link routes to pigio.app/wishlist/[syncKey] which shows the user's
  /// public wishes and prompts non-users to install the app.
  static Future<void> shareMyWishlist({
    required BuildContext context,
    required PigioAppState state,
  }) async {
    final syncKey = state.syncKey;
    if (syncKey.isEmpty) return;

    final isFr = state.locale.languageCode == 'fr';
    final name = state.profile.name;
    final wishCount = state.getWishesFor(null).length;

    final url = 'https://pigio.app/wishlist/$syncKey';
    final text = isFr
        ? '$name partage sa liste d\'envies sur Pigio ($wishCount envie${wishCount > 1 ? 's' : ''}) !\n$url'
        : '$name is sharing their wishlist on Pigio ($wishCount wish${wishCount > 1 ? 'es' : ''})!\n$url';

    await SharePlus.instance.share(ShareParams(text: text));
    AnalyticsService.log('wishlist_shared', {'wishes': wishCount});
  }

  /// Share a specific contact's wishlist (for circle coordination).
  static Future<void> shareContactWishlist({
    required BuildContext context,
    required PigioAppState state,
    required String contactId,
  }) async {
    final contact = state.contacts.where((c) => c.id == contactId).firstOrNull;
    if (contact == null) return;

    final wishes = state.getWishesFor(contactId);
    final isFr = state.locale.languageCode == 'fr';

    final text = isFr
        ? 'Liste d\'envies de ${contact.name} sur Pigio (${wishes.length} idée${wishes.length > 1 ? 's' : ''}) !\nTéléchargez Pigio pour coordonner les cadeaux : https://pigio.app'
        : '${contact.name}\'s wishlist on Pigio (${wishes.length} idea${wishes.length > 1 ? 's' : ''})!\nDownload Pigio to coordinate gifts: https://pigio.app';

    await SharePlus.instance.share(ShareParams(text: text));
    AnalyticsService.log('contact_wishlist_shared', {'contact': contactId});
  }
}
