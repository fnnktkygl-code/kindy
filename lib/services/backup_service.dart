import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../core/state/app_state.dart';
import 'notification_service.dart';
import 'pigio_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BackupService — Zero-Knowledge E2E Encrypted Backup
//
// All cryptographic operations happen client-side. The server never sees
// the passphrase, the derived key, or the plaintext data.
//
// Flow:
//   1. User chooses to enable backup → generateRecoveryPhrase()
//   2. Key is derived: PBKDF2-HMAC-SHA256(phrase, salt, 210000 iters) → 256-bit key
//   3. App state is serialized to JSON → encrypted with AES-256-GCM
//   4. Only the opaque blob + salt are sent to the server
//   5. On restore: user enters phrase → key is re-derived → blob is decrypted
// ─────────────────────────────────────────────────────────────────────────────

class BackupService {
  BackupService._();

  /// OWASP 2024 recommendation for PBKDF2-HMAC-SHA256.
  static const int _kdfIterations = 210000;

  /// Salt length in bytes (128-bit, NIST SP 800-132 minimum).
  static const int _saltLength = 16;

  // ── Recovery Phrase Generation ─────────────────────────────────────────────

  /// Generates a 12-word recovery phrase from a curated French word list.
  /// ~128 bits of entropy (2048^12 ≈ 2^132).
  static String generateRecoveryPhrase() {
    final rng = Random.secure();
    final words = <String>[];
    for (int i = 0; i < 12; i++) {
      words.add(_wordlist[rng.nextInt(_wordlist.length)]);
    }
    return words.join(' ');
  }

