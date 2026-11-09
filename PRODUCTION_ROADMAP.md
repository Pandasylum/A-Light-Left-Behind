# THE LAST KEEPER — FEUILLE DE ROUTE DE PRODUCTION

## Objectif général

Construire progressivement The Last Keeper en validant le gameplay principal avant d'investir massivement dans la production du contenu et des ressources visuelles.

Le projet doit rester réalisable pour un développeur solo utilisant Claude, Claude Code, Godot, Blender et des outils de création assistée par IA.

La production est divisée en six phases.

Chaque phase doit être validée avant de passer à la suivante.

Les durées indiquées sont des estimations et peuvent évoluer en fonction des difficultés rencontrées.

---

# PHASE 0 — PRÉPRODUCTION

<text>Durée estimée : 2 à 4 jours</text>

## Objectifs

Préparer le projet, définir sa direction et organiser l'environnement de développement.

Cette phase doit permettre de disposer d'une vision claire du jeu, d'une organisation documentaire et d'un environnement technique opérationnel.

## Tâches

### Organisation des projets Claude

- Créer les six projets Claude spécialisés.
- Ajouter le document `PROJECT_RULES.md` à chaque projet.
- Créer le projet central Direction & Game Design.
- Créer les documents de référence.
- Définir les responsabilités de chaque projet.

### Conception

- Définir la vision générale.
- Définir la boucle de gameplay principale.
- Définir les premières mécaniques.
- Définir la progression générale.
- Définir les premières améliorations d'équipement.
- Définir l'identité visuelle.
- Définir les grandes lignes de la conception sonore.

### Environnement technique

- Installer Godot 4.6.
- Installer Blender.
- Installer et configurer Git.
- Créer le dépôt du projet.
- Définir une première organisation des dossiers.
- Préparer la structure technique initiale.

### Recherche des outils de production

- Identifier les outils de génération 3D par IA.
- Identifier les outils de génération sonore.
- Identifier les bibliothèques de ressources existantes.
- Vérifier les licences et les possibilités d'utilisation commerciale.
- Identifier les outils de préparation et de traitement des ressources.

## Documents à produire

- `GDD.md`
- `VISION.md`
- `PROJECT_RULES.md`
- `ART_BIBLE.md`
- `TECHNICAL.md`
- `ROADMAP.md`
- `ASSET_LIST.md`
- `SOUND_LIST.md`

## Validation de la phase

La vision du jeu, les grandes mécaniques, la direction artistique, la direction technique et les outils de production doivent être clairement définis.

Le développeur doit savoir ce qu'il va construire et comment commencer.

---

# PHASE 1 — PROTOTYPE GREYBOX

<text>Durée estimée : 1 à 2 semaines</text>

## Objectifs

Construire la première pièce jouable avec une géométrie simple.

L'objectif n'est pas de produire un environnement visuellement abouti, mais de valider les interactions fondamentales.

Ne pas investir de temps dans les ressources artistiques finales à ce stade.

## Environnement initial

Créer un seul atelier comprenant :

- Des murs basiques.
- Un sol.
- Un plafond si nécessaire.
- Un établi.
- Un tiroir.
- Une étagère.
- Cinq objets interactifs.
- Un éclairage simple.

Les meubles et les objets peuvent être représentés par des formes géométriques simples.

## Systèmes de gameplay à développer

### Déplacement

- Déplacement à la première personne.
- Contrôle de la caméra.
- Gestion des collisions.
- Interaction avec l'environnement.

### Manipulation des objets

- Détection des objets.
- Ramassage.
- Rotation.
- Déplacement.
- Placement.
- Dépôt.
- Gestion de la distance de manipulation.
- Gestion des collisions lors du placement.

### Rangement

- Ouverture des tiroirs.
- Fermeture des tiroirs.
- Stockage des objets.
- Récupération des objets rangés.

### Sauvegarde

- Sauvegarde de la position des objets.
- Sauvegarde de leur état.
- Sauvegarde de leur emplacement.
- Chargement de la scène.
- Vérification de la persistance des données.

## Validation de la phase

Le joueur doit pouvoir :

1. Explorer l'atelier.
2. Ramasser les objets.
3. Les manipuler confortablement.
4. Les faire pivoter.
5. Les poser sur les meubles.
6. Les déplacer.
7. Les ranger dans un tiroir.
8. Les récupérer.
9. Sauvegarder.
10. Recharger la scène et retrouver les objets dans leur état précédent.

Les interactions doivent être naturelles et ne pas lutter contre le joueur.

La manipulation des objets constitue une fondation importante du jeu. Elle doit être suffisamment agréable avant de poursuivre.

---

