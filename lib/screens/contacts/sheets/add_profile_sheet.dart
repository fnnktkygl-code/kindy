import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/i18n/i18n.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';
import 'package:kindy/screens/contacts/mondial_relay_screen.dart';

class AddProfileSheet extends StatefulWidget {
  final ContactProfile? contact;
  final bool isMyProfile;
  const AddProfileSheet({super.key, this.contact, this.isMyProfile = false});

  @override
  State<AddProfileSheet> createState() => _AddProfileSheetState();
}

class _AddProfileSheetState extends State<AddProfileSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _roleCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _mondialRelayCtrl = TextEditingController();
  String? _birthdate;
  TrustLevel _trustLevel = TrustLevel.friend;
  bool _submitted = false; // tracks whether save was attempted
  bool _hideBirthdate = false;
  bool _hideAddress = false;
  bool _hideMondialRelay = false;
  
  String? _selectedAvatarIcon;
  Color? _selectedAvatarColor;

  /// True when editing a joined (non-managed) contact — synced fields are read-only.
  bool get _isJoinedRemote =>
      widget.contact != null &&
      !widget.contact!.managedProfile &&
      widget.contact!.status == ContactStatus.joined;

  // Address Autocomplete State
  Timer? _debounce;
  List<dynamic> _addressSuggestions = [];
  bool _isFetchingAddress = false;
  final FocusNode _addressFocusNode = FocusNode();

  final List<String> _defaultAvatars = [
    'assets/defaults/default_man.png',
    'assets/defaults/default_woman.png',
    'assets/defaults/default_boy.png',
    'assets/defaults/default_afro.png',
    'assets/defaults/default_dreads.png',
    'assets/defaults/default_hijabie.png',
    'assets/defaults/default_old_man.png',
    'assets/defaults/default_elder_man.png',
    'assets/defaults/default_man_dreads.png',
    'assets/defaults/default_elder_woman.png',
    'assets/defaults/default_woman_dreads.png',
  ];

  final List<String> _avatars = [
    for (int i = 1; i <= 38; i++) 'assets/avatars/avatar_$i.png',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isMyProfile) {
      final state = Provider.of<PigioAppState>(context, listen: false);
      final p = state.profile;
      _nameCtrl.text = p.name;
      _roleCtrl.text = p.handle;
      _addressCtrl.text = p.address ?? "";
      _mondialRelayCtrl.text = p.mondialRelayPoint ?? "";
      _birthdate = p.birthdate;
      _hideBirthdate = p.hideBirthdate;
      _hideAddress = p.hideAddress;
      _hideMondialRelay = p.hideMondialRelay;
      _selectedAvatarIcon = p.avatarIcon ?? 'assets/defaults/default_man.png';
      _selectedAvatarColor = p.avatarColor ?? AppColors.notionWarmColors[0];
    } else if (widget.contact != null) {
      _nameCtrl.text = widget.contact!.name;
      _roleCtrl.text = widget.contact!.role;
      _addressCtrl.text = widget.contact!.address ?? "";
      _mondialRelayCtrl.text = widget.contact!.mondialRelayPoint ?? "";
      _birthdate = widget.contact!.birthdate;
      _trustLevel = widget.contact!.trustLevel;
      _hideBirthdate = widget.contact!.hideBirthdate;
      _hideAddress = widget.contact!.hideAddress;
      _hideMondialRelay = widget.contact!.hideMondialRelay;
      _selectedAvatarIcon = widget.contact!.avatarIcon;
      _selectedAvatarColor = widget.contact!.avatarColor;
    } else {
      _selectedAvatarIcon = 'assets/defaults/default_man.png';
      _selectedAvatarColor = AppColors.notionWarmColors[0];
    }
    _nameCtrl.addListener(() => setState(() {}));
    _roleCtrl.addListener(() => setState(() {}));
    _addressCtrl.addListener(_onAddressChanged);
    _addressFocusNode.addListener(() {
      if (!_addressFocusNode.hasFocus && _addressSuggestions.isNotEmpty) {
        setState(() => _addressSuggestions.clear());
      }
    });
  }

  void _onAddressChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _addressCtrl.text.trim();
      if (query.length > 3) {
        _fetchOSMSuggestions(query);
      } else {
        setState(() {
          _addressSuggestions.clear();
        });
      }
    });
  }

  Future<void> _fetchOSMSuggestions(String query) async {
    setState(() => _isFetchingAddress = true);
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=jsonv2&addressdetails=1&limit=5');
      final response = await http.get(uri, headers: {
        'User-Agent': 'PigioApp/contact@pigio.app',
      }).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        if (raw is List) {
          setState(() => _addressSuggestions = raw);
        }
      }
    } catch (e) {
      debugPrint('[AddProfile] Address autocomplete failed: $e');
    } finally {
      if (mounted) setState(() => _isFetchingAddress = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _addressCtrl.dispose();
    _mondialRelayCtrl.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  double _getCorrectiveScale(String? path) {
    if (path == null) return 1.0;
    if (path.contains('hijabie') || path.contains('old_man') || path.contains('elder')) {
      return 1.35;
    }
    return 1.1;
  }

  Future<void> _pickDate(PigioThemeData theme) async {
    DateTime initialDate = DateTime.now();
    if (_birthdate != null) {
      try {
        final parts = _birthdate!.split('/');
        initialDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } catch (e) {
        debugPrint('[AddProfile] Invalid birthdate format: $_birthdate');
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        // Enforce light color scheme for readability in date picker since
        // the default material picker might struggle with some dark theme combos
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: theme.isDark 
              ? ColorScheme.dark(
                  primary: theme.primary, 
                  onPrimary: theme.onAccent,
                  surface: theme.card,
                  onSurface: theme.ink,
                )
              : ColorScheme.light(
                  primary: theme.primary,
                  onPrimary: theme.onAccent,
                  surface: theme.card,
                  onSurface: theme.ink,
                ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.primary, // OK/Cancel buttons
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthdate = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  void _save() {
    setState(() => _submitted = true);
    if (_nameCtrl.text.trim().isEmpty) return;
    if (!widget.isMyProfile && _roleCtrl.text.trim().isEmpty) return;

    final state = Provider.of<PigioAppState>(context, listen: false);
    if (widget.isMyProfile) {
      state.updateProfile(
        name: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : "You",
        handle: _roleCtrl.text.trim().isNotEmpty ? _roleCtrl.text.trim() : "@you",
        memberSince: state.profile.memberSince,
        birthdate: _birthdate,
        address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
        mondialRelayPoint: _mondialRelayCtrl.text.trim().isNotEmpty ? _mondialRelayCtrl.text.trim() : null,
        hideBirthdate: _hideBirthdate,
        hideAddress: _hideAddress,
        hideMondialRelay: _hideMondialRelay,
        avatarIcon: _selectedAvatarIcon,
        avatarColor: _selectedAvatarColor,
      );
    } else if (widget.contact != null) {
      state.updateContact(
        id: widget.contact!.id,
        name: _nameCtrl.text.trim(),
        role: _roleCtrl.text.trim().isEmpty ? t(context, 'friend_role') : _roleCtrl.text.trim(),
        birthdate: _birthdate,
        address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
        mondialRelayPoint: _mondialRelayCtrl.text.trim().isNotEmpty ? _mondialRelayCtrl.text.trim() : null,
        hideBirthdate: _hideBirthdate,
        hideAddress: _hideAddress,
        hideMondialRelay: _hideMondialRelay,
        trustLevel: _trustLevel,
        avatarIcon: _selectedAvatarIcon,
        avatarColor: _selectedAvatarColor,
      );
    } else {
      final trimmedName = _nameCtrl.text.trim();
      final isDuplicate = state.contacts.any(
        (c) => c.name.trim().toLowerCase() == trimmedName.toLowerCase(),
      );
      if (isDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Un contact nommé "$trimmedName" existe déjà.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      state.addContact(
        name: trimmedName,
        role: _roleCtrl.text.trim().isEmpty ? t(context, 'friend_role') : _roleCtrl.text.trim(),
        trustLevel: _trustLevel,
        birthdate: _birthdate,
        address: _addressCtrl.text.trim().isNotEmpty ? _addressCtrl.text.trim() : null,
        mondialRelayPoint: _mondialRelayCtrl.text.trim().isNotEmpty ? _mondialRelayCtrl.text.trim() : null,
        hideBirthdate: _hideBirthdate,
        hideAddress: _hideAddress,
        hideMondialRelay: _hideMondialRelay,
        avatarIcon: _selectedAvatarIcon,
        avatarColor: _selectedAvatarColor,
      );
    }

    Navigator.pop(context, true);
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 12, left: 24, right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 5, decoration: BoxDecoration(color: theme.mid.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10))),
            ),
            const SizedBox(height: 24),

            Text(
              widget.isMyProfile ? "Modifier mon profil" : (widget.contact != null ? "Modifier le proche" : "Ajouter un proche"),
              style: fw(size: 24, w: FontWeight.w900, color: theme.ink),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isMyProfile
                  ? "Mettez à jour vos informations personnelles."
                  : _isJoinedRemote
                      ? "Ce contact gère son propre profil. Vous pouvez modifier le niveau de confiance."
                      : "Les profils ajoutés sont gérés par vous (ex: enfants, parents âgés).",
              style: fw(size: 14, w: FontWeight.w600, color: theme.mid),
            ),
            const SizedBox(height: 24),

            if (!_isJoinedRemote) ...[
            // Preview — show the theme-appropriate display color
            Center(
              child: Builder(
                builder: (context) {
                  // Map the stored canonical color to the theme-appropriate display variant
                  Color previewBg = theme.surface;
                  if (_selectedAvatarColor != null) {
                    final idx = AppColors.notionWarmColors.indexOf(_selectedAvatarColor!);
                    previewBg = (theme.isDark && idx >= 0)
                        ? AppColors.notionWarmColorsDark[idx]
                        : _selectedAvatarColor!;
                  }
                  return Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: previewBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.divider, width: 2),
                    ),
                    child: ClipOval(
                      child: _selectedAvatarIcon != null
                          ? Transform.scale(
                              scale: _getCorrectiveScale(_selectedAvatarIcon),
                              child: Image.asset(_selectedAvatarIcon!, width: 100, height: 100, fit: BoxFit.cover),
                            )
                          : Center(child: Text(_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : "?", style: fw(size: 40, w: FontWeight.w800, color: theme.ink))),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // Silhouettes
            Text("Silhouettes", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _defaultAvatars.length,
                itemBuilder: (context, index) {
                  final iconPath = _defaultAvatars[index];
                  final isSelected = _selectedAvatarIcon == iconPath;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatarIcon = iconPath),
                    child: Container(
                      width: 70, height: 70,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.primary.withValues(alpha: 0.15)
                            : (theme.isDark ? theme.surface.withValues(alpha: 0.6) : theme.surface),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? theme.primary : (theme.isDark ? theme.divider : Colors.transparent),
                          width: isSelected ? 2.5 : 1.0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Transform.scale(scale: _getCorrectiveScale(iconPath), child: Image.asset(iconPath, fit: BoxFit.cover)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Avatars
            Text("Avatars", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _avatars.length,
                itemBuilder: (context, index) {
                  final iconPath = _avatars[index];
                  final isSelected = _selectedAvatarIcon == iconPath;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatarIcon = iconPath),
                    child: Container(
                      width: 70, height: 70,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.primary.withValues(alpha: 0.15)
                            : (theme.isDark ? theme.surface.withValues(alpha: 0.6) : theme.surface),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? theme.primary : (theme.isDark ? theme.divider : Colors.transparent),
                          width: isSelected ? 2.5 : 1.0,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.asset(iconPath, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Fonds colorés — use themed palette
            Text("Fonds colorés", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: AppColors.notionWarmColors.length,
                itemBuilder: (context, index) {
                  // Always store the light color as the canonical value
                  final canonicalColor = AppColors.notionWarmColors[index];
                  // Display the theme-appropriate variant
                  final displayColor = theme.isDark
                      ? AppColors.notionWarmColorsDark[index]
                      : canonicalColor;
                  final isSelected = _selectedAvatarColor == canonicalColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedAvatarColor = canonicalColor),
                    child: Container(
                      width: 50, height: 50,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: displayColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? theme.primary : theme.divider,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: displayColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            ], // end if (!_isJoinedRemote) — avatar section

            _buildInput(
              controller: _nameCtrl,
              label: "Prénom / Nom",
              hint: "Ex: Léo",
              icon: Icons.person,
              hasError: !_isJoinedRemote && _submitted && _nameCtrl.text.trim().isEmpty,
              errorText: 'Le prénom ou nom est obligatoire',
              readOnly: _isJoinedRemote,
            ),
            const SizedBox(height: 16),
            if (widget.isMyProfile)
              _buildInput(
                controller: _roleCtrl,
                label: 'Pseudo',
                hint: 'Ex: @leo',
                icon: Icons.alternate_email,
                hasError: false,
              )
            else
              GestureDetector(
                onTap: () => _showRelationPicker(context, theme),
                child: AbsorbPointer(
                  child: _buildInput(
                    controller: _roleCtrl,
                    label: 'Relation',
                    hint: 'Sélectionner...',
                    icon: Icons.people,
                    hasError: !_isJoinedRemote && _submitted && _roleCtrl.text.trim().isEmpty,
                    errorText: 'La relation est obligatoire',
                  ),
                ),
              ),
            const SizedBox(height: 24),

            if (!widget.isMyProfile) ...[
              // TRUST LEVEL SELECTOR
              Text("Niveau de confiance".toUpperCase(), style: fw(size: 12, w: FontWeight.w800, color: theme.mid, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTrustChip("🏠 Famille", TrustLevel.family, theme.success, theme),
                  const SizedBox(width: 8),
                  _buildTrustChip("🤝 Ami", TrustLevel.friend, theme.primary, theme),
                  const SizedBox(width: 8),
                  _buildTrustChip("🌍 Public", TrustLevel.public_, theme.mid, theme),
                ],
              ),
              const SizedBox(height: 24),
            ],

            if (!_isJoinedRemote) ...[
            // Birthday Picker
            Text("Date de naissance", style: fw(size: 14, w: FontWeight.w800, color: theme.ink)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickDate(theme),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.mid.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cake_outlined, color: theme.mid, size: 20),
                          const SizedBox(width: 12),
                          Text(_birthdate ?? "JJ/MM/AAAA", style: fw(size: 16, w: FontWeight.w600, color: _birthdate != null ? theme.ink : theme.light)),
                          const Spacer(),
                          Icon(Icons.calendar_today_outlined, size: 16, color: theme.primary.withValues(alpha: 0.6)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_birthdate != null) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => setState(() => _hideBirthdate = !_hideBirthdate),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _hideBirthdate ? theme.surfaceAlt : theme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _hideBirthdate ? theme.primary : theme.mid.withValues(alpha: 0.1)),
                      ),
                      child: Icon(_hideBirthdate ? Icons.visibility_off : Icons.visibility, color: _hideBirthdate ? theme.primary : theme.mid, size: 20),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Adresses & Livraison
            Row(
              children: [
                Text("Adresses & Livraison", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _hideAddress = !_hideAddress),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _hideAddress ? theme.surfaceAlt : theme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _hideAddress ? theme.primary : theme.mid.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(_hideAddress ? Icons.visibility_off : Icons.visibility, size: 14, color: _hideAddress ? theme.primary : theme.mid),
                        const SizedBox(width: 6),
                        Text(_hideAddress ? "Cachée" : "Visible", style: fw(size: 12, w: FontWeight.w700, color: _hideAddress ? theme.primary : theme.mid)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInput(controller: _addressCtrl, focusNode: _addressFocusNode, label: "Adresse postale", hint: "Pour les colis surprises", icon: Icons.home_outlined),
            if (_isFetchingAddress)
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 16),
                child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_addressSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.mid.withValues(alpha: 0.1)),
                ),
                child: Column(
                  children: _addressSuggestions.map((s) {
                    final display = s['display_name'] as String;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _addressCtrl.text = display;
                          _addressSuggestions.clear();
                        });
                        FocusScope.of(context).unfocus();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.mid.withValues(alpha: 0.05)))),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 16, color: theme.primary),
                            const SizedBox(width: 12),
                            Expanded(child: Text(display, style: fw(size: 13, w: FontWeight.w600, color: theme.ink), maxLines: 2, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Text("Point Mondial Relay", style: fw(size: 15, w: FontWeight.w800, color: theme.ink)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _hideMondialRelay = !_hideMondialRelay),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _hideMondialRelay ? theme.surfaceAlt : theme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _hideMondialRelay ? theme.primary : theme.mid.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(_hideMondialRelay ? Icons.visibility_off : Icons.visibility, size: 14, color: _hideMondialRelay ? theme.primary : theme.mid),
                        const SizedBox(width: 6),
                        Text(_hideMondialRelay ? "Caché" : "Visible", style: fw(size: 12, w: FontWeight.w700, color: _hideMondialRelay ? theme.primary : theme.mid)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_mondialRelayCtrl.text.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: theme.surface, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(child: Text(_mondialRelayCtrl.text, style: fw(size: 14, w: FontWeight.w600, color: theme.ink))),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: theme.mid),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _mondialRelayCtrl.clear()),
                    )
                  ],
                ),
              )
            ] else ...[
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const MondialRelayScreen()));
                  if (result != null && result is Map<String, dynamic>) {
                    setState(() {
                      _mondialRelayCtrl.text = "${result['Nom']} (${result['ID']})";
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3004F).withValues(alpha: theme.isDark ? 0.25 : 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE3004F).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, color: theme.isDark ? const Color(0xFFFF6B8A) : const Color(0xFFE3004F), size: 18),
                      const SizedBox(width: 8),
                      Text("Choisir un point relais", style: fw(size: 14, w: FontWeight.w800, color: theme.isDark ? const Color(0xFFFF6B8A) : const Color(0xFFE3004F))),
                    ],
                  ),
                ),
              )
            ],
            ], // end if (!_isJoinedRemote)
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: PigioButton(
                label: widget.contact != null ? 'Enregistrer les modifications' : 'Ajouter le profil',
                color: (_submitted && (_nameCtrl.text.trim().isEmpty || (!widget.isMyProfile && _roleCtrl.text.trim().isEmpty)))
                    ? theme.error
                    : theme.primary,
                textColor: theme.onAccent,
                onTap: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRelationPicker(BuildContext context, PigioThemeData theme) {
    final Map<String, List<String>> categories = {
      "Famille proche": ["Mère", "Père", "Fille", "Fils", "Sœur", "Frère", "Conjointe / Femme", "Conjoint / Mari"],
      "Famille élargie": ["Grand-mère", "Grand-père", "Petite-fille", "Petit-fils", "Tante", "Oncle", "Nièce", "Neveu", "Cousine", "Cousin", "Belle-mère", "Beau-père", "Belle-sœur", "Beau-frère"],
      "Autres": ["Ami(e)", "Collègue", "Voisin(e)", "Connaissance", "Parrain", "Marraine", "Filleul(e)", "Autre"]
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: theme.sheet,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 5, decoration: BoxDecoration(color: theme.mid.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 16),
              Text("Sélectionner la relation", style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: categories.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(entry.key.toUpperCase(), style: fw(size: 13, w: FontWeight.w800, color: theme.primary, letterSpacing: 1.2)),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.divider),
                          ),
                          child: Column(
                            children: entry.value.asMap().entries.map((item) {
                              final isLast = item.key == entry.value.length - 1;
                              return Column(
                                children: [
                                  ListTile(
                                    title: Text(item.value, style: fw(size: 16, w: FontWeight.w600, color: theme.ink)),
                                    trailing: _roleCtrl.text == item.value ? Icon(Icons.check_circle, color: theme.primary) : null,
                                    onTap: () {
                                      setState(() => _roleCtrl.text = item.value);
                                      Navigator.pop(context);
                                    },
                                  ),
                                  if (!isLast) Divider(color: theme.divider, height: 1),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    bool hasError = false,
    String errorText = 'Ce champ est obligatoire',
    bool readOnly = false,
  }) {
    final theme = context.pt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: fw(size: 14, w: FontWeight.w800, color: hasError ? theme.error : (readOnly ? theme.mid : theme.ink))),
            if (hasError) ...
              [
                const SizedBox(width: 6),
                Icon(Icons.error_outline, color: theme.error, size: 14),
              ],
            if (readOnly) ...[
              const SizedBox(width: 6),
              Icon(Icons.lock_outline, color: theme.light, size: 14),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: readOnly ? 0.55 : 1.0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: hasError ? theme.error.withValues(alpha: 0.05) : theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasError ? theme.error.withValues(alpha: 0.6) : theme.mid.withValues(alpha: 0.1),
                width: hasError ? 1.5 : 1,
              ),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              style: fw(size: 16, w: FontWeight.w600, color: readOnly ? theme.mid : theme.ink),
              decoration: InputDecoration(
                icon: Icon(icon, color: hasError ? theme.error : theme.mid, size: 20),
                hintText: hint,
                hintStyle: fw(size: 16, w: FontWeight.w500, color: theme.light),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        if (hasError) ...
          [
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                errorText,
                style: fw(size: 12, w: FontWeight.w700, color: theme.error),
              ),
            ),
          ],
      ],
    );
  }

  Widget _buildTrustChip(String label, TrustLevel level, Color activeColor, PigioThemeData theme) {
    final isActive = _trustLevel == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _trustLevel = level),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor.withValues(alpha: 0.15) : theme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isActive ? activeColor.withValues(alpha: 0.5) : Colors.transparent, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(label, style: fw(size: 13, w: FontWeight.w800, color: isActive ? activeColor : theme.mid)),
        ),
      ),
    );
  }
}
