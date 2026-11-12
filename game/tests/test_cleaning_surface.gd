extends SceneTree
## Test de l'entité « surface à nettoyer » (CleaningSurface) : seuil, passage descendant, une seule
## émission, surface propre ou déjà sous le seuil (terminée d'office), chargement sans signal,
## marche à deux faces, regroupement et comptage sur le tour. Affiche les aires observées sur le tour.
## Lancer : tools/godot.sh --headless --path game --script res://tests/test_cleaning_surface.gd

const TOUR_SCENE: String = "res://tests/test_cleaning/cleaning_tour.tscn"
const SHADER: String = "res://systems/cleaning/pierre_nettoyable.gdshader"
const RADIUS: float = 0.15
const DOSE: float = 100.0 ## dose par geste : tout ce qui est sous le pinceau devient propre
const ROW_STEP: float = 0.1 ## m entre deux gestes parallèles
const SEGMENTS: int = 4 ## gestes par rangée (suit les faces courbes)

var _failures: int = 0
var _events: Array[CleaningSurface] = []


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_test_threshold()
	_test_crossing()
	_test_clean_at_start()
	_test_below_threshold_at_start()
	_test_load()
	_test_tour()
	print("test_cleaning_surface : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


# --- Seuil ---

func _test_threshold() -> void:
	var room: Node3D = _room("Seuil")
	var defaults: CleaningParams = CleaningParams.new()
	_check(is_equal_approx(defaults.seuil_surface_max_m2, 0.5) and is_equal_approx(defaults.seuil_surface_fraction, 0.10),
			"seuil : constantes de départ 0,5 m² et 0,10")
	var small: CleaningSurface = _surface(room, "Petite", [_face(room, "A", Vector2(1.0, 1.0))])
	_check(is_equal_approx(small.geometric_area(), 1.0) and is_equal_approx(small.threshold(), 0.1),
			"seuil : 1 m² -> 0,10 m² (trouvé %.4f)" % small.threshold())
	var large: CleaningSurface = _surface(room, "Grande", [_face(room, "B", Vector2(3.0, 2.0))])
	_check(is_equal_approx(large.geometric_area(), 6.0) and is_equal_approx(large.threshold(), 0.5),
			"seuil : 6 m² -> plafond 0,5 m² (trouvé %.4f)" % large.threshold())
	var pair: CleaningSurface = _surface(room, "Paire", [_face(room, "C", Vector2(1.0, 1.0)), _face(room, "D", Vector2(0.5, 1.0))])
	_check(is_equal_approx(pair.geometric_area(), 1.5) and is_equal_approx(pair.threshold(), 0.15),
			"seuil : aire géométrique = somme des faces (1,5 m² -> 0,15 m²)")
	_check(is_equal_approx(pair.remaining_dirty_area(), pair.faces[0].remaining_dirty_area() + pair.faces[1].remaining_dirty_area())
			and pair.remaining_dirty_area() > 1.4, "seuil : aire sale restante = somme des faces")
	var tuned: CleaningParams = CleaningParams.new()
	tuned.seuil_surface_max_m2 = 0.15
	tuned.seuil_surface_fraction = 0.2
	var custom: CleaningSurface = _surface(room, "Reglee", [_face(room, "E", Vector2(1.0, 1.0))], tuned)
	_check(is_equal_approx(custom.threshold(), 0.15), "seuil : constantes lues dans CleaningParams (min(0,15 ; 0,2 × 1))")
	_check(not small.is_finished() and not large.is_finished() and not pair.is_finished(), "seuil : surfaces sales non terminées au départ")
	_check(small.surface_id(room) == "Surfaces/Petite", "identifiant : chemin depuis la racine de la pièce (%s)" % small.surface_id(room))
	room.free()


# --- Passage descendant, une seule émission ---

func _test_crossing() -> void:
	var room: Node3D = _room("Passage")
	var face: CleanableFace = _face(room, "A", Vector2(1.0, 1.0))
	var surface: CleaningSurface = _surface(room, "S", [face])
	var threshold: float = surface.threshold()
	_events.clear()
	var crossings: int = 0
	var consistent: bool = true
	var rows: int = ceili(1.0 / ROW_STEP)
	for j: int in rows + 1:
		for i: int in SEGMENTS:
			var before: float = surface.remaining_dirty_area()
			var emitted: int = _events.size()
			_stroke(face, float(i) / SEGMENTS, float(i + 1) / SEGMENTS, float(j) / float(rows))
			var crossed: bool = before > threshold and surface.remaining_dirty_area() <= threshold
			if crossed:
				crossings += 1
			if (_events.size() - emitted) != (1 if crossed else 0):
				consistent = false
			if _events.is_empty() and surface.is_finished():
				consistent = false
	_check(consistent, "passage : signal émis exactement au geste qui fait passer l'aire restante sous le seuil")
	_check(crossings == 1 and _events.size() == 1 and _events[0] == surface, "passage : une seule émission, avec la surface (trouvé %d)" % _events.size())
	_check(surface.is_finished() and surface.remaining_dirty_area() <= threshold, "passage : surface terminée sous le seuil")
	_sweep(face)
	_check(_events.size() == 1, "passage : aucun signal après la fin")
	room.free()


# --- Terminée d'office ---

func _test_clean_at_start() -> void:
	var room: Node3D = _room("Propre")
	var face: CleanableFace = _face(room, "A", Vector2(1.0, 1.0), _thickness(0))
	_events.clear()
	var surface: CleaningSurface = _surface(room, "S", [face])
	_check(surface.remaining_dirty_area() == 0.0, "propre : aucune aire sale au départ")
	_check(surface.is_finished(), "propre : terminée d'office")
	_sweep(face)
	_check(_events.is_empty() and surface.is_finished(), "propre : aucun signal")
	_check(CleaningSurface.count_in_room(room) == 1 and CleaningSurface.finished_count_in_room(room) == 1, "propre : compte comme terminée")
	room.free()


func _test_below_threshold_at_start() -> void:
	var room: Node3D = _room("SousSeuil")
	var face: CleanableFace = _face(room, "A", Vector2(1.0, 1.0), _thickness(3))
	_events.clear()
	var surface: CleaningSurface = _surface(room, "S", [face])
	var initial: float = surface.remaining_dirty_area()
	_check(initial > 0.0 and initial < surface.threshold(), "sous le seuil : 0 < aire sale initiale < seuil (%.4f / %.4f)" % [initial, surface.threshold()])
	_check(surface.is_finished(), "sous le seuil : terminée d'office")
	_sweep(face)
	_check(surface.remaining_dirty_area() < initial, "sous le seuil : le nettoyage reste possible")
	_check(_events.is_empty() and surface.is_finished(), "sous le seuil : aucun signal, même en la nettoyant")
	_check(CleaningSurface.finished_count_in_room(room) == 1, "sous le seuil : compte comme terminée")
	room.free()


# --- Chargement ---

func _test_load() -> void:
	var room: Node3D = _room("Chargement")
	var face: CleanableFace = _face(room, "A", Vector2(1.0, 1.0))
	var surface: CleaningSurface = _surface(room, "S", [face])
	_events.clear()
	_sweep(face, 0.0, 0.4)
	var partial: Dictionary = CleanableFace.export_room(room)
	_check(not surface.is_finished() and _events.is_empty(), "chargement : état partiel au-dessus du seuil, non terminée")
	_sweep(face)
	var done: Dictionary = CleanableFace.export_room(room)
	_check(surface.is_finished() and _events.size() == 1, "chargement : surface terminée par le geste (1 signal)")
	_check(CleanableFace.import_room(room, {}) == 0 and not surface.is_finished(), "chargement : pièce sale rechargée -> non terminée")
	_check(CleanableFace.import_room(room, done) == 0 and surface.is_finished(), "chargement : état terminé recalculé depuis les faces")
	_check(_events.size() == 1, "chargement : aucun signal émis par import_room")
	_check(CleanableFace.import_room(room, partial) == 0 and not surface.is_finished() and _events.size() == 1,
			"chargement : état partiel rechargé -> non terminée, sans signal")
	_sweep(face)
	_check(surface.is_finished() and _events.size() == 2, "chargement : le passage sous le seuil après un chargement émet le signal")
	room.free()


# --- Tour ---

func _test_tour() -> void:
	var tour: Node3D = (load(TOUR_SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(tour)
	var faces: Array[CleanableFace] = []
	faces.assign(tour.get("faces"))
	var surfaces: Array[CleaningSurface] = CleaningSurface.room_surfaces(tour)
	_check(faces.size() == 188, "tour : 188 faces (trouvé %d)" % faces.size())
	_check(surfaces.size() == 104 and CleaningSurface.count_in_room(tour) == 104, "tour : 104 surfaces (trouvé %d)" % surfaces.size())
	for surface: CleaningSurface in surfaces:
		surface.surface_finished.connect(func(finished: CleaningSurface) -> void: _events.append(finished))

	# Regroupement par règle : marche = 2 faces du même module, mur = 1 face, panneau = 6 faces d'un anneau.
	var kinds: Dictionary = {"Marche": 0, "Mur": 0, "Noyau": 0}
	var owners: Dictionary = {}
	var ids: Dictionary = {}
	var grouping: bool = true
	for surface: CleaningSurface in surfaces:
		var kind: String = _kind(surface)
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		ids[surface.surface_id(tour)] = true
		var expected: int = 2 if kind == "Marche" else (6 if kind == "Noyau" else 1)
		if surface.faces.size() != expected:
			grouping = false
		for face: CleanableFace in surface.faces:
			owners[face] = int(owners.get(face, 0)) + 1
			var module: String = String(face.get_parent().name)
			if kind != "Noyau" and module != String(surface.name):
				grouping = false
	_check(kinds["Marche"] == 24 and kinds["Mur"] == 68 and kinds["Noyau"] == 12,
			"tour : 24 marches, 68 faces de mur, 12 panneaux de noyau (trouvé %s)" % [kinds])
	_check(grouping, "tour : nombre de faces par surface (marche 2, mur 1, panneau 6), faces du même module")
	var once: bool = owners.size() == faces.size()
	for face: CleanableFace in faces:
		if int(owners.get(face, 0)) != 1:
			once = false
	_check(once, "tour : chaque face appartient à une surface et une seule")
	_check(ids.size() == surfaces.size() and ids.has("Surfaces/Marche0") and ids.has("Surfaces/Mur1_5") and ids.has("Surfaces/Noyau2_P3"),
			"tour : identifiants uniques, chemin depuis la racine de la pièce")
	var panel: CleaningSurface = tour.get_node("Surfaces/Noyau1_P2") as CleaningSurface
	var modules: PackedStringArray = PackedStringArray()
	for face: CleanableFace in panel.faces:
		modules.append(String(face.get_parent().name))
	_check(", ".join(modules) == "Noyau1_12, Noyau1_13, Noyau1_14, Noyau1_15, Noyau1_16, Noyau1_17",
			"tour : panneau Noyau1_P2 = secteurs 12 à 17 de l'anneau 1 (trouvé %s)" % ", ".join(modules))

	# État de départ (estimation grossière des faces), puis grille fine pour les chiffres.
	var started_finished: PackedStringArray = PackedStringArray()
	for surface: CleaningSurface in surfaces:
		if surface.is_finished():
			started_finished.append(String(surface.name))
	var initial_finished: int = CleaningSurface.finished_count_in_room(tour)
	_check(initial_finished == started_finished.size(), "tour : comptage des surfaces terminées au départ")
	for face: CleanableFace in faces:
		face.ensure_fine_grid()
	_print_tour_figures(surfaces)
	print("Tour : surfaces terminées d'office au départ (estimation grossière) : %d %s" % [started_finished.size(), ", ".join(started_finished)])

	# Marche : dessus + contremarche, état de fin partagé.
	_events.clear()
	var step: CleaningSurface = tour.get_node("Surfaces/Marche3") as CleaningSurface
	var tread: CleanableFace = tour.get_node("Assemblage/Marche3/FaceDessus") as CleanableFace
	var riser: CleanableFace = tour.get_node("Assemblage/Marche3/FaceContremarche") as CleanableFace
	_check(step.faces.has(tread) and step.faces.has(riser), "marche : dessus et contremarche dans la même surface")
	_check(is_equal_approx(step.geometric_area(), tread.face_area() + riser.face_area()) and absf(step.geometric_area() - 0.76) < 0.01,
			"marche : aire = somme des deux faces (%.3f m²)" % step.geometric_area())
	_check(is_equal_approx(step.remaining_dirty_area(), tread.remaining_dirty_area() + riser.remaining_dirty_area()),
			"marche : aire sale restante = somme des deux faces")
	_sweep(tread)
	_check(tread.is_finished() and is_equal_approx(step.remaining_dirty_area(), riser.remaining_dirty_area()),
			"marche : dessus propre, reste = contremarche (%.3f m², seuil %.3f)" % [step.remaining_dirty_area(), step.threshold()])
	_check(step.remaining_dirty_area() > step.threshold() and not step.is_finished() and _events.is_empty(),
			"marche : dessus seul nettoyé -> surface non terminée, aucun signal")
	_sweep(riser)
	_check(step.is_finished() and _events.size() == 1 and _events[0] == step, "marche : contremarche nettoyée -> un seul signal pour la marche")
	var other: CleaningSurface = tour.get_node("Surfaces/Marche7") as CleaningSurface
	_sweep(tour.get_node("Assemblage/Marche7/FaceContremarche") as CleanableFace)
	_check(not other.is_finished() and _events.size() == 1, "marche : contremarche seule nettoyée -> surface non terminée")
	_sweep(tour.get_node("Assemblage/Marche7/FaceDessus") as CleanableFace)
	_check(other.is_finished() and _events.size() == 2 and _events[1] == other, "marche : ordre inverse -> un seul signal")

	# Mur (une face) et panneau de noyau (six faces).
	var wall: CleaningSurface = tour.get_node("Surfaces/Mur1_5") as CleaningSurface
	_sweep(wall.faces[0])
	_check(wall.is_finished() and _events.size() == 3 and _events[2] == wall, "mur : face nettoyée -> un seul signal")
	var crossed_at: int = 0
	for i: int in panel.faces.size():
		_sweep(panel.faces[i])
		if crossed_at == 0 and panel.is_finished():
			crossed_at = i + 1
	_check(panel.is_finished() and _events.size() == 4 and _events[3] == panel, "panneau : un seul signal pour les six faces")
	print("Tour : panneau Noyau1_P2 terminé après %d face(s) nettoyée(s) sur 6" % crossed_at)
	_check(CleaningSurface.finished_count_in_room(tour) == initial_finished + 4 and CleaningSurface.count_in_room(tour) == 104,
			"tour : comptage après quatre surfaces terminées (%d)" % CleaningSurface.finished_count_in_room(tour))

	# Chargement sur le tour : recalcul depuis les faces, sans signal.
	var saved: Dictionary = CleanableFace.export_room(tour)
	_check(CleanableFace.import_room(tour, {}) == 0 and CleaningSurface.finished_count_in_room(tour) == initial_finished and not step.is_finished(),
			"tour : pièce sale rechargée -> surfaces non terminées")
	_check(CleanableFace.import_room(tour, saved) == 0 and CleaningSurface.finished_count_in_room(tour) == initial_finished + 4
			and step.is_finished() and other.is_finished() and wall.is_finished() and panel.is_finished(),
			"tour : sauvegarde rechargée -> surfaces terminées recalculées")
	_check(_events.size() == 4, "tour : aucun signal au chargement")
	tour.free()


## Aires observées sur le tour, par type de surface (grille fine).
func _print_tour_figures(surfaces: Array[CleaningSurface]) -> void:
	var rows: Dictionary = {}
	for surface: CleaningSurface in surfaces:
		var dirt: float = 0.0
		var foam: float = 0.0
		for face: CleanableFace in surface.faces:
			dirt += face.remaining_area(0)
			foam += face.remaining_area(1) if face.channels > 1 else 0.0
		var kind: String = _kind(surface)
		if not rows.has(kind):
			rows[kind] = {"n": 0, "aire": 0.0, "seuil": 0.0, "salete": [INF, 0.0], "mousse": [INF, 0.0], "somme": [INF, 0.0], "sous": []}
		var row: Dictionary = rows[kind]
		row["n"] = int(row["n"]) + 1
		row["aire"] = surface.geometric_area()
		row["seuil"] = surface.threshold()
		for pair: Array in [["salete", dirt], ["mousse", foam], ["somme", surface.remaining_dirty_area()]]:
			var range_: Array = row[pair[0]]
			range_[0] = minf(range_[0], pair[1])
			range_[1] = maxf(range_[1], pair[1])
		if surface.remaining_dirty_area() <= surface.threshold():
			(row["sous"] as Array).append(String(surface.name))
	print("Tour : aires par type de surface (m², min..max sur les surfaces du type, grille fine)")
	for kind: String in rows:
		var row: Dictionary = rows[kind]
		var total: Array = row["somme"]
		var area: float = row["aire"]
		print("  %s x%d : aire géométrique %.3f, seuil %.3f | saleté %.3f..%.3f, mousse %.3f..%.3f, somme %.3f..%.3f (%.0f..%.0f %% de l'aire, %.1f..%.1f x le seuil) | sous le seuil au départ : %d %s" % [
				kind, row["n"], area, row["seuil"], row["salete"][0], row["salete"][1], row["mousse"][0], row["mousse"][1],
				total[0], total[1], 100.0 * total[0] / area, 100.0 * total[1] / area, total[0] / row["seuil"], total[1] / row["seuil"],
				(row["sous"] as Array).size(), ", ".join(PackedStringArray(row["sous"] as Array))])


# --- Outils ---

func _kind(surface: CleaningSurface) -> String:
	var surface_name: String = String(surface.name)
	for kind: String in ["Marche", "Mur", "Noyau"]:
		if surface_name.begins_with(kind):
			return kind
	return surface_name


func _room(room_name: String) -> Node3D:
	var room: Node3D = Node3D.new()
	room.name = room_name
	root.add_child(room)
	var holder: Node = Node.new()
	holder.name = "Surfaces"
	room.add_child(holder)
	return room


## Face plane verticale d'une couche. Sans texture d'épaisseur : entièrement sale.
func _face(room: Node3D, face_name: String, size: Vector2, thickness: Texture2D = null) -> CleanableFace:
	var mapping: PlanarMapping = PlanarMapping.new()
	mapping.taille = size
	mapping.tuile_m = size.x # la texture d'épaisseur couvre la face une fois en largeur
	var face: CleanableFace = CleanableFace.new()
	face.name = face_name
	face.mapping = mapping
	face.channels = 1
	if thickness != null:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = load(SHADER) as Shader
		material.set_shader_parameter(&"masque_salete", thickness)
		face.material = material
	room.add_child(face)
	return face


func _surface(room: Node3D, surface_name: String, faces: Array[CleanableFace], params: CleaningParams = null) -> CleaningSurface:
	var surface: CleaningSurface = CleaningSurface.new()
	surface.name = surface_name
	surface.faces = faces
	surface.params = params
	surface.surface_finished.connect(func(finished: CleaningSurface) -> void: _events.append(finished))
	room.get_node("Surfaces").add_child(surface)
	return surface


## Texture d'épaisseur 64 x 64 : dirty_columns colonnes sales (0 = face propre).
func _thickness(dirty_columns: int) -> ImageTexture:
	var image: Image = Image.create(64, 64, false, Image.FORMAT_R8)
	image.fill(Color.BLACK)
	for x: int in dirty_columns:
		for y: int in 64:
			image.set_pixel(32 + x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)


## Un geste le long de u (u0 -> u1) à la hauteur v de la face.
func _stroke(face: CleanableFace, u0: float, u1: float, v: float) -> void:
	var xform: Transform3D = face.global_transform
	face.clean_stroke(xform * face.mapping.point_at(Vector2(u0, v)), xform * face.mapping.point_at(Vector2(u1, v)), RADIUS, DOSE)


## Nettoie à fond la bande v0..v1 de la face (toute la face par défaut).
func _sweep(face: CleanableFace, v0: float = 0.0, v1: float = 1.0) -> void:
	var height: float = face.mapping.point_at(Vector2(0.5, v0)).distance_to(face.mapping.point_at(Vector2(0.5, v1)))
	var rows: int = maxi(1, ceili(height / ROW_STEP))
	for j: int in rows + 1:
		for i: int in SEGMENTS:
			_stroke(face, float(i) / SEGMENTS, float(i + 1) / SEGMENTS, lerpf(v0, v1, float(j) / float(rows)))


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("ÉCHEC : ", label)
