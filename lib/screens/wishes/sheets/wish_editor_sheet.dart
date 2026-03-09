import 'dart:io';
import 'package:pigio_app/core/theme/pigio_theme.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/i18n/i18n.dart';
import 'package:pigio_app/shared/widgets/ui_widgets.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

class WishEditorSheet extends StatefulWidget {
  final PigioAppState state;
  final String? contactId;
  final Wish? existingWish;

  const WishEditorSheet({super.key, required this.state, this.contactId, this.existingWish});

  @override
  State<WishEditorSheet> createState() => _WishEditorSheetState();
}

class _WishEditorSheetState extends State<WishEditorSheet> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _linkCtrl = TextEditingController();

  WishPriority _priority = WishPriority.medium;
  WishPriceRange? _priceRange;
  String? _imageUrl;
  File? _customImageFile;
  
  String? _urlError;

  @override
  void initState() {
    super.initState();
    if (widget.existingWish != null) {
      _titleCtrl.text = widget.existingWish!.title;
      _linkCtrl.text = widget.existingWish!.url ?? '';
      _imageUrl = widget.existingWish!.imageUrl;
      _priority = widget.existingWish!.priority;
      _priceRange = widget.existingWish!.priceRange;
    }

    _titleCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _linkCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _pickCustomImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _customImageFile = File(image.path);
        _imageUrl = null; // Prioritize local file
      });
    }
  }

  String? _validateAndNormalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // Reject dangerous schemes before any normalization
    final lower = trimmed.toLowerCase();
    const blocked = ['javascript:', 'data:', 'vbscript:', 'file:', 'blob:'];
    if (blocked.any(lower.startsWith)) return null;

    String normalized = trimmed;
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      normalized = 'https://$trimmed';
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) return null;
    if (!['http', 'https'].contains(uri.scheme)) return null;
    // Host must look like a real domain (contains a dot, not just localhost tricks)
    if (uri.host.isEmpty || !uri.host.contains('.')) return null;

    if (uri.scheme == 'http') {
      normalized = normalized.replaceFirst('http://', 'https://');
    }

    return normalized;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    return Container(
      decoration: BoxDecoration(
        color: theme.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.existingWish != null ? "Modifier" : t(context, 'add_new'), style: fw(size: 22, w: FontWeight.w900, color: theme.ink)),
                  Row(
                    children: [
                      if (widget.existingWish != null)
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.accent2),
                          onPressed: () {
                            final deleted = widget.existingWish!;
                            context.read<PigioAppState>().deleteWish(deleted.id);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${deleted.title} supprimée'),
                                action: SnackBarAction(
                                  label: 'Annuler',
                                  onPressed: () => context.read<PigioAppState>().undoDeleteWish(deleted),
                                ),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          },
                        ),
                      IconButton(
                        icon: Icon(Icons.close, color: theme.mid),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  )
                ],
              ),
            ),
            
            Divider(height: 1, color: theme.surface),
            
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text("Titre de l'envie".toUpperCase(), style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
                      child: TextField(
                        controller: _titleCtrl,
                        textInputAction: TextInputAction.next,
                        style: fw(size: 18, w: FontWeight.w800, color: theme.ink),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "Ex: Baskets Nike, Livre...",
                          hintStyle: fw(size: 16, w: FontWeight.w600, color: theme.light),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Link
                    Text("Lien (Optionnel)".toUpperCase(), style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: _urlError != null ? Border.all(color: theme.error) : null,
                      ),
                      child: TextField(
                        controller: _linkCtrl,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.url,
                        style: fw(size: 16, w: FontWeight.w600, color: theme.primary),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: "https://...",
                          hintStyle: fw(size: 16, w: FontWeight.w600, color: theme.light),
                          icon: Icon(Icons.link, color: theme.mid, size: 20),
                        ),
                      ),
                    ),
                    if (_urlError != null) ...[
                      const SizedBox(height: 4),
                      Text(_urlError!, style: fw(size: 11, w: FontWeight.w700, color: theme.error)),
                    ],

                    const SizedBox(height: 24),

                    // Image Selector
                    Text("Image du souhait".toUpperCase(), style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickCustomImage,
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(20),
                          image: (_customImageFile != null || _imageUrl != null)
                              ? DecorationImage(
                                  image: _customImageFile != null
                                      ? FileImage(_customImageFile!) as ImageProvider
                                      : CachedNetworkImageProvider(_imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          border: (_customImageFile == null && _imageUrl == null)
                              ? Border.all(color: theme.mid.withValues(alpha: 0.2), width: 2, strokeAlign: BorderSide.strokeAlignInside)
                              : null,
                        ),
                        child: (_customImageFile == null && _imageUrl == null)
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 32, color: theme.mid),
                                  const SizedBox(height: 8),
                                  Text("AJOUTER UNE PHOTO", style: fw(size: 12, w: FontWeight.w800, color: theme.mid)),
                                ],
                              )
                            : Container(
                                alignment: Alignment.bottomRight,
                                padding: const EdgeInsets.all(12),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                                  child: const Icon(Icons.edit, size: 16, color: Colors.white),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Priority & Price
                    Text("Priorité".toUpperCase(), style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildChoiceChip(theme, "🟢 BASSE", _priority == WishPriority.low, () => setState(() => _priority = WishPriority.low)),
                        const SizedBox(width: 8),
                        _buildChoiceChip(theme, "🟡 MOYENNE", _priority == WishPriority.medium, () => setState(() => _priority = WishPriority.medium)),
                        const SizedBox(width: 8),
                        _buildChoiceChip(theme, "🔴 HAUTE", _priority == WishPriority.high, () => setState(() => _priority = WishPriority.high)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text("Tranche de Prix".toUpperCase(), style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildChoiceChip(theme, "??", _priceRange == null, () => setState(() => _priceRange = null)),
                          const SizedBox(width: 8),
                          _buildChoiceChip(theme, "< 30€", _priceRange == WishPriceRange.budget, () => setState(() => _priceRange = WishPriceRange.budget)),
                          const SizedBox(width: 8),
                          _buildChoiceChip(theme, "30-100€", _priceRange == WishPriceRange.mid, () => setState(() => _priceRange = WishPriceRange.mid)),
                          const SizedBox(width: 8),
                          _buildChoiceChip(theme, "100€+", _priceRange == WishPriceRange.premium, () => setState(() => _priceRange = WishPriceRange.premium)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            
            // Footer Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PigioButton(
                label: widget.existingWish != null ? t(context, 'update') : t(context, 'save'),
                color: widget.existingWish != null ? theme.warning : theme.accent2,
                textColor: theme.onAccent,
                onTap: () {
                  if (_titleCtrl.text.isNotEmpty) {
                    final rawUrl = _linkCtrl.text;
                    String? finalUrl;
                    
                    if (rawUrl.trim().isNotEmpty) {
                       final validUrl = _validateAndNormalizeUrl(rawUrl);
                       if (validUrl == null) {
                         setState(() => _urlError = "URL invalide (HTTP/HTTPS requis)");
                         return;
                       }
                       finalUrl = validUrl;
                    }
                    setState(() => _urlError = null);
                    
                    if (widget.existingWish != null) {
                      context.read<PigioAppState>().updateWish(
                        widget.existingWish!.id,
                        title: _titleCtrl.text.trim(),
                        url: finalUrl ?? clearUrlSentinel, 
                        imageUrl: _customImageFile != null ? _customImageFile!.path : (_imageUrl ?? clearUrlSentinel),
                        contactId: widget.contactId,
                        priority: _priority,
                        priceRange: _priceRange,
                      );
                    } else {
                      context.read<PigioAppState>().addWish(
                        title: _titleCtrl.text.trim(),
                        url: finalUrl,
                        imageUrl: _customImageFile != null ? _customImageFile!.path : _imageUrl,
                        contactId: widget.contactId,
                        priority: _priority,
                        priceRange: _priceRange,
                      );
                    }
                    Navigator.pop(context, true);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(PigioThemeData theme, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent2 : theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? theme.accent2 : theme.divider, width: 1.5),
        ),
        child: Text(label, style: fw(size: 13, w: FontWeight.w800, color: isSelected ? theme.onAccent : theme.mid)),
      ),
    );
  }
}
