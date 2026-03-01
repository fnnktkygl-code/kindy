# Audit Complet — Système d'Invitation Pigio

**Date de l'audit :** 23 février 2026  
**Périmètre :** Système d'invitation de contacts et de groupes (génération de jetons, liens profonds, flux de consentement, synchronisation, mascotte)  
**Fichiers audités :** 26 fichiers (Edge Functions, services Dart, état Provider, UI, configuration de plateforme, migration SQL, manifestes)

---

## 1. Synthèse Exécutive

Le système d'invitation Pigio est fonctionnellement **complet pour un MVP** : il couvre la génération de jetons côté serveur (SHA-256 + token opaque), la résolution via Edge Functions Supabase, la redirection 302 vers un lien profond, la gestion d'état côté client avec Provider, un flux de consentement pré-partage et une intégration de la mascotte. L'architecture est raisonnablement compartimentée entre le service HTTP (`InvitationService`), l'état applicatif (`PigioAppState`) et les Edge Functions.

**Maturité globale : 6/10** — Bienconçue pour un prototype avancé, mais plusieurs failles de sécurité critiques, des lacunes de confidentialité RGPD et des fragilités architecturales empêchent un déploiement en production sans corrections préalables.

| Axe | Note | Commentaire |
|---|---|---|
| Logique & Architecture | 7/10 | Flux cohérent, mais god-class `PigioAppState` (1925 lignes) et manque de séparation |
| Sécurité | 4/10 | Jetons valides dans l'URL, pas de rate-limiting, replay possible, `consumed_ip` RGPD-sensible |
| Confidentialité & RGPD | 5/10 | Consentement présent mais contournable, identifiants exposés dans les liens partagés |
| Performances | 7/10 | Synchronisation séquentielle des invites en suspens, sinon correct |

---

## 2. Failles Critiques

### CRIT-01 · Jetons bruts exposés dans l'URL partagée (Sévérité : CRITIQUE)

