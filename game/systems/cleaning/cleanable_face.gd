class_name CleanableFace
extends Node3D
## Face nettoyable (spike P2-N1) : unité technique d'état, de sauvegarde et de fin de geste.
## Enfant du module, transformation identité. Porte un masque d'état à 1 ou 2 couches
## (R = proprete_salete, G = proprete_mousse ; 0 = sale, 1 = propre) :
## tampons flottants CPU (source de vérité) + copie GPU (R8 / RG8), sans aucune relecture GPU.
## Le poids (aires) est mesuré seulement : aucun branchement au 100 % de la pièce.

signal finished ## fin de geste déclenchée (reste <= tau) ; l'état est déjà écrit propre

const GROUP: StringName = &"cleanable_faces"
const COMPRESSION: int = FileAccess.COMPRESSION_ZSTD ## sans perte
## Épaisseurs par défaut sans texture : identiques aux hints du shader (blanc / noir).
const DEFAULT_THICKNESS: Array[float] = [1.0, 0.0]
const THICKNESS_UNIFORMS: Array[StringName] = [&"masque_salete", &"masque_mousse"]

@export var mapping: SurfaceMapping
@export var params: CleaningParams
## Matériau modèle (shader pierre_nettoyable) ; dupliqué au _ready, propre à la face.
@export var material: ShaderMaterial
@export var mesh_instance: MeshInstance3D
@export var surface_index: int = 0
@export_range(1, 2) var channels: int = 2 ## 1 = R8 (saleté), 2 = RG8 (saleté + mousse)

## Mesures du spike (µs).
var coarse_init_usec: int = 0
var fine_grid_usec: int = 0

var _material: ShaderMaterial
var _projection: SurfaceMapping.WorldProjection
var _xform: Transform3D
var _xform_inv: Transform3D
var _thickness_scale: Vector2 = Vector2.ONE
var _sources: Array = [] # par couche : [PackedByteArray, largeur, hauteur] ou [] (constante)

var _w: int = 0
var _h: int = 0
var _grid_ready: bool = false
var _positions: PackedVector3Array = PackedVector3Array() # centre des texels, repère du module
var _areas: PackedFloat64Array = PackedFloat64Array() # aire des texels (m²)
var _thickness: Array[PackedFloat32Array] = []
var _state: Array[PackedFloat32Array] = [] # tampons flottants CPU
var _bytes: PackedByteArray = PackedByteArray() # copie 8 bits envoyée au GPU et sauvegardée
var _image: Image
var _texture: ImageTexture

var _coarse_area: PackedFloat64Array = PackedFloat64Array() # aire sale initiale grossière, par couche
var _initial_area: PackedFloat64Array = PackedFloat64Array() # grille fine, par couche
var _initial_texels: PackedInt32Array = PackedInt32Array()
var _remaining_area: PackedFloat64Array = PackedFloat64Array() # reste incrémental, par couche
var _remaining_texels: PackedInt32Array = PackedInt32Array()

var _finished: bool = false
var _fade: float = -1.0 # < 0 : aucun fondu en cours ; sinon avancement 0..1

static var _source_cache: Dictionary = {} # Texture2D -> [octets R8 niveau 0, largeur, hauteur]
static var _base64_regex: RegEx


func _ready() -> void:
	add_to_group(GROUP)
	set_process(false)
	if params == null:
		params = CleaningParams.new()
	assert(mapping != null, "CleanableFace : mapping manquant")
	_xform = global_transform
	_xform_inv = _xform.affine_inverse()
	var size: Vector2i = mapping.grid_size(params.texels_par_m)
	_w = size.x
	_h = size.y
	_material = (material.duplicate() as ShaderMaterial) if material != null else ShaderMaterial.new()
	if mesh_instance != null:
		mesh_instance.set_surface_override_material(surface_index, _material)
	# Une seule source : la projection de la correspondance alimente le shader et le CPU.
	_projection = mapping.projection(_xform)
	_projection.apply_to(_material)
	_material.set_shader_parameter(&"epsilon", params.epsilon)
	_material.set_shader_parameter(&"fondu", 0.0)
	var scale_param: Variant = _material.get_shader_parameter(&"echelle_epaisseur")
	_thickness_scale = scale_param if scale_param is Vector2 else Vector2.ONE
	_material.set_shader_parameter(&"echelle_epaisseur", _thickness_scale)
	_sources.clear()
	for c: int in channels:
		_sources.append(_thickness_source(_material.get_shader_parameter(THICKNESS_UNIFORMS[c]) as Texture2D))
	var t0: int = Time.get_ticks_usec()
	_measure_coarse()
	coarse_init_usec = Time.get_ticks_usec() - t0
	_finished = _sum(_coarse_area) <= 0.0


