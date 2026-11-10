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
- La première pièce est une zone de tutoriel où se trouvent les outils de nettoyage et de rangement de base (contenu à définir).
- L'atelier est la deuxième pièce. Il introduit la réparation et ses outils, puis sert à améliorer les outils, ceinture à outils comprise. Aucune fabrication d'objets.

## Décisions validées (2026-11-10)

- Plateforme : PC uniquement, mobile abandonné.
- Entrées : clavier/souris de référence. Toutes les entrées passent par des actions de l'Input Map.
- L'ancienne feuille de route (PRODUCTION_ROADMAP) est archivée dans `docs/direction/archive/`.
- Cœur du jeu : nettoyer, ranger et réparer.
- Pièce 1 (zone tutoriel) : nettoyage et rangement. Elle contient les outils de base de nettoyage et de rangement.
- Pièce 2 (atelier) : introduit la réparation et ses outils, puis permet d'améliorer les outils, ceinture comprise. L'atelier ne fabrique jamais d'objets.
- La ceinture reste trouvée dans la pièce 1.
- Les objets et meubles cassés, ainsi que des mécanismes spécifiques (lampe du phare, chaufferie, électricité, etc.) pouvant avoir un impact sur le lore, se réparent.
- Le nettoyage précède la réparation.
- Déroulé de réparation : une étape simple et satisfaisante ; dans certains cas, un remplacement (par exemple un fusible). Aucune collecte de pièces ou de matériaux : les pièces de remplacement sont fournies par la trousse à outils du joueur.
- États visuels : cassé puis réparé, sauf cas particuliers (par exemple la lampe du phare). Une réparation a un effet fonctionnel dans le jeu.
- Six outils au total. Pièce 1 : éponge (nettoyage courant), raclette (vitres et surfaces lisses), serpillière (sols), seau (rincer les outils). Atelier : marteau (réparations du bois et éléments à redresser), outil multifonction (visserie, plomberie, petites réparations ; reprend le rôle de reboucher, colmater et restaurer les surfaces abîmées). Les pièces de remplacement restent fournies par la trousse à outils, distincte de la ceinture.
- La réparation compte dans le 100 %.
- Le 100 % d'une pièce couvre tout ce que la pièce permet de faire avec les mécaniques disponibles à ce stade : la pièce 1 ne compte que le nettoyage et le rangement, sans la réparation ; les pièces suivantes comptent la réparation lorsqu'elle est disponible. La définition technique exacte reste ouverte (GDD §15).
- Plan de production : la phase 4 (pièce 1) contient la boucle « nettoyer, ranger » ; la réparation est introduite en phase 5 avec l'atelier. La phase 2 (prototype de réparation) reste inchangée.
- Non décidé (GDD §15) : liste exacte des outils de nettoyage, mécanique détaillée de la réparation, origine des pièces de remplacement, consommabilité du kit de réparation, liste et nombre des réparations spécifiques.
- Seau : sert à rincer les outils de nettoyage ; sans rinçage, leur efficacité baisse fortement (un outil sale perd jusqu'à 90 % d'efficacité au maximum, jamais 100 %). Le rinçage est un geste court : le joueur tient l'outil sale et interagit avec le seau. Les améliorations du seau permettent de rincer moins souvent ; il est amélioré à l'atelier comme les autres outils. Renouvellement de l'eau retiré du périmètre actuel (piste 💡, GDD §14).
- Rangement (2026-11-10) : zones souples par catégorie d'objets, sans position imposée ; un objet est rangé s'il est hors du sol et hors du désordre.
- Placement libre avec aimantation douce sur les surfaces ; objets figés une fois posés (pas de simulation physique persistante).
- Rotation par paliers (touche ou molette), valeur proposée 15° À CONFIRMER ; chaque objet a des orientations autorisées.
- Empilement : un petit objet posé sur un objet plus gros (exemple : une lampe de table sur un gros carton) ; petits objets empilables entre eux (livres).
- Murs : objets décoratifs et cadres ; pas de plafond (exception possible : réparation d'un lustre). Gros objets portés à deux mains, un seul à la fois.
- Collisions : placement qui chevauche refusé, sauf empilement de petits objets.
- Un objet tombe au sol s'il est lâché ou posé trop près du bord de son support. Un objet tombé fait baisser le 100 %. Une fois le 100 % atteint, il reste acquis définitivement.
- Pièce 1 (tutoriel), 2026-11-10 : apprentissage libre avec indices (le personnage commente à voix haute, sans forcer) ; outils de nettoyage trouvés progressivement ; ceinture = récompense (clé trouvée pendant le rangement, vieux coffre en bois fermé à clé près de la porte de sortie) ; le coffre est le gros objet d'apprentissage (saisie, port à deux mains, dépôt précis, rotation par orientations prédéfinies) ; rinçage du seau découvert seul ; durée visée 15 minutes ; sortie = 100 % ET ceinture ; narration : le nouveau Gardien n'a pas envie d'être là mais le fait pour sa fille malade ; trousse à outils obtenue à l'atelier.
- Outils : outils de nettoyage trouvés progressivement dans la pièce 1 ; outils de réparation trouvés progressivement à l'atelier. La clé du tutoriel est obligatoire (la ceinture qu'elle ouvre est requise pour sortir de la pièce 1).
- Atelier (pièce 2), 2026-11-10 : durée visée 20 minutes ; retour possible à tout moment ; compte dans le 100 % (nettoyage, rangement, réparation) ; outils de réparation (marteau, outil multifonction) trouvés progressivement ; réparations d'apprentissage : remettre le courant, réparer le meuble de l'atelier pour pouvoir l'utiliser (chaise = proposition À CONFIRMER) ; amélioration : items d'amélioration trouvés dans les pièces suivantes, clic sur le meuble de l'atelier = menu d'amélioration, arbre entier visible d'avance avec indication de ce qui est faisable, clic sur l'amélioration avec l'item pour valider, l'item ne compte pas dans la ceinture ; arbres par type d'objet (outil) de 3 ou 4 améliorations ; éponge abrasive en début d'arbre de l'éponge ; améliorations = simples réglages de paramètres (plus rapide, surface plus large, outil qui se salit moins vite), sans nouvelle mécanique ; narration : outils de l'ancien gardien, notes et plan du phare, tout laissé en plan.
- Saleté et outils (2026-11-10) : poussière et traces = éponge ; vitres = éponge puis raclette ; sols = serpillière ; rouille superficielle = éponge abrasive (amélioration, après l'atelier) ; métal profondément corrodé = réparation après un traitement (non défini).
- Catégories d'objets (2026-11-10) : petits (à la main, un à la fois ; ceinture = 1 emplacement au départ, jusqu'à 5), moyens (à la main), gros (deux mains), fixes (non déplaçables).

## Décisions en attente (GDD §15)

1. Liste exacte des outils de nettoyage et de rangement trouvés dans la pièce 1.
2. Définition technique du 100 % (nettoyage, réparation, rangement).
3. Liste des pièces et graphe des embranchements.
4. Nombre d'orientations prédéfinies par objet ou famille.
5. Catalogue des améliorations d'outils et ordre de déblocage (sans coût en matériaux : déblocage par la récupération d'items d'amélioration).
6. Contenu restant de la pièce 1 et de l'atelier (points ouverts au GDD §15).
7. Langues de sous-titrage supplémentaires.
8. Détails des sauvegardes, contrôles et compatibilité par plateforme.

## Propositions non validées

- Préparer en parallèle, dès la phase 1, des références visuelles et un comparatif de génération 3D par IA (2 outils, 3 objets), sans abonnement.

## Bloqué

Rien.

## Archive

`docs/direction/archive/PRODUCTION_ROADMAP.md` : ancienne feuille de route, obsolète. À reprendre plus tard si le GDD le confirme : pipeline 3D assisté par IA (§3.1 à 3.3) et catalogue d'améliorations (§5.1).
