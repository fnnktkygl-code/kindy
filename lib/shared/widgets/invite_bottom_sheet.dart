import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kindy/core/config/constants.dart';
import 'package:kindy/core/state/app_state.dart';
import 'package:kindy/core/theme/pigio_theme.dart';
import 'ui_widgets.dart';

class InviteBottomSheet extends StatefulWidget {
  final ContactProfile? contact;
  final String? groupId;
  final String? groupName;

  const InviteBottomSheet({
    super.key,
    this.contact,
    this.groupId,
    this.groupName,
  });

  @override
  State<InviteBottomSheet> createState() => _InviteBottomSheetState();
}

class _InviteBottomSheetState extends State<InviteBottomSheet> {
  bool _isSending = false;

  /// Client-side cooldown: prevent spam-tapping invite sends.
  static DateTime? _lastSendTime;
  static const _sendCooldown = Duration(seconds: 30);

  Future<bool> _showConsentModal(PigioThemeData theme) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: theme.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Consentement requis', style: fw(size: 20, w: FontWeight.w900, color: theme.ink)),
                const SizedBox(height: 10),
                Text(
                  'Pigio va créer un lien temporaire sécurisé contenant uniquement un identifiant opaque. Ce lien sera partagé via la méthode de votre choix (WhatsApp, SMS…), qui dispose de sa propre politique de confidentialité. Aucune donnée personnelle (nom, adresse…) n\'est incluse dans le lien. Vous pouvez révoquer votre consentement dans les paramètres.',
                  style: fw(size: 13, w: FontWeight.w600, color: theme.mid),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: PigioButton(
                        label: 'Annuler',
                        color: theme.surface,
                        textColor: theme.ink,
                        height: 44,
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PigioButton(
                        label: 'J’accepte',
                        color: theme.primary,
                        textColor: theme.onAccent,
                        height: 44,
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _sendInvite(InviteChannel channel) async {
    if (_isSending) return;

    // Rate limit: 30s cooldown between invite sends
    if (_lastSendTime != null && DateTime.now().difference(_lastSendTime!) < _sendCooldown) {
      final isFr = context.read<PigioAppState>().locale.languageCode == 'fr';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFr ? 'Patiente un peu avant de renvoyer une invitation.' : 'Please wait a moment before sending another invite.')),
      );
      return;
    }

    final theme = context.ptnl;
    final state = context.read<PigioAppState>();

    if (!state.contactsConsentGiven) {
      final consent = await _showConsentModal(theme);
      if (!consent || !mounted) return;
      state.setContactsConsentGiven(true);
    }

    setState(() => _isSending = true);
    try {
      final String? link;
      if (widget.contact != null) {
        link = await state.sendInvite(
          widget.contact!.id,
          groupId: widget.groupId,
          channel: channel,
        );
      } else if (widget.groupId != null) {
        link = await state.createGroupInviteLink(
          widget.groupId!,
          channel: channel,
        );
      } else {
        link = await state.createContactListInviteLink(channel: channel);
      }

      if (link == null || link.isEmpty) {
        throw Exception('Lien d’invitation vide');
      }

      if (channel == InviteChannel.copyLink) {
        await Clipboard.setData(ClipboardData(text: link));
      } else if (channel == InviteChannel.whatsApp) {
        final message = 'Rejoins-moi sur Kindy 🐣 : $link';
        final encoded = Uri.encodeComponent(message);
        final directUri = Uri.parse('whatsapp://send?text=$encoded');
        final webUri = Uri.parse('https://wa.me/?text=$encoded');

        if (await canLaunchUrl(directUri)) {
          await launchUrl(directUri, mode: LaunchMode.externalApplication);
        } else if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          await SharePlus.instance.share(
            ShareParams(
              text: message,
              title: 'Invitation Kindy',
            ),
          );
        }
      } else {
        await SharePlus.instance.share(
          ShareParams(
            text: 'Invitation Kindy: $link',
            title: 'Invitation Kindy',
          ),
        );
      }

      _lastSendTime = DateTime.now();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            channel == InviteChannel.copyLink
                ? 'Lien copié dans le presse-papiers.'
                : 'Invitation prête à être partagée.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible d’envoyer l’invitation. R\u00e9essayez.")),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _methodTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required InviteChannel channel,
  }) {
    final theme = context.pt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.divider.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: fw(size: 14, w: FontWeight.w800, color: theme.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: fw(size: 12, w: FontWeight.w600, color: theme.mid)),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: PigioButton(
              label: 'Choisir',
              fullWidth: false,
              height: 40,
              fontSize: 13,
              color: color,
              // Utilise la couleur du scaffold pour s'assurer que le texte est lisible
              // même si la couleur du bouton est 'theme.ink' en mode sombre
              textColor: color == theme.ink ? theme.scaffold : theme.onAccent,
              onTap: _isSending ? null : () => _sendInvite(channel),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.pt;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.sheet,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.mid.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.contact != null
                  ? 'Inviter ${widget.contact!.name}'
                  : (widget.groupName != null ? 'Inviter au cercle ${widget.groupName}' : 'Inviter sur Pigio'),
              style: fw(size: 22, w: FontWeight.w900, color: theme.ink),
            ),
            const SizedBox(height: 6),
            Text(
              widget.groupName != null
                  ? 'Invitation vers le cercle « ${widget.groupName} ».'
                  : (widget.contact != null
                      ? 'Envoyez une invitation à ce contact via la méthode de votre choix.'
                      : 'Générez un lien d’invitation à partager via WhatsApp/SMS ou copier.'),
              style: fw(size: 13, w: FontWeight.w600, color: theme.mid),
            ),
            const SizedBox(height: 18),
            _methodTile(
              title: 'SMS',
              subtitle: 'Partage via la feuille native iOS/Android',
              icon: Icons.sms_outlined,
              color: theme.primary,
              channel: InviteChannel.sms,
            ),
            _methodTile(
              title: 'WhatsApp',
              subtitle: 'Partage via la feuille native iOS/Android',
              icon: Icons.chat_bubble_outline,
              color: theme.accent4,
              channel: InviteChannel.whatsApp,
            ),
            _methodTile(
              title: 'Copier le lien',
              subtitle: 'Copie un lien temporaire sécurisé',
              icon: Icons.link_outlined,
              color: theme.ink,
              channel: InviteChannel.copyLink,
            ),
            if (_isSending) ...[
              const SizedBox(height: 8),
              Center(child: CircularProgressIndicator(color: theme.primary)),
            ],
          ],
        ),
      ),
    );
  }
}
