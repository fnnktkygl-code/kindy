# Pigio App

Pigio est une app Flutter de gestion de souhaits et de cercles (groupes), avec une logique d’invitation, de confidentialité et de consentement.

## Privacy Matrix (source de vérité)

### Niveaux de confiance

- `family`: accès maximal autorisé par les règles de visibilité.
- `friend`: accès intermédiaire.
- `public_`: accès minimal.

### Données sensibles

| Donnée | Règle de visibilité |
|---|---|
| Date d’anniversaire | Affichée seulement si `hideBirthdate == false` |
| Adresse postale | Masquée si `hideAddress == true` |
| Point relais | Masqué si `hideMondialRelay == true` |
| Tailles (`SizeProfile`) | Filtrées par `visibilityKey` + `TrustLevel` |

### Matrice tailles (`visibilityKey`)

| `visibilityKey` | family | friend | public_ |
|---|---:|---:|---:|
| `full_access` | ✅ | ❌ | ❌ |
| `general_access` | ✅ | ✅ | ❌ |
| `limited_view` | ❌ | ❌ | ❌ |

Implémentation: `getVisibleSizesFor(contactId, viewerTrustLevel: ...)` dans `PigioAppState`.

## Invitation & Consentement

### Statuts contact

`ContactStatus`:

- `local`: contact local non inscrit.
- `invited`: invitation envoyée.
- `pending`: invitation reçue, en attente d’approbation admin (waiting room).
- `joined`: membre approuvé et actif.

### Waiting room

Chaque `CircleGroup` maintient `pendingInviteIds` pour les membres en attente.

- `approvePendingMember(groupId, contactId)` → passe le contact en `joined` + ajoute au cercle.
- `rejectPendingMember(groupId, contactId)` → retire de la file d’attente + remet le contact en `local`.

### Consentement unique

La clé `pigio_contacts_consent_given` stocke le consentement d’invitation.

- Si `false`: modal de consentement affichée avant envoi d’invitation.
- Si `true`: l’envoi ne redemande pas le consentement.

## Deep Links sécurisés

- URL d’invitation: `https://pigio.app/invite/...` ou `pigio://invite...`
- Android App Links: `android/app/src/main/AndroidManifest.xml`
- iOS Universal Links + scheme: `ios/Runner/Info.plist` + `ios/Runner/Runner.entitlements`
- Fichiers web: `.well-known/assetlinks.json` et `.well-known/apple-app-site-association`

## Lancement

```bash
flutter pub get
flutter run
```
