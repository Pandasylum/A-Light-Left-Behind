extends Node3D
# Test bois à deux canaux (bois.gdshader) : planche de gauche = référence propre,
# planche de droite = pilotée par les curseurs proprete / poussiere / traces.
# Boutons : lumière froide/chaude, vues (ensemble, gros plan, rasante pour juger les reflets).

# [nom, position de la caméra, point regardé]
const VUES := [
	["ensemble", Vector3(-0.5, 1.9, -0.4), Vector3(-0.5, 0, -0.4)],
	["gros plan", Vector3(1.05, 0.7, 0.1), Vector3(1.05, 0, 0.1)],
	["très gros plan", Vector3(1.3, 0.3, 0.45), Vector3(1.3, 0, 0.45)],
	["rasante (reflets)", Vector3(0, 0.55, 1.9), Vector3(0, 0, 0.2)],
]

@onready var planche: MeshInstance3D = $Planche
@onready var camera: Camera3D = $Camera3D
@onready var lumiere: DirectionalLight3D = $Lumiere
@onready var env: Environment = $WorldEnvironment.environment
@onready var curseur_propre: HSlider = $Interface/Panneau/CurseurPropre
@onready var etiquette_propre: Label = $Interface/Panneau/EtiquettePropre
@onready var curseur_poussiere: HSlider = $Interface/Panneau/CurseurPoussiere
@onready var etiquette_poussiere: Label = $Interface/Panneau/EtiquettePoussiere
@onready var curseur_traces: HSlider = $Interface/Panneau/CurseurTraces
@onready var etiquette_traces: Label = $Interface/Panneau/EtiquetteTraces
@onready var bouton_lumiere: Button = $Interface/Panneau/BoutonLumiere
@onready var bouton_vue: Button = $Interface/Panneau/BoutonVue

var chaud := false
var vue := 0


func _ready() -> void:
	curseur_propre.value_changed.connect(_sur_propre)
	curseur_poussiere.value_changed.connect(_sur_poussiere)
	curseur_traces.value_changed.connect(_sur_traces)
	bouton_lumiere.pressed.connect(_basculer_lumiere)
	bouton_vue.pressed.connect(_basculer_vue)
	_appliquer_lumiere()
	_appliquer_vue()
	_sur_propre(curseur_propre.value)
	_sur_poussiere(curseur_poussiere.value)
	_sur_traces(curseur_traces.value)


func _sur_propre(valeur: float) -> void:
	planche.set_instance_shader_parameter("proprete", valeur)
	etiquette_propre.text = "proprete = %.2f (0 sale, 1 propre)" % valeur


func _sur_poussiere(valeur: float) -> void:
	planche.set_instance_shader_parameter("poussiere", valeur)
	etiquette_poussiere.text = "poussiere = %.2f (voile mat)" % valeur


func _sur_traces(valeur: float) -> void:
	planche.set_instance_shader_parameter("traces", valeur)
	etiquette_traces.text = "traces = %.2f (marques sombres)" % valeur


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
