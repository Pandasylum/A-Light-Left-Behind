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
