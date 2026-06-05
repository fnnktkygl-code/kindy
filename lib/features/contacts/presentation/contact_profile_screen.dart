import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/i18n/i18n.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import '../../../shared/widgets/ui_widgets.dart';
import 'package:kindy/screens/sizes/sheets/size_editor_sheet.dart';
import 'package:kindy/screens/contacts/sheets/add_profile_sheet.dart';
import 'package:kindy/screens/wishes/sheets/wish_editor_sheet.dart';
import 'package:kindy/screens/groups/sheets/add_group_sheet.dart';
import 'package:kindy/screens/wishes/sheets/wizz_sheet.dart';
import 'package:kindy/screens/wishes/sheets/wish_detail_sheet.dart';
import '../../../shared/widgets/wish_card.dart';
import '../../../shared/widgets/invite_bottom_sheet.dart';
import 'widgets/contact_profile_header.dart';
import 'widgets/contact_sizes_section.dart';
import 'widgets/contact_delivery_section.dart';
import 'widgets/contact_wishes_history_section.dart';
import 'widgets/contact_danger_zone.dart';
import '../../../shared/widgets/ai_gift_suggestions.dart';
import 'widgets/contact_invite_status_section.dart';

class ContactProfileScreen extends StatefulWidget {
  final ContactProfile contact;

  const ContactProfileScreen({super.key, required this.contact});

  @override
  State<ContactProfileScreen> createState() => _ContactProfileScreenState();
}

