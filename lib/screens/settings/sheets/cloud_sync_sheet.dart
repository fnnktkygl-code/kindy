import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';
import 'restore_backup_sheet.dart';

/// Bottom sheet for managing E2E encrypted cloud backup.
class CloudSyncSheet extends StatefulWidget {
  const CloudSyncSheet({super.key});

  @override
  State<CloudSyncSheet> createState() => _CloudSyncSheetState();
}

class _CloudSyncSheetState extends State<CloudSyncSheet> {
  bool _isActivating = false;
  bool _isSyncing = false;
  bool _isDeleting = false;
  String? _recoveryPhrase;
  bool _hasAcknowledged = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;
    final state = context.watch<PigioAppState>();
    final isEnabled = state.syncEnabled && state.backupLookupKey.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle ──
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: theme.mid.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),

              // ── Header ──
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.cloud_outlined, color: theme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Sauvegarde Cloud", style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
                        const SizedBox(height: 2),
                        Text(
                          isEnabled ? "Chiffrement activé ✓" : "Non activée",
                          style: fw(size: 14, w: FontWeight.w600, color: isEnabled ? theme.success : theme.mid),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Recovery Phrase Display (activation flow) ──
              if (_recoveryPhrase != null) ...[
                _buildRecoveryPhraseView(theme),
              ]

              // ── Enabled State ──
              else if (isEnabled) ...[
                _buildEnabledView(theme, state),
              ]

              // ── Disabled State ──
              else ...[
                _buildDisabledView(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledView(PigioThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Explanation card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 20, color: theme.primary),
                  const SizedBox(width: 8),
                  Text("Zero-Knowledge", style: fw(size: 16, w: FontWeight.w800, color: theme.ink)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Tes données sont chiffrées avec un code de récupération que toi seul connais. "
                "Même nous ne pouvons pas les lire.",
                style: fw(size: 14, w: FontWeight.w500, color: theme.mid, height: 1.5),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.key, "Code de 12 mots unique", theme),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.shield_outlined, "Chiffrement AES-256", theme),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.visibility_off, "Serveur ne voit rien", theme),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Activate button
        SizedBox(
          width: double.infinity,
          child: PigioButton(
            label: _isActivating ? "Activation en cours..." : "Activer la sauvegarde",
            color: theme.primary,
            textColor: theme.onAccent,
            onTap: _isActivating ? null : () => _activate(context),
          ),
        ),
        const SizedBox(height: 12),

        // Restore button
        Center(
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const RestoreBackupSheet(),
              );
            },
            child: Text(
              "J'ai déjà un code de récupération",
              style: fw(size: 14, w: FontWeight.w700, color: theme.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecoveryPhraseView(PigioThemeData theme) {
    final words = _recoveryPhrase!.split(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Warning banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.accent2.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.accent2.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: theme.accent2, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Note ce code maintenant ! Il ne sera plus jamais affiché. "
                  "Sans lui, impossible de récupérer tes données.",
                  style: fw(size: 13, w: FontWeight.w600, color: theme.accent2, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text("Ton code de récupération", style: fw(size: 16, w: FontWeight.w800, color: theme.ink)),
        const SizedBox(height: 12),

        // Word grid
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: words.asMap().entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.divider),
                ),
                child: Text(
                  "${entry.key + 1}. ${entry.value}",
                  style: fw(size: 15, w: FontWeight.w700, color: theme.ink),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Copy button
        Center(
          child: GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _recoveryPhrase!));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Code copié dans le presse-papiers", style: fw(size: 14, w: FontWeight.w600))),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, size: 16, color: theme.primary),
                  const SizedBox(width: 8),
                  Text("Copier le code", style: fw(size: 14, w: FontWeight.w700, color: theme.primary)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Acknowledgement checkbox
        GestureDetector(
          onTap: () => setState(() => _hasAcknowledged = !_hasAcknowledged),
          child: Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: _hasAcknowledged ? theme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _hasAcknowledged ? theme.primary : theme.mid, width: 2),
                ),
                child: _hasAcknowledged
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "J'ai bien noté mon code de récupération",
                  style: fw(size: 14, w: FontWeight.w700, color: theme.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: PigioButton(
            label: "Continuer",
            color: _hasAcknowledged ? theme.primary : theme.mid.withValues(alpha: 0.3),
            textColor: _hasAcknowledged ? theme.onAccent : theme.mid,
            onTap: _hasAcknowledged ? () => Navigator.pop(context) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildEnabledView(PigioThemeData theme, PigioAppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.success.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: theme.success),
                  const SizedBox(width: 8),
                  Text("Sauvegarde active", style: fw(size: 16, w: FontWeight.w800, color: theme.success)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Tes données sont automatiquement sauvegardées et chiffrées. "
                "Utilise ton code de récupération si tu réinstalles l'app.",
                style: fw(size: 14, w: FontWeight.w500, color: theme.mid, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Sync now
        SizedBox(
          width: double.infinity,
          child: PigioButton(
            label: _isSyncing ? "Synchronisation..." : "Synchroniser maintenant",
            color: theme.primary,
            textColor: theme.onAccent,
            onTap: _isSyncing ? null : () => _syncNow(context, state),
          ),
        ),
        const SizedBox(height: 16),

        // Delete backup (RGPD Art. 17)
        Center(
          child: GestureDetector(
            onTap: _isDeleting ? null : () => _deleteBackup(context, state, theme),
            child: Text(
              _isDeleting ? "Suppression..." : "Supprimer ma sauvegarde cloud",
              style: fw(size: 14, w: FontWeight.w700, color: theme.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text, PigioThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.primary),
        const SizedBox(width: 8),
        Text(text, style: fw(size: 13, w: FontWeight.w600, color: theme.ink)),
      ],
    );
  }

  Future<void> _activate(BuildContext context) async {
    setState(() => _isActivating = true);
    try {
      final state = context.read<PigioAppState>();
      final phrase = await state.enableE2EBackup();
      if (mounted) {
        setState(() {
          _recoveryPhrase = phrase;
          _isActivating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActivating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'activation : $e")),
        );
      }
    }
  }

  Future<void> _syncNow(BuildContext context, PigioAppState state) async {
    setState(() => _isSyncing = true);
    try {
      await state.syncNow();
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sauvegarde synchronisée ✓", style: fw(size: 14, w: FontWeight.w600))),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _deleteBackup(BuildContext context, PigioAppState state, PigioThemeData theme) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.sheet,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Supprimer la sauvegarde ?", style: fw(size: 18, w: FontWeight.w900, color: theme.ink)),
        content: Text(
          "Cette action est irréversible. Tes données resteront sur ton téléphone mais seront supprimées du cloud.",
          style: fw(size: 14, w: FontWeight.w500, color: theme.mid, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Annuler", style: fw(size: 14, w: FontWeight.w700, color: theme.mid)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Supprimer", style: fw(size: 14, w: FontWeight.w700, color: theme.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await state.deleteCloudBackup();
      if (mounted) {
        setState(() => _isDeleting = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sauvegarde cloud supprimée", style: fw(size: 14, w: FontWeight.w600))),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}