func _process(delta: float) -> void:
	advance_fade(delta)


# --- Nettoyage ---

## Nettoie le long du segment monde from -> to : tampons sphériques de rayon radius_m, espacés de
## radius_m / 2 au maximum (from exclu si le segment n'est pas nul). amount = dose totale du geste,
## répartie sur les tampons (PROVISOIRE). layers = masque de bits des couches visées (PROVISOIRE).
## Renvoie true si au moins un texel a changé.
func clean_stroke(from: Vector3, to: Vector3, radius_m: float, amount: float, layers: int = 0b11) -> bool:
	if _finished or radius_m <= 0.0 or amount <= 0.0:
		return false
	var a: Vector3 = _xform_inv * from
	var b: Vector3 = _xform_inv * to
	var steps: int = maxi(1, ceili(a.distance_to(b) / (radius_m * 0.5)))
	var dose: float = amount / float(steps)
	var changed: bool = false
	for i: int in range(1, steps + 1):
		if _stamp(a.lerp(b, float(i) / float(steps)), radius_m, dose, layers):
			changed = true
	if changed:
		_upload()
		if remaining_ratio() <= params.tau:
			_finish(true)
	return changed


func _stamp(center: Vector3, radius_m: float, dose: float, layers: int) -> bool:
	if absf(mapping.depth_at(center)) >= radius_m:
		return false
	var uv: Vector2 = mapping.uv_at(center)
	var ext: Vector2 = mapping.radius_to_uv(uv, radius_m)
	var x0: int = maxi(0, floori((uv.x - ext.x) * _w))
	var x1: int = mini(_w - 1, floori((uv.x + ext.x) * _w))
	var y0: int = maxi(0, floori((uv.y - ext.y) * _h))
	var y1: int = mini(_h - 1, floori((uv.y + ext.y) * _h))
	if x0 > x1 or y0 > y1:
		return false
	ensure_fine_grid() # premier contact du pinceau
	var eps: float = params.epsilon
	var r2: float = radius_m * radius_m
	var changed: bool = false
	for c: int in channels:
		if layers & (1 << c) == 0:
			continue
		var state: PackedFloat32Array = _state[c]
		var thickness: PackedFloat32Array = _thickness[c]
		var area_lost: float = 0.0
		var texels_lost: int = 0
		for y: int in range(y0, y1 + 1):
			var row: int = y * _w
			for x: int in range(x0, x1 + 1):
				var i: int = row + x
				var before: float = state[i]
				if before >= 1.0:
					continue
				var d2: float = _positions[i].distance_squared_to(center)
				if d2 >= r2:
					continue
				# Profil du pinceau : plein jusqu'à r/2, linéaire jusqu'au bord (PROVISOIRE).
				var weight: float = minf(1.0, 2.0 * (1.0 - sqrt(d2) / radius_m))
				state[i] = minf(1.0, before + dose * weight)
				var after: float = state[i] # valeur réellement stockée (32 bits)
				if after == before:
					continue
				changed = true
				_bytes[i * channels + c] = roundi(after * 255.0)
				var e: float = thickness[i]
				if e - before > eps and e - after <= eps:
					area_lost += _areas[i]
					texels_lost += 1
		_state[c] = state
		_remaining_area[c] -= area_lost
		_remaining_texels[c] -= texels_lost
	return changed


## Avance le fondu de fin de geste (appelé par _process ; public pour les tests headless).
func advance_fade(delta: float) -> void:
	if _fade < 0.0:
		return
	_fade += delta / maxf(params.duree_fondu, 0.001)
	if _fade >= 1.0:
		_fade = -1.0
		_upload()
		_material.set_shader_parameter(&"fondu", 0.0)
		set_process(false)
	else:
		_material.set_shader_parameter(&"fondu", _fade)


func is_finished() -> bool:
	return _finished


func is_fading() -> bool:
	return _fade >= 0.0


# --- Poids (mesure seulement) ---

func face_area() -> float:
	return mapping.area()