# PHASE 2 — SYSTÈME DE NETTOYAGE

<text>Durée estimée : 1 à 3 semaines</text>

## Objectifs

Développer et valider la boucle de gameplay principale liée au nettoyage.

Le nettoyage doit être une activité tactile et satisfaisante.

Le joueur doit percevoir visuellement la transformation des surfaces.

## Fonctionnalités

### Représentation de la saleté

- Surfaces nettoyables.
- État de saleté.
- Progression du nettoyage.
- Évolution visuelle de la surface.
- Persistance de l'état après sauvegarde.

### Outils

- Brosse.
- Chiffon.
- Éponge.
- Pulvérisateur.

Les outils peuvent être introduits progressivement.

### Interactions

- Utilisation des outils.
- Détection des surfaces.
- Zone d'action du nettoyage.
- Retour visuel pendant l'utilisation.
- Retour sonore.
- Évolution de l'état de la surface.

### Technique

Commencer par une représentation simple de la saleté.

Ne pas développer immédiatement une simulation dynamique complexe.

Une représentation par zones ou par données peut suffire pour valider le système.

Une gestion par masque dynamique peut être envisagée si elle apporte une réelle amélioration à l'expérience.

La complexité technique doit être justifiée par le résultat obtenu.

### Sauvegarde

L'état de nettoyage des surfaces doit être conservé.

Le joueur ne doit pas devoir recommencer une pièce déjà nettoyée après avoir quitté le jeu.

## Validation de la phase

Le nettoyage d'un établi ou d'une autre surface doit être satisfaisant.

Le joueur doit pouvoir voir clairement la différence entre une surface sale et une surface nettoyée.

Le système ne doit pas dépendre :
- D'un chronomètre.
- D'un score.
- D'une récompense artificielle.
- D'une pression temporelle.

Le plaisir doit venir de l'action et du résultat visuel.

---

# PHASE 3 — VERTICAL SLICE ARTISTIQUE

<text>Durée estimée : 2 à 4 semaines</text>

## Objectifs

Produire une petite section du phare avec la qualité visuelle et sonore prévue pour le jeu final.

Cette phase permet de valider les méthodes de production des ressources 3D, des textures, des matériaux et des sons.

Il ne s'agit plus uniquement de valider le gameplay, mais de vérifier que le jeu peut atteindre son identité visuelle avec des moyens adaptés à un développeur solo.

## Environnement

L'atelier doit contenir environ :

- 30 objets.
- 4 outils.
- 10 surfaces nettoyables.
- 2 objets restaurables.

Ces chiffres constituent des objectifs pour le vertical slice et non des contraintes absolues.

## 3.1. Production des ressources visuelles

### Étape 1 — Références visuelles

Créer des références pour :
- Le mobilier.
- Les outils.
- Les objets.
- Les matériaux.
- Les textures.
- L'éclairage.
- L'atmosphère de l'atelier.

Utiliser la même direction artistique pour les différentes familles d'objets.

### Étape 2 — Génération et récupération des ressources

Utiliser plusieurs sources complémentaires :

- Génération de modèles 3D par IA.
- Bibliothèques de ressources existantes.
- Ressources modulaires.
- Modèles existants pouvant être modifiés.
- Variations de matériaux et de textures.

Ne pas chercher à générer chaque objet individuellement si une ressource existante peut être réutilisée.

### Étape 3 — Préparation dans Blender

Chaque ressource doit être vérifiée avant intégration.

Contrôler :
- L'échelle.
- La topologie.
- Le nombre de polygones.
- Les UV.
- Les textures.
- Les matériaux.
- L'orientation.
- Les collisions.
- La qualité générale du modèle.

Nettoyer les modèles lorsque cela est nécessaire.

### Étape 4 — Intégration dans Godot

Privilégier le format GLB/glTF.

Vérifier :
- L'importation.
- Les dimensions.
- Les matériaux.
- Les collisions.
- Les performances.
- L'apparence dans l'éclairage réel du jeu.

## 3.2. Pipeline de production 3D assisté par IA

Le pipeline recommandé est :

1. Claude et la génération d'images pour les concepts, références et variantes.
2. Génération 3D par IA et bibliothèques de ressources pour les meubles, outils et accessoires.
3. Blender et Claude pour le nettoyage, la mise à l'échelle, les collisions, les matériaux et l'optimisation.
4. Godot pour l'intégration, l'éclairage, les interactions et le rendu.

Les modèles générés par IA ne doivent pas être considérés comme prêts à l'emploi.

