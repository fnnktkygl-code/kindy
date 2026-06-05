import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/i18n/i18n.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';
import 'package:kindy/shared/widgets/wish_card.dart';
import 'package:kindy/screens/contacts/sheets/add_profile_sheet.dart';
import 'package:kindy/screens/wishes/sheets/wish_editor_sheet.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = Provider.of<PigioAppState>(context);
    final profile = state.profile;
    final sizes = state.getSizesFor(null);

    return Scaffold(
      backgroundColor: theme.scaffold,
      appBar: PigioAppBar(
        title: "Mon Profil",
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        PigioAvatar(
                          name: profile.name,
                          size: 90,
                          avatarIcon: profile.avatarIcon,
                          avatarColor: profile.avatarColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(profile.name, style: fw(size: 26, w: FontWeight.w900, color: theme.ink)),
                    Text('${profile.handle} · ${t(context, 'member_since')} ${profile.memberSince}', style: fw(size: 14, w: FontWeight.w600, color: theme.mid)),
                    if (profile.birthdate != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.accent2.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("🎂", style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(profile.birthdate!, style: fw(size: 13, w: FontWeight.w800, color: theme.accent2)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    PigioButton(
                      label: "Modifier les infos",
                      icon: Icons.edit_outlined,
                      color: theme.surface,
                      textColor: theme.ink,
                      height: 44,
                      fontSize: 14,
                      onTap: () => _showMyProfileEditor(context, state),
                      fullWidth: false,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(t(context, 'sizes_title'), style: fw(size: 22, w: FontWeight.w900, color: theme.ink)),
                        Text(
                          t(context, 'tap_to_edit'),
                          style: fw(size: 12, w: FontWeight.w600, color: theme.mid),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildSizeHighlightCard(context, state, sizes, 'clothes', '👕', theme.primary)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSizeHighlightCard(context, state, sizes, 'bottoms', '👖', theme.success)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSizeHighlightCard(context, state, sizes, 'shoes', '👟', theme.accent3)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("LIVRAISON", style: fw(size: 12, w: FontWeight.w800, color: theme.mid, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    _buildAddressCard(
                      icon: "🏠",
                      title: "Adresse postale",
                      value: profile.address,
                      isHidden: profile.hideAddress,
                      hiddenLabel: "Cachée",
                      onTap: () => _showMyProfileEditor(context, state),
                    ),
                    const SizedBox(height: 12),
                    _buildAddressCard(
                      icon: "📦",
                      title: "Point Relais Favori",
                      value: profile.mondialRelayPoint,
                      isHidden: profile.hideMondialRelay,
                      hiddenLabel: "Caché",
                      onTap: () => _showMyProfileEditor(context, state),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Historique", style: fw(size: 22, w: FontWeight.w900, color: theme.ink)),
                            const SizedBox(height: 2),
                            Text("Les 12 derniers mois", style: fw(size: 13, w: FontWeight.w600, color: theme.mid)),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (ctx) => WishEditorSheet(contactId: null, state: state),
                            );
                          },
                          child: PigioBadge(
                            label: "+ Ajouter",
                            color: theme.primary,
                            bg: theme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._buildMyWishesHistory(context, state, theme),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard({required String icon, required String title, String? value, bool isHidden = false, String hiddenLabel = "Caché", required VoidCallback onTap}) {
    final theme = context.pt;
    bool isEmpty = value == null || value.isEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.mid.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: fw(size: 14, w: FontWeight.w800, color: theme.ink)),
                      if (isHidden) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: theme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(hiddenLabel, style: fw(size: 10, w: FontWeight.w700, color: theme.primary)),
                        ),
                      ]
                    ],
                  ),
                  if (isHidden && !isEmpty)
                    Text("Masqué du public", style: fw(size: 13, w: FontWeight.w600, color: theme.mid))
                  else if (!isEmpty)
                    Text(value, style: fw(size: 13, w: FontWeight.w600, color: theme.mid), maxLines: 1, overflow: TextOverflow.ellipsis)
                  else
                    Text("Non renseigné", style: fw(size: 12, w: FontWeight.w600, color: theme.light)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.light),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeHighlightCard(BuildContext context, PigioAppState state, List<SizeProfile> profiles, String key, String emoji, Color color) {
    final theme = context.pt;
    final profile = profiles.where((s) => s.categoryKey == key).firstOrNull;

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
      onTap: () {
        state.setTabIndex(2);
        Navigator.pop(context);
      },
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
                Text(
                  t(context, key),
                  style: fw(size: 11, w: FontWeight.w700, color: theme.mid),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10, right: 10,
            child: Icon(Icons.add_circle_outline, size: 16, color: color.withValues(alpha: 0.5)),
          )
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const m = ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"];
    return m[month - 1];
  }

  List<Widget> _buildMyWishesHistory(BuildContext context, PigioAppState state, PigioThemeData theme) {
    final wishes = state.getWishesFor(null);
    if (wishes.isEmpty) {
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40),
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
      grouped.putIfAbsent(key, () => []).add(w);
    }

    List<Widget> sections = [];
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    for (var key in keys) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final isCurrentMonth = DateTime.now().year == year && DateTime.now().month == month;
      final title = isCurrentMonth ? "Ce mois-ci" : "${_getMonthName(month)} $year";

      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 12, left: 4),
          child: Text(title.toUpperCase(), style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2)),
        )
      );

      final wishesThisMonth = grouped[key]!;

      sections.add(
        SmartMasonryGrid(
          estimatedHeights: wishesThisMonth.map((w) => WishCard.estimateHeight(w, hasCustomAction: false)).toList(),
          children: wishesThisMonth.map((w) {
            return WishCard(
              wish: w,
              theme: theme,
              surpriseMode: false,
              isMine: w.contactId == null,
              onTap: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: theme.sheet,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  builder: (ctx) => WishEditorSheet(state: state, existingWish: w),
                );
              },
              onEdit: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: theme.sheet,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  builder: (ctx) => WishEditorSheet(state: state, existingWish: w),
                );
              },
              onDelete: () async {
                final confirm = await _showDeleteConfirmation(context, theme);
                if (confirm == true) {
                  state.deleteWish(w.id);
                  setState(() {});
                }
              },
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

  void _showMyProfileEditor(BuildContext context, PigioAppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AddProfileSheet(isMyProfile: true),
    );
  }
}
