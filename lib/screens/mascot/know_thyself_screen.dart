import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/shared/widgets/pigio_painter.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';

// ─── QUIZ DATA MODEL ─────────────────────────────────────────────────────────

class QuizOption {
  final String key;
  final String emoji;
  final String labelFr;
  final String labelEn;
  const QuizOption({
    required this.key,
    required this.emoji,
    required this.labelFr,
    required this.labelEn,
  });
}

class QuizQuestion {
  final String id;
  final String questionFr;
  final String questionEn;
  final String subtitleFr;
  final String subtitleEn;
  final List<QuizOption> options;
  final bool multiSelect;
  final int? maxSelections;
  final PigMood pigioMood;
  const QuizQuestion({
    required this.id,
    required this.questionFr,
    required this.questionEn,
    this.subtitleFr = '',
    this.subtitleEn = '',
    required this.options,
    this.multiSelect = true,
    this.maxSelections,
    this.pigioMood = PigMood.searching,
  });
}

const List<QuizQuestion> kQuizQuestions = [
  QuizQuestion(
    id: 'style',
    questionFr: 'Mon style, c\'est plutôt...',
    questionEn: 'My style is more like...',
    subtitleFr: 'Choisis autant que tu veux !',
    subtitleEn: 'Pick as many as you like!',
    pigioMood: PigMood.searching,
    options: [
      QuizOption(key: 'casual', emoji: '👕', labelFr: 'Casual', labelEn: 'Casual'),
      QuizOption(key: 'elegant', emoji: '✨', labelFr: 'Élégant', labelEn: 'Elegant'),
      QuizOption(key: 'sporty', emoji: '🏃', labelFr: 'Sport', labelEn: 'Sporty'),
      QuizOption(key: 'boheme', emoji: '🌸', labelFr: 'Bohème', labelEn: 'Boho'),
      QuizOption(key: 'creative', emoji: '🎨', labelFr: 'Créatif', labelEn: 'Creative'),
      QuizOption(key: 'vintage', emoji: '🕰️', labelFr: 'Vintage', labelEn: 'Vintage'),
      QuizOption(key: 'streetwear', emoji: '🧢', labelFr: 'Streetwear', labelEn: 'Streetwear'),
      QuizOption(key: 'minimalist', emoji: '🤍', labelFr: 'Minimaliste', labelEn: 'Minimalist'),
    ],
  ),
  QuizQuestion(
    id: 'passions',
    questionFr: 'Mes vraies passions...',
    questionEn: 'My real passions...',
    subtitleFr: 'Qu\'est-ce qui te fait vibrer ?',
    subtitleEn: 'What makes you tick?',
    pigioMood: PigMood.excited,
    options: [
      QuizOption(key: 'reading', emoji: '📚', labelFr: 'Lecture', labelEn: 'Reading'),
      QuizOption(key: 'gaming', emoji: '🎮', labelFr: 'Gaming', labelEn: 'Gaming'),
      QuizOption(key: 'cooking', emoji: '🍳', labelFr: 'Cuisine', labelEn: 'Cooking'),
      QuizOption(key: 'music', emoji: '🎵', labelFr: 'Musique', labelEn: 'Music'),
      QuizOption(key: 'fitness', emoji: '🏋️', labelFr: 'Sport & Fitness', labelEn: 'Sport & Fitness'),
      QuizOption(key: 'art', emoji: '🎨', labelFr: 'Art & Création', labelEn: 'Art & Creation'),
      QuizOption(key: 'travel', emoji: '✈️', labelFr: 'Voyages', labelEn: 'Travel'),
      QuizOption(key: 'movies', emoji: '🎬', labelFr: 'Cinéma & Séries', labelEn: 'Movies & TV'),
      QuizOption(key: 'nature', emoji: '🌿', labelFr: 'Nature & Outdoor', labelEn: 'Nature & Outdoor'),
      QuizOption(key: 'tech', emoji: '💻', labelFr: 'Tech & Gadgets', labelEn: 'Tech & Gadgets'),
      QuizOption(key: 'photo', emoji: '📷', labelFr: 'Photo & Vidéo', labelEn: 'Photo & Video'),
      QuizOption(key: 'plants', emoji: '🌱', labelFr: 'Jardinage', labelEn: 'Gardening'),
    ],
  ),
  QuizQuestion(
    id: 'gift_style',
    questionFr: 'Le cadeau parfait pour moi...',
    questionEn: 'The perfect gift for me...',
    subtitleFr: 'Ce qui me ferait vraiment plaisir',
    subtitleEn: 'What would truly delight me',
    pigioMood: PigMood.thumbsUp,
    options: [
      QuizOption(key: 'surprise', emoji: '🎁', labelFr: 'Une surprise totale', labelEn: 'A total surprise'),
      QuizOption(key: 'wishlist', emoji: '✅', labelFr: 'Ce que j\'ai demandé', labelEn: 'Something I asked for'),
      QuizOption(key: 'experience', emoji: '✨', labelFr: 'Une expérience', labelEn: 'An experience'),
      QuizOption(key: 'handmade', emoji: '💝', labelFr: 'Fait main avec amour', labelEn: 'Handmade with love'),
      QuizOption(key: 'product', emoji: '🛍️', labelFr: 'Un produit que j\'adore', labelEn: 'A product I love'),
      QuizOption(key: 'subscription', emoji: '📦', labelFr: 'Un abonnement', labelEn: 'A subscription'),
    ],
  ),
  QuizQuestion(
    id: 'treats',
    questionFr: 'Mes petits plaisirs...',
    questionEn: 'My little pleasures...',
    subtitleFr: 'Ce qui me fait sourire au quotidien',
    subtitleEn: 'What makes me smile daily',
    pigioMood: PigMood.thinking,
    options: [
      QuizOption(key: 'coffee', emoji: '☕', labelFr: 'Café & thé', labelEn: 'Coffee & tea'),
      QuizOption(key: 'chocolate', emoji: '🍫', labelFr: 'Chocolat & douceurs', labelEn: 'Chocolate & sweets'),
      QuizOption(key: 'fragrance', emoji: '🌸', labelFr: 'Parfums & cosméto', labelEn: 'Fragrances & cosmetics'),
      QuizOption(key: 'candles', emoji: '🕯️', labelFr: 'Bougies & ambiance', labelEn: 'Candles & vibes'),
      QuizOption(key: 'books', emoji: '📖', labelFr: 'Livres & magazines', labelEn: 'Books & magazines'),
      QuizOption(key: 'home_plants', emoji: '🌱', labelFr: 'Plantes & déco verte', labelEn: 'Plants & green deco'),
      QuizOption(key: 'gadgets', emoji: '🔌', labelFr: 'High-tech & accessoires', labelEn: 'Tech & accessories'),
      QuizOption(key: 'beauty', emoji: '💅', labelFr: 'Beauté & soin', labelEn: 'Beauty & self-care'),
      QuizOption(key: 'audio', emoji: '🎧', labelFr: 'Musique & audio', labelEn: 'Music & audio'),
      QuizOption(key: 'home_decor', emoji: '🏡', labelFr: 'Maison & déco', labelEn: 'Home & decor'),
    ],
  ),
  QuizQuestion(
    id: 'personality',
    questionFr: 'Je me reconnais dans...',
    questionEn: 'I identify with...',
    subtitleFr: 'Choisis jusqu\'à 3 traits qui te ressemblent',
    subtitleEn: 'Pick up to 3 traits that describe you',
    pigioMood: PigMood.excited,
    maxSelections: 3,
    options: [
      QuizOption(key: 'optimist', emoji: '🌟', labelFr: 'Optimiste', labelEn: 'Optimistic'),
      QuizOption(key: 'curious', emoji: '🔍', labelFr: 'Curieux·se', labelEn: 'Curious'),
      QuizOption(key: 'creative_p', emoji: '🎭', labelFr: 'Créatif·ve', labelEn: 'Creative'),
      QuizOption(key: 'adventurer', emoji: '🌊', labelFr: 'Aventurier·e', labelEn: 'Adventurous'),
      QuizOption(key: 'social', emoji: '🤝', labelFr: 'Social·e & bienveillant·e', labelEn: 'Social & caring'),
      QuizOption(key: 'homebody', emoji: '🏠', labelFr: 'Homebody & cosy', labelEn: 'Homebody & cosy'),
      QuizOption(key: 'ambitious', emoji: '🎯', labelFr: 'Organisé·e & ambitieux·se', labelEn: 'Organized & ambitious'),
      QuizOption(key: 'free_spirit', emoji: '🦋', labelFr: 'Libre & indépendant·e', labelEn: 'Free-spirited'),
    ],
  ),
  QuizQuestion(
    id: 'budget',
    questionFr: 'Côté budget cadeaux...',
    questionEn: 'When it comes to gift budgets...',
    subtitleFr: 'Ce que j\'apprécie vraiment',
    subtitleEn: 'What I truly appreciate',
    pigioMood: PigMood.thumbsUp,
    multiSelect: false,
    options: [
      QuizOption(key: 'symbolic', emoji: '❤️', labelFr: 'L\'intention compte tout', labelEn: 'The thought counts'),
      QuizOption(key: 'budget_low', emoji: '🎁', labelFr: 'Entre 20 et 50€', labelEn: '20 to 50€'),
      QuizOption(key: 'budget_mid', emoji: '✨', labelFr: 'Entre 50 et 150€', labelEn: '50 to 150€'),
      QuizOption(key: 'budget_high', emoji: '💎', labelFr: 'Pas de limite si c\'est parfait', labelEn: 'No limit if it\'s perfect'),
    ],
  ),
  QuizQuestion(
    id: 'experience',
    questionFr: 'Je préfère...',
    questionEn: 'I prefer...',
    subtitleFr: 'Mon mode de vie idéal',
    subtitleEn: 'My ideal lifestyle',
    pigioMood: PigMood.searching,
    multiSelect: false,
    options: [
      QuizOption(key: 'explore', emoji: '🌍', labelFr: 'Voyager & explorer', labelEn: 'Travel & explore'),
      QuizOption(key: 'cozy', emoji: '🏡', labelFr: 'Cocooner chez moi', labelEn: 'Stay cosy at home'),
      QuizOption(key: 'social_out', emoji: '🎉', labelFr: 'Sortir & voir du monde', labelEn: 'Go out & socialise'),
      QuizOption(key: 'learn', emoji: '🎓', labelFr: 'Apprendre & progresser', labelEn: 'Learn & grow'),
      QuizOption(key: 'outdoor', emoji: '🌳', labelFr: 'Profiter de la nature', labelEn: 'Enjoy nature'),
    ],
  ),
  QuizQuestion(
    id: 'wishlist_type',
    questionFr: 'Sur ma wishlist on trouverait...',
    questionEn: 'On my wishlist you\'d find...',
    subtitleFr: 'Les catégories qui me font rêver',
    subtitleEn: 'Categories that make me dream',
    pigioMood: PigMood.celebrating,
    options: [
      QuizOption(key: 'fashion', emoji: '👗', labelFr: 'Mode & accessoires', labelEn: 'Fashion & accessories'),
      QuizOption(key: 'tech_w', emoji: '📱', labelFr: 'Gadgets & tech', labelEn: 'Gadgets & tech'),
      QuizOption(key: 'art_deco', emoji: '🎨', labelFr: 'Art & déco', labelEn: 'Art & decor'),
      QuizOption(key: 'culture', emoji: '📚', labelFr: 'Livres & culture', labelEn: 'Books & culture'),
      QuizOption(key: 'wellness', emoji: '💆', labelFr: 'Bien-être & spa', labelEn: 'Wellness & spa'),
      QuizOption(key: 'food_wine', emoji: '🍷', labelFr: 'Gastronomie', labelEn: 'Gastronomy'),
      QuizOption(key: 'luggage', emoji: '🧳', labelFr: 'Voyage & aventure', labelEn: 'Travel & adventure'),
      QuizOption(key: 'games', emoji: '🎮', labelFr: 'Jeux & loisirs', labelEn: 'Games & leisure'),
    ],
  ),
];