func has_fine_grid() -> bool:
	return _grid_ready


## Aire sale initiale par échantillonnage grossier (somme des couches), calculée au _ready.
func initial_dirty_area_coarse() -> float:
	return _sum(_coarse_area)


## Aire sale initiale : grille fine si elle existe, sinon estimation grossière.
func initial_dirty_area() -> float:
	return _sum(_initial_area) if _grid_ready else _sum(_coarse_area)


## Aire encore sale (somme des couches ; texels où épaisseur − propreté > epsilon).
func remaining_dirty_area() -> float:
	if _finished:
		return 0.0
	return _sum(_remaining_area) if _grid_ready else _sum(_coarse_area)


## Reste de la face (0..1), pondéré par l'aire des texels.
func remaining_ratio() -> float:
	var initial: float = initial_dirty_area()
	return remaining_dirty_area() / initial if initial > 0.0 else 0.0


## Propreté de la face (0..1), pondérée par l'aire.
func cleanliness() -> float:
	return 1.0 - remaining_ratio()


func remaining_texels(layer: int) -> int:
	return _remaining_texels[layer] if _grid_ready else -1


func remaining_area(layer: int) -> float:
	return _remaining_area[layer] if _grid_ready else -1.0


## Recalcul complet du reste depuis les tampons (contrôle du compteur incrémental).
func recount() -> Dictionary:
	var areas: PackedFloat64Array = PackedFloat64Array()
	var texels: PackedInt32Array = PackedInt32Array()
	areas.resize(channels)
	texels.resize(channels)
	if _grid_ready:
		var eps: float = params.epsilon
		for c: int in channels:
			var state: PackedFloat32Array = _state[c]
			var thickness: PackedFloat32Array = _thickness[c]
			var total: float = 0.0
			var count: int = 0
			for i: int in _w * _h:
				if thickness[i] - state[i] > eps:
					total += _areas[i]
					count += 1
			areas[c] = total
			texels[c] = count
	return {"aire": areas, "texels": texels}


# --- Accès de contrôle (tests, HUD) ---

func grid_size() -> Vector2i:
	return Vector2i(_w, _h)


func face_material() -> ShaderMaterial:
	return _material


func world_projection() -> SurfaceMapping.WorldProjection:
	return _projection


func state_buffer(layer: int) -> PackedFloat32Array:
	return _state[layer] if _grid_ready else PackedFloat32Array()


func state_bytes() -> PackedByteArray:
	return _bytes


## Distance (m) d'un point monde à la face, INF s'il se projette hors de la face.
func surface_distance(world_point: Vector3) -> float:
	var local: Vector3 = _xform_inv * world_point
	var uv: Vector2 = mapping.uv_at(local)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return INF
	return absf(mapping.depth_at(local))


# --- Sauvegarde ---

## Entrée pour le SaveService ; {} si la face n'a jamais été touchée (clé absente = sale).
## id = chemin du nœud depuis la racine de la pièce. Le poids n'est pas sauvegardé.
func export_state(room_root: Node) -> Dictionary:
	if not _grid_ready:
		return {}
	return {
		"id": String(room_root.get_path_to(self)),
		"largeur": _w,
		"hauteur": _h,
		"canaux": channels,
		"donnees": Marshalls.raw_to_base64(_bytes.compress(COMPRESSION)),
	}


## Restaure l'état. {} = sale. Toute incohérence = face sale + push_warning (renvoie false).
## La taille attendue vient de la scène (grille de la face), jamais du fichier.
func import_state(entry: Dictionary) -> bool:
	_reset_dirty()
	if entry.is_empty():
		return true
	var expected: int = _w * _h * channels
	if not _is_number(entry.get("largeur")) or not _is_number(entry.get("hauteur")) \
			or not _is_number(entry.get("canaux")) or not entry.get("donnees") is String:
		return _reject("entrée incomplète")
	if int(entry["largeur"]) != _w or int(entry["hauteur"]) != _h or int(entry["canaux"]) != channels:
		return _reject("dimensions %sx%sx%s au lieu de %dx%dx%d" % [
				entry["largeur"], entry["hauteur"], entry["canaux"], _w, _h, channels])
	var text: String = entry["donnees"]
	if text.is_empty() or text.length() % 4 != 0 or _base64_pattern().search(text) == null:
		return _reject("données vides ou base64 invalide")
	var packed: PackedByteArray = Marshalls.base64_to_raw(text)
	if packed.is_empty():
		return _reject("données vides")
	# Tampon d'une marge d'un octet : détecte les octets en trop comme les octets manquants.
	var raw: PackedByteArray = packed.decompress(expected + 1, COMPRESSION)
	if raw.size() != expected:
		return _reject("%d octets au lieu de %d" % [raw.size(), expected])
	ensure_fine_grid()
	_bytes = raw
	for c: int in channels:
		var state: PackedFloat32Array = _state[c]
		for i: int in _w * _h:
			state[i] = float(raw[i * channels + c]) / 255.0
		_state[c] = state
	var counted: Dictionary = recount()
	_remaining_area = counted["aire"]
	_remaining_texels = counted["texels"]
	if remaining_ratio() <= params.tau:
		_finish(false) # déjà finie à la sauvegarde : pas de fondu
	else:
		_upload()
	return true


