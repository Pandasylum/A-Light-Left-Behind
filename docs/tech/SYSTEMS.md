# SYSTEMS — carte du code

Statut : projet Godot initialisé dans `game/` (2026-11-10), squelette sans gameplay.
Mis à jour par Claude Code à chaque PR touchant l'architecture. 100 lignes maximum.
Format d'une entrée : `chemin` — rôle en une ligne — dépendances principales.

## Systèmes
`game/project.godot` [input] — actions Input Map provisoires (liste dans docs/tech/TECHNICAL.md) — aucune
`tools/` — godot.sh (télécharge/lance Godot 4.7.2 épinglé), check_project.sh (import + chargement headless) — aucune

`game/core/save_service.gd` — autoload SaveService (sans class_name, conflit Godot) : save_slot/load_slot/slot_exists, JSON versionné, écriture atomique + .bak ; checksum = SHA-256 de la chaîne JSON des données stockée telle quelle dans l'enveloppe (aucune re-sérialisation, donc stable pour les flottants) — aucune
`game/tests/save_roundtrip_test.gd` — test aller-retour/.bak/altération/version du SaveService (dossier user://test_saves/) — save_service.gd
Test : `tools/godot.sh --headless --path game --script res://tests/save_roundtrip_test.gd` (code de sortie non nul au premier échec)

## Scènes
`game/core/main.tscn` — scène principale (Node3D), instancie la scène grise — greybox.tscn
`game/rooms/test/greybox.tscn` — pièce grise de test : sol 10x10, lumière, environnement, caméra fixe — aucune

## Données et ressources
(vide)
