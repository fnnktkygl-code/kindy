import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/config/constants.dart';
import '../../../app_shell/main_shell.dart';

class OnboardingShell extends StatefulWidget {
  const OnboardingShell({super.key});

  @override
  State<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<OnboardingShell> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Collected onboarding data
  final _nameController = TextEditingController();
  String? _selectedAvatarIcon;
  Color? _selectedAvatarColor;
  final _wishController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _wishController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    // Persist name + avatar as soon as we reach the circles (invite) step,
    // so any invite generated there carries the real user identity.
    if (_currentPage == 2) {
      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        final state = context.read<PigioAppState>();
        final handle = '@${name.toLowerCase().replaceAll(' ', '_')}';
        state.updateProfile(
          name: name,
          handle: handle,
          memberSince: DateTime.now().year,
          avatarIcon: _selectedAvatarIcon,
          avatarColor: _selectedAvatarColor,
        );
      }
    }
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    final state = context.read<PigioAppState>();
    
    // Save name if provided
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      final handle = '@${name.toLowerCase().replaceAll(' ', '_')}';
      state.updateProfile(
        name: name,
        handle: handle,
        memberSince: DateTime.now().year,
        avatarIcon: _selectedAvatarIcon,
        avatarColor: _selectedAvatarColor,
      );
    }

    // Save first wish if provided
    final wish = _wishController.text.trim();
    if (wish.isNotEmpty) {
      state.addWish(title: wish);
    }

    state.completeOnboarding();
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;

    return Scaffold(
      backgroundColor: pt.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / 5,
                backgroundColor: pt.card,
                valueColor: AlwaysStoppedAnimation<Color>(pt.primary),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _StepNameScreen(
                    nameController: _nameController,
                    onNext: _nextPage,
                  ),
                  _StepAvatarScreen(
                    onNext: _nextPage,
                    onAvatarSelected: (icon, color) {
                      _selectedAvatarIcon = icon;
                      _selectedAvatarColor = color;
                    },
                  ),
                  _StepWishScreen(
                    wishController: _wishController,
                    onNext: _nextPage,
                  ),
                  _StepCirclesScreen(onNext: _nextPage),
                  _StepDoneScreen(onNext: _finishOnboarding),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Step 1: Name ---
class _StepNameScreen extends StatelessWidget {
  final TextEditingController nameController;
  final VoidCallback onNext;
  
  const _StepNameScreen({required this.nameController, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('👋', style: TextStyle(fontSize: 80), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Text(
            "Comment vous appelez-vous ?",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: pt.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: "Prénom",
              filled: true,
              fillColor: pt.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: TextStyle(color: pt.ink, fontSize: 18),
            onSubmitted: (_) => onNext(),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: pt.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continuer →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// --- Step 2: Avatar ---
class _StepAvatarScreen extends StatefulWidget {
  final VoidCallback onNext;
  final void Function(String icon, Color color) onAvatarSelected;
  const _StepAvatarScreen({required this.onNext, required this.onAvatarSelected});
  @override
  State<_StepAvatarScreen> createState() => _StepAvatarScreenState();
}

class _StepAvatarScreenState extends State<_StepAvatarScreen> {
  static const _defaultAvatars = [
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
  static final List<String> _avatars = [
    for (int i = 1; i <= 38; i++) 'assets/avatars/avatar_$i.png',
  ];

  String _selectedAvatarIcon = 'assets/defaults/default_man.png';
  Color _selectedColor = AppColors.notionWarmColors[0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onAvatarSelected(_selectedAvatarIcon, _selectedColor);
    });
  }

  double _getCorrectiveScale(String path) {
    if (path.contains('hijabie') ||
        path.contains('old_man') ||
        path.contains('elder')) {
      return 1.35;
    }
    return 1.1;
  }

  void _select(String icon, Color color) {
    setState(() {
      _selectedAvatarIcon = icon;
      _selectedColor = color;
    });
    widget.onAvatarSelected(icon, color);
  }

  Widget _avatarTile(String iconPath) {
    final pt = context.watch<PigioAppState>().currentTheme;
    final isSelected = _selectedAvatarIcon == iconPath;
    final isDefault = !iconPath.contains('avatar_');
    return GestureDetector(
      onTap: () => _select(iconPath, _selectedColor),
      child: Container(
        width: 70,
        height: 70,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? pt.primary.withValues(alpha: 0.15) : pt.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? pt.primary : pt.divider,
            width: isSelected ? 2.5 : 1.0,
          ),
        ),
        child: ClipOval(
          child: isDefault
              ? Transform.scale(
                  scale: _getCorrectiveScale(iconPath),
                  child: Image.asset(iconPath, fit: BoxFit.cover),
                )
              : Image.asset(iconPath, fit: BoxFit.cover),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Choisissez votre Avatar",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: pt.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Preview
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _selectedColor,
                shape: BoxShape.circle,
                border: Border.all(color: pt.divider, width: 2),
              ),
              child: ClipOval(
                child: Transform.scale(
                  scale: _getCorrectiveScale(_selectedAvatarIcon),
                  child: Image.asset(_selectedAvatarIcon, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Silhouettes
          Text("Silhouettes", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pt.ink)),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _defaultAvatars.length,
              itemBuilder: (_, i) => _avatarTile(_defaultAvatars[i]),
            ),
          ),
          const SizedBox(height: 20),

          // Avatars
          Text("Avatars", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pt.ink)),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _avatars.length,
              itemBuilder: (_, i) => _avatarTile(_avatars[i]),
            ),
          ),
          const SizedBox(height: 20),

          // Background colour
          Text("Fond coloré", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: pt.ink)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AppColors.notionWarmColors.map((color) {
              final isSelected = _selectedColor == color;
              return GestureDetector(
                onTap: () => _select(_selectedAvatarIcon, color),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? pt.ink : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: pt.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continuer →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: widget.onNext,
            child: Text("Passer", style: TextStyle(color: pt.ink.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }
}


// --- Step 3: First Wish ---
class _StepWishScreen extends StatelessWidget {
  final TextEditingController wishController;
  final VoidCallback onNext;

  const _StepWishScreen({required this.wishController, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('✨', style: TextStyle(fontSize: 80), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Text(
            "Qu'est-ce qui vous ferait plaisir ?",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: pt.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Ajoutez votre première envie !",
            style: TextStyle(fontSize: 15, color: pt.ink.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: wishController,
            decoration: InputDecoration(
              hintText: "Ex: AirPods Pro, un bon livre...",
              filled: true,
              fillColor: pt.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            style: TextStyle(color: pt.ink),
            onSubmitted: (_) => onNext(),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: pt.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ajouter →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: onNext,
            child: Text("Passer pour l'instant", style: TextStyle(color: pt.ink.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }
}

// --- Step 4: Invite Circle ---
class _StepCirclesScreen extends StatefulWidget {
  final VoidCallback onNext;
  const _StepCirclesScreen({required this.onNext});

  @override
  State<_StepCirclesScreen> createState() => _StepCirclesScreenState();
}

class _StepCirclesScreenState extends State<_StepCirclesScreen> {
  bool _isLoading = false;

  Future<void> _shareLink({required bool copyOnly}) async {
    final state = context.read<PigioAppState>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      // Tapping share in onboarding is explicit consent.
      state.setContactsConsentGiven(true);
      final link = await state.createContactListInviteLink(
        channel: copyOnly ? InviteChannel.copyLink : InviteChannel.whatsApp,
      );
      if (!mounted) return;
      if (link == null || link.isEmpty) throw Exception('Lien indisponible');
      if (copyOnly) {
        await Clipboard.setData(ClipboardData(text: link));
        messenger.showSnackBar(
          const SnackBar(content: Text('Lien copié dans le presse-papier !')),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(text: 'Rejoins-moi sur Pigio 🎁 $link', title: 'Invitation Pigio'),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de générer le lien d\'invitation. Réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('👥', style: TextStyle(fontSize: 80), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Text(
            "Invitez vos proches !",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: pt.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Partagez vos envies avec votre entourage",
            style: TextStyle(fontSize: 15, color: pt.ink.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _shareLink(copyOnly: false),
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.share),
            label: const Text('Partager le lien'),
            style: ElevatedButton.styleFrom(
              backgroundColor: pt.card,
              foregroundColor: pt.ink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _shareLink(copyOnly: true),
            icon: const Icon(Icons.copy),
            label: const Text('Copier le lien'),
            style: ElevatedButton.styleFrom(
              backgroundColor: pt.card,
              foregroundColor: pt.ink,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: pt.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Continuer →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: widget.onNext,
            child: Text("Passer", style: TextStyle(color: pt.ink.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }
}

// --- Step 5: Done ---
class _StepDoneScreen extends StatelessWidget {
  final VoidCallback onNext;
  const _StepDoneScreen({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final pt = context.watch<PigioAppState>().currentTheme;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: Image.asset(
              'icon/app_icon.png',
              width: 120,
              height: 120,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "Pigio est prêt !",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: pt.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "🎉",
            style: TextStyle(fontSize: 48),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: pt.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Découvrir Pigio →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