class _ContactProfileScreenState extends State<ContactProfileScreen>
    with TickerProviderStateMixin {
  late final AnimationController _avatarShakeCtrl;
  late final Animation<double> _avatarShakeAnim;

  Map<String, Map<String, dynamic>> _getMeta(PigioThemeData theme) => {
    'clothes': {
      'emoji': '👕',
      'bg': theme.primary.withValues(alpha: 0.15),
      'visColor': theme.primary,
      'fields': ['standard', 'eu_clothes'],
      'fits': ['slim', 'regular', 'oversized'],
    },
    'bottoms': {
      'emoji': '👖',
      'bg': theme.success.withValues(alpha: 0.15),
      'visColor': theme.success,
      'fields': ['eu_bottoms', 'us_waist', 'us_length', 'standard'],
      'fits': ['skinny', 'straight', 'relaxed'],
    },
    'shoes': {
      'emoji': '👟',
      'bg': theme.accent3.withValues(alpha: 0.15),
      'visColor': theme.accent3,
      'fields': ['eu_shoes', 'us_shoes', 'uk_shoes', 'cm_shoes'],
      'fits': ['regular'],
    },
  };

  @override
  void initState() {
    super.initState();
    _avatarShakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _avatarShakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -5.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 2),
    ]).animate(CurvedAnimation(parent: _avatarShakeCtrl, curve: Curves.linear));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = context.read<PigioAppState>();
        state.recordProfileView(widget.contact.id);

        // NOUVEAU: Rafraîchir les données approfondies (tailles, envies)
        // si le contact a rejoint Pigio et qu'on consulte son profil.
        final c = state.contacts.firstWhere((c) => c.id == widget.contact.id, orElse: () => widget.contact);
        if (c.status == ContactStatus.joined) {
          state.refreshContactData(c.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _avatarShakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context);
    final contact = state.contacts.firstWhere((c) => c.id == widget.contact.id, orElse: () => widget.contact);
    final sizes = state.getVisibleSizesFor(contact.id, viewerTrustLevel: contact.trustLevel);
    final isFamily = contact.isFamily;
    final isInvited = contact.status == ContactStatus.invited;
    final canEditProfile = contact.isManaged && !isInvited;
    final canEditTrustLevel = !isInvited;

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: PigioAppBar(
        title: contact.name,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContactProfileHeader(
                contact: contact,
                isFamily: isFamily,
                canEditProfile: canEditProfile,
                canEditTrustLevel: canEditTrustLevel,
                theme: theme,
                avatarShakeAnimation: _avatarShakeAnim,
                inviteStatusSection: ContactInviteStatusSection(
                  state: state,
                  contact: contact,
                  theme: theme,
                  onOpenInvite: () => _openInviteSheet(context, contact),
                  onConfirmReset: () => _confirmResetContact(context, state, contact, theme),
                  onConfirmResend: () => _confirmResendInvite(context, state, contact, theme),
                ),
                onEdit: () => _showProfileEditor(state, contact),
                onPickCircle: () => _showGroupPicker(context, state, contact),
                onWizz: () => _openWizzSheet(context, state, contact, theme),
              ),

              if (isFamily)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.success.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.success.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.security, size: 18, color: theme.success),
                        const SizedBox(width: 12),
                        Expanded(child: Text("Profil Famille : Accès exceptionnel aux mesures et coordonnées.", style: fw(size: 12, w: FontWeight.w600, color: theme.success))),
                      ],
                    ),
                  ),
                ),

              ContactSizesSection(
                contact: contact,
                sizes: sizes,
                canEditProfile: canEditProfile,
                theme: theme,
                buildSizeCard: (key, emoji, color) =>
                    _buildSizeCard(context, state, sizes, key, emoji, color, contact.id),
              ),

              ContactDeliverySection(
                contact: contact,
                canEditProfile: canEditProfile,
                theme: theme,
                onEditProfile: () => _showProfileEditor(state, contact),
              ),

              // AI Gift Suggestions with affiliate links
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: AiGiftSuggestions(
                  contact: contact,
                  state: state,
                  theme: theme,
                ),
              ),

              ContactWishesHistorySection(
                canEditProfile: canEditProfile,
                theme: theme,
                onAddWish: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => WishEditorSheet(contactId: contact.id, state: state),
                  );
                },
                historyChildren: _buildWishesHistory(context, state, contact.id, theme),
              ),

              ContactDangerZone(
                theme: theme,
                onDelete: () => _confirmDeleteContact(context, state, contact, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizeCard(BuildContext context, PigioAppState state, List<SizeProfile> profiles, String key, String emoji, Color color, String contactId) {
    final theme = context.pt;
    final profile = profiles.where((s) => s.categoryKey == key).firstOrNull;
    final canEditProfile = state.contacts.firstWhere((c) => c.id == contactId).isManaged;

    List<String> values = [];
    if (profile != null) {
      if (key == 'clothes') {
        if (profile.values['standard'] != null) values.add(profile.values['standard']!);
        if (profile.values['eu_clothes'] != null) values.add(profile.values['eu_clothes']!);
      } else if (key == 'bottoms') {
        if (profile.values['eu_bottoms'] != null) values.add(profile.values['eu_bottoms']!);
        if (profile.values['us_waist'] != null && profile.values['us_length'] != null) {
          values.add("W${profile.values['us_waist']} L${profile.values['us_length']}");
        } else if (profile.values['us_waist'] != null) {
          values.add("W${profile.values['us_waist']}");
        }
        if (profile.values['standard'] != null) values.add(profile.values['standard']!);
      } else if (key == 'shoes') {
        if (profile.values['eu_shoes'] != null) values.add(profile.values['eu_shoes']!);
        if (profile.values['cm_shoes'] != null) values.add("${profile.values['cm_shoes']}cm");
        if (profile.values['us_shoes'] != null) values.add("${profile.values['us_shoes']} US");
      }
    }

    String displayVal = values.isEmpty ? "-" : values.join(" • ");

    return GestureDetector(
      onTap: canEditProfile ? () => _showSizeEditor(state, key, contactId, theme) : null,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            decoration: BoxDecoration(
              color: theme.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 12),
                Text(
                  displayVal,
                  textAlign: TextAlign.center,
                  style: fw(size: values.length > 2 ? 14 : 18, w: FontWeight.w900, color: color),
                ),
                const SizedBox(height: 6),
                Text(t(context, key), style: fw(size: 11, w: FontWeight.w700, color: theme.mid)),
              ],
            ),
          ),
          Positioned(
            top: 10, right: 10,
            child: Icon(
              canEditProfile ? Icons.add_circle_outline : Icons.lock_outline,
              size: 16,
              color: color.withValues(alpha: 0.5),
            ),
          )
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const m = ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"];
    return m[month - 1];
  }

  List<Widget> _buildWishesHistory(BuildContext context, PigioAppState state, String contactId, PigioThemeData theme) {
    final wishes = state.getWishesFor(contactId);

    if (wishes.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.divider),
          ),
          child: Column(
            children: [
              Icon(Icons.history, size: 40, color: theme.light),
              const SizedBox(height: 12),
              Text("Aucune envie récente", style: fw(size: 14, w: FontWeight.w800, color: theme.mid)),
            ],
          ),
        )
      ];
    }

    wishes.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    Map<String, List<Wish>> grouped = {};
    for (var w in wishes) {
      final key = "${w.addedAt.year}-${w.addedAt.month.toString().padLeft(2, '0')}";
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(w);
    }

    List<Widget> sections = [];
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    for (var key in keys) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      final title = "${_getMonthName(month)} $year";

      sections.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 12, left: 4),
            child: Text(title.toUpperCase(), style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2)),
          )
      );
      final wishesThisMonth = grouped[key]!;

      sections.add(
          SmartMasonryGrid(
            estimatedHeights: wishesThisMonth.map((w) => WishCard.estimateHeight(w, hasCustomAction: w.reservedById == null || w.reservedById == 'self')).toList(),
            children: wishesThisMonth.map((w) {
              final canEditProfile = state.contacts.firstWhere((c) => c.id == contactId).isManaged;
              return WishCard(
                wish: w,
                theme: theme,
                surpriseMode: false,
                isMine: canEditProfile,
                onTap: canEditProfile
                    ? () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: theme.sheet,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    builder: (ctx) => WishEditorSheet(state: state, contactId: contactId, existingWish: w),
                  ).then((_) {
                    if (mounted) setState(() {});
                  });
                }
                    : () => showWishDetailSheet(context, w),
                onEdit: canEditProfile
                    ? () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: theme.sheet,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    builder: (ctx) => WishEditorSheet(state: state, contactId: contactId, existingWish: w),
                  );
                }
                    : null,
                onDelete: canEditProfile
                    ? () async {
                  final confirm = await _showDeleteConfirmation(context, theme);
                  if (confirm == true) {
                    state.deleteWish(w.id);
                    if (mounted) setState(() {});
                  }
                }
                    : null,
                customAction: w.reservedById == null
                    ? PigioButton(
                        label: "Réserver 🎁",
                        color: theme.success,
                        textColor: theme.onAccent,
                        onTap: () {
                          state.toggleReserveWish(w.id, 'self');
                          if (mounted) setState(() {});
                        },
                        fullWidth: true,
                        height: 38,
                        fontSize: 13,
                      )
                    : w.reservedById == 'self'
                        ? PigioButton(
                            label: "Annuler réservation",
                            color: theme.mid.withValues(alpha: 0.12),
                            textColor: theme.mid,
                            onTap: () {
                              state.toggleReserveWish(w.id, 'self');
                              if (mounted) setState(() {});
                            },
                            fullWidth: true,
                            height: 38,
                            fontSize: 13,
                          )
                        : null,
              );
            }).toList(),
          )
      );
    }

    return sections;
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, PigioThemeData theme) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Supprimer l'envie ?", style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
        content: Text("Cette action est irréversible. Voulez-vous vraiment supprimer cet article ?", style: fw(size: 14, w: FontWeight.w600, color: theme.mid)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Annuler", style: fw(size: 14, w: FontWeight.w800, color: theme.mid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Supprimer", style: fw(size: 14, w: FontWeight.w900, color: theme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _showProfileEditor(PigioAppState state, ContactProfile contact) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddProfileSheet(contact: contact),
    );
    setState(() {});
  }

  void _openWizzSheet(
      BuildContext context, PigioAppState state, ContactProfile contact, PigioThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WizzSheet(
        contact: contact,
      ),
    );
  }

  Future<void> _showSizeEditor(PigioAppState state, String categoryKey, String contactId, PigioThemeData theme) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizeEditorSheet(
        state: state,
        initialCategoryKey: categoryKey,
        allMeta: _getMeta(theme),
        contactId: contactId,
      ),
    );
    setState(() {});
  }

  void _openInviteSheet(BuildContext ctx, ContactProfile contact) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InviteBottomSheet(contact: contact),
    );
  }

  Future<void> _confirmResetContact(
      BuildContext ctx,
      PigioAppState state,
      ContactProfile contact,
      PigioThemeData theme,
      ) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        backgroundColor: theme.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Réinitialiser ce contact ?",
            style: fw(size: 18, w: FontWeight.w900, color: theme.ink)),
        content: Text(
          "${contact.name} sera réinitialisé·e en contact local. Les tailles et l'historique sont conservés, mais la connexion Pigio sera coupée et vous pourrez renvoyer une invitation.\n\nÀ faire uniquement si ${contact.name} a changé d'email, de compte ou supprimé son compte Pigio.",
          style: fw(size: 13, w: FontWeight.w600, color: theme.mid, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text("Annuler", style: fw(size: 14, w: FontWeight.w800, color: theme.mid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text("Réinitialiser",
                style: fw(size: 14, w: FontWeight.w900, color: theme.error)),
          ),
        ],
      ),
    );

    if (confirm == true && ctx.mounted) {
      state.resetContactForReinvite(contact.id);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            "${contact.name} réinitialisé·e. Vous pouvez maintenant renvoyer une invitation.",
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteContact(
      BuildContext ctx,
      PigioAppState state,
      ContactProfile contact,
      PigioThemeData theme,
      ) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        backgroundColor: theme.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          "Supprimer ${contact.name} ?",
          style: fw(size: 18, w: FontWeight.w900, color: theme.error),
        ),
        content: Text(
          "Toutes les envies et données associées seront supprimées. Cette action est irréversible.",
          style: fw(size: 13, w: FontWeight.w600, color: theme.mid, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text("Annuler", style: fw(size: 14, w: FontWeight.w800, color: theme.mid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text("Supprimer", style: fw(size: 14, w: FontWeight.w900, color: theme.error)),
          ),
        ],
      ),
    );

    if (confirm == true && ctx.mounted) {
      state.deleteContact(contact.id);
      Navigator.of(ctx).pop(); // return to contacts list
    }
  }

  Future<void> _confirmResendInvite(
      BuildContext ctx,
      PigioAppState state,
      ContactProfile contact,
      PigioThemeData theme,
      ) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        backgroundColor: theme.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Renvoyer l'invitation ?",
            style: fw(size: 18, w: FontWeight.w900, color: theme.ink)),
        content: Text(
          "L'ancien lien d'invitation sera invalidé. Un nouveau lien sera créé et vous pourrez le partager à nouveau avec ${contact.name}.",
          style: fw(size: 13, w: FontWeight.w600, color: theme.mid, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text("Annuler", style: fw(size: 14, w: FontWeight.w800, color: theme.mid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text("Renvoyer",
                style: fw(size: 14, w: FontWeight.w900, color: theme.primary)),
          ),
        ],
      ),
    );

    if (confirm == true && ctx.mounted) {
      // Mark all active pending invites as revoked so getInviteBlockReason
      // returns null, then open the invite sheet for a fresh send.
      state.resetContactForReinvite(contact.id);
      // Restore joined status if they were only 'invited' before reset
      // (resetContactForReinvite sets status to local, which is correct here)
      _openInviteSheet(ctx, contact);
    }
  }

  // ── Group picker ─────────────────────────────────────────────────────────

  void _showGroupPicker(BuildContext context, PigioAppState state, ContactProfile contact) {
    final theme = context.ptnl;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            final groups = state.groups;
            final hasFamilleGroup = groups.any((g) => g.isSystem && g.trustLevel == TrustLevel.family);
            return Container(
              decoration: BoxDecoration(
                color: theme.sheet,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.divider, borderRadius: BorderRadius.circular(2))),
                    ),
                    const SizedBox(height: 20),
                    Text("Ajouter ${contact.name} à un cercle", style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
                    const SizedBox(height: 6),
                    Text("Sélectionnez un cercle existant ou créez-en un nouveau.", style: fw(size: 13, w: FontWeight.w600, color: theme.mid)),
                    const SizedBox(height: 16),
                    // Scrollable group list
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Create Famille group shortcut when it doesn’t exist yet and
                            // the contact is family-tagged
                            if (!hasFamilleGroup && contact.isFamily)
                              GestureDetector(
                                onTap: () {
                                  state.addGroup(
                                    'Famille',
                                    '🏠',
                                    [contact.id],
                                    trustLevel: TrustLevel.family,
                                    isSystem: true,
                                  );
                                  setSheetState(() {});
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: theme.success.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: theme.success.withValues(alpha: 0.35)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('🏠', style: TextStyle(fontSize: 24)),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Créer le cercle Famille', style: fw(size: 15, w: FontWeight.w800, color: theme.success)),
                                            Text('Crée le groupe Famille et y ajoute ce contact', style: fw(size: 12, w: FontWeight.w600, color: theme.mid)),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.add_circle_outline, color: theme.success, size: 24),
                                    ],
                                  ),
                                ),
                              ),
                            if (groups.isEmpty && !(contact.isFamily && !hasFamilleGroup))
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: Text("Aucun cercle pour le moment", style: fw(size: 14, w: FontWeight.w600, color: theme.light))),
                              ),
                            ...groups.map((g) {
                              final freshContact = state.contacts.firstWhere((c) => c.id == contact.id, orElse: () => contact);
                              final isMember = g.contactIds.contains(contact.id);
                              final isFamilyGroup = g.isSystem && g.trustLevel == TrustLevel.family;
                              final isBlocked = isFamilyGroup && !freshContact.isFamily;
                              return GestureDetector(
                                onTap: isBlocked
                                    ? () async {
                                  final promote = await showDialog<bool>(
                                    context: ctx2,
                                    builder: (d) => AlertDialog(
                                      backgroundColor: theme.sheet,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                      title: Text("Passer en Famille ?", style: fw(size: 18, w: FontWeight.w900, color: theme.ink)),
                                      content: Text(
                                        "Pour ajouter ${freshContact.name} au cercle Famille, son niveau de confiance doit être « Famille ».\n\nVoulez-vous le modifier maintenant ?",
                                        style: fw(size: 13, w: FontWeight.w600, color: theme.mid, height: 1.45),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(d, false),
                                          child: Text("Annuler", style: fw(size: 14, w: FontWeight.w800, color: theme.mid)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(d, true),
                                          child: Text("Passer en Famille", style: fw(size: 14, w: FontWeight.w900, color: theme.success)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (promote == true) {
                                    state.updateContact(
                                      id: contact.id,
                                      name: freshContact.name,
                                      role: freshContact.role,
                                      trustLevel: TrustLevel.family,
                                    );
                                    setSheetState(() {});
                                  }
                                }
                                    : () {
                                  if (isMember) {
                                    state.removeContactFromGroup(g.id, contact.id);
                                  } else {
                                    state.addContactToGroup(g.id, contact.id);
                                  }
                                  setSheetState(() {});
                                },
                                child: Opacity(
                                  opacity: isBlocked ? 0.45 : 1.0,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isMember ? theme.accent4.withValues(alpha: 0.1) : theme.card,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isBlocked
                                            ? theme.divider
                                            : isMember
                                            ? theme.accent4.withValues(alpha: 0.4)
                                            : theme.divider,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(g.emoji, style: const TextStyle(fontSize: 24)),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(g.name, style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                                              if (isBlocked)
                                                Text(
                                                  "Réservé aux contacts Famille",
                                                  style: fw(size: 11, w: FontWeight.w700, color: theme.warning),
                                                )
                                              else
                                                Text("${g.contactIds.length} membre${g.contactIds.length != 1 ? 's' : ''}", style: fw(size: 12, w: FontWeight.w600, color: theme.mid)),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          isBlocked
                                              ? Icons.lock_outline
                                              : isMember
                                              ? Icons.check_circle
                                              : Icons.add_circle_outline,
                                          color: isBlocked
                                              ? theme.mid
                                              : isMember
                                              ? theme.accent4
                                              : theme.light,
                                          size: 24,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: PigioButton(
                        label: "Nouveau cercle",
                        icon: Icons.add,
                        color: theme.accent4,
                        textColor: theme.onAccent,
                        height: 48,
                        fontSize: 14,
                        onTap: () {
                          Navigator.pop(ctx2);
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (c) => AddGroupSheet(preSelectedContactIds: [contact.id]),
                          );
                        },
                        fullWidth: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}