**Fichier :** [supabase/functions/invite-create/index.ts](supabase/functions/invite-create/index.ts#L68-L74)  
**Constat :** Le lien d'invitation contient le token opaque **en clair** dans les query parameters, **accompagné de l'identifiant de l'expéditeur (`inviter`), de l'identifiant du contact (`contactId`) et du groupe (`groupId`)**. Ce lien est partagé via WhatsApp, SMS ou presse-papiers.

```
https://…/functions/v1/invite-open?token=<TOKEN>&inviter=richard&contactId=abc&groupId=xyz&exp=2026-02-25T…
```

**Risques :**
- Toute personne interceptant le lien (historique de chat, proxy, log serveur) obtient le token brut **et** les identifiants internes.
- L'`inviterId` est le `handle` ou le `name` de l'utilisateur — c'est une **donnée personnelle** transmise en clair dans une URL partagée sur des plateformes tierces.
- Le `contactId` et le `groupId` sont des UUID v4 internes exposés, permettant potentiellement l'énumération.

**Correctif proposé :**

```typescript
// invite-create/index.ts — NE PAS inclure d'identifiants dans l'URL publique
const inviteUrl = new URL('/functions/v1/invite-open', invitePublicBase);
inviteUrl.searchParams.set('token', token);
// SUPPRIMER : inviter, contactId, groupId, exp — ces données sont dans la DB côté serveur
```

Côté `invite-open`, le serveur doit chercher la DB par token hash pour récupérer les métadonnées, au lieu de les transiter dans l'URL.

---

### CRIT-02 · Attaque par rejeu (Replay Attack) — Absence de single-use côté `invite-open` (Sévérité : HAUTE)

**Fichier :** [supabase/functions/invite-open/index.ts](supabase/functions/invite-open/index.ts#L31-L55)  
**Constat :** La fonction `invite-open` effectue une redirection 302 vers `pigio://invite?token=…` **sans vérifier la validité du token ni le marquer comme consommé**. Seul `invite-resolve` marque le token comme `accepted`.

**Scénario d'attaque :** Un attaquant qui intercepte le lien HTTPS peut l'ouvrir un nombre illimité de fois. `invite-open` redirigera toujours vers le deep-link. Si `invite-resolve` est appelé après la première acceptation, le statut `already_consumed` protège côté serveur, **mais** le fallback URL-parameter dans `_resolveIncomingLinkWithFallback()` ([app_state.dart](lib/theme/app_state.dart#L1196-L1216)) **accepte le lien localement sans validation serveur**.

**Fichier :** [lib/theme/app_state.dart](lib/theme/app_state.dart#L1196-L1216)
```dart
Future<InvitationLinkResolution> _resolveIncomingLinkWithFallback(Uri link) async {
    try {
      final remote = await _invitationService.resolveIncomingLink(link);
      if (remote.valid) return remote;
    } catch (_) {}
    // ⚠️ FALLBACK: accepte sans validation serveur si le réseau échoue
    final tokenId = link.queryParameters['token'] ?? ...;
    ...
    return InvitationLinkResolution(valid: true, ...); // TOUJOURS valide en fallback
}
```

**Risque :** En cas d'erreur réseau ou si le serveur est injoignable, **n'importe quel lien avec un token et un inviter est accepté localement comme valide**, sans aucune vérification cryptographique. Un attaquant peut forger un lien factice `pigio://invite?token=fake&inviter=evil`.

**Correctif proposé :**
```dart
// NE JAMAIS accepter un lien sans validation serveur
Future<InvitationLinkResolution> _resolveIncomingLinkWithFallback(Uri link) async {
  try {
    return await _invitationService.resolveIncomingLink(link);
  } catch (e) {
    return InvitationLinkResolution(valid: false);
  }
}
```

Si un mode hors-ligne est nécessaire, stocker les liens non résolus dans une file d'attente et les résoudre lors de la reconnexion.

---

### CRIT-03 · Aucun Rate-Limiting sur la création de jetons (Sévérité : HAUTE)

**Fichier :** [supabase/functions/invite-create/index.ts](supabase/functions/invite-create/index.ts)  
**Constat :** L'endpoint `invite-create` est déployé avec `--no-verify-jwt`. Il n'y a aucune authentification ni rate-limiting. Un attaquant peut :
1. Inonder la table `invites` de millions de lignes (DoS).
2. Utiliser l'endpoint comme spam relay en générant des milliers de liens avec des `inviterId` arbitraires.

**Correctif proposé :**
1. Exiger un JWT Supabase Auth ou une clé API applicative.
2. À défaut, ajouter un rate-limit par IP dans la fonction :

```typescript
// invite-create/index.ts
const ip = req.headers.get('x-forwarded-for') ?? 'unknown';
const { count } = await admin
  .from('invites')
  .select('id', { count: 'exact', head: true })
  .eq('inviter_id', inviterId)
  .gte('created_at', new Date(Date.now() - 3600_000).toISOString());

if (count && count > 20) {
  return json({ error: 'Rate limit exceeded' }, 429);
}
```

---

### CRIT-04 · Stockage de l'IP et User-Agent du destinataire (Sévérité : HAUTE — RGPD)

**Fichier :** [supabase/functions/invite-resolve/index.ts](supabase/functions/invite-resolve/index.ts#L71-L72)  
**Constat :**
```typescript
const ip = req.headers.get('x-forwarded-for') ?? req.headers.get('cf-connecting-ip');
const ua = req.headers.get('user-agent');
// stocké dans consumed_ip et consumed_ua
```

L'adresse IP et le User-Agent du **destinataire** de l'invitation sont stockés dans la base Supabase sans :
- Notice de collecte dans l'app du destinataire
- Base légale explicite (pas de consentement, pas d'intérêt légitime documenté)
- Politique de rétention ou de suppression

**Correctif :** Supprimer ces colonnes ou, si nécessaire pour la détection de fraude, les hasher et les supprimer après 72h via un cron job Supabase.

---

## 3. Recommandations d'Architecture

### ARCH-01 · God-Class `PigioAppState` — Responsabilité unique violée

**Fichier :** [lib/theme/app_state.dart](lib/theme/app_state.dart) (1925 lignes)  
**Constat :** Cette classe gère : les souhaits, les contacts, les groupes, les événements, les tailles vestimentaires, le profil utilisateur, les logs d'activité, les paramètres de la mascotte, le mode surprise, le consentement, **ET** toute la logique d'invitation (création, résolution, sync, liens profonds). Chaque appel à `notifyListeners()` reconstruit potentiellement tout l'arbre de widgets qui écoute cet objet.

**Proposition :**
```
lib/
  state/
    app_state.dart           → orchestrateur minimal, compose les sous-états
    invitation_state.dart    → PendingInvite, sendInvite(), handleIncomingLink()
    contact_state.dart       → contacts, statuts, profils
    wish_state.dart          → wishes, cache, réservation
    mascot_state.dart        → moments, paramètres, chattiness
    profile_state.dart       → UserProfile, SizeProfile
```

Utiliser `MultiProvider` avec des `ChangeNotifier` indépendants. Les widgets n'écoutent que l'état pertinent → réduction drastique des rebuilds.

---

### ARCH-02 · Deep Link : course de condition entre `getInitialLink()` et l'état

**Fichier :** [lib/main.dart](lib/main.dart#L110-L126)  
**Constat :** `_initDeepLinkHandling()` est appelé dans `initState()` de `_MainShellState`. Il lit immédiatement `context.read<PigioAppState>()`, mais `PigioAppState._loadData()` est **asynchrone** (SharedPreferences) et peut ne pas être terminé à ce stade. Si un lien profond arrive avant que les données soient chargées, `handleIncomingLink()` opère sur un état vide.

**Correctif :**
```dart
// PigioAppState
final Completer<void> _ready = Completer<void>();
Future<void> get ready => _ready.future;

Future<void> _loadData() async {
  // ... chargement ...
  _ready.complete();
}

// main.dart
Future<void> _initDeepLinkHandling() async {
  await context.read<PigioAppState>().ready; // attendre le chargement
  final initial = await _appLinks.getInitialLink();
  ...
}
```

---

### ARCH-03 · Modèles immutables avec `copyWith` incomplet

**Fichier :** [lib/theme/app_state.dart](lib/theme/app_state.dart#L90-L180) (class `ContactProfile`)  
**Constat :** `ContactProfile` n'a pas de méthode `copyWith()`. Chaque modification de statut reconstruit manuellement un nouveau `ContactProfile` avec tous les champs ([ligne ~750](lib/theme/app_state.dart#L750-L770)) — erreur probable à chaque ajout de champ.

**Correctif :** Ajouter `copyWith()` (ou utiliser `freezed`/`equatable`) :
```dart
ContactProfile copyWith({
  String? name,
  ContactStatus? status,
  bool? managedProfile,
  // ... tous les champs
}) {
  return ContactProfile(
    id: id,
    name: name ?? this.name,
    status: status ?? this.status,
    managedProfile: managedProfile ?? this.managedProfile,
    // ...
  );
}
```

---

### ARCH-04 · Absence de gestion d'erreur visible pour l'utilisateur dans `_syncPendingInvitesFromServer()`

**Fichier :** [lib/theme/app_state.dart](lib/theme/app_state.dart#L855-L895)  
**Constat :** Cette méthode est appelée via `Future.microtask()` dans `_loadData()`. Si une exception non interceptée se produit dans la boucle (par exemple un changement de format de réponse de l'API), elle sera **silencieusement avalée** et l'utilisateur ne saura pas que la synchronisation a échoué.

**Correctif :** Wrapper dans un try-catch et loguer :
```dart
Future<void> _syncPendingInvitesFromServer() async {
  for (int i = 0; i < _pendingInvites.length; i++) {
    try {
      // ... polling ...
    } catch (e) {
      debugPrint('[Pigio] Sync invite ${_pendingInvites[i].tokenId} failed: $e');
    }
  }
}
```

---

### ARCH-05 · Edge Functions : duplication de `sha256Hex` et `corsHeaders`

**Fichiers :** Quatre Edge Functions dupliquent indépendamment `sha256Hex()`, `corsHeaders`, et `json()`.

**Correctif :** Extraire dans un module partagé :
```
supabase/functions/_shared/
  cors.ts
  crypto.ts
  response.ts
```

```typescript
// invite-create/index.ts
import { corsHeaders, json } from '../_shared/response.ts';
import { sha256Hex } from '../_shared/crypto.ts';
```

---

## 4. Failles de Sécurité Complémentaires

### SEC-01 · `Access-Control-Allow-Origin: *` sur tous les endpoints (Sévérité : MOYENNE)

**Fichiers :** Les 4 Edge Functions utilisent `'Access-Control-Allow-Origin': '*'`.

**Risque :** N'importe quel site web malveillant peut appeler `invite-create`, `invite-resolve` ou `invite-status` via JavaScript côté client.

**Correctif :** Restreindre à l'origine Pigio :
```typescript
const ALLOWED_ORIGIN = 'https://pigio.app';
const corsHeaders = {
  'Access-Control-Allow-Origin': ALLOWED_ORIGIN,
  ...
};
```

---

### SEC-02 · `invite-status` renvoie le token brut dans la réponse (Sévérité : MOYENNE)

**Fichier :** [supabase/functions/invite-status/index.ts](supabase/functions/invite-status/index.ts#L51-L60)  
**Constat :** La réponse inclut `tokenId: token` (le token envoyé en query). Bien que fonctionnellement neutre (l'appelant le connaît déjà), un log de réponse ou un proxy intermédiaire aurait accès au token.

**Correctif :** Ne pas renvoyer le token dans le body. Identifier via `invitationId` (UUID DB) uniquement.

---

### SEC-03 · Fallback hors-ligne génère des UUID v4 comme tokens (Sévérité : MOYENNE)

**Fichier :** [lib/theme/app_state.dart](lib/theme/app_state.dart#L1000-L1020)  
**Constat :** Si l'appel API échoue, `_createTokenWithFallback()` génère un UUID v4 comme `tokenId`. Contrairement aux 256 bits du token serveur (32 octets aléatoires encodés base64url), un UUID v4 ne contient que ~122 bits d'entropie. De plus, ce token n'est **jamais stocké côté serveur** — il n'y a pas de hash en base pour le valider.

**Risque :** Le lien fallback est un lien "fantôme" qui ne peut être résolu que via le fallback client, qui l'accepte toujours (voir CRIT-02).

**Correctif :** Ne pas générer de lien d'invitation en mode hors-ligne. Afficher un message d'erreur clair à l'utilisateur.

---

### SEC-04 · `sendInvite()` permet l'envoi pour les profils **non-managés** uniquement (Sévérité : INFO)

**Fichier :** [lib/theme/app_state.dart](lib/theme/app_state.dart#L908-L912)
```dart
if (contact.isManaged) {
  throw Exception('Ce profil est administré localement et ne peut pas recevoir d\'invitation.');
}
```

**Constat :** La logique est **inversée** par rapport à l'intention documentée. On empêche l'envoi d'une invitation à un contact "managed" (créé localement par l'utilisateur), ce qui signifie qu'on ne peut inviter **que** des contacts déjà reçus via invitation. Ce n'est probablement pas le comportement souhaité.

**Correctif attendu :** Clarifier la sémantique de `managedProfile`. Si l'objectif est d'empêcher d'inviter un contact qui est déjà arrivé via invitation (non-managé), la logique est correcte mais le naming est confus. Documenter explicitement.

---

### SEC-05 · Absence de validation de la structure du `inviterId` (Sévérité : BASSE)

**Fichier :** [supabase/functions/invite-create/index.ts](supabase/functions/invite-create/index.ts#L38)  
**Constat :** `inviterId` est un `String(body.inviterId).trim()` — il peut contenir n'importe quel caractère, y compris du HTML/JavaScript. Bien qu'il ne soit pas rendu dans une page web (redirection 302), il est stocké en base et pourrait être affiché dans un futur dashboard admin non sanitisé.

**Correctif :**
```typescript
const inviterId = String(body.inviterId ?? '').trim().substring(0, 100);
if (!/^[\w@.-]+$/.test(inviterId)) return json({ error: 'Invalid inviterId' }, 400);
```

---

## 5. Confidentialité et RGPD

### RGPD-01 · Le consentement est contournable par `setContactsConsentGiven(true)` (Sévérité : HAUTE)

**Fichier :** [lib/theme/app_state.dart](lib/theme/app_state.dart#L729)  
**Constat :** `setContactsConsentGiven()` est une méthode publique. Le consentement est stocké comme un simple booléen dans SharedPreferences. Une fois défini à `true`, il n'est **jamais ré-interrogé**. L'utilisateur ne peut pas le révoquer facilement (pas d'UI de révocation visible).

**Par ailleurs :** Le consentement est vérifié dans `invite_bottom_sheet.dart` mais **n'est pas vérifié dans `createContactListInviteLink()` ni `createGroupInviteLink()`** ([app_state.dart L956-L985](lib/theme/app_state.dart#L956-L985)). Un développeur futur pourrait appeler ces méthodes sans passer par le bottom sheet, contournant le consentement.

**Correctif :**
```dart
// Dans PigioAppState
Future<String?> createGroupInviteLink(...) async {
  if (!_contactsConsentGiven) {
    throw Exception('Consentement requis avant de générer un lien');
  }
  ...
}
```

Et ajouter un bouton de révocation dans les paramètres de confidentialité.

---

### RGPD-02 · Identifiants de l'expéditeur transmis en clair dans le lien (Sévérité : HAUTE)

**Fichier :** [supabase/functions/invite-create/index.ts](supabase/functions/invite-create/index.ts#L69)  
**Constat (lié à CRIT-01) :** Le `inviter` dans l'URL est le **handle ou nom réel** de l'utilisateur. Ce lien transite par WhatsApp, des serveurs SMS, est stocké dans l'historique de navigation, et peut être partagé par erreur sur des forums publics.

Cela constitue une violation du **principe de minimisation** (Art. 5(1)(c) RGPD).

**Correctif :** Ne transmettre que le token dans l'URL. Le nom de l'expéditeur est récupéré côté serveur lors de la résolution.

---

### RGPD-03 · Données des utilisateurs non-inscrits stockées localement (Sévérité : MOYENNE)

**Fichier :** [lib/theme/app_state.dart](lib/theme/app_state.dart#L1109-L1150) (`_acceptInviteAsDirectContact()`)  
**Constat :** Quand un lien est accepté, un `ContactProfile` est créé automatiquement avec le nom de l'expéditeur, stocké indéfiniment dans SharedPreferences. Le destinataire n'a pas consenti à stocker les données du contact. Le contact créé n'a pas de mécanisme d'auto-suppression.

**Correctif :** Ajouter un TTL pour les contacts créés par invitation (ex: 30 jours sans interaction → suppression) ou un écran de confirmation avant la création du contact.

---

### RGPD-04 · Le texte de consentement ne mentionne pas WhatsApp/tiers (Sévérité : MOYENNE)

**Fichier :** [lib/shared/widgets/invite_bottom_sheet.dart](lib/shared/widgets/invite_bottom_sheet.dart#L68-L70)
```dart
'Pigio va transmettre uniquement les métadonnées nécessaires à l\'invitation
(contact, groupe, expiration). Aucun message personnel saisi par vous n\'est lu ni stocké.',
```

**Constat :** Le texte ne mentionne pas que le lien sera partagé via WhatsApp ou d'autres plateformes tierces, ni que ces plateformes ont leurs propres politiques de données.

---

## 6. Optimisations de Code

### OPT-01 · `_syncPendingInvitesFromServer()` — appels séquentiels

**Fichier :** [lib/theme/app_state.dart](lib/theme/app_state.dart#L855-L895)  
**Constat :** Chaque invite en attente est vérifiée **séquentiellement** via un appel HTTP. Avec 10 invites en attente, cela représente 10 allers-retours réseau en série.

**Correctif :**
```dart
Future<void> _syncPendingInvitesFromServer() async {
  final pendingOnly = _pendingInvites
      .asMap()
      .entries
      .where((e) => e.value.state == PendingInviteState.pending)
      .toList();

  final results = await Future.wait(
    pendingOnly.map((e) => _invitationService.getTokenStatus(e.value.tokenId).catchError((_) => null)),
  );

  bool changed = false;
  for (int i = 0; i < pendingOnly.length; i++) {
    final status = results[i];
    if (status == null || !status.found) continue;
    final originalIdx = pendingOnly[i].key;
    // ... mise à jour comme avant ...
  }
}
```

Ou mieux : créer un endpoint batch `invite-status-batch` qui accepte plusieurs tokens.

---

### OPT-02 · `_setContactStatus()` — reconstruction complète du modèle

**Fichier :** [lib/theme/app_state.dart](lib/theme/app_state.dart#L745-L770)  
**Constat :** Chaque modification de statut reconstruit manuellement un `ContactProfile` avec 16+ paramètres. Ajouter `copyWith()` (voir ARCH-03).

---

### OPT-03 · `InvitationService` ne ferme jamais le `http.Client`

**Fichier :** [lib/services/invitation_service.dart](lib/services/invitation_service.dart#L131)  
**Constat :** Un `http.Client()` est créé par défaut mais jamais fermé. Avec le client `http` de Dart/IO, cela maintient un pool de connexions ouvert indéfiniment.

**Correctif :**
```dart
class InvitationService {
  ...
  void dispose() => _httpClient.close();
}
```
Et appeler `dispose()` dans `PigioAppState.dispose()`.

---

### OPT-04 · `_isInviteLink()` — logique trop permissive

**Fichier :** [lib/main.dart](lib/main.dart#L99-L106)
```dart
final domainMatch = host.contains('pigio.app') || uri.scheme.toLowerCase() == 'pigio' || hasToken;
final routeMatch = path.contains('invite') || hasToken;
return domainMatch && routeMatch;
```

**Constat :** Si `hasToken` est `true`, alors `domainMatch` ET `routeMatch` sont tous deux `true` — n'importe quelle URL avec un paramètre `token` sera traitée comme un lien d'invitation Pigio, y compris `https://evil.com/page?token=xyz`.

**Correctif :**
```dart
bool _isInviteLink(Uri uri) {
  if (uri.scheme.toLowerCase() == 'pigio' && uri.host.toLowerCase() == 'invite') return true;
  final trustedHosts = {'pigio.app', 'rlghoamehiqlqzjdyxcg.supabase.co'};
  return trustedHosts.contains(uri.host.toLowerCase()) && uri.path.toLowerCase().contains('invite');
}
```

---

## 7. Plan de Tests

### Tests Unitaires (Priorité 1)

| # | Scénario | Fichier cible |
|---|---|---|
| T-01 | Création de token → vérifie que le token retourné est base64url-safe et a 256 bits | `invite-create/index.ts` |
| T-02 | Résolution d'un token valide → `valid: true`, statut passe à `accepted` | `invite-resolve/index.ts` |
| T-03 | Résolution d'un token déjà consommé → `valid: false`, reason `already_consumed` | `invite-resolve/index.ts` |
| T-04 | Résolution d'un token expiré → `valid: false`, statut passe à `expired` | `invite-resolve/index.ts` |
| T-05 | TTL clamping → max 7 jours, min 5 min | `invite-create/index.ts` |
| T-06 | `InvitationService.createToken()` → payload correct, parsing de la réponse | `invitation_service.dart` |
| T-07 | `InvitationService.getTokenStatus()` → gestion 404, parsing | `invitation_service.dart` |
| T-08 | `_resolveIncomingLinkWithFallback()` → NE DOIT PAS accepter en fallback (après fix CRIT-02) | `app_state.dart` |

### Tests d'Intégration (Priorité 2)

| # | Scénario | Couverture |
|---|---|---|
| T-09 | Flux complet : create → open (302) → resolve → contact créé localement | E2E |
| T-10 | Lien expiré : create (TTL=1s) → attendre 2s → resolve → `valid: false` | E2E |
| T-11 | Replay : create → resolve 1x → resolve 2x → `already_consumed` | E2E |
| T-12 | Sync expéditeur : create → resolve (destinataire) → `_syncPendingInvitesFromServer()` détecte l'acceptation | E2E |
| T-13 | Cold start deep link : app fermée → tap sur lien → app s'ouvre → contact ajouté | Mobile E2E |
| T-14 | Background deep link : app en arrière-plan → tap sur lien → navigation vers contacts | Mobile E2E |
| T-15 | Consentement : tenter de partager sans consentement → modale affichée → annuler → aucun lien généré | UI test |

### Tests de Sécurité (Priorité 1)

| # | Scénario |
|---|---|
| T-16 | Forger un lien avec un token inexistant → `valid: false` |
| T-17 | Forger un lien avec un `inviter` contenant du HTML → pas de XSS, validé ou rejeté |
| T-18 | Rate-limiting : envoyer 100 requêtes à `invite-create` en 1 minute → 429 (après implémentation) |
| T-19 | Appel `invite-create` depuis un domaine tiers (CORS) → bloqué (après fix SEC-01) |
| T-20 | Vérifier que `consumed_ip` n'est pas loggée (après fix CRIT-04) |

### Tests de Performance (Priorité 3)

| # | Scénario |
|---|---|
| T-21 | `_syncPendingInvitesFromServer()` avec 50 invites → temps < 3s (après parallélisation OPT-01) |
| T-22 | Deep link parsing → temps < 50ms (profiler le SHA-256 + HTTP sur appareil bas de gamme) |
| T-23 | Rebuilds Provider → vérifier avec `RepaintBoundary` qu'un changement d'invite ne reconstruit pas l'écran des souhaits |

---

## 8. Résumé des Actions par Priorité

| Priorité | ID | Action | Effort |
|---|---|---|---|
| **P0 — Bloquant** | CRIT-01 | Supprimer les identifiants de l'URL d'invitation | 2h |
| **P0 — Bloquant** | CRIT-02 | Supprimer le fallback d'acceptation hors-ligne | 30min |
| **P0 — Bloquant** | CRIT-03 | Ajouter rate-limiting sur `invite-create` | 1h |
| **P0 — Bloquant** | CRIT-04 | Supprimer le stockage d'IP/UA du destinataire | 15min |
| **P1 — Urgent** | RGPD-01 | Vérifier le consentement dans toutes les méthodes de génération | 30min |
| **P1 — Urgent** | SEC-01 | Restreindre CORS aux origines Pigio | 15min |
| **P1 — Urgent** | OPT-04 | Corriger `_isInviteLink()` pour n'accepter que les hôtes de confiance | 15min |
| **P2 — Important** | ARCH-01 | Refactorer `PigioAppState` en sous-états | 4-8h |
| **P2 — Important** | ARCH-02 | Corriger la race condition deep-link / chargement des données | 1h |
| **P2 — Important** | ARCH-03 | Ajouter `copyWith()` aux modèles | 1h |
| **P2 — Important** | SEC-03 | Supprimer le fallback token UUID hors-ligne | 30min |
| **P3 — Amélioration** | OPT-01 | Paralléliser la sync des invites | 1h |
| **P3 — Amélioration** | OPT-03 | Fermer le `http.Client` | 15min |
| **P3 — Amélioration** | ARCH-05 | Factoriser le code commun des Edge Functions | 1h |

---

*Rapport généré par analyse statique de code. Aucun test d'intrusion dynamique n'a été effectué. Les recommandations sont fournies à titre d'orientation technique et ne constituent pas un avis juridique RGPD.*
