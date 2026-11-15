# TECHNICAL — A Light Left Behind

Propriétaire : projet Godot Engineering. Dernière mise à jour : 2026-11-15.
Légende : ✅ décision validée · 🟡 à décider en Phase 0

## Contraintes validées ✅
- Moteur : Godot 4.7.2 (2026-11-13 : version de Godot = 4.7.2, épinglée par tools/godot.sh, validé par le développeur). Plateforme : PC uniquement (mobile abandonné le 2026-11-09).
- Un seul dépôt Git. Une PR par sujet.
- Deux PC de travail, synchronisés via Git uniquement (aucun transfert de fichiers hors dépôt).
- Entrées : clavier/souris de référence, manette en bonus non engagé. Toutes les entrées passent par des actions de l'Input Map, jamais par des touches en dur.
- Systèmes modulaires et réutilisables. Contenu séparé du code par des ressources et des données. Pas de script propre à une pièce quand une donnée suffit.
- Pas de sur-ingénierie.
- Le 100 % d'une pièce repose sur des unités explicites (surfaces, objets). Les découvertes facultatives sont comptées à part.
- Sauvegarde locale. Intégrité validée avant toute écriture.

## À décider en Phase 0
1. ✅ 2026-11-10 — Rendu : Forward+.
2. ✅ 2026-11-10 — Langage : GDScript seul (pas de C#), typage statique encouragé.
3. ✅ 2026-11-10 — Dossiers : projet Godot dans `game/` (`core`, `systems`, `data`, `rooms/test`, `props`, `ui`, `assets`, `tests`) ; docs et CLAUDE.md hors du moteur. Nommage : fichiers en snake_case, classes en PascalCase.
  - 15/11/2026 : .glb des objets dans `game/assets/objets/`, nom = id de l'ItemData (snake_case, ASCII, sans accent) ; .glb des meubles dans `game/assets/meubles/` (table, palette, etagere_basse, etagere_murale) ; scènes qui instancient ces .glb dans `game/props/`, même nom en .tscn, référence au .glb par ext_resource ; modules d'architecture inchangés dans `game/assets/modules_temoins/` ; pas de règle sur les textures pour l'instant.
  - 15/11/2026 : pivot des .glb d'objets et de meubles : origine au centre de la boîte englobante (centre du volume), ce que supposent TestItem et PlacementController (corps posé à center + UP × height × 0,5). Boîte englobante = emprise et hauteur de l'ItemData (valeurs provisoires, qui peuvent suivre l'art final). Échelle 1 unité = 1 m.
  - 15/11/2026 : exception de pivot : étagère murale (meuble fixe, non déplacé par le jeu) : pivot au centre du plateau, équerres exclues, pour que la surface de pose ne dépende pas des équerres. La hauteur de la surface de pose par rapport au pivot est fournie par l'art avec le .glb. Les autres objets et meubles gardent la règle du centre de la boîte englobante.
  - Écart connu, non traité : `module_tronçon_mur.glb` et `module_tronçon_noyau.glb` contiennent un « ç », contre la règle snake_case ; les renommer toucherait `cleaning_spike.gd`, les `.import` et `build_modules_temoins.py`.
Nettoyage localisé — ✅ VALIDÉ 2026-11-11
- L'état de saleté est un masque par surface (R8, 0 = sale, 1 = propre). Aucun scalaire d'instance.
- Périmètre : mousse sur pierre architecturale. Verrière, rambardes et mobilier : décisions séparées.
- Correspondance point visé / UV analytique, via SurfaceMapping : plan (murs droits, marches, contremarches), cylindre (fût, noyau). Maillages quelconques non retenus.
- Épaisseur en coordonnées monde, projection plane ou cylindrique. Mêmes paramètres pour le shader et le CPU.
- Matériau propre à chaque face ; UV2 = développée linéaire, sans recouvrement.
- Unité du 100 % : la surface. Fin de surface : voir « Surfaces à nettoyer » (décision du 2026-11-12, remplace le critère tau au niveau de la surface). Le reste de texels couverts (épaisseur - propreté > epsilon) sert au critère tau par face.
- Valeurs de départ, provisoires, à régler en playtest : epsilon = 0,05 ; tau = 0,02 (fraction des texels couverts). Constantes uniques, exposées.
- Fin de geste : une fois tau atteint pour une face, ses résidus s'effacent automatiquement (fondu ~0,5 s). Le passage de la surface à « nettoyée » suit la règle « Surfaces à nettoyer ».
- Le shader rend la mousse invisible à epsilon, pour que le comptage CPU corresponde au rendu.
- Réserve : si tau = 2 % est trop visible sur la plus grande surface, un plafond en m² sera rediscuté. Non implémenté.
- Sauvegarde : JSON du SaveService, R8 compressé puis base64, id = chemin depuis la racine de la pièce. Taille attendue dérivée de la scène. Clé absente = sale.
- Noms : proprete_mousse, epaisseur_mousse, proprete_surface ; plus tard proprete_mousse_tenace et epaisseur_mousse_tenace.
4. ✅ 2026-11-11 — Représentation de la saleté : masque d'état par surface (voir « Nettoyage localisé »).
5. ✅ 2026-11-10 — Architecture : trois autoloads maximum (sauvegarde, progression, réglages) ; physique par requêtes uniquement (raycast, shape query), aucun RigidBody persistant. Sauvegarde : JSON versionné dans `user://`, écriture atomique, jamais de .tres/ResourceSaver.
6. ✅ 2026-11-10 — Objets = ressource `ItemData` ; emplacements de rangement = volumes (Area3D) dans les scènes de pièce + ressource `ZoneData` pour les règles.

## Input Map (provisoire) 🟡
Actions définies dans `game/project.godot` (clavier/souris, touches provisoires, codes physiques ; aucune manette). Le regard à la souris est lu directement, hors Input Map. Les actions `ui_*` par défaut sont conservées.
- Déplacement : `move_forward`, `move_back`, `move_left`, `move_right`, `walk_slow`
- Interaction : `interact`, `use_primary`, `use_secondary`, `drop_object`, `rotate_left`, `rotate_right`, `cycle_item`, `equip_tool` (F, provisoire ; `rinse_tool` retirée, décision du 2026-11-11)
- Interface : `inventory_open`, `journal_open`, `pause_menu`

Vérification automatique : `tools/check_project.sh` (Godot headless Linux, version épinglée à 4.7.2).

## Sauvegarde ✅
- Service `SaveService` (autoload) : enveloppe JSON {format_version, written_at, checksum, payload}, écriture via .tmp relu et validé, ancienne sauvegarde conservée en .bak.
- Le JSON de Godot relit tous les nombres en flottants (un entier revient en 1.0) : les consommateurs convertissent en entier à la lecture.
- Les vecteurs sont stockés sous forme de tableaux ; aucun objet sérialisé, le fichier est traité comme non fiable.
- Une version de format plus récente que celle supportée est refusée ; point d'extension `_migrate` vide.

Couches de collision (2026-11-10). Couche 1 : monde (sol, murs, meubles). Couche 2 : joueur (masque 1). Les couches suivantes seront ajoutées ici au fur et à mesure.
Couches de collision (2026-11-10), mise à jour. Couche 3 : objets interactifs (masque 4). Le raycast d’interaction lit les couches 1 et 3, portée 2,0 m (provisoire).

- ✅ Décision de Direction (2026-11-13, provisoire) : la sauvegarde conserve la disposition de tous les objets libres de chaque pièce : position, angle autour de la verticale, posture, support. Le seau est inclus, bien qu'exclu du 100 %.
- ✅ Portage (2026-11-13, provisoire) : la sauvegarde inclut l'objet en main et les objets à la ceinture. Au chargement, le joueur retrouve exactement son portage d'avant la sauvegarde (même objet en main, mêmes objets à la ceinture).
- ✅ Un objet porté est sauvegardé une seule fois, dans le portage, jamais en plus dans une pièce. Chaque objet est identifié par un identifiant stable.
- ✅ Au rechargement, les objets reprennent leur place sauvegardée et le pourcentage de la pièce se recalcule depuis cet état. Le verrou « restaurée » reste inchangé (déjà sauvegardé).
- ✅ Format (2026-11-13, implémenté dans [PR #112](https://github.com/Pandasylum/A-Light-Left-Behind/pull/112), validé par le développeur) : section « disposition » du SaveService, à côté de « nettoyage » et « outils », avec sa propre version. Section absente = disposition initiale de la scène. La version du format du SaveService reste inchangée.
- ✅ Implémentation (2026-11-13) : module `game/systems/layout/`, avec une logique pure et un nœud de scène RoomLayout.
- ✅ Objets de pièce (2026-11-13) : un enregistrement par objet libre (identifiant, position absolue dans la pièce, angle, posture, support = identifiant de la surface porteuse ou « sol »). La posture est conservée dans RoomLayout, pas sur TestItem, où elle reste « à plat ».
- ✅ Support « sol » (2026-11-13) : la surface de sol qui contient le point. Une seule surface de sol aujourd'hui ; à revoir s'il y en a plusieurs.
- ✅ Portage (2026-11-13) : main et ceinture par emplacement, identifiés par l'identifiant stable. La capacité de ceinture reste celle du joueur. Une ceinture restaurée avec un outil en main est un état permis.
- ✅ Identifiant stable (2026-11-13) : chemin complet depuis la racine de la pièce, comme l'id des surfaces à nettoyer, pas l'id d'ItemData.
- ✅ Restauration (2026-11-13) : meubles libres, puis objets posés, puis reconstruction des charges depuis le support sauvegardé, puis portage. Aucun objet créé ni supprimé. Aucune sauvegarde déclenchée au chargement. L'état « rangé » est évalué avec le support sauvegardé, après restauration de la disposition et du portage.
- ✅ Objet jamais déplacé (2026-11-13) : un objet jamais posé ni déplacé n'est pas écrit et garde sa place initiale.
- ✅ Rejet de la section (2026-11-13) : disposition initiale, portage vide et avertissement dans le journal si la section est illisible, de version inconnue, avec un identifiant en double, un objet à la fois porté et en pièce, une ceinture au-delà de sa capacité, un objet non petit en ceinture, ou un identifiant de portage inconnu. Une entrée sans identifiant rejette aussi toute la section.
- ✅ Rejet d'une entrée (2026-11-13) : une position, un angle ou une posture illisible n'ignore que l'entrée. Un objet posé sur un objet ignoré ou porté est ignoré aussi. Entrée inconnue ou support introuvable : cette entrée seule est ignorée.
- ✅ Objet en main et outil en main dans l'état sauvegardé (2026-11-13) : l'objet est gardé, l'outil est rangé, avertissement dans le journal.
- 🟡 Déclencheur : dépôt validé (chute comprise), par la demande de sauvegarde existante de l'Autosave, qui fusionne les demandes rapprochées. Pas d'optimisation de l'export des faces : à reconsidérer après mesure en playtest. La prise, le changement d'objet en main (cycle_item) et le changement de ceinture ne déclenchent pas de sauvegarde : la fermeture du jeu (déjà couverte, sauvegarde avec attente) enregistre le portage du moment. Après un plantage, la disposition revient à la dernière sauvegarde, cohérente (objet à sa place de dépôt, portage correspondant).
- ✅ Coût mesuré (2026-11-13) : 176 octets par objet (identifiants en chemin complet), soit environ 9 Ko pour 50 objets. Négligeable. Remplace l'estimation « environ 100 octets ». Pas de compression des identifiants.
- 🟡 Posture (2026-11-13) : contrainte pour le lot de posture : la posture devra passer dans l'état de pose de l'objet, avec la forme de pose (contrainte (a)).
- 🟡 Écart mineur (2026-11-13) : la position de cycle_item n'est pas sauvegardée ; les objets en main et à la ceinture sont identiques.
- ✅ Dette connue, résolue (2026-11-13) : l'indicateur de debug des surfaces a été retiré avec le HUD de debug.
- Limites de test (2026-11-13) : le doublon après rechargement n'est vérifié que par comptage. L'export et l'import du portage sont testés dans test_disposition.gd, pas dans test_carry.gd.

## Autosave (décidé le 2026-11-12) 🟡 — partiellement implémenté
- Sauvegarde sur événements plus sortie. Aucun intervalle fixe, aucune sauvegarde manuelle, un seul emplacement.
- Rangement d'un outil (12/11/2026) : l'outil remis à son emplacement déclenche une sauvegarde, avec son état. Implémenté : `Autosave`, `request_save()` pour les déclencheurs à venir.
- Sortie (12/11/2026) : quitter le jeu déclenche une sauvegarde, après la fin ou l'annulation propre de l'action d'outil en cours. Implémenté via `save_and_wait()`, réutilisable pour le retour au menu. Le retour au menu principal n'est pas encore implémenté.
- Changement de pièce (12/11/2026) : le passage d'une pièce à une autre déclenchera une sauvegarde. Non implémenté ; implémentable quand le système de pièces existe.
- Fin de surface (12/11/2026) : la fin d'une surface à nettoyer déclenche une sauvegarde. Implémenté (2026-11-12) : `Autosave` relie `surface_finished` de chaque `CleaningSurface` de la pièce (`setup()`, `watch_surface()`). Une surface terminée d'office et le chargement n'émettent pas le signal : aucune sauvegarde ; un nouveau passage sous le seuil après un chargement en déclenche une.
- Action d'outil (12/11/2026) : geste continu sur une surface, qui finit au clic relâché, à la surface quittée ou à l'outil rangé. La fin d'une action d'outil ne déclenche jamais de sauvegarde ; elle libère uniquement un déclencheur en attente.
- Déclencheurs rapprochés (12/11/2026) : ceux reçus avant la fin de l'export en cours donnent une seule écriture, l'export repartant du début. Aucun délai d'attente n'est ajouté.
- Écriture atomique : fichier temporaire, puis remplacement, avec l'ancienne version conservée en `.bak`. Le chargement lit le `.bak` si le fichier principal est illisible.
- Mesure (12/11/2026) : le coût de `export_room` est de l'encodage CPU (zstd ≈ 58 %, base64 ≈ 29 %), pas de la lecture GPU. L'export est étalé sur plusieurs images, avec un budget de 2 ms par image (provisoire), une liste de faces figée et un contrôle de validité de chaque face. Pire image mesurée : 2,98 ms en headless, contre 20,1 ms d'un bloc. Non mesuré sur un vrai GPU.
- Écriture (12/11/2026) : par `save_slot_threaded`, résultat par `save_finished`. Emplacement `partie` (provisoire).
- Décision (12/11/2026) : pas d'omission des écritures inutiles. À rouvrir si le profilage montre un problème.
- Intégration (12/11/2026) : `Autosave` est instancié dans `sponge_test.tscn` seulement, sans autoload, tant que la scène de jeu n'existe pas.
- Note (12/11/2026) : la salissure d'un outil relue du fichier peut différer sur les dernières décimales (JSON existant) ; les tests comparent avec tolérance.
- Menu : « Continuer » remplace « Nouvelle partie » si une sauvegarde existe. « Réinitialiser la partie » (Options) supprime le fichier principal et le `.bak`, ne touche pas aux réglages, puis ramène à l'écran-titre, après une alerte avec « Annuler » par défaut. Implémenté : voir la section « Réinitialiser la partie ».
- Sauvegardes illisibles (principal et `.bak`) : jamais traitées comme une absence de sauvegarde. L'écran-titre affiche « sauvegarde endommagée ». Les fichiers sont renommés (par exemple `.corrompu`), jamais supprimés ni écrasés. « Nouvelle partie » reste disponible avec confirmation, qui précise que la sauvegarde endommagée sera mise de côté. L'entrée dans le journal est conservée.

## Menu (écran-titre et pause) ✅ (12/11/2026)
- L'écran-titre est la scène principale du projet.
- La pause s'ouvre par l'action d'Input Map `pause_menu` (touche Échap).
- Le menu Options est décrit dans les sections « Réglages (Options) » et « Commandes et caméra ».
- « Retour au menu » et « Quitter » appellent `save_and_wait()` avant de sortir de la partie.
- `Player.restore_mouse_mode()` rétablit le mode de la souris à la sortie de la pause.
- Provisoire : la scène de jeu lancée depuis le titre est `sponge_test.tscn`, à remplacer par la vraie scène de jeu.
- Fait : table de traduction (13/11/2026, section « Traduction ») ; lot Options (lots A, B et Réinitialiser, 13 au 15/11/2026).

## Traduction ✅ (13/11/2026)
- Langues : fr (référence) et en, décidées par Direction le 12/11/2026.
- Un seul CSV `game/data/ui.csv`, colonnes `clés,fr,en`, importé comme ressource de traduction et déclaré dans les paramètres du projet. Langue de repli : en.
- Au premier lancement, le jeu suit la langue du système (en si elle n'est pas supportée). Le choix du joueur n'est enregistré que s'il change la langue.
- Clés au format `domaine.élément[.sous-élément]`, en minuscules. Aucune cellule vide.
- Ajouter une langue = ajouter une colonne au CSV et une ligne dans `game/data/languages.json`.
- `tools/check_project.sh` échoue si une clé trouvée dans `game/` manque dans `ui.csv`, mais seulement pour les domaines déjà présents et sans voir les clés construites dynamiquement.
- Les tests comparent à `TranslationServer.translate(clé)`, jamais à un texte en dur.
- Dette connue : le texte de debug du ToolController et le panneau d'inventaire provisoire restent en dur. 🟡 Les textes sont provisoires.

## Réglages (Options) ✅ (13/11/2026)
- Décisions de Direction du 13/11/2026, validées le 13/11/2026.
- L'autoload `Settings` (`core/settings.gd`) lit et écrit `user://settings.cfg`. Défauts, bornes et pas dans `game/data/settings_defaults.json`.
- Fichier absent, illisible ou valeur hors bornes = défaut. Valeur dans les bornes mais hors pas = arrondie au pas. Un fichier illisible est écrasé à la prochaine écriture.
- Écriture atomique, à la fermeture de l'écran Options et à la sortie du jeu.
- Affichage : plein écran non exclusif (défaut) ou fenêtré ; taille de fenêtre mémorisée ; minimum 960 × 540 (🟡 provisoire) ; synchro verticale activée par défaut.
- Volumes : quatre canaux (Master = Général, Music, Ambience, Effects), 0 à 100, pas de 5, 0 = muet. Défauts 80, 70, 100, 100 (🟡 provisoires). Disposition des canaux dans `game/default_bus_layout.tres`.

## Commandes et caméra ✅ (13/11/2026)
- Toutes les actions de jeu sont modifiables ; liste dans `game/data/controls_actions.json` (`journal_open` retirée tant que le journal n'existe pas). Échap est fixe.
- Clavier et souris, une touche par action, molette non assignable, pas de manette.
- Touches enregistrées par position physique (`physical_keycode`), seuls les écarts dans la section `[controls]`. Touche déjà prise = échange. « Touches par défaut » ne remet à zéro que les touches.
- Sensibilité de la souris : multiplicateur de 0,2 à 3,0 (1,0 = comportement d'origine), pas de 0,1 (🟡 provisoire). Inversion de l'axe vertical, désactivée par défaut.
- Champ de vision de 70 à 95°, défaut 80°, entendu en horizontal pour un écran 16:9 de référence. Le code le convertit en champ vertical pour Godot (80° horizontal vaut environ 50,5° vertical). L'ancien défaut était 75° vertical.
- 🟡 Valeurs de départ, à régler après essai.
- À vérifier à l'écran : les objets portés sont sous `Head/HandAnchor`, à côté de la caméra, donc sensibles au champ de vision.

## Réinitialiser la partie ✅ (12 et 13/11/2026)
- Décisions de Direction des 12 et 13/11/2026.
- Disponible seulement dans les Options ouvertes depuis l'écran-titre, jamais depuis la pause. Grisée sans sauvegarde (fichier principal ou `.bak` absent). Bouton rouge avec alerte de validation, « Annuler » par défaut.
- Supprime le fichier principal et le `.bak` lisibles, sans toucher aux réglages. Un fichier illisible n'est jamais supprimé : il est renommé en `.corrompu`, sans écraser un `.corrompu` existant.
- Limite connue (15/11/2026) : après une réinitialisation, un ancien `.corrompu` peut faire réapparaître l'avertissement « sauvegarde endommagée » jusqu'à la prochaine « Nouvelle partie ».

## Décisions de Direction ✅ (source : Direction 2026-11-10)
- Verrou du 100 % : booléen « restaurée » par pièce, posé au premier passage à 100 %, sauvegardé, jamais retiré. Le pourcentage affiché reflète l'état réel ; un axe ajouté plus tard ne retire pas le statut.
- Rangement : zones souples par catégorie. Un objet est rangé s'il est posé (ni tenu, ni au sol) dans une zone qui accepte sa catégorie.
- Piles : un meuble ne peut pas être déplacé tant qu'il porte au moins un objet (message d'indice pour le joueur).
- Ceinture (2026-11-10). Capacité paramétrable, 1 au départ et 5 au maximum. 6 objets portés au maximum (main + ceinture pleine), ce qui n'arrive qu'avec toutes les améliorations.
- Métal très corrodé : intégré au geste de réparation, aucun état distinct.
- Prise en main (2026-11-10, Direction). Une main (un objet) et une ceinture n'acceptant que des SMALL. Capacité de la ceinture paramétrable : 1 au départ, 5 au maximum (+1 par amélioration). SMALL : main si libre, sinon ceinture si un emplacement est libre, sinon refusé. MEDIUM ou LARGE : un SMALL en main est rangé automatiquement en ceinture, et la prise est refusée si la ceinture est pleine. Main occupée par un MEDIUM ou un LARGE : toute prise refusée, SMALL compris. Un seul LARGE, à deux mains. cycle_item échange la main avec le prochain emplacement occupé de la ceinture, et il est inactif avec un MEDIUM ou un LARGE en main.
- Sol et supports (2026-11-10, Direction). Le sol n'est jamais une zone de rangement. Un support déclaré (palette, étagère basse) n'est pas du sol, même au niveau du sol : le test repose sur la surface qui porte l'objet, pas sur une hauteur. Un objet posé sur un objet qui n'est pas un support déclaré est non rangé.
- Verrouillage de caméra (nettoyage) (2026-11-10, Direction). Pendant le verrouillage, la souris pilote un curseur ; l'outil suit le point où le rayon caméra→curseur touche la surface, et le curseur système est masqué. Le verrou est relâché automatiquement dès que l'outil n'est plus tenu ou que l'objet tenu change. La bascule se fait par une nouvelle action lock_camera, touche C (position physique), à ajouter à l'Input Map au lot de la Phase 2 qui implémente le nettoyage. Le verrouillage n'est jamais imposé, la caméra est libre par défaut, et elle reste toujours libre pendant la manipulation d'objet.
- Caméra : Pendant la manipulation d’un objet, la caméra reste toujours libre. Pendant le nettoyage, le joueur peut verrouiller la caméra avec une touche à bascule. Le verrouillage n’est jamais imposé, et la caméra est libre par défaut.
- Chute (2026-11-10). Pose instable (couverture sous le seuil) : l'objet quitte son support, tombe verticalement jusqu'au premier support valide en dessous (8 itérations au maximum), puis, s'il recouvre le volume du support quitté, est décalé horizontalement du plus petit déplacement qui l'en dégage (axes testés par distance croissante, ordre fixe en cas d'égalité), avant contrôle comme une pose. Sans position valide : pose refusée, rien ne change.
- Empilement ✅ (précision Direction, 2026-11-10 ; GDD §15 point 18). SMALL sur tout (SMALL, MEDIUM, LARGE, meuble libre) ; MEDIUM sur LARGE uniquement, jamais MEDIUM sur MEDIUM, y compris sur un meuble libre ; rien sur FIXED, sauf sur les surfaces des installations fixes déclarées (exemption) ; SMALL sur SMALL permis, non rangé. Table de données dans PlacementCheck (STACK_TABLE). Un objet portant une charge n'est pas déplaçable.
- Meubles (2026-11-10). Meuble libre : objet MEDIUM ou LARGE avec provides_support, qui porte une surface de pose déclarée. Installation fixe : catégorie FIXED, non prenable, surfaces déclarées dans la scène de la pièce. La surface du dessus d'un objet ordinaire n'est pas un support déclaré : un objet posé dessus est non rangé.
- Orientation et posture ✅ (2026-11-10, Direction). Le joueur ne règle que l'angle autour de la verticale. Les objets à plusieurs postures (livre : à plat ou debout) reçoivent la posture imposée par la zone de pose ; chaque zone déclare la posture par catégorie. Hors zone : à plat. Aucune bascule de posture par le joueur.
- Types de meubles ✅ (2026-11-10, Direction ; remplace « table fixe »). Libres, déplaçables vides seulement : palette, table. Fixes : étagère basse, bibliothèque. Un support portant des objets ne se déplace pas.
- Chute, précision ✅ (2026-11-10, Direction). Le point de dépôt doit être atteignable. L'objet n'est jamais détruit ni perdu ; il est marqué non rangé.
- Marche lente 🟡 (2026-11-10). Bascule par l'action walk_slow, à confirmer en jeu ; option d'inspecteur pour revenir au maintenu.
- Valeurs de placement 🟡 (2026-11-10). Marge au bord, couverture minimale et pas de rotation sont des réglages de départ, modifiables dans une ressource exportée par le contrôleur. Orientation permissive. Mode de rotation fin optionnel, non implémenté.
- Contraintes techniques 🟡 (2026-11-10, propositions pour les lots P1-F2 et P1-F3). (a) Une posture change l'emprise et la hauteur : PlacementCheck et PlacementLanding recevront une forme de pose (emprise, hauteur) ; ItemData.footprint et height restent la posture « à plat ». (b) La posture imposée par la zone suppose un lien PlacementSurface vers la zone, à créer avec le lot de rangement. (c) Atteignabilité du point de chute : anneau d'échantillons autour du point où une capsule joueur tient, avec ligne de vue vers l'objet, appliqué aux chutes seulement.

## Nettoyage localisé ✅ (2026-11-11)
- Masque d'état par face nettoyable (CleanableFace) : RG8, R = proprete_salete, G = proprete_mousse ; 0 = sale, 1 = propre. Aucun scalaire d'instance. Remplace le point 4 de la Phase 0.
- Périmètre : mousse sur pierre architecturale. Verrière, rambardes et mobilier : décisions séparées.
- Correspondance point visé / UV analytique via SurfaceMapping : plan (murs droits, contremarches), cylindre (fût, noyau), secteur polaire (dessus de marche). Maillages quelconques non retenus.
- Épaisseur et textures de pierre et de mousse en projection monde (plane ou cylindrique), mêmes paramètres pour le shader et le CPU ; échantillonneurs d'épaisseur sans mipmap (parité CPU/GPU). L'état est lu par l'UV2 de la face (îlot 0..1, v inversée par l'export glTF). Matériau propre à chaque face.
- Unité du 100 % : la surface (GDD §15 pt 2 clos, Direction, 2026-11-12). La face nettoyable (cellule du masque) est une unité technique : état, sauvegarde, fin de geste à tau. Reste = texels couverts (épaisseur − propreté > epsilon) / texels couverts initiaux ; face finie quand reste ≤ tau.
- Fin de geste ✅ (Direction, 2026-11-11) : à tau, les résidus de la face s'effacent (fondu ≈ 0,5 s). Le passage de la surface à « nettoyée » suit la règle « Surfaces à nettoyer » (décision du 2026-11-12). Le shader rend la mousse invisible à epsilon.
- Valeurs 🟡 provisoires, à régler en playtest, constantes uniques : epsilon = 0,05 ; tau = 0,02. Réserve : plafond en m² à rediscuter si 2 % est trop visible sur la plus grande surface.
- Sauvegarde : JSON du SaveService, RG8 compressé sans perte puis base64, id = chemin du nœud depuis la racine de la pièce, taille attendue dérivée de la scène, clé absente = sale. Faces intactes absentes. Le poids n'est pas sauvegardé.
- Noms : proprete_salete et proprete_mousse (états) ; masque_salete et masque_mousse (épaisseurs, vocabulaire d'Art) ; proprete_surface ; plus tard proprete_mousse_tenace et masque_mousse_tenace.
- Écarts du spike P2-N1 validés par le développeur (2026-11-11) : reste pondéré par l'aire (le compte de texels est aussi tenu) ; fondu de fin de geste purement visuel, état écrit propre immédiatement ; dose de clean_stroke répartie sur les tampons ; l'éponge nettoie les deux couches ensemble (GDD §4) ; l'aire sale fine remplace l'aire grossière au premier contact.
- Poids par aire sale initiale 🟡 (proposition Direction, non validée) : mesure seulement, non branché au 100 %, non sauvegardé.
- Provisoire 🟡 : échelles de texture (Art), profil du pinceau (playtest).
- Préchauffage de la grille fine (lot P2-N2, 2026-11-11) : en arrière-plan, faces à moins de 4 m du joueur ; repli synchrone au contact d'une face non prête. Valeurs 🟡 provisoires : 4 m, 2 calculs simultanés, parcours toutes les 0,25 s, budget d'affectation 2 ms par image. Projection des faces verticales sur le plan de la face : faite.
- Corrigé (2026-11-11) : masques d'épaisseur en Lossless (.import poussés, compress/mode=0) ; sens de u sur le mur courbe vu de l'intérieur ; montée des marches par step-up dans le joueur (max_step_height 0,3 m 🟡 provisoire) avec lissage de la tête après le step-up (step_smooth_time 0,12 s 🟡 provisoire). Subdivision du dessus de marche : faite.

## Surfaces à nettoyer (décision de Direction, 2026-11-12, Phase 3)
- Une surface est une zone reconnaissable d'un objet ou du décor, regroupant plusieurs faces. Les grandes surfaces sont découpées. À ne pas confondre avec les surfaces de pose.
- Fin automatique d’une surface (décision de Direction, 2026-11-12, valeurs de départ provisoires 🟡) : seuil = min(~0,5 m², 10 % de l’aire géométrique de la surface). Aire sale restante = somme des remaining_dirty_area() des faces de la surface. La fin se déclenche uniquement au passage de l’aire sale restante du dessus au dessous du seuil. Une surface propre au départ n’a pas de fin. Le reste se finit automatiquement.

- Taille d’une surface : minimum 0,5 m², maximum 2 m² par surface (Direction, 2026-11-12, valeurs de départ provisoires 🟡).
- Tailles (Direction, 2026-11-12, valeurs de départ provisoires 🟡) : mur : une face de mur = une surface (1,13 m²) ; un mur de 2 ou 3 faces donne 2 ou 3 surfaces successives ; noyau en panneaux de 6 faces (≈ 1,7 m²) ; marche : dessus + contremarche dans une même surface (0,76 m²), le dessus seul n’est jamais une surface ; les deux faces partagent le même état de fin et l’aire restante est la somme des deux.
- Noyau : une face nettoyable (CleanableFace) par panneau de 90° (6 facettes de 15°, UV2 0..1 sur le panneau), 12 panneaux pour la tour ; jamais une face par facette. Les limites de panneau sont des joints de texture, sans relief en géométrie (ART_BIBLE).
- Surface déjà propre au départ : une surface dont l’aire sale initiale est non nulle mais déjà sous le seuil est terminée d’office : elle compte comme propre dans le 100 % de la pièce, sans retour visuel ni sonore, sans autosave, sans événement de fin.
- 100 % de la pièce : chaque surface vaut 1.
- Portée du geste : 2,0 m depuis la caméra, sans limite de hauteur ; pas de plafond de hauteur à ajouter (Direction, 2026-11-12).
- Retour visuel de fin de surface (Direction, 2026-11-12, 🟡 valeurs provisoires, ) : proposition d’Art, discret, 1,4 s, une seule fois, sans trace. Livrable Art : fin_surface.gdshader (déplacé dans game/systems/cleaning/ le 2026-11-13). Placé en next_pass sur le matériau de la face terminée, progress animé de 0 à 1 en 1,4 s (tween linéaire), puis next_pass retiré. Vérifié dans Godot sur le noyau (2026-11-12) : peak retenu 0,12 🟡 (réglage de départ, à revoir dans le vestibule avec le vrai éclairage), edge_boost = 0, voile éteint à progress = 1 sans trace. Branché (CleaningSurface, après l’effacement du reste ; un seul tween sur toutes les faces de la surface, une fin pendant un voile en cours est ignorée, aucun voile au chargement ni pour une surface d’office). Le shader ne lit plus UV ; la marche (dessus + contremarche) est traitée. Limites restantes : un dessus + une contremarche contigus par surface ; edge_boost > 0 non testé ; look à revoir au vestibule ; rendu Forward+ non vérifié en conteneur. Retour sonore : Sound Design. Dépend de l’entité Surface (non codée).
- Pinceau et limites de panneau (décision Direction, 2026-11-12, 🟡 provisoire) : le geste reste envoyé à toutes les faces à portée, y compris à travers une limite de panneau ou de face. Une frange propre de largeur au plus égale au rayon du pinceau sur le panneau voisin est acceptée. Pas de filtrage sur la face visée. À réévaluer après l’entité Surface (option : limiter aux seules limites de surface). Vérifié le 2026-11-12 (tests/test_fin_surface_frange.gd, pire cas : tous les voisins nettoyés à fond le long de toutes les limites, rayon 0,15, dose 100 par limite) : la frange enlève 43,7 % de l’aire sale d’un panneau de noyau et 56 % d’une face de mur ; il reste 5 à 6 fois le seuil de fin (0,96 m² pour 0,17 m² ; 0,62 m² pour 0,11 m²). Aucune surface ne démarre sous son seuil. Bande fragile estimée : saleté initiale entre le seuil et ≈ 0,30 m² (panneau) ou ≈ 0,26 m² (mur). L’aire sale restante additionne les couches saleté et mousse alors que le seuil se calcule sur l’aire de la face : à trancher avec l’entité Surface. Tranché le 2026-11-13 : voir la décision sur le seuil de fin de surface (lecture littérale, laissée telle quelle ; réglage en playtest).


- ✅ Surface terminée d'office (2026-11-13) : propre, ou sous le seuil au départ, ou au chargement. Aucun signal ; le résidu sous le seuil reste visible ; aucun changement visuel.
- 🟡 Pic de création des grilles fines à la fin d'une grande surface (2026-11-13) : non traité. À mesurer en playtest sur GPU réel.
- ✅ Fin de surface pendant un voile de fin déjà en cours (2026-11-13) : ignorée.
- ✅ Seuil de fin et aire géométrique (2026-11-13) : le seuil est comparé à l'aire géométrique de la surface, alors que la somme saleté + mousse vaut 127 à 141 % de cette aire. Lecture littérale du GDD, laissée telle quelle. 🟡 Réglage à faire en playtest.

## Outil éponge ✅ (2026-11-11)
- ToolData : ressource de données (couches nettoyées, rayon, efficacité, perte maximale, salissure par m², portée). Instance de l'éponge : game/data/tools/sponge.tres.
- Efficacité effective = efficacité de base × (1 − salissure × perte maximale). Plancher de 10 % : invariant du code (GDD §7), pas un réglage.
- Valeurs 🟡 provisoires de l'éponge : saleté et mousse, rayon 0,08 m, efficacité 4,0 dose/s, perte maximale 0,9, salissure 0,5 par m², portée 2,0 m.
- Aire nettoyée = baisse de remaining_dirty_area() : la salissure arrive par à-coups. Validé par le développeur (2026-11-11), ainsi que le texte de debug.
- Seau de rinçage : le rinçage remet la salissure à 0 (commande par clic gauche, voir décisions du 11/11/2026 ci-dessous) ; il est sur la couche physique 3 seule.
- lock_camera ✅ : bascule (touche C), relâchée automatiquement quand l'outil n'est plus tenu ou que l'objet tenu change, et à la prise d'un objet (décision de Direction du 2026-11-10, précisée le 2026-11-11).
- Seau (2026-11-11, validé) : ItemData MEDIUM, ramassable, exclu du 100 %, non empilable (détail ci-dessous).
- Outils du joueur (2026-11-11, validé) : emplacement dédié, hors ItemData et hors ceinture ; sortis en main, rangés automatiquement à la prise d'un objet.
- Décisions du 11/11/2026 (Direction) :
  - Input Map : `equip_tool` = F (touche physique, provisoire). L'action `rinse_tool` (R) est retirée.
  - Rinçage : clic gauche sur le seau. Cette commande est distincte de la touche de ramassage.
  - Sortir l'outil est refusé si la main porte un objet (« une main, un objet ») ; le joueur pose d'abord l'objet, avec un message d'indice (clé `tool.hand_occupied`).
  - `cycle_item` range l'outil, comme la prise d'un objet : tout changement d'objet en main renvoie l'outil à son emplacement.
  - La salissure reste attachée à l'outil rangé : ranger l'outil ne le nettoie pas.
  - Seau : ItemData MEDIUM, ramassable, exclu du 100 %, non empilable (aucun objet ne peut être posé dessus) via le drapeau `ItemData.can_support_items` = false, ajouté par `fix/seau-non-empilable`.
  - Valeurs 🟡 provisoires du seau : cylindre de 0,32 × 0,32 × 0,30 m ; anneau de marqueur blanc de 20 px, bord de 2 px.
- Pas encore fait : le ToolController fixe l'outil par export (aucun lien avec l'emplacement dédié) ; seau fixe à rendre ramassable ; l'outil doit remplacer le curseur à l'écran.

## Textures du noyau ✅ (décision de Direction, 2026-11-12)
- Noyau (R = 0,5 m) : tuile d'Art = 1 tour × 1 module, soit 3,1416 × 2,16 m (N = 1), au lieu de N/4 = 3 (1,047 m). Raison : les 4 panneaux de 90° (6 faces de 15° chacun, 24 faces par anneau) ne tiennent pas dans 3 répétitions. Mur : inchangé (N = 12).
- Convention de la tuile : u = angle/360 (0 = limite de panneau), v = hauteur/2,16 depuis le bas de l'anneau.
- Lecture : projection cylindrique monde, déjà décidée pour la pierre et les masques (angle absolu), et non UV1 d'instance : l'UV1 du module (15° dans le .glb témoin) repart à u = 0 à chaque instance, donc ne parcourt que le début de la tuile. L'origine de l'angle monde est fixée par Engineering à la première intégration du noyau, alignée sur les limites de panneau géométriques du maillage (Direction, 2026-11-12) ; la couture de la texture d'Art tombe déjà sur une limite de panneau. Vérifié dans Godot le 2026-11-12 (essai tests/test_fin_surface/noyau_panneaux.tscn, 12 panneaux) : projection cylindrique monde retenue, N = 1, uv_echelle = (1, 3,1416/2,16). Origine de l'angle = axe +X monde ; les limites de panneau tombent aux angles k × 90° (u = k/4). Contrainte de montage : noyau à l'axe de la tour, tourné par multiples de 90°. Variante UV1 non retenue.
- Si lecture par UV1 (non retenue) 🟡 non testée dans Godot : échelle UV (1/3,1416 ; 1/2,16), et décalage de v de 1 − 1/2,16 (≈ 0,537) à cause de l'inversion v = 1 − hauteur de l'export glTF.
- 24 pans par anneau : provisoire 🟡 (Direction, 2026-11-12).

## Rangement (GDD §5) 🟡 (proposition d'Engineering, 2026-11-13, plan en lots)
- 🟡 Lot 1 : zones de rangement en scène (Area3D + ZoneData), critère « objet rangé » testable, signal de changement d'état. Interrogation par requêtes à la pose et à la reprise (pas de body_entered). Ni posture imposée, ni comptage par pièce, ni verrou du 100 %. État dérivé du monde, jamais sauvegardé.
- ✅ Lot de persistance de la disposition (livré 2026-11-13, [PR #112](https://github.com/Pandasylum/A-Light-Left-Behind/pull/112)) : voir Sauvegarde, « disposition et portage ». Le lot 3 en dépend, plus le lot 1.
- 🟡 Lot 2 : posture imposée par la zone, avec les contraintes (a) et (b) déjà écrites plus haut. Bloqué par GDD §15 point 3.
- 🟡 Lot 3 : comptage par pièce, pourcentage, verrou « restaurée » au premier 100 %, indicateur de progression. Dépend du lot 1 et de la persistance.
- GDD §15 points 3 (postures par objet et par zone) et 19 (liste des zones par catégorie) restent ouverts. Le lot 1 tourne sur des zones de test.
- ✅ Plan (Direction, 2026-11-13) : le lot 3 passe avant le lot 2, car la posture imposée par la zone n'a aucun objet à posture multiple dans le vestibule. Le lot 2 est reporté ; GDD §15 point 3 reste ouvert.
- ✅ Plan (Direction, 2026-11-13) : les zones de rangement gardent les catégories de taille (SMALL, MEDIUM, LARGE), sans champ « catégorie de rangement » pour l'instant.
- ✅ Plan (Direction, 2026-11-13) : les zones réelles du vestibule (GDD §15 point 19) viennent après la définition de ses meubles. D'ici là, on continue avec les zones de test.
- ✅ 2026-11-13 : le lot de persistance de la disposition et le lot 3 sont livrés.

## Progression de pièce ✅ (2026-11-13)
- ✅ 2026-11-13 : module `game/systems/progress/`, avec quatre classes : `ProgressFormula` (seul endroit où la formule est écrite), `ProgressSave` (section « progression » du SaveService), `RoomProgress` (nœud de calcul) et `ProgressIndicator` (affichage provisoire).
- ✅ 2026-11-13 (Direction ; validée à titre provisoire, à réévaluer après l'essai du vestibule) : chaque surface à nettoyer vaut 1, terminées d'office comprises. Chaque objet suivi pour le rangement vaut 1. Aucune pondération par axe.
- ✅ 2026-11-13 : pourcentage = surfaces finies plus objets rangés, sur surfaces plus objets suivis. Total à zéro : 0 %, jamais complet. Affichage entier arrondi vers le bas ; 100 n'apparaît que si la pièce est complète.
- ✅ 2026-11-13 (Direction) : le pourcentage reste calculé en direct après le premier 100 %. Un objet tombé le fait baisser. Seul le statut « restaurée » est définitif.
- ✅ 2026-11-13 : objets suivis = ceux dont `ItemData` déclare l'axe rangement. Le seau n'en déclare aucun : exclu. Les meubles libres (palette, table) ne déclarent pas le rangement en pièce 1 (axes suivis : réparation seulement) : non comptés. Un objet porté reste dans le total, non rangé. La réparation n'est pas comptée en pièce 1.
- ✅ 2026-11-13 : verrou « restaurée » par pièce (clé = identifiant de `RoomData`). Posé au premier passage à complet, jamais retiré, y compris si un axe est ajouté plus tard.
- ✅ 2026-11-13 : section « progression » du SaveService, version 1, contenant par pièce l'état « restaurée ». Les compteurs ne sont pas sauvegardés : ils sont recalculés.
- ✅ 2026-11-13 : section absente = aucune pièce restaurée, sans avertissement (ancien format). Section illisible ou version inconnue : ignorée, avertissement dans le journal. La version de format du SaveService reste inchangée.
- ✅ 2026-11-13 : poser le verrou déclenche une demande de sauvegarde (`Autosave`). Rien ne déclenche au chargement. Si le calcul au chargement donne « complet » sans verrou, celui-ci est posé sans demande de sauvegarde.
- ✅ 2026-11-13 : la scène de jeu importe la section comme les autres (nettoyage, outils, disposition). Le premier calcul a lieu à l'évaluation du rangement.
- ✅ 2026-11-13 (contrainte pour les scènes futures) : une scène qui charge ses états plus tard doit rappeler le recalcul.
- 🟡 2026-11-13 : indicateur provisoire. Il affiche le pourcentage de la pièce, les surfaces finies sur le total, les objets rangés sur les objets suivis, et la marque « restaurée ». Interface provisoire, sans décision d'art. Les libellés sont des clés `progress.*` de `game/data/ui.csv`.
- ✅ 2026-11-13 : remplace le texte de débogage des surfaces et les messages de débogage du journal, retirés.
- ✅ 2026-11-13 : test `test_progression.gd`.
- 🟡 2026-11-13, limite connue : dans la scène de jeu provisoire (`sponge_test`), aucun objet ne déclare le rangement. Le pourcentage ne porte donc que sur les surfaces. L'axe rangement est couvert par la scène de vérification de la progression. Les vrais objets déclareront le rangement avec le vestibule.
- ✅ 2026-11-13 : cas limites couverts par les tests : objet déplacé après validation, objet tombé, objet empilé sur un non-support, meuble déplacé avec ou sans charge, retour dans la pièce après sauvegarde et chargement.

## Chaîne de déverrouillage ✅ (2026-11-15)
- ✅ Module de données et de logique pure, sans scène, sans porte, sans interface, non branché au jeu. `UnlockStep` (id, zones requises, accès ouverts) et `UnlockChain` (les 6 étapes) dans `game/data/` ; données dans `game/data/unlock/unlock_chain.tres` ; `UnlockEvaluator` (`game/systems/progress/`, RefCounted, statique) est le seul endroit de la règle.
- ✅ `UnlockEvaluator.evaluate(chain, zones_restaurées)` renvoie les étapes complètes et les accès ouverts. Une étape est complète quand toutes ses zones requises sont restaurées ; elle ne dépend pas des étapes précédentes (la tour compte dès qu'elle est à 100 %, quel que soit l'ordre de pose des verrous). Une étape sans zone requise n'est jamais complète. Identifiants inconnus et doublons ignorés.
- ✅ Identifiants de zones (snake_case) : vestibule ; atelier ; hub_n0, cuisine, salle_d_eau, wc ; salon, chambre, hub_n1 ; archives_bureau, hub_n2, tour_n0_n4 ; n5, n6, lanterne. Accès ouverts : étape 1 `atelier` ; étape 2 `hub_n0`, `cuisine`, `salle_d_eau`, `wc` ; étape 3 `porte_fut_n0` ; étape 4 `acces_n2` ; étape 5 `trappe_n4_n5` ; étape 6 `fin_du_jeu`.
- 🟡 Identifiants `porte_fut_n0`, `acces_n2`, `trappe_n4_n5`, `fin_du_jeu` provisoires. Pour l'atelier et les pièces de l'étape 2, l'accès porte l'identifiant de la zone.
- ✅ Direction, 2026-11-15 : `acces_n2` provisoire accepté, à confirmer à la construction des portes du fût. Il désigne la porte du fût de N2, verrouillée jusqu'à l'étape 4. La porte du fût de N1 n'a aucun verrou : elle est ouverte dès que la tour est déverrouillée (étape 3).
- ✅ Test : `test_unlock_chain.gd`.

## Vestibule de test ✅ (décision de Direction, 2026-11-15)
- ✅ 15/11/2026 : le vestibule en blocage gris (`game/rooms/vestibule/vestibule.tscn`) est la scène de jeu provisoire ; `GameFlow.GAME_SCENE` pointe dessus (au lieu de sponge_test.tscn). Contenu de test uniquement avec l'existant : 3 surfaces à nettoyer (cleaning_spike réduit), table et palette (supports ; zones comptées depuis le 15/11/2026, voir ci-dessous), étagère basse et 2 étagères murales (zones SMALL), 9 objets suivis (voir ci-dessous), seau non suivi.
- ✅ 15/11/2026 (mise à jour) : les copies provisoires d'ItemData du vestibule sont supprimées ; la scène utilise les .tres de `game/data/items/` (mêmes id).
- 🟡 15/11/2026 — règle « objet libre suivi » (Direction, provisoire, à régler après essai du vestibule) : tout objet libre est suivi (`tracks_storing = true`), sauf les outils et le seau. Appliquée aux 9 .tres d'objets libres (test_small_1 à 7, test_medium_1, test_large_1). Les 2 meubles libres (test_furniture_low, test_furniture_tall, `provides_support`) et bucket.tres restent inchangés (non suivis) ; un meuble n'est pas un objet suivi.
- 🟡 15/11/2026 — décision de Direction (provisoire) : (1) la clé est suivie (`tracks_storing = true`), sans exception ; (2) le coffre est suivi ; (3) règle de contenu : tout objet suivi démarre non rangé (au sol ou hors zone compatible), car un objet suivi déjà dans une zone compatible compterait sans geste du joueur, ce qui est interdit. Précise la règle « objet libre suivi » ci-dessus (les exceptions « outils et seau » ne concernent pas la clé ni le coffre). La clé et le coffre n'existent pas encore ; vestibule.tscn et `test_vestibule.gd` vérifient la règle de contenu (0 objet rangé à l'ouverture d'une scène neuve).
- 🟡 15/11/2026 — table (SMALL, MEDIUM) et palette (SMALL, MEDIUM, LARGE) du vestibule deviennent des zones de rangement comptées, comme les étagères (5 zones au total). Les meubles eux-mêmes ne comptent pas. Disposition de départ : 9 objets au sol (7 SMALL, 1 MEDIUM, 1 LARGE), libre. Provisoire, à régler après essai.
- 🟡 Capacité (15/11/2026) : aucune notion de capacité n'existe dans le code (zones souples, sans nombre d'emplacements) ; vérification faite par surface d'emprise cumulée contre surface de zone, SMALL 0,33 m² pour 3,92 m², MEDIUM 0,20 m² pour 2,16 m², LARGE 0,64 m² pour 1,20 m² : tout tient.
- 🟡 15/11/2026 — contenu de test de World accepté par Direction (provisoire, à régler après essai) : le vestibule contient 10 objets suivis au sol (7 SMALL, 2 MEDIUM, 1 LARGE) : clé, boîte à vis ×3 (un seul ItemData), bobine de ficelle, gants de travail, tasse émaillée, bottes réparées, ciré plié, coffre ; ItemData en blocage gris dans `game/data/items/`. Coffre près de la porte de sortie (GDD §6) ; repère `PorteSortie` (Marker3D) sur le mur sud, sans géométrie de porte. Ordre des lots : ce contenu, puis clé, coffre et ceinture. En attendant, la clé et le coffre sont inertes (objets suivis portables, sans interaction particulière). Les anciens objets de test (.tres test_*) ne sont plus utilisés par le vestibule.

## Hypothèses 🟡
- Valeurs par défaut de `PlacementRules` (pas de rotation, marge, couverture) : provisoires, conception ouverte.

## Décisions validées ✅

### 2026-11-13 — Montée de la lanterne : appui long de saut
- Durée d'appui long : 0,6 s, valeur de données (ressource de réglages), modifiable sans toucher au code.
- Action dédiée `ladder_skip` dans l'Input Map, liée par défaut à la touche d'interaction, remappable.
- Anneau de progression pendant l'appui. Si l'appui est relâché avant la fin, l'anneau se vide et la montée continue normalement.
- Ordre d'exécution : verrou de la trappe, puis règle de la main, puis montée. Si la règle de la main refuse, l'appui long ne démarre pas.
- Verrous prévus : porte du fût, machinerie, trappe.
- 🟡 à réexaminer par Direction (GDD §15, mécanique des échelles ouverte)

### 2026-11-15 — Refonte du phare : impacts techniques
- ✅ Décisions de Direction : chaîne de déverrouillage en 6 étapes. Escalier N0-N4 (72 marches), puis trois échelles de 3 m ; règles d'échelle inchangées. Mécanique de montée = point ouvert : rien à implémenter avant décision. Plus de montée d'ambiance ni de cinématique. Le nombre de pièces principales n'est plus 7 et n'est pas redéfini. Cotes : étage 3,0 m, tour 5,9 m de diamètre, pilier 0,7 m de rayon, portes 0,9 x 2,1 m. Électricité et eau = repères, aucun système.
- ✅ Chaîne de déverrouillage en ressource de données (Direction, 2026-11-15) : étapes, identifiants de RoomData requis, verrous ouverts. L'état d'une étape se déduit des verrous « restaurée » déjà sauvegardés, sans nouvelle section de sauvegarde. Voir « Chaîne de déverrouillage ».
- ✅ Zones de la chaîne de déverrouillage (Direction, 2026-11-15, à inscrire dans GDD §6) : 1 vestibule ; 2 atelier ; 3 hub N0, cuisine, salle d'eau, WC ; 4 salon, chambre, hub N1 ; 5 archives + bureau (une zone), hub N2, tour N0-N4 ; 6 N5, N6, lanterne (trois zones). Le sas appartient au hub de son niveau. La tour N0-N4 est une zone unique (fût rond, escalier, paliers, N3 et N4, sans les sas), un seul RoomData, un seul verrou « restaurée ».
- 🟡 Proposition d'Engineering : la tour est une scène unique, sas exclus, pour que son pourcentage se recalcule d'un bloc. Les verrous d'accès (porte du fût, trappe) et les verrous de comptage (« restaurée ») restent distincts dans la ressource d'étapes.
- ✅ Comptage de la tour (Direction, 2026-11-15) : la tour compte dès qu'elle est à 100 %, même avant l'étape 5. Son verrou « restaurée » se pose à ce moment et reste définitif. Ses surfaces ne sont jamais désactivées avant l'étape 4. La trappe N4 vers N5 se déverrouille quand toutes les zones de l'étape 5 (tour, archives + bureau, hub N2) ont leur verrou « restaurée », dans n'importe quel ordre.
