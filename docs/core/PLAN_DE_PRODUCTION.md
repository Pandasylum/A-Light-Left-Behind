# A LIGHT LEFT BEHIND — Plan de production

Dernière mise à jour : 2026-11-09  
Statut : plan de réalisation proposé à partir du GDD validé. L'ordre est une recommandation de production, pas une nouvelle décision de contenu.

## 1. Principe directeur

Construire d'abord une **vertical slice** : une première pièce jouable qui contient la boucle centrale complète (explorer, nettoyer, réparer, déplacer/ranger, découvrir, valider). Ne pas produire toutes les pièces avant d'avoir vérifié que cette boucle est agréable, compréhensible et techniquement fiable.

Le plan est organisé par dépendances et livrables. Les durées ne sont pas estimées : elles dépendront du moteur, de l'état actuel du projet, des outils déjà en place et du temps disponible.

## 2. Périmètre de production

### Indispensable pour la première version

- Jeu solo à la première personne, PC uniquement.
- Déplacement, interaction, nettoyage, réparation, manipulation et rangement.
- Progression guidée avec embranchements, validation de restauration à 100 % et découvertes facultatives séparées.
- Outils de base disponibles dans la première pièce ; améliorations progressives via un atelier dédié, probablement la deuxième pièce.
- Journal, documents, notes et pensées orales du nouveau gardien.
- Sauvegarde locale, menus, cinématiques, audio, sous-titres français et retours joueur.
- Campagne complète, conclusion et exploration libre après la campagne.

### Hors périmètre de la première version

- Coopération à deux joueurs.
- Sous-sol, cabanon et autres espaces d'extension non planifiés.
- Passage sous le phare jusqu'à la côte.
- Fabrication d'objets à l'atelier.

## 3. Phases de production

### Phase 0 — Audit et fondations du projet

**Objectif :** connaître l'état réel du projet et éviter de bâtir les nouveaux systèmes sur une structure fragile.

Tâches :
- Faire l'inventaire du projet existant : moteur, scènes/niveaux, scripts, assets, dépendances, plateformes déjà testées.
- Identifier les systèmes déjà fonctionnels et ceux qui sont seulement expérimentaux.
- Définir une structure de dossiers claire pour scripts, scènes, matériaux, modèles, sons, musique, UI, sauvegardes et documentation.
- Séparer les systèmes réutilisables du contenu propre à une pièce.
- Mettre en place une convention de nommage et un suivi des tâches/bugs.
- Mettre à jour les documents de référence pour utiliser le titre **A Light Left Behind** et supprimer les anciennes références contradictoires à **The Last Keeper**.

**Livrable / sortie :** projet audité, structure claire, liste des systèmes existants, liste des risques techniques et backlog priorisé.

**Dépendance :** aucune. Cette phase peut être courte si le projet est déjà propre.

### Phase 1 — Prototype des interactions fondamentales

**Objectif :** valider les sensations de base avant de créer le contenu.

Tâches :
- Déplacement à la première personne : marche, déplacement lent, caméra et collisions.
- Détection d'objet regardé et à portée.
- Interaction contextuelle : prendre, utiliser, déposer, ouvrir/consulter.
- Prise en main d'un objet et caméra éventuellement verrouillée.
- Placement sur surface avec orientations prédéfinies.
- Déplacement d'un meuble libre et distinction avec les installations fixes.
- Commandes PC (clavier/souris).
- Première version de l'inventaire et changement rapide de l'objet tenu.

**Livrable / sortie :** scène grise de test où le joueur peut se déplacer, interagir, prendre, transporter, orienter et placer quelques objets sans blocage.

**Critères de validation :** les interactions sont compréhensibles sans explication constante ; le placement est prévisible ; les contrôles sont utilisables à la souris/clavier.

### Phase 2 — Prototype du nettoyage et de la réparation

**Objectif :** rendre la transformation de l'environnement agréable et mesurable.

Tâches :
- Choisir un petit ensemble représentatif de surfaces, salissures et matériaux.
- Implémenter l'application des outils et la progression visuelle de la saleté.
- Définir les retours visuels et sonores de contact, progression et achèvement.
- Implémenter les étapes de réparation et les variantes selon le matériau.
- Définir la mesure de progression par surface et par objet.
- Tester les performances sur PC, notamment sur les surfaces de grande taille.

