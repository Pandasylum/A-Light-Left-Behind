# A LIGHT LEFT BEHIND — ORGANISATION DES PROJETS CLAUDE

## Objectif général

Organiser le développement de A Light Left Behind à travers six projets Claude spécialisés.

Chaque projet possède un domaine de responsabilité précis.

L'objectif est de disposer d'une assistance spécialisée pour les différentes dimensions du développement sans créer plusieurs versions concurrentes du jeu.

Les six projets doivent suivre la même vision, les mêmes décisions de conception et les mêmes contraintes de production.

Le véritable projet Godot et son code source restent dans un unique dépôt Git.

Les projets Claude servent principalement à :
- La réflexion.
- La conception.
- La documentation.
- La recherche.
- La planification.
- L'analyse.
- L'assistance spécialisée.

Claude Code est utilisé pour intervenir directement sur les fichiers du projet Godot.

**Important :** ne pas considérer les six projets Claude comme six projets de jeu indépendants. Ils travaillent tous sur le même jeu.

## 1. A LIGHT LEFT BEHIND — Direction & Game Design

**Rôle : cerveau central du projet et source de référence.**

Ce projet est responsable de la vision globale du jeu et des décisions de conception validées.

### Responsabilités

- Vision globale du jeu.
- Identité du projet.
- Game Design Document.
- Boucle de gameplay principale.
- Mécaniques et interactions.
- Organisation générale du gameplay.
- Progression du joueur.
- Déblocages.
- Améliorations d'équipement.
- Équilibrage des systèmes.
- Priorités de développement.
- Feuille de route.
- Cohérence globale des fonctionnalités.

Ce projet doit prendre en compte les contraintes de production et la capacité d'un développeur solo.

Il doit éviter de proposer des fonctionnalités ambitieuses qui augmenteraient inutilement la charge de développement.

### Documents de référence

- `PROJECT_RULES.md`
- `GDD.md`
- `VISION.md`
- `ROADMAP.md`
- `PROGRESSION.md`

### Règle particulière

Ce projet est responsable des décisions de conception approuvées.

Les autres projets doivent respecter ces décisions.

Lorsqu'une proposition provenant d'un autre projet implique une modification du game design, elle doit être examinée ici avant d'être considérée comme validée.

## 2. A LIGHT LEFT BEHIND — Godot Engineering

**Rôle : développement technique et architecture du jeu.**

Ce projet est consacré à l'implémentation technique dans Godot.

### Responsabilités

- Architecture du projet Godot.
- Organisation des scènes.
- Organisation des scripts.
- GDScript.
- Déplacement du joueur.
- Caméra.
- Détection des objets.
- Interactions.
- Ramassage des objets.
- Rotation.
- Placement.
- Dépôt.
- Inventaire.
- Rangement.
- Tiroirs et portes.
- Système de nettoyage.
- Système de restauration.
- Sauvegarde.
- Chargement.
- Persistance de l'état du monde.
- Optimisation.
- Performances.
- Résolution des problèmes techniques.

### Documents de référence

- `PROJECT_RULES.md`
- `TECHNICAL.md`
- `SYSTEMS.md`
- `GDD.md`

### Règles particulières

Privilégier des systèmes modulaires et réutilisables.

Éviter de dupliquer le même code pour chaque pièce ou chaque type d'objet.

Utiliser des ressources et des données lorsque cela permet de séparer le contenu de l'implémentation.

Ne pas sur-ingénier les systèmes.

La priorité est de disposer d'une architecture fiable, compréhensible et suffisamment souple pour accueillir les futures pièces du phare.

## 3. A LIGHT LEFT BEHIND — Art Direction & Assets

**Rôle : direction artistique et production des ressources visuelles.**

Ce projet est consacré à l'identité visuelle du jeu et à la production des éléments 3D.

### Responsabilités

- Références visuelles.
- Direction artistique.
- Cohérence des environnements.
- Conception des pièces.
- Mobilier.
- Objets.
- Accessoires.
- Matériaux.
- Textures.
- Ressources 3D générées par IA.
- Recherche de bibliothèques de ressources.
- Préparation dans Blender.
- Nettoyage des modèles.
- Vérification des UV.
- Vérification des matériaux.
- Préparation des collisions.
- Optimisation des ressources.
- Intégration dans Godot.

