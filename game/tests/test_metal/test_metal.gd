extends Node3D
# Test métal (metal.gdshader) : plaque de gauche = référence propre, plaque de droite = curseur « rouille ».
# Boutons : lumière froide/chaude, vues (ensemble, gros plan, très gros plan, rasante), rugosité brute (A/B du reflet).

# [nom, position de la caméra, point regardé]
const VUES := [
	["ensemble", Vector3(-0.5, 1.9, -0.4), Vector3(-0.5, 0, -0.4)],
	["gros plan", Vector3(1.05, 0.7, 0.1), Vector3(1.05, 0, 0.1)],
	["très gros plan", Vector3(1.3, 0.3, 0.45), Vector3(1.3, 0, 0.45)],
	["rasante (reflets)", Vector3(0, 0.55, 1.9), Vector3(0, 0, 0.2)],
]

@onready var plaque: MeshInstance3D = $Plaque
@onready var camera: Camera3D = $Camera3D
@onready var lumiere: DirectionalLight3D = $Lumiere
@onready var env: Environment = $WorldEnvironment.environment
@onready var curseur: HSlider = $Interface/Panneau/CurseurRouille
@onready var etiquette: Label = $Interface/Panneau/EtiquetteRouille
@onready var bouton_lumiere: Button = $Interface/Panneau/BoutonLumiere
@onready var bouton_vue: Button = $Interface/Panneau/BoutonVue
@onready var bouton_rug: Button = $Interface/Panneau/BoutonRugosite

var chaud := false
var vue := 0
var brute := false


func _ready() -> void:
	curseur.value_changed.connect(_sur_rouille)
	bouton_lumiere.pressed.connect(_basculer_lumiere)
	bouton_vue.pressed.connect(_basculer_vue)
	bouton_rug.pressed.connect(_basculer_rugosite)
	_appliquer_lumiere()
	_appliquer_vue()
	_appliquer_rugosite()
	_sur_rouille(curseur.value)


func _sur_rouille(valeur: float) -> void:
	plaque.set_instance_shader_parameter("rouille", valeur)
	etiquette.text = "rouille = %.2f (0 propre, 1 rouillé)" % valeur


func _basculer_lumiere() -> void:
	chaud = not chaud
	_appliquer_lumiere()


func _appliquer_lumiere() -> void:
	if chaud:
		lumiere.light_color = Color(1.0, 0.82, 0.62)
		lumiere.light_energy = 1.3
		env.ambient_light_color = Color(0.62, 0.54, 0.42)
		env.ambient_light_energy = 0.45
		env.background_color = Color(0.13, 0.10, 0.07)
		bouton_lumiere.text = "Lumière : chaude"
	else:
		lumiere.light_color = Color(0.70, 0.80, 1.0)
		lumiere.light_energy = 1.0
		env.ambient_light_color = Color(0.40, 0.48, 0.62)
		env.ambient_light_energy = 0.5
		env.background_color = Color(0.06, 0.08, 0.12)
		bouton_lumiere.text = "Lumière : froide"


func _basculer_vue() -> void:
	vue = (vue + 1) % VUES.size()
	_appliquer_vue()


func _appliquer_vue() -> void:
	# « Haut » de l'image = -Z, pour que la vue à la verticale reste valide.
	camera.look_at_from_position(VUES[vue][1], VUES[vue][2], Vector3(0, 0, -1))
	bouton_vue.text = "Vue : " + VUES[vue][0]


func _basculer_rugosite() -> void:
	brute = not brute
	_appliquer_rugosite()


func _appliquer_rugosite() -> void:
	# Le matériau est partagé : les deux plaques changent ensemble.
	var mat := plaque.get_surface_override_material(0) as ShaderMaterial
	mat.set_shader_parameter("rugosite_brute", brute)
	bouton_rug.text = "Rugosité : brute (trop brillante)" if brute else "Rugosité : corrigée"
