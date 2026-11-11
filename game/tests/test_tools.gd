extends SceneTree
## Test des outils de nettoyage (ToolData, ToolState, ToolController, RinseBucket) + mesures.
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_tools.gd

const SPONGE: String = "res://data/tools/sponge.tres"
const SPIKE_SCENE: String = "res://tests/test_cleaning/cleaning_spike.tscn"
const SPONGE_SCENE: String = "res://tests/test_tools/sponge_test.tscn"
const BUCKET_SCENE: String = "res://props/rinse_bucket.tscn"
const FRAME: float = 1.0 / 60.0

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
	_test_bucket(spike, sponge)
	_test_camera_lock(spike, sponge)
	spike.free()

	_measure_tour(sponge)

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
	controller.equip(dirt_only)
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
	controller.equip(sponge)
	_check(controller.state.soil == 0.0, "outil équipé : propre")
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


# --- Seau de rinçage ---

func _test_bucket(spike: Node3D, sponge: ToolData) -> void:
	var player: Node = spike.get_node("Player")
	var controller: ToolController = player.get_node("ToolController") as ToolController
	var bucket: RinseBucket = (load(BUCKET_SCENE) as PackedScene).instantiate() as RinseBucket
	root.add_child(bucket)
	var interactable: Interactable = bucket.get_node("Interactable") as Interactable
	_check(bucket.collision_layer == 4 and interactable.action == Interactable.Action.USE, "seau : couche 3, action USE")
	controller.equip(sponge)
	controller.state.add_cleaned_area(1.0)
	_check(controller.state.soil > 0.0, "éponge salie avant rinçage")
	interactable.interact(player)
	_check(controller.state.soil == 0.0, "interaction avec le seau : salissure remise à 0")
	controller.equip(null)
	interactable.interact(player)
	interactable.interact(bucket)
	_check(controller.state == null, "seau sans outil tenu ou sans joueur : sans effet, sans erreur")
	bucket.free()


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
	controller.equip(sponge)
	_lock_press(player)
	_check(not player.camera_locked, "lock_camera : refusé si la souris n'est pas capturée (headless)")
	player.camera_locked = true
	_lock_press(player)
	_check(not player.camera_locked, "lock_camera : appui sur verrouillé = bascule off (relâchement de touche sans effet)")
	player.camera_locked = true
	controller.set_tool_held(true)
	_check(player.camera_locked, "set_tool_held(true) : le verrou reste")
	controller.equip(null)
	_check(not player.camera_locked, "outil plus tenu : verrou relâché")
	controller.equip(sponge)
	player.camera_locked = true
	controller.equip(sponge)
	_check(player.camera_locked, "rééquiper l'outil tenu : le verrou reste")
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
	controller.equip(null)


# --- Scène de vérification + mesures : coût par image du frottement dans le tour (188 faces) ---

func _measure_tour(sponge: ToolData) -> void:
	var scene: Node3D = (load(SPONGE_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	var tour: Node3D = scene.get_node("Tour") as Node3D
	var faces: Array = tour.get("faces")
	var controller: ToolController = tour.get_node("Player/ToolController") as ToolController
	_check(controller.tool == sponge and controller.state != null, "scène de vérification : joueur équipé de l'éponge")
	_check(not tour.is_physics_processing(), "scène de vérification : pinceau du spike coupé")
	_check(scene.get_node_or_null("RinseBucket") is RinseBucket, "scène de vérification : seau présent")
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
