# A LIGHT LEFT BEHIND — Game Design Document

Dernière mise à jour : 2026-11-10  
Statut : document de référence des décisions de conception validées.

**Légende** : ✅ décision validée · 💡 piste non engagée · 🟡 à préciser pendant le prototypage

Le GDD décrit le jeu voulu. Les choix techniques détaillés et l'ordre de réalisation sont consignés dans `PLAN_DE_PRODUCTION.md`. Ne pas transformer une piste ou un point à préciser en fonctionnalité promise sans validation.

---

## 1. Concept et intention ✅

**A Light Left Behind** est un jeu solo à la première personne centré sur le nettoyage, la réparation, la restauration et le rangement d'un ancien phare abandonné, construit sur un rocher isolé au large.

Le joueur incarne le nouveau gardien du phare. Le départ du précédent gardien est mystérieux ; le joueur en découvre progressivement les raisons à travers les lieux, les objets et les traces laissées derrière lui.

L'expérience recherchée est calme, immersive, mélancolique et satisfaisante. Le plaisir vient autant de la transformation visible des espaces que de la découverte de leur histoire.

- Plateforme visée : PC uniquement.
- Priorité absolue : une expérience solo de qualité.
- Référence de sensation pour le nettoyage et les déplacements : *PowerWash Simulator*.

## 2. Boucle de jeu principale ✅

1. Explorer la pièce et repérer le travail à faire.
2. Nettoyer les surfaces et les objets.
3. Réparer les éléments qui le nécessitent.
4. Déplacer et ranger les objets dans des emplacements cohérents.
5. Découvrir, au fil de l'exploration, les éléments narratifs facultatifs.
6. Terminer la restauration de la pièce pour ouvrir la suite du phare.

La transformation de la pièce doit être lisible et gratifiante. La progression ne doit pas se réduire à une liste de corvées ou à une chasse frustrante au dernier pixel de saleté.

## 3. Déplacements et caméra ✅

- Vue à la première personne et déplacement libre en 3D.
- Possibilité de marcher plus lentement.
- Pendant la manipulation d'un objet, la caméra reste toujours libre. Pendant le nettoyage, le joueur peut verrouiller la caméra avec une touche à bascule. Le verrouillage n'est jamais imposé et la caméra est libre par défaut.
- Les sensations de déplacement et de nettoyage doivent rester confortables sur PC.
- Les commandes exactes et leur personnalisation seront définies lors du prototype d'interaction.

## 4. Nettoyage et réparation ✅

- Le joueur nettoie directement les surfaces et les objets avec les outils adaptés.
- Les outils de nettoyage et de rangement de base sont trouvés dans la première pièce servant de tutoriel.
- Outils de nettoyage trouvés progressivement dans la pièce 1 ; outils de réparation trouvés progressivement à l'atelier. La réparation est introduite à l'atelier, et les améliorations se débloquent progressivement.
- Le nettoyage précède la réparation : une surface ou un objet doit être nettoyé avant d'être réparé.
- Réparer consiste en une étape simple et satisfaisante. Dans certains cas, la réparation passe par un remplacement (par exemple un fusible).
- Réparer ne demande aucune collecte de pièces ni de matériaux. Les pièces de remplacement sont fournies par la trousse à outils du joueur.
- Les objets et meubles cassés ont deux états visuels, cassé puis réparé, sauf cas particuliers (par exemple la lampe du phare).
- Une réparation a un effet fonctionnel dans le jeu.
- Certaines réparations spécifiques (lampe du phare, chaufferie, électricité, etc.) peuvent avoir un impact sur le lore.
- Les réparations se font par étapes et tiennent compte du matériau de l'objet ou de l'élément concerné.
- Métal très corrodé : le traitement est intégré au geste de réparation (outil multifonction), sans étape distincte. Aucun métal très corrodé avant l'atelier.
- La réparation compte dans le 100 % de la pièce (§6).
- Les installations lourdes et fixes (par exemple radiateurs et équipements intégrés) restent en place.
- Le nettoyage et la réparation doivent produire un retour visuel et sonore satisfaisant.
- Les systèmes doivent permettre une forte différence visible entre l'état abandonné et l'état restauré.

