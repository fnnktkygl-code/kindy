import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'package:kindy/core/config/constants.dart';
import 'package:kindy/shared/widgets/ui_widgets.dart';

/// Bottom sheet for restoring data from an E2E encrypted backup using
/// a 12-word recovery phrase.
class RestoreBackupSheet extends StatefulWidget {
  const RestoreBackupSheet({super.key});

  @override
  State<RestoreBackupSheet> createState() => _RestoreBackupSheetState();
}

class _RestoreBackupSheetState extends State<RestoreBackupSheet> {
  final _phraseCtrl = TextEditingController();
  bool _isRestoring = false;
  String? _error;

  @override
  void dispose() {
    _phraseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;

    return Container(
      decoration: BoxDecoration(
        color: theme.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: theme.mid.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.restore, color: theme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Restaurer", style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
                        const SizedBox(height: 2),
                        Text(
                          "Entre ton code de récupération",
                          style: fw(size: 14, w: FontWeight.w600, color: theme.mid),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Instruction
              Text(
                "Entre les 12 mots de ton code de récupération, séparés par des espaces.",
                style: fw(size: 14, w: FontWeight.w500, color: theme.mid, height: 1.5),
              ),
              const SizedBox(height: 16),

              // Input field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _error != null ? theme.error : theme.mid.withValues(alpha: 0.2),
                    width: _error != null ? 2 : 1,
                  ),
                ),
                child: TextField(
                  controller: _phraseCtrl,
                  style: fw(size: 16, w: FontWeight.w600, color: theme.ink),
                  maxLines: 3,
                  minLines: 3,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: "abricot balcon cerise ...",
                    hintStyle: fw(size: 16, w: FontWeight.w500, color: theme.light),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: theme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!, style: fw(size: 13, w: FontWeight.w600, color: theme.error)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Restore button
              SizedBox(
                width: double.infinity,
                child: PigioButton(
                  label: _isRestoring ? "Restauration en cours..." : "Restaurer mes données",
                  color: theme.primary,
                  textColor: theme.onAccent,
                  onTap: _isRestoring ? null : () => _restore(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final phrase = _phraseCtrl.text.trim().toLowerCase();
    final words = phrase.split(RegExp(r'\s+'));

    if (words.length != 12) {
      setState(() => _error = "Le code doit contenir exactement 12 mots (${words.length} détectés).");
      return;
    }

    setState(() {
      _isRestoring = true;
      _error = null;
    });

    try {
      final state = context.read<PigioAppState>();
      final success = await state.restoreFromPhrase(phrase);

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Données restaurées avec succès ✓", style: fw(size: 14, w: FontWeight.w600))),
          );
        } else {
          setState(() {
            _isRestoring = false;
            _error = "Code incorrect ou aucune sauvegarde trouvée pour ce code.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _error = "Erreur lors de la restauration. Vérifie ta connexion.";
        });
      }
    }
  }
}
