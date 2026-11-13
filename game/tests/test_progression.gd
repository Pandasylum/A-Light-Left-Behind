extends SceneTree
## Progression de pièce : formule pure (ProgressFormula), section de sauvegarde (ProgressSave), puis cas
## en scène : progression_test.tscn (chaîne complète, verrou, Autosave, sauvegarde/chargement, indicateur),
## rangement_test.tscn (chute, meubles) et une pièce synthétique (surfaces terminées d'office).
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_progression.gd

const SaveServiceScript: GDScript = preload("res://core/save_service.gd")
const SCENE: String = "res://tests/test_progression/progression_test.tscn"
const SPONGE_SCENE: String = "res://tests/test_tools/sponge_test.tscn"
const RANGEMENT_SCENE: String = "res://tests/test_rangement/rangement_test.tscn"
const SAVE_DIR: String = "user://test_saves_progression/"
const SHADER: String = "res://systems/cleaning/pierre_nettoyable.gdshader"
const ROOM_ID: StringName = &"progression_test"
const CLEANING: RoomData.Axis = RoomData.Axis.CLEANING
const REPAIR: RoomData.Axis = RoomData.Axis.REPAIR
const STORING: RoomData.Axis = RoomData.Axis.STORING

var _failures: int = 0
var _service: Node
var _own_service: bool = false
var _previous_dir: Variant


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_formula()
	_save_section()
	_open_service()
	await _scene_chain()
	await _scene_lock_merge()
	await _scene_carried_and_stacked()
	await _scene_signals_and_indicator()
	await _scene_save_load()
	await _sponge_load()
	await _greybox()
	await _synthetic_room()
	_close_service()
	print("test_progression : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


# --- Fonction pure ---------------------------------------------------------------------------

func _data(tracks: bool) -> ItemData:
	var data: ItemData = ItemData.new()
	data.id = &"x"
	data.tracks_storing = tracks
	return data


func _axes(list: Array[RoomData.Axis]) -> Array[RoomData.Axis]:
	return list


func _formula() -> void:
	var both: Array[RoomData.Axis] = [CLEANING, STORING]
	# Total à zéro : 0 %, jamais complet.
	var empty: ProgressFormula.Result = ProgressFormula.compute(both, 0, 0, [], [])
	_check(empty.total == 0 and empty.percent == 0 and not empty.complete, "formule : total 0 = 0 %, pas complet")
	_check(not ProgressFormula.is_complete(0, 0) and ProgressFormula.display_percent(0, 0) == 0, "formule : 0/0 jamais complet")
	_check(not ProgressFormula.compute(_axes([]), 5, 5, [_data(true)], [true]).complete, "formule : aucun axe actif = total 0, pas complet")
	# Axes mixtes : 2/4 surfaces + 1/2 objets suivis = 3/6.
	var mixed: ProgressFormula.Result = ProgressFormula.compute(both, 2, 4, [_data(true), _data(true)], [true, false])
	_check(mixed.cleaning_done == 2 and mixed.cleaning_total == 4 and mixed.storing_done == 1 and mixed.storing_total == 2
			and mixed.done == 3 and mixed.total == 6 and mixed.percent == 50 and not mixed.complete, "formule : axes mixtes (3/6 = 50 %)")
	# Arrondi vers le bas : 1/3 = 33, 2/3 = 66, 99,5 % = 99.
	_check(ProgressFormula.display_percent(1, 3) == 33 and ProgressFormula.display_percent(2, 3) == 66, "formule : arrondi vers le bas (33, 66)")
	_check(ProgressFormula.display_percent(199, 200) == 99 and ProgressFormula.display_percent(999, 1000) == 99
			and ProgressFormula.display_percent(9999, 10000) == 99, "formule : 99,x % n'affiche pas 100")
	_check(ProgressFormula.display_percent(3, 3) == 100 and ProgressFormula.is_complete(3, 3) and ProgressFormula.display_percent(1, 1) == 100,
			"formule : 100 seulement si complet")
	var near: ProgressFormula.Result = ProgressFormula.compute(both, 199, 200, [], [])
	_check(near.percent == 99 and not near.complete, "formule : 199/200 = 99 %, pas complet")
	_check(ProgressFormula.compute(both, 200, 200, [], []).percent == 100, "formule : 200/200 = 100 %, complet")
	# Objets suivis seulement : le seau (aucun axe suivi), un objet sans axe et une donnée absente sont exclus.
	var bucket: ItemData = load("res://data/items/bucket.tres") as ItemData
	var tracked_only: ProgressFormula.Result = ProgressFormula.compute(both, 0, 0, [bucket, _data(false), null, _data(true)], [true, true, true, false])
	_check(not bucket.tracks_storing and tracked_only.storing_total == 1 and tracked_only.storing_done == 0,
			"formule : seau et objets sans axe suivi exclus du total")
	var all_stored: ProgressFormula.Result = ProgressFormula.compute(both, 0, 0, [bucket, _data(true)], [false, true])
	_check(all_stored.complete and all_stored.percent == 100, "formule : le seau non rangé ne bloque pas le 100 %")
	# Objet porté : dans le total, pas rangé.
	var carried: ProgressFormula.Result = ProgressFormula.compute(both, 1, 1, [_data(true), _data(true)], [true, false])
	_check(carried.storing_total == 2 and carried.storing_done == 1 and carried.done == 2 and carried.total == 3 and carried.percent == 66
			and not carried.complete, "formule : objet porté compté, non rangé")
	# Axes : la réparation n'est jamais comptée ; un axe inactif ne compte pas.
	var with_repair: Array[RoomData.Axis] = [CLEANING, REPAIR, STORING]
	var repaired: ProgressFormula.Result = ProgressFormula.compute(with_repair, 2, 4, [_data(true)], [true])
	_check(repaired.total == 5 and repaired.done == 3, "formule : axe réparation actif, rien n'est compté pour lui")
	_check(ProgressFormula.compute(_axes([REPAIR]), 3, 3, [_data(true)], [true]).total == 0, "formule : réparation seule = total 0")
	var cleaning_only: ProgressFormula.Result = ProgressFormula.compute(_axes([CLEANING]), 1, 2, [_data(true)], [true])
	_check(cleaning_only.total == 2 and cleaning_only.storing_total == 0 and not cleaning_only.storing_active,
			"formule : rangement inactif = objets ignorés")
	var storing_only: ProgressFormula.Result = ProgressFormula.compute(_axes([STORING]), 3, 3, [_data(true)], [false])
	_check(storing_only.total == 1 and storing_only.cleaning_total == 0, "formule : nettoyage inactif = surfaces ignorées")
	# Bornes.
	_check(ProgressFormula.compute(both, 9, 3, [], []).cleaning_done == 3 and ProgressFormula.compute(both, -2, 3, [], []).cleaning_done == 0,
			"formule : surfaces finies bornées à [0, total]")
	_check(ProgressFormula.compute(both, 0, 0, [_data(true)], []).storing_done == 0, "formule : état « rangé » manquant = non rangé")
	_check(mixed.same_as(ProgressFormula.compute(both, 2, 4, [_data(true), _data(true)], [true, false]))
			and not mixed.same_as(ProgressFormula.compute(both, 3, 4, [_data(true), _data(true)], [true, false])) and not mixed.same_as(null),
			"formule : same_as compare les compteurs")


# --- Section de sauvegarde -------------------------------------------------------------------

func _save_section() -> void:
	var section: Dictionary = ProgressSave.make_section({"salle_a": true, &"salle_b": true, "salle_c": false})
	_check(section["version"] == ProgressSave.SAVE_VERSION and ProgressSave.SAVE_VERSION == 1 and section[ProgressSave.ROOMS_KEY] == {"salle_a": true, "salle_b": true},
			"section : version 1, seules les pièces restaurées sont écrites")
	var read: ProgressSave.Plan = ProgressSave.parse(JSON.parse_string(JSON.stringify(section)))
	_check(read.accepted and read.restored.size() == 2 and read.restored.has("salle_a") and read.restored.has("salle_b"), "section : aller-retour JSON")
	var absent: ProgressSave.Plan = ProgressSave.parse({})
	_check(absent.accepted and absent.restored.is_empty(), "section : absente = aucune pièce restaurée")
	var rejected: Dictionary = {
		"pas un dictionnaire": "x",
		"null": null,
		"sans version": {ProgressSave.ROOMS_KEY: {}},
		"version texte": {"version": "1", ProgressSave.ROOMS_KEY: {}},
		"version fractionnaire": {"version": 1.5, ProgressSave.ROOMS_KEY: {}},
		"version inconnue": {"version": 2, ProgressSave.ROOMS_KEY: {}},
		"version zéro": {"version": 0, ProgressSave.ROOMS_KEY: {}},
		"sans liste": {"version": 1},
		"liste illisible": {"version": 1, ProgressSave.ROOMS_KEY: [true]},
		"valeur non booléenne": {"version": 1, ProgressSave.ROOMS_KEY: {"salle_a": 1}},
		"identifiant vide": {"version": 1, ProgressSave.ROOMS_KEY: {"": true}},
	}
	for label: String in rejected:
		var plan: ProgressSave.Plan = ProgressSave.parse(rejected[label])
		_check(not plan.accepted and plan.restored.is_empty() and not plan.error.is_empty(), "section : rejetée (%s)" % label)
	var mixed: ProgressSave.Plan = ProgressSave.parse({"version": 1, ProgressSave.ROOMS_KEY: {"a": true, "b": false}})
	_check(mixed.accepted and mixed.restored == {"a": true}, "section : une valeur false n'est jamais une pièce restaurée")


# --- Cas en scène : progression_test.tscn -----------------------------------------------------

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


func _open(continue_game: bool = false) -> Node3D:
	return _open_scene(SCENE, continue_game)


func _open_scene(path: String, continue_game: bool) -> Node3D:
	GameFlow.continue_requested = continue_game
	var scene: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(scene)
	return scene


func _settle() -> void:
	await physics_frame
	await physics_frame


func _close(scene: Node3D) -> void:
	_service.call(&"flush")
	scene.queue_free()
	await process_frame


## Pose directe (sans contrôleur) : reprise, déplacement au point (x, z) du dessus de la surface, pose.
func _put(item: TestItem, surface: PlacementSurface, x: float, z: float) -> void:
	item.on_picked_up()
	item.global_position = Vector3(x, surface.top_y() + item.item_data.height * 0.5, z)
	item.on_placed(surface)


## Pose sans reprise préalable (l'objet est déjà posé quelque part) : pas un dépôt du RoomLayout, donc
## aucun déclencheur de l'Autosave en dehors du verrou.
func _place(item: TestItem, surface: PlacementSurface, x: float, z: float) -> void:
	item.global_position = Vector3(x, surface.top_y() + item.item_data.height * 0.5, z)
	item.on_placed(surface)


func _shelf(scene: Node3D, name: String) -> PlacementSurface:
	return scene.get_node("Shelves/%s/PlacementSurface" % name) as PlacementSurface


func _floor(scene: Node3D) -> PlacementSurface:
	return PlacementSurface.of_body(scene.get_node("Spike/Floor"))


func _drain(autosave: Autosave) -> void:
	var frames: int = 0
	while autosave.is_busy() and frames < 2000:
		autosave.advance()
		frames += 1


func _saved() -> Dictionary:
	var loaded: Dictionary = _service.call("load_slot", Autosave.SLOT_ID)
	return loaded["data"] as Dictionary if loaded["ok"] else {}


## Termine toutes les surfaces et range les trois objets (A, B sur l'étagère A ; C sur l'étagère B).
func _complete_room(scene: Node3D) -> void:
	while scene.call(&"finish_next_surface"):
		pass
	_put(scene.get_node("ItemA"), _shelf(scene, "ShelfA"), 3.2, -1.2)
	_put(scene.get_node("ItemB"), _shelf(scene, "ShelfA"), 3.6, -1.2)
	_put(scene.get_node("ItemC"), _shelf(scene, "ShelfB"), 3.4, 1.2)


func _scene_chain() -> void:
	var scene: Node3D = _open()
	var progress: RoomProgress = scene.get_node("RoomProgress")
	var indicator: ProgressIndicator = scene.get_node("ProgressIndicator")
	var autosave: Autosave = scene.get_node("Autosave")
	var item_a: TestItem = scene.get_node("ItemA")
	var item_b: TestItem = scene.get_node("ItemB")
	var item_c: TestItem = scene.get_node("ItemC")
	var changes: Array[int] = [0]
	var locks: Array[StringName] = []
	progress.changed.connect(func() -> void: changes[0] += 1)
	progress.lock_posed.connect(func(id: StringName) -> void: locks.append(id))

	# Avant la fin du chargement : neutre.
	_check(not progress.is_evaluated() and progress.percent() == 0 and not progress.is_restored() and not progress.is_complete(),
			"chargement : RoomProgress neutre avant room_evaluated")
	_check((indicator.get_node("Panel/Rows/Percent") as Label).text == TranslationServer.translate("progress.pending")
			and not (indicator.get_node("Panel/Rows/Surfaces") as Label).visible and not (indicator.get_node("Panel/Rows/Items") as Label).visible
			and not (indicator.get_node("Panel/Rows/Restored") as Label).visible, "chargement : indicateur neutre")
	await _settle()
	_check(progress.is_evaluated() and changes[0] == 1 and progress.percent() == 0 and progress.cleaning_counts() == Vector2i(0, 3)
			and progress.storing_counts() == Vector2i(0, 3), "chargement : premier calcul (0/3 surfaces, 0/3 objets suivis, seau exclu), un signal")
	_check(autosave.triggers_received == 0 and locks.is_empty(), "chargement : aucune demande de sauvegarde")
	progress.refresh()
	progress.refresh()
	scene.get_node("StorageService").call(&"evaluate", item_a)
	_check(changes[0] == 1, "aucun signal si rien ne change (refresh, réévaluation)")

	# Surfaces : une par une, par la touche locale (F8).
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F8
	key.pressed = true
	scene.call(&"_unhandled_input", key)
	_check(progress.cleaning_counts() == Vector2i(1, 3) and progress.percent() == 16 and changes[0] == 2 and autosave.triggers_received == 1,
			"touche locale : une surface terminée = 1/6 (16 %), un signal, une demande (fin de surface)")
	scene.call(&"finish_next_surface")
	scene.call(&"finish_next_surface")
	_check(progress.cleaning_counts() == Vector2i(3, 3) and progress.percent() == 50 and not progress.is_complete() and changes[0] == 4,
			"toutes les surfaces terminées = 50 % (3/6)")
	_check(not scene.call(&"finish_next_surface"), "touche locale : plus aucune surface à terminer")
	_drain(autosave)

	# Rangement.
	var triggers: int = autosave.triggers_received
	_place(item_a, _shelf(scene, "ShelfA"), 3.2, -1.2)
	_check(progress.storing_counts() == Vector2i(1, 3) and progress.percent() == 66, "un objet rangé = 4/6 (66 %)")
	_place(item_b, _shelf(scene, "ShelfA"), 3.6, -1.2)
	_check(progress.storing_counts() == Vector2i(2, 3) and progress.percent() == 83 and not progress.is_complete() and not progress.is_restored(),
			"deux objets rangés = 5/6 (83 %), pas de 100 affiché, pas de verrou")
	_check((indicator.get_node("Panel/Rows/Percent") as Label).text == TranslationServer.translate("progress.room") + " 83 %" and not (indicator.get_node("Panel/Rows/Restored") as Label).visible,
			"indicateur : 83 %, pas de marque restaurée")
	_check(autosave.triggers_received == triggers and locks.is_empty(), "avant le verrou : aucune demande de sauvegarde")
	_place(item_c, _shelf(scene, "ShelfB"), 3.4, 1.2)
	_check(progress.percent() == 100 and progress.is_complete() and progress.is_restored() and locks == [ROOM_ID],
			"tout fait = 100 %, complet, verrou posé (un signal lock_posed)")
	_check(autosave.triggers_received == triggers + 1, "verrou posé = une demande de sauvegarde")
	_check((indicator.get_node("Panel/Rows/Percent") as Label).text == TranslationServer.translate("progress.room") + " 100 %" and (indicator.get_node("Panel/Rows/Restored") as Label).visible
			and (indicator.get_node("Panel/Rows/Restored") as Label).text == TranslationServer.translate("progress.restored"), "indicateur : 100 % et marque restaurée")
	_drain(autosave)
	_service.call(&"flush")
	var saved: Dictionary = _saved()
	_check(saved.get(ProgressSave.SAVE_KEY) == {"version": 1.0, ProgressSave.ROOMS_KEY: {String(ROOM_ID): true}},
			"sauvegarde : section « progression » écrite avec le verrou (%s)" % str(saved.get(ProgressSave.SAVE_KEY)))
	_check(saved.has(Autosave.CLEANING_KEY) and saved.has(ToolSlots.SAVE_KEY) and saved.has(LayoutState.SAVE_KEY),
			"sauvegarde : les autres sections sont inchangées")

	# Objet déplacé après validation : le pourcentage baisse, le verrou reste, le pourcentage est en direct.
	triggers = autosave.triggers_received
	_place(item_c, _floor(scene), 1.9, 0.4)
	_check(progress.percent() == 83 and not progress.is_complete() and progress.is_restored() and locks.size() == 1,
			"objet déplacé après validation : 83 %, verrou conservé")
	_check((indicator.get_node("Panel/Rows/Percent") as Label).text == TranslationServer.translate("progress.room") + " 83 %" and (indicator.get_node("Panel/Rows/Restored") as Label).visible,
			"indicateur : 83 %, marque restaurée conservée")
	_place(item_c, _shelf(scene, "ShelfB"), 3.4, 1.2)
	_check(progress.percent() == 100 and locks.size() == 1 and autosave.triggers_received == triggers,
			"rangé de nouveau : 100 %, verrou jamais reposé, aucune demande de sauvegarde")
	# Jamais retiré : un import vide ou illisible ne le retire pas.
	_check(progress.import_state({}) and progress.import_state(ProgressSave.make_section({})) and progress.is_restored(), "verrou : jamais retiré par un import vide")
	_check(not progress.import_state("illisible") and progress.is_restored(), "verrou : section illisible ignorée, verrou conservé")
	await _close(scene)


## Un vrai dépôt qui complète la pièce : dépôt + verrou = deux déclencheurs fusionnés en une écriture.
func _scene_lock_merge() -> void:
	var scene: Node3D = _open()
	await _settle()
	var autosave: Autosave = scene.get_node("Autosave")
	var progress: RoomProgress = scene.get_node("RoomProgress")
	while scene.call(&"finish_next_surface"):
		pass
	_place(scene.get_node("ItemA"), _shelf(scene, "ShelfA"), 3.2, -1.2)
	_place(scene.get_node("ItemB"), _shelf(scene, "ShelfA"), 3.6, -1.2)
	_drain(autosave)
	var triggers: int = autosave.triggers_received
	var writes: int = autosave.writes_requested
	_check(progress.percent() == 83 and not progress.is_restored(), "fusion : 5/6 avant le dernier dépôt")
	_put(scene.get_node("ItemC"), _shelf(scene, "ShelfB"), 3.4, 1.2)
	_check(progress.is_restored() and autosave.triggers_received == triggers + 2 and autosave.is_busy(), "fusion : dépôt + verrou = deux déclencheurs")
	_drain(autosave)
	_check(autosave.writes_requested == writes + 1, "fusion : une seule écriture")
	await _close(scene)


func _scene_carried_and_stacked() -> void:
	var scene: Node3D = _open()
	await _settle()
	var progress: RoomProgress = scene.get_node("RoomProgress")
	var carry: CarryController = scene.get_node("Spike/Player/CarryController")
	var item_a: TestItem = scene.get_node("ItemA")
	var item_b: TestItem = scene.get_node("ItemB")
	var item_c: TestItem = scene.get_node("ItemC")
	_put(item_a, _shelf(scene, "ShelfA"), 3.2, -1.2)
	_put(item_b, _shelf(scene, "ShelfA"), 3.6, -1.2)
	_check(progress.storing_counts() == Vector2i(2, 3), "porté : deux objets rangés au départ")
	# Objet porté : reste dans le total, n'est pas rangé.
	carry.pick_up(item_a.get_node("Interactable"))
	_check(carry.held_body() == item_a and progress.storing_counts() == Vector2i(1, 3) and progress.percent() == 16,
			"objet porté : toujours dans le total (1/3), non rangé")
	_put(item_a, _shelf(scene, "ShelfA"), 3.2, -1.2)
	_check(progress.storing_counts() == Vector2i(2, 3), "objet reposé : rangé de nouveau")
	# Empilé sur un objet ordinaire (non-support) : non rangé même dans la zone.
	_put(item_c, PlacementSurface.of_body(item_a), 3.2, -1.2)
	_check(not item_c.rests_on_declared_support() and progress.storing_counts() == Vector2i(2, 3),
			"objet empilé sur un non-support : non rangé")
	_put(item_c, _shelf(scene, "ShelfB"), 3.4, 1.2)
	_check(progress.storing_counts() == Vector2i(3, 3), "sorti de la pile et rangé : 3/3")
	# Le seau n'entre jamais dans le compte, posé ou porté.
	var bucket: TestItem = scene.get_node("Bucket")
	_put(bucket, _shelf(scene, "ShelfB"), 3.4, 1.2)
	_check(progress.storing_counts() == Vector2i(3, 3), "seau posé sur une étagère : hors du compte")
	carry.pick_up(bucket.get_node("Interactable"))
	_check(carry.held_body() == bucket and progress.storing_counts() == Vector2i(3, 3), "seau porté : hors du compte")
	await _close(scene)


func _scene_signals_and_indicator() -> void:
	var scene: Node3D = _open()
	await _settle()
	var progress: RoomProgress = scene.get_node("RoomProgress")
	var indicator: ProgressIndicator = scene.get_node("ProgressIndicator")
	var surfaces: Label = indicator.get_node("Panel/Rows/Surfaces")
	var items: Label = indicator.get_node("Panel/Rows/Items")
	var percent: Label = indicator.get_node("Panel/Rows/Percent")
	_check(surfaces.visible and items.visible and surfaces.text == TranslationServer.translate("progress.surfaces") + " 0/3" and items.text == TranslationServer.translate("progress.stored") + " 0/3",
			"indicateur : « surfaces a/b » et « objets rangés c/d » au départ")
	scene.call(&"finish_next_surface")
	_put(scene.get_node("ItemA"), _shelf(scene, "ShelfA"), 3.2, -1.2)
	_check(surfaces.text == TranslationServer.translate("progress.surfaces") + " 1/3" and items.text == TranslationServer.translate("progress.stored") + " 1/3" and percent.text == TranslationServer.translate("progress.room") + " 33 %",
			"indicateur : reflète les compteurs (1/3, 1/3, 33 %)")
	_check(not (indicator.get_node("Panel/Rows/Restored") as Label).visible, "indicateur : pas de marque restaurée sans verrou")
	# Indicateur détaché : neutre.
	indicator.bind(null)
	_check(percent.text == TranslationServer.translate("progress.pending") and not surfaces.visible, "indicateur : sans progression = neutre")
	indicator.bind(progress)
	_check(percent.text == TranslationServer.translate("progress.room") + " 33 %" and surfaces.visible, "indicateur : relié de nouveau")
	# Axe inactif : ligne masquée.
	var cleaning_only: Array[RoomData.Axis] = [CLEANING]
	progress.room_data.active_axes = cleaning_only
	progress.refresh()
	_check(surfaces.visible and not items.visible and percent.text == TranslationServer.translate("progress.room") + " 33 %", "indicateur : axe rangement inactif = ligne masquée (surfaces 1/3)")
	await _close(scene)


func _scene_save_load() -> void:
	# Pièce complète sauvegardée, puis un objet déplacé après validation : la sortie écrit les deux.
	_clear_saves()
	var scene: Node3D = _open()
	await _settle()
	var autosave: Autosave = scene.get_node("Autosave")
	_complete_room(scene)
	_check((scene.get_node("RoomProgress") as RoomProgress).is_restored(), "retour : pièce restaurée avant la sortie")
	_put(scene.get_node("ItemC"), _floor(scene), 1.9, 0.4)
	_check(autosave.save_and_wait() == 0, "retour : sauvegarde de sortie écrite")
	var saved: Dictionary = _saved()
	var kept_section: Dictionary = saved[ProgressSave.SAVE_KEY]
	scene.queue_free()
	await process_frame

	# Chargement sans import_state : le verrou reste à faux, RoomProgress ne lit jamais l'emplacement
	# (la scène de vérification importe nettoyage, outils et disposition mais pas la progression :
	# l'appel à import_state est fait ici, comme le fait sponge_test.gd).
	var scene_n: Node3D = _open(true)
	await _settle()
	var progress_n: RoomProgress = scene_n.get_node("RoomProgress")
	_check(progress_n.is_evaluated() and not progress_n.is_restored() and progress_n.percent() == 83
			and (scene_n.get_node("Autosave") as Autosave).triggers_received == 0,
			"chargement sans import_state : verrou à faux malgré la section du fichier, pourcentage recalculé, aucune demande")
	scene_n.queue_free()
	await process_frame

	# Chargement avec la section : le verrou est appliqué par import_state.
	var scene_b: Node3D = _open(true)
	var progress_b: RoomProgress = scene_b.get_node("RoomProgress")
	var autosave_b: Autosave = scene_b.get_node("Autosave")
	var locks_b: Array[StringName] = []
	progress_b.lock_posed.connect(func(id: StringName) -> void: locks_b.append(id))
	_check(not progress_b.is_restored(), "chargement : verrou à faux avant import_state")
	_check(progress_b.import_state(saved.get(ProgressSave.SAVE_KEY, {})) and progress_b.is_restored() and not progress_b.is_evaluated()
			and progress_b.percent() == 0, "chargement avec la section : verrou appliqué, indicateur neutre jusqu'à room_evaluated")
	await _settle()
	_check(not GameFlow.continue_requested and progress_b.is_evaluated() and progress_b.percent() == 83 and progress_b.is_restored()
			and progress_b.cleaning_counts() == Vector2i(3, 3) and progress_b.storing_counts() == Vector2i(2, 3),
			"retour : pourcentage (83 %%) et verrou identiques (%d %%, %s)" % [progress_b.percent(), str(progress_b.storing_counts())])
	_check(autosave_b.triggers_received == 0 and not autosave_b.is_busy() and locks_b.is_empty(), "retour : aucune demande de sauvegarde au chargement")
	var indicator_b: ProgressIndicator = scene_b.get_node("ProgressIndicator")
	_check((indicator_b.get_node("Panel/Rows/Percent") as Label).text == TranslationServer.translate("progress.room") + " 83 %" and (indicator_b.get_node("Panel/Rows/Restored") as Label).visible,
			"retour : indicateur à jour (83 %, restaurée)")
	_place(scene_b.get_node("ItemC"), _shelf(scene_b, "ShelfB"), 3.4, 1.2)
	_check(progress_b.percent() == 100 and locks_b.is_empty() and autosave_b.triggers_received == 0, "retour : verrou déjà posé, jamais reposé")
	scene_b.queue_free()
	await process_frame

	# Section absente (ancien format, acceptée sans avertissement), illisible ou de version inconnue
	# (rejetées, avertissement au journal) : verrou à faux, pièce incomplète, aucune demande de sauvegarde.
	var cases: Dictionary = {
		"absente": [{}, true],
		"illisible": ["texte", false],
		"de version inconnue": [{"version": 99, ProgressSave.ROOMS_KEY: {String(ROOM_ID): true}}, false],
		"à entrée illisible": [{"version": 1, ProgressSave.ROOMS_KEY: {String(ROOM_ID): "oui"}}, false],
	}
	for label: String in cases:
		var scene_d: Node3D = _open(true)
		var progress_d: RoomProgress = scene_d.get_node("RoomProgress")
		var accepted: bool = progress_d.import_state((cases[label] as Array)[0])
		await _settle()
		_check(accepted == (cases[label] as Array)[1] and progress_d.is_evaluated() and not progress_d.is_restored() and progress_d.percent() == 83
				and (scene_d.get_node("Autosave") as Autosave).triggers_received == 0,
				"section %s : verrou à faux, pourcentage recalculé, aucune demande" % label)
		scene_d.queue_free()
		await process_frame

	# Section absente mais pièce complète au chargement : verrou posé sans demande de sauvegarde.
	_clear_saves()
	var scene_e: Node3D = _open()
	await _settle()
	_complete_room(scene_e)
	(scene_e.get_node("Autosave") as Autosave).save_and_wait()
	var complete_section: Dictionary = (scene_e.get_node("RoomProgress") as RoomProgress).export_state()
	scene_e.queue_free()
	await process_frame
	var scene_f: Node3D = _open(true)
	var progress_f: RoomProgress = scene_f.get_node("RoomProgress")
	var autosave_f: Autosave = scene_f.get_node("Autosave")
	var locks_f: Array[StringName] = []
	progress_f.lock_posed.connect(func(id: StringName) -> void: locks_f.append(id))
	progress_f.import_state({})
	await _settle()
	_check(progress_f.percent() == 100 and progress_f.is_restored() and locks_f.is_empty() and autosave_f.triggers_received == 0 and not autosave_f.is_busy(),
			"pièce complète sans section : verrou posé au chargement, sans signal ni demande de sauvegarde")
	_check(progress_f.export_state()[ProgressSave.ROOMS_KEY] == {String(ROOM_ID): true} and complete_section[ProgressSave.ROOMS_KEY] == {String(ROOM_ID): true},
			"pièce complète sans section : le verrou sera écrit à la prochaine sauvegarde")
	# Nouvelle partie : rien n'est chargé.
	scene_f.queue_free()
	await process_frame
	var scene_g: Node3D = _open(false)
	await _settle()
	var progress_g: RoomProgress = scene_g.get_node("RoomProgress")
	_check(progress_g.percent() == 0 and not progress_g.is_restored(), "nouvelle partie : aucun verrou")
	await _close(scene_g)
	_clear_saves()


## Scène de jeu provisoire (sponge_test.tscn) : sponge_test.gd importe la section « progression » du
## fichier par RoomProgress.import_state, comme les autres sections.
func _sponge_load() -> void:
	var cases: Dictionary = {
		"section présente": [ProgressSave.make_section({"sponge_test": true}), true],
		"section absente": [null, false],
		"section illisible": ["texte", false],
		"version inconnue": [{"version": 99, ProgressSave.ROOMS_KEY: {"sponge_test": true}}, false],
	}
	for label: String in cases:
		var data: Dictionary = {Autosave.CLEANING_KEY: {}}
		var section: Variant = (cases[label] as Array)[0]
		if section != null:
			data[ProgressSave.SAVE_KEY] = section
		_check(_service.call("save_slot", Autosave.SLOT_ID, data) == 0, "scène de jeu, %s : fichier écrit" % label)
		var scene: Node3D = _open_scene(SPONGE_SCENE, true)
		await _settle()
		var progress: RoomProgress = scene.get_node("RoomProgress")
		_check(progress.is_evaluated() and progress.is_restored() == (cases[label] as Array)[1]
				and (scene.get_node("Autosave") as Autosave).triggers_received == 0 and not GameFlow.continue_requested,
				"scène de jeu, %s : verrou %s, aucune demande de sauvegarde" % [label, "posé" if (cases[label] as Array)[1] else "à faux"])
		scene.queue_free()
		await process_frame
	# Nouvelle partie : la section du fichier n'est pas lue.
	_service.call("save_slot", Autosave.SLOT_ID, {Autosave.CLEANING_KEY: {}, ProgressSave.SAVE_KEY: ProgressSave.make_section({"sponge_test": true})})
	var fresh: Node3D = _open_scene(SPONGE_SCENE, false)
	await _settle()
	_check(not (fresh.get_node("RoomProgress") as RoomProgress).is_restored(), "scène de jeu, nouvelle partie : aucun verrou")
	await _close(fresh)
	_clear_saves()


# --- rangement_test.tscn : chute, meubles ------------------------------------------------------

func _tracked(item: TestItem) -> void:
	var data: ItemData = item.item_data.duplicate() as ItemData
	data.tracks_storing = true
	item.item_data = data


func _aim_at(player: Player, pos: Vector3, target: Vector3) -> void:
	player.global_position = pos
	var dir: Vector3 = target - player.get_node("Head/Camera3D").global_position
	player.rotation.y = atan2(-dir.x, -dir.z)
	player.head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())