## Entrées de toutes les faces sous room_root, indexées par id (faces intactes omises).
static func export_room(room_root: Node) -> Dictionary:
	var out: Dictionary = {}
	for node: Node in room_root.find_children("*", "CleanableFace", true, false):
		var entry: Dictionary = (node as CleanableFace).export_state(room_root)
		if not entry.is_empty():
			out[entry["id"]] = entry
	return out


## Restaure toutes les faces sous room_root (clé absente = sale). Renvoie le nombre d'entrées rejetées.
static func import_room(room_root: Node, data: Dictionary) -> int:
	var rejected: int = 0
	for node: Node in room_root.find_children("*", "CleanableFace", true, false):
		var entry: Variant = data.get(String(room_root.get_path_to(node)), {})
		if not entry is Dictionary:
			entry = {"invalide": true}
		if not (node as CleanableFace).import_state(entry):
			rejected += 1
	return rejected


# --- Interne ---

## Crée la grille fine (positions, aires, épaisseurs, état sale, copie GPU). Idempotent.
func ensure_fine_grid() -> void:
	if _grid_ready:
		return
	var t0: int = Time.get_ticks_usec()
	var n: int = _w * _h
	_positions.resize(n)
	_areas.resize(n)
	var thick_r: PackedFloat32Array = PackedFloat32Array()
	var thick_g: PackedFloat32Array = PackedFloat32Array()
	thick_r.resize(n)
	thick_g.resize(n if channels > 1 else 0)
	var eps: float = params.epsilon
	_initial_area.resize(channels)
	_initial_area.fill(0.0)
	_initial_texels.resize(channels)
	_initial_texels.fill(0)
	for y: int in _h:
		var v: float = (float(y) + 0.5) / float(_h)
		for x: int in _w:
			var i: int = y * _w + x
			var local: Vector3 = mapping.point_at(Vector2((float(x) + 0.5) / float(_w), v))
			var area: float = mapping.texel_area(x, y, _w, _h)
			_positions[i] = local
			_areas[i] = area
			var uv: Vector2 = _projection.uv_monde(_xform * local) * _thickness_scale
			for c: int in channels:
				var e: float = _read_thickness(c, uv)
				if c == 0:
					thick_r[i] = e
				else:
					thick_g[i] = e
				if e > eps:
					_initial_area[c] += area
					_initial_texels[c] += 1
	_thickness.clear()
	_thickness.append(thick_r)
	if channels > 1:
		_thickness.append(thick_g)
	_state.clear()
	for c: int in channels:
		var buffer: PackedFloat32Array = PackedFloat32Array()
		buffer.resize(n) # zéro = sale
		_state.append(buffer)
	_remaining_area = _initial_area.duplicate()
	_remaining_texels = _initial_texels.duplicate()
	_bytes.resize(n * channels)
	_bytes.fill(0)
	_image = Image.create_from_data(_w, _h, false, _format(), _bytes)
	_texture = ImageTexture.create_from_image(_image)
	_material.set_shader_parameter(&"etat", _texture)
	_grid_ready = true
	_finished = _sum(_initial_area) <= 0.0
	fine_grid_usec = Time.get_ticks_usec() - t0


