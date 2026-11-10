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
6. 🟡 Représentation des objets et de leurs emplacements de rangement.

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
