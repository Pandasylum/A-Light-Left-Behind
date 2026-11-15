extends SceneTree
## Test de UnlockEvaluator et de la ressource de chaîne. Lancer : tools/godot.sh --headless --path game --script res://tests/test_unlock_chain.gd

const CHAIN_PATH: String = "res://data/unlock/unlock_chain.tres"
const STEP_ZONES: Array = [
	["vestibule"],
	["atelier"],
	["hub_n0", "cuisine", "salle_d_eau", "wc"],
	["salon", "chambre", "hub_n1"],
	["archives_bureau", "hub_n2", "tour_n0_n4"],
	["n5", "n6", "lanterne"],
]

var _failures: int = 0
var _chain: UnlockChain


func _init() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	_chain = load(CHAIN_PATH) as UnlockChain
	_check(_chain != null, "chaîne chargée")
	if _chain == null:
		quit(1)
		return
	_check(_chain.validate().is_empty(), "chaîne valide : %s" % str(_chain.validate()))
	_check(_chain.steps.size() == 6, "6 étapes")

	# Liste vide
	var r: UnlockEvaluator.Result = UnlockEvaluator.evaluate(_chain, [])
	_check(r.completed_steps.is_empty() and r.open_accesses.is_empty(), "liste vide : rien")
	r = UnlockEvaluator.evaluate(null, ["vestibule"])
	_check(r.completed_steps.is_empty(), "chaîne nulle : rien")

	# Étapes dans l'ordre, accès ouverts
	var zones: Array = []
	var expected_access: Array = [["atelier"], ["hub_n0", "cuisine", "salle_d_eau", "wc"], ["porte_fut_n0"], ["acces_n2"], ["trappe_n4_n5"], ["fin_du_jeu"]]
	var accesses: Array = []
	for i: int in 6:
		zones.append_array(STEP_ZONES[i])
		accesses.append_array(expected_access[i])
		r = UnlockEvaluator.evaluate(_chain, zones)
		_check(r.completed_steps.size() == i + 1, "étape %d : %d complètes" % [i + 1, r.completed_steps.size()])
		_check(r.completed_steps[i] == StringName("etape_%d" % (i + 1)), "étape %d : identifiant" % (i + 1))
		_check(_same_set(r.open_accesses, accesses), "étape %d : accès %s" % [i + 1, str(r.open_accesses)])

	# Tour restaurée avant l'étape 3 : compte déjà, n'ouvre rien d'autre
	r = UnlockEvaluator.evaluate(_chain, ["tour_n0_n4"])
	_check(r.completed_steps.is_empty() and r.open_accesses.is_empty(), "tour seule : aucune étape")
	r = UnlockEvaluator.evaluate(_chain, ["tour_n0_n4", "vestibule"])
	_check(r.completed_steps == [&"etape_1"], "tour + vestibule : seule l'étape 1")
	r = UnlockEvaluator.evaluate(_chain, ["tour_n0_n4", "archives_bureau", "hub_n2"])
	_check(r.completed_steps == [&"etape_5"] and r.open_accesses == [&"trappe_n4_n5"], "étape 5 sans les étapes précédentes")
	r = UnlockEvaluator.evaluate(_chain, ["tour_n0_n4", "vestibule", "atelier", "hub_n0", "cuisine", "salle_d_eau", "wc"])
	_check(r.completed_steps == [&"etape_1", &"etape_2", &"etape_3"], "tour restaurée avant l'étape 3")
	_check(r.open_accesses.has(&"porte_fut_n0") and not r.open_accesses.has(&"trappe_n4_n5"), "porte du fût N0 ouverte, trappe fermée")

	# Étape 5 : manque une seule zone
	var s5: Array = STEP_ZONES[4]
	for missing: int in s5.size():
		var z: Array = s5.duplicate()
		z.remove_at(missing)
		r = UnlockEvaluator.evaluate(_chain, z)
		_check(not r.completed_steps.has(&"etape_5") and not r.open_accesses.has(&"trappe_n4_n5"), "étape 5 incomplète sans %s" % s5[missing])
	# Trappe ouverte dans tous les ordres
	for perm: Array in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		var z2: Array = []
		for k: int in 3:
			z2.append(s5[perm[k]])
			var open_now: bool = UnlockEvaluator.evaluate(_chain, z2).open_accesses.has(&"trappe_n4_n5")
			_check(open_now == (k == 2), "trappe, ordre %s, après %d zone(s)" % [str(perm), k + 1])

	# Inconnus et doublons
	r = UnlockEvaluator.evaluate(_chain, ["inconnue", "", "vestibule", "vestibule", "vestibule"])
	_check(r.completed_steps == [&"etape_1"] and r.open_accesses == [&"atelier"], "inconnus et doublons ignorés")
	r = UnlockEvaluator.evaluate(_chain, [&"vestibule", "atelier"])
	_check(r.completed_steps == [&"etape_1", &"etape_2"], "StringName et String mélangés")

	# Étape sans zone requise : jamais complète
	var empty_step: UnlockStep = UnlockStep.new()
	empty_step.id = &"vide"
	empty_step.opens = [&"x"]
	var chain2: UnlockChain = UnlockChain.new()
	chain2.steps = [empty_step]
	r = UnlockEvaluator.evaluate(chain2, ["vestibule"])
	_check(r.completed_steps.is_empty() and r.open_accesses.is_empty(), "étape sans zone requise jamais complète")
	_check(not empty_step.validate().is_empty(), "validate signale l'étape sans zone")

	print("test_unlock_chain : ", "OK" if _failures == 0 else "%d échec(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x: Variant in a:
		if not b.has(x):
			return false
	return true


func _check(ok: bool, label: String) -> void:
	if not ok:
		_failures += 1
		printerr("ÉCHEC : ", label)