### Documents de référence

- `PROJECT_RULES.md`
- `ART_BIBLE.md`
- `ASSET_LIST.md`
- `MATERIALS.md`

### Règles particulières

Le développeur possède une expérience limitée en modélisation 3D.

Privilégier les solutions accessibles :
- Ressources existantes.
- Génération 3D par IA.
- Éléments modulaires.
- Variations de matériaux.
- Textures réutilisables.
- Préparation simple dans Blender.

Ne pas proposer de workflows de modélisation complexes sans nécessité.

Ne pas générer chaque objet indépendamment si une ressource existante peut être réutilisée.

Ne pas générer des pièces entières sous forme d'un seul modèle 3D.

La cohérence visuelle de l'ensemble est plus importante que la complexité individuelle de chaque ressource.

## 4. A LIGHT LEFT BEHIND — Sound Design

**Rôle : conception et production sonore.**

Ce projet est consacré aux ambiances et aux sons d'interaction du jeu.

### Responsabilités

- Ambiances environnementales.
- Vent.
- Pluie.
- Mer.
- Craquements du bâtiment.
- Bruits de pas.
- Manipulation des objets.
- Sons de rangement.
- Ouverture et fermeture des tiroirs.
- Portes.
- Nettoyage.
- Restauration.
- Outils.
- Mécanismes.
- Engrenages.
- Machines.
- Mixage audio.
- Organisation de la bibliothèque sonore.
- Intégration dans Godot.

### Documents de référence

- `PROJECT_RULES.md`
- `AUDIO_BIBLE.md`
- `SOUND_LIST.md`

### Règles particulières

Le développeur possède une expérience limitée en conception sonore.

Privilégier :
- Les sons générés par IA.
- Les bibliothèques de sons existantes.
- Les sons réutilisables.
- Les variations d'un même son.
- Les traitements audio simples.
- Les ambiances en boucle.

Le son doit renforcer l'immersion et le plaisir des interactions.

Les sons de manipulation doivent être suffisamment présents pour donner du poids aux actions.

Les ambiances doivent rester discrètes et ne pas devenir envahissantes.

Éviter les effets sonores excessifs.

## 5. A LIGHT LEFT BEHIND — World & Content

**Rôle : conception du monde, des pièces et du contenu.**

Ce projet est consacré à la création du contenu du phare et à sa narration environnementale.

### Responsabilités

- Organisation des pièces.
- Agencement des espaces.
- Mobilier.
- Objets.
- Collections.
- Décoration.
- Documents.
- Notes.
- Découvertes.
- Narration environnementale.
- Histoire du phare.
- Progression des pièces.
- Contenu à découvrir.
- Détails visuels.
- Identité de chaque espace.

### Documents de référence

- `PROJECT_RULES.md`
- `ROOMS.md`
- `OBJECTS.md`
- `COLLECTIONS.md`

### Règles particulières

Chaque pièce doit posséder :
- Une fonction.
- Une identité visuelle.
- Une cohérence avec le reste du phare.
- Des objets adaptés à son usage.
- Des détails qui récompensent l'exploration.

Les objets ne doivent pas être uniquement décoratifs lorsqu'ils pourraient contribuer à l'histoire du lieu.

Privilégier les détails environnementaux et les découvertes progressives plutôt que les longues explications.

Les pièces doivent s'intégrer à la progression globale du joueur.

## 6. A LIGHT LEFT BEHIND — QA & Production

**Rôle : assurance qualité et suivi du développement.**

Ce projet est consacré à la vérification des fonctionnalités, à la gestion des problèmes et au suivi de la production.

### Responsabilités

- Plans de test.
- Tests fonctionnels.
- Suivi des bugs.
- Tests de régression.
- Vérification des interactions.
- Vérification des sauvegardes.
- Vérification des chargements.
- Contrôle des performances.
- Validation des fonctionnalités.
- Suivi des étapes de production.
- Historique des modifications.
- Suivi de l'avancement.

### Documents de référence

- `PROJECT_RULES.md`
- `TEST_PLAN.md`
- `BUGS.md`
- `CHANGELOG.md`

### Règles particulières

Ne jamais considérer une fonctionnalité comme terminée sans l'avoir testée.

Vérifier qu'une nouvelle fonctionnalité ne casse pas les systèmes existants.