func _greybox() -> void:
	GameFlow.continue_requested = false
	var scene: Node3D = (load(RANGEMENT_SCENE) as PackedScene).instantiate() as Node3D
	var room: Node3D = scene.get_node("Greybox")
	var items: Node = room.get_node("TestItems")
	var preplaced: TestItem = scene.get_node("ExtraItems/small_palette")
	var small: TestItem = items.get_node("small_1")
	var small_b: TestItem = items.get_node("small_2")
	var low: TestItem = items.get_node("furniture_low")
	for item: TestItem in [preplaced, small, small_b, low]:
		_tracked(item)
	var room_data: RoomData = RoomData.new()
	room_data.id = &"greybox_test"
	var axes: Array[RoomData.Axis] = [CLEANING, STORING]
	room_data.active_axes = axes
	var progress: RoomProgress = RoomProgress.new()
	progress.name = "RoomProgress"
	progress.room_data = room_data
	progress.storage_path = ^"../StorageService"
	scene.add_child(progress)
	var events: Array[int] = [0]
	progress.changed.connect(func() -> void: events[0] += 1)
	root.add_child(scene)
	var service: StorageService = scene.get_node("StorageService")
	var player: Player = room.get_node("Player")
	var carry: CarryController = player.get_node("CarryController")
	var placement: PlacementController = player.get_node("PlacementController")
	var floor_surface: PlacementSurface = PlacementSurface.of_body(room.get_node("Floor"))
	var table: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestTable"))
	var pallet: PlacementSurface = PlacementSurface.of_body(room.get_node("Supports/TestPallet"))

	await service.room_evaluated
	_check(progress.is_evaluated() and progress.cleaning_counts() == Vector2i.ZERO and progress.storing_counts() == Vector2i(1, 4)
			and progress.percent() == 25, "rangement_test : 4 objets suivis (dont un meuble libre), 1 rangé à la palette = 25 %")
	_check(not progress.is_complete(), "rangement_test : aucune surface et un objet non rangé = pas complet")
	await physics_frame

	# Objet rangé à la table, repris, posé au bord (chute), reposé dans les règles.
	_put(small, table, 3.2, -0.5)
	_check(service.is_stored(small) and progress.storing_counts() == Vector2i(2, 4) and progress.percent() == 50, "chute : objet rangé sur la table = 50 %")
	carry.pick_up(small.get_node("Interactable"))
	_check(carry.held_body() == small and progress.storing_counts() == Vector2i(1, 4) and progress.percent() == 25, "chute : objet repris = 25 % (total inchangé)")
	_aim_at(player, Vector3(4.1, 0.05, 0.7), Vector3(4.095, table.top_y(), -0.5))
	await physics_frame
	placement._update_target()
	_check(placement._verdict == PlacementController.Verdict.UNSTABLE, "chute : bord de la table = pose instable")
	placement.place_held()
	_check(carry.held_body() == null and small.support_surface == floor_surface and not service.is_stored(small)
			and progress.storing_counts() == Vector2i(1, 4) and progress.percent() == 25, "objet tombé au sol : pourcentage baissé (25 %), jamais détruit")
	await physics_frame
	carry.pick_up(small.get_node("Interactable"))
	_aim_at(player, Vector3(3.2, 0.05, 0.7), Vector3(3.2, table.top_y(), -0.2))
	await physics_frame
	placement._update_target()
	placement.place_held()
	_check(small.support_surface == table and service.is_stored(small) and progress.storing_counts() == Vector2i(2, 4) and progress.percent() == 50,
			"objet tombé reposé dans les règles : pourcentage rétabli (50 %)")

	# Meuble libre suivi : sans charge, déplacé dans une zone puis hors zone.
	_check(not service.is_stored(low), "meuble libre au sol : non rangé")
	_put(low, pallet, -3.5, -0.5)
	_check(service.is_stored(low) and progress.storing_counts() == Vector2i(3, 4), "meuble déplacé sur la palette (zone) : rangé")
	# Avec charge : pris refusé, rien ne change ; l'objet posé dessus (suivi) est rangé aussi.
	_put(small_b, PlacementSurface.of_body(low), -3.5, -0.5)
	_check(small_b.rests_on_declared_support() and service.is_stored(small_b) and progress.storing_counts() == Vector2i(4, 4) and progress.is_complete()
			and progress.percent() == 100, "meuble chargé dans une zone : meuble et charge rangés = 100 %")
	var before: int = events[0]
	carry.pick_up(low.get_node("Interactable"))
	_check(carry.held_body() == null and progress.storing_counts() == Vector2i(4, 4) and events[0] == before,
			"meuble avec charge : prise refusée, aucun changement, aucun signal")
	# Sans charge : on retire la charge, on déplace le meuble hors de toute zone.
	_put(small_b, floor_surface, 0.0, 2.0)
	_check(progress.storing_counts() == Vector2i(3, 4), "charge retirée : 3/4")
	_put(low, floor_surface, 0.0, 0.0)
	_check(not service.is_stored(low) and progress.storing_counts() == Vector2i(2, 4) and progress.percent() == 50,
			"meuble sans charge déplacé hors zone : non rangé (50 %)")
	scene.queue_free()
	await process_frame


