extends SceneTree
## Simula muitas partidas com políticas automáticas para calibrar o equilíbrio.
## Uso: godot --headless --path . --script res://tests/balance_test.gd

const GS := preload("res://scripts/game_state.gd")
const RUNS := 200


func _init() -> void:
	for policy in ["passiva", "esperta"]:
		_run(policy)
	quit()


func _run(policy: String) -> void:
	var wins := 0
	var alive_sum := 0
	var dose_sum := 0.0
	var built_sum := 0
	var grades := {}
	var reasons := {}
	for i in RUNS:
		var s := GS.new()
		s.setup(i)
		while not s.game_over:
			if policy == "esperta":
				smart(s)
			var ev := s.advance_day()
			if not ev.is_empty() and not s.game_over:
				var idx := 0
				while idx < ev["choices"].size() - 1 and s.choice_blocked(ev["choices"][idx]) != "":
					idx += 1
				s.apply_choice(ev, idx)
		if s.victory:
			wins += 1
		else:
			reasons[s.end_reason] = reasons.get(s.end_reason, 0) + 1
		alive_sum += s.alive_count()
		dose_sum += s.avg_dose()
		built_sum += s.stats["builds"]
		var g: String = s.grade()["letter"]
		grades[g] = grades.get(g, 0) + 1
	print("%-8s vitórias %3d%%  vivos %.2f  dose %.0f  obras %.1f  notas %s" % [
		policy, wins * 100 / RUNS, float(alive_sum) / RUNS, dose_sum / RUNS, float(built_sum) / RUNS, grades])
	if not reasons.is_empty():
		print("         derrotas: ", reasons)


## Heurística de um jogador atento: prepara energia para a escuridão.
static func smart(s) -> void:
	# Construções, em ordem de prioridade
	var plan := ["battery", "ridge_cable", "battery", "wadi", "greenhouse", "led", "battery"]
	var want := {}
	for k in plan:
		want[k] = want.get(k, 0) + 1
		if s.count(k) + s.queued(k) < want[k] and s.can_build(k) == "":
			s.start_build(k)
			break
	# Tarefas
	for t in s.TASKS:
		s.tasks[t] = 0
	var roles := ["maintenance", "farming", "construction", "construction"]
	if s.queue.is_empty():
		roles = ["maintenance", "farming", "eva" if s.shield_layers < 2.0 else "rest", "farming"]
	for k in mini(s.alive_count(), roles.size()):
		s.tasks[roles[k]] += 1
	# Energia: tudo em 100% e corta o que for menos essencial se faltar
	for sys in s.SYSTEMS:
		s.alloc[sys] = 1.0
	for cut in ["isru", "greenhouse"]:
		var f: Dictionary = s.compute_flows()
		var low: bool = f["energy_next"] < s.storage_capacity() * 0.3 and f["energy_delta"] < 0
		if f["pf"] < 0.999 or low:
			s.alloc[cut] = 0.5 if cut == "greenhouse" else 0.0
