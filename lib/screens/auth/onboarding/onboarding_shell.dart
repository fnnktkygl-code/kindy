import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pigio_app/core/state/app_state.dart';
import 'package:pigio_app/core/config/constants.dart';
import 'package:pigio_app/screens/auth/auth_screen.dart';
import '../../../app_shell/main_shell.dart';

class OnboardingShell extends StatefulWidget {
  const OnboardingShell({super.key});

  @override
  State<OnboardingShell> createState() => _OnboardingShellState();
}

class _OnboardingShellState extends State<OnboardingShell> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Total steps: Name → Avatar → Wish (with celebration) = 3
  static const _totalSteps = 3;

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
    HapticFeedback.lightImpact();
    if (_currentPage < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishOnboarding() {
    HapticFeedback.mediumImpact();
    final state = context.read<PigioAppState>();
    
    // Save name (required so always non-empty)
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

  void _openSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen(mode: AuthScreenMode.signIn)),
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
            // Top actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  // Back button (visible on step 2+)
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: _previousPage,
                      icon: Icon(Icons.arrow_back_ios, size: 20, color: pt.ink),
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  // Only show "Se connecter" if user is NOT authenticated
                  if (Supabase.instance.client.auth.currentUser == null)
                    TextButton.icon(
                      onPressed: _openSignIn,
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Se connecter'),
                      style: TextButton.styleFrom(
                        foregroundColor: pt.primary,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / _totalSteps,
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
                    onFinish: _finishOnboarding,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Step 1: Name (required) ---
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
            onSubmitted: (_) {
              if (nameController.text.trim().isNotEmpty) onNext();
            },
          ),
          const Spacer(),
          // Button disabled until name is entered
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: nameController,
            builder: (_, value, child) {
              final hasName = value.text.trim().isNotEmpty;
              return ElevatedButton(
                onPressed: hasName ? onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: pt.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: pt.primary.withValues(alpha: 0.3),
                  disabledForegroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Continuer →', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              );
            },
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


// --- Step 3: Wish + Finish (replaces old Wish + Circles + Done) ---
class _StepWishScreen extends StatelessWidget {
  final TextEditingController wishController;
  final VoidCallback onFinish;

  const _StepWishScreen({required this.wishController, required this.onFinish});

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
            onSubmitted: (_) => onFinish(),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: pt.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Découvrir Pigio 🎉', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: onFinish,
            child: Text("Passer pour l'instant", style: TextStyle(color: pt.ink.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }
}
