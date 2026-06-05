import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';
import 'package:kindy/shared/widgets/invite_bottom_sheet.dart';
import 'package:kindy/screens/contacts/sheets/add_profile_sheet.dart';
import 'package:kindy/features/contacts/presentation/contact_profile_screen.dart';
import 'package:kindy/features/circles/presentation/circles_screen.dart';
import 'package:kindy/screens/wishes/sheets/wizz_sheet.dart';

class _ContactCardData {
  final ContactProfile contact;
  final bool bdaySoon;
  final bool incomplete;
  final bool addedWish;

  _ContactCardData(this.contact, this.bdaySoon, this.incomplete, this.addedWish);
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _search = '';

  List<_ContactCardData> _cachedData = [];
  String? _highlightContactId;
  /// null = all contacts, otherwise filter to contacts in this group id
  String? _selectedGroupId;

  @override
  void initState() {
    super.initState();
    // NOUVEAU: Vérifier silencieusement si des invitations en attente ont été acceptées
    // Cela permet au Desktop (et au Mobile) de découvrir les nouveaux contacts ayant rejoint l'app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PigioAppState>().checkPendingInvites();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<PigioAppState>();
    final focusId = state.inviteFocusContactId;
    if (focusId != null && focusId.isNotEmpty && _highlightContactId != focusId) {
      _highlightContactId = focusId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        state.clearInviteFocusContactId();
      });
    }
    _recomputeData();
  }

  void _recomputeData() {
    final state = Provider.of<PigioAppState>(context);
    final allContacts = state.contacts;
    final now = DateTime.now();

    _cachedData = allContacts.map((c) {
      final sizes = state.getVisibleSizesFor(c.id, viewerTrustLevel: c.trustLevel);
      bool bdaySoon = false;
      if (c.birthdate != null && !c.hideBirthdate) {
        try {
          final parts = c.birthdate!.split('/');
          final bday = DateTime(now.year, int.parse(parts[1]), int.parse(parts[0]));
          final diff = bday.difference(now).inDays;
          if (diff >= 0 && diff <= 30) bdaySoon = true;
        } catch (e) {
          debugPrint('[Contacts] Invalid birthdate for ${c.name}: ${c.birthdate}');
        }
      }
      return _ContactCardData(
          c,
          bdaySoon,
          sizes.length < 3,
          state.hasAddedWishThisMonth(c.id)
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final int viewIndex = state.contactsSubIndex;

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: const PigioAppBar(title: "Réseau", autoShowBackFromCanPop: false),
      floatingActionButton: viewIndex == 0
          ? Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            backgroundColor: theme.primary,
            elevation: 4,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => const InviteBottomSheet(),
              );
            },
            icon: Icon(Icons.share_outlined, color: theme.onAccent, size: 22),
            label: Text("Inviter", style: fw(size: 15, w: FontWeight.w800, color: theme.onAccent)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            backgroundColor: theme.accent4,
            elevation: 4,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => const AddProfileSheet(),
              );
            },
            icon: Icon(Icons.person_add, color: theme.onAccent, size: 22),
            label: Text("Nouveau", style: fw(size: 15, w: FontWeight.w800, color: theme.onAccent)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ],
      )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Top Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => state.setContactsSubIndex(0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: viewIndex == 0 ? theme.primary : theme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: viewIndex == 0 ? Colors.transparent : theme.divider),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_outline, size: 18, color: viewIndex == 0 ? theme.onAccent : theme.mid),
                            const SizedBox(width: 8),
                            Text("Contacts", style: fw(size: 14, w: FontWeight.w800, color: viewIndex == 0 ? theme.onAccent : theme.mid)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => state.setContactsSubIndex(1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: viewIndex == 1 ? theme.accent4 : theme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: viewIndex == 1 ? Colors.transparent : theme.divider),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.groups_outlined, size: 18, color: viewIndex == 1 ? theme.onAccent : theme.mid),
                            const SizedBox(width: 8),
                            Text("Cercles", style: fw(size: 14, w: FontWeight.w800, color: viewIndex == 1 ? theme.onAccent : theme.mid)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body Content
            Expanded(
              child: viewIndex == 0
                  ? _buildContactsView(state, theme)
                  : const CirclesScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsView(PigioAppState state, PigioThemeData theme) {
    // Apply group filter first, then search, then sort
    List<_ContactCardData> byGroup = _selectedGroupId == null
        ? _cachedData
        : () {
      final g = state.groups.where((g) => g.id == _selectedGroupId).firstOrNull;
      if (g == null) return _cachedData;
      return _cachedData.where((d) => g.contactIds.contains(d.contact.id)).toList();
    }();

    final filtered = (_search.isEmpty
        ? byGroup
        : byGroup.where((d) => d.contact.name.toLowerCase().contains(_search.toLowerCase())).toList())
      ..sort((a, b) {
        final aFocus = _highlightContactId != null && a.contact.id == _highlightContactId;
        final bFocus = _highlightContactId != null && b.contact.id == _highlightContactId;
        if (aFocus == bFocus) return 0;
        return aFocus ? -1 : 1;
      });

    final groups = state.groups;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: fw(size: 15, w: FontWeight.w600, color: theme.ink),
              decoration: InputDecoration(
                hintText: "Rechercher un contact…",
                hintStyle: fw(size: 15, w: FontWeight.w500, color: theme.light),
                border: InputBorder.none,
                icon: Icon(Icons.search, color: theme.light, size: 20),
              ),
            ),
          ),
        ),

        // Group filter chips
        if (groups.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // "Tous" chip
                _groupChip(
                  label: 'Tous',
                  emoji: '👥',
                  isSelected: _selectedGroupId == null,
                  color: theme.primary,
                  theme: theme,
                  onTap: () => setState(() => _selectedGroupId = null),
                ),
                ...groups.map((g) => _groupChip(
                  label: g.name,
                  emoji: g.emoji,
                  isSelected: _selectedGroupId == g.id,
                  color: g.isSystem ? theme.success : theme.accent4,
                  theme: theme,
                  onTap: () => setState(() =>
                  _selectedGroupId = _selectedGroupId == g.id ? null : g.id),
                )),
              ],
            ),
          ),

        // Recently viewed (only when no search/filter active)
        if (_search.isEmpty && _selectedGroupId == null)
          _buildRecentlyViewed(state, theme),

        // Contact count
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: Row(
            children: [
              Text(
                "${filtered.length} contact${filtered.length != 1 ? 's' : ''}"
                    "${_selectedGroupId != null ? ' · ${groups.where((g) => g.id == _selectedGroupId).firstOrNull?.name ?? ""}' : ''}",
                style: fw(size: 13, w: FontWeight.w700, color: theme.mid),
              ),
            ],
          ),
        ),

        // Contact list
        Expanded(
          child: filtered.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, size: 48, color: theme.light),
                const SizedBox(height: 12),
                Text(
                  _search.isNotEmpty
                      ? "Aucun résultat"
                      : _selectedGroupId != null
                      ? "Aucun contact dans ce cercle"
                      : "Aucun contact",
                  style: fw(size: 16, w: FontWeight.w800, color: theme.mid),
                ),
                const SizedBox(height: 4),
                Text(
                  _search.isNotEmpty
                      ? "Essayez un autre nom"
                      : _selectedGroupId != null
                      ? "Ajoutez des contacts à ce cercle depuis leur profil"
                      : "Ajoutez vos proches pour commencer",
                  style: fw(size: 13, w: FontWeight.w600, color: theme.light),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            itemCount: filtered.length,
            addAutomaticKeepAlives: false,
            itemBuilder: (context, index) {
              final d = filtered[index];
              return _buildContactCard(d, state, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentlyViewed(PigioAppState state, PigioThemeData theme) {
    final recentIds = state.recentProfiles;
    final recentContacts = recentIds
        .map((id) => state.contacts.where((c) => c.id == id).firstOrNull)
        .whereType<ContactProfile>()
        .toList();

    if (recentContacts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "RÉCEMMENT CONSULTÉS",
            style: fw(size: 10, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.1),
          ),
          const SizedBox(height: 8),
          Row(
            children: recentContacts.map((c) {
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    state.recordProfileView(c.id);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ContactProfileScreen(contact: c)),
                    );
                  },
                  child: Column(
                    children: [
                      PigioAvatar(
                        name: c.name,
                        size: 44,
                        avatarIcon: c.avatarIcon,
                        avatarColor: c.avatarColor,
                        ringColor: c.color,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 56,
                        child: Text(
                          c.name.split(' ').first,
                          style: fw(size: 11, w: FontWeight.w700, color: theme.mid),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Divider(color: theme.divider, height: 1),
        ],
      ),
    );
  }

  Widget _groupChip({
    required String label,
    required String emoji,
    required bool isSelected,
    required Color color,
    required PigioThemeData theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : theme.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              label,
              style: fw(
                size: 12,
                w: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : theme.mid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(_ContactCardData d, PigioAppState state, PigioThemeData theme) {
    final c = d.contact;
    final isHighlighted = _highlightContactId != null && _highlightContactId == c.id;
    final card = _ContactCard(
      data: d,
      isHighlighted: isHighlighted,
      wizzEffectMode: state.wizzEffectMode,
      onTap: () {
        if (isHighlighted) setState(() => _highlightContactId = null);
        state.recordProfileView(c.id);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContactProfileScreen(contact: c)),
        );
      },
    );

    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.error,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: theme.sheet,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              "Supprimer ${c.name} ?",
              style: fw(size: 18, w: FontWeight.w900, color: theme.ink),
            ),
            content: Text(
              "Toutes les envies et données associées seront supprimées. Cette action est irréversible.",
              style: fw(size: 13, w: FontWeight.w600, color: theme.mid, height: 1.45),
            ),
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
      },
      onDismissed: (_) {
        state.deleteContact(c.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${c.name} supprimé"),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      child: card,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shakeable, wizzable contact card
// ─────────────────────────────────────────────────────────────────────────────

class _ContactCard extends StatefulWidget {
  final _ContactCardData data;
  final bool isHighlighted;
  final WizzEffectMode wizzEffectMode;
  final VoidCallback onTap;

  const _ContactCard({
    required this.data,
    required this.isHighlighted,
    required this.wizzEffectMode,
    required this.onTap,
  });

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 0.0), weight: 2),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.linear));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ContactCard oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  void _openWizz(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WizzSheet(
        contact: widget.data.contact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final c = widget.data.contact;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) {
        final isPhase2 = widget.wizzEffectMode == WizzEffectMode.phase2;
        final x = _shakeAnim.value;
        final y = isPhase2 ? (x.abs() * 0.18) : 0.0;
        return Transform.translate(offset: Offset(x, y), child: child);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isHighlighted
                      ? theme.primary
                      : theme.divider.withValues(alpha: 0.5),
                  width: widget.isHighlighted ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  PigioAvatar(
                    name: c.name,
                    size: 50,
                    avatarIcon: c.avatarIcon,
                    avatarColor: c.avatarColor,
                    ringColor: c.color,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (c.isFamily) _chip('Famille', theme.success, theme),
                            if (!c.isFamily && c.trustLevel == TrustLevel.friend)
                              _chip('Ami', theme.primary, theme),
                            if (c.trustLevel == TrustLevel.public_)
                              _chip('Public', theme.mid, theme),
                            if (widget.data.bdaySoon)
                              _chip('Bientôt 🎂', theme.accent2, theme),
                            if (widget.data.incomplete)
                              _chip('Tailles 📏', theme.warning, theme),
                            if (!widget.data.incomplete)
                              _chip('Complet ✅', theme.success, theme),
                            if (widget.data.addedWish)
                              _chip('Envie ✨', theme.accent2, theme),
                            if (c.status == ContactStatus.invited)
                              _chip('En attente…', theme.warning, theme),
                            if (c.status == ContactStatus.pending)
                              _chip('Invite reçue', theme.accent4, theme),
                            if (c.status == ContactStatus.joined)
                              _chip('Sur Pigio ✅', theme.success, theme),
                            if (c.isManaged)
                              _chip('Profil administré', theme.mid, theme),
                            if (widget.isHighlighted)
                              _chip('Nouveau contact', theme.primary, theme),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.status == ContactStatus.joined ||
                          c.status == ContactStatus.invited)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openWizz(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: theme.accent1.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('⚡',
                                style: TextStyle(fontSize: 14)),
                          ),
                        ),
                      Icon(Icons.chevron_right, color: theme.light, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color, PigioThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: fw(size: 10, w: FontWeight.w800, color: color)),
    );
  }
}
