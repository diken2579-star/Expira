# EXPIRA

> « Expira vous aide à savoir quoi manger avant que ça expire. »

Application iOS native (SwiftUI, iOS 17+) de suivi des dates de péremption.
Le produit tient en une boucle : **SCANNER → ENREGISTRER → PRÉVENIR → SAUVER**.

📄 **La conception complète — architecture, écrans, modèle de données,
monétisation, rétention, risques, périmètre du MVP et plan de développement —
est dans [`docs/BLUEPRINT.md`](docs/BLUEPRINT.md).** Lisez-le en premier : le
code en découle directement.

---

## Ce qui est construit (V1)

| Fonctionnalité | État |
|---|---|
| Onboarding 4 écrans + premiers aliments | ✅ |
| Ajout manuel avec défauts intelligents | ✅ |
| Scan de code-barres (mode rafale) + Open Food Facts | ✅ |
| OCR de la date de péremption (FR/EU, on-device) | ✅ |
| Estimation automatique (16 catégories × 4 lieux de stockage) | ✅ |
| Écran Frigo trié par urgence, sortie en un swipe | ✅ |
| Notifications locales (digest quotidien, plafond 1/jour) | ✅ |
| Recettes anti-gaspi (24 recettes + moteur de matching) | ✅ |
| « Sauver mes aliments » — plan sur 3 jours | ✅ |
| Bilan mensuel + série sans gaspillage | ✅ |
| Paywall + abonnement StoreKit 2 | ✅ |
| Analytics d'entonnoir (local, anonyme, désactivable) | ✅ |
| Dark mode, Dynamic Type, VoiceOver, états hors-ligne | ✅ |
| Scan de ticket · Liste de courses | V1.1 |
| Frigo partagé (CloudKit) · Statistiques détaillées | V1.2 |

## Trois décisions structurantes

1. **Local-first, on-device-first.** Aucun backend en V1. OCR, estimation,
   recettes, plan et notifications tournent sur l'appareil. Une seule requête
   réseau : le code-barres envoyé à Open Food Facts. Résultat : app instantanée,
   fonctionnelle hors-ligne, coût d'infrastructure ≈ 0 €, RGPD trivial.
2. **Le scan de code-barres reste gratuit.** C'est le moment « aha » : le
   verrouiller détruirait l'activation. On monétise l'usage intensif, pas la
   découverte.
3. **Pas d'IA générative pour les recettes en V1.** Un catalogue embarqué et un
   bon moteur de matching donnent 90 % de la valeur, en 2 ms, hors-ligne, sans
   coût par requête et sans risque d'hallucination sur un sujet alimentaire.

## Démarrer

**Prérequis : macOS avec Xcode 16 ou plus récent.** XcodeGen génère un projet au
format 77, que Xcode 15 ne sait pas ouvrir.

```bash
brew install xcodegen     # une seule fois
make open                 # génère Expira.xcodeproj et l'ouvre
make test                 # tests unitaires du noyau métier
```

Le `.xcodeproj` n'est pas versionné : il est régénéré depuis `project.yml`.
Le schéma est préconfiguré avec `Expira.storekit`, ce qui permet de tester
l'abonnement sans compte App Store Connect.

### Ce qui marche dans le simulateur

Onboarding, frigo, recettes, plan de sauvetage, bilan et paywall fonctionnent
au simulateur. **Le scan de code-barres et l'OCR de date demandent un iPhone
physique** : le simulateur n'a pas de caméra, et l'app bascule alors
automatiquement sur ses replis manuels — ce qui permet au passage de vérifier
que ces replis sont corrects.

### Aperçus Xcode

Chacun des 12 écrans principaux porte un `#Preview` alimenté par `SampleData`
(`Expira/Support/PreviewSupport.swift`), avec sa variante « état vide ».
Le jeu de démonstration couvre volontairement tous les niveaux d'urgence et les
deux sources de date : c'est la seule façon de voir d'un coup d'œil si la
hiérarchie visuelle tient. Les aperçus tournent sur une base en mémoire et un
domaine `UserDefaults` volatil — ils n'écrasent jamais les données de l'app.