# --- Pièce synthétique : surfaces terminées d'office, comptage de surfaces --------------------

func _face(room: Node3D, face_name: String, columns: int) -> CleanableFace:
	var mapping: PlanarMapping = PlanarMapping.new()
	mapping.taille = Vector2(1.0, 1.0)
	mapping.tuile_m = 1.0
	var face: CleanableFace = CleanableFace.new()
	face.name = face_name
	face.mapping = mapping
	face.channels = 1
	if columns != 0:
		var image: Image = Image.create(64, 64, false, Image.FORMAT_R8)
		image.fill(Color.BLACK)
		for x: int in maxi(columns, 0):
			for y: int in 64:
				image.set_pixel(32 + x, y, Color.WHITE)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = load(SHADER) as Shader
		material.set_shader_parameter(&"masque_salete", ImageTexture.create_from_image(image))
		face.material = material
	room.add_child(face)
	return face


func _surface(holder: Node, surface_name: String, face: CleanableFace) -> CleaningSurface:
	var surface: CleaningSurface = CleaningSurface.new()
	surface.name = surface_name
	var faces: Array[CleanableFace] = [face]
	surface.faces = faces
	holder.add_child(surface)
	return surface


func _sweep(face: CleanableFace) -> void:
	var xform: Transform3D = face.global_transform
	for j: int in 11:
		for i: int in 4:
			var v: float = float(j) / 10.0
			face.clean_stroke(xform * face.mapping.point_at(Vector2(float(i) / 4.0, v)),
					xform * face.mapping.point_at(Vector2(float(i + 1) / 4.0, v)), 0.15, 100.0)