Il est possible de rencontrer :
- Des maillages trop lourds.
- Une topologie incorrecte.
- Des UV de mauvaise qualité.
- Des matériaux manquants.
- Des échelles incohérentes.
- Des collisions absentes.
- Des problèmes de performances.

Chaque ressource doit être contrôlée dans Blender puis dans Godot.

Ne pas générer une pièce entière sous forme d'un unique modèle 3D.

Construire les murs, sols, plafonds et éléments architecturaux avec des modules réutilisables.

Réserver la génération 3D principalement aux meubles, accessoires et petits objets.

### Comparaison des outils

Tester au moins deux outils de génération 3D sur les mêmes objets.

Par exemple :
- Une chaise.
- Une caisse en bois.
- Un outil à main.

Comparer les résultats dans Blender et Godot.

Ne pas souscrire immédiatement à plusieurs abonnements.

Choisir un outil principal après avoir vérifié la qualité, les possibilités d'exportation et la facilité de préparation des ressources.

Les outils envisagés comprennent notamment :
- Tripo AI.
- Meshy.
- Rodin / Hyper3D.

Les bibliothèques complémentaires à examiner comprennent :
- Poly Haven.
- ambientCG.
- Sketchfab.
- Kenney.

Vérifier les licences de chaque ressource, en particulier les droits d'utilisation commerciale.

## 3.3. Matériaux et textures

Créer une bibliothèque de matériaux réutilisables.

Prévoir notamment :
- Bois ancien.
- Bois verni.
- Bois brut.
- Métal oxydé.
- Fer.
- Cuivre.
- Laiton.
- Verre.
- Pierre.
- Tissu.
- Peinture ancienne.
- Surfaces poussiéreuses.

Utiliser des variations de matériaux pour donner différents états aux objets sans multiplier inutilement les modèles 3D.

Les matériaux doivent contribuer à l'impression d'ancienneté et d'usure.

## 3.4. Production sonore

Intégrer les premiers sons nécessaires à l'atelier.

Créer au minimum :

- Un son d'ouverture de tiroir.
- Un son de fermeture de tiroir.
- Un son de manipulation d'objet.
- Un son de brosse.
- Un son de chiffon.
- Une ambiance de pluie.

Tester la génération sonore par IA.

Outils envisagés :
- ElevenLabs Sound Effects.
- Adobe Firefly Sound Effects.
- Audacity pour le montage et le traitement audio.

### Organisation de la bibliothèque sonore

Prévoir des catégories distinctes :

**Ambiances**
- Vent.
- Pluie.
- Mer.
- Craquements du phare.

**Déplacements**
- Pas sur le bois.
- Pas sur la pierre.
- Pas sur le métal.

**Objets**
- Bois.
- Métal.
- Verre.

**Rangement**
- Tiroirs.
- Portes.
- Boîtes.
- Armoires.

**Nettoyage**
- Brosse.
- Chiffon.
- Éponge.
- Pulvérisateur.

**Restauration**
- Ponçage.
- Polissage.
- Vissage.

**Mécanismes**
- Engrenages.
- Leviers.
- Moteurs.

Les sons d'interaction doivent être légèrement plus présents que l'ambiance de fond.

La superposition et le mixage sont aussi importants que les sons individuels.

### Exemple de prompt sonore pour un tiroir

Créer un son rapproché et intime d'un vieux tiroir en bois massif qui s'ouvre dans un atelier silencieux d'un ancien phare.

Le son doit comporter :
- Le frottement sec du bois.
- Un léger grincement.
- Une résistance mécanique naturelle.
- Un arrêt final perceptible.

Aucune musique, aucune voix et aucune ambiance de fond.

Le résultat doit ressembler à un véritable enregistrement de bruitage.

### Exemple de prompt sonore pour une ambiance

Créer une ambiance sonore continue à l'intérieur d'un ancien phare isolé pendant une journée froide et pluvieuse.

Inclure :
- Des vagues lointaines.
- Un vent doux.
- La pluie sur les vieilles fenêtres.
- Quelques craquements discrets du bâtiment.

L'atmosphère doit être calme, mélancolique et réconfortante.

Aucune musique et aucune voix.

Prévoir une boucle fluide et sans coupure perceptible.

## 3.5. Première amélioration d'équipement

Introduire la première amélioration du joueur.

Elle doit être simple et démontrer le fonctionnement du système d'amélioration.

Exemple :
- Ceinture à outils permettant de transporter deux petits objets au lieu d'un.

Le système doit pouvoir accueillir d'autres améliorations ultérieurement.

## Validation de la phase

L'atelier doit représenter la qualité visuelle et sonore visée pour le jeu final.