## Aire sale initiale par couche, à la densité grossière (aucun tampon conservé).
func _measure_coarse() -> void:
	var size: Vector2i = mapping.grid_size(params.texels_par_m_grossier)
	var eps: float = params.epsilon
	_coarse_area.resize(channels)
	_coarse_area.fill(0.0)
	for y: int in size.y:
		var v: float = (float(y) + 0.5) / float(size.y)
		for x: int in size.x:
			var local: Vector3 = mapping.point_at(Vector2((float(x) + 0.5) / float(size.x), v))
			var uv: Vector2 = _projection.uv_monde(_xform * local) * _thickness_scale
			for c: int in channels:
				if _read_thickness(c, uv) > eps:
					_coarse_area[c] += mapping.texel_area(x, y, size.x, size.y)


## Épaisseur de la couche en uv : bilinéaire, répétition, niveau 0 (comme le shader).
func _read_thickness(layer: int, uv: Vector2) -> float:
	var source: Array = _sources[layer]
	if source.is_empty():
		return DEFAULT_THICKNESS[layer]
	var data: PackedByteArray = source[0]
	var w: int = source[1]
	var h: int = source[2]
	var fx: float = uv.x * w - 0.5
	var fy: float = uv.y * h - 0.5
	var x0: int = floori(fx)
	var y0: int = floori(fy)
	fx -= x0
	fy -= y0
	var xa: int = posmod(x0, w)
	var xb: int = posmod(x0 + 1, w)
	var ya: int = posmod(y0, h) * w
	var yb: int = posmod(y0 + 1, h) * w
	var top: float = lerpf(data[ya + xa], data[ya + xb], fx)
	var bottom: float = lerpf(data[yb + xa], data[yb + xb], fx)
	return lerpf(top, bottom, fy) / 255.0


## Octets R8 du niveau 0 d'une texture d'épaisseur ([] si absente : épaisseur par défaut).
static func _thickness_source(texture: Texture2D) -> Array:
	if texture == null:
		return []
	if _source_cache.has(texture):
		return _source_cache[texture]
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_warning("CleanableFace : image d'épaisseur illisible (%s), épaisseur par défaut." % texture.resource_path)
		return []
	if image.is_compressed() and image.decompress() != OK:
		push_warning("CleanableFace : décompression impossible (%s), épaisseur par défaut." % texture.resource_path)
		return []
	if image.has_mipmaps():
		image.clear_mipmaps()
	image.convert(Image.FORMAT_R8)
	var source: Array = [image.get_data(), image.get_width(), image.get_height()]
	_source_cache[texture] = source
	return source


func _format() -> Image.Format:
	return Image.FORMAT_R8 if channels == 1 else Image.FORMAT_RG8


## Envoie la copie 8 bits au GPU (aucune relecture).
func _upload() -> void:
	if not _grid_ready:
		return
	_image.set_data(_w, _h, false, _format(), _bytes)
	_texture.update(_image)


## Fin de geste : l'état est écrit propre tout de suite (persistant) ; à l'écran, les résidus
## se fondent via l'uniform fondu, puis la texture propre est envoyée à la fin du fondu.
func _finish(with_fade: bool) -> void:
	_finished = true
	for c: int in channels:
		var state: PackedFloat32Array = _state[c]
		state.fill(1.0)
		_state[c] = state
		_remaining_area[c] = 0.0
		_remaining_texels[c] = 0
	_bytes.fill(255)
	if with_fade and is_inside_tree() and params.duree_fondu > 0.0:
		_fade = 0.0
		set_process(true)
	else:
		_fade = -1.0
		_material.set_shader_parameter(&"fondu", 0.0)
		_upload()
	finished.emit()


func _reset_dirty() -> void:
	_fade = -1.0
	set_process(false)
	_material.set_shader_parameter(&"fondu", 0.0)
	if not _grid_ready:
		_finished = _sum(_coarse_area) <= 0.0
		return
	for c: int in channels:
		var state: PackedFloat32Array = _state[c]
		state.fill(0.0)
		_state[c] = state
	_bytes.fill(0)
	_remaining_area = _initial_area.duplicate()
	_remaining_texels = _initial_texels.duplicate()
	_finished = _sum(_initial_area) <= 0.0
	_upload()


func _reject(reason: String) -> bool:
	push_warning("CleanableFace %s : état sauvegardé incohérent (%s), face remise sale." % [get_path(), reason])
	return false


static func _base64_pattern() -> RegEx:
	if _base64_regex == null:
		_base64_regex = RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}$")
	return _base64_regex


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _sum(values: PackedFloat64Array) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total