Tester les interactions dans des conditions normales d'utilisation.

Vérifier la persistance des données après sauvegarde et chargement.

Signaler les problèmes de manière précise et reproductible.

Privilégier les validations concrètes plutôt que les suppositions.

## 7. Organisation des documents communs

Les six projets doivent disposer d'un socle documentaire commun.

Le document `PROJECT_RULES.md` constitue la référence fondamentale.

Les documents de conception approuvés doivent être conservés dans le projet central.

Les autres projets doivent utiliser ces documents comme références.

Il ne faut pas laisser chaque projet créer sa propre version indépendante du GDD, de la vision ou de la progression.

Lorsqu'une décision importante est modifiée :
1. La modification doit être examinée dans le projet central.
2. La décision validée doit être documentée.
3. Les documents concernés doivent être mis à jour.
4. Les projets spécialisés doivent prendre en compte cette nouvelle référence.

Ne pas supposer que les différents projets Claude partagent automatiquement leurs conversations ou leurs décisions.

Les documents communs doivent donc être fournis explicitement aux projets concernés.

## 8. Organisation du code et du dépôt Git

Le code source du jeu doit rester dans un seul dépôt Git.

Les six projets Claude ne doivent pas posséder des copies concurrentes du code.

Claude Code travaille directement sur ce dépôt.

Les projets Claude servent à préparer et documenter les décisions, tandis que Claude Code réalise les modifications techniques.

Les modifications importantes doivent être enregistrées dans Git.

Éviter les modifications massives et difficiles à vérifier.

## 9. Règles communes aux six projets

Tous les projets doivent respecter les règles suivantes :

1. `PROJECT_RULES.md` est la base commune.
2. Le projet Direction & Game Design possède la responsabilité des décisions de conception validées.
3. Les décisions techniques importantes doivent être documentées.
4. Ne pas contredire une décision établie sans expliquer pourquoi.
5. Ne pas introduire de nouvelles mécaniques sans considérer leur impact sur l'ensemble du jeu.
6. Privilégier des plans de production réalistes.
7. Respecter les contraintes d'un développeur solo.
8. Éviter les workflows inutilement complexes.
9. Favoriser la réutilisation des ressources et des systèmes.
10. Maintenir une cohérence entre gameplay, visuels, sons, progression et narration.

## 10. Méthodologie de travail avec Claude Code

Claude Code intervient directement sur le dépôt Godot.

Avant chaque implémentation importante, il doit :

- Lire la documentation concernée.
- Examiner l'architecture existante.
- Identifier les fichiers et systèmes impliqués.
- Comprendre les dépendances.
- Proposer un plan d'implémentation limité.
- Éviter les modifications sans rapport avec la demande.

Après l'implémentation, il doit :

- Tester le résultat dans Godot.
- Expliquer les modifications effectuées.
- Signaler les problèmes restants.
- Vérifier les éventuelles régressions.
- Mettre à jour la documentation lorsque cela est nécessaire.

L'objectif est de construire un seul jeu cohérent, maintenable et évolutif, et non six projets indépendants.
## 11. Activation progressive des projets (décision du 2026-11-10)

Trois projets sont actifs au départ : Direction & Game Design, Godot Engineering, Art Direction & Assets.
Sound Design, World & Content et QA & Production sont créés quand leur phase approche (audio : phases 6 à 9 ; contenu : phase 7 ; QA : avant la phase 10). D'ici là, Direction suit l'avancement dans `ROADMAP.md` et Claude Code lance ses tests ciblés.

## 12. Circulation de l'information (décision du 2026-11-10)

- Le dépôt est la seule source de vérité. Les chats pensent et décident, Claude Code exécute.
- Chaque décision vit dans un seul document : `GDD.md` (conception), `TECHNICAL.md` (technique), `ART_BIBLE.md` (art). Pas de copie.
- Chaque projet Claude ne synchronise que ses documents depuis GitHub (filtre par projet).
- Entre projets : fiche de transmission de 10 lignes maximum (décision, pourquoi, demande, contraintes, livrable).
- Prompts Claude Code : techniques écrits par Godot Engineering, documentation et game design par Direction. Règles permanentes dans `CLAUDE.md`, carte du code dans `SYSTEMS.md`.
- Claude Code ne prend aucune décision : doute de conception → Direction ; doute technique → Godot Engineering.