Le joueur doit pouvoir :
- Manipuler les objets.
- Les ranger.
- Nettoyer les surfaces.
- Restaurer un objet.
- Utiliser un outil amélioré.
- Entendre les interactions.
- Observer une transformation visuelle satisfaisante.

Ne pas passer à la production des autres pièces avant d'avoir validé ce niveau de qualité.

---

# PHASE 4 — PRODUCTION DU CONTENU

## Objectifs

Étendre progressivement le phare en utilisant les systèmes validés et les ressources réutilisables.

Les nouvelles pièces doivent enrichir le contenu sans nécessiter la création de systèmes entièrement nouveaux à chaque étape.

## Ordre de production suggéré

### 1. Atelier

Pièce de référence du jeu.

Elle permet de :
- Manipuler les objets.
- Utiliser les outils.
- Nettoyer.
- Restaurer.
- Organiser le mobilier.
- Découvrir les premières améliorations.

### 2. Hall d'entrée

Premier espace de transition et de découverte.

Il doit permettre de donner une identité au phare et de montrer progressivement son état général.

### 3. Bibliothèque

Pièce consacrée aux documents, aux livres, aux collections et aux découvertes.

Elle peut accueillir des éléments de narration environnementale.

### 4. Cuisine

Espace domestique avec ses propres objets, meubles, surfaces et éléments à restaurer.

### 5. Quartiers du gardien

Espace plus personnel.

Il peut contribuer à renforcer l'impression que le phare est un lieu de vie et un refuge.

### 6. Salle des machines

Pièce consacrée aux mécanismes, aux équipements et aux éléments techniques du phare.

Elle permet d'introduire davantage d'interactions mécaniques.

### 7. Salle de la lanterne

Pièce symbolique du phare et point important de son identité.

Elle doit bénéficier d'une attention particulière concernant l'ambiance, les matériaux et l'éclairage.

## Principes de production

- Réutiliser le mobilier lorsque cela est pertinent.
- Créer des variations avec les matériaux et l'état des objets.
- Réutiliser les systèmes de nettoyage.
- Réutiliser les systèmes de restauration.
- Conserver des agencements modulaires.
- Réutiliser les interactions existantes.
- Ajouter de la narration environnementale.
- Introduire de nouveaux objets progressivement.
- Introduire de nouvelles interactions uniquement lorsqu'elles apportent une réelle valeur.

Chaque nouvelle pièce doit être construite à partir des systèmes déjà validés.

Ne pas réécrire un système existant simplement parce qu'une nouvelle pièce utilise un autre type de mobilier.

## Validation de la phase

Chaque pièce doit être :
- Jouable.
- Cohérente visuellement.
- Intégrée à la progression.
- Compatible avec les systèmes existants.
- Correctement sauvegardée.
- Suffisamment détaillée pour récompenser l'exploration.

---

# PHASE 5 — PROGRESSION ET FINITIONS

## Objectifs

Donner au joueur des raisons supplémentaires d'explorer, de restaurer et de personnaliser le phare.

Cette phase permet d'enrichir la progression sans introduire de systèmes punitifs ou de mécaniques artificielles.

## 5.1. Améliorations d'équipement

Les améliorations doivent être pratiques, modestes et cohérentes avec l'univers.

Elles doivent faciliter certaines tâches sans supprimer leur intérêt.

### Catégorie 1 — Transport et rangement

**Ceinture à outils**
- Permet de transporter deux petits objets au lieu d'un.

**Sac de transport**
- Augmente la capacité de transport de petits objets.

**Plateau de transport**
- Permet de déplacer plusieurs petits objets en une seule fois.

**Chariot**
- Permet de transporter des objets encombrants.

### Catégorie 2 — Nettoyage

**Brosse renforcée**
- Augmente légèrement la vitesse de nettoyage.

**Brosse large**
- Augmente légèrement le rayon d'action du nettoyage.

**Pulvérisateur amélioré**
- Augmente la surface humidifiée.

**Chiffon de qualité**
- Rend le polissage plus efficace.

### Catégorie 3 — Restauration et exploration

**Kit de précision**
- Facilite la restauration des petits objets.

**Lampe d'atelier**
- Améliore la visibilité des détails.

## 5.2. Déblocage des améliorations

Privilégier les découvertes naturelles et les étapes de restauration plutôt qu'une monnaie artificielle.

Exemples :

- Restaurer l'atelier pour fabriquer une ceinture à outils.
- Trouver des pièces dans la salle des machines pour réparer le pulvérisateur.
- Découvrir d'anciens plans dans la bibliothèque.
- Réparer l'ancien établi pour fabriquer de nouveaux outils.
- Explorer une pièce oubliée pour découvrir une lampe d'atelier.

