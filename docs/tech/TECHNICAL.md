# TECHNICAL — A Light Left Behind

Propriétaire : projet Godot Engineering. Dernière mise à jour : 2026-11-11.
Légende : ✅ décision validée · 🟡 à décider en Phase 0

## Contraintes validées ✅
- Moteur : Godot 4.7.2. Plateforme : PC uniquement (mobile abandonné le 2026-11-09).
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
Nettoyage localisé — ✅ VALIDÉ 2026-11-11
- L'état de saleté est un masque par surface (R8, 0 = sale, 1 = propre). Aucun scalaire d'instance.
- Périmètre : mousse sur pierre architecturale. Verrière, rambardes et mobilier : décisions séparées.
- Correspondance point visé / UV analytique, via SurfaceMapping : plan (murs droits, marches, contremarches), cylindre (fût, noyau). Maillages quelconques non retenus.
- Épaisseur en coordonnées monde, projection plane ou cylindrique. Mêmes paramètres pour le shader et le CPU.
- Matériau propre à chaque face ; UV2 = développée linéaire, sans recouvrement.
- Unité du 100 % : la surface. Nettoyée quand le reste de texels couverts (épaisseur - propreté > epsilon) est <= tau.
- Valeurs de départ, provisoires, à régler en playtest : epsilon = 0,05 ; tau = 0,02 (fraction des texels couverts). Constantes uniques, exposées.
- Fin de geste : une fois tau atteint, les résidus s'effacent automatiquement (fondu ~0,5 s) et la surface passe à « nettoyée ».
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
- Interaction : `interact`, `use_primary`, `use_secondary`, `drop_object`, `rotate_left`, `rotate_right`, `cycle_item`
- Interface : `inventory_open`, `journal_open`, `pause_menu`

Vérification automatique : `tools/check_project.sh` (Godot headless Linux, version épinglée à 4.7.2).

## Sauvegarde ✅
- Service `SaveService` (autoload) : enveloppe JSON {format_version, written_at, checksum, payload}, écriture via .tmp relu et validé, ancienne sauvegarde conservée en .bak.
- Le JSON de Godot relit tous les nombres en flottants (un entier revient en 1.0) : les consommateurs convertissent en entier à la lecture.
- Les vecteurs sont stockés sous forme de tableaux ; aucun objet sérialisé, le fichier est traité comme non fiable.
- Une version de format plus récente que celle supportée est refusée ; point d'extension `_migrate` vide.

Couches de collision (2026-11-10). Couche 1 : monde (sol, murs, meubles). Couche 2 : joueur (masque 1). Les couches suivantes seront ajoutées ici au fur et à mesure.
Couches de collision (2026-11-10), mise à jour. Couche 3 : objets interactifs (masque 4). Le raycast d’interaction lit les couches 1 et 3, portée 2,0 m (provisoire).

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
- Unité du 100 % : non fixée (GDD §15 pt 2). La face nettoyable (cellule du masque) est une unité technique : état, sauvegarde, fin de geste à tau. Reste = texels couverts (épaisseur − propreté > epsilon) / texels couverts initiaux ; face finie quand reste ≤ tau.
- Fin de geste ✅ (Direction, 2026-11-11) : à tau, les résidus s'effacent (fondu ≈ 0,5 s) et la surface est nettoyée. Le shader rend la mousse invisible à epsilon.
- Valeurs 🟡 provisoires, à régler en playtest, constantes uniques : epsilon = 0,05 ; tau = 0,02. Réserve : plafond en m² à rediscuter si 2 % est trop visible sur la plus grande surface.
- Sauvegarde : JSON du SaveService, RG8 compressé sans perte puis base64, id = chemin du nœud depuis la racine de la pièce, taille attendue dérivée de la scène, clé absente = sale. Faces intactes absentes. Le poids n'est pas sauvegardé.
- Noms : proprete_salete et proprete_mousse (états) ; masque_salete et masque_mousse (épaisseurs, vocabulaire d'Art) ; proprete_surface ; plus tard proprete_mousse_tenace et masque_mousse_tenace.
- Écarts du spike P2-N1 validés par le développeur (2026-11-11) : reste pondéré par l'aire (le compte de texels est aussi tenu) ; fondu de fin de geste purement visuel, état écrit propre immédiatement ; dose de clean_stroke répartie sur les tampons ; l'éponge nettoie les deux couches ensemble (GDD §4) ; l'aire sale fine remplace l'aire grossière au premier contact.
- Poids par aire sale initiale 🟡 (proposition Direction, non validée) : mesure seulement, non branché au 100 %, non sauvegardé.
- Provisoire 🟡 : échelles de texture (Art), profil du pinceau (playtest).
- À corriger : projection des faces verticales sur le plan de la face et préchauffage de la grille fine (lot P2-N2) ; subdivision du dessus de marche et masques en Lossless (Art).

## Hypothèses 🟡
- Valeurs par défaut de `PlacementRules` (pas de rotation, marge, couverture) : provisoires, conception ouverte.
