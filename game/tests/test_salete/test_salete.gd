extends Node3D
# Scène de test du shader sale/propre : le curseur règle "proprete" du plan.

@onready var plan: MeshInstance3D = $Plan
@onready var curseur: HSlider = $Interface/Panneau/Curseur
@onready var etiquette: Label = $Interface/Panneau/Etiquette


func _ready() -> void:
	curseur.value_changed.connect(_sur_changement)
	_sur_changement(curseur.value)


func _sur_changement(valeur: float) -> void:
	plan.set_instance_shader_parameter("proprete", valeur)
	etiquette.text = "proprete = %.2f" % valeur