func _synthetic_room() -> void:
	var room: Node3D = Node3D.new()
	room.name = "Piece"
	root.add_child(room)
	var holder: Node = Node.new()
	holder.name = "Surfaces"
	room.add_child(holder)
	var dirty: CleanableFace = _face(room, "Sale", 0)
	var clean: CleanableFace = _face(room, "Propre", -1)
	var below: CleanableFace = _face(room, "SousSeuil", 3)
	_surface(holder, "SSale", dirty)
	var surf_clean: CleaningSurface = _surface(holder, "SPropre", clean)
	var surf_below: CleaningSurface = _surface(holder, "SSousSeuil", below)
	var room_data: RoomData = RoomData.new()
	room_data.id = &"synthetique"
	var axes: Array[RoomData.Axis] = [CLEANING, REPAIR]
	room_data.active_axes = axes
	var progress: RoomProgress = RoomProgress.new()
	progress.room_data = room_data
	room.add_child(progress)
	var changes: Array[int] = [0]
	var locks: Array[StringName] = []
	progress.changed.connect(func() -> void: changes[0] += 1)
	progress.lock_posed.connect(func(id: StringName) -> void: locks.append(id))
	_check(surf_clean.is_finished() and surf_below.is_finished(), "synthétique : deux surfaces terminées d'office au départ")
	_check(not progress.is_evaluated() and progress.percent() == 0, "synthétique : neutre avant finish_loading")
	progress.finish_loading()
	progress.finish_loading()
	_check(progress.cleaning_counts() == Vector2i(2, 3) and progress.percent() == 66 and not progress.is_complete() and changes[0] == 1,
			"synthétique : surfaces terminées d'office comptées (2/3 = 66 %), un seul calcul de chargement")
	_check(progress.storing_counts() == Vector2i.ZERO and not progress.result().storing_active, "synthétique : sans StorageService, aucun objet compté")
	_sweep(dirty)
	_check(progress.cleaning_counts() == Vector2i(3, 3) and progress.percent() == 100 and progress.is_restored() and locks == [&"synthetique"],
			"synthétique : dernière surface terminée par un geste = 100 %, verrou posé (réparation active : rien compté)")
	# Nettoyer encore une surface d'office ne change rien.
	_sweep(clean)
	_check(changes[0] == 2 and locks.size() == 1, "synthétique : surface d'office nettoyée ensuite, aucun signal")
	# Une surface ajoutée plus tard : le pourcentage baisse, le verrou reste.
	_surface(holder, "SPlusTard", _face(room, "PlusTard", 0))
	progress.watch_surfaces()
	progress.refresh()
	_check(progress.cleaning_counts() == Vector2i(3, 4) and progress.percent() == 75 and not progress.is_complete() and progress.is_restored()
			and locks.size() == 1, "synthétique : surface ajoutée plus tard = 75 %, verrou conservé")
	# Pièce entièrement terminée d'office : verrou posé au chargement, sans signal.
	var room2: Node3D = Node3D.new()
	root.add_child(room2)
	var holder2: Node = Node.new()
	room2.add_child(holder2)
	_surface(holder2, "S1", _face(room2, "P1", -1))
	_surface(holder2, "S2", _face(room2, "P2", -1))
	var progress2: RoomProgress = RoomProgress.new()
	progress2.room_data = room_data
	room2.add_child(progress2)
	var locks2: Array[StringName] = []
	progress2.lock_posed.connect(func(id: StringName) -> void: locks2.append(id))
	progress2.finish_loading()
	_check(progress2.percent() == 100 and progress2.is_restored() and locks2.is_empty(), "synthétique : pièce terminée d'office = verrou posé au chargement, sans signal")
	# Total à zéro (aucune surface) : jamais complet.
	var room3: Node3D = Node3D.new()
	root.add_child(room3)
	var progress3: RoomProgress = RoomProgress.new()
	progress3.room_data = room_data
	room3.add_child(progress3)
	progress3.finish_loading()
	_check(progress3.percent() == 0 and not progress3.is_complete() and not progress3.is_restored(), "synthétique : total à zéro = 0 %, jamais complet, pas de verrou")
	for node: Node in [room, room2, room3]:
		node.queue_free()
	await process_frame


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_failures += 1