### Intégration continue

`.github/workflows/ci.yml` compile l'app pour le simulateur iOS et exécute
`ExpiraCoreTests` sur un runner macOS à chaque poussée. C'est la source de
vérité du projet : le code peut être écrit depuis n'importe quelle machine, la
CI dit s'il compile.

## Structure

```
Expira/                   Application (SwiftUI)
├── App/                  Composition root, routage, délégué de notifications
├── Features/
│   ├── Onboarding/       O1–O4 + premiers aliments
│   ├── Fridge/           Écran principal, détail, ligne d'aliment
│   ├── AddItem/          Brouillon, formulaire, scan code-barres, OCR de date
│   ├── Recipes/          Liste, détail, « J'ai cuisiné ça »
│   ├── Rescue/           Plan « Sauver mes aliments »
│   ├── Profile/          Bilan, notifications, confidentialité
│   └── Paywall/          Abonnement
└── Support/              Info.plist, assets, config StoreKit

ExpiraKit/                Package local, 8 modules
├── ExpiraCore            Modèles + moteurs purs. Zéro UI, zéro I/O. Tout en dépend.
├── ExpiraDesignSystem    Couleurs, typo, composants
├── ExpiraCatalog         Durées de conservation, recettes, Open Food Facts
├── ExpiraData            SwiftData + stores observables
├── ExpiraScanning        VisionKit / Vision / AVFoundation
├── ExpiraNotifications   Programmation locale
├── ExpiraCommerce        StoreKit 2
└── ExpiraAnalytics       Suivi d'entonnoir local
```

Règle de dépendance : **tout dépend de `ExpiraCore`, `ExpiraCore` ne dépend de
rien.** Les moteurs (urgence, estimation, matching de recettes, plan de
sauvetage, économies, rédaction des notifications) sont des fonctions pures et
se testent sans simulateur.

## Tests

`ExpiraCoreTests` couvre ce qui casse silencieusement en production :

- **Analyse OCR des dates** — formats FR/EU, priorité de la mention
  « à consommer avant » sur une date de fabrication, et surtout les **refus** :
  date aberrante, 31 février, ou fragment ambigu à côté d'une date complète.
- **Estimation de péremption** — cohérence de la table sur les 64 combinaisons
  catégorie × stockage.
- **Moteur de recettes** — jamais de recette sans aliment du frigo, jamais un
  aliment compté deux fois, priorité à ce qui expire en premier.
- **Plan de sauvetage** — pas de recette répétée, pas d'aliment sauvé deux fois,
  repli quand aucune recette ne colle.
- **Notifications** — plafond d'une par jour, aucune notification à vide, rien
  planifié dans le passé.
- **Bilan et série** — la série ne commence jamais avant la première utilisation.

## Avant la mise en production

- [ ] Remplacer les URL de `Expira/Support/LegalLinks.swift` (CGU, confidentialité)
- [ ] Créer les produits d'abonnement dans App Store Connect avec les
      identifiants de `ExpiraProduct` (`app.expira.premium.annual` / `.monthly`)
- [ ] Fournir l'icône d'app (1024×1024) dans `Assets.xcassets/AppIcon`
- [ ] Renseigner l'équipe de signature dans Xcode
- [ ] Valider l'OCR de date sur un corpus réel d'emballages avant d'élargir
      l'audience

## Confidentialité

Aucun compte. Aucune donnée alimentaire ne quitte l'appareil. Une seule requête
réseau (13 chiffres de code-barres, sans identifiant). Les images de la caméra
sont analysées en mémoire et jamais enregistrées. Le journal analytique est
local, consultable ligne par ligne depuis l'app, et désactivable.
