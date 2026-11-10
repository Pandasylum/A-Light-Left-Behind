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
`game/rooms/test/greybox.tscn` — pièce grise de test : sol 10x10, lumière, environnement, caméra fixe (current=false), bordures 1 m (couche 1), sol = PlacementSurface is_floor, PlacedObjects, 3 supports de test (table, palette, plot ; PlacementSurface is_floor = false), 11 objets de test ramassables (TestItems, dont 2 meubles libres au sol, z = 3,4), instancie Player — player.tscn, test_item.tscn
`game/systems/player/player.gd` + `player.tscn` — Player (CharacterBody3D, classe Player) : marche/marche lente (bascule par walk_slow, export slow_walk_toggle ; maintenu si false), regard souris (yaw Player, pitch Head), Échap libère la souris, clic gauche la recapture, capteur + indice d'interaction, remise au départ sous fall_limit_y ; couche 2, masque 1 — Input Map
`game/systems/interaction/interactable.gd` — Interactable (Node, class_name) : enfant d'un corps sur la couche 3 ; prompt_key, action (PICK_UP/USE/PLACE/OPEN), signal interacted, interact() — aucune
`game/systems/interaction/interaction_sensor.gd` — InteractionSensor (enfant de Head) : raycast physique 2 m (couches 1+3), target_changed, action interact ; inactif si souris non capturée — Interactable
`game/ui/hud/interaction_prompt.tscn` + `.gd` — viseur central + indice tr(prompt_key) visible si cible — Interactable
`game/tests/test_interaction.gd` — cible, target_changed, interacted, souris non capturée, chute (pas de raycast réel ni de souris CAPTURED en headless) — player.tscn
Test : `tools/godot.sh --headless --path game --script res://tests/test_interaction.gd`
Couches de collision : 1 monde, 2 joueur, 3 interactifs (nouvelle ; valeur de masque 4).
`game/tests/test_player.gd` — structure de player.tscn, valeurs par défaut, logique de déplacement/regard — player.gd
Test : `tools/godot.sh --headless --path game --script res://tests/test_player.gd`

