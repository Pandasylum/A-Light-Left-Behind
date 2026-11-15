extends SceneTree
## Vestibule (blocage gris) : chargement, GAME_SCENE, comptage surfaces + 11 objets suivis (7 SMALL, 3 MEDIUM dont le tableau, 1 LARGE ; ItemData .tres),
## table et palette zones comptées (meubles non comptés), verrou « restaurée » à 100 % et conservé après sauvegarde/rechargement,
## tableau (zone murale ACCROCHE, refus de posture, chute, raccrochage).
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_vestibule.gd

const SaveServiceScript: GDScript = preload("res://core/save_service.gd")
const SCENE: String = "res://rooms/vestibule/vestibule.tscn"
const SAVE_DIR: String = "user://test_saves_vestibule/"
const SURFACES: int = 3
const ITEMS: int = 11 ## 10 objets d'origine + le tableau du phare (tracks_storing, 15/11/2026)
const SWEEP_RADIUS: float = 0.15
const SWEEP_STEP: float = 0.1
const SWEEP_SEGMENTS: int = 8

var _failures: int = 0
var _service: Node
var _own_service: bool = false
var _previous_dir: Variant


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_open_service()
	_check(GameFlow.GAME_SCENE == SCENE, "GAME_SCENE pointe sur la scène vestibule")
	var scene: Node3D = _open(false)
	await _settle()
	var progress: RoomProgress = scene.get_node("RoomProgress")
	_check(progress.is_evaluated() and progress.percent() == 0 and not progress.is_restored(), "chargement sans erreur, 0 %, verrou à faux")
	for path: String in ["Spike/Player", "Autosave", "PauseMenu", "Disposition", "StorageService", "RoomProgress", "ProgressIndicator"]:
		_check(scene.has_node(path), "nœud présent : " + path)
	_check(progress.cleaning_counts() == Vector2i(0, SURFACES) and progress.storing_counts() == Vector2i(0, ITEMS),
			"comptage : %d surfaces + %d objets suivis (%s, %s)" % [SURFACES, ITEMS, str(progress.cleaning_counts()), str(progress.storing_counts())])

	# Règle de contenu (Direction 15/11/2026, provisoire) : tout objet suivi démarre non rangé, sans geste du joueur.
	var started_stored: int = 0
	for tracked: Node in (scene.get_node("StorageService") as StorageService).tracked_items():
		if (scene.get_node("StorageService") as StorageService).is_stored(tracked):
			started_stored += 1
	_check(started_stored == 0 and progress.storing_counts().x == 0 and progress.percent() == 0,
			"scène neuve : 0 objet suivi rangé (%d), 0 objet compté, 0 %%" % started_stored)

	# Comptage par taille : 7 SMALL, 3 MEDIUM (dont le tableau), 1 LARGE, tous suivis ; PorteSortie présent.
	var by_size: Array[int] = [0, 0, 0]
	for tracked: Node in (scene.get_node("StorageService") as StorageService).tracked_items():
		if (tracked as TestItem).item_data.tracks_storing:
			by_size[(tracked as TestItem).item_data.category] += 1
	_check(by_size == [7, 3, 1], "objets suivis par taille : SMALL 7, MEDIUM 3 (tableau compris), LARGE 1 (%s)" % str(by_size))
	_check(scene.get_node("PorteSortie") is Marker3D, "repère PorteSortie présent")

	# Table (SMALL/MEDIUM) et palette (SMALL/MEDIUM/LARGE) : zones comptées ; les meubles eux-mêmes ne comptent pas.
	var storage: StorageService = scene.get_node("StorageService")
	var cle: TestItem = scene.get_node("Cle")
	var bottes: TestItem = scene.get_node("Bottes")
	var coffre: TestItem = scene.get_node("Coffre")
	_check(cle.item_data == load("res://data/items/cle.tres") and coffre.item_data == load("res://data/items/coffre.tres"),
			"les objets utilisent les .tres de game/data/items/")
	# Art : chaque objet a un visuel .glb (pas de boîte de test), collision et surface conformes à l'ItemData.
	for item: Node in scene.get_children():
		# Exclusions codées en dur (visuel .glb absent) : le seau ; le tableau du phare, dont le .glb d'Art n'est
		# pas livré. À RETIRER (TableauPhare) à la livraison du .glb d'Art.
		if not (item is TestItem) or item.name == &"Bucket" or item.name == &"TableauPhare":
			continue
		var it: TestItem = item
		var data: ItemData = it.item_data
		var thick: float = TestItem.collider_thickness(data) ## épaisseur minimale du collider (PlacementRules)
		var box: Vector3 = Vector3(data.footprint.x, thick, data.footprint.y)
		var shape: BoxShape3D = (it.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		var top: PlacementSurface = it.get_node("PlacementSurface")
		_check(it.has_node("Visuel") and not it.has_node("MeshInstance3D") and it.get_node("Visuel").get_child_count() > 0,
				"visuel .glb, sans boîte de test : " + it.name)
		_check(shape != null and shape.size.is_equal_approx(box) and top.size == data.footprint
				and is_equal_approx(top.position.y, thick - data.height * 0.5), "collision et surface conformes à l'ItemData : " + it.name)
	_put(cle, _support(scene, "Table"), -3.5, -1.5)
	_put(bottes, _support(scene, "Table"), -3.2, -1.5)
	_put(coffre, _support(scene, "Table"), -3.8, -1.5)
	_check(storage.is_stored(cle) and storage.is_stored(bottes) and not storage.is_stored(coffre) and progress.storing_counts() == Vector2i(2, ITEMS),
			"table : SMALL et MEDIUM rangés, LARGE refusé, total inchangé (%s)" % str(progress.storing_counts()))
	_put(coffre, _support(scene, "Palette"), -3.5, 1.5)
	_check(storage.is_stored(coffre) and progress.storing_counts() == Vector2i(3, ITEMS), "palette : LARGE rangé (%s)" % str(progress.storing_counts()))
	_check(_zone_count(scene) == 7 and _count_nodes(scene, ^"Furniture") == 7, "7 zones comptées (basse, table, palette, 2 murales, meuble à bottes, zone du tableau), 7 meubles non suivis")
	for furniture: Node in scene.get_node("Furniture").get_children():
		_check(not (furniture is TestItem) and not furniture.has_node("StorageZone"), "meuble non compté : " + furniture.name)

	# Meuble à bottes (MEDIUM seule) : accepte un MEDIUM, refuse SMALL et LARGE. Banc : rien ne s'y pose.
	var mb_zone: StorageZone = scene.get_node("Zones/ZoneMeubleBottes")
	_check(mb_zone.zone_data.id == &"vestibule_meuble_bottes" and mb_zone.zone_data.accepted_categories == [ItemData.Category.MEDIUM],
			"meuble à bottes : zone vestibule_meuble_bottes, MEDIUM seule")
	var mb_surf: PlacementSurface = _support(scene, "MeubleBottes")
	var mb_shape: BoxShape3D = (mb_zone.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	_check(is_equal_approx(mb_surf.global_position.y, 0.55) and is_equal_approx(mb_surf.size.x, 0.86) and is_equal_approx(mb_surf.size.y, 0.36)
			and is_equal_approx(mb_shape.size.x, 0.86) and is_equal_approx(mb_shape.size.z, 0.36), "meuble à bottes : surface et zone = dessus du .glb moins marge 0,02 m")
	_put(bottes, mb_surf, 1.4, 2.5)
	_check(storage.is_stored(bottes), "meuble à bottes : MEDIUM accepté")
	_put(cle, mb_surf, 1.2, 2.5)
	_put(coffre, mb_surf, 1.6, 2.5)
	_check(not storage.is_stored(cle) and not storage.is_stored(coffre), "meuble à bottes : SMALL et LARGE refusés")
	var banc: StaticBody3D = scene.get_node("Furniture/Banc")
	_check(PlacementSurface.of_body(banc) == null and not banc.has_node("StorageZone"), "banc : ni surface de pose ni zone")
	for z: Node in scene.get_node("Zones").get_children():
		_check(not (z as StorageZone).contains_point(banc.global_position + Vector3(0.0, 0.3, 0.0)), "banc : aucune zone ne le recouvre : " + z.name)
	# Retour à l'état de départ du test.
	_put(cle, _support(scene, "Table"), -3.5, -1.5)
	_put(bottes, _support(scene, "Table"), -3.2, -1.5)
	_put(coffre, _support(scene, "Palette"), -3.5, 1.5)

	# Meubles .glb (15/11/2026, hauteurs de l'art provisoires) : surfaces et zones alignées sur le dessus,
	# dimensions horizontales (capacités) inchangées, Visuel des étagères murales pivoté de 90°.
	# nom : [hauteur monde du dessus, zone, centre Y de zone, emprise zone XZ, catégories]
	var expect: Dictionary = {
		"Table": [0.75, "ZoneTable", Vector2(1.2, 0.8), [0, 1]],
		"Palette": [0.144, "ZonePalette", Vector2(1.2, 1.0), [0, 1, 2]],
		"EtagereBasse": [0.70, "ZoneEtagereBasse", Vector2(1.2, 0.8), [0]],
		"EtagereMuraleA": [1.425, "ZoneEtagereMuraleA", Vector2(0.4, 1.0), [0]],
		"EtagereMuraleB": [1.425, "ZoneEtagereMuraleB", Vector2(0.4, 1.0), [0]],
	}
	for fname: String in expect:
		var furn: StaticBody3D = scene.get_node("Furniture/" + fname)
		var row: Array = expect[fname]
		var surf: PlacementSurface = PlacementSurface.of_body(furn)
		var zone: StorageZone = scene.get_node("Zones/" + str(row[1]))
		var zshape: BoxShape3D = (zone.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		var visuel: Node3D = furn.get_node_or_null("Visuel")
		_check(visuel != null and visuel.get_child_count() > 0 and not furn.has_node("MeshInstance3D"), "visuel .glb sans boîte de test : " + fname)
		_check(is_equal_approx(surf.global_position.y, row[0]), "surface de pose au dessus du modèle (%.3f m) : %s" % [row[0], fname])
		var is_wall: bool = fname.begins_with("EtagereMurale")
		if is_wall:
			_check(is_equal_approx(zone.global_position.y, 1.65), "zone murale inchangée (1,65 m) : " + fname)
		else:
			_check(is_equal_approx(zone.global_position.y, row[0]), "zone centrée sur le dessus : " + fname)
		_check(is_equal_approx(zshape.size.x, row[2].x) and is_equal_approx(zshape.size.z, row[2].y) and is_equal_approx(zshape.size.y, 0.6 if is_wall else 0.8),
				"zone : dimensions inchangées (capacité) : " + fname)
		_check(zone.zone_data.accepted_categories == Array(row[3], TYPE_INT, &"", null), "zone : catégories inchangées : " + fname)
		_check(is_equal_approx(zone.global_position.x, furn.global_position.x) and is_equal_approx(zone.global_position.z, furn.global_position.z),
				"zone alignée sur le meuble (XZ) : " + fname)
		var cshape: BoxShape3D = (furn.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
		_check(is_equal_approx(furn.global_position.y + cshape.size.y * 0.5, row[0]), "collision boîte : dessus = dessus du modèle : " + fname)
		_check(is_equal_approx(surf.size.x, row[2].x) and is_equal_approx(surf.size.y, row[2].y), "surface de pose : emprise inchangée : " + fname)
		if is_wall:
			var bois: MeshInstance3D = visuel.find_child("bois", true, false)
			var box: AABB = bois.global_transform * bois.get_aabb()
			_check(is_equal_approx(box.size.x, 0.4) and is_equal_approx(box.size.z, 1.0) and is_equal_approx(visuel.rotation.x, 0.0) and is_equal_approx(visuel.rotation.z, 0.0),
					"Visuel pivoté de 90° autour de la verticale (0,4 en X, 1,0 en Z), surface et zone non pivotées : " + fname)
			_check(surf.global_transform.basis.is_equal_approx(Basis()) and zone.global_transform.basis.is_equal_approx(Basis()), "surface et zone sans rotation : " + fname)
			# Plaque verticale des équerres côté -Z du modèle : doit viser le mur est (+X).
			_check((visuel.global_transform.basis * Vector3(0.0, 0.0, -1.0)).is_equal_approx(Vector3.RIGHT), "côté mur des équerres vers +X : " + fname)

	# Rangement : 100 % pose le verrou une fois.
	var locks: Array[StringName] = []
	progress.lock_posed.connect(func(id: StringName) -> void: locks.append(id))
	while _finish_next_surface(scene):
		pass
	_check(progress.cleaning_counts() == Vector2i(SURFACES, SURFACES) and not progress.is_restored(), "surfaces finies, verrou pas encore posé")
	_put(cle, _support(scene, "EtagereBasse"), 3.0, -1.2)
	_put(scene.get_node("BoiteVis1"), _support(scene, "EtagereBasse"), 3.3, -1.2)
	_put(scene.get_node("BoiteVis2"), _support(scene, "EtagereBasse"), 3.6, -1.2)
	_put(scene.get_node("BoiteVis3"), _support(scene, "EtagereBasse"), 3.9, -1.2)
	_put(scene.get_node("Bobine"), _support(scene, "EtagereMuraleA"), 4.75, -3.0)
	_put(scene.get_node("Gants"), _support(scene, "EtagereMuraleB"), 4.75, 2.8)
	_put(scene.get_node("Tasse"), _support(scene, "EtagereMuraleB"), 4.75, 3.2)
	_put(bottes, _support(scene, "Table"), -3.8, -1.5)
	_check(progress.percent() < 100 and not progress.is_restored(), "9 objets sur 11 rangés : < 100 %%, verrou à faux (%d %%)" % progress.percent())
	_put(scene.get_node("Cire"), _support(scene, "Table"), -3.2, -1.5)
	_check(progress.percent() < 100 and not progress.is_restored(), "10 objets sur 11 rangés : < 100 %%, verrou à faux (%d %%)" % progress.percent())
	_hang(scene.get_node("TableauPhare"), _wall(scene), Vector3(0.0, 1.5, -5.0))
	_check(progress.percent() == 100 and progress.is_restored() and locks == [&"vestibule"], "100 %% : verrou posé une seule fois")
	_check((scene.get_node("Autosave") as Autosave).save_and_wait() == 0, "sauvegarde écrite")
	var saved: Dictionary = _saved()
	scene.queue_free()
	await process_frame

	# Rechargement (Continuer) : verrou conservé.
	var scene_b: Node3D = _open(true)
	await _settle()
	var progress_b: RoomProgress = scene_b.get_node("RoomProgress")
	_check(progress_b.is_evaluated() and progress_b.is_restored() and progress_b.percent() == 100 and saved.has(ProgressSave.SAVE_KEY),
			"rechargement : verrou posé, 100 %% (%d %%)" % progress_b.percent())
	scene_b.queue_free()
	await process_frame

	await _tableau()
	await _tableau_persistence(true)
	await _tableau_persistence(false)
	_close_service()
	print("test_vestibule : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


## Surface murale de la zone du tableau.
func _wall(scene: Node3D) -> PlacementSurface:
	return scene.get_node("Zones/ZoneMuraleTableau/PlacementSurface")


## Accroche l'objet par le même chemin que PlacementController : ancrage sur le mur, orientation de la normale.
func _hang(item: TestItem, wall: PlacementSurface, anchor: Vector3) -> void:
	item.on_picked_up()
	item.global_transform = HangPose.transform_for(anchor, wall.wall_normal(), item.item_data)
	item.on_placed(wall)


func _aim_at(player: Player, pos: Vector3, target: Vector3) -> void:
	player.global_position = pos
	var dir: Vector3 = target - player.get_node("Head/Camera3D").global_position
	player.rotation.y = atan2(-dir.x, -dir.z)
	player.head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())


## Tableau du phare (Direction 15/11/2026, provisoire) : données, zone murale (mur nord), départ au sol, refus de
## posture, accrochage, chute depuis la zone, raccrochage. Le contrôleur est forcé actif (souris non capturée en
## headless : visée forcée puis _update_target() direct, comme test_phase1_flow.gd).
func _tableau() -> void:
	var scene: Node3D = _open(false)
	await _settle()
	var progress: RoomProgress = scene.get_node("RoomProgress")
	var storage: StorageService = scene.get_node("StorageService")
	var tableau: TestItem = scene.get_node("TableauPhare")
	var bottes: TestItem = scene.get_node("Bottes")
	var data: ItemData = tableau.item_data
	var wall: PlacementSurface = _wall(scene)
	var zone: StorageZone = scene.get_node("Zones/ZoneMuraleTableau")

	# Données : seuls les champs demandés changent, collider épaissi en donnée, visuel inchangé.
	_check(data == load("res://data/items/tableau_phare.tres") and data.validate().is_empty(), "tableau : ItemData valide, .tres de game/data/items/")
	_check(data.category == ItemData.Category.MEDIUM and data.footprint.is_equal_approx(Vector2(0.45, 0.35)) and is_equal_approx(data.height, 0.03)
			and data.postures_supportees == [ItemData.Posture.A_PLAT, ItemData.Posture.ACCROCHE] and data.tracks_storing,
			"tableau : MEDIUM, 0,45 x 0,35 m, 0,03 m, [A_PLAT, ACCROCHE], suivi (rangement)")
	var rules: PlacementRules = PlacementRules.new()
	var cshape: BoxShape3D = (tableau.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	_check(is_equal_approx(rules.collider_min_thickness, 0.05) and is_equal_approx(cshape.size.y, 0.05) and is_equal_approx(cshape.size.x, 0.45)
			and is_equal_approx(cshape.size.z, 0.35), "collider : épaisseur minimale 0,05 m (donnée de PlacementRules), emprise inchangée")
	var collision: CollisionShape3D = tableau.get_node("CollisionShape3D")
	_check(is_equal_approx(collision.position.y - cshape.size.y * 0.5, -data.height * 0.5), "collider : dessous et face arrière du visuel conservés (épaissi vers l'avant)")

	# Zone murale : mur nord, plan 0,60 x 0,50 m, normale = orientation de la zone, MEDIUM -> ACCROCHE.
	var zshape: BoxShape3D = (zone.get_node("CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	_check(zone.zone_data.validate().is_empty() and zone.zone_data.accepted_categories == [ItemData.Category.MEDIUM]
			and zone.zone_data.posture_for(ItemData.Category.MEDIUM) == ItemData.Posture.ACCROCHE
			and zone.zone_data.posture_for(ItemData.Category.SMALL) == ItemData.Posture.A_PLAT, "zone murale : MEDIUM accepté et ACCROCHE imposé")
	_check(wall.is_wall and wall.zone == zone and wall.size.is_equal_approx(Vector2(0.6, 0.5))
			and is_equal_approx(zshape.size.x, 0.6) and is_equal_approx(zshape.size.y, 0.5), "zone murale : plan 0,60 m x 0,50 m (surface et volume)")
	_check(wall.wall_normal().is_equal_approx(Vector3(0.0, 0.0, 1.0)) and is_equal_approx(zone.global_position.z, -5.0),
			"zone murale : sur le mur nord, normale +Z (orientation de la zone)")

	# Départ : au sol, à plat, hors zone, non rangé ; 10 objets d'origine suivis + le tableau.
	var tracked: int = 0
	for item: TestItem in storage.tracked_items():
		if item.item_data.tracks_storing and item != tableau:
			tracked += 1
	_check(tracked == 10 and progress.storing_counts() == Vector2i(0, ITEMS), "départ : 10 objets suivis + le tableau (%s)" % str(progress.storing_counts()))
	_check(tableau.support_surface != null and tableau.support_surface.is_floor and tableau.global_basis.y.is_equal_approx(Vector3.UP)
			and not zone.contains_item(tableau) and not storage.is_stored(tableau) and progress.percent() == 0,
			"départ : tableau au sol, à plat, hors zone, non rangé, 0 %%")

	var player: Player = scene.get_node("Spike/Player")
	var carry: CarryController = player.get_node("CarryController")
	var placement: PlacementController = player.get_node("PlacementController")
	var standing: Vector3 = Vector3(0.0, 0.05, -3.5)
	var center: Vector3 = Vector3(0.0, 1.5, -5.0)

	# Refus : un MEDIUM sans ACCROCHE (bottes) sur la zone murale.
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var check: PlacementCheck = PlacementCheck.new()
	_check(PlacementLanding.evaluate_pose(space, check, bottes.item_data, 0.0, center, wall) == PlacementLanding.Verdict.POSTURE_REFUSED
			and check.evaluate(bottes.item_data, 0.0, center, wall).status == PlacementCheck.Status.POSTURE_REFUSED,
			"zone murale : MEDIUM sans ACCROCHE refusé (POSTURE_REFUSED)")
	carry.pick_up(bottes.get_node("Interactable"))
	_aim_at(player, standing, center)
	await physics_frame
	placement._update_target()
	_check(placement._surface == wall and placement._verdict == PlacementController.Verdict.BLOCKED, "visée : bottes refusées sur la zone murale (aperçu rouge)")
	placement.place_held()
	_check(carry.held_body() == bottes and bottes.support_surface == null, "bottes toujours en main : aucune pose")
	_aim_at(player, Vector3(1.0, 0.05, -3.3), Vector3(1.0, 0.0, -4.2)) # loin du joueur et du mur
	await physics_frame
	placement._update_target()
	placement.place_held() # repose les bottes au sol (mains libres)
	_check(carry.held_body() == null and bottes.support_surface != null and bottes.support_surface.is_floor, "bottes reposées au sol")
	await physics_frame

	# Accrochage au centre de la zone : face arrière contre le mur, orientation de la normale, rangé.
	carry.pick_up(tableau.get_node("Interactable"))
	_aim_at(player, standing, center)
	await physics_frame
	placement._update_target()
	_check(placement._surface == wall and placement._verdict == PlacementController.Verdict.OK, "visée : tableau accrochable au centre de la zone (vert)")
	placement.place_held()
	var back_face: Vector3 = tableau.global_position - tableau.global_basis.y * data.height * 0.5
	_check(carry.held_body() == null and tableau.support_surface == wall and tableau.global_basis.y.is_equal_approx(Vector3(0.0, 0.0, 1.0))
			and is_equal_approx(back_face.z, -5.0), "accroché : face arrière contre le mur nord, orientation imposée par la normale")
	_check(storage.is_stored(tableau) and progress.storing_counts() == Vector2i(1, ITEMS), "accroché : rangé (%s)" % str(progress.storing_counts()))
	var hung_percent: int = progress.percent()
	_check(hung_percent > 0, "accroché : pourcentage > 0 (%d %%)" % hung_percent)
	await physics_frame

	# Chute depuis la zone : visée au bord (couverture insuffisante), le tableau tombe à plat au sol, non rangé.
	carry.pick_up(tableau.get_node("Interactable"))
	_aim_at(player, standing, Vector3(0.5, 1.5, -5.0))
	await physics_frame
	placement._update_target()
	_check(placement._surface == wall and placement._verdict == PlacementController.Verdict.UNSTABLE, "visée au bord de la zone : instable (orange)")
	placement.place_held()
	_check(carry.held_body() == null and tableau.support_surface != null and tableau.support_surface.is_floor
			and tableau.global_basis.y.is_equal_approx(Vector3.UP) and is_equal_approx(tableau.global_position.y, data.height * 0.5),
			"chute : le tableau reste à plat au sol")
	_check(not storage.is_stored(tableau) and progress.percent() < hung_percent and progress.storing_counts().x == 0,
			"chute : non rangé, pourcentage en baisse (%d %% < %d %%)" % [progress.percent(), hung_percent])
	await physics_frame

	# Raccrochage : le pourcentage remonte.
	carry.pick_up(tableau.get_node("Interactable"))
	_aim_at(player, standing, center)
	await physics_frame
	placement._update_target()
	placement.place_held()
	_check(tableau.support_surface == wall and storage.is_stored(tableau) and progress.percent() == hung_percent,
			"raccrochage : rangé, pourcentage remonté (%d %%)" % progress.percent())
	scene.queue_free()
	await process_frame


## Sauvegarde → rechargement du tableau, sur la vraie zone murale : accroché (même transform, toujours rangé, même
## nombre d'objets rangés) ou tombé à plat (rechargé à plat, non rangé). Champ « rotation » écrit dans l'entrée.
func _tableau_persistence(hung: bool) -> void:
	var tag: String = "accroché" if hung else "tombé à plat"
	var scene: Node3D = _open(false)
	await _settle()
	var tableau: TestItem = scene.get_node("TableauPhare")
	var wall: PlacementSurface = _wall(scene)
	var anchor: Vector3 = Vector3(0.0, 1.5, -5.0)
	var floor_surface: PlacementSurface = tableau.support_surface
	_hang(tableau, wall, anchor)
	if not hung: # chute : posé au sol, à plat, au même endroit qu'après une chute
		tableau.on_picked_up()
		tableau.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.5, tableau.item_data.height * 0.5, -4.0))
		tableau.on_placed(floor_surface)
	await physics_frame
	var storage: StorageService = scene.get_node("StorageService")
	var stored_before: int = (scene.get_node("RoomProgress") as RoomProgress).storing_counts().x
	var transform_before: Transform3D = tableau.global_transform
	_check(storage.is_stored(tableau) == hung, "persistance (%s) : état de départ" % tag)
	_check((scene.get_node("Autosave") as Autosave).save_and_wait() == 0, "persistance (%s) : sauvegarde écrite" % tag)
	var entry: Dictionary = {}
	for raw: Variant in (_saved().get("disposition", {}) as Dictionary).get("objets", []):
		if (raw as Dictionary)["id"] == "TableauPhare":
			entry = raw
	_check(entry.has("rotation") and (entry["rotation"] as Array).size() == 4, "persistance (%s) : champ « rotation » écrit" % tag)
	scene.queue_free()
	await process_frame

	var reloaded: Node3D = _open(true)
	await _settle()
	var again: TestItem = reloaded.get_node("TableauPhare")
	_check(again.global_transform.is_equal_approx(transform_before), "persistance (%s) : même transform (%s)" % [tag, str(again.global_transform)])
	var storage_again: StorageService = reloaded.get_node("StorageService")
	for i: int in 5:
		await physics_frame
	var stored_after: int = (reloaded.get_node("RoomProgress") as RoomProgress).storing_counts().x
	_check(storage_again.is_stored(again) == hung and stored_after == stored_before,
			"persistance (%s) : rangé = %s, même nombre d'objets rangés (%d)" % [tag, str(hung), stored_before])
	_check(again.global_basis.y.is_equal_approx(Vector3(0.0, 0.0, 1.0)) == hung and again.global_basis.y.is_equal_approx(Vector3.UP) == not hung,
			"persistance (%s) : %s" % [tag, "face contre le mur (axe horizontal conservé)" if hung else "à plat"])
	reloaded.queue_free()
	await process_frame


func _zone_count(scene: Node3D) -> int:
	return scene.get_node("Zones").get_child_count()


func _count_nodes(scene: Node3D, path: NodePath) -> int:
	return scene.get_node(path).get_child_count()


func _support(scene: Node3D, name: String) -> PlacementSurface:
	return PlacementSurface.of_body(scene.get_node("Furniture/" + name))


func _put(item: TestItem, surface: PlacementSurface, x: float, z: float) -> void:
	item.on_picked_up()
	item.global_position = Vector3(x, surface.top_y() + item.item_data.height * 0.5, z)
	item.on_placed(surface)


func _finish_next_surface(scene: Node3D) -> bool:
	for surface: CleaningSurface in CleaningSurface.room_surfaces(scene.get_node("Spike")):
		if not surface.is_finished():
			for face: CleanableFace in surface.faces:
				if is_instance_valid(face):
					_sweep(face)
			return true
	return false


func _sweep(face: CleanableFace) -> void:
	face.ensure_fine_grid()
	var xform: Transform3D = face.global_transform
	var size: Vector3 = face.world_bounds().size
	var rows: int = ceili(maxf(size.x, maxf(size.y, size.z)) / SWEEP_STEP) + 1
	for j: int in rows + 1:
		for i: int in SWEEP_SEGMENTS:
			var v: float = float(j) / float(rows)
			face.clean_stroke(xform * face.mapping.point_at(Vector2(float(i) / SWEEP_SEGMENTS, v)),
					xform * face.mapping.point_at(Vector2(float(i + 1) / SWEEP_SEGMENTS, v)), SWEEP_RADIUS, 100.0)


func _open_service() -> void:
	_service = root.get_node_or_null("SaveService")
	_own_service = _service == null
	if _own_service:
		_service = SaveServiceScript.new() as Node
		_service.name = "SaveService"
		root.add_child(_service)
	_previous_dir = _service.get("save_dir")
	_service.set("save_dir", SAVE_DIR)
	_clear_saves()
	GameFlow.continue_requested = false


func _close_service() -> void:
	_service.call(&"flush")
	_clear_saves()
	_service.set("save_dir", _previous_dir)
	GameFlow.continue_requested = false
	if _own_service:
		_service.free()


func _clear_saves() -> void:
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir == null:
		return
	for file: String in dir.get_files():
		dir.remove(file)


func _open(continue_game: bool) -> Node3D:
	GameFlow.continue_requested = continue_game
	var scene: Node3D = (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	return scene


func _settle() -> void:
	await physics_frame
	await physics_frame


func _saved() -> Dictionary:
	var loaded: Dictionary = _service.call("load_slot", Autosave.SLOT_ID)
	return loaded["data"] as Dictionary if loaded["ok"] else {}


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_failures += 1
