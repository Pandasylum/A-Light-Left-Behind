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
`game/rooms/test/greybox.tscn` — pièce grise de test : sol 10x10, lumière, environnement, caméra fixe (current=false), bordures 1 m (couche 1), 9 objets de test ramassables (TestItems), instancie Player — player.tscn, test_item.tscn
`game/systems/player/player.gd` + `player.tscn` — Player (CharacterBody3D, classe Player) : marche/marche lente, regard souris (yaw Player, pitch Head), Échap libère la souris, clic gauche la recapture, capteur + indice d'interaction, remise au départ sous fall_limit_y ; couche 2, masque 1 — Input Map
`game/systems/interaction/interactable.gd` — Interactable (Node, class_name) : enfant d'un corps sur la couche 3 ; prompt_key, action (PICK_UP/USE/PLACE/OPEN), signal interacted, interact() — aucune
`game/systems/interaction/interaction_sensor.gd` — InteractionSensor (enfant de Head) : raycast physique 2 m (couches 1+3), target_changed, action interact ; inactif si souris non capturée — Interactable
`game/ui/hud/interaction_prompt.tscn` + `.gd` — viseur central + indice tr(prompt_key) visible si cible — Interactable
`game/tests/test_interaction.gd` — cible, target_changed, interacted, souris non capturée, chute (pas de raycast réel ni de souris CAPTURED en headless) — player.tscn
Test : `tools/godot.sh --headless --path game --script res://tests/test_interaction.gd`
Couches de collision : 1 monde, 2 joueur, 3 interactifs (nouvelle ; valeur de masque 4).
`game/tests/test_player.gd` — structure de player.tscn, valeurs par défaut, logique de déplacement/regard — player.gd
Test : `tools/godot.sh --headless --path game --script res://tests/test_player.gd`

`game/systems/carry/carry_inventory.gd` — CarryInventory (RefCounted) : logique pure main + ceinture de SMALL (capacité 1 à 5, paramètre du constructeur), rangement automatique du SMALL en main avant un MEDIUM/LARGE, pick_up/add_to_belt/cycle_item (CYCLE_BLOCKED, NOTHING_TO_DO)/drop_object, énum Result, signaux held_changed/belt_changed — ItemData
`game/systems/carry/carry_controller.gd` — CarryController (enfant de Player ; capacité = Player.belt_capacity) : prise via Interactable PICK_UP, cycle_item/drop_object, HandAnchor, masquage ceinture, dépôt provisoire à l'origine (remplacé en P1-D), label de debug (provisoire, P1-E) — CarryInventory, InteractionSensor, InteractionPrompt
`game/props/test_item.tscn` + `.gd` — TestItem (StaticBody3D, couche 3) : ItemData exportée, cube suivant l'emprise, Interactable PICK_UP — ItemData, interactable.gd
`game/data/items/` — 9 ItemData de test (7 SMALL, 1 MEDIUM, 1 LARGE) — item_data.gd
`game/tests/test_carry.gd` — règles de CarryInventory (tableau de cas, capacité 1 à 5, rangement auto, cycle (CYCLE_BLOCKED/NOTHING_TO_DO), dépôt, signaux) — carry_inventory.gd
Test : `tools/godot.sh --headless --path game --script res://tests/test_carry.gd`
`InteractionPrompt.show_message(key)` — message temporaire ~2 s sous l'indice — interaction_prompt.gd

## Données et ressources
`game/data/item_data.gd` — ItemData (Resource) : id, nom, catégorie, emprise, orientations, axes suivis ; validate() — aucune
`game/data/zone_data.gd` — ZoneData (Resource) : id, catégories acceptées (règles d'un volume Area3D de rangement) ; validate() — ItemData
`game/data/room_data.gd` — RoomData (Resource) : id, nom, pièce précédente, axes actifs ; validate() — aucune
`game/data/placement_rules.gd` — PlacementRules (Resource) : pas de rotation, marge, couverture (valeurs provisoires) ; validate() — aucune
`game/tests/data_validation_test.gd` — test de validate() des 4 classes de données — game/data/*
Test : `tools/godot.sh --headless --path game --script res://tests/data_validation_test.gd`