Les améliorations doivent s'intégrer à l'exploration et à la restauration du phare.

Éviter une progression artificielle reposant sur des points d'expérience ou une accumulation de monnaie.

## 5.3. Organisation technique des améliorations

Les améliorations doivent être conçues de manière à pouvoir être étendues sans devoir modifier individuellement chaque système.

Privilégier une architecture pilotée par les données.

Les améliorations doivent pouvoir définir :
- Leur identifiant.
- Leur nom.
- Leur description.
- Leur catégorie.
- Leur niveau maximal.
- Leur bonus de capacité de transport.
- Leur multiplicateur de vitesse de nettoyage.
- Leur multiplicateur de rayon de nettoyage.

Exemple de structure illustrative en GDScript :

```gdscript
extends Resource
class_name UpgradeData

@export var upgrade_id: String
@export var display_name: String
@export_multiline var description: String

@export var category: String
@export var max_level: int = 1

@export var carry_capacity_bonus: int = 0
@export var cleaning_speed_multiplier: float = 1.0
@export var cleaning_radius_multiplier: float = 1.0
```

Cet exemple constitue une base de réflexion et non une implémentation définitive.

L'architecture finale doit être adaptée aux systèmes réellement présents dans le projet.

Éviter de coder directement chaque amélioration dans chaque mécanique.

Les systèmes concernés doivent pouvoir récupérer les bonus applicables depuis les données des améliorations.

## 5.4. Progression supplémentaire

Prévoir progressivement :

- Des collections.
- Des documents.
- Des notes.
- Des découvertes.
- Des étapes de restauration des pièces.
- Des objets à conserver.
- Des possibilités de personnalisation.
- La transformation visuelle du phare.

Ces éléments doivent enrichir l'expérience sans devenir des obligations répétitives.

## 5.5. Finitions et optimisation

Une fois le contenu principal développé :

- Améliorer l'éclairage.
- Améliorer les matériaux.
- Améliorer les textures.
- Améliorer le mixage audio.
- Vérifier les ambiances.
- Optimiser les ressources 3D.
- Optimiser les performances.
- Vérifier la fiabilité des sauvegardes.
- Vérifier la fiabilité des chargements.
- Tester les interactions dans l'ensemble du phare.
- Recueillir des retours de joueurs extérieurs.
- Corriger les bugs.
- Améliorer l'ergonomie.
- Vérifier la cohérence générale du jeu.

---

# RÈGLES GÉNÉRALES DE DÉVELOPPEMENT

## 1. Travailler par petites étapes

Ne jamais tenter d'implémenter une phase entière en une seule tâche importante.

Découper chaque fonctionnalité en étapes limitées.

Pour chaque fonctionnalité :

1. Définir le comportement attendu.
2. Identifier les dépendances.
3. Examiner les systèmes existants.
4. Implémenter la plus petite version fonctionnelle.
5. Tester le résultat dans Godot.
6. Corriger les problèmes.
7. Vérifier les régressions.
8. Enregistrer les modifications dans Git.
9. Mettre à jour la documentation si nécessaire.

## 2. Ne pas anticiper inutilement

Ne pas développer un système complexe avant d'en avoir besoin.

Ne pas produire des ressources qui ne sont pas encore nécessaires.

Ne pas ajouter de fonctionnalités simplement parce qu'elles sont techniquement possibles.

Chaque fonctionnalité doit apporter une valeur réelle à l'expérience.

## 3. Priorités de développement

L'ordre des priorités est :

1. Fiabilité des interactions.
2. Satisfaction du gameplay.
3. Persistance de l'état du monde.
4. Cohérence de l'identité visuelle.
5. Immersion sonore.
6. Contenu et progression.
7. Optimisation et finitions.

## 4. Validation avant extension

Ne pas construire un immense phare rempli de beaux objets avant d'avoir validé l'expérience consistant à les manipuler, les nettoyer, les ranger et les restaurer.

Le premier atelier doit démontrer que le gameplay principal est agréable.

Le vertical slice doit ensuite démontrer que le niveau de qualité visuelle et sonore est atteignable avec les outils et méthodes disponibles.

Les autres pièces doivent être construites à partir de cette fondation.

## 5. Principe essentiel

The Last Keeper doit rester une expérience contemplative dans laquelle le joueur prend plaisir à restaurer un lieu et à se l'approprier.

La production doit toujours privilégier :
- La qualité des interactions.
- La cohérence de l'univers.
- La satisfaction de la restauration.
- La liberté d'organisation.
- La découverte progressive.
- Une atmosphère mélancolique et réconfortante.

La complexité technique et la quantité de contenu ne doivent jamais devenir des objectifs en soi.