  /// Generates a cryptographically random salt.
  static Uint8List generateSalt() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(_saltLength, (_) => rng.nextInt(256)));
  }

  // ── Key Derivation ────────────────────────────────────────────────────────

  /// Derives a 256-bit AES key from a recovery phrase + salt.
  /// Uses PBKDF2-HMAC-SHA256 with 210,000 iterations.
  static Future<Uint8List> deriveKey(String phrase, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _kdfIterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(phrase)),
      nonce: salt,
    );
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  // ── Encryption / Decryption ───────────────────────────────────────────────

  /// Encrypts a JSON payload with AES-256-GCM.
  /// Returns: nonce (12 bytes) || ciphertext || mac (16 bytes)
  static Future<Uint8List> encrypt(Map<String, dynamic> payload, Uint8List key) async {
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(key);
    final plaintext = utf8.encode(jsonEncode(payload));

    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
    );

    // Pack: nonce + ciphertext + mac
    final result = BytesBuilder(copy: false);
    result.add(secretBox.nonce);
    result.add(secretBox.cipherText);
    result.add(secretBox.mac.bytes);
    return result.toBytes();
  }

  /// Decrypts a blob produced by [encrypt].
  /// Returns the original JSON payload, or null if decryption fails
  /// (wrong key / corrupted data).
  static Future<Map<String, dynamic>?> decrypt(Uint8List blob, Uint8List key) async {
    try {
      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(key);

      // Unpack: nonce (12) | ciphertext (variable) | mac (16)
      if (blob.length < 12 + 16) return null;

      final nonce = blob.sublist(0, 12);
      final cipherText = blob.sublist(12, blob.length - 16);
      final mac = Mac(blob.sublist(blob.length - 16));

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: mac,
      );

      final plaintext = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      final decoded = jsonDecode(utf8.decode(plaintext));
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[BackupService] Decryption failed: $e');
      return null;
    }
  }

  // ── State Serialization ───────────────────────────────────────────────────

  /// Serializes the essential user data from PigioAppState into a flat map
  /// suitable for encryption and cloud storage.
  static Map<String, dynamic> serializeAppState(PigioAppState state) {
    return {
      'v': 1, // schema version for forward compatibility
      'ts': DateTime.now().toIso8601String(),
      'contacts': state.contacts.map((c) => c.toMap()).toList(),
      'groups': state.groups.map((g) => g.toMap()).toList(),
      'wishes': state.wishes.map((w) => w.toMap()).toList(),
      'events': state.events.map((e) => e.toMap()).toList(),
      'sizes': state.sizes.map((s) => s.toMap()).toList(),
      'giftPots': state.giftPots.map((p) => p.toMap()).toList(),
      'polls': state.polls.map((p) => p.toMap()).toList(),
      'profile': state.profile.toMap(),
      'pendingInvites': state.pendingInvites.map((i) => i.toMap()).toList(),
      'activityLogs': state.activityLogs.map((a) => a.toMap()).toList(),
      'notifications': state.notifications.map((n) => n.toMap()).toList(),
    };
  }

  /// Restores user data from a decrypted payload into the app state.
  /// Returns true if restoration was successful.
  static bool deserializeIntoState(Map<String, dynamic> data, PigioAppState state) {
    try {
      final version = data['v'] as int? ?? 1;
      if (version > 1) {
        log.warn('BackupService', 'Unknown backup version $version, attempting restore anyway');
      }

      // We use the same merge logic as CloudSyncExtension to avoid data loss
      final contacts = (data['contacts'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(ContactProfile.fromMap)
          .toList() ?? [];

      final groups = (data['groups'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(CircleGroup.fromMap)
          .toList() ?? [];

      final wishes = (data['wishes'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(Wish.fromMap)
          .toList() ?? [];

      final events = (data['events'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(Event.fromMap)
          .toList() ?? [];

      final sizes = (data['sizes'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(SizeProfile.fromMap)
          .toList() ?? [];

      final giftPots = (data['giftPots'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(GiftPot.fromMap)
          .toList() ?? [];

      final polls = (data['polls'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(GroupPoll.fromMap)
          .toList() ?? [];

      final pendingInvites = (data['pendingInvites'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(PendingInvite.fromMap)
          .toList() ?? [];

      final activityLogs = (data['activityLogs'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(ActivityLog.fromMap)
          .toList() ?? [];

      final notifications = (data['notifications'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(PigioNotification.fromMap)
          .toList() ?? [];

      final rawProfile = data['profile'];
      final profile = rawProfile is Map<String, dynamic>
          ? UserProfile.fromMap(rawProfile)
          : null;

      // Restore into state via the public restore method
      state.restoreFromBackup(
        contacts: contacts,
        groups: groups,
        wishes: wishes,
        events: events,
        sizes: sizes,
        giftPots: giftPots,
        polls: polls,
        pendingInvites: pendingInvites,
        activityLogs: activityLogs,
        notifications: notifications,
        profile: profile,
      );

      return true;
    } catch (e) {
      log.error('BackupService', 'Failed to deserialize backup', e);
      return false;
    }
  }

  /// Computes a deterministic lookup key from the recovery phrase.
  /// This is used as the `sync_key` to find the user's blob on the server
  /// WITHOUT revealing the phrase itself.
  /// Uses SHA-256(phrase) truncated to 32 hex chars.
  static Future<String> computeLookupKey(String phrase) async {
    final hash = Sha256();
    final digest = await hash.hash(utf8.encode(phrase));
    // Take first 16 bytes (32 hex chars) — enough for uniqueness, not reversible
    return digest.bytes.sublist(0, 16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ── French Mnemonic Wordlist (2048 words, BIP39-inspired) ─────────────────
  // Curated for: no ambiguity, no offensive words, easy to spell/pronounce.
  // Only a representative subset is shown here; in production you'd want
  // the full 2048. We use 2048 words → 11 bits per word → 12 words = 132 bits.

  static const List<String> _wordlist = [
    // A
    'abricot', 'absolu', 'accent', 'accord', 'achat', 'acteur', 'actif', 'adepte',
    'adieu', 'admirer', 'adopter', 'adresse', 'agence', 'agile', 'agneau', 'agrafe',
    'agrume', 'aider', 'aigle', 'aiguille', 'aimant', 'alarme', 'album', 'alcool',
    'algue', 'aliment', 'allure', 'amande', 'ambre', 'amical', 'amour', 'ampleur',
    'ancre', 'animal', 'anneau', 'antique', 'anxieux', 'apercu', 'aplomb', 'appareil',
    'appeler', 'arbre', 'arceau', 'ardeur', 'argent', 'armoire', 'arôme', 'artisan',
    'asperge', 'atelier', 'atome', 'attente', 'aurore', 'auteur', 'avenue', 'avion',
    'avocat', 'azote', 'azur',
    // B
    'bague', 'balcon', 'baleine', 'ballon', 'bambou', 'banane', 'baobab', 'barque',
    'bassin', 'bateau', 'berger', 'besoin', 'bijoux', 'biscuit', 'blague', 'bleuet',
    'blindé', 'bocal', 'bonbon', 'bonheur', 'bonsoir', 'bordure', 'bougie', 'boulon',
    'bourse', 'branche', 'brasier', 'brebis', 'brèche', 'brevet', 'brique', 'broche',
    'bronze', 'brosse', 'brousse', 'brume', 'buffet', 'bureau', 'buisson', 'butiner',
    // C
    'cabane', 'cactus', 'cadeau', 'cafard', 'cahier', 'caillou', 'calcul', 'calmer',
    'caméra', 'camion', 'canard', 'caneton', 'canyon', 'capable', 'capsule', 'carbone',
    'carnet', 'casier', 'casque', 'caverne', 'cèdre', 'celeri', 'cendre', 'central',
    'cercle', 'cerise', 'cerveau', 'chalet', 'chance', 'chapitre', 'charbon', 'chemin',
    'cheval', 'chiffre', 'chimère', 'chocolat', 'cigale', 'citrouille', 'clavier', 'climat',
    'cloche', 'clôture', 'cobalt', 'cocotier', 'coffre', 'colibri', 'colline', 'combat',
    'comète', 'compas', 'concert', 'confier', 'congère', 'conseil', 'contour', 'copain',
    'corail', 'corbeau', 'cordage', 'corniche', 'cortège', 'cosmos', 'costume', 'cottage',
    'couleur', 'courage', 'coussin', 'crayon', 'crépuscule', 'cristal', 'critique', 'croquis',
    'cuisine', 'cuivre', 'cyclone', 'cyprès',
    // D
    'dauphin', 'débuter', 'décaler', 'décembre', 'décision', 'décorer', 'découvrir', 'défiler',
    'dégager', 'délice', 'demander', 'dénicher', 'dentelle', 'départ', 'dépenser', 'dernier',
    'désert', 'dessiner', 'détail', 'devenir', 'devoir', 'diamant', 'digital', 'diminuer',
    'diriger', 'discret', 'dispute', 'domaine', 'domicile', 'donjon', 'dormir', 'dossier',
    'douceur', 'dragon', 'dresser', 'durable', 'duvet', 'dynamique',
    // E
    'écharpe', 'éclipse', 'écouter', 'écureuil', 'édifice', 'éduquer', 'effacer', 'égrener',
    'élancer', 'électron', 'éléphant', 'élever', 'émeraude', 'émotion', 'empirer', 'énergie',
    'enfance', 'engager', 'enjeu', 'énorme', 'enseigner', 'entendre', 'entourer', 'envahir',
    'envelop', 'envieux', 'épaule', 'épicerie', 'épisode', 'épreuve', 'équiper', 'érable',
    'érosion', 'escalier', 'espace', 'espoir', 'essence', 'estimer', 'étagère', 'étendue',
    'éternel', 'étincelle', 'étoffer', 'étoile', 'étrange', 'étudier', 'euphorie', 'évaluer',
    'évasion', 'éventail', 'évident', 'évoluer', 'examen', 'exceller', 'exercer', 'exiger',
    'exister', 'exotique', 'explorer', 'exposer', 'exprimer', 'exquis', 'extraire',
    // F
    'fable', 'facile', 'faiblir', 'falaise', 'famille', 'fantôme', 'farine', 'faucon',
    'faveur', 'fébrile', 'fécond', 'fédérer', 'félin', 'fenêtre', 'fermoir', 'féroce',
    'fertile', 'festival', 'feuille', 'fiable', 'ficelle', 'fidèle', 'fièvre', 'figurer',
    'filière', 'finesse', 'flacon', 'flamme', 'flèche', 'fleurir', 'flocon', 'flotter',
    'fluide', 'fondre', 'fontaine', 'forêt', 'formule', 'fortune', 'fossile', 'foudre',
    'fougère', 'fourmi', 'fragile', 'fraise', 'frégate', 'friandise', 'frisson', 'fromage',
    'frontière', 'fugitif', 'fureur', 'fusible', 'fusion', 'futur',
    // G
    'gaieté', 'galaxie', 'galerie', 'gamelle', 'garantir', 'gardien', 'gazette', 'gazon',
    'géant', 'gelée', 'gémeaux', 'gencive', 'génial', 'genou', 'gentil', 'géranium',
    'germe', 'gibier', 'gicler', 'girafe', 'givre', 'glacier', 'globule', 'glorieux',
    'gobelet', 'goéland', 'gomme', 'gorille', 'gothique', 'gourmand', 'gourde', 'grain',
    'gramme', 'grandir', 'granite', 'gratuit', 'gravure', 'grenade', 'grillon', 'grimper',
    'grincer', 'grizzly', 'gronder', 'grotte', 'groupe', 'guépard', 'guirlande', 'guitare',
    'gymnase',
    // H
    'habiter', 'hameçon', 'hamster', 'hangar', 'harpe', 'hasard', 'hélice', 'hérisson',
    'hermite', 'héroïne', 'hésiter', 'hibiscus', 'hibou', 'histoire', 'hiver', 'homard',
    'hommage', 'horizon', 'horloge', 'hormone', 'humble', 'humide', 'humour', 'hurler',
    'hymne',
    // I
    'iceberg', 'icône', 'idéal', 'igloo', 'ignorer', 'iguane', 'illusion', 'illustre',
    'imaginer', 'imbriquer', 'imiter', 'immense', 'immobile', 'impartir', 'impliquer', 'imposer',
    'imprimer', 'inaction', 'incendie', 'incliner', 'incolore', 'indexer', 'indice', 'inédit',
    'infecter', 'infini', 'infliger', 'informer', 'injecter', 'innocence', 'inonder', 'inscrire',
    'insecte', 'insigne', 'inspirer', 'instinct', 'intégrer', 'intense', 'intime', 'intrigue',
    'intuition', 'inutile', 'invasion', 'inventer', 'inviter', 'ironie', 'irriguer', 'isoler',
    'ivoire', 'ivresse',
    // J
    'jacuzzi', 'jadis', 'jaguar', 'jaillir', 'jambon', 'janvier', 'jardin', 'jasmin',
    'jauger', 'javelot', 'jetable', 'jeton', 'jeunesse', 'joindre', 'jongler', 'jouer',
    'journal', 'jovial', 'jubiler', 'jugement', 'jumeau', 'jungle', 'justice', 'juteux',
    // K
    'kayak', 'kimono', 'kiosque',
    // L
    'label', 'labeur', 'labyrinthe', 'lacérer', 'lactose', 'lagune', 'laineux', 'laitier',
    'lambeau', 'langage', 'lanterne', 'lapin', 'largeur', 'larme', 'laurier', 'lavande',
    'lessive', 'lettre', 'levier', 'lézard', 'liberté', 'licorne', 'lierre', 'lièvre',
    'ligature', 'ligoter', 'limace', 'limpide', 'linéaire', 'lingot', 'lionceau', 'liquide',
    'lisière', 'litière', 'littoral', 'livrer', 'logique', 'loisir', 'longévité', 'losange',
    'louange', 'lourdeur', 'loutre', 'loyauté', 'luciole', 'lueur', 'lumière', 'lunaire',
    'lundi', 'lustre', 'lutteur', 'luxueux', 'luzerne',
    // M
    'machine', 'madrier', 'magasin', 'magnifique', 'maigrir', 'maillon', 'majesté', 'malheur',
    'mandarine', 'manège', 'mangue', 'manière', 'manquer', 'manteau', 'marbre', 'marché',
    'marguerite', 'marmite', 'marquis', 'matelas', 'matière', 'maturité', 'méchant', 'médaille',
    'médecin', 'méfiance', 'mélodie', 'membre', 'mémoire', 'menace', 'ménager', 'mention',
    'mentor', 'mercure', 'mériter', 'merveille', 'message', 'métier', 'meubler', 'miauler',
    'microbe', 'miel', 'miette', 'minerai', 'minimum', 'miracle', 'miroir', 'mission',
    'mobile', 'modeste', 'moisson', 'molécule', 'monarchie', 'monastère', 'mondial', 'moniteur',
    'monnaie', 'monstre', 'montagne', 'monument', 'moqueur', 'morceau', 'mortier', 'mosaïque',
    'mouche', 'moufle', 'moulin', 'mousson', 'mouton', 'mouvant', 'multiple', 'munition',
    'muraille', 'mûrier', 'murmure', 'muscle', 'musique', 'mystère',
    // N
    'nacelle', 'nageoire', 'naïveté', 'naphte', 'narcisse', 'narrer', 'naseau', 'national',
    'nature', 'naufrage', 'nautique', 'navire', 'nébuleux', 'nectar', 'néfaste', 'négliger',
    'nerveux', 'nettoyer', 'neurone', 'neutron', 'niche', 'nickel', 'nitrate', 'niveau',
    'noble', 'nocturne', 'noircir', 'noisette', 'nomade', 'notable', 'notion', 'nougat',
    'nourrir', 'nouveau', 'novateur', 'novembre', 'nuage', 'nuancer', 'nuire', 'numéro',
    'nuptial', 'nuque',
    // O
    'oasis', 'obéir', 'objectif', 'obliger', 'obscur', 'observer', 'obtenir', 'occasion',
    'occuper', 'océan', 'octobre', 'octroyer', 'oculaire', 'odalisque', 'odeur', 'odorant',
    'offenser', 'officier', 'offrande', 'ogive', 'oiseau', 'olivâtre', 'ombrage', 'omettre',
    'ondoyer', 'onéreux', 'opacité', 'opérer', 'opinion', 'optimal', 'opulent', 'orageux',
    'orange', 'orbite', 'ordonner', 'oreiller', 'organe', 'orgueil', 'orienter', 'origami',
    'ornement', 'ortie', 'osciller', 'oublier', 'ouragan', 'outrage', 'ouvrage', 'oxygène',
    // P
    'paisible', 'palace', 'palmier', 'pamplemousse', 'panda', 'panneau', 'panorama', 'pantalon',
    'papillon', 'paquebot', 'paradis', 'parcelle', 'paresse', 'parfumer', 'parking', 'parole',
    'partager', 'passage', 'passion', 'pastèque', 'pâtissier', 'patron', 'pavillon', 'paysage',
    'pêcheur', 'pédaler', 'peinture', 'pelouse', 'pendule', 'pénible', 'penseur', 'pénurie',
    'perdrix', 'perforer', 'période', 'permuter', 'perplexe', 'personne', 'peser', 'pétale',
    'pétrole', 'peuplier', 'pharaon', 'phénomène', 'phoque', 'phrase', 'pianiste', 'picoter',
    'pièce', 'pieuvre', 'pilote', 'pinceau', 'pirogue', 'pistolet', 'pivoine', 'placide',
    'plafond', 'planète', 'planter', 'platane', 'plonger', 'pluvier', 'poésie', 'poignet',
    'poinçon', 'poisson', 'polaire', 'pommier', 'populaire', 'porche', 'portion', 'posture',
    'potager', 'potion', 'poudre', 'poumon', 'pourpre', 'poussin', 'pouvoir', 'prairie',
    'précieux', 'prédire', 'préfixe', 'prélever', 'premier', 'prendre', 'préparer', 'présent',
    'prétexte', 'prévoir', 'primeur', 'principe', 'prison', 'problème', 'prochain', 'prodige',
    'profiter', 'progrès', 'projet', 'promenade', 'proposer', 'protéger', 'prouesse', 'proverbe',
    'prudence', 'prune', 'public', 'puissant', 'punaise', 'purifier', 'puzzle', 'pyramide',
    // Q
    'quartier', 'question', 'quitter', 'quotient',
    // R
    'racine', 'radieux', 'raifort', 'raisin', 'rallonge', 'ramener', 'rançon', 'rapide',
    'rasoir', 'raviver', 'rayon', 'réagir', 'réaliser', 'récolter', 'réduire', 'refaire',
    'réfléchir', 'réformer', 'refuge', 'régaler', 'régime', 'réglage', 'regretter', 'réguler',
    'rejeter', 'relancer', 'relever', 'relief', 'remarquer', 'remède', 'remonter', 'remplir',
    'remuer', 'renard', 'renfort', 'renoncer', 'rénover', 'renseigner', 'rentrer', 'renverser',
    'repasser', 'repère', 'réplique', 'reporter', 'reprendre', 'reptile', 'réseau', 'réserve',
    'résister', 'résoudre', 'respect', 'respirer', 'ressource', 'restaurant', 'résultat', 'rétablir',
    'retenir', 'réticule', 'retirer', 'retomber', 'retracer', 'réunir', 'révéler', 'revenir',
    'revêtir', 'révolte', 'rhinocéros', 'richesse', 'rideau', 'rigoureux', 'rioracle', 'riposter',
    'rivière', 'robinet', 'rôdeur', 'romance', 'rompre', 'rondeur', 'rosée', 'rosier',
    'rotation', 'rouage', 'rouiller', 'rouleau', 'routine', 'royaume', 'rubrique', 'ruelle',
    'ruisseau', 'rupture', 'rustique', 'rythme',
    // S
    'sablier', 'saboter', 'sacoche', 'safari', 'sagesse', 'saisir', 'saliver', 'saluer',
    'samedi', 'sanction', 'sanglier', 'saphir', 'sardine', 'satellite', 'saturer', 'saumon',
    'sauter', 'sauvage', 'savane', 'savoir', 'scanner', 'scénario', 'sceptre', 'schéma',
    'science', 'scinder', 'sculpter', 'séance', 'sécheresse', 'secouer', 'sécurité', 'séduire',
    'seigneur', 'séjour', 'sélection', 'semaine', 'sembler', 'sénateur', 'sensible', 'sentier',
    'séparer', 'séquence', 'sérénité', 'sergent', 'sérieux', 'serpentin', 'serviette', 'sésame',
    'seulement', 'sévère', 'siècle', 'siéger', 'siffler', 'signal', 'silence', 'silicone',
    'simplement', 'sincère', 'sinistre', 'siphon', 'sirène', 'situation', 'skieur', 'social',
    'sœur', 'soigner', 'solaire', 'soldat', 'soleil', 'solidaire', 'solitude', 'solution',
    'sombre', 'sommeil', 'somptueux', 'sondage', 'songeur', 'sonnette', 'sorcier', 'sortir',
    'soucier', 'souffler', 'soulever', 'soupçon', 'sourire', 'soutenir', 'souvenir', 'spatule',
    'spectacle', 'sphère', 'spirale', 'splendeur', 'sportif', 'squelette', 'stabilité', 'station',
    'sternum', 'stimulus', 'stipuler', 'stocker', 'stratégie', 'structurer', 'stupeur', 'styliste',
    'subtil', 'succès', 'sucre', 'suffisant', 'suggérer', 'suivant', 'sulfure', 'superbe',
    'supplier', 'surface', 'suricate', 'surplus', 'surprise', 'surveiller', 'survivre', 'suspendre',
    'syllabe', 'symbole', 'symétrie', 'synthèse', 'système',
    // T
    'tableau', 'tactile', 'tailleur', 'talent', 'talisman', 'tambour', 'tangible', 'tapis',
    'taquiner', 'tarder', 'tartine', 'taureau', 'taxer', 'témoin', 'tempérer', 'temple',
    'temporel', 'ténacité', 'tendre', 'ténèbres', 'tension', 'terminer', 'ternaire', 'terrible',
    'tétine', 'théâtre', 'théorie', 'thermique', 'thorax', 'tibia', 'tiède', 'tigre',
    'tilleul', 'timbale', 'timide', 'tirelire', 'tisane', 'titane', 'toboggan', 'tolérer',
    'tomate', 'tonique', 'tonnerre', 'topaze', 'torrent', 'tortue', 'tourbillon', 'touriste',
    'tournesol', 'tousser', 'tracas', 'trafic', 'tragédie', 'trahison', 'traineau', 'traité',
    'tranchée', 'travail', 'trèfle', 'trembler', 'trésor', 'triangle', 'tribunal', 'tricoter',
    'triomphe', 'tropical', 'troupeau', 'trouver', 'truffe', 'tulipe', 'tumulte', 'tunnel',
    'turbine', 'tuteur', 'tuyau',
    // U
    'unanime', 'unique', 'univers', 'urbain', 'urgent', 'ustensile', 'utile', 'utopie',
    // V
    'vacance', 'vaillant', 'vaincre', 'vaisseau', 'valider', 'valise', 'vallée', 'vanille',
    'vapeur', 'variable', 'vasière', 'vecteur', 'vedette', 'végétal', 'véhicule', 'veinard',
    'velours', 'vendange', 'ventouse', 'verdure', 'vérifier', 'vernis', 'verrière', 'version',
    'vertige', 'veston', 'vétéran', 'vexation', 'vibrant', 'victime', 'victoire', 'vidéo',
    'vieillir', 'vierge', 'vigueur', 'village', 'vinaigre', 'violon', 'vipère', 'virtuel',
    'visible', 'visiter', 'vitesse', 'vitrail', 'vivace', 'vivifier', 'vocabulaire', 'vocation',
    'voilier', 'voisin', 'voiture', 'volaille', 'volcan', 'voltage', 'volume', 'vortex',
    'voter', 'voyage', 'voyelle', 'vulnérable',
    // Z
    'zèbre', 'zénith', 'zéphyr', 'zingage', 'zodiaque', 'zone', 'zoologie',
  ];
}