Types de saleté et outils :
- Poussière (dépôts secs sur meubles, étagères, objets, installations) : éponge.
- Traces et salissures (doigts, graisse, dépôts collants, saleté incrustée) : éponge.
- Vitres et surfaces vitrées (voile terne, traces d'eau, pluie séchée) : éponge puis raclette.
- Sols sales (poussière accumulée, traces de pas, boue) : serpillière.
- Rouille et corrosion superficielles : éponge avec une face abrasive (amélioration de l'éponge, donc après l'atelier).
- Métal profondément corrodé : réparation avec les outils de réparation, après un traitement (traitement non défini, §15).

🟡 La liste exacte des outils de départ, les types de salissures, les matériaux et les gestes de réparation seront déterminés par le prototype et le contenu de la première pièce.

## 5. Manipulation, transport et rangement ✅

- Le joueur peut prendre, déplacer et placer les objets libres.
- Les objets se posent sur des surfaces de pose (étagère, table, crochet, etc.). Le rangement repose sur des zones par catégorie, pas sur des emplacements imposés.
- Le joueur choisit librement leur position précise dans l'espace autorisé par l'emplacement logique.
- La manipulation est volontairement simplifiée et se concentre principalement sur les surfaces ; elle ne vise pas une simulation physique complexe.
- Le placement est libre, avec une aimantation douce sur les surfaces. Les objets sont figés une fois posés (pas de simulation physique persistante).
- La rotation se fait par paliers, avec une touche ou la molette (valeur proposée : 15°, à confirmer). Chaque objet a des orientations autorisées (par exemple un livre debout ou à plat).
- Rangement : zones souples par catégorie d'objets, sans position imposée. Un objet est rangé s'il repose directement sur un support déclaré, dans une zone qui accepte sa catégorie. Le sol de la pièce n'est jamais une zone. Un support déclaré (palette, étagère basse…) n'est pas du sol, même posé au niveau du sol. Un objet posé sur un autre objet qui n'est pas un support déclaré n'est pas rangé. Déplacer un support qui porte des objets est interdit.
- Empilement : un petit objet peut être posé sur un objet plus gros (exemple : une lampe de table sur un gros carton) ; les petits objets sont empilables entre eux (livres).
- Murs : objets décoratifs et cadres. Pas de plafond (exception possible : la réparation d'un lustre).
- Gros objets : portés à deux mains, un seul à la fois.
- Catégories d'objets :
  - Petits objets (livres, outils, boîtes, vaisselle) : portés à la main, un à la fois. La ceinture ajoute des emplacements supplémentaires pour petits objets (1 au départ, jusqu'à 5 avec les améliorations).
  - Objets moyens (chaises, caisses, tabourets) : portés à la main.
  - Gros objets (armoires, commodes, tables) : transport à deux mains.
  - Objets fixes (radiateurs, installations, éléments muraux) : ne peuvent pas être déplacés.
- Collisions : un placement qui chevauche est refusé, sauf l'empilement de petits objets.
- Un objet tombe au sol s'il est lâché ou posé trop près du bord de son support. Avant le premier passage d'une pièce à 100 %, un objet tombé fait baisser le pourcentage. Au premier passage à 100 %, le statut « restaurée » de la pièce est verrouillé définitivement (verrou par pièce). Un axe ajouté plus tard (par exemple la réparation) ne retire pas ce statut.
- Les meubles libres peuvent être déplacés après avoir été nettoyés et réparés ; leur positionnement reste libre.
- Un message d'indice explique au joueur pourquoi un support qui porte des objets ne peut pas être déplacé.
- Les installations fixes et gros équipements ne sont pas déplaçables.
- Les réparations de meubles dépendent de leur matériau.
- La ceinture de transport n'est pas possédée au départ : le joueur la trouve dans la pièce tutoriel. Sa capacité de départ est de 1 petit objet, en plus de l'objet tenu en main (la main n'est pas comptée dans les emplacements : 5 emplacements au maximum, plus la main). Chaque amélioration (à l'atelier) augmente cette capacité de 1, jusqu'à un plafond de 5 petits objets. L'arbre d'amélioration de la ceinture compte 4 améliorations (de 1 à 5 emplacements).
- L'inventaire sert à gérer les objets transportés. Le joueur peut changer rapidement d'objet tenu avec une commande dédiée.
- L'ouverture de l'inventaire ne met pas le jeu en pause.

🟡 Les règles précises de placement valide, de collision, de prise en main et de transport seront stabilisées au prototype. Elles doivent préserver la liberté d'organisation sans permettre les placements absurdes ou bloquants.

## 6. Progression et structure des pièces ✅

- La progression principale suit un ordre défini, avec quelques embranchements.
- Les pièces se débloquent progressivement ; la campagne reste guidée.
- Une pièce doit atteindre **100 %** pour valider sa restauration et débloquer la suite prévue. Le 100 % couvre tout ce que la pièce permet de faire avec les mécaniques disponibles à ce stade : la pièce 1 ne compte que le nettoyage et le rangement, sans la réparation ; les pièces suivantes comptent la réparation lorsqu'elle est disponible. La définition technique exacte reste ouverte (§15).
- Les clés, objets d'histoire et autres découvertes narratives ne sont pas obligatoires pour valider une pièce. Leur suivi est séparé de l'objectif de restauration. Exception : la clé du tutoriel est obligatoire, car la ceinture qu'elle ouvre est requise pour sortir de la pièce 1.
- Les pièces déjà restaurées restent accessibles. Le joueur peut y revenir pour modifier leur organisation ou poursuivre l'entretien.
- Les pièces sont initialement très sales et encombrées.
- La restauration transforme visiblement et progressivement chaque espace.
- Graphe des pièces (décisions validées le 2026-11-10) :
  - Le jeu compte 7 pièces principales, hub et atelier compris, plus la pièce 1 (tutoriel), vestibule d'entrée et 8e zone jouable distincte des 7. Durée visée : 45 minutes à 1 heure par pièce principale, environ 7 heures de jeu au total. Le contenu est produit par étapes, pas tout d'un coup.
  - Structure : noyau de départ (pièce 1 et atelier) → hub central (rez-de-chaussée) → branches de restauration → étages supérieurs → sommet du phare.
  - Le hub est le point central de circulation. Plusieurs portes donnent accès aux pièces ; certaines sont verrouillées et se débloquent progressivement. Le hub doit lui-même être restauré. L'escalier central s'y trouve ; il est débloqué quand toutes les zones autour du hub sont à 100 %.
  - L'atelier est collé au hub, ouvert et facilement accessible. Il sert de tutoriel.
  - Une pièce se débloque quand la précédente (dans sa branche) est à 100 %. Exception : le hub est accessible sans que l'atelier soit à 100 %. À partir du hub, plusieurs branches peuvent être explorées en parallèle et l'ordre de certaines pièces est libre. Seul le dernier étage (la lampe) reste bloqué tant que le reste n'est pas terminé.
  - Liste des pièces (décisions validées le 2026-11-10). Rez-de-chaussée, 3 zones autour du hub : hall central (hub), point de circulation donnant accès aux pièces et à l'atelier, qui contient l'escalier central ; cuisine (mobilier, vaisselle, surfaces et équipements) ; salle de vie (canapé, bibliothèque, cheminée et objets personnels) ; atelier (réparation, rangement des outils et améliorations). Premier étage, 2 zones : chambre (ancien espace personnel du gardien) ; salle d'archives (documents, cartes, registres et souvenirs). Sommet, 1 zone : salle de la lanterne, dernière zone, cœur du phare et conclusion de la restauration.
  - L'escalier central est débloqué quand les 3 zones autour du hub (cuisine, salle de vie, atelier) sont à 100 %.
  - Réparations particulières par pièce : hall central (installation électrique générale, interrupteurs, éclairage, câblage) ; cuisine (robinetterie, évier, tuyauterie, équipements de cuisine) ; salle de vie (cheminée, conduits, mobilier nécessitant une restauration particulière) ; atelier (établi, éclairage technique, prises, équipements d'amélioration des outils) ; chambre (mobilier abîmé, lit, armoire, éléments en bois) ; salle d'archives (étagères, tiroirs, boîtes de rangement, mobilier de conservation) ; salle de la lanterne (mécanisme optique, rotation de la lanterne, alimentation lumineuse, système de signalisation). Réparation signature par pièce : hall central, tableau électrique ; cuisine, évier et robinetterie ; salle de vie, cheminée ; atelier, établi ; chambre, lit du gardien ; salle d'archives, meuble à tiroirs ; salle de la lanterne, mécanisme et lampe. Les autres réparations de chaque pièce restent classiques (bois, métal, surfaces, mobilier).
  - Chaufferie : au sous-sol, dans l'extension prévue (trappe vers le tunnel, §14), hors des 7 pièces. Le jeu de base garde le chauffage via la cheminée de la salle de vie et la plomberie de la cuisine.
  - Direction artistique (principe) : palette commune à tout le phare, avec des variations de matériaux, mobilier, décoration et éclairage propres à chaque pièce. La lumière est froide au début et devient progressivement plus chaude avec la restauration. Les détails relèvent du projet Art et de ART_BIBLE.md.
  - Courant de l'atelier : le joueur lance un générateur de secours pour alimenter l'atelier le temps de trouver l'installation électrique ; le personnage indique qu'il faut la chercher en priorité dans le hub. L'installation électrique générale (tableau principal) est dans le hub et se répare là.
  - Les étages supérieurs deviennent accessibles progressivement. Le phare monte vers la lanterne, au sommet, dernière grande étape : rallumer la lampe est l'aboutissement du jeu.
  - Chaque pièce principale doit être nettoyée, rangée et réparée à 100 % (selon ce que la pièce permet) pour être validée. Le 100 % acquis reste acquis, même si le joueur modifie ensuite le rangement. Les objets narratifs, clés et découvertes restent facultatifs (exception : la clé du tutoriel).
  - Après la campagne : exploration libre et restauration complémentaire. L'extérieur n'est pas jouable pour l'instant (visible par les fenêtres seulement).
  - L'atmosphère (éclairage, ambiance) évolue avec la progression, du froid vers le chaleureux.
  - Aucune nouveauté de mécanique n'est imposée pièce par pièce : tous les outils et mécaniques sont utilisables ; à revoir avec une extension.
  - Principes d'architecture : éviter une progression entièrement linéaire, donner une sensation de liberté sans monde ouvert, réutiliser les mêmes systèmes et des espaces indépendants, limiter les coûts grâce à une architecture simple.

### Pièce 1 — tutoriel

- Apprentissage libre avec indices : le personnage commente à voix haute (par exemple « Il faudrait que je récupère cette éponge pour nettoyer »), sans jamais forcer le joueur.
- Les outils de nettoyage sont trouvés progressivement dans la pièce.
- La ceinture est une récompense : le joueur trouve une clé pendant le rangement (par exemple sur une table) ; le personnage dit en substance qu'il se demande ce qu'elle ouvre. Un vieux coffre en bois fermé à clé, placé à côté de la porte de sortie, contient la ceinture.
- Le coffre en bois est le gros objet utilisé pour apprendre : saisir un objet volumineux, le porter à deux mains, le déposer à un emplacement précis et le tourner selon les orientations prédéfinies.
- Le joueur découvre seul la nécessité de rincer le seau ; le personnage peut la commenter.
- Durée visée : 15 minutes.
- Sortie de la pièce 1 : 100 % de la pièce requis ET possession de la ceinture.
- Narration : le nouveau Gardien n'a pas envie d'être là, mais il le faut pour sa fille malade.
- La trousse à outils est obtenue à l'atelier.

### Pièce 2 — atelier

- Durée visée : 20 minutes.
- Le joueur peut revenir à l'atelier à tout moment. L'atelier compte dans le 100 % : il se nettoie, se range et se répare.
- Les outils de réparation (marteau, outil multifonction) sont trouvés progressivement dans l'atelier.
- Réparations d'apprentissage : lancer le générateur de secours de l'atelier ; réparer le meuble de l'atelier lui-même pour pouvoir l'utiliser. Réparer une chaise est une proposition À CONFIRMER.
- Améliorer un outil : le joueur trouve des items d'amélioration dans les pièces suivantes. À l'atelier, il clique sur le meuble de l'atelier, ce qui ouvre un menu d'amélioration. Tout l'arbre est visible d'avance et le menu indique ce qui est faisable. Il suffit de cliquer sur l'amélioration avec l'item pour la valider. L'item ne compte pas dans la ceinture.
- Les améliorations se débloquent par la récupération d'items d'amélioration. Elles sont organisées en arbres par type d'objet (outil), de 3 ou 4 améliorations chacun. L'éponge abrasive est la première amélioration de l'éponge (début d'arbre), pour qu'elle ne bloque pas la progression.
- Les améliorations sont simples : de simples réglages de paramètres (par exemple plus rapide, surface plus large, outil qui se salit moins vite donc moins de rinçages), sans nouvelle mécanique.
- Narration : outils de l'ancien gardien, notes et plan du phare ; l'ancien gardien a tout laissé en plan.

### Après la campagne ✅

- Le joueur peut continuer à explorer, entretenir et réorganiser librement le phare.
- Il est possible de remettre la progression à zéro.
- Les succès restent acquis même après une remise à zéro de la progression.
- Le résumé de fin de campagne reste consultable depuis le menu principal.

⚠️ Point de vigilance de conception : le 100 % est une règle de progression validée, mais son implémentation doit éviter la chasse au pixel. Les surfaces, objets et tâches doivent avoir des états de complétion fiables, visibles et compréhensibles. Les découvertes facultatives restent hors du calcul.

## 7. Outils, améliorations et atelier ✅

- Le jeu compte six outils au total : quatre de nettoyage et de rangement, deux de réparation.
- Les outils de nettoyage et de rangement de base sont trouvés dans la première pièce du tutoriel :
  - Éponge : nettoyage courant.
  - Raclette : vitres et surfaces lisses.
  - Serpillière : sols.
  - Seau : rincer les outils de nettoyage. Sans rinçage, leur efficacité baisse fortement ; un outil sale perd jusqu'à 90 % d'efficacité au maximum, jamais 100 %. Le rinçage est un geste court : le joueur tient l'outil sale et interagit avec le seau. Le seau est améliorable à l'atelier comme les autres outils, ce qui permet de rincer moins souvent.
- Outils de nettoyage trouvés progressivement dans la pièce 1 ; outils de réparation trouvés progressivement à l'atelier. Les améliorations se débloquent au fil de la progression.
- Une pièce dédiée, l'atelier, est la deuxième pièce restaurée. Elle introduit la réparation et ses outils, puis permet d'améliorer les outils, ceinture comprise.
- L'atelier ne fabrique jamais d'objets.
- Les deux outils de réparation :
  - Marteau : réparations du bois et éléments à redresser.
  - Outil multifonction : visserie, plomberie, petites réparations ; il reprend le rôle de reboucher, colmater et restaurer les surfaces abîmées.
- La trousse à outils est un objet distinct de la ceinture de transport. Elle fournit les pièces de remplacement nécessaires à certaines réparations (par exemple un fusible). Ces pièces n'occupent pas les emplacements de la ceinture et ne se collectent pas.
- Les déblocages sont liés à la restauration de certaines pièces et à la récupération d'items d'amélioration (voir « Pièce 2 — atelier », §6).
- Pas de grind artificiel, pas de niveaux ni de système d'XP.
- Les améliorations restent modestes et ne doivent pas accélérer excessivement le nettoyage.

🟡 Le catalogue d'améliorations et l'ordre de déblocage seront définis après les premiers essais de nettoyage.

## 8. Exploration, découvertes et journal ✅

Les découvertes secondaires enrichissent l'univers mais ne bloquent jamais la progression principale.

Elles peuvent inclure :
- souvenirs ;
- objets cachés ou particuliers ;
- clés et objets liés à l'histoire ;
- documents et lettres ;
- éléments décoratifs à restaurer ;
- objets ayant une valeur personnelle ou narrative.

### Journal

- Les éléments importants découverts sont ajoutés automatiquement au journal avec une description ou un indice de lore.
- Les entrées sont classées alphabétiquement et réparties par catégories, chacune avec son icône.
- Les entrées encore inconnues sont signalées par un petit symbole, sans révéler leur contenu.
- Les entrées déjà consultées se distinguent visuellement des nouvelles ; aucun marqueur de nouvelle entrée n'est ajouté à l'icône du journal sur le HUD.
- Les illustrations des entrées peuvent être agrandies.
- Certains documents et objets peuvent être accompagnés de dessins ou croquis de l'ancien gardien, parfois incomplets, effacés ou incertains. Ils ne se complètent pas automatiquement lorsque le joueur trouve des éléments associés.
- Les dates ou périodes estimées sont indiquées lorsque l'information est connue.
- Certains objets potentiellement musicaux (par exemple une boîte à musique) peuvent proposer un contenu audio pertinent ; il n'y a pas d'audio ajouté artificiellement à toutes les entrées.
- Le journal possède une couverture illustrée évoquant le carnet de l'ancien gardien ; elle évolue au fil des découvertes.
- Un son discret de manipulation des pages accompagne l'ouverture et la fermeture.
- Le journal s'ouvre sur son onglet principal, sans mémoriser le dernier onglet consulté.
- L'ouverture du journal met automatiquement le jeu en pause.
- Le journal est inaccessible pendant les cinématiques.
- Sur PC : navigation par défilement et boutons précédent/suivant ; une touche dédiée est personnalisable.
- Pas de recherche textuelle dans le journal.

### Deux voix narratives distinctes

- **Ancien gardien** : notes manuscrites, observations, souvenirs, hypothèses, croquis et annotations personnelles. Ses suppositions restent subjectives et incertaines ; elles ne sont pas présentées comme des vérités établies.
- **Nouveau gardien** : pensées orales écrites à l'avance et déclenchées à certains moments de l'histoire ou de la découverte. Le joueur ne rédige pas librement ses propres notes.

La narration repose notamment sur les documents et notes écrites ainsi que sur les pensées orales du nouveau gardien. Le phare raconte aussi son passé par son environnement.

## 9. HUD et interactions ✅

- Le HUD peut être temporairement masqué ou affiché par une commande ; la commande est personnalisable sur PC.
- Le HUD est automatiquement masqué pendant les cinématiques, dans le journal et sur la carte, puis rétabli à la fermeture.
- Pas de personnalisation indépendante de chaque élément du HUD.
- Lorsqu'un objet interactif est regardé à portée, un indicateur discret affiche son nom et une icône.
- L'indicateur disparaît lorsque le joueur détourne le regard ou sort de portée.
- Pas de contour ni de surbrillance dans le monde sur les objets interactifs.
- Une indication de commande (ex. « E — Prendre ») s'adapte à la plateforme et reste visible tant que l'objet est ciblé à portée.
- La découverte d'un objet important déclenche une notification discrète, éventuellement accompagnée d'une réaction du personnage.
- La notification indique la catégorie de découverte et disparaît après quelques secondes ; pas d'historique des notifications dans le journal.

## 10. Menu principal, sauvegarde et transitions ✅

### Menu principal

- Entrées : Continuer, Nouvelle partie, Options, Succès, Crédits.
- Si une sauvegarde existe, Nouvelle partie demande confirmation avant écrasement.
- Le menu indique la dernière pièce visitée, la progression, ainsi que la date et l'heure de la dernière sauvegarde.
- Numéro de version affiché (ex. v1.0.0).
- Lien vers la page itch.io et accès au formulaire de retour/rapport de bug.
- Illustration fixe du phare sur son rocher dans la tempête au début du jeu ; après la fin de la campagne, elle montre le phare restauré. Pas d'évolution progressive de cette illustration.
- Pas de message de bienvenue au premier lancement.
- Les crédits sont accessibles depuis le menu principal uniquement.

### Sauvegarde

- Une seule sauvegarde locale ; pas de synchronisation cloud prévue.
- Sauvegarde automatique et notification discrète.
- Export manuel de la sauvegarde dans un fichier et import depuis un fichier.
- L'import demande confirmation s'il remplace une progression existante.
- Le fichier importé est contrôlé (intégrité et compatibilité) avant toute modification ; un fichier invalide ou incompatible est rejeté sans toucher à la sauvegarde actuelle.
- L'export inclut progression, inventaire, journal, statistiques et données nécessaires aux succès. Les succès doivent rester persistants indépendamment d'une remise à zéro de la progression.

### Transitions et chargements

- Fondu au noir entre les pièces, lors du retour au menu et au démarrage d'une nouvelle partie.
- Écran de chargement avec illustration propre à la pièce de destination, courte phrase d'ambiance et barre de progression.
- Les phrases proviennent de notes de l'ancien gardien déjà découvertes ; aucun contenu non découvert n'est révélé.
- L'écran disparaît automatiquement lorsque la pièce est prête ; pas de bouton pour le passer.

## 11. Cinématiques et conclusion ✅

- Introduction : trajet en bateau vers le phare ; le passeur raconte une légende locale.
- Cinématiques mises en scène à la première personne ; le personnage n'est pas directement montré.
- Aucun contrôle de déplacement ou de regard pendant les cinématiques.
- Première lecture obligatoire ; après cette première lecture, la cinématique peut être passée avec Échap. Même règle pour toutes les cinématiques.
- Sous-titres activés par défaut ; HUD masqué.
- Fin : après avoir rallumé le phare, le protagoniste décide d'y rester comme gardien ; sa pensée fait écho à sa fille.
- Après la fin : résumé des pièces terminées, découvertes, succès débloqués et temps total consacré à la restauration.
- Le résumé reste accessible depuis le menu principal.

## 12. Audio, ambiance et langues ✅

- Ambiance initiale froide et mélancolique : vent, pluie, craquements et sons d'un bâtiment abandonné.
- À mesure que le phare est restauré, l'ambiance intérieure devient plus douce et chaleureuse. L'extérieur conserve son caractère froid et exposé.
- Musique discrète et sons d'interaction satisfaisants.
- **Voix françaises et sous-titres.** Les langues supplémentaires de sous-titrage ne sont pas encore définies.

## 13. Retours et qualité de vie ✅

- Bouton de retour accessible en jeu, ouvrant un formulaire externe (par exemple itch.io).
- Catégories : bug, difficulté/équilibrage, suggestion, retour général.
- Pas de pièce jointe de capture d'écran prévue dans le formulaire.
- Si le joueur tente de quitter pendant une action importante (par exemple une manipulation ou une restauration), un avertissement est affiché.
- Retour au menu principal immédiat, sans confirmation supplémentaire ; l'autosauvegarde protège la progression.

## 14. Périmètre et pistes futures

### Périmètre de la première version ✅

- Expérience solo de qualité prioritaire.
- PC uniquement ; mobile hors périmètre (décision du 2026-11-09).
- Campagne de restauration du phare et exploration libre après la campagne.

### Pistes non engagées 💡

- Coopération à deux joueurs, uniquement si elle devient techniquement réaliste sans compromettre l'expérience solo. Aucune contrainte d'architecture ne doit être imposée à la première version pour cette possibilité.
- Nouveaux espaces après la campagne (sous-sol, cabanon extérieur, autres extensions).
- Extension : trappe vers un sous-sol menant à un tunnel ; le sous-sol accueillerait la chaufferie.
- Extension : cabanon extérieur.
- Passage sous le phare pouvant éventuellement conduire jusqu'à la côte : idée d'extension future, pas une fonctionnalité requise pour la sortie initiale.
- Support manette en bonus, si facile. Non engagé : le clavier/souris reste la référence.
- Renouvellement de l'eau du seau : retiré du périmètre actuel, à reconsidérer plus tard.
- Coffre en bois de la pièce 1 utilisable ensuite comme rangement.
- Catégorie « objets d'histoire » (clés, documents, souvenirs) hors des règles de rangement, avec un journal ou un inventaire.
- Mobilité réduite en portant un gros objet.

## 15. Points à préciser pendant le prototypage 🟡

Ces points ne remettent pas en cause les décisions de conception ci-dessus ; ils demandent des choix concrets de production ou des essais :

1. Définition technique du 100 % de nettoyage, de réparation et de rangement, avec une validation robuste qui évite les faux blocages.
2. Graphe des pièces :
   - position du vestibule (pièce 1) par rapport au hub et à l'atelier ;
   - fonctionnement du générateur de secours et emplacement exact du tableau principal dans le hub ;
   - connexion physique entre la pièce 1, l'atelier et le hub, et condition d'ouverture de la première branche ;
   - nombre d'étages ;
   - définition exacte de « le reste » pour débloquer le dernier étage (la lampe) ;
   - relation entre le déblocage de l'escalier et celui du dernier étage (lampe) ;
   - mécanisme de l'évolution de l'atmosphère (globale ou par pièce) ;
   - rôle, contenu et fonctionnement du journal (mentionné comme découverte du noyau de départ).
3. Liste des orientations autorisées par objet.
4. ~~Liste, ordre et coûts des améliorations d'outils.~~ Fusionné au point 5.
5. Catalogue des améliorations d'outils (arbres, contenu de chacun) et ordre de déblocage. Les améliorations n'ont pas de coût en matériaux : elles se débloquent par la récupération d'items d'amélioration. L'éponge abrasive en est le premier exemple.
   Contenu précis restant de l'atelier (voir « Pièce 2 — atelier », §6) et du reste de la première pièce tutorielle (voir « Pièce 1 — tutoriel », §6). Points ouverts de l'atelier :
   - forme de l'item d'amélioration (porté ou stocké) et combien, où, dans quelles pièces ;
   - liste des arbres d'amélioration (quels outils) et contenu de chacun ;
   - condition de sortie de l'atelier ;
   - confirmation de la chaise comme réparation d'apprentissage ;
   - contenu exact des notes et du plan du phare.
6. Langues de sous-titrage supplémentaires éventuelles.
7. Détails techniques des sauvegardes, contrôles et compatibilité selon la plateforme.
8. Mécanique de réparation : déroulé exact des étapes et variantes selon le matériau.
9. Origine des pièces de remplacement (fusibles, etc.) fournies par la trousse à outils.
10. L'outil multifonction est-il consommable ?
11. Liste et nombre des réparations spécifiques (lampe du phare, chaufferie, électricité, etc.) et de leur impact sur le lore.
12. ~~Quand et où le joueur obtient la trousse à outils.~~ Réglé : à l'atelier (§6).
13. Contenu exact de la trousse à outils.
14. La trousse à outils est-elle améliorable ?
15. Rythme de salissure des outils, signal visuel d'outil sale, effet exact des améliorations du seau sur la fréquence de rinçage.
16. Comportement de l'outil multifonction selon la cible.
17. ~~Définition de « désordre ».~~ Réglé : critère de rangement testable (§5).
18. Règles d'empilement par catégorie d'objets (petits, moyens, gros, fixes).
19. Liste des zones de rangement par catégorie.
20. Valeur des paliers de rotation (15° à confirmer).
21. Articulation entre orientations autorisées et paliers de rotation.
22. ~~Portée du 100 % acquis (par pièce ou global).~~ Réglé : verrou par pièce, au premier 100 % (§5).
23. Distance limite au bord d'un support et signal d'aperçu avant le placement.
24. Emplacements et ordre de découverte des outils dans la pièce 1.
25. Ordre entre l'ouverture du coffre, son rangement et la sortie.
26. ~~Traitement du métal corrodé avant réparation.~~ Réglé : intégré à la réparation (§5/§6).
27. Pièces où la rouille apparaît.
28. ~~Catalogue des améliorations (l'éponge abrasive en est le premier exemple).~~ Fusionné au point 5.

---

**Document de référence :** `GDD.md`  
**Plan de réalisation :** `PLAN_DE_PRODUCTION.md`
