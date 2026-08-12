# EXPIRA — Blueprint produit & technique

> « Expira vous aide à savoir quoi manger avant que ça expire. »

Document de conception validé **avant** développement. Il répond aux 12 livrables
demandés. Chaque décision est justifiée par un des 4 critères : **simplicité,
utilité réelle, rétention, monétisation**.

---

## 0. La thèse produit (à lire en premier)

Il existe des dizaines d'apps de gestion de frigo. Elles meurent toutes de la
même façon : **le coût de saisie est supérieur à la valeur perçue**, et au bout
de 10 jours le stock affiché ne correspond plus au frigo réel. L'utilisateur
ouvre l'app, voit des données fausses, et ne revient plus.

EXPIRA n'a donc que **deux vrais problèmes à résoudre**, et tout le reste en
découle :

1. **Le coût d'entrée** — ajouter un aliment doit coûter < 5 secondes.
   → scan code-barres, OCR de date, estimation automatique, valeurs par défaut
   intelligentes. On ne demande jamais à l'utilisateur une information qu'on
   peut déduire.
2. **La dérive du stock** (*stock drift*) — le stock doit rester vrai sans
   effort. → sortie d'un aliment en un swipe, digest quotidien qui sert aussi de
   « check-in », auto-archivage des périmés avec un tap, aucune culpabilisation.

La boucle est : **SCANNER → ENREGISTRER → PRÉVENIR → SAUVER**.
Une fonctionnalité qui ne sert pas cette boucle n'entre pas dans le produit.

**Le moment « aha »** que l'onboarding doit atteindre en < 30 s : *le premier
aliment apparaît dans le frigo avec une date, sans que j'aie tapé cette date.*
C'est ce moment qu'on optimise, pas le nombre de fonctionnalités.

---

## 1. Architecture complète de l'application

### 1.1 Couches produit

```
┌──────────────────────────────────────────────────────────────┐
│  ENTRÉE (réduire le travail utilisateur au minimum)          │
│  Scan code-barres · OCR date · Saisie manuelle assistée      │
│  V1.1 : Scan de ticket                                        │
└───────────────────────────┬──────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  STOCK (la vérité : mon frigo maintenant)                    │
│  Aliments · Dates (confirmée / estimée) · Lieu de stockage   │
│  Sortie en 1 geste : Consommé / Jeté                         │
└───────────────────────────┬──────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  INTELLIGENCE (le cerveau, 100 % on-device en V1)            │
│  Urgence · Estimation de péremption · Matching de recettes   │
│  Plan de sauvetage · Estimation d'économies                  │
└───────────────────────────┬──────────────────────────────────┘
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  RETOUR VERS L'UTILISATEUR (la raison de revenir)            │
│  Digest quotidien · Recettes anti-gaspi · Sauver mes aliments│
│  Série sans gaspillage · Bilan du mois                       │
└──────────────────────────────────────────────────────────────┘
```

### 1.2 Principe d'architecture technique : **local-first, on-device-first**

- **Zéro backend en V1.** Toute l'intelligence (OCR, estimation, recettes, plan,
  notifications) tourne sur l'appareil. Conséquences : app instantanée, marche
  hors-ligne, coût d'infrastructure ≈ 0 €, aucune donnée alimentaire ne quitte
  le téléphone.
- Une **seule** dépendance réseau : la base produits par code-barres
  (Open Food Facts), en lecture, avec cache local et repli manuel. Si le réseau
  tombe, l'app reste 100 % fonctionnelle.