**Livrable / sortie :** petit espace de test où plusieurs types de surfaces peuvent être nettoyés et quelques objets réparés de bout en bout.

**Critères de validation :** le joueur comprend ce qui est nettoyable/réparable ; le résultat est visible ; la progression est stable et ne se bloque pas à cause d'un résidu imperceptible.

### Phase 3 — Prototype du rangement et de la validation à 100 %

**Objectif :** transformer la règle de complétion du GDD en système fiable.

Tâches :
- Définir pour chaque objet sa catégorie, son état de restauration et ses emplacements logiques autorisés.
- Implémenter les orientations prédéfinies par objet ou famille.
- Définir ce qui compte comme rangement terminé : objet dans un emplacement logique valide, meuble libre positionné et autres critères nécessaires.
- Implémenter la progression de rangement sans imposer une disposition décorative unique.
- Séparer strictement les objectifs obligatoires (nettoyage, réparation, rangement) des découvertes facultatives (clés, lore, souvenirs, objets d'histoire).
- Créer un écran ou indicateur de progression de pièce qui explique clairement les éléments restants.
- Tester les cas limites : objets déplacés après validation, objets manquants, objets empilés, meubles déplacés, retour dans une pièce précédente.

**Livrable / sortie :** une pièce test qui peut être validée à 100 % sans devoir collecter les objets narratifs facultatifs.

**Critères de validation :** chaque pourcentage est explicable et reproductible ; aucun pixel invisible ne bloque la fin ; le joueur conserve une vraie liberté de placement.

### Phase 4 — Vertical slice : première pièce tutorielle

**Objectif :** assembler la boucle complète dans une vraie pièce représentative.

Tâches :
- Construire la première pièce avec son état abandonné, ses surfaces, ses meubles et ses objets.
- Y placer les outils de base à découvrir ; tous les outils de base prévus sont accessibles dès cette première pièce.
- Y placer la ceinture de transport : le joueur ne la possède pas au départ et la trouve dans cette pièce.
- Introduire les commandes et interactions progressivement, sans transformer le tutoriel en long texte.
- Ajouter quelques objets narratifs facultatifs et les premières entrées du journal.
- Ajouter une première pensée orale du nouveau gardien si le rythme narratif le justifie.
- Ajouter les sons et l'éclairage de base.
- Faire tester la pièce par des personnes qui ne connaissent pas le projet.
- Corriger les incompréhensions, les gestes pénibles, les bugs et le rythme.

**Livrable / sortie :** première pièce complète, jouable du début à sa validation, avec nettoyage, réparation, rangement, découverte et sauvegarde de progression.

**Jalon majeur :** ne pas passer à la production en série des autres pièces tant que cette vertical slice n'est pas satisfaisante.

### Phase 5 — Systèmes de progression, inventaire et atelier

**Objectif :** rendre la boucle extensible à toute la campagne.

Tâches :
- Finaliser l'inventaire et le transport des petits objets.
- Implémenter la ceinture : capacité de départ de 1 petit objet (en plus de l'objet tenu en main), +1 par amélioration à l'atelier, plafond de 5 petits objets (soit 4 améliorations).
- Implémenter le déblocage des améliorations selon les pièces restaurées et les matériaux récupérés naturellement.
- Construire la pièce dédiée à l'atelier, probablement la deuxième pièce restaurée.
- Créer l'interface d'amélioration des outils ; aucune fabrication d'objets.
- Implémenter les améliorations modestes et leurs effets.
- Créer le graphe de progression des pièces : ordre principal et embranchements.
- Implémenter la validation de pièce et le déblocage de la suite.

**Livrable / sortie :** progression jouable entre les premières pièces, avec atelier et première amélioration fonctionnelle.

### Phase 6 — Journal, narration et découvertes

**Objectif :** intégrer la narration sans ralentir ni bloquer la restauration.

Tâches :
- Implémenter le journal et ses catégories, index alphabétique, symboles d'entrées inconnues et distinction lu/non lu.
- Ajouter la couverture évolutive, illustrations agrandissables, dessins/croquis et annotations de l'ancien gardien.
- Gérer explicitement l'incertitude des notes de l'ancien gardien : hypothèses et impressions restent subjectives.
- Ajouter les pensées orales préécrites du nouveau gardien et leurs déclencheurs.
- Ajouter les documents, lettres, photographies, objets personnels, souvenirs, clés et éléments d'histoire.
- Ajouter les notifications de découverte, sans historique de notifications.
- Ajouter les contenus audio uniquement pour les objets qui le justifient.
- Vérifier que les contenus inconnus ne sont jamais révélés par les écrans de chargement ou le journal.

**Livrable / sortie :** une chaîne de découvertes cohérente et facultative, testée dans les premières pièces.

### Phase 7 — Production des pièces et du contenu de campagne

**Objectif :** produire les pièces restantes à partir des systèmes validés.

Tâches :
- Définir la liste finale des pièces, leurs dépendances et les embranchements.
- Pour chaque pièce, établir une fiche de contenu : état initial, surfaces, matériaux, objets à nettoyer/réparer/ranger, meubles déplaçables, outils utiles, matériaux récupérables, découvertes facultatives, ambiance et critères de validation.
- Produire les pièces et leur progression de restauration.
- Créer les transitions et chargements propres à chaque destination.
- Ajuster le niveau d'encombrement et la quantité de tâches pour conserver un rythme agréable.
- Réutiliser les systèmes communs ; éviter les scripts spécifiques quand une donnée de configuration suffit.

**Livrable / sortie :** campagne complète jouable du début à la dernière pièce, même si certains éléments artistiques restent temporaires.

### Phase 8 — Menus, sauvegarde et expérience complète

**Objectif :** rendre le jeu utilisable de bout en bout sans intervention du développeur.

Tâches :
- Menu principal, Continuer, Nouvelle partie avec confirmation, Options, Succès et Crédits.
- Afficher pièce/progression et date/heure de dernière sauvegarde.
- Sauvegarde automatique locale et notification discrète.
- Export/import de sauvegarde, validation d'intégrité et compatibilité avant remplacement.
- Persistance indépendante des succès lors d'une remise à zéro.
- Écran de chargement illustré, phrases déjà découvertes, barre de progression et fondu au noir.
- HUD masquable, indicateurs contextuels, journal en pause et inventaire sans pause.
- Formulaire externe de feedback et avertissement lors d'une tentative de quitter pendant une action importante.
- Illustration du menu avant/après fin de campagne et résumé de fin consultable.

**Livrable / sortie :** boucle complète du lancement à la fin, sauvegarde et reprise comprises.

### Phase 9 — Cinématiques, audio et finition artistique

**Objectif :** donner au phare son identité émotionnelle et finaliser la présentation.

Tâches :
- Cinématique d'arrivée en bateau et dialogue du passeur.
- Cinématique finale du phare rallumé et décision du nouveau gardien.
- Règles de lecture : première lecture obligatoire, puis passage possible avec Échap.
- Voix françaises et sous-titres ; finaliser les textes et synchronisations.
- Ambiance sonore froide au début puis plus douce à l'intérieur au fil de la restauration ; extérieur toujours exposé et froid.
- Musique discrète, sons de nettoyage, réparation, rangement, journal, notifications et interactions.
- Éclairage, effets atmosphériques, détails visuels et transitions.

**Livrable / sortie :** version complète avec narration audiovisuelle et identité visuelle cohérente.

### Phase 10 — QA, équilibrage et sortie

**Objectif :** fiabiliser le jeu sur les plateformes cibles.

Tâches :
- Tester chaque pièce à 100 % dans plusieurs ordres de découverte.
- Vérifier qu'aucun objet facultatif n'est requis pour progresser.
- Tester les embranchements, retours aux pièces précédentes et modifications après validation.
- Tester les sauvegardes, imports invalides, exports, nouvelles parties et réinitialisations.
- Tester PC (clavier/souris), différentes résolutions et performances.
- Vérifier les sous-titres, volumes, lisibilité des indications et options.
- Faire tester par des joueurs novices et recueillir les retours sur le rythme, la clarté et la fatigue liée au rangement.
- Corriger les bugs bloquants et les problèmes de progression avant les défauts mineurs.
- Préparer la page itch.io, la version publiée et les informations de retour joueur.

**Livrable / sortie :** version candidate à la publication, testée du début à la fin.

## 4. Dépendances principales

```text
Audit du projet
      ↓
Déplacements et interactions
      ↓
Nettoyage + réparation
      ↓
Rangement + critères de validation à 100 %
      ↓
Première pièce complète (vertical slice)
      ↓
Progression + atelier + inventaire
      ↓
Journal et narration ─────────┐
      ↓                       │
Production des pièces         │
      └───────────────┬───────┘
                      ↓
       Menus + sauvegarde + cinématiques
                      ↓
          Audio et finition artistique
                      ↓
                 QA et sortie
```

Certaines tâches peuvent avancer en parallèle une fois leurs dépendances stabilisées : par exemple, préparer les textes et documents narratifs pendant le prototypage des interactions, sans intégrer trop tôt tous les contenus dans le jeu.

## 5. Ordre de priorité en cas de manque de temps

1. Fiabilité de la boucle centrale : nettoyer, réparer, ranger et valider.
2. Confort des déplacements et interactions sur PC.
3. Progression sans blocage et sauvegarde fiable.
4. Campagne complète et conclusion compréhensible.
5. Journal et narration essentielle.
6. Ambiance sonore et visuelle.
7. Contenus secondaires, détails et améliorations de confort.

Ne pas sacrifier la lisibilité de la restauration ou la stabilité des sauvegardes pour ajouter des découvertes facultatives.

## 6. Risques à surveiller

| Risque | Prévention / réponse |
|---|---|
| Le 100 % devient une chasse au pixel | Comptabiliser des unités de surface/objets explicites ; fournir un indicateur clair des éléments restants ; tester les cas limites. |
| Le rangement devient une corvée ou limite trop la créativité | Valider un emplacement logique plutôt qu'une position décorative exacte ; garder un placement libre dans les contraintes prévues. |
| Trop de contenu est produit avant validation du gameplay | Exiger une vertical slice satisfaisante avant la production en série des pièces. |
| Les systèmes deviennent difficiles à réutiliser | Séparer les systèmes communs des données propres à chaque pièce. |
| Les découvertes facultatives bloquent la campagne | Séparer leurs flags et compteurs des critères de restauration. |
| Les sauvegardes importées corrompent la progression | Valider intégrité et compatibilité avant toute écriture ; conserver la sauvegarde actuelle en cas d'échec. |
| La portée du projet gonfle | Garder coopération et extensions hors périmètre initial. |

## 7. Définition de « terminé » par pièce

Une pièce est prête à être considérée comme terminée lorsque :

- toutes les surfaces et tous les objets obligatoires atteignent leur état de nettoyage requis ;
- toutes les réparations obligatoires sont terminées ;
- tous les objets concernés sont rangés dans un emplacement logique valide ;
- le calcul affiche 100 % pour les trois axes : nettoyage, réparation, rangement ;
- les découvertes facultatives peuvent rester non trouvées ;
- la pièce peut être quittée puis revisitée sans perdre son état ni casser la progression.

La définition technique des unités comptabilisées doit être décidée pendant les phases 2 et 3 et testée avant de produire les pièces en série.

## 8. Suivi de production

Pour chaque tâche, utiliser les statuts : **À faire**, **En cours**, **À tester**, **Bloqué**, **Terminé**.

Chaque tâche devrait préciser :
- son résultat attendu ;
- ses dépendances ;
- un critère de validation observable ;

### Prochaine étape concrète

Commencer par la **Phase 0 — Audit et fondations** : relever ce qui existe déjà dans le projet, ce qui fonctionne réellement et ce qui doit être repris. Ensuite, attaquer la Phase 1 sans ajouter de contenu de campagne tant que les interactions fondamentales ne sont pas validées.

---

**Document de conception :** `GDD.md`  
**Plan de réalisation :** `PLAN_DE_PRODUCTION.md`
