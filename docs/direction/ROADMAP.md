# A LIGHT LEFT BEHIND — ROADMAP

Dernière mise à jour : 2026-11-10
Suivi de production. Le détail des phases est dans `PLAN_DE_PRODUCTION.md`. Les décisions de conception sont dans `GDD.md`, qui prévaut en cas de contradiction.

Statuts : À faire · En cours · À tester · Bloqué · Terminé

## Phases

| Phase | Intitulé | Statut | Dépend de |
|---|---|---|---|
| 0 | Audit et fondations du projet | En cours | — |
| 1 | Prototype des interactions fondamentales | À faire | 0 |
| 2 | Prototype du nettoyage et de la réparation | À faire | 1 |
| 3 | Prototype du rangement et de la validation à 100 % | À faire | 2 |
| 4 | Vertical slice : première pièce tutorielle (jalon majeur) | À faire | 3 |
| 5 | Systèmes de progression, inventaire et atelier | À faire | 4 |
| 6 | Journal, narration et découvertes | À faire | 5 |
| 7 | Production des pièces et du contenu de campagne | À faire | 5, 6 |
| 8 | Menus, sauvegarde et expérience complète | À faire | 7 |
| 9 | Cinématiques, audio et finition artistique | À faire | 8 |
| 10 | QA, équilibrage et sortie | À faire | 9 |

Règle : pas de production en série des pièces (phase 7) tant que la vertical slice (phase 4) n'est pas jugée satisfaisante.

## En cours — Phase 0

- [Terminé] Assainissement documentaire : renommage, ROADMAP.md, README.md.
- [À faire] Audit ou initialisation du dépôt Godot 4.6 : structure de dossiers, conventions de nommage, suivi des bugs.
- [À faire] Backlog priorisé et liste des risques techniques.

## Décisions validées (2026-11-09)

- Le GDD prévaut sur toute ancienne feuille de route.
- Titre du jeu : A Light Left Behind.
- La première pièce est une zone de tutoriel où se trouvent tous les outils de base (contenu à définir).
- L'atelier est la deuxième pièce. Il sert uniquement à améliorer les outils, ceinture à outils comprise, que le joueur possède déjà. Aucune fabrication d'objets.

## Décisions validées (2026-11-10)

- Plateforme : PC uniquement, mobile abandonné.
- Entrées : clavier/souris de référence. Toutes les entrées passent par des actions de l'Input Map.
- L'ancienne feuille de route (PRODUCTION_ROADMAP) est archivée dans `docs/direction/archive/`.
- Cœur du jeu : nettoyer, ranger et réparer.
- Pièce 1 (zone tutoriel) : nettoyage et rangement. Elle contient les outils de base de nettoyage et de rangement.
- Pièce 2 (atelier) : introduit la réparation et ses outils, puis permet d'améliorer les outils, ceinture comprise. L'atelier ne fabrique jamais d'objets.
- La ceinture reste trouvée dans la pièce 1.
- Non décidé (GDD §15) : liste exacte des outils de nettoyage, liste des outils de réparation, mécanique de réparation.

## Décisions en attente (GDD §15)

1. Liste exacte des outils de base.
2. Définition technique du 100 % (nettoyage, réparation, rangement).
3. Liste des pièces et graphe des embranchements.
4. Nombre d'orientations prédéfinies par objet ou famille.
5. Liste, ordre et coûts des améliorations d'outils.
6. Contenu de la première pièce tutorielle et de l'atelier.
7. Langues de sous-titrage supplémentaires.
8. Détails des sauvegardes, contrôles et compatibilité par plateforme.

## Propositions non validées

- Préparer en parallèle, dès la phase 1, des références visuelles et un comparatif de génération 3D par IA (2 outils, 3 objets), sans abonnement.

## Bloqué

Rien.

## Archive

`docs/direction/archive/PRODUCTION_ROADMAP.md` : ancienne feuille de route, obsolète. À reprendre plus tard si le GDD le confirme : pipeline 3D assisté par IA (§3.1 à 3.3) et catalogue d'améliorations (§5.1).
