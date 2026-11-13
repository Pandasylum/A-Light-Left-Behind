# A LIGHT LEFT BEHIND — ROADMAP

Dernière mise à jour : 2026-11-13
Suivi de production. Le détail des phases est dans `PLAN_DE_PRODUCTION.md`. Les décisions de conception sont dans `GDD.md`, qui prévaut en cas de contradiction.

Statuts : À faire · En cours · À tester · Bloqué · Terminé

## Phases

| Phase | Intitulé | Statut | Dépend de |
|---|---|---|---|
| 0 | Audit et fondations du projet | En cours | — |
| 1 | Prototype des interactions fondamentales | À faire | 0 |
| 2 | Prototype du nettoyage et de la réparation | À faire | 1 |
| 3 | Prototype du rangement et de la validation à 100 % | À faire | 2 |
| 4 | Première pièce : vestibule (tutoriel nettoyage et rangement) | À faire | 3 |
| 5 | Systèmes de progression, inventaire et atelier ; fin de la vertical slice (vestibule + atelier + hub, jalon majeur) | À faire | 4 |
| 6 | Journal, narration et découvertes | À faire | 5 |
| 7 | Production des pièces et du contenu de campagne | À faire | 5, 6 |
| 8 | Menus, sauvegarde et expérience complète | À faire | 7 |
| 9 | Cinématiques, audio et finition artistique | À faire | 8 |
| 10 | QA, équilibrage et sortie | À faire | 9 |

Règle : pas de production en série des pièces (phase 7) tant que la vertical slice (fin de la phase 5) n'est pas jugée satisfaisante.

## En cours — Phase 0

