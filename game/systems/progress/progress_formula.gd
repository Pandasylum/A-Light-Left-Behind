class_name ProgressFormula
extends RefCounted
## Formule de progression d'une pièce (GDD §5 et §6). 🟡 PROVISOIRE : ce fichier est le SEUL endroit
## où vit la formule ; la changer ne touche rien d'autre. Logique pure, sans scène.
## Axes comptés : ceux que RoomData déclare actifs, limités à COUNTED_AXES (la réparation n'est pas
## comptée : elle n'existe pas encore). Unités : chaque surface à nettoyer vaut 1 ; chaque objet libre
## dont ItemData déclare l'axe rangement (tracks_storing) vaut 1 (un objet sans axe suivi, comme le
## seau, est exclu). Pourcentage = (surfaces finies + objets rangés) / (surfaces + objets suivis).
## Total à zéro = 0 %, jamais « complet ». Complet = fait = total et total > 0.

## Axes pris en compte par la formule (les autres sont ignorés même s'ils sont actifs).
const COUNTED_AXES: Array[RoomData.Axis] = [RoomData.Axis.CLEANING, RoomData.Axis.STORING]


## Résultat d'un calcul : compteurs par axe, totaux, complétude, pourcentage affiché.
class Result extends RefCounted:
	var cleaning_active: bool = false
	var storing_active: bool = false
	var cleaning_done: int = 0
	var cleaning_total: int = 0
	var storing_done: int = 0
	var storing_total: int = 0
	var done: int = 0
	var total: int = 0
	var complete: bool = false
	## Pourcentage affiché : entier arrondi vers le bas ; 100 seulement si la pièce est complète.
	var percent: int = 0

	func same_as(other: Result) -> bool:
		return other != null and cleaning_done == other.cleaning_done and cleaning_total == other.cleaning_total \
				and storing_done == other.storing_done and storing_total == other.storing_total \
				and cleaning_active == other.cleaning_active and storing_active == other.storing_active


## Calcule la progression. active_axes : axes actifs de RoomData ; surfaces_* : compteurs de
## CleaningSurface (terminées d'office comprises) ; item_datas / item_stored : un ItemData et un état
## « rangé » par objet libre de la pièce (porté compris : non rangé). Les objets sans axe rangement
## suivi ne comptent pas.
static func compute(active_axes: Array, surfaces_done: int, surfaces_total: int, item_datas: Array, item_stored: Array) -> Result:
	var result: Result = Result.new()
	result.cleaning_active = active_axes.has(RoomData.Axis.CLEANING) and COUNTED_AXES.has(RoomData.Axis.CLEANING)
	result.storing_active = active_axes.has(RoomData.Axis.STORING) and COUNTED_AXES.has(RoomData.Axis.STORING)
	if result.cleaning_active:
		result.cleaning_total = maxi(surfaces_total, 0)
		result.cleaning_done = clampi(surfaces_done, 0, result.cleaning_total)
	if result.storing_active:
		for i: int in item_datas.size():
			var data: ItemData = item_datas[i] as ItemData
			if data == null or not data.tracks_storing:
				continue
			result.storing_total += 1
			if i < item_stored.size() and item_stored[i] == true:
				result.storing_done += 1
	result.done = result.cleaning_done + result.storing_done
	result.total = result.cleaning_total + result.storing_total
	result.complete = is_complete(result.done, result.total)
	result.percent = display_percent(result.done, result.total)
	return result


## Complet : total strictement positif et tout est fait.
static func is_complete(done: int, total: int) -> bool:
	return total > 0 and done >= total


## Pourcentage entier arrondi vers le bas (division entière : 99,9 % reste 99). 0 si le total est nul.
static func display_percent(done: int, total: int) -> int:
	if total <= 0:
		return 0
	@warning_ignore("integer_division")
	return clampi(done, 0, total) * 100 / total
