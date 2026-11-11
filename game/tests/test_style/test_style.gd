extends Node3D
# Test de style : 3 matériaux (bois, pierre, métal), curseur sale/propre,
# bouton lumière froide/chaude, bouton style photo/peint.

const DOSSIER := "res://tests/test_style/tex/"
# Vues : ensemble, puis gros plan de chaque matériau à hauteur d'yeux (~1,8 m).
const VUES := [["ensemble", Vector3(0, 5, 0)], ["bois", Vector3(-4.5, 1.8, 0)], ["pierre", Vector3(0, 1.8, 0)], ["métal", Vector3(4.5, 1.8, 0)]]

@onready var plans: Dictionary = {"bois": $Bois, "pierre": $Pierre, "metal": $Metal}
@onready var camera: Camera3D = $Camera3D
@onready var lumiere: DirectionalLight3D = $Lumiere
@onready var env: Environment = $WorldEnvironment.environment
@onready var curseur: HSlider = $Interface/Panneau/Curseur
@onready var etiquette: Label = $Interface/Panneau/Etiquette
@onready var bouton_lumiere: Button = $Interface/Panneau/BoutonLumiere
@onready var bouton_style: Button = $Interface/Panneau/BoutonStyle
@onready var bouton_vue: Button = $Interface/Panneau/BoutonVue

var chaud := false
var peint := true
var vue := 0


func _ready() -> void:
	curseur.value_changed.connect(_sur_proprete)
	bouton_lumiere.pressed.connect(_basculer_lumiere)
	bouton_style.pressed.connect(_basculer_style)
	bouton_vue.pressed.connect(_basculer_vue)
	_appliquer_lumiere()
	_appliquer_style()
	_sur_proprete(curseur.value)


func _sur_proprete(valeur: float) -> void:
	for nom in plans:
		plans[nom].set_instance_shader_parameter("proprete", valeur)
	etiquette.text = "proprete = %.2f" % valeur


func _basculer_lumiere() -> void:
	chaud = not chaud
	_appliquer_lumiere()


func _appliquer_lumiere() -> void:
	if chaud:
		lumiere.light_color = Color(1.0, 0.68, 0.38)
		lumiere.light_energy = 1.4
		env.ambient_light_color = Color(0.75, 0.5, 0.3)
		env.ambient_light_energy = 0.45
		env.background_color = Color(0.13, 0.09, 0.06)
		bouton_lumiere.text = "Lumière : chaude"
	else:
		lumiere.light_color = Color(0.62, 0.74, 1.0)
		lumiere.light_energy = 1.0
		env.ambient_light_color = Color(0.35, 0.45, 0.65)
		env.ambient_light_energy = 0.5
		env.background_color = Color(0.06, 0.08, 0.13)
		bouton_lumiere.text = "Lumière : froide"


func _basculer_style() -> void:
	peint = not peint
	_appliquer_style()


func _appliquer_style() -> void:
	var suffixe := "peint" if peint else "photo"
	for nom in plans:
		var mat: ShaderMaterial = plans[nom].material_override
		mat.set_shader_parameter("albedo_propre", load(DOSSIER + nom + "_alb_propre_" + suffixe + ".jpg"))
		mat.set_shader_parameter("albedo_sale", load(DOSSIER + nom + "_alb_sale_" + suffixe + ".jpg"))
	bouton_style.text = "Style : " + ("peint" if peint else "photo")


func _basculer_vue() -> void:
	vue = (vue + 1) % VUES.size()
	camera.position = VUES[vue][1]
	bouton_vue.text = "Vue : " + VUES[vue][0]