- [Terminé] Assainissement documentaire : renommage, ROADMAP.md, README.md.
- [À faire] Audit ou initialisation du dépôt Godot 4.7.2 : structure de dossiers, conventions de nommage, suivi des bugs.
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
- Six outils au total, dont cinq à emplacement dédié et le seau, objet libre MEDIUM (décision validée le 2026-11-11). Chaque outil de nettoyage et de réparation a un emplacement dédié, distinct de la main et de la ceinture ; le seau fait exception : c'est un objet libre de catégorie MEDIUM (et non un outil à emplacement dédié), exclu du calcul du 100 % (décision validée le 2026-11-11). Pièce 1 : éponge (nettoyage courant), raclette (vitres et surfaces lisses), serpillière (sols), seau (rincer les outils). Atelier : marteau (réparations du bois et éléments à redresser), outil multifonction (visserie, plomberie, petites réparations ; reprend le rôle de reboucher, colmater et restaurer les surfaces abîmées). Les pièces de remplacement restent fournies par la trousse à outils, distincte de la ceinture.
- La réparation compte dans le 100 %.
- Le 100 % d'une pièce couvre tout ce que la pièce permet de faire avec les mécaniques disponibles à ce stade : la pièce 1 ne compte que le nettoyage et le rangement, sans la réparation ; les pièces suivantes comptent la réparation lorsqu'elle est disponible. La définition technique exacte reste ouverte (GDD §15).
- Plan de production : la phase 4 (pièce 1) contient la boucle « nettoyer, ranger » ; la réparation est introduite en phase 5 avec l'atelier. La phase 2 (prototype de réparation) reste inchangée.
- Non décidé (GDD §15) : mécanique détaillée de la réparation, origine des pièces de remplacement, liste et nombre des réparations spécifiques.
- Seau : sert à rincer les outils de nettoyage ; sans rinçage, leur efficacité baisse fortement (un outil sale perd jusqu'à 90 % d'efficacité au maximum, jamais 100 %). Le rinçage ne demande pas de prendre le seau : le seau reste au sol. Le rinçage utilise une touche d'interaction distincte de la touche de prise (touche exacte : réglage technique, non décidée ici). Le geste est court : l'outil sale est en main et le joueur interagit avec le seau (décision validée le 2026-11-11). Les améliorations du seau permettent de rincer moins souvent ; il est amélioré à l'atelier comme les autres outils. Renouvellement de l'eau retiré du périmètre actuel (piste 💡, GDD §14).
- Rangement (2026-11-10) : zones souples par catégorie d'objets, sans position imposée ; un objet est rangé s'il est hors du sol et hors du désordre.
- Placement libre avec aimantation douce sur les surfaces ; objets figés une fois posés (pas de simulation physique persistante).
- Rotation par paliers (touche ou molette), valeur proposée 15° À CONFIRMER ; chaque objet a des orientations autorisées.
- Empilement : un petit objet posé sur un objet plus gros (exemple : une lampe de table sur un gros carton) ; petits objets empilables entre eux (livres).
- Murs : objets décoratifs et cadres ; pas de plafond (exception possible : réparation d'un lustre). Gros objets portés à deux mains, un seul à la fois.
- Collisions : placement qui chevauche refusé, sauf empilement de petits objets.
- Un objet tombe au sol s'il est lâché ou posé trop près du bord de son support. Un objet tombé fait baisser le 100 %. Une fois le 100 % atteint, il reste acquis définitivement.
- Pièce 1 (tutoriel), 2026-11-10 : apprentissage libre avec indices (le personnage commente à voix haute, sans forcer) ; outils de nettoyage trouvés progressivement ; ceinture = récompense (clé trouvée pendant le rangement, vieux coffre en bois fermé à clé près de la porte de sortie) ; le coffre est le gros objet d'apprentissage (saisie, port à deux mains, dépôt précis, rotation par orientations prédéfinies) ; rinçage du seau découvert seul ; durée visée 15 minutes ; sortie = 100 % ET ceinture ; narration : le nouveau Gardien n'a pas envie d'être là mais le fait pour sa fille malade ; trousse à outils obtenue à l'atelier.
- Outils : outils de nettoyage trouvés progressivement dans la pièce 1 ; outils de réparation trouvés progressivement à l'atelier. La clé du tutoriel est obligatoire (la ceinture qu'elle ouvre est requise pour sortir de la pièce 1).
- Atelier (pièce 2), 2026-11-10 : durée visée 20 minutes ; retour possible à tout moment ; compte dans le 100 % (nettoyage, rangement, réparation) ; outils de réparation (marteau, outil multifonction) trouvés progressivement ; réparations d'apprentissage : lancer le générateur de secours de l'atelier, réparer le meuble de l'atelier pour pouvoir l'utiliser (chaise = proposition À CONFIRMER) ; amélioration : items d'amélioration trouvés dans les pièces suivantes, clic sur le meuble de l'atelier = menu d'amélioration, arbre entier visible d'avance avec indication de ce qui est faisable, clic sur l'amélioration avec l'item pour valider, l'item ne compte pas dans la ceinture ; arbres par type d'objet (outil) de 3 ou 4 améliorations ; éponge abrasive en début d'arbre de l'éponge ; améliorations = simples réglages de paramètres (plus rapide, surface plus large, outil qui se salit moins vite), sans nouvelle mécanique ; narration : outils de l'ancien gardien, notes et plan du phare, tout laissé en plan.
- Saleté et outils (2026-11-10) : poussière et traces = éponge ; vitres = éponge puis raclette ; sols = serpillière ; rouille superficielle = éponge abrasive (amélioration, après l'atelier) ; métal profondément corrodé = réparation après un traitement (non défini). mousse sur pierre = éponge (2026-11-11) ; mousse tenace plus tard, non défini.
- Catégories d'objets (2026-11-10) : petits (à la main, un à la fois ; ceinture = 1 emplacement au départ, jusqu'à 5), moyens (à la main ; exception : le seau, objet libre MEDIUM, décision validée le 2026-11-11), gros (deux mains), fixes (non déplaçables).
- Graphe des pièces (2026-11-10) : 7 pièces principales, hub et atelier compris, plus la pièce 1 (tutoriel) ; 45 min à 1 h par pièce principale, environ 7 h au total, contenu produit par étapes ; structure noyau de départ → hub central (rez-de-chaussée) → branches de restauration → étages supérieurs → sommet du phare ; hub = point central de circulation, portes verrouillées débloquées progressivement, hub à restaurer ; atelier collé au hub, ouvert, tutoriel ; une pièce se débloque quand la précédente de sa branche est à 100 % ; branches explorables en parallèle, ordre de certaines pièces libre, seul le dernier étage (lampe) reste bloqué tant que le reste n'est pas terminé ; étages supérieurs accessibles progressivement, lanterne au sommet = aboutissement ; chaque pièce principale à 100 % (nettoyée, rangée, réparée selon ce que la pièce permet), 100 % acquis conservé, pièces restaurées accessibles et réorganisables ; objets narratifs, clés et découvertes facultatifs (sauf clé du tutoriel) ; après la campagne : exploration libre et restauration complémentaire ; extérieur non jouable pour l'instant (visible par les fenêtres) ; atmosphère du froid vers le chaleureux avec la progression ; aucune nouveauté de mécanique imposée par pièce (à revoir avec une extension) ; principes : éviter la linéarité complète, liberté sans monde ouvert, systèmes réutilisés et espaces indépendants, architecture simple ; escalier central dans le hub, débloqué quand toutes les zones autour du hub sont à 100 %. Pistes non engagées : trappe vers un sous-sol menant à un tunnel ; cabanon extérieur. Points ouverts : GDD §15.
- Liste des pièces (2026-11-10) : 7 pièces principales, hub et atelier compris ; pièce 1 (tutoriel) = vestibule d'entrée, 8e zone jouable distincte. Rez-de-chaussée : hall central (hub, escalier central), cuisine, salon, atelier. Premier étage : chambre, salle d'archives. Sommet : salle de la lanterne. Escalier central débloqué quand cuisine, salon et atelier sont à 100 %. Exception à la règle « une pièce se débloque quand la précédente est à 100 % » : le hub est accessible sans que l'atelier soit à 100 %.
- Réparations particulières (2026-11-10) : hall central (installation électrique générale, interrupteurs, éclairage, câblage) ; cuisine (robinetterie, évier, tuyauterie, équipements) ; salon (cheminée, conduits, mobilier à restauration particulière) ; atelier (établi, éclairage technique, prises, équipements d'amélioration) ; chambre (mobilier abîmé, lit, armoire, bois) ; salle d'archives (étagères, tiroirs, boîtes, mobilier de conservation) ; salle de la lanterne (mécanisme optique, rotation, alimentation lumineuse, signalisation). Réparation signature par pièce : hall central, tableau électrique ; cuisine, évier et robinetterie ; salon, cheminée ; atelier, établi ; chambre, lit du gardien ; salle d'archives, meuble à tiroirs ; salle de la lanterne, mécanisme et lampe ; autres réparations classiques (bois, métal, surfaces, mobilier).
- Vertical slice (2026-11-10) : vestibule + atelier + hub, terminée à la fin de la phase 5 ; la phase 4 produit le vestibule seul ; la production en série (phase 7) attend que la slice soit satisfaisante.
- Courant (2026-11-10) : l'atelier se lance avec un générateur de secours ; le personnage indique de chercher l'installation électrique générale en priorité dans le hub, où se trouve le tableau principal et où elle se répare. « Remettre le courant » n'est plus une réparation d'apprentissage de l'atelier.
- Chaufferie (2026-11-10) : au sous-sol, dans l'extension prévue (trappe vers le tunnel), hors des 7 pièces ; le jeu de base garde le chauffage via la cheminée du salon et la plomberie de la cuisine.
- Direction artistique (2026-11-10, principe) : palette commune, variations par pièce, lumière froide puis plus chaude ; détails dans ART_BIBLE.md.
- Cadre narratif (2026-11-13) : le nouveau gardien ignorait l'état réel du phare (lampe hors service, bâtiment abandonné, informations cachées) et le départ de son prédécesseur ; le mauvais temps l'empêche de repartir ; sa fille n'apparaît jamais et existe dans ses pensées ; départ de l'ancien gardien, panne de la lampe, légende du passeur et chronologie non décidés (incertitude préservée). Aucun lore rattaché au sous-sol, à la chaufferie ni au tunnel. Détails : GDD §1, §14, §15 pt 31.
- Structure du phare (2026-11-13, détail : GDD §5 et §6) : maison accolée à la tour ; la tour est le hub et sert de passage commun (N0, N1, N2), le fût (rayon 2,0 m) est dans ce passage, avec une porte fût/passage à chaque niveau. N0 = vestibule, atelier, cuisine, salon, hub (ordre vestibule → atelier → hub, atelier à côté du hub). N1 = chambre + bureau en une seule grande pièce (bureau = zone). N2 = archives + machinerie. N3 = lanterne. Toujours 7 pièces principales. Machinerie : petite pièce séparée dans la moitié basse du fût au N2, bloc de maçonnerie dessous, « zone de la lampe » avec la lanterne, verrouillée jusqu'à la lanterne et exclue de « le reste » ; sa clé se trouve dans la lanterne (décision du 2026-11-13). Porte du fût (module « mur avec ouverture » 30°, décision du 2026-11-12 reformulée) verrouillée tant que cuisine, salon et atelier ne sont pas à 100 %. Escalier arrêté au palier N2 ; échelle vers la lanterne par une trappe à côté de la machinerie, verrouillée tant que « le reste » n'est pas à 100 % ; environ 10 m de hauteur conservés. Règle de l'échelle : objet moyen ou gros en main = refusé, petit objet = ceinture si place libre sinon refusé, vérification avant la montée. Montée automatique : animée la première fois (fentes de lumière, vent, fondu à mi-hauteur), transition courte ensuite, appui long pour passer (durée non décidée).

## Dépendances à suivre

- Phase 3 — fin de surface (GDD §4, §15 pt 30) : autosave à la fin d'une surface, retour de fin (visuel : Art ; sonore : Sound Design), découpage des surfaces par Art.
- Menu (GDD §10) : écran-titre, pause, Options, Recommencer.

## Décisions en attente (GDD §15)

1. Liste exacte des outils de nettoyage et de rangement trouvés dans la pièce 1.
2. Définition technique du 100 % (nettoyage, réparation, rangement).
3. Graphe des embranchements (liste des pièces et niveaux réglés le 2026-11-13 ; voir points ouverts de la structure du phare ci-dessous).
4. Nombre d'orientations prédéfinies par objet ou famille.
5. Catalogue des améliorations d'outils et ordre de déblocage (sans coût en matériaux : déblocage par la récupération d'items d'amélioration).
6. Contenu restant de la pièce 1 et de l'atelier (points ouverts au GDD §15).
7. Langues de sous-titrage supplémentaires.
8. Détails des sauvegardes, contrôles et compatibilité par plateforme.

## Points ouverts (surfaces et menu)

- Texte de l'alerte de Recommencer.
- Ruptures visibles du noyau (Art).
- Règle de contenu « une surface démarre bien au-dessus de son seuil » (World & Content).

## Points ouverts (structure du phare, 2026-11-13)

- 🟡 Position de la porte extérieure du bâtiment (proposition : côté vestibule).
- 🟡 Position du tableau électrique dans le passage.
- 🟡 Quelles portes (cuisine, salon) sont verrouillées au départ.
- 🟡 Place disponible dans le fût au N2 (machinerie + palier + échelle) : à vérifier à l'échelle réelle par Art.

## Propositions non validées

- Préparer en parallèle, dès la phase 1, des références visuelles et un comparatif de génération 3D par IA (2 outils, 3 objets), sans abonnement.

## Bloqué

Rien.

## Archive

`docs/direction/archive/PRODUCTION_ROADMAP.md` : ancienne feuille de route, obsolète. À reprendre plus tard si le GDD le confirme : pipeline 3D assisté par IA (§3.1 à 3.3) et catalogue d'améliorations (§5.1).
