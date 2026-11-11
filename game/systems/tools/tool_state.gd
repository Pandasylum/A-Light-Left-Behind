class_name ToolState
extends RefCounted
## État d'usage d'un outil tenu (logique pure, testable sans scène) : niveau de salissure
## et efficacité effective. Les valeurs de jeu viennent de ToolData.

signal soil_changed(soil: float)

var data: ToolData
var soil: float = 0.0 ## niveau de salissure, 0 (propre) à 1 (sale) ; lecture seule hors de cette classe


func _init(tool_data: ToolData) -> void:
	data = tool_data


## Part de l'efficacité de base conservée au niveau de salissure donné :
## 1 − salissure × perte maximale, jamais sous le plancher (1 − ToolData.MAX_LOSS_LIMIT = 10 %).
static func efficiency_factor_at(soil_level: float, max_loss: float) -> float:
	var factor: float = 1.0 - clampf(soil_level, 0.0, 1.0) * max_loss
	return clampf(factor, 1.0 - ToolData.MAX_LOSS_LIMIT, 1.0)


func efficiency_factor() -> float:
	return efficiency_factor_at(soil, data.max_efficiency_loss)


## Efficacité effective (dose par seconde) = efficacité de base × facteur de salissure.
func effective_efficiency() -> float:
	return data.base_efficiency * efficiency_factor()


## Salit l'outil en proportion de l'aire nettoyée (m²). Monotone : une aire négative est ignorée.
func add_cleaned_area(area_m2: float) -> void:
	if area_m2 <= 0.0:
		return
	_set_soil(soil + area_m2 * data.soil_per_m2)


## Rinçage : salissure remise à 0.
func rinse() -> void:
	_set_soil(0.0)


## Chargement d'une sauvegarde : rétablit la salissure telle quelle (ni rinçage ni usage).
func restore_soil(value: float) -> void:
	_set_soil(value)


func _set_soil(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	if clamped != soil:
		soil = clamped
		soil_changed.emit(soil)