- La synchronisation (V1.2) se fera via **CloudKit** (compte iCloud de
  l'utilisateur) : pas de serveur à opérer, pas de données santé/alimentaires
  stockées chez nous, conformité RGPD triviale.

C'est une décision de fondateur autant que d'ingénieur : elle permet de lancer,
d'itérer et de rester rentable sans lever de fonds.

---

## 2. Parcours utilisateur complet

### 2.1 Acquisition → activation (objectif : < 30 s jusqu'au 1er aliment)

```
Install
  └─ O1 Bienvenue                       (1 tap)
     └─ O2 « Combien jetez-vous ? »      (1 tap)  → personnalise les € plus tard
        └─ O3 Promesse produit           (1 tap)
           └─ O4 Notifications           (1 tap, expliqué avant le prompt iOS)
              └─ F1 « Ajoutez vos premiers aliments »
                 ├─ [Scanner un produit] → caméra → produit reconnu
                 │     → confirmation pré-remplie → Enregistrer   ✅ AHA
                 ├─ [Ajouter manuellement] → formulaire pré-rempli
                 └─ [Scanner mon ticket]  → (Premium) → paywall contextuel
```

La permission **caméra** n'est PAS demandée à l'onboarding : elle est demandée
au moment exact du premier scan, quand l'intention est maximale. Taux
d'acceptation nettement supérieur, et c'est plus honnête.

### 2.2 Boucle quotidienne (le cœur de la rétention)

```
09h00 — Notification digest
  « 🍗 3 aliments à consommer dans les 2 jours »
        │
        ▼
  Ouverture app → Frigo, section URGENT en haut
        │
        ├─ swipe → « Consommé »        (stock reste vrai, +1 aliment sauvé)
        ├─ tap « Sauver mes aliments » → plan sur 3 jours
        └─ tap recette → « J'ai cuisiné ça » → sort 3 aliments d'un coup
```

### 2.3 Boucle hebdomadaire (courses)

```
Retour des courses → Scanner (mode rafale : on scanne 8 produits d'affilée)
   → un seul écran de confirmation groupée → Enregistrer
V1.1 : photo du ticket → liste pré-remplie
```

### 2.4 Parcours de monétisation

```
Déclencheurs de paywall (contextuels, jamais bloquants au lancement) :
  · tentative d'ajout du 16e aliment
  · tap sur « Scanner la date » (OCR)
  · tap sur « Sauver mes aliments » (après 1 essai gratuit offert)
  · tap sur « Scanner mon ticket »
  · onglet Statistiques du mois
→ PW1 Paywall : valeur + prix + fermeture évidente (croix en haut à gauche,
  taille de cible ≥ 44 pt, aucun délai, aucun faux compte à rebours).
```

---

## 3. Liste de tous les écrans (V1)

| # | Écran | Rôle | V1 |
|---|-------|------|----|
| O1 | Bienvenue | Promesse | ✅ |
| O2 | Estimation du gaspillage | Personnalisation + engagement | ✅ |
| O3 | Promesse produit | Compréhension | ✅ |
| O4 | Permissions expliquées | Notifications | ✅ |
| F1 | Premiers aliments | Activation | ✅ |
| H1 | **Frigo** (accueil) | Stock trié par urgence | ✅ |
| H2 | Détail aliment | Voir / corriger / sortir | ✅ |
| H3 | Formulaire aliment | Ajout & édition | ✅ |
| S1 | Scanner code-barres | Entrée rapide | ✅ |
| S2 | Confirmation produit | Vérification avant sauvegarde | ✅ |
| S3 | Scanner la date (OCR) | Date réelle > estimation | ✅ |
| S4 | Produit inconnu | Repli manuel pré-rempli | ✅ |
| R1 | Recettes anti-gaspi | Valeur récurrente | ✅ |
| R2 | Détail recette | Exécution + sortie de stock | ✅ |
| RS1 | **Sauver mes aliments** | Plan sur 3 jours | ✅ |
| P1 | Profil / Bilan | Série, économies, réglages | ✅ |
| P2 | Réglages notifications | Contrôle utilisateur | ✅ |
| PW1 | Paywall | Monétisation | ✅ |
| — | Scan de ticket | Entrée en masse | V1.1 |
| — | Liste de courses | Boucle course | V1.1 |
| — | Frigo partagé (famille) | Rétention foyer | V1.2 |
| — | Statistiques détaillées | Preuve de valeur | V1.2 |

**3 onglets seulement en V1 : Frigo · Recettes · Profil.** Un 4e onglet
(Liste de courses) arrivera en V1.1. On n'affiche jamais un onglet vide.

---

## 4. Fonctionnement de chaque écran

### O1 — Bienvenue
Logo EXPIRA, titre « Ne laissez plus votre nourriture expirer. », un seul CTA
« Commencer ». Aucun texte légal, aucun compte demandé. **Pas de création de
compte en V1** : l'app marche immédiatement, les données sont locales.

### O2 — « Combien jetez-vous chaque mois ? »
4 choix rapides : `~10 €` / `~30 €` / `~60 €` / `Je ne sais pas`.
Sert à (a) faire prendre conscience du problème, (b) calibrer l'estimation
d'économies affichée plus tard. Stocké dans `wasteBaselineEUR`. Modifiable dans
les réglages. Aucune obligation de répondre.

### O3 — Promesse produit
« Expira transforme votre frigo en liste intelligente. » + 3 puces :
*Scannez en 3 secondes · On vous prévient au bon moment · On vous dit quoi
cuisiner.* Illustration légère, pas de carrousel de 6 écrans.

### O4 — Permissions
Écran d'explication **avant** le prompt système : « Sans notification, Expira ne
peut pas vous prévenir à temps. Une notification par jour maximum, à l'heure de
votre choix. » Boutons : « Activer » / « Plus tard » (jamais grisé, jamais
piégé). Si refus → l'app fonctionne, un bandeau discret propose de réactiver.

### F1 — Premiers aliments
Trois cartes : **Scanner un produit** (mise en avant), **Ajouter manuellement**,
**Scanner mon ticket** (badge Premium). Lien « Je le ferai plus tard » visible.

### H1 — Frigo (écran principal)
- En-tête compact : série en cours (`🔥 7 jours sans gaspillage`) + nombre
  d'aliments à consommer.
- Bouton proéminent **« Sauver mes aliments »** (visible sans scroll).
- Sections dans cet ordre, masquées si vides :
  `Expiré` · `Aujourd'hui` · `Demain` · `Cette semaine` · `Plus tard`.
- Chaque ligne : emoji catégorie, nom, marque, **badge d'urgence textuel**
  (`Aujourd'hui`, `Dans 3 jours`, `Périmé depuis 2 jours`) + icône + couleur.
  L'urgence n'est **jamais** portée par la couleur seule (accessibilité).
- Le badge indique `· estimée` quand la date n'est pas confirmée.
- Swipe gauche → `Consommé` (vert, haptic succès) ; swipe droite → `Jeté`.
- Bouton flottant `+` → feuille : Scanner / Manuel / Ticket.
- État vide : illustration + « Votre frigo est vide » + CTA scanner.

### H2 — Détail aliment
Photo produit (si dispo), nom, marque, catégorie, lieu de stockage, quantité.
Bloc date : grande date + source (`Date sur l'emballage` / `Date estimée`).
Si estimée : bandeau « Estimation basée sur la catégorie et le mode de
conservation. Vérifiez l'emballage. » + bouton **Scanner la date**.
Actions : `Consommé` · `Jeté` · `Modifier` · (V1.1 `Ajouter à ma liste`).

### H3 — Formulaire aliment
Champs : nom (obligatoire, focus auto), catégorie (grille d'emojis, non un
picker), lieu de stockage (segmenté Frigo/Congélateur/Placard), quantité,
date de péremption (pré-remplie par estimation, éditable). **Un seul champ est
réellement obligatoire : le nom.** Tout le reste a un défaut intelligent.

### S1 — Scanner code-barres
`DataScannerViewController` plein écran, cadre de visée, retour haptique à la
détection. **Mode rafale** : chaque produit reconnu s'empile en bas ; on peut
scanner 10 produits sans quitter l'écran. Bouton « Terminer (n) ».
Repli si l'appareil ne supporte pas le scan → formulaire manuel.

### S2 — Confirmation produit
Feuille pré-remplie : photo, nom, marque, catégorie déduite, lieu de stockage
déduit, **date estimée** clairement étiquetée. Deux boutons :
`Scanner la date` (priorité à la date réelle) et **`Enregistrer`**.
Un seul tap suffit pour enregistrer — la confirmation n'est pas un formulaire.

### S3 — Scanner la date (OCR)
Caméra en mode texte. Reconnaît les formats FR/EU (`12/03/26`, `12 MARS 2026`,
`À consommer avant le 12.03.2026`, `DLC 12-03-26`, `DLUO`, `EXP`). La date
détectée s'affiche en surimpression pour confirmation. Si rien n'est lu en
8 s : « Date illisible — saisissez-la » + roue de sélection.
Une date lue sur l'emballage écrase **toujours** une estimation.

### S4 — Produit inconnu
Le code-barres n'est pas dans la base → formulaire pré-rempli avec le
code-barres mémorisé localement. La prochaine fois que ce code est scanné, le
nom saisi est proposé automatiquement (mémoire locale, sans serveur).

### R1 — Recettes anti-gaspi
Haut d'écran : bandeau **« À utiliser en priorité »** avec les aliments les plus
urgents (puces tapables). En dessous, 3 recettes classées par score
anti-gaspillage. Carte recette : titre, temps, difficulté, `4/5 ingrédients
disponibles`, et surtout **« Sauve 3 aliments »** — c'est le vrai argument.

### R2 — Détail recette
Temps · difficulté · portions. Deux listes explicites : **Vous avez** /
**Il vous manque**. Étapes numérotées. Bouton final **« J'ai cuisiné ça »** →
feuille de confirmation qui marque les aliments utilisés comme *consommés*
(cases décochables). C'est le geste qui maintient le stock vrai.

### RS1 — Sauver mes aliments
Analyse du stock → plan sur 3 jours :
```
CE SOIR      🍗 Poulet + riz          → sauve 2 aliments
DEMAIN       🥗 Salade + tomates      → sauve 2 aliments
APRÈS-DEMAIN 🧀 Fromage + pâtes       → sauve 1 aliment
```
Chaque ligne renvoie à la recette. En bas : « Ce plan sauve 5 aliments,
≈ 14 € ». Bouton « Nouveau plan » si l'utilisateur n'aime pas les propositions.

### P1 — Profil / Bilan
Carte « Ce mois-ci » : `🥦 18 aliments sauvés` · `💰 34 € économisés (estimé)` ·
`🗑️ 3 aliments jetés`. Série en cours. Objectif de la semaine
(« 0 aliment gaspillé »). Entrées : Premium, Notifications, Confidentialité,
Estimation de gaspillage, Aide. Les chiffres incertains portent le mot
**estimé** — jamais de faux précis.

### P2 — Réglages notifications
Interrupteur maître · heure du digest · seuil d'alerte (1/2/3 jours) ·
« Alerte le jour même » · « Résumé du dimanche ». Maximum **1 notification par
jour** par défaut, affiché noir sur blanc.

### PW1 — Paywall
Titre orienté bénéfice, 5 lignes de valeur maximum, deux offres
(**Annuel mis en avant avec l'économie en %**, Mensuel), essai gratuit indiqué
sans ambiguïté avec la date de fin et le prix après essai, `Restaurer mes
achats`, CGU/Confidentialité, **croix de fermeture immédiate en haut à gauche**.
Aucun compte à rebours, aucune offre « qui expire », aucun bouton « Non merci,
je préfère gaspiller ». Ce sont des dark patterns : interdits.

---

## 5. Architecture technique

### 5.1 Stack

| Domaine | Choix | Pourquoi |
|---|---|---|
| UI | SwiftUI (iOS 17+) | Natif, rapide à itérer, dark mode et Dynamic Type gratuits |
| État | `@Observable` + stores injectés | Simple, testable, pas de dépendance externe |
| Persistance | SwiftData | Natif, migration vers CloudKit facile |
| Code-barres | VisionKit `DataScannerViewController` | Le meilleur scanner iOS, gratuit |
| OCR | Vision (`VNRecognizeTextRequest`) via VisionKit | On-device, hors-ligne, privé |
| Base produits | Open Food Facts (REST, lecture) | Gratuite, ouverte, très bonne couverture FR |
| Notifications | `UNUserNotificationCenter`, locales | Aucun serveur, aucun token, fiable hors-ligne |
| Abonnement | StoreKit 2 | API moderne, vérification native |
| Analytics | Protocole maison + implémentation branchable | On ne s'enferme pas dans un SDK |
| Sync (V1.2) | SwiftData + CloudKit | Pas de backend, données chez l'utilisateur |

**Aucune dépendance tierce en V1.** Chaque SDK ajouté est un risque de
performance, de vie privée et de refus App Store.

### 5.2 Modularisation (package local `ExpiraKit`)

```
ExpiraKit/
├── ExpiraCore           Foundation seul. Modèles de domaine + moteurs.
│                        100 % testable, zéro UI, zéro I/O.
├── ExpiraDesignSystem   Couleurs, typo, espacements, composants réutilisables.
├── ExpiraData           SwiftData (@Model) + mapping ↔ domaine + stores.
├── ExpiraCatalog        Données embarquées (durées de conservation, recettes)
│                        + client Open Food Facts + cache.
├── ExpiraScanning       VisionKit / Vision / AVFoundation.
├── ExpiraNotifications  Planification et rédaction des notifications.
├── ExpiraCommerce       StoreKit 2, entitlements, restauration.
└── ExpiraAnalytics      Implémentations du protocole de tracking.

Expira (app target)      Écrans SwiftUI, navigation, composition (DI).
```

Règle de dépendance : **tout dépend de `ExpiraCore`, `ExpiraCore` ne dépend de
rien.** Les moteurs (urgence, estimation, recettes, plan) sont des fonctions
pures : ils se testent sans simulateur, sans base, sans réseau.

### 5.3 Flux de données

```
Vue SwiftUI ──> Store @Observable @MainActor ──> Repository (ExpiraData)
                      │                                   │
                      │                            SwiftData / SQLite
                      ▼
              Moteurs purs (ExpiraCore)
              urgence · estimation · recettes · plan · économies
```

Les vues ne parlent jamais à SwiftData directement. Les moteurs ne connaissent
ni SwiftData ni SwiftUI.

### 5.4 États à gérer explicitement (aucun crash possible)

| État | Comportement |
|---|---|
| Hors-ligne | Scan code-barres → cache local, sinon écran S4 pré-rempli. Tout le reste marche. |
| Réseau lent | Timeout 6 s, on n'attend jamais : bascule S4, l'utilisateur n'est pas bloqué. |
| Échec OCR | Message clair + roue de sélection. Jamais d'échec silencieux. |
| Produit inconnu | S4 + mémorisation locale du code-barres. |
| Date illisible | Estimation proposée, marquée « estimée », modifiable. |
| Caméra refusée | Explication + bouton vers Réglages + repli manuel. |
| Appareil sans DataScanner | Repli automatique sur la saisie manuelle. |
| Échec de sync (V1.2) | Bandeau non bloquant, file d'attente, réessai. |
| Base corrompue | Conteneur de secours en mémoire + message, jamais de crash au lancement. |

---

## 6. Modèle de données

### 6.1 Entités

**FoodItem** (entité centrale)

| Champ | Type | Note |
|---|---|---|
| `id` | UUID | |
| `name` | String | seul champ obligatoire |
| `brand` | String? | |
| `barcode` | String? | indexé |
| `category` | FoodCategory | enum (raw String) |
| `storage` | StorageLocation | `fridge` / `freezer` / `pantry` / `counter` |
| `quantity` | Double | défaut 1 |
| `unit` | QuantityUnit | `piece` / `g` / `kg` / `mL` / `L` / `pack` |
| `purchaseDate` | Date | défaut = aujourd'hui |
| `expiryDate` | Date | toujours renseignée (estimée si inconnue) |
| `expirySource` | ExpiryDateSource | `.label` / `.user` / `.estimated` |
| `isOpened` | Bool | réduit la durée restante |
| `imageURLString` | String? | vignette Open Food Facts |
| `estimatedValueEUR` | Double | pour le calcul d'économies |
| `status` | ItemStatus | `.active` / `.consumed` / `.discarded` |
| `resolvedAt` | Date? | date de sortie du stock |
| `householdID` | UUID? | prévu pour la V1.2, présent dès la V1 |
| `createdAt` / `updatedAt` | Date | |

> `expirySource` est le champ le plus important du modèle : c'est lui qui
> garantit qu'on n'affiche **jamais** une estimation comme une certitude.

**HistoryEvent** — trace immuable des sorties de stock
`id · itemID · itemName · category · kind(.consumed/.discarded) · date · estimatedValueEUR`
Sert au bilan mensuel, à la série, et aux économies. Conservé même si l'aliment
est supprimé.

**Recipe** (embarquée, JSON)
`id · title · minutes · difficulty · servings · ingredients[] · steps[] · tags[]`
`RecipeIngredient : name · category · isOptional · matchKeywords[]`

**ShelfLifeRule** (embarquée, JSON)
`category · storage · days · daysWhenOpened · averagePriceEUR · defaultStorage`

**UserPreferences** (UserDefaults)
`hasCompletedOnboarding · wasteBaselineEUR · notificationsEnabled · digestHour ·
alertThresholdDays · sameDayAlert · weeklySummary · rescueFreeTrialUsed ·
appearance`

**BarcodeMemory** (local) — `barcode → nom/catégorie` saisis par l'utilisateur,
pour que l'app apprenne des produits absents de la base.

### 6.2 Valeurs dérivées (jamais stockées)

`daysRemaining` · `urgency` (`expired/today/tomorrow/thisWeek/later`) ·
`isEstimated` · `savedCount` · `streakDays` · `monthlySavingsEUR`.
Elles sont recalculées à l'affichage : impossible d'avoir un état incohérent.

### 6.3 Estimation de la date de péremption

```
expiryDate = purchaseDate + shelfLife(category, storage, isOpened)
```
La table couvre 16 catégories × 4 lieux de stockage. Exemples :
volaille/frigo 2 j · poisson/frigo 1 j · lait ouvert/frigo 3 j ·
salade/frigo 4 j · œufs/frigo 21 j · fromage dur/frigo 21 j ·
surgelé/congélateur 180 j · conserve/placard 730 j.

Le résultat est **toujours** marqué `.estimated` et affiché « Date estimée ».
L'app n'affirme jamais qu'un aliment est propre à la consommation ; elle rappelle
une date. La nuance est écrite dans l'app et dans les CGU.

### 6.4 Score d'urgence et score anti-gaspillage

```
urgencyWeight(item) = max(0, 1 - daysRemaining / 7)        // 1 = expire aujourd'hui
recipeScore(r)      = Σ urgencyWeight(itemsMatched)  × 3   // sauver, l'objectif
                    + coverage(r)                    × 2   // faisabilité
                    − missingIngredients(r)          × 0.5 // friction
                    − minutes(r) / 60                × 0.3 // effort
```
Le plan de sauvetage applique un **glouton par couverture d'ensemble** : on
choisit la recette qui sauve le plus d'aliments urgents, on retire ces aliments
du pool, on recommence pour le jour suivant.

---

## 7. Système de monétisation

### 7.1 Frontière gratuit / Premium

| | Gratuit | Premium |
|---|---|---|
| Aliments suivis | **15** | Illimité |
| Ajout manuel | ✅ | ✅ |
| **Scan code-barres** | ✅ | ✅ |
| Notification digest | 1 / jour | Complètes + personnalisées |
| Recettes | 3 / semaine | Illimitées |
| Scan de la date (OCR) | — | ✅ |
| Scan de ticket (V1.1) | — | ✅ |
| Sauver mes aliments | 1 essai | Illimité |
| Bilan & historique | 7 jours | Complet |
| Frigo partagé (V1.2) | — | ✅ |

**Le scan code-barres reste gratuit.** C'est contre-intuitif mais décisif : il
*est* le moment « aha ». Le verrouiller détruirait l'activation, donc la base
d'utilisateurs à convertir. On monétise l'**usage intensif** (volume, gain de
temps, foyer), pas la découverte.

### 7.2 Prix — à tester, pas à décréter

| Offre | Hypothèse de départ | Variantes à tester |
|---|---|---|
| Mensuel | **4,99 €** | 3,99 € · 5,99 € |
| Annuel | **29,99 €** (≈ 2,50 €/mois, −50 %) | 24,99 € · 34,99 € |
| Essai | 7 jours sur l'annuel | 3 jours · sans essai |

Protocole : un seul groupe d'abonnement, plusieurs product IDs, affectation
stable par hachage de l'identifiant d'installation, mesure sur **revenu par
installation à 60 jours** (pas sur le taux de conversion, qui pousse à
brader). Minimum ~1 000 installations par variante avant de trancher.

L'annuel est présenté comme le meilleur rapport qualité/prix avec le prix
mensuel équivalent affiché — c'est une information, pas une manipulation.

### 7.3 Règles anti-dark-pattern (non négociables)

- Croix de fermeture visible immédiatement, en haut à **gauche**, ≥ 44 pt.
- Prix, durée d'essai, date de premier prélèvement et prix après essai affichés
  **sur le bouton lui-même**.
- Aucun faux compte à rebours, aucune fausse rareté, aucune culpabilisation.
- « Restaurer mes achats » toujours visible.
- Résiliation expliquée en une phrase avec lien direct vers les réglages iOS.
- L'app reste **utile** en gratuit. Pas de fonctionnalité retirée après coup.

### 7.4 Unit economics visées

Cible : conversion 3–5 % des actifs, LTV ≈ 22 €, CPI organique dominant
(ASO + partage du bilan mensuel). Coût serveur ≈ 0 € grâce au local-first :
le seuil de rentabilité est atteint avec quelques centaines d'abonnés.

---

## 8. Stratégie de rétention

### 8.1 Le vrai ennemi : la dérive du stock

Une app de frigo meurt quand les données deviennent fausses. Contre-mesures
intégrées au produit dès la V1 :

1. **Sortie en un geste** — swipe `Consommé` / `Jeté` depuis la liste, sans
   ouvrir le détail. Le coût de maintien de la vérité doit être proche de zéro.
2. **« J'ai cuisiné ça »** — une recette sort 3 à 5 aliments en un tap.
3. **Check-in dans le digest** — les items périmés depuis > 2 jours apparaissent
   dans un bloc « Toujours là ? » avec deux boutons. On nettoie sans culpabiliser.
4. **Auto-archivage** — un aliment périmé depuis 7 jours sans action passe en
   archive silencieuse (récupérable), il ne pollue plus la liste ni les stats.
5. **Aucune notification en cas de stock vide.** Une app qui alerte dans le vide
   se fait désinstaller.

### 8.2 Les 3 crochets de retour

| Rythme | Crochet | Écran cible |
|---|---|---|
| Quotidien | Digest 1×/jour à l'heure choisie | H1 Frigo |
| Hebdomadaire | « Sauver mes aliments » + recettes | RS1 / R1 |
| Mensuel | Bilan « Ce mois-ci » + série | P1 Profil |

### 8.3 Notifications — la règle des 3

Une notification n'est envoyée que si elle est **actionnable**, **personnelle**
et **rare**. Plafond dur : 1 par jour (+ le résumé du dimanche si activé).

```
« 🍓 Vos fraises sont à consommer aujourd'hui. »
« ⚠️ Votre poulet expire demain. Voir une recette ? »
« 🍳 4 aliments à utiliser cette semaine. »
```
Actions rapides depuis la notification : `Consommé` · `Voir une recette`.

### 8.4 Gamification — sobre, jamais infantile

Une seule mécanique : **la série sans gaspillage** (`🔥 7 jours`). Elle se
construit passivement (ne rien jeter suffit). Pas de badges, pas de points, pas
de mascotte, pas de perte de série punitive : quand la série casse, le message
est « Nouvelle série démarrée » — pas « Vous avez échoué ».

### 8.5 Objectifs mesurables V1

| Métrique | Cible |
|---|---|
| Onboarding terminé | > 80 % |
| 1er aliment ajouté (J0) | > 65 % |
| ≥ 5 aliments à J1 | > 40 % |
| Rétention J7 | > 35 % |
| Rétention J30 | > 20 % |
| Notification → ouverture | > 12 % |
| Conversion Premium (actifs J30) | 3–5 % |

---

## 9. Risques techniques (et parades)

| # | Risque | Impact | Parade |
|---|---|---|---|
| 1 | **OCR de date peu fiable** (relief, courbe, encre pâle) | Élevé | Vision + grammaire de dates FR/EU tolérante, aperçu avant validation, repli roue de sélection en 8 s, jamais bloquant |
| 2 | **Couverture Open Food Facts** (marques distributeur, frais en vrac) | Élevé | Cache + mémoire locale des codes-barres + écran S4 en 2 champs. Le scan ne doit jamais être une impasse |
| 3 | **Dérive du stock** | Critique (rétention) | Voir §8.1 — traité comme une fonctionnalité, pas comme un détail |
| 4 | **Refus des notifications (~50 %)** | Élevé | Écran d'explication avant le prompt, demande différée, bandeau in-app si refus |
| 5 | **Responsabilité sanitaire** d'une estimation | Juridique | `expirySource` partout, libellé « Date estimée », avertissement, CGU explicites. L'app ne dit jamais « c'est bon à manger » |
| 6 | **Complexité CloudKit Sharing** (famille) | Moyen | Reporté en V1.2, mais `householdID` présent dès la V1 → pas de migration douloureuse |
| 7 | **Migration SwiftData** | Moyen | Versioned schema dès le départ, plan de migration, conteneur de secours en cas d'échec |
| 8 | **Refus App Store** (abonnement, caméra) | Moyen | Textes d'usage explicites, paywall conforme, restauration, liens CGU/confidentialité |
| 9 | **Performance caméra** sur vieux appareils | Faible | `DataScannerViewController.isSupported` testé, repli manuel automatique |
| 10 | **Qualité OCR des tickets** (V1.1) | Élevé | C'est pourquoi ce n'est pas dans le MVP : à valider sur ~200 tickets réels avant de l'expédier |
| 11 | **Fatigue des notifications** | Moyen | Plafond dur 1/jour, mesure du taux de désactivation comme métrique de premier plan |

---

## 10. Ce qui doit absolument être dans le MVP

1. Onboarding 4 écrans + premiers aliments
2. Ajout manuel avec valeurs par défaut intelligentes
3. Scan code-barres + fiche produit pré-remplie
4. OCR de la date de péremption
5. Estimation automatique de péremption (table 16 catégories × 4 stockages)
6. Écran Frigo trié par urgence, avec sections et badges accessibles
7. Sortie de stock en un geste (Consommé / Jeté)
8. Notifications locales : digest quotidien + alerte veille
9. Recettes anti-gaspi (catalogue embarqué + moteur de matching)
10. « Sauver mes aliments » (plan sur 3 jours)
11. Bilan « Ce mois-ci » + série sans gaspillage
12. Paywall + abonnement StoreKit 2 (mensuel / annuel)
13. Analytics d'entonnoir
14. Dark mode, Dynamic Type, VoiceOver, états hors-ligne/erreur

## 11. Ce qui doit être supprimé du MVP

| Retiré | Pourquoi | Quand |
|---|---|---|
| Création de compte / login | Friction pure, aucune valeur en V1 (données locales) | V1.2, avec la sync |
| Scan de ticket | Le maillon le plus fragile ; à fiabiliser sur données réelles avant expédition | V1.1 |
| Frigo partagé / famille | CloudKit Sharing = semaines de travail, valeur nulle sans base d'utilisateurs | V1.2 |
| Liste de courses | N'appartient pas à la boucle SCANNER→SAUVER | V1.1 |
| Recettes générées par IA | Coût par requête, latence, hallucinations sur un sujet alimentaire, hors-ligne impossible. Un catalogue embarqué + un bon moteur de matching donne 90 % de la valeur pour 0 % du risque | V2 |
| Reconnaissance du contenu du frigo par photo | Techniquement séduisant, précision insuffisante aujourd'hui | V2+ |
| Statistiques avancées / graphiques | Personne n'ouvre une app de frigo pour des courbes | V1.2 |
| Widgets, Watch, Siri, App Clip | Excellents plus tard, zéro impact sur l'activation initiale | V1.2+ |
| Badges, niveaux, classements | Gamification infantile, explicitement exclue | Jamais |
| Publicité | Détruit la perception premium et la rétention | Jamais |

## 12. Plan de développement par étapes

| Phase | Contenu | Sortie |
|---|---|---|
| **P0 — Fondations** | Package `ExpiraKit`, `ExpiraCore` (modèles + moteurs purs) + tests, design system, schéma SwiftData, squelette de l'app | Le cerveau de l'app, testé, sans UI |
| **P1 — Boucle stock** | Frigo (H1), formulaire (H3), détail (H2), sortie en un geste, estimation automatique | Utilisable en interne |
| **P2 — Entrée rapide** | Scan code-barres (S1/S2), Open Food Facts + cache, produit inconnu (S4), OCR date (S3) | Le « aha » fonctionne |
| **P3 — Retour utilisateur** | Notifications locales, onboarding (O1–O4, F1), analytics d'entonnoir | Boucle complète |
| **P4 — Valeur récurrente** | Recettes (R1/R2), plan « Sauver mes aliments » (RS1), bilan et série (P1) | Raison de revenir |
| **P5 — Monétisation** | StoreKit 2, entitlements, paywall (PW1), limites du gratuit | Prêt à générer du revenu |
| **P6 — Finition** | Accessibilité, hors-ligne, états d'erreur, haptics, animations, performance, TestFlight | Candidat App Store |
| **V1.1** | Scan de ticket · Liste de courses intelligente | Après mesure de la V1 |
| **V1.2** | CloudKit sync · Frigo partagé · Statistiques · Widgets | Après validation de la rétention |
| **V2** | Chef IA (recettes génératives), reconnaissance visuelle du frigo | Après un product-market fit prouvé |

---

## Annexe A — Événements analytics (anonymes)

`app_installed` · `onboarding_started` · `onboarding_step_completed(step)` ·
`waste_baseline_selected(bucket)` · `notification_permission(result)` ·
`onboarding_completed` · `first_item_added(method)` · `item_added(method,
expiry_source)` · `camera_permission(result)` · `scan_started(type)` ·
`scan_succeeded(type, duration_ms)` · `scan_failed(type, reason)` ·
`product_lookup(found, cached)` · `date_ocr(result)` ·
`item_resolved(kind, days_before_expiry)` · `notification_scheduled(type)` ·
`notification_opened(type)` · `recipe_list_viewed` · `recipe_opened(id)` ·
`recipe_cooked(id, items_saved)` · `rescue_plan_generated(items_at_risk)` ·
`paywall_shown(trigger)` · `paywall_dismissed(trigger, seconds)` ·
`subscription_started(product_id)` · `subscription_cancelled(product_id)` ·
`day1_active` · `day7_active` · `day30_active`

Aucun identifiant personnel, aucun nom d'aliment, aucune donnée de santé ne
transite. Le suivi est désactivable dans les réglages.

## Annexe B — Confidentialité

- Aucun compte requis en V1. Les données restent sur l'appareil.
- Une seule requête réseau : le code-barres (13 chiffres) envoyé à Open Food
  Facts. Aucun identifiant utilisateur n'y est joint.
- Caméra : les images ne sont **jamais** envoyées ni stockées ; l'analyse est
  faite en mémoire, sur l'appareil.
- Aucune revente de données. Jamais. C'est aussi un argument produit.
- Export et suppression totale des données depuis les réglages.
