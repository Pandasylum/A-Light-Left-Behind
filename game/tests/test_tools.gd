extends SceneTree
## Test des outils de nettoyage (ToolData, ToolState, ToolSlots, ToolController, Bucket) + mesures.
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_tools.gd

const SPONGE: String = "res://data/tools/sponge.tres"
const SPIKE_SCENE: String = "res://tests/test_cleaning/cleaning_spike.tscn"
const SPONGE_SCENE: String = "res://tests/test_tools/sponge_test.tscn"
const BUCKET_SCENE: String = "res://props/bucket.tscn"
const ITEM_SCENE: String = "res://props/test_item.tscn"
const FRAME: float = 1.0 / 60.0
const SaveServiceScript: GDScript = preload("res://core/save_service.gd")
const SAVE_DIR: String = "user://test_saves/"
const SAVE_SLOT: String = "outils"

var _failures: int = 0


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var sponge: ToolData = load(SPONGE) as ToolData
	_test_data(sponge)
	_test_efficiency(sponge)
	_test_soiling(sponge)

	var spike: Node3D = (load(SPIKE_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(spike)
	_test_controller(spike, sponge)
	_test_slots(sponge)
	_test_tool_in_hand(spike, sponge)
	_test_bucket(spike, sponge)
	_test_camera_lock(spike, sponge)
	_test_save(spike, sponge)
	spike.free()

	await _measure_tour(sponge)

	print("test_tools : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


# --- ToolData ---

func _test_data(sponge: ToolData) -> void:
	_check(sponge != null, "sponge.tres se charge comme ToolData")
	if sponge == null:
		return
	_check(sponge.validate().is_empty(), "éponge valide : " + ", ".join(sponge.validate()))
	_check(sponge.id == &"sponge", "id de l'éponge")
	_check(sponge.max_efficiency_loss == 0.9, "perte maximale de l'éponge = 0,9")
	_check(ToolData.new().validate().size() == 1, "ToolData par défaut : seul l'id manque")
	var cases: Array[Array] = [
		["layers", 0], ["layers", 4], ["radius_m", 0.0], ["base_efficiency", 0.0], ["base_efficiency", -1.0],
		["max_efficiency_loss", -0.1], ["max_efficiency_loss", 0.95], ["soil_per_m2", -0.1], ["reach_m", 0.0],
	]
	for case: Array in cases:
		var data: ToolData = sponge.duplicate() as ToolData
		data.set(case[0], case[1])
		_check(data.validate().size() == 1, "validate() refuse %s = %s" % [case[0], case[1]])
	for layers: int in [1, 2, 3]:
		var data: ToolData = sponge.duplicate() as ToolData
		data.layers = layers
		_check(data.validate().is_empty(), "couches %d acceptées" % layers)


# --- Formule d'efficacité ---

func _test_efficiency(sponge: ToolData) -> void:
	var state: ToolState = ToolState.new(sponge)
	_check(state.soil == 0.0 and is_equal_approx(state.effective_efficiency(), sponge.base_efficiency),
			"outil propre : efficacité de base")
	_check(is_equal_approx(ToolState.efficiency_factor_at(0.5, 0.9), 0.55), "salissure 0,5, perte 0,9 : facteur 0,55")
	_check(is_equal_approx(ToolState.efficiency_factor_at(1.0, 0.9), 0.1), "outil sale : 10 % de l'efficacité")
	_check(is_equal_approx(ToolState.efficiency_factor_at(1.0, 0.4), 0.6), "perte 0,4 : facteur 0,6 outil sale")
	_check(is_equal_approx(ToolState.efficiency_factor_at(1.0, 0.0), 1.0), "perte nulle : aucune baisse")
	# Bornes : salissure hors de [0, 1], perte hors de [0, 0,9] (ressource invalide) : plancher tenu.
	_check(is_equal_approx(ToolState.efficiency_factor_at(-1.0, 0.9), 1.0), "salissure négative bornée à 0")
	_check(is_equal_approx(ToolState.efficiency_factor_at(5.0, 0.9), 0.1), "salissure > 1 bornée à 1")
	_check(is_equal_approx(ToolState.efficiency_factor_at(1.0, 1.0), 0.1), "plancher de 10 % même avec une perte de 100 %")
	_check(is_equal_approx(ToolState.efficiency_factor_at(1.0, -1.0), 1.0), "perte négative : jamais au-dessus de la base")
	var previous: float = INF
	var monotone: bool = true
	for i: int in 101:
		var factor: float = ToolState.efficiency_factor_at(i / 100.0, sponge.max_efficiency_loss)
		monotone = monotone and factor <= previous and factor >= 0.1 - 1e-6 and factor <= 1.0
		previous = factor
	_check(monotone, "facteur décroissant avec la salissure, dans [0,1 ; 1]")


# --- Salissure (logique pure) et rinçage ---

func _test_soiling(sponge: ToolData) -> void:
	var state: ToolState = ToolState.new(sponge)
	var emitted: Array[float] = []
	state.soil_changed.connect(func(value: float) -> void: emitted.append(value))
	state.add_cleaned_area(0.1)
	_check(is_equal_approx(state.soil, 0.1 * sponge.soil_per_m2), "salissure = aire nettoyée × vitesse")
	var before: float = state.soil
	state.add_cleaned_area(-1.0)
	state.add_cleaned_area(0.0)
	_check(state.soil == before, "aire nulle ou négative : salissure inchangée")
	var monotone: bool = true
	for i: int in 50:
		var last: float = state.soil
		state.add_cleaned_area(0.1)
		monotone = monotone and state.soil >= last
	_check(monotone, "salissure monotone")
	_check(state.soil == 1.0, "salissure plafonnée à 1")
	_check(is_equal_approx(state.effective_efficiency(), sponge.base_efficiency * 0.1), "outil saturé : plancher de 10 %")
	var count: int = emitted.size()
	state.add_cleaned_area(1.0)
	_check(emitted.size() == count, "salissure saturée : pas de signal")
	state.rinse()
	_check(state.soil == 0.0 and is_equal_approx(state.effective_efficiency(), sponge.base_efficiency),
			"rinçage : salissure 0, efficacité de base")
	_check(emitted.size() == count + 1 and emitted[-1] == 0.0, "rinçage : signal soil_changed(0)")


# --- ToolController sur des faces réelles (mini-assemblée) ---

func _largest_face(scene: Node) -> CleanableFace:
	var best: CleanableFace = null
	for face: CleanableFace in scene.get("faces"):
		if best == null or face.face_area() > best.face_area():
			best = face
	return best


func _point(face: CleanableFace, uv: Vector2) -> Vector3:
	return face.global_transform * face.mapping.point_at(uv)


func _test_controller(spike: Node3D, sponge: ToolData) -> void:
	var controller: ToolController = spike.get_node_or_null("Player/ToolController") as ToolController
	_check(controller != null, "player.tscn porte un ToolController")
	if controller == null:
		return
	_check(controller.state == null and controller.debug_text() == "", "sans outil : inactif, pas de texte")
	var face: CleanableFace = _largest_face(spike)
	var center: Vector3 = _point(face, Vector2(0.5, 0.5))
	_check(controller.stroke(center, center, 1.0) == 0.0 and not face.has_fine_grid(), "sans outil : geste sans effet")
	_check(not controller.rinse(), "sans outil : rinçage refusé")

	# Couche saleté seule : la mousse n'est pas touchée (la liste des couches est un paramètre).
	var dirt_only: ToolData = sponge.duplicate() as ToolData
	dirt_only.layers = ToolData.LAYER_DIRT
	_hold(controller, dirt_only)
	face.ensure_fine_grid()
	var moss_before: float = face.remaining_area(1)
	var dirt_before: float = face.remaining_area(0)
	var cleaned: float = controller.stroke(center, center, 1.0)
	_check(cleaned > 0.0 and face.remaining_area(0) < dirt_before, "éponge saleté seule : la saleté part")
	_check(face.remaining_area(1) == moss_before, "éponge saleté seule : mousse intacte")
	_check(is_equal_approx(controller.state.soil, minf(1.0, cleaned * sponge.soil_per_m2)), "salissure = aire réellement nettoyée × vitesse")
	_check(controller.stroke(center, center, 0.0) == 0.0, "durée nulle : aucun effet")
	var far: Vector3 = center + Vector3(0.0, 50.0, 0.0)
	var soil: float = controller.state.soil
	_check(controller.stroke(far, far, 1.0) == 0.0 and controller.state.soil == soil, "geste hors des faces : ni nettoyage ni salissure")

	# Frottement le long de la face : salissure monotone, efficacité décroissante, reste décroissant.
	_hold(controller, sponge)
	_check(controller.state.soil == 0.0, "nouvel emplacement : outil propre")
	var monotone: bool = true
	var last_point: Vector3 = _point(face, Vector2(0.2, 0.3))
	var total: float = 0.0
	for i: int in 240:
		var u: float = 0.2 + 0.6 * absf(fmod(i / 60.0, 2.0) - 1.0)
		var point: Vector3 = _point(face, Vector2(u, 0.3 + 0.4 * i / 240.0))
		var soil_before: float = controller.state.soil
		var efficiency_before: float = controller.state.effective_efficiency()
		var remaining_before: float = face.remaining_dirty_area()
		total += controller.stroke(last_point, point, FRAME)
		monotone = monotone and controller.state.soil >= soil_before \
				and controller.state.effective_efficiency() <= efficiency_before \
				and face.remaining_dirty_area() <= remaining_before
		last_point = point
	_check(monotone, "frottement : salissure croissante, efficacité et reste décroissants")
	_check(total > 0.0 and controller.state.soil > 0.0, "frottement : l'éponge se salit en nettoyant")
	_check(controller.state.effective_efficiency() >= sponge.base_efficiency * 0.1 - 1e-6, "frottement : plancher tenu")
	_check(controller.debug_text().contains("Salissure") and controller.debug_text().contains("Efficacité"), "texte de debug : salissure et efficacité")
	print("Frottement 4 s (mini-assemblée) : %.3f m² nettoyés, salissure %.0f %%, efficacité %.2f" % [
		total, controller.state.soil * 100.0, controller.state.effective_efficiency()])


# --- Emplacements d'outils (logique pure) ---

func _test_slots(sponge: ToolData) -> void:
	var slots: ToolSlots = ToolSlots.new()
	var changes: Array[int] = [0]
	slots.held_changed.connect(func() -> void: changes[0] += 1)
	_check(slots.count() == 0 and slots.held() == null and slots.held_index == ToolSlots.NONE, "emplacements : vides au départ")
	_check(not slots.toggle() and not slots.stow() and not slots.take_out(0), "emplacements vides : sortir/ranger sans effet")
	_check(slots.add_tool(null) == ToolSlots.NONE and slots.count() == 0, "emplacements : outil nul refusé")
	_check(slots.add_tool(sponge) == 0 and slots.count() == 1, "emplacements : l'éponge reçoit l'emplacement 0")
	_check(slots.held() == null and changes[0] == 0, "emplacements : aucun outil en main par défaut")
	_check(slots.add_tool(sponge) == 0 and slots.count() == 1, "emplacements : un seul emplacement par outil")
	_check(slots.take_out(0) and slots.held() != null and slots.held().data == sponge and changes[0] == 1, "sortir : l'outil est en main")
	_check(slots.take_out(0) and changes[0] == 1, "sortir l'outil déjà en main : sans changement")
	slots.held().add_cleaned_area(1.0)
	var soil: float = slots.held().soil
	_check(slots.stow() and slots.held() == null and changes[0] == 2, "ranger : plus d'outil en main")
	_check(soil > 0.0 and slots.state_at(0).soil == soil, "ranger : la salissure reste dans l'emplacement")
	_check(slots.toggle() and slots.held_index == 0 and slots.held().soil == soil, "bascule : ressort l'outil sélectionné, tel qu'il a été rangé")
	_check(slots.toggle() and slots.held() == null, "bascule : range l'outil en main")
	# Plusieurs outils : l'API prend un index (la sélection par le joueur n'est pas implémentée).
	var other: ToolData = sponge.duplicate() as ToolData
	_check(slots.add_tool(other) == 1 and slots.take_out(1) and slots.held().data == other, "second outil : son propre emplacement")
	_check(not slots.take_out(5) and slots.held_index == 1, "emplacement inexistant : refusé, outil en main inchangé")
	_check(slots.take_out(0) and slots.held().data == sponge and slots.state_at(1).data == other, "sortir un autre outil : le précédent retourne dans son emplacement")
	slots.clear()
	_check(slots.count() == 0 and slots.held() == null, "clear : plus d'emplacement, plus d'outil en main")


# --- Outil en main : action equip_tool, rangement à la prise, prise refusée, marqueur ---

func _make_item(category: ItemData.Category, id: StringName) -> TestItem:
	var item: TestItem = (load(ITEM_SCENE) as PackedScene).instantiate() as TestItem
	var data: ItemData = ItemData.new()
	data.id = id
	data.category = category
	data.footprint = Vector2(0.1, 0.1)
	data.height = 0.1
	item.item_data = data
	root.add_child(item)
	return item


func _press(node: Node, action: StringName) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	node._unhandled_input(ev)


## Headless : la souris n'est jamais CAPTURED ; les actions du ToolController ne passent donc que
## caméra verrouillée (état posé directement, comme dans _test_camera_lock).
func _test_tool_in_hand(spike: Node3D, sponge: ToolData) -> void:
	var player: Player = spike.get_node("Player") as Player
	var controller: ToolController = player.get_node("ToolController") as ToolController
	var carry: CarryController = player.get_node("CarryController") as CarryController
	controller.slots.clear()
	_check(InputMap.has_action(&"equip_tool") and not InputMap.has_action(&"rinse_tool"), "Input Map : equip_tool, plus de rinse_tool")
	_check(controller.add_tool(sponge) == 0 and controller.state == null and controller.held_tool() == null, "éponge ajoutée : rangée, aucun outil en main")
	var face: CleanableFace = _largest_face(spike)
	var center: Vector3 = _point(face, Vector2(0.8, 0.8))
	_check(controller.stroke(center, center, 1.0) == 0.0, "outil rangé : geste sans effet")
	_check(not controller.rinse(), "outil rangé : rinçage refusé")
	_press(controller, &"equip_tool")
	_check(controller.state == null, "equip_tool : sans effet si la souris n'est pas capturée (headless)")
	player.camera_locked = true
	_press(controller, &"equip_tool")
	_check(controller.held_tool() == sponge and player.camera_locked, "equip_tool : sort l'éponge (le verrou reste)")
	_check(controller.stroke(center, center, 1.0) > 0.0, "outil en main : le geste nettoie")
	var soil: float = controller.state.soil
	_press(controller, &"equip_tool")
	_check(controller.state == null and not player.camera_locked, "equip_tool : range l'éponge (verrou relâché)")
	controller.toggle_tool()
	_check(soil > 0.0 and controller.state.soil == soil, "ressortir l'outil : salissure conservée")

	# Prise refusée (objet FIXED, objet qui porte une charge) : l'outil reste en main.
	var fixed: TestItem = _make_item(ItemData.Category.FIXED, &"slot_fixed")
	carry.pick_up(fixed.get_node("Interactable") as Interactable)
	_check(carry.held_data() == null and controller.held_tool() == sponge, "prise refusée (FIXED) : l'outil reste en main")
	var loaded: TestItem = _make_item(ItemData.Category.SMALL, &"slot_loaded")
	loaded.loads.append(fixed)
	carry.pick_up(loaded.get_node("Interactable") as Interactable)
	_check(carry.held_data() == null and controller.held_tool() == sponge, "prise refusée (objet chargé) : l'outil reste en main")
	loaded.loads.clear()

	# Prise réussie : l'outil retourne dans son emplacement, avec sa salissure.
	var small: TestItem = _make_item(ItemData.Category.SMALL, &"slot_small")
	player.camera_locked = true
	carry.pick_up(small.get_node("Interactable") as Interactable)
	_check(carry.held_data() == small.item_data, "objet pris")
	_check(controller.state == null and not player.camera_locked, "prise réussie : outil rangé, verrou relâché")
	_check(controller.slots.state_at(0).soil == soil, "prise réussie : l'outil rangé garde sa salissure")
	_check(not controller.take_out() and controller.state == null, "main occupée par un objet : sortir l'outil est refusé")
	carry.release_held()
	_check(controller.take_out() and controller.held_tool() == sponge, "main libre : l'outil ressort")

	# Marqueur de visée : visible seulement caméra verrouillée.
	var marker: Control = controller.get_node("ToolDebug/AimMarker") as Control
	controller._process(0.0)
	_check(not marker.visible, "marqueur : masqué hors verrouillage")
	player.camera_locked = true
	controller._process(0.0)
	_check(marker.visible, "marqueur : visible pendant le verrouillage")
	player.camera_locked = false
	controller._process(0.0)
	_check(not marker.visible, "marqueur : masqué au déverrouillage")
	for item: TestItem in [fixed, loaded, small]:
		item.free()
	controller.slots.clear()


# --- Seau : objet libre MEDIUM, rinçage par clic ---

func _test_bucket(spike: Node3D, sponge: ToolData) -> void:
	var player: Player = spike.get_node("Player") as Player
	var controller: ToolController = player.get_node("ToolController") as ToolController
	var carry: CarryController = player.get_node("CarryController") as CarryController
	var bucket: Bucket = (load(BUCKET_SCENE) as PackedScene).instantiate() as Bucket
	root.add_child(bucket)
	var interactable: Interactable = bucket.get_node("Interactable") as Interactable
	var data: ItemData = bucket.item_data
	_check(bucket.collision_layer == 4 and interactable.action == Interactable.Action.PICK_UP, "seau : couche 3, action PICK_UP")
	_check(data != null and data.validate().is_empty(), "seau : ItemData valide")
	_check(data.category == ItemData.Category.MEDIUM and not data.provides_support, "seau : objet libre MEDIUM")
	_check(not data.tracks_cleaning and not data.tracks_repair and not data.tracks_storing, "seau : aucun axe suivi (exclu du 100 %)")
	_check(carry.inventory.add_to_belt(data) == CarryInventory.Result.NOT_STOWABLE, "seau : jamais en ceinture")

	_hold(controller, sponge)
	controller.state.add_cleaned_area(1.0)
	var soil: float = controller.state.soil
	_check(soil > 0.0, "éponge salie avant rinçage")
	var other: TestItem = _make_item(ItemData.Category.SMALL, &"not_a_bucket")
	_check(not controller.rinse_at(null) and not controller.rinse_at(other) and controller.state.soil == soil, "rinçage sans seau visé : refusé")
	_check(controller.rinse_at(bucket) and controller.state.soil == 0.0, "rinçage au seau posé, outil en main : salissure remise à 0")

	# Outil rangé : pas de rinçage.
	controller.state.add_cleaned_area(1.0)
	controller.stow_tool()
	_check(not controller.rinse_at(bucket) and controller.slots.state_at(0).soil == soil, "rinçage outil rangé : refusé")

	# Seau porté : la prise range l'outil ; même outil en main (état forcé), le seau porté ne rince pas.
	controller.take_out()
	carry.pick_up(interactable)
	_check(carry.held_body() == bucket and controller.state == null, "seau pris en main : outil rangé")
	_check(not controller.rinse_at(bucket), "seau porté, outil rangé : rinçage refusé")
	controller.slots.take_out(0)
	_check(controller.state != null and not controller.rinse_at(bucket) and controller.state.soil == soil, "seau porté, outil en main : rinçage refusé")
	carry.pick_up(other.get_node("Interactable") as Interactable)
	_check(carry.held_body() == bucket and controller.state != null, "seau porté : toute autre prise refusée (sans ranger l'outil)")
	carry.release_held()
	controller.take_out()

	# Clic maintenu sur le seau posé (rayon de visée) : rince une fois par appui, rien nettoyé derrière.
	var face: CleanableFace = _largest_face(spike)
	var behind: Vector3 = _point(face, Vector2(0.8, 0.8))
	var bucket_hit: Dictionary = {"collider": bucket, "position": behind}
	var floor_hit: Dictionary = {"collider": face, "position": behind}
	controller.state.add_cleaned_area(1.0)
	var dirty: float = face.remaining_dirty_area()
	controller.apply_aim_hit(bucket_hit, 0.1)
	_check(controller.state.soil == 0.0, "clic sur le seau posé : outil rincé")
	_check(face.remaining_dirty_area() == dirty, "clic sur le seau : rien nettoyé derrière")
	controller.state.add_cleaned_area(1.0)
	controller.apply_aim_hit(bucket_hit, 0.1)
	_check(controller.state.soil == soil, "même appui : un seul rinçage")
	controller.apply_aim_hit(floor_hit, 0.1)
	_check(controller.state.soil >= soil and controller.last_cleaned_area >= 0.0, "hors seau : nettoyage habituel")
	controller._rinse_latched = false
	controller.state.add_cleaned_area(1.0)
	var soil2: float = controller.state.soil
	controller.apply_aim_hit({"collider": other, "position": behind}, 0.1)
	_check(controller.state.soil >= soil2, "autre objet : pas de rinçage")
	controller.stow_tool()
	controller.apply_aim_hit(bucket_hit, 0.1)
	_check(controller.slots.state_at(0).soil >= soil2, "sans outil en main : pas de rinçage")
	controller.take_out()
	controller._rinse_latched = false
	carry.pick_up(interactable)
	controller.slots.take_out(0)
	controller.apply_aim_hit(bucket_hit, 0.1)
	_check(controller.state.soil >= soil2, "seau porté : pas de rinçage par clic")
	carry.release_held()
	controller.take_out()
	player.camera_locked = false
	other.free()
	bucket.free()
	controller.slots.clear()


## Met l'outil en main dans un emplacement neuf (outil propre).
func _hold(controller: ToolController, data: ToolData) -> void:
	controller.slots.clear()
	controller.add_tool(data)
	controller.take_out()


func _lock_press(player: Player) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"lock_camera"
	ev.pressed = true
	player._unhandled_input(ev)
	ev = InputEventAction.new()
	ev.action = &"lock_camera"
	ev.pressed = false
	player._unhandled_input(ev) ## le relâchement ne change rien (bascule)


## Headless : Input.mouse_mode reste VISIBLE (jamais CAPTURED), donc le verrouillage réel est refusé
## par set_camera_locked ; l'état verrouillé est posé directement, le mode souris n'est pas vérifié.
func _test_camera_lock(spike: Node3D, sponge: ToolData) -> void:
	var player: Player = spike.get_node("Player") as Player
	var controller: ToolController = player.get_node("ToolController") as ToolController
	var carry: CarryController = player.get_node("CarryController") as CarryController
	_hold(controller, sponge)
	_lock_press(player)
	_check(not player.camera_locked, "lock_camera : refusé si la souris n'est pas capturée (headless)")
	player.camera_locked = true
	_lock_press(player)
	_check(not player.camera_locked, "lock_camera : appui sur verrouillé = bascule off (relâchement de touche sans effet)")
	player.camera_locked = true
	controller.set_tool_held(true)
	_check(player.camera_locked, "set_tool_held(true) : le verrou reste")
	controller.stow_tool()
	_check(not player.camera_locked, "outil plus tenu : verrou relâché")
	controller.take_out()
	player.camera_locked = true
	controller.take_out()
	_check(player.camera_locked, "ressortir l'outil déjà en main : le verrou reste")
	# Prise d'un objet : l'objet tenu change (outil rangé) -> verrou relâché.
	var item: TestItem = (load("res://props/test_item.tscn") as PackedScene).instantiate() as TestItem
	var data: ItemData = ItemData.new()
	data.id = &"lock_test"
	data.category = ItemData.Category.SMALL
	data.footprint = Vector2(0.1, 0.1)
	data.height = 0.1
	item.item_data = data
	root.add_child(item)
	carry.pick_up(item.get_node("Interactable") as Interactable)
	_check(carry.held_data() == data, "objet pris")
	_check(not player.camera_locked, "prise d'objet : verrou relâché")
	player.camera_locked = true
	carry.release_held()
	_check(not player.camera_locked, "objet tenu change (dépôt) : verrou relâché")
	item.free()
	controller.slots.clear()



# --- Sauvegarde des outils : section « outils » à côté de « nettoyage », aller-retour, ancien format ---

## Écrit puis relit les données par le SaveService (fichier JSON réel) ; {} si l'un des deux échoue.
func _through_file(service: Node, data: Dictionary) -> Dictionary:
	var error: int = service.call("save_slot", SAVE_SLOT, data)
	var loaded: Dictionary = service.call("load_slot", SAVE_SLOT)
	_check(error == 0 and loaded["ok"], "sauvegarde : écriture et relecture par le SaveService")
	return loaded["data"] as Dictionary


func _same_slots(a: ToolSlots, b: ToolSlots) -> bool:
	if a.count() != b.count() or a.held_index != b.held_index:
		return false
	for index: int in a.count():
		if a.state_at(index).data != b.state_at(index).data or a.state_at(index).soil != b.state_at(index).soil:
			return false
	return true


func _test_save(spike: Node3D, sponge: ToolData) -> void:
	var service: Node = SaveServiceScript.new() as Node
	service.set("save_dir", SAVE_DIR)
	# Second outil générique (futur outil) : rien dans la sauvegarde n'est propre à l'éponge.
	var squeegee: ToolData = sponge.duplicate() as ToolData
	squeegee.id = &"raclette_test"
	squeegee.soil_per_m2 = 1.0 / 3.0
	var catalog: Array[ToolData] = [sponge, squeegee]
	var face: CleanableFace = _largest_face(spike)
	var center: Vector3 = _point(face, Vector2(0.5, 0.5))
	face.ensure_fine_grid()
	face.clean_stroke(center, center, 0.2, 1.0)
	var cleaning: Dictionary = CleanableFace.export_room(spike)

	# Aller-retour : un outil sale rangé, un outil sale en main.
	var source: ToolSlots = ToolSlots.new()
	source.add_tool(sponge)
	source.add_tool(squeegee)
	source.state_at(0).add_cleaned_area(0.337)
	source.state_at(1).add_cleaned_area(0.7)
	source.take_out(1)
	var soils: Array[float] = [source.state_at(0).soil, source.state_at(1).soil]
	var section: Dictionary = source.export_state()
	_check(source.held_index == 1 and source.state_at(0).soil == soils[0] and source.state_at(1).soil == soils[1], "export : état des outils inchangé")
	_check(section.get("version") == ToolSlots.SAVE_VERSION and (section["emplacements"] as Array).size() == 2, "export : version de format + une entrée par outil")
	var loaded: Dictionary = _through_file(service, {"nettoyage": cleaning, ToolSlots.SAVE_KEY: section})
	_check(loaded.get("nettoyage") == JSON.parse_string(JSON.stringify(cleaning)), "sauvegarde : section « nettoyage » intacte à côté des outils")
	var restored: ToolSlots = ToolSlots.new()
	_check(restored.import_state(loaded.get(ToolSlots.SAVE_KEY, {}) as Dictionary, catalog), "aller-retour : section « outils » acceptée")
	_check(_same_slots(source, restored), "aller-retour : outils, emplacements, salissure exacte et outil en main rétablis")
	_check(restored.held() != null and restored.held().data == squeegee and restored.state_at(0).data == sponge, "aller-retour : chaque ToolData retrouvé par son identifiant")
	_check(restored.export_state() == section, "aller-retour : ré-export identique (ni rinçage ni salissure)")
	_check(restored.stow() and restored.take_out(0) and restored.held().soil == soils[0], "aller-retour : emplacements utilisables après chargement")

	# Tout rangé, dans le contrôleur du joueur : l'outil propre en main est remplacé par l'état sauvegardé.
	var controller: ToolController = spike.get_node("Player/ToolController") as ToolController
	source.stow()
	loaded = _through_file(service, {"nettoyage": cleaning, ToolSlots.SAVE_KEY: source.export_state()})
	_hold(controller, sponge)
	_check(controller.import_tools(loaded.get(ToolSlots.SAVE_KEY, {}) as Dictionary, catalog), "contrôleur : chargement accepté")
	_check(_same_slots(source, controller.slots) and controller.state == null, "contrôleur : outils rangés et sales comme à la sauvegarde")
	_check(controller.export_tools() == source.export_state() and controller.debug_text() == "Outil : rangé", "contrôleur : ré-export identique, affichage à jour")
	controller.take_out()
	_check(controller.state != null and controller.state.soil == soils[0], "contrôleur : l'outil ressorti porte la salissure sauvegardée")

	# Ancien format : aucune section « outils » -> chargement sans erreur, aucun outil.
	loaded = _through_file(service, {"nettoyage": cleaning})
	_check(not loaded.has(ToolSlots.SAVE_KEY) and CleanableFace.import_room(spike, loaded.get("nettoyage", {}) as Dictionary) == 0, "ancien format : nettoyage rechargé sans rejet")
	_check(controller.import_tools(loaded.get(ToolSlots.SAVE_KEY, {}) as Dictionary, catalog), "ancien format : chargement sans erreur")
	_check(controller.slots.count() == 0 and controller.state == null and controller.debug_text() == "", "ancien format : le joueur n'a aucun outil")
	_check((controller.export_tools()["emplacements"] as Array).is_empty(), "sans outil : section exportée vide")

	# Fichier non fiable : toute incohérence = aucun outil (avertissement attendu dans la sortie).
	var valid: Dictionary = JSON.parse_string(JSON.stringify(section))
	var cases: Dictionary = {
		"version plus récente": func(d: Dictionary) -> void: d["version"] = ToolSlots.SAVE_VERSION + 1,
		"version absente": func(d: Dictionary) -> void: d.erase("version"),
		"liste absente": func(d: Dictionary) -> void: d["emplacements"] = "x",
		"outil inconnu": func(d: Dictionary) -> void: ((d["emplacements"] as Array)[0] as Dictionary)["id"] = "inconnu",
		"outil en double": func(d: Dictionary) -> void: ((d["emplacements"] as Array)[0] as Dictionary)["id"] = "raclette_test",
		"emplacement en double": func(d: Dictionary) -> void: ((d["emplacements"] as Array)[0] as Dictionary)["emplacement"] = 1,
		"emplacement hors bornes": func(d: Dictionary) -> void: ((d["emplacements"] as Array)[0] as Dictionary)["emplacement"] = 7,
		"salissure hors bornes": func(d: Dictionary) -> void: ((d["emplacements"] as Array)[0] as Dictionary)["salissure"] = 1.5,
		"deux outils en main": func(d: Dictionary) -> void: ((d["emplacements"] as Array)[0] as Dictionary)["en_main"] = true,
		"champ manquant": func(d: Dictionary) -> void: ((d["emplacements"] as Array)[1] as Dictionary).erase("en_main"),
	}
	for label: String in cases:
		var bad: Dictionary = valid.duplicate(true)
		(cases[label] as Callable).call(bad)
		_check(restored.import_state(valid, catalog) and restored.count() == 2, "sauvegarde : état valide rechargé avant le cas « %s »" % label)
		_check(not restored.import_state(bad, catalog) and restored.count() == 0 and restored.held() == null, "sauvegarde : %s = aucun outil + avertissement" % label)

	controller.slots.clear()
	CleanableFace.import_room(spike, {})
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir != null:
		for file: String in dir.get_files():
			if file.begins_with(SAVE_SLOT + "."):
				dir.remove(file)
	service.free()


# --- Scène de vérification + mesures : coût par image du frottement dans le tour (188 faces) ---

func _measure_tour(sponge: ToolData) -> void:
	var scene: Node3D = (load(SPONGE_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	var tour: Node3D = scene.get_node("Tour") as Node3D
	var faces: Array = tour.get("faces")
	var controller: ToolController = tour.get_node("Player/ToolController") as ToolController
	_check(controller.slots.count() == 1 and controller.state == null, "scène de vérification : éponge dans son emplacement, aucun outil en main")
	_check(not tour.is_physics_processing(), "scène de vérification : pinceau du spike coupé")
	var bucket: Bucket = scene.get_node_or_null("Bucket") as Bucket
	var item: TestItem = scene.get_node_or_null("TestItem") as TestItem
	_check(bucket != null and item != null and not (item is Bucket), "scène de vérification : seau ramassable et objet de test présents")
	await physics_frame
	await physics_frame
	for body: TestItem in [bucket, item]:
		_check(body != null and body.support_surface != null and body.support_surface.is_floor
				and is_equal_approx(body.global_position.y, body.item_data.height * 0.5),
				"scène de vérification : %s posé sur le sol" % (body.name if body != null else &"?"))
	_check(controller.take_out() and controller.held_tool() == sponge, "scène de vérification : l'éponge sort de son emplacement")
	var face: CleanableFace = _largest_face(tour)
	var last_point: Vector3 = _point(face, Vector2(0.2, 0.2))
	controller.stroke(last_point, last_point, FRAME)
	var first_usec: int = controller.last_stroke_usec
	var sum_usec: int = 0
	var worst_usec: int = 0
	var frames: int = 300
	for i: int in frames:
		var u: float = 0.2 + 0.6 * absf(fmod(i / 45.0, 2.0) - 1.0)
		var point: Vector3 = _point(face, Vector2(u, 0.2 + 0.6 * i / float(frames)))
		controller.stroke(last_point, point, FRAME)
		sum_usec += controller.last_stroke_usec
		worst_usec = maxi(worst_usec, controller.last_stroke_usec)
		last_point = point
	_check(faces.size() == 188, "tour : 188 faces (trouvé %d)" % faces.size())
	_check(controller.state.soil > 0.0, "tour : l'éponge se salit")
	print("Coût du frottement dans le tour (%d faces, face %s, headless, envoi GPU factice) : premier contact %.2f ms (grille fine %s) ; ensuite %.3f ms par image en moyenne, pire %.3f ms, sur %d images à 60 Hz ; salissure finale %.0f %%" % [
		faces.size(), face.grid_size(), first_usec / 1000.0, "synchrone", sum_usec / 1000.0 / frames, worst_usec / 1000.0, frames,
		controller.state.soil * 100.0])
	scene.free()


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("ÉCHEC : ", label)
