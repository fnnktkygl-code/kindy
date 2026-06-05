import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/ui_widgets.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/theme/pigio_theme.dart';

class GroupPollsSection extends StatefulWidget {
  final CircleGroup group;

  const GroupPollsSection({super.key, required this.group});

  @override
  State<GroupPollsSection> createState() => _GroupPollsSectionState();
}

class _GroupPollsSectionState extends State<GroupPollsSection> {
  bool _showClosed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final polls = state.getPollsForGroup(widget.group.id);
    final activePolls = polls.where((p) => p.isActive).toList();
    final closedPolls = polls.where((p) => !p.isActive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Create poll button
        SizedBox(
          width: double.infinity,
          child: PigioButton(
            label: "Nouveau sondage",
            icon: Icons.poll_outlined,
            color: theme.accent4,
            textColor: theme.onAccent,
            height: 46,
            fontSize: 14,
            onTap: () => _showPollCreator(context, state, theme),
            fullWidth: true,
          ),
        ),
        const SizedBox(height: 16),

        if (polls.isEmpty)
          _buildEmptyState(theme)
        else ...[
          // Active polls
          ...activePolls.map((p) => _buildPollCard(p, state, theme)),

          // Closed polls
          if (closedPolls.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _showClosed = !_showClosed),
              child: Row(
                children: [
                  Text(
                    "TERMINÉS (${closedPolls.length})",
                    style: fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _showClosed ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.mid,
                  ),
                ],
              ),
            ),
            if (_showClosed) ...[
              const SizedBox(height: 10),
              ...closedPolls.map((p) => _buildPollCard(p, state, theme)),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildEmptyState(PigioThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text("📊", style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            "Aucun sondage",
            style: fw(size: 15, w: FontWeight.w800, color: theme.ink),
          ),
          const SizedBox(height: 4),
          Text(
            "Créez un sondage pour décider ensemble !",
            style: fw(size: 13, w: FontWeight.w600, color: theme.mid),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPollCard(GroupPoll poll, PigioAppState state, PigioThemeData theme) {
    final myVote = poll.voterChoice('self');
    final total = poll.totalVotes;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: poll.isActive ? theme.divider : theme.mid.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  poll.question,
                  style: GoogleFonts.caveat(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: poll.isActive ? theme.ink : theme.mid,
                  ),
                ),
              ),
              if (!poll.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.mid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text("Terminé", style: fw(size: 10, w: FontWeight.w800, color: theme.mid)),
                ),
              if (poll.createdBy == 'self') ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _confirmDeletePoll(context, poll.id, poll.question, state, theme),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: theme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.delete_outline, size: 16, color: theme.error),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          ...poll.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final voteCount = poll.votesForOption(index);
            final percent = total > 0 ? voteCount / total : 0.0;
            final isMyVote = myVote == index;

            return GestureDetector(
              onTap: poll.isActive
                  ? () => isMyVote
                      ? state.unvoteOnPoll(poll.id)
                      : state.voteOnPoll(poll.id, index)
                  : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMyVote
                      ? theme.primary.withValues(alpha: 0.1)
                      : theme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMyVote ? theme.primary : theme.divider,
                    width: isMyVote ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isMyVote) ...[
                          Icon(Icons.check_circle, size: 16, color: theme.primary),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            option,
                            style: fw(
                              size: 14,
                              w: isMyVote ? FontWeight.w800 : FontWeight.w600,
                              color: poll.isActive ? theme.ink : theme.mid,
                            ),
                          ),
                        ),
                        Text(
                          '$voteCount',
                          style: fw(size: 13, w: FontWeight.w800, color: theme.mid),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        backgroundColor: theme.divider,
                        valueColor: AlwaysStoppedAnimation(
                          isMyVote ? theme.primary : theme.accent2,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (poll.isActive && poll.createdBy == 'self') ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => state.closePoll(poll.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Text(
                      "Fermer le sondage",
                      style: fw(size: 12, w: FontWeight.w700, color: theme.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (total > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                "$total vote${total > 1 ? 's' : ''}",
                style: fw(size: 11, w: FontWeight.w600, color: theme.light),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDeletePoll(BuildContext context, String pollId, String question, PigioAppState state, PigioThemeData theme) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Supprimer ce sondage ?", style: fw(size: 17, w: FontWeight.w900, color: theme.ink)),
        content: Text(
          "\"$question\" sera supprimé définitivement.",
          style: fw(size: 14, w: FontWeight.w600, color: theme.mid, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Annuler", style: fw(size: 14, w: FontWeight.w800, color: theme.mid)),
          ),
          TextButton(
            onPressed: () {
              state.deletePoll(pollId);
              Navigator.pop(ctx);
            },
            child: Text("Supprimer", style: fw(size: 14, w: FontWeight.w800, color: theme.error)),
          ),
        ],
      ),
    );
  }

  void _showPollCreator(BuildContext context, PigioAppState state, PigioThemeData theme) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PollCreatorSheet(groupId: widget.group.id),
    );
  }
}

// ─── Poll Creator Sheet ────────────────────────────────────────────────────

class _PollCreatorSheet extends StatefulWidget {
  final String groupId;
  const _PollCreatorSheet({required this.groupId});

  @override
  State<_PollCreatorSheet> createState() => _PollCreatorSheetState();
}

class _PollCreatorSheetState extends State<_PollCreatorSheet> {
  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _submitted = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isValid {
    if (_questionCtrl.text.trim().isEmpty) return false;
    final nonEmpty = _optionCtrls.where((c) => c.text.trim().isNotEmpty).length;
    return nonEmpty >= 2;
  }

  void _submit() {
    setState(() => _submitted = true);
    if (!_isValid) return;

    final state = context.read<PigioAppState>();
    state.createPoll(
      groupId: widget.groupId,
      question: _questionCtrl.text.trim(),
      options: _optionCtrls
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
    );
    Navigator.pop(context);
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
        top: 12,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.mid.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Nouveau sondage",
              style: fw(size: 22, w: FontWeight.w900, color: theme.ink),
            ),
            const SizedBox(height: 6),
            Text(
              "Posez une question au groupe et proposez des options.",
              style: fw(size: 13, w: FontWeight.w600, color: theme.mid),
            ),
            const SizedBox(height: 24),

            // Question field
            Text("Question", style: fw(size: 14, w: FontWeight.w800, color: theme.ink)),
            const SizedBox(height: 8),
            _buildField(
              controller: _questionCtrl,
              hint: "Que voulez-vous décider ?",
              theme: theme,
              hasError: _submitted && _questionCtrl.text.trim().isEmpty,
            ),
            const SizedBox(height: 20),

            // Options
            Text("Options", style: fw(size: 14, w: FontWeight.w800, color: theme.ink)),
            const SizedBox(height: 8),
            ...List.generate(_optionCtrls.length, (i) {
              final isRemovable = _optionCtrls.length > 2;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "${i + 1}",
                        style: fw(size: 13, w: FontWeight.w800, color: theme.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildField(
                        controller: _optionCtrls[i],
                        hint: "Option ${i + 1}",
                        theme: theme,
                        hasError: _submitted && i < 2 && _optionCtrls[i].text.trim().isEmpty,
                      ),
                    ),
                    if (isRemovable) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _optionCtrls[i].dispose();
                            _optionCtrls.removeAt(i);
                          });
                        },
                        child: Icon(Icons.remove_circle_outline, color: theme.error, size: 22),
                      ),
                    ],
                  ],
                ),
              );
            }),

            if (_optionCtrls.length < 4)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _optionCtrls.add(TextEditingController());
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: theme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text("Ajouter une option", style: fw(size: 13, w: FontWeight.w700, color: theme.primary)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              child: PigioButton(
                label: "Créer le sondage",
                color: theme.primary,
                textColor: theme.onAccent,
                height: 52,
                fontSize: 15,
                onTap: _submit,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required PigioThemeData theme,
    bool hasError = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: hasError ? theme.error.withValues(alpha: 0.05) : theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError ? theme.error.withValues(alpha: 0.5) : theme.mid.withValues(alpha: 0.1),
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        style: fw(size: 15, w: FontWeight.w600, color: theme.ink),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: fw(size: 15, w: FontWeight.w500, color: theme.light),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