`game/systems/carry/carry_inventory.gd` — CarryInventory (RefCounted) : logique pure main + ceinture de SMALL (capacité 1 à 5, paramètre du constructeur), rangement automatique du SMALL en main avant un MEDIUM/LARGE, pick_up/add_to_belt/cycle_item (CYCLE_BLOCKED, NOTHING_TO_DO)/drop_object, énum Result, signaux held_changed/belt_changed — ItemData
`game/systems/carry/carry_controller.gd` — CarryController (enfant de Player ; capacité = Player.belt_capacity) : prise via Interactable PICK_UP (refusée si l'objet porte une charge : carry.supports_object), cycle_item/drop_object, HandAnchor, masquage ceinture, dépôt délégué au PlacementController (held_data/held_body/release_held) — CarryInventory, InteractionSensor, InteractionPrompt
`game/props/test_item.tscn` + `.gd` — TestItem (StaticBody3D, couche 3) : ItemData exportée, cube emprise × height, enfant PlacementSurface (dessus, is_floor = false, taille = emprise), support_surface, loads (charges posées dessus), on_placed/on_picked_up/has_loads, rests_on_declared_support() (posé sur un support déclaré non-sol, pour le rangement à venir ; dessus déclaré seulement si item_data.provides_support), Interactable PICK_UP — ItemData, interactable.gd, placement_surface.gd
`game/systems/placement/placement_surface.gd` — PlacementSurface (Node3D, class_name) : surface plate horizontale (face supérieure à l'origine), enfant d'un corps couche 1 ; size (XZ), is_floor, is_declared_support (vrai par défaut ; faux pour le dessus d'un objet ordinaire) ; of_body() — aucune
`game/systems/placement/placement_check.gd` — PlacementCheck (RefCounted) : support par échantillonnage de l'empreinte (marge, couverture de PlacementRules), Outcome (Status OK/UNSUPPORTED + coverage), can_stack(haut, bas) piloté par STACK_TABLE (provisoire, GDD §15 pt 18) — PlacementRules, PlacementSurface, ItemData
`game/systems/placement/placement_landing.gd` — PlacementLanding (RefCounted, fonctions statiques) : evaluate_pose (CANNOT_STACK/BLOCKED/UNSTABLE/OK), is_blocked (requête boîte couches 1+2+3), resolve = chute verticale par cast_motion de la boîte (8 itérations max, corps du dernier support ignoré pendant la chute, instantanée), puis dégagement horizontal du support quitté (push_out : SAT de deux OrientedRect en XZ + marge, décalages triés par distance, ordre fixe à égalité ; premier décalage valide retenu, sinon pose refusée) — PlacementCheck, PlacementRules, PlacementSurface, ItemData
`game/systems/placement/placement_controller.gd` — PlacementController (enfant de Player ; rules = @export PlacementRules) : aperçu vert (stable) / orange (va tomber) / rouge, rotation par paliers, raycast couches 1+3 (face dont la normale . haut < 0,95 = aucune surface), place_held() (place.no_surface/blocked/cannot_stack/fell ; instable = chute via PlacementLanding) — CarryController, PlacementCheck, PlacementLanding, PlacementSurface
`game/tests/test_placement.gd` — PlacementCheck, can_stack, flanc, surface des objets, push_out (axes, rectangles tournés, marge, égalité), atterrissage (chute, dégagement, cascade, 8 itérations, depuis un objet empilé) avec requêtes de forme réelles, pose/empilement/reprise/chute dans la scène grise (état forcé par _update_target, souris non capturée en headless) — placement_*.gd
Test : `tools/godot.sh --headless --path game --script res://tests/test_placement.gd`
`game/data/items/` — 11 ItemData de test (7 SMALL, 1 MEDIUM, 1 LARGE, 2 meubles libres LARGE provides_support : test_furniture_low 1,0x0,6x0,45, test_furniture_tall 0,6x0,5x0,9) — item_data.gd
`game/tests/test_carry.gd` — règles de CarryInventory (tableau de cas, capacité 1 à 5, rangement auto, cycle (CYCLE_BLOCKED/NOTHING_TO_DO), dépôt, signaux) — carry_inventory.gd
Test : `tools/godot.sh --headless --path game --script res://tests/test_carry.gd`
`game/ui/inventory/inventory_panel.tscn` + `.gd` — InventoryPanel (CanvasLayer, class_name, enfant de Player) : inventory_open affiche/masque (non modal, inactif souris libre) la liste Main + emplacements de ceinture disponibles ; label permanent bas-gauche = objet tenu ; build_rows() statique pure ; mise à jour sur held_changed/belt_changed (interface provisoire) — CarryController, CarryInventory, ItemData
`game/tests/test_inventory_panel.gd` — build_rows (main vide/tenue, ceinture partielle/pleine, capacité 1 et 5), instanciation et signaux — inventory_panel.gd
Test : `tools/godot.sh --headless --path game --script res://tests/test_inventory_panel.gd`
`game/tests/test_phase1_flow.gd` — scénario de bout en bout de la Phase 1 dans greybox.tscn (prise, rangement auto, rotation, pose, empilement, chute, reprise, meuble libre) — greybox.tscn
Test : `tools/godot.sh --headless --path game --script res://tests/test_phase1_flow.gd`
`docs/tech/PHASE1_CHECKLIST.md` — liste de vérification manuelle de la Phase 1 + valeurs provisoires à régler — greybox.tscn
`InteractionPrompt.show_message(key)` — message temporaire ~2 s sous l'indice — interaction_prompt.gd

## Données et ressources
`game/data/item_data.gd` — ItemData (Resource) : id, nom, catégorie, emprise, height (m, > 0), orientations, axes suivis, provides_support (meuble libre, MEDIUM/LARGE) ; validate() — aucune
`game/data/zone_data.gd` — ZoneData (Resource) : id, catégories acceptées (règles d'un volume Area3D de rangement) ; validate() — ItemData
`game/data/room_data.gd` — RoomData (Resource) : id, nom, pièce précédente, axes actifs ; validate() — aucune
`game/data/placement_rules.gd` — PlacementRules (Resource) : pas de rotation, marge, couverture (valeurs provisoires) ; validate() — aucune
`game/tests/data_validation_test.gd` — test de validate() des 4 classes de données — game/data/*
Test : `tools/godot.sh --headless --path game --script res://tests/data_validation_test.gd`
