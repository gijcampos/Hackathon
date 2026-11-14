extends SceneTree
## Simula muitas partidas com políticas automáticas para calibrar o equilíbrio.
## Uso: godot --headless --path . --script res://tests/balance_test.gd

const GS := preload("res://scripts/game_state.gd")
const RUNS := 200


func _init() -> void:
	for loc in ["moon", "mars"]:
		for policy in ["passiva", "esperta"]:
			_run(loc, policy)
	quit()


func _run(loc: String, policy: String) -> void:
	var wins := 0
	var alive_sum := 0
	var sci_sum := 0.0
	var dose_sum := 0.0
	var grades := {}
	var reasons := {}
	var days_sum := 0
	for i in RUNS:
		var s := GS.new()
		s.setup(loc, i)
		while not s.game_over:
			if policy == "esperta":
				_smart(s)
			var ev := s.advance_day()
			if not ev.is_empty() and not s.game_over:
				var idx := 0
				while idx < ev["choices"].size() - 1 and s.choice_blocked(ev["choices"][idx]) != "":
					idx += 1
				if policy == "passiva":
					idx = ev["choices"].size() - 1 if ev["id"] == "spe" else idx
				s.apply_choice(ev, idx)
		if s.victory:
			wins += 1
		else:
			reasons[s.end_reason] = reasons.get(s.end_reason, 0) + 1
		alive_sum += s.alive_count()
		sci_sum += s.science
		dose_sum += s.avg_dose()
		days_sum += s.day - 1
		var g: String = s.grade()["letter"]
		grades[g] = grades.get(g, 0) + 1
	print("%-5s %-8s vitórias %3d%%  vivos %.2f  ciência %.0f  dose %.0f  dias %.1f  notas %s" % [
		loc, policy, wins * 100 / RUNS, float(alive_sum) / RUNS, sci_sum / RUNS, dose_sum / RUNS, float(days_sum) / RUNS, grades])
	if not reasons.is_empty():
		print("      derrotas: ", reasons)


## Heurística simples de um jogador atento.
static func _smart(s) -> void:
	var f: Dictionary = s.compute_flows()
	var alive: int = s.alive_count()
	# Energia: corta laboratório/ISRU/estufa se a bateria não aguenta
	s.alloc["lab"] = 1.0
	s.alloc["greenhouse"] = 1.0
	s.alloc["isru"] = 1.0
	s.alloc["life_support"] = 1.0
	s.alloc["thermal"] = 1.0
	var cuts := ["lab", "greenhouse", "isru"] if s.water < 250 else ["lab", "isru", "greenhouse"]
	for cut in cuts:
		f = s.compute_flows()
		var low: bool = f["battery_next"] < s.battery_capacity() * 0.35 and f["battery_delta"] < 0
		if f["pf"] < 0.999 or (low and cut != "greenhouse"):
			s.alloc[cut] = 0.5 if cut == "greenhouse" else 0.0
	# Antecipa a escuridão lunar (o jogador recebe aviso e vê a contagem)
	if s.location == "moon" and (s.days_until_dark() <= 2 or s.sun_factor() < 1.0):
		s.alloc["lab"] = 0.0
		s.alloc["isru"] = 0.0
		s.alloc["greenhouse"] = minf(s.alloc["greenhouse"], 0.5)
	if s.o2 < 40:
		s.alloc["life_support"] = 1.3
	# Construções
	var want: Dictionary = {}
	if s.location == "moon":
		want = {"battery": 4, "solar": 8, "isru": 1, "greenhouse": 2, "reactor": 1, "water_wall": 1}
	else:
		want = {"greenhouse": 2, "solar": 8, "battery": 3, "water_wall": 1}
	for k in want:
		if k == "water_wall" and (s.water < 450 or s.buildings["isru"] == 0):
			continue
		if s.buildings.get(k, 0) < want[k] and s.can_build(k) == "":
			s.build(k)
			break
	# Tarefas: rotina padrão; EVA no lugar da ciência até ter 2 camadas de blindagem
	for t in s.TASKS:
		s.tasks[t] = 0
	var plan := ["maintenance", "farming", "rest", "science"]
	if s.shield_layers < 2.0:
		plan[3] = "eva"
	if s.integrity < 60:
		plan[3] = "maintenance"
	for k in mini(alive, plan.size()):
		s.tasks[plan[k]] += 1
