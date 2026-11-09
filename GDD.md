# A LIGHT LEFT BEHIND — Game Design Document

Dernière mise à jour : 2026-11-09  
Statut : document de référence des décisions de conception validées.

**Légende** : ✅ décision validée · 💡 piste non engagée · 🟡 à préciser pendant le prototypage

Le GDD décrit le jeu voulu. Les choix techniques détaillés et l'ordre de réalisation sont consignés dans `PLAN_DE_PRODUCTION.md`. Ne pas transformer une piste ou un point à préciser en fonctionnalité promise sans validation.

---

## 1. Concept et intention ✅

**A Light Left Behind** est un jeu solo à la première personne centré sur le nettoyage, la réparation, la restauration et le rangement d'un ancien phare abandonné, construit sur un rocher isolé au large.

Le joueur incarne le nouveau gardien du phare. Le départ du précédent gardien est mystérieux ; le joueur en découvre progressivement les raisons à travers les lieux, les objets et les traces laissées derrière lui.

L'expérience recherchée est calme, immersive, mélancolique et satisfaisante. Le plaisir vient autant de la transformation visible des espaces que de la découverte de leur histoire.

- Plateformes visées : PC et mobile.
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
- La caméra peut être verrouillée pendant certaines manipulations pour faciliter le placement.
- Les sensations de déplacement et de nettoyage doivent rester confortables sur PC comme sur mobile.
- Les commandes exactes et leur personnalisation seront définies lors du prototype d'interaction.

## 4. Nettoyage et réparation ✅

- Le joueur nettoie directement les surfaces et les objets avec les outils adaptés.
- Les outils de base sont trouvés dans la première pièce servant de tutoriel.
- Tous les outils de base sont accessibles dès le départ ; les améliorations se débloquent progressivement.
- Les réparations se font par étapes et tiennent compte du matériau de l'objet ou de l'élément concerné.
- Les installations lourdes et fixes (par exemple radiateurs et équipements intégrés) restent en place.
- Le nettoyage et la réparation doivent produire un retour visuel et sonore satisfaisant.
- Les systèmes doivent permettre une forte différence visible entre l'état abandonné et l'état restauré.

🟡 La liste exacte des outils de départ, les types de salissures, les matériaux et les gestes de réparation seront déterminés par le prototype et le contenu de la première pièce.

## 5. Manipulation, transport et rangement ✅

- Le joueur peut prendre, déplacer et placer les objets libres.
- Les objets possèdent des emplacements logiques (étagère, table, crochet, etc.).
- Le joueur choisit librement leur position précise dans l'espace autorisé par l'emplacement logique.
- La manipulation est volontairement simplifiée et se concentre principalement sur les surfaces ; elle ne vise pas une simulation physique complexe.
- La rotation est possible selon un ensemble d'orientations prédéfinies, et non de manière totalement libre.
- Les meubles libres peuvent être déplacés après avoir été nettoyés et réparés ; leur positionnement reste libre.
- Les installations fixes et gros équipements ne sont pas déplaçables.
- Les réparations de meubles dépendent de leur matériau.
- La ceinture de transport peut être améliorée : chaque amélioration augmente de 1 le nombre de petits objets transportables, jusqu'à une capacité maximale envisagée de 5.
- L'inventaire sert à gérer les objets transportés. Le joueur peut changer rapidement d'objet tenu avec une commande dédiée.
- L'ouverture de l'inventaire ne met pas le jeu en pause.

🟡 Les règles précises de placement valide, de collision, de prise en main et de transport seront stabilisées au prototype. Elles doivent préserver la liberté d'organisation sans permettre les placements absurdes ou bloquants.

## 6. Progression et structure des pièces ✅

- La progression principale suit un ordre défini, avec quelques embranchements.
- Les pièces se débloquent progressivement ; la campagne reste guidée.
- Une pièce doit atteindre **100 % de nettoyage, 100 % de réparation et 100 % de rangement** pour valider sa restauration et débloquer la suite prévue.
- Les clés, objets d'histoire et autres découvertes narratives ne sont pas obligatoires pour valider une pièce. Leur suivi est séparé de l'objectif de restauration.
- Les pièces déjà restaurées restent accessibles. Le joueur peut y revenir pour modifier leur organisation ou poursuivre l'entretien.
- Les pièces sont initialement très sales et encombrées.
- La restauration transforme visiblement et progressivement chaque espace.

### Après la campagne ✅

- Le joueur peut continuer à explorer, entretenir et réorganiser librement le phare.
- Il est possible de remettre la progression à zéro.
- Les succès restent acquis même après une remise à zéro de la progression.
- Le résumé de fin de campagne reste consultable depuis le menu principal.

⚠️ Point de vigilance de conception : le 100 % est une règle de progression validée, mais son implémentation doit éviter la chasse au pixel. Les surfaces, objets et tâches doivent avoir des états de complétion fiables, visibles et compréhensibles. Les découvertes facultatives restent hors du calcul.

## 7. Outils, améliorations et atelier ✅

- Les outils de base sont trouvés dans la première pièce du tutoriel.
- Ils sont tous disponibles dès le départ ; les améliorations, elles, se débloquent au fil de la progression.
- Une pièce dédiée sert d'atelier d'amélioration ; elle sera probablement la deuxième pièce restaurée.
- L'atelier sert uniquement à améliorer les outils, pas à fabriquer des objets.
- Les déblocages sont liés à la restauration de certaines pièces et à la récupération naturelle de matériaux.
- Pas de grind artificiel, pas de niveaux ni de système d'XP.
- Les améliorations restent modestes et ne doivent pas accélérer excessivement le nettoyage.

🟡 Le catalogue d'améliorations, les coûts en matériaux et l'ordre de déblocage seront définis après les premiers essais de nettoyage.

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
- Sur mobile : icône tactile dédiée.
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
- PC et mobile.
- Campagne de restauration du phare et exploration libre après la campagne.

### Pistes non engagées 💡

- Coopération à deux joueurs, uniquement si elle devient techniquement réaliste sans compromettre l'expérience solo. Aucune contrainte d'architecture ne doit être imposée à la première version pour cette possibilité.
- Nouveaux espaces après la campagne (sous-sol, cabanon extérieur, autres extensions).
- Passage sous le phare pouvant éventuellement conduire jusqu'à la côte : idée d'extension future, pas une fonctionnalité requise pour la sortie initiale.

## 15. Points à préciser pendant le prototypage 🟡

Ces points ne remettent pas en cause les décisions de conception ci-dessus ; ils demandent des choix concrets de production ou des essais :

1. Liste exacte des outils de base trouvés dans la première pièce.
2. Définition technique du 100 % de nettoyage, de réparation et de rangement, avec une validation robuste qui évite les faux blocages.
3. Liste des pièces et graphe exact des embranchements.
4. Nombre d'orientations prédéfinies par objet ou famille d'objets.
5. Liste, ordre et coûts des améliorations d'outils.
6. Contenu précis de la première pièce tutorielle et de la deuxième pièce qui accueillera probablement l'atelier.
7. Langues de sous-titrage supplémentaires éventuelles.
8. Détails techniques des sauvegardes, contrôles et compatibilité selon la plateforme.

---

**Document de référence :** `GDD.md`  
**Plan de réalisation :** `PLAN_DE_PRODUCTION.md`
