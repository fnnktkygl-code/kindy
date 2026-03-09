import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/models/app_models.dart';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';

void showWishDetailSheet(BuildContext context, Wish wish) {
  final theme = context.ptnl;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _WishDetailSheet(wish: wish, theme: theme),
  );
}

class _WishDetailSheet extends StatelessWidget {
  final Wish wish;
  final PigioThemeData theme;

  const _WishDetailSheet({required this.wish, required this.theme});

  ImageProvider? _getImageProvider(String path) {
    if (path.isEmpty || path == 'null') return null;
    if (path.startsWith('http')) return CachedNetworkImageProvider(path);
    final file = File(path);
    if (file.existsSync()) return FileImage(file);
    return null;
  }

  String get _priceLabel {
    switch (wish.priceRange) {
      case WishPriceRange.budget:
        return '< 30€';
      case WishPriceRange.mid:
        return '30 – 100€';
      case WishPriceRange.premium:
        return '100€+';
      case null:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = wish.imageUrl != null ? _getImageProvider(wish.imageUrl!) : null;
    final isReserved = wish.reservedById != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Image or emoji hero
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(20),
                image: imageProvider != null
                    ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: imageProvider != null
                  ? null
                  : Text(wish.emoji, style: const TextStyle(fontSize: 72)),
            ),
          ),

          // Reserved overlay badge
          if (isReserved) ...[
            const SizedBox(height: 10),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.success.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: theme.success, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    wish.reservedById == 'self' ? 'Réservé par vous' : 'Déjà réservé',
                    style: fw(size: 13, w: FontWeight.w700, color: theme.success),
                  ),
                ],
              ),
            ),
          ],

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  wish.title,
                  style: GoogleFonts.caveat(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.ink,
                    height: 1.2,
                  ),
                ),

                // Price range
                if (wish.priceRange != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.divider),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _priceLabel,
                      style: GoogleFonts.caveat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.mid,
                      ),
                    ),
                  ),
                ],

                // Notes
                if (wish.notes != null && wish.notes!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      wish.notes!,
                      style: fw(size: 14, w: FontWeight.w500, color: theme.ink),
                    ),
                  ),
                ],

                // URL button
                if (wish.url != null && wish.url!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  PigioButton(
                    label: 'Voir le lien',
                    icon: Icons.open_in_new,
                    color: theme.primary.withValues(alpha: 0.12),
                    textColor: theme.primary,
                    height: 46,
                    fontSize: 14,
                    fullWidth: true,
                    onTap: () async {
                      final uri = Uri.tryParse(wish.url!);
                      if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
