# TECHNICAL — A Light Left Behind

Propriétaire : projet Godot Engineering. Dernière mise à jour : 2026-11-10.
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
4. 🟡 Représentation de la saleté (masque ou zones), à tester en Phase 2.
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
- Ceinture (2026-11-10). Capacité paramétrable, 1 au départ et 5 au maximum. Au maximum 6 objets portés (main + ceinture pleine), ce qui n’arrive qu’avec toutes les améliorations.
- Métal très corrodé : intégré au geste de réparation, aucun état distinct.
- Prise en main (2026-11-10, Direction). Une main (un objet) et une ceinture n'acceptant que des SMALL. Capacité de la ceinture paramétrable : 1 au départ, 5 au maximum (+1 par amélioration). SMALL : main si libre, sinon ceinture si un emplacement est libre, sinon refusé. MEDIUM ou LARGE : un SMALL en main est rangé automatiquement en ceinture, et la prise est refusée si la ceinture est pleine. Main occupée par un MEDIUM ou un LARGE : toute prise refusée, SMALL compris. Un seul LARGE, à deux mains. cycle_item échange la main avec le prochain emplacement occupé de la ceinture, et il est inactif avec un MEDIUM ou un LARGE en main.
- Sol et supports (2026-11-10, Direction). Le sol n'est jamais une zone de rangement. Un support déclaré (palette, étagère basse) n'est pas du sol, même au niveau du sol : le test repose sur la surface qui porte l'objet, pas sur une hauteur. Un objet posé sur un objet qui n'est pas un support déclaré est non rangé.
- Verrouillage de caméra (nettoyage) (2026-11-10, Direction). Pendant le verrouillage, la souris pilote un curseur ; l'outil suit le point où le rayon caméra→curseur touche la surface, et le curseur système est masqué. Le verrou est relâché automatiquement dès que l'outil n'est plus tenu ou que l'objet tenu change. La bascule se fait par une nouvelle action lock_camera, touche C (position physique), à ajouter à l'Input Map au lot de la Phase 2 qui implémente le nettoyage. Le verrouillage n'est jamais imposé, la caméra est libre par défaut, et elle reste toujours libre pendant la manipulation d'objet.
- Caméra : Pendant la manipulation d’un objet, la caméra reste toujours libre. Pendant le nettoyage, le joueur peut verrouiller la caméra avec une touche à bascule. Le verrouillage n’est jamais imposé, et la caméra est libre par défaut.

## Hypothèses 🟡
- Valeurs par défaut de `PlacementRules` (pas de rotation, marge, couverture) : provisoires, conception ouverte.