// ─── MAIN SCREEN ─────────────────────────────────────────────────────────────

class KnowThyselfScreen extends StatefulWidget {
  const KnowThyselfScreen({super.key});

  @override
  State<KnowThyselfScreen> createState() => _KnowThyselfScreenState();
}

class _KnowThyselfScreenState extends State<KnowThyselfScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _completed = false;

  // Per-question selected option keys
  final Map<String, Set<String>> _answers = {};

  late AnimationController _slideCtrl;
  late AnimationController _pigioCtrl;
  late Animation<double> _slideAnim;
  late Animation<double> _pigioScale;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _pigioCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);

    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic);
    _pigioScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pigioCtrl, curve: Curves.easeInOut),
    );

    _slideCtrl.forward();

    // Pre-fill from existing personality profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existing = context.read<PigioAppState>().personalityProfile;
      if (existing.isNotEmpty) {
        setState(() {
          existing.forEach((qId, answers) {
            _answers[qId] = Set<String>.from(answers);
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _pigioCtrl.dispose();
    super.dispose();
  }

  QuizQuestion get _current => kQuizQuestions[_currentIndex];

  Set<String> get _currentSelections => _answers[_current.id] ?? {};

  void _toggle(String key) {
    setState(() {
      final set = _answers.putIfAbsent(_current.id, () => {});
      if (!_current.multiSelect) {
        set
          ..clear()
          ..add(key);
      } else {
        final max = _current.maxSelections;
        if (set.contains(key)) {
          set.remove(key);
        } else {
          if (max != null && set.length >= max) return;
          set.add(key);
        }
      }
    });
  }

  void _next() async {
    // Capture state reference before any await (avoid BuildContext async gap)
    final state = context.read<PigioAppState>();
    await _slideCtrl.reverse();
    if (_currentIndex < kQuizQuestions.length - 1) {
      setState(() => _currentIndex++);
      _slideCtrl.forward();
    } else {
      setState(() => _completed = true);
      _slideCtrl.forward();
      // Save to state
      final result = _answers.map((k, v) => MapEntry(k, v.toList()));
      state.savePersonalityProfile(result);
      state.setMascotMoment(MascotMoment.quizCompleted);
    }
  }

  void _prev() async {
    if (_currentIndex == 0) return;
    await _slideCtrl.reverse();
    setState(() => _currentIndex--);
    _slideCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final lang = context.read<PigioAppState>().locale.languageCode;
    final isFr = lang == 'fr';

    return Scaffold(
      backgroundColor: theme.scaffold,
      body: SafeArea(
        child: _completed ? _buildCompletion(theme, isFr) : _buildQuiz(theme, isFr),
      ),
    );
  }

  // ── QUIZ VIEW ──────────────────────────────────────────────────────────────
  Widget _buildQuiz(PigioThemeData theme, bool isFr) {
    final q = _current;
    final selected = _currentSelections;
    final progress = (_currentIndex + 1) / kQuizQuestions.length;

    return Column(
      children: [
        // ── TOP BAR ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              if (_currentIndex > 0)
                IconButton(
                  onPressed: _prev,
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: theme.ink),
                )
              else
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, size: 20, color: theme.ink),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: theme.ink.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(theme.primary),
                    ),
                  ),
                ),
              ),
              Text(
                '${_currentIndex + 1}/${kQuizQuestions.length}',
                style: fw(size: 12, w: FontWeight.w600, color: theme.ink.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ),

        // ── PIGIO + SPEECH BUBBLE ──
        const SizedBox(height: 16),
        _buildMascotSection(theme, isFr, q),
        const SizedBox(height: 20),

        // ── OPTIONS ──
        Expanded(
          child: FadeTransition(
            opacity: _slideAnim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
                  .animate(_slideAnim),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildOptions(theme, isFr, q, selected),
              ),
            ),
          ),
        ),

        // ── BOTTOM BUTTON ──
        _buildBottomBar(theme, isFr, selected),
      ],
    );
  }

  Widget _buildMascotSection(PigioThemeData theme, bool isFr, QuizQuestion q) {
    final state = context.watch<PigioAppState>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: ScaleTransition(
            scale: _pigioScale,
            child: PigioWidget(
              mood: q.pigioMood,
              size: 80,
              scarfColor: state.mascotScarfColor,
              outfit: state.activeOutfit,
              outfitColors: state.outfitColors,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FadeTransition(
            opacity: _slideAnim,
            child: Container(
              margin: const EdgeInsets.only(right: 16, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(color: theme.ink.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFr ? q.questionFr : q.questionEn,
                    style: fw(size: 15, w: FontWeight.w700, color: theme.ink),
                  ),
                  if ((isFr ? q.subtitleFr : q.subtitleEn).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      isFr ? q.subtitleFr : q.subtitleEn,
                      style: fw(size: 12, w: FontWeight.w400, color: theme.ink.withValues(alpha: 0.55)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptions(PigioThemeData theme, bool isFr, QuizQuestion q, Set<String> selected) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: q.options.map((opt) {
        final isSelected = selected.contains(opt.key);
        return _OptionChip(
          emoji: opt.emoji,
          label: isFr ? opt.labelFr : opt.labelEn,
          isSelected: isSelected,
          theme: theme,
          onTap: () => _toggle(opt.key),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar(PigioThemeData theme, bool isFr, Set<String> selected) {
    final isLast = _currentIndex == kQuizQuestions.length - 1;
    final canProceed = selected.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: AnimatedOpacity(
        opacity: canProceed ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: PigioButton(
          label: isLast
              ? (isFr ? 'Terminer le quiz ✓' : 'Finish quiz ✓')
              : (isFr ? 'Suivant →' : 'Next →'),
          color: canProceed ? theme.primary : theme.ink.withValues(alpha: 0.15),
          textColor: canProceed ? theme.onAccent : theme.ink.withValues(alpha: 0.4),
          onTap: canProceed ? _next : null,
        ),
      ),
    );
  }

  // ── COMPLETION VIEW ────────────────────────────────────────────────────────
  Widget _buildCompletion(PigioThemeData theme, bool isFr) {
    final state = context.watch<PigioAppState>();
    final totalAnswers = _answers.values.fold<int>(0, (s, v) => s + v.length);

    return FadeTransition(
      opacity: _slideAnim,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          children: [
            // Header
            PigioWidget(
              mood: PigMood.celebrating,
              size: 120,
              scarfColor: state.mascotScarfColor,
              outfit: state.activeOutfit,
              outfitColors: state.outfitColors,
            ),
            const SizedBox(height: 20),
            Text(
              isFr ? '🎉 Je te connais mieux !' : '🎉 I know you better!',
              style: fw(size: 22, w: FontWeight.w800, color: theme.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isFr
                  ? 'Merci ! J\'ai appris $totalAnswers choses sur toi.\nJe vais pouvoir aider tes proches à mieux te gâter 🎁'
                  : 'Thanks! I learned $totalAnswers things about you.\nI\'ll help your loved ones gift you better 🎁',
              style: fw(size: 14, color: theme.ink.withValues(alpha: 0.65)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Summary cards
            ..._buildSummaryCards(theme, isFr),

            const SizedBox(height: 28),

            // Done button
            PigioButton(
              label: isFr ? 'Parfait !' : 'Got it!',
              color: theme.primary,
              textColor: theme.onAccent,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 0;
                  _completed = false;
                });
                _slideCtrl.forward();
              },
              child: Text(
                isFr ? 'Refaire le quiz' : 'Retake quiz',
                style: fw(size: 14, color: theme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSummaryCards(PigioThemeData theme, bool isFr) {
    final cards = <Widget>[];
    for (final q in kQuizQuestions) {
      final selected = _answers[q.id];
      if (selected == null || selected.isEmpty) continue;
      final labels = q.options
          .where((o) => selected.contains(o.key))
          .map((o) => '${o.emoji} ${isFr ? o.labelFr : o.labelEn}')
          .toList();

      cards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: theme.ink.withValues(alpha: 0.05), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFr ? q.questionFr : q.questionEn,
                style: fw(size: 13, w: FontWeight.w700, color: theme.ink.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: labels.map((l) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(l, style: fw(size: 12, w: FontWeight.w600, color: theme.primary)),
                )).toList(),
              ),
            ],
          ),
        ),
      );
    }
    return cards;
  }
}

// ─── OPTION CHIP ─────────────────────────────────────────────────────────────

class _OptionChip extends StatefulWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final PigioThemeData theme;
  final VoidCallback onTap;

  const _OptionChip({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_OptionChip> createState() => _OptionChipState();
}

class _OptionChipState extends State<_OptionChip> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120), lowerBound: 0.92, upperBound: 1.0, value: 1.0);
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() async {
    await _ctrl.reverse();
    widget.onTap();
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected ? theme.primary : theme.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isSelected ? theme.primary : theme.ink.withValues(alpha: 0.1),
              width: widget.isSelected ? 2 : 1.5,
            ),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: theme.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                : [BoxShadow(color: theme.ink.withValues(alpha: 0.04), blurRadius: 4)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: fw(
                  size: 13,
                  w: FontWeight.w600,
                  color: widget.isSelected ? theme.onAccent : theme.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
