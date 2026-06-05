import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/i18n/i18n.dart';
import 'package:kindy/core/theme/pigio_theme.dart';

class GiftPotDetailSheet extends StatefulWidget {
  final String potId;

  const GiftPotDetailSheet({super.key, required this.potId});

  @override
  State<GiftPotDetailSheet> createState() => _GiftPotDetailSheetState();
}

class _GiftPotDetailSheetState extends State<GiftPotDetailSheet> {
  final _amountController = TextEditingController();
  final _messageController = TextEditingController();
  bool _showContributeForm = false;

  @override
  void dispose() {
    _amountController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final pot = state.getPotById(widget.potId);

    if (pot == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Center(
          child: Text('Cagnotte introuvable',
              style: GoogleFonts.nunito(color: theme.mid)),
        ),
      );
    }

    final isCreator = pot.creatorId == 'self';
    final isOpen = pot.status == GiftPotStatus.open;
    final recipientName = state.contacts
            .where((c) => c.id == pot.recipientContactId)
            .firstOrNull
            ?.name ??
        '?';
    final progress = pot.progressPercent;

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        color: theme.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Text(pot.emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pot.title,
                        style:
                            fw(size: 18, w: FontWeight.w900, color: theme.ink),
                      ),
                      Text(
                        '${t(context, 'pot_for')} $recipientName${pot.isSurprise ? ' 🤫' : ''}',
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.mid,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: theme.mid),
                ),
              ],
            ),
          ),
          Divider(color: theme.divider, height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress section
                  _buildProgressSection(pot, progress, theme),
                  const SizedBox(height: 20),

                  // Mode indicator
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.divider),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          pot.mode == GiftPotMode.share
                              ? Icons.group
                              : Icons.payments_outlined,
                          size: 18,
                          color: theme.accent2,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pot.mode == GiftPotMode.share
                              ? '${t(context, 'pot_mode_share')} · ${pot.sharePerPerson.toStringAsFixed(0)}€ / pers.'
                              : t(context, 'pot_mode_amount'),
                          style: fw(
                              size: 13, w: FontWeight.w700, color: theme.ink),
                        ),
                      ],
                    ),
                  ),

                  if (pot.description != null &&
                      pot.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      pot.description!,
                      style: GoogleFonts.nunito(
                          fontSize: 14, color: theme.ink, height: 1.4),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Participants / contributors section
                  _buildParticipantsSection(pot, state, theme),

                  const SizedBox(height: 20),

                  // Contribute form
                  if (isOpen && _showContributeForm) ...[
                    _buildContributeForm(pot, theme),
                    const SizedBox(height: 12),
                  ],

                  // Action buttons
                  if (isOpen) ...[
                    if (!_showContributeForm)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              setState(() => _showContributeForm = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accent2,
                            foregroundColor: theme.onAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.favorite, size: 18),
                          label: Text(
                            t(context, 'pot_contribute'),
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    if (isCreator) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                state.updateGiftPot(pot.id,
                                    status: GiftPotStatus.closed);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.divider),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                t(context, 'pot_close'),
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w800,
                                  color: theme.mid,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                state.updateGiftPot(pot.id,
                                    status: GiftPotStatus.completed);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.success,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: Text(
                                t(context, 'pot_complete'),
                                style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],

                  // Completed / closed status
                  if (pot.status == GiftPotStatus.completed)
                    _buildStatusBanner('🎊', t(context, 'pot_complete'),
                        theme.success, theme),
                  if (pot.status == GiftPotStatus.closed)
                    _buildStatusBanner(
                        '🔒', 'Cagnotte clôturée', theme.mid, theme),

                  // Delete (creator only)
                  if (isCreator) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          state.deleteGiftPot(pot.id);
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Supprimer la cagnotte',
                          style: GoogleFonts.nunito(
                            color: theme.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildProgressSection(
      GiftPot pot, double progress, PigioThemeData theme) {
    return Column(
      children: [
        // Animated progress bar
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: progress),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: theme.divider,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.accent2),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${pot.totalContributed.toStringAsFixed(0)}€ ${t(context, 'pot_contributed').toLowerCase()}',
                      style: fw(
                          size: 15, w: FontWeight.w800, color: theme.accent2),
                    ),
                    Text(
                      '${t(context, 'pot_target')} : ${pot.targetAmount.toStringAsFixed(0)}€',
                      style: fw(size: 14, w: FontWeight.w700, color: theme.mid),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Participants section ─────────────────────────────────────────────────

  Widget _buildParticipantsSection(
      GiftPot pot, PigioAppState state, PigioThemeData theme) {
    final isCreator = pot.creatorId == 'self';
    final hasInvited = pot.invitedContactIds.isNotEmpty;

    // When there are invited contacts and the current user is the creator,
    // show the full participants panel (invited list cross-referenced with contributions).
    // Otherwise fall back to the simple contribution list.
    if (isCreator && hasInvited) {
      return _buildInvitedParticipantsPanel(pot, state, theme);
    }

    // Simple contributions list (non-creator or no invited contacts)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${t(context, 'pot_contributors')} (${pot.contributorCount})',
          style: fw(size: 14, w: FontWeight.w800, color: theme.mid),
        ),
        const SizedBox(height: 10),
        if (pot.contributions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Aucune contribution pour le moment',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: theme.mid,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ...pot.contributions.map((c) => _buildContributionTile(c, theme)),
      ],
    );
  }

  Widget _buildInvitedParticipantsPanel(
      GiftPot pot, PigioAppState state, PigioThemeData theme) {
    final isShareMode = pot.mode == GiftPotMode.share;

    // Self contribution
    final selfContrib = pot.contributions
        .where((c) => c.contributorId == 'self')
        .firstOrNull;

    // Build rows: self first, then invited contacts
    final allRows = <Widget>[];

    // Self row
    allRows.add(_buildParticipantRow(
      name: 'Moi',
      initials: 'M',
      contribution: selfContrib,
      isPaid: selfContrib != null,
      shareAmount: isShareMode ? pot.sharePerPerson : null,
      theme: theme,
      onMarkPaid: null, // self pays via the contribute form
    ));

    // Invited contacts
    for (final contactId in pot.invitedContactIds) {
      final contact =
          state.contacts.where((c) => c.id == contactId).firstOrNull;
      if (contact == null) continue;

      final contrib = pot.contributions
          .where((c) => c.contributorId == contactId)
          .firstOrNull;
      final isPaid = contrib != null;

      allRows.add(_buildParticipantRow(
        name: contact.name,
        initials: contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
        contribution: contrib,
        isPaid: isPaid,
        shareAmount: isShareMode ? pot.sharePerPerson : null,
        theme: theme,
        onMarkPaid: pot.status == GiftPotStatus.open
            ? () => _showMarkAsPaidDialog(
                context, pot, contactId, contact.name, state, theme)
            : null,
      ));
    }

    final paidCount = pot.invitedContactIds
            .where((id) => pot.contributions.any((c) => c.contributorId == id))
            .length +
        (selfContrib != null ? 1 : 0);
    final total = pot.invitedContactIds.length + 1; // +1 for self

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PARTICIPANTS',
              style:
                  fw(size: 11, w: FontWeight.w900, color: theme.mid, letterSpacing: 1.2),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: paidCount == total
                    ? theme.success.withValues(alpha: 0.12)
                    : theme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$paidCount / $total ont payé',
                style: fw(
                  size: 11,
                  w: FontWeight.w800,
                  color: paidCount == total ? theme.success : theme.warning,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...allRows,
      ],
    );
  }

  Widget _buildParticipantRow({
    required String name,
    required String initials,
    required GiftContribution? contribution,
    required bool isPaid,
    required double? shareAmount,
    required PigioThemeData theme,
    required VoidCallback? onMarkPaid,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isPaid
              ? theme.success.withValues(alpha: 0.06)
              : theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPaid
                ? theme.success.withValues(alpha: 0.3)
                : theme.divider,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isPaid
                    ? theme.success.withValues(alpha: 0.15)
                    : theme.accent2.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: fw(
                  size: 15,
                  w: FontWeight.w800,
                  color: isPaid ? theme.success : theme.accent2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style:
                          fw(size: 14, w: FontWeight.w700, color: theme.ink)),
                  if (isPaid && contribution != null)
                    Text(
                      '${contribution.amount.toStringAsFixed(0)}€ payés${contribution.message != null && contribution.message!.isNotEmpty ? ' · ${contribution.message}' : ''}',
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: theme.success, height: 1.3),
                    )
                  else if (shareAmount != null)
                    Text(
                      '${shareAmount.toStringAsFixed(0)}€ à payer',
                      style:
                          GoogleFonts.nunito(fontSize: 12, color: theme.mid),
                    )
                  else
                    Text(
                      'En attente',
                      style:
                          GoogleFonts.nunito(fontSize: 12, color: theme.warning),
                    ),
                ],
              ),
            ),
            if (isPaid)
              Icon(Icons.check_circle, color: theme.success, size: 20)
            else if (onMarkPaid != null)
              GestureDetector(
                onTap: onMarkPaid,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.accent2.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Marquer payé',
                    style: fw(size: 11, w: FontWeight.w800, color: theme.accent2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMarkAsPaidDialog(
    BuildContext context,
    GiftPot pot,
    String contactId,
    String contactName,
    PigioAppState state,
    PigioThemeData theme,
  ) {
    final amountCtrl = TextEditingController(
      text: pot.mode == GiftPotMode.share
          ? pot.sharePerPerson.toStringAsFixed(0)
          : '',
    );
    final msgCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Marquer $contactName comme payé',
          style: fw(size: 16, w: FontWeight.w900, color: theme.ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.nunito(color: theme.ink),
              decoration: InputDecoration(
                labelText: 'Montant (€)',
                labelStyle: GoogleFonts.nunito(color: theme.mid),
                suffixText: '€',
                filled: true,
                fillColor: theme.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.accent2, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: msgCtrl,
              style: GoogleFonts.nunito(color: theme.ink),
              decoration: InputDecoration(
                hintText: 'Note (optionnel)',
                hintStyle: GoogleFonts.nunito(color: theme.light),
                filled: true,
                fillColor: theme.surface,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.accent2, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              amountCtrl.dispose();
              msgCtrl.dispose();
              Navigator.pop(ctx);
            },
            child:
                Text('Annuler', style: fw(size: 14, w: FontWeight.w700, color: theme.mid)),
          ),
          TextButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;
              state.markParticipantPaid(
                potId: pot.id,
                contactId: contactId,
                amount: amount,
                message: msgCtrl.text.trim().isNotEmpty
                    ? msgCtrl.text.trim()
                    : null,
              );
              amountCtrl.dispose();
              msgCtrl.dispose();
              Navigator.pop(ctx);
            },
            child: Text('Confirmer',
                style: fw(size: 14, w: FontWeight.w800, color: theme.success)),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionTile(
      GiftContribution contribution, PigioThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.accent2.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                contribution.contributorName.isNotEmpty
                    ? contribution.contributorName[0].toUpperCase()
                    : '?',
                style: fw(size: 15, w: FontWeight.w800, color: theme.accent2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contribution.contributorName,
                    style: fw(size: 14, w: FontWeight.w700, color: theme.ink),
                  ),
                  if (contribution.message != null &&
                      contribution.message!.isNotEmpty)
                    Text(
                      contribution.message!,
                      style: GoogleFonts.nunito(
                          fontSize: 12, color: theme.mid, height: 1.3),
                    ),
                ],
              ),
            ),
            Text(
              '${contribution.amount.toStringAsFixed(0)}€',
              style: fw(size: 15, w: FontWeight.w800, color: theme.accent2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributeForm(GiftPot pot, PigioThemeData theme) {
    final isShareMode = pot.mode == GiftPotMode.share;
    if (isShareMode) {
      _amountController.text = pot.sharePerPerson.toStringAsFixed(0);
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.accent2.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(context, 'pot_contribute'),
            style: fw(size: 15, w: FontWeight.w800, color: theme.ink),
          ),
          const SizedBox(height: 12),
          if (isShareMode) ...[
            Text(
              '${t(context, 'pot_your_share')} : ${pot.sharePerPerson.toStringAsFixed(0)}€',
              style: fw(size: 16, w: FontWeight.w800, color: theme.accent2),
            ),
          ] else ...[
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.nunito(color: theme.ink),
              decoration: InputDecoration(
                hintText: t(context, 'pot_amount_label'),
                hintStyle: GoogleFonts.nunito(color: theme.light),
                suffixText: '€',
                filled: true,
                fillColor: theme.sheet,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.accent2, width: 2),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _messageController,
            style: GoogleFonts.nunito(color: theme.ink),
            decoration: InputDecoration(
              hintText: t(context, 'pot_message_hint'),
              hintStyle: GoogleFonts.nunito(color: theme.light),
              filled: true,
              fillColor: theme.sheet,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.accent2, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _showContributeForm = false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Annuler',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700, color: theme.mid)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final amount =
                        double.tryParse(_amountController.text) ?? 0;
                    if (amount <= 0) return;
                    final state = context.read<PigioAppState>();
                    state.addContribution(
                      potId: pot.id,
                      amount: amount,
                      message: _messageController.text.trim().isNotEmpty
                          ? _messageController.text.trim()
                          : null,
                    );
                    setState(() {
                      _showContributeForm = false;
                      _amountController.clear();
                      _messageController.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent2,
                    foregroundColor: theme.onAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('Confirmer',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(
      String emoji, String text, Color color, PigioThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Text(
            text,
            style: fw(size: 16, w: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}
