extends Node3D
# Test mousse sur pierre : curseurs proprete et mousse, lumière froide/chaude,
# style photo/peint, vues (ensemble puis gros plans à hauteur d'yeux).

const DOSSIER := "res://tests/test_mousse/tex/"
const VUES := [
	["ensemble", Vector3(0, 2.4, 0)],
	["gauche", Vector3(-1.0, 1.0, 0)],
	["centre", Vector3(0, 1.0, 0)],
	["droite", Vector3(1.0, 1.0, 0)],
]

@onready var pierre: MeshInstance3D = $Pierre
@onready var camera: Camera3D = $Camera3D
@onready var lumiere: DirectionalLight3D = $Lumiere
@onready var env: Environment = $WorldEnvironment.environment
@onready var curseur_propre: HSlider = $Interface/Panneau/CurseurPropre
@onready var etiquette_propre: Label = $Interface/Panneau/EtiquettePropre
@onready var curseur_mousse: HSlider = $Interface/Panneau/CurseurMousse
@onready var etiquette_mousse: Label = $Interface/Panneau/EtiquetteMousse
@onready var bouton_lumiere: Button = $Interface/Panneau/BoutonLumiere
@onready var bouton_style: Button = $Interface/Panneau/BoutonStyle
@onready var bouton_vue: Button = $Interface/Panneau/BoutonVue

var chaud := false
var peint := true
var vue := 0


func _ready() -> void:
	curseur_propre.value_changed.connect(_sur_propre)
	curseur_mousse.value_changed.connect(_sur_mousse)
	bouton_lumiere.pressed.connect(_basculer_lumiere)
	bouton_style.pressed.connect(_basculer_style)
	bouton_vue.pressed.connect(_basculer_vue)
	_appliquer_lumiere()
	_appliquer_style()
	_sur_propre(curseur_propre.value)
	_sur_mousse(curseur_mousse.value)


func _sur_propre(valeur: float) -> void:
	pierre.set_instance_shader_parameter("proprete", valeur)
	etiquette_propre.text = "proprete = %.2f" % valeur


func _sur_mousse(valeur: float) -> void:
	pierre.set_instance_shader_parameter("mousse", valeur)
	etiquette_mousse.text = "mousse = %.2f" % valeur


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


func _basculer_style() -> void:
	peint = not peint
	_appliquer_style()


func _appliquer_style() -> void:
	var s := "peint" if peint else "photo"
	var mat: ShaderMaterial = pierre.material_override
	mat.set_shader_parameter("albedo_propre", load(DOSSIER + "pierre_alb_propre_" + s + ".jpg"))
	mat.set_shader_parameter("albedo_sale", load(DOSSIER + "pierre_alb_sale_" + s + ".jpg"))
	mat.set_shader_parameter("albedo_mousse", load(DOSSIER + "mousse_alb_" + s + ".jpg"))
	bouton_style.text = "Style : " + s


func _basculer_vue() -> void:
	vue = (vue + 1) % VUES.size()
	camera.position = VUES[vue][1]
	bouton_vue.text = "Vue : " + VUES[vue][0]
