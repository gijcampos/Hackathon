extends RefCounted
## Estado e simulação do posto avançado.
## Não depende de nenhuma UI: pode ser testado em modo headless (tests/balance_test.gd).

const EventsDB := preload("res://scripts/events_db.gd")

const SYSTEMS := ["life_support", "greenhouse", "thermal", "lab", "isru"]
const SYSTEM_NAMES := {
	"life_support": "Suporte de vida",
	"greenhouse": "Estufa (iluminação)",
	"thermal": "Controle térmico",
	"lab": "Laboratório",
	"isru": "ISRU (recursos locais)",
}
const SYSTEM_HELP := {
	"life_support": "Eletrólise gera O2 a partir da água, filtros removem CO2 e o reciclador recupera até 93% da água.\nAbaixo de 60% o CO2 se acumula e prejudica a saúde.\nAcima de 100% produz O2 extra (e gasta mais água).",
	"greenhouse": "Luz LED para as plantas: gera comida, um pouco de O2 e melhora o moral.\nAbaixo de 50% as plantas começam a morrer e levam dias para se recuperar.",
	"thermal": "Aquecimento e radiadores. Na noite lunar a demanda sobe muito.\nAbaixo de 70% a tripulação passa frio e perde saúde.",
	"lab": "Experimentos científicos: o motivo da missão existir.\nÉ o primeiro candidato a corte quando falta energia.",
	"isru": "Uso de recursos in situ. Lua: extrai água do gelo e O2. Marte: produz O2 a partir do CO2 da atmosfera (como o MOXIE).",
}
const TASKS := ["maintenance", "farming", "science", "eva", "rest"]
const TASK_NAMES := {
	"maintenance": "Manutenção",
	"farming": "Agricultura",
	"science": "Ciência",
	"eva": "EVA (atividade externa)",
	"rest": "Descanso",
}
const TASK_HELP := {
	"maintenance": "+1,3% de integridade por pessoa. O habitat se desgasta todo dia.",
	"farming": "Cuidar das plantas. Ideal: 1 agricultor para cada 2 módulos de estufa.\nSem agricultor a estufa rende só 65%.",
	"science": "Cada cientista multiplica a produção do laboratório.",
	"eva": "Empilha regolito sobre o habitat (4 pessoas-dia = 1 camada, -15% de radiação).\nEm Marte também limpa os painéis. Dose extra e risco de acidente (3%).",
	"rest": "+1,8 de moral por pessoa e melhor recuperação de saúde.",
}

const O2_PER_PERSON := 0.84
const WATER_PER_PERSON := 3.5
const FOOD_PER_PERSON := 1.0
const WATER_PER_KG_O2 := 1.125
const WATER_RECOVERY := 0.93
const DOSE_LIMIT := 250.0
const LS_KWH_PER_PERSON := 12.0
const GH_KWH := 35.0
const LAB_KWH := 20.0
const ISRU_KWH := 30.0
const REACTOR_KWH := 120.0
const BATTERY_KWH := 150.0
const FOOD_PER_GH := 1.5
const MAX_LAYERS := 4.0

const BUILD_ORDER := ["solar", "battery", "reactor", "greenhouse", "isru", "water_wall"]
const BUILD_COSTS := {"solar": 8, "battery": 6, "reactor": 35, "greenhouse": 14, "isru": 18, "water_wall": 5}
const BUILD_NAMES := {
	"solar": "Painel solar",
	"battery": "Bateria",
	"reactor": "Reator de fissão",
	"greenhouse": "Módulo de estufa",
	"isru": "Unidade ISRU",
	"water_wall": "Parede de água",
}
const BUILD_LIMITS := {"solar": 14, "battery": 6, "reactor": 2, "greenhouse": 4, "isru": 3, "water_wall": 1}

const LOCATIONS := {
	"moon": {
		"name": "Lua: borda da cratera Shackleton (polo sul)",
		"short": "Lua",
		"mission_length": 60,
		"day_word": "Dia",
		"panel_kwh": 30.0,
		"base_dose": 1.35,
		"spe_factor": 1.0,
		"wear": 0.8,
		"science_target": 180.0,
		"resupply_days": [20, 40],
		"isru_o2": 1.0,
		"isru_water": 8.0,
		"start": {"o2": 100.0, "water": 500.0, "food": 180.0, "parts": 50},
		"buildings": {"solar": 6, "battery": 3, "reactor": 0, "greenhouse": 1, "isru": 0, "water_wall": 0},
	},
	"mars": {
		"name": "Marte: cratera Jezero",
		"short": "Marte",
		"mission_length": 80,
		"day_word": "Sol",
		"panel_kwh": 14.0,
		"base_dose": 0.65,
		"spe_factor": 0.4,
		"wear": 1.0,
		"science_target": 240.0,
		"resupply_days": [],
		"isru_o2": 1.5,
		"isru_water": 4.0,
		"start": {"o2": 110.0, "water": 550.0, "food": 170.0, "parts": 60},
		"buildings": {"solar": 4, "battery": 2, "reactor": 1, "greenhouse": 1, "isru": 1, "water_wall": 0},
	},
}

const CREW_TEMPLATE := [
	{"name": "Ana Ribeiro", "role": "Comandante"},
	{"name": "Kenji Sato", "role": "Engenheiro"},
	{"name": "Amara Okafor", "role": "Médica"},
	{"name": "Lucas Ferreira", "role": "Botânico"},
]

var location := "moon"
var day := 1
var rng := RandomNumberGenerator.new()

var o2 := 0.0
var water := 0.0
var food := 0.0
var battery := 0.0
var parts := 0
var science := 0.0
var morale := 75.0
var integrity := 100.0
var crop_health := 100.0
var dust := 1.0
var shield_layers := 0.0

var buildings := {}
var alloc := {"life_support": 1.0, "greenhouse": 1.0, "thermal": 1.0, "lab": 1.0, "isru": 1.0}
var tasks := {"maintenance": 1, "farming": 1, "science": 1, "eva": 0, "rest": 1}
var crew: Array = []
var modifiers := {}
var work_block := ""        # "" | "shelter" | "day_off" -> vale para o próximo dia
var built_today := false
var pending := {}           # dados temporários do evento em andamento
var last_seen := {}         # id do evento -> dia em que ocorreu

var game_over := false
var victory := false
var end_reason := ""
var log_lines: Array = []
var decisions: Array = []
var history: Array = []
var stats := {
	"brownout_days": 0, "o2_empty_days": 0, "water_empty_days": 0, "food_empty_days": 0,
	"co2_days": 0, "cold_days": 0, "deaths": 0, "eva_accidents": 0, "spe_count": 0,
	"spe_shelter": 0, "max_dose_day": 0.0, "crop_loss_days": 0, "builds": 0,
}


func setup(loc_id: String, seed_value: int = -1) -> void:
	location = loc_id
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var L: Dictionary = loc()
	var s: Dictionary = L["start"]
	o2 = s["o2"]
	water = s["water"]
	food = s["food"]
	parts = s["parts"]
	buildings = (L["buildings"] as Dictionary).duplicate()
	battery = battery_capacity() * 0.8
	crew.clear()
	for c in CREW_TEMPLATE:
		crew.append({"name": c["name"], "role": c["role"], "health": 100.0, "dose": 0.0, "alive": true})
	add_log("[b]Missão iniciada:[/b] %s. Duração: %d %ss." % [L["name"], mission_length(), String(L["day_word"]).to_lower()])


# ---------------------------------------------------------------- consultas

func loc() -> Dictionary:
	return LOCATIONS[location]


func mission_length() -> int:
	return loc()["mission_length"]


func day_word() -> String:
	return loc()["day_word"]


func alive_count() -> int:
	var n := 0
	for c in crew:
		if c["alive"]:
			n += 1
	return n


func alive_crew() -> Array:
	return crew.filter(func(c): return c["alive"])


func assigned_count() -> int:
	var n := 0
	for k in TASKS:
		n += int(tasks[k])
	return n


func battery_capacity() -> float:
	return buildings.get("battery", 0) * BATTERY_KWH


## Ciclo de iluminação no polo sul lunar: picos de "luz quase eterna", mas com
## alguns dias de escuridão a cada ciclo de ~29 dias.
func moon_phase() -> int:
	return (day - 1) % 29


func sun_factor() -> float:
	if location == "mars":
		return 1.0
	var p := moon_phase()
	if p >= 21 and p <= 25:
		return 0.0
	if p in [19, 20, 26, 27]:
		return 0.4
	return 1.0


func period_name() -> String:
	if location == "mars":
		if modifiers.has("dust_storm"):
			return "Tempestade de poeira"
		return "Sol marciano"
	var s := sun_factor()
	if s == 0.0:
		return "Escuridão lunar"
	if s < 1.0:
		return "Penumbra"
	return "Iluminado"


func days_until_dark() -> int:
	if location != "moon":
		return -1
	var p := moon_phase()
	if p < 19:
		return 19 - p
	return 0


func thermal_demand() -> float:
	if location == "mars":
		return 26.0 + (8.0 if modifiers.has("dust_storm") else 0.0)
	var s := sun_factor()
	if s == 0.0:
		return 30.0
	if s < 1.0:
		return 18.0
	return 8.0


func shield_fraction() -> float:
	return minf(0.85, 0.2 + 0.15 * floorf(shield_layers))


func shelter_factor() -> float:
	if buildings.get("water_wall", 0) > 0:
		return 0.06
	return 0.35 * (1.0 - shield_fraction())


func avg_dose() -> float:
	var a := alive_crew()
	if a.is_empty():
		return 0.0
	var t := 0.0
	for c in a:
		t += c["dose"]
	return t / a.size()


# ---------------------------------------------------------------- simulação

## Calcula os fluxos de um dia sem alterar o estado (usado na previsão e no avanço).
func compute_flows() -> Dictionary:
	var f := {}
	var alive := alive_count()
	var L: Dictionary = loc()
	var storm := modifiers.has("dust_storm")
	var blocked := work_block != ""
	var t := {}
	for k in TASKS:
		t[k] = 0 if blocked else int(tasks[k])
	if blocked:
		t["rest"] = alive

	var demand := {
		"life_support": LS_KWH_PER_PERSON * alive * alloc["life_support"],
		"greenhouse": GH_KWH * buildings["greenhouse"] * alloc["greenhouse"],
		"thermal": thermal_demand() * alloc["thermal"],
		"lab": LAB_KWH * alloc["lab"],
		"isru": ISRU_KWH * buildings["isru"] * alloc["isru"],
	}
	var total_demand := 0.0
	for k in demand:
		total_demand += demand[k]
	var panel_kwh: float = L["panel_kwh"]
	var solar: float = buildings["solar"] * panel_kwh * sun_factor() * dust * (0.25 if storm else 1.0)
	var reactor: float = buildings["reactor"] * REACTOR_KWH * (0.0 if modifiers.has("reactor_off") else 1.0)
	var gen := solar + reactor
	var available := gen + battery
	var pf := 1.0
	if total_demand > available and total_demand > 0.0:
		pf = available / total_demand
	var used := total_demand * pf
	var battery_next := clampf(battery + gen - used, 0.0, battery_capacity())

	var eff := {}
	for k in SYSTEMS:
		eff[k] = alloc[k] * pf
	var machine := 1.0 if integrity >= 50.0 else 0.5 + integrity / 100.0
	var crew_eff := 0.6 + 0.4 * morale / 100.0
	var gh: int = buildings["greenhouse"]
	var isru: int = buildings["isru"]

	# Oxigênio
	var ls_eff: float = eff["life_support"]
	var o2_ls := O2_PER_PERSON * alive * 1.05 * ls_eff * machine
	var gh_eff: float = minf(eff["greenhouse"], 1.3)
	var o2_gh := 0.25 * gh * gh_eff * crop_health / 100.0
	var isru_o2: float = L["isru_o2"]
	var o2_isru: float = isru_o2 * isru * eff["isru"] * machine
	var o2_use := O2_PER_PERSON * alive
	var o2_leak := 0.0
	if integrity < 50.0:
		o2_leak = (50.0 - integrity) * 0.06
	f["o2_delta"] = o2_ls + o2_gh + o2_isru - o2_use - o2_leak
	f["o2_leak"] = o2_leak

	# Água
	var water_use := WATER_PER_PERSON * alive
	var recovery := WATER_RECOVERY * minf(ls_eff, 1.0) * machine
	if modifiers.has("recycler_fail"):
		recovery *= 0.5
	var isru_water: float = L["isru_water"]
	var water_in: float = water_use * recovery + isru_water * isru * eff["isru"] * machine
	var water_out := water_use + o2_ls * WATER_PER_KG_O2 + 0.5 * gh
	f["water_delta"] = water_in - water_out

	# Comida
	var farm_factor := 0.65 + 0.35 * minf(1.0, float(t["farming"]) * 2.0 / maxf(1.0, gh))
	var food_prod := gh * FOOD_PER_GH * gh_eff * crop_health / 100.0 * farm_factor * crew_eff
	f["food_produced"] = food_prod
	f["food_delta"] = food_prod - FOOD_PER_PERSON * alive
	var crop_delta := 4.0
	if gh > 0 and eff["greenhouse"] < 0.5:
		crop_delta = -14.0 * (0.5 - eff["greenhouse"]) / 0.5 - 2.0
	if modifiers.has("blight"):
		crop_delta -= 9.0
	f["crop_delta"] = crop_delta

	# Ciência, integridade, blindagem, poeira
	f["science_delta"] = eff["lab"] * machine * (1.0 + 2.5 * t["science"]) * crew_eff
	var wear: float = L["wear"] + (0.6 if storm else 0.0)
	f["integrity_delta"] = -wear + 1.3 * t["maintenance"] * crew_eff
	f["shield_delta"] = 0.25 * t["eva"] * crew_eff if shield_layers < MAX_LAYERS else 0.0
	var dust_delta := 0.0
	if location == "mars":
		dust_delta = -0.006 - (0.02 if storm else 0.0) + 0.08 * t["eva"]
	f["dust_delta"] = dust_delta

	# Radiação (mSv)
	var base_dose: float = L["base_dose"]
	var dose_hab := base_dose * (1.0 - shield_fraction())
	if work_block == "shelter":
		dose_hab = base_dose * shelter_factor()
	f["dose_hab"] = dose_hab
	f["dose_eva_extra"] = base_dose * 0.25

	# Saúde (penalidades de sistemas)
	var hp := 0.0
	var warnings: Array = []
	if ls_eff < 0.6:
		hp += (0.6 - ls_eff) * 25.0
		warnings.append("CO2 acumulando: suporte de vida abaixo de 60%")
	var th_eff: float = eff["thermal"]
	if th_eff < 0.7:
		hp += (0.7 - th_eff) * 20.0
		warnings.append("Frio no habitat: controle térmico abaixo de 70%")
	f["health_penalty"] = hp
	f["co2"] = ls_eff < 0.6
	f["cold"] = th_eff < 0.7

	# Moral
	var m := -1.5
	if work_block == "shelter":
		m -= 2.0
	else:
		m += 1.8 * t["rest"]
		if t["rest"] == 0 and not blocked:
			m -= 1.5
	if gh > 0 and eff["greenhouse"] > 0.3 and crop_health > 40.0:
		m += 0.5
	if pf < 0.999:
		m -= 2.0
	if modifiers.has("conjunction"):
		m -= 0.5
	if food < alive * 5.0:
		m -= 1.0
	f["morale_delta"] = m

	if pf < 0.999:
		warnings.append("APAGÃO: demanda maior que geração + bateria (%d%% atendido)" % int(pf * 100))
	if gh > 0 and eff["greenhouse"] < 0.5:
		warnings.append("Plantas morrendo: estufa com menos de 50% de luz")
	if integrity < 50.0:
		warnings.append("Integridade baixa: vazamento de O2 e máquinas menos eficientes")
	if alive - assigned_count() > 0 and not blocked:
		warnings.append("%d tripulante(s) sem tarefa" % (alive - assigned_count()))

	f["warnings"] = warnings
	f["solar"] = solar
	f["reactor"] = reactor
	f["gen"] = gen
	f["demand"] = demand
	f["total_demand"] = total_demand
	f["pf"] = pf
	f["battery_next"] = battery_next
	f["battery_delta"] = battery_next - battery
	f["eff"] = eff
	return f


## Avança um dia. Retorna o evento sorteado para o novo dia (ou {}).
func advance_day() -> Dictionary:
	if game_over:
		return {}
	var f := compute_flows()
	var alive_before := alive_count()
	var eva_today: int = 0 if work_block != "" else int(tasks["eva"])

	battery = f["battery_next"]
	o2 += f["o2_delta"]
	water += f["water_delta"]
	food += f["food_delta"]
	science += f["science_delta"]
	integrity = clampf(integrity + f["integrity_delta"], 0.0, 100.0)
	if buildings["greenhouse"] > 0:
		crop_health = clampf(crop_health + f["crop_delta"], 0.0, 100.0)
	shield_layers = minf(MAX_LAYERS, shield_layers + f["shield_delta"])
	dust = clampf(dust + f["dust_delta"], 0.2, 1.0)
	morale = clampf(morale + f["morale_delta"], 0.0, 100.0)

	if f["pf"] < 0.999:
		stats["brownout_days"] += 1
	if f["co2"]:
		stats["co2_days"] += 1
	if f["cold"]:
		stats["cold_days"] += 1
	if f["crop_delta"] < 0:
		stats["crop_loss_days"] += 1

	var hp: float = -f["health_penalty"]
	if o2 < 0.0:
		o2 = 0.0
		hp -= 30.0
		stats["o2_empty_days"] += 1
		add_log("[color=#f85149]Sem oxigênio! A tripulação está sufocando.[/color]")
	if water < 0.0:
		water = 0.0
		hp -= 15.0
		stats["water_empty_days"] += 1
		add_log("[color=#f85149]Sem água potável![/color]")
	if food < 0.0:
		food = 0.0
		hp -= 4.0
		morale = maxf(0.0, morale - 4.0)
		stats["food_empty_days"] += 1
		add_log("[color=#f85149]Sem comida: a tripulação passa fome.[/color]")
	if hp >= 0.0:
		hp = 1.0 + (1.0 if int(tasks["rest"]) > 0 or work_block != "" else 0.0)

	for c in alive_crew():
		c["health"] = clampf(c["health"] + hp, 0.0, 100.0)
		c["dose"] += f["dose_hab"]
	stats["max_dose_day"] = maxf(stats["max_dose_day"], f["dose_hab"])

	if eva_today > 0:
		var team := alive_crew()
		team.shuffle()
		for i in mini(eva_today, team.size()):
			var c: Dictionary = team[i]
			c["dose"] += f["dose_eva_extra"]
			if rng.randf() < 0.03:
				var dmg := rng.randf_range(15.0, 35.0)
				c["health"] = maxf(0.0, c["health"] - dmg)
				stats["eva_accidents"] += 1
				add_log("[color=#d29922]Acidente na EVA: %s rasgou o traje e se feriu (-%d saúde).[/color]" % [c["name"], int(dmg)])

	for c in alive_crew():
		if c["dose"] > DOSE_LIMIT:
			c["health"] = maxf(0.0, c["health"] - 0.5 - (c["dose"] - DOSE_LIMIT) * 0.02)

	_check_deaths()

	for k in modifiers.keys():
		modifiers[k] -= 1
		if modifiers[k] <= 0:
			modifiers.erase(k)
			_on_modifier_end(k)

	work_block = ""
	built_today = false
	history.append({
		"day": day, "o2": o2, "water": water, "food": food, "battery": battery,
		"morale": morale, "integrity": integrity, "science": science, "dose": avg_dose(),
		"alive": alive_count(),
	})
	day += 1
	if alive_count() < alive_before:
		morale = maxf(0.0, morale - 25.0)
	_check_end()
	if game_over:
		return {}
	return roll_event()


func _check_deaths() -> void:
	for c in crew:
		if c["alive"] and c["health"] <= 0.0:
			c["alive"] = false
			stats["deaths"] += 1
			add_log("[color=#f85149][b]%s (%s) morreu.[/b][/color]" % [c["name"], c["role"]])
	# Ajusta tarefas se faltar gente
	while assigned_count() > alive_count():
		for k in ["science", "eva", "rest", "farming", "maintenance"]:
			if tasks[k] > 0 and assigned_count() > alive_count():
				tasks[k] -= 1


func _on_modifier_end(k: String) -> void:
	match k:
		"dust_storm":
			add_log("A tempestade de poeira passou. Os painéis voltam a gerar normalmente (mas sujos).")
		"recycler_fail":
			add_log("O reciclador de água voltou a operar normalmente.")
		"blight":
			add_log("O fungo na estufa foi contido.")
		"reactor_off":
			add_log("O reator voltou a operar.")
		"conjunction":
			add_log("Fim da conjunção solar: comunicação com a Terra restabelecida.")


func _check_end() -> void:
	if alive_count() == 0:
		_end(false, "Toda a tripulação morreu.")
	elif integrity <= 0.0:
		_end(false, "O habitat perdeu a integridade estrutural e despressurizou.")
	elif morale <= 0.0:
		_end(false, "O moral chegou a zero. A tripulação se recusou a continuar e a missão foi abortada.")
	elif day > mission_length():
		_end(true, "A missão chegou ao fim e a tripulação foi resgatada.")


func _end(win: bool, reason: String) -> void:
	game_over = true
	victory = win
	end_reason = reason
	add_log("[b]FIM DA MISSÃO:[/b] " + reason)


# ---------------------------------------------------------------- ações do jogador

func can_build(kind: String) -> String:
	## Retorna "" se pode construir, senão o motivo.
	if built_today:
		return "Só é possível uma construção por dia."
	if parts < BUILD_COSTS[kind]:
		return "Peças insuficientes."
	if buildings.get(kind, 0) >= BUILD_LIMITS[kind]:
		return "Limite atingido."
	if kind == "water_wall" and water < 320.0:
		return "Precisa de 300 L de água (e uma margem)."
	return ""


func build(kind: String) -> bool:
	if can_build(kind) != "":
		return false
	parts -= BUILD_COSTS[kind]
	buildings[kind] = buildings.get(kind, 0) + 1
	if kind == "water_wall":
		water -= 300.0
	if kind == "battery":
		battery += 20.0
	built_today = true
	stats["builds"] += 1
	add_log("Construído: %s." % BUILD_NAMES[kind])
	decisions.append("%s %d: construiu %s" % [day_word(), day, BUILD_NAMES[kind]])
	return true


func set_task(task: String, value: int) -> int:
	## Ajusta a tarefa respeitando o total de tripulantes vivos. Retorna o valor aplicado.
	var others := assigned_count() - int(tasks[task])
	var v := clampi(value, 0, alive_count() - others)
	tasks[task] = v
	return v


# ---------------------------------------------------------------- eventos

func roll_event() -> Dictionary:
	var sched := _scheduled_event_id()
	var ev := {}
	if sched != "":
		ev = EventsDB.get_event(sched)
	elif day >= 3 and rng.randf() < 0.38:
		var pool: Array = []
		var total := 0.0
		for e in EventsDB.all():
			if _eligible(e):
				pool.append(e)
				total += float(e.get("weight", 1.0))
		if not pool.is_empty():
			var r := rng.randf() * total
			for e in pool:
				r -= float(e.get("weight", 1.0))
				if r <= 0.0:
					ev = e
					break
			if ev.is_empty():
				ev = pool.back()
	if ev.is_empty():
		return {}
	last_seen[ev["id"]] = day
	return _trigger(ev)


func _scheduled_event_id() -> String:
	if day in loc()["resupply_days"]:
		return "resupply"
	if location == "moon" and moon_phase() == 17:
		return "lunar_night"
	if location == "mars" and day == 45:
		return "conjunction"
	return ""


func _eligible(e: Dictionary) -> bool:
	if e.get("scheduled", false):
		return false
	if not location in e.get("where", ["moon", "mars"]):
		return false
	if day < int(e.get("min_day", 3)):
		return false
	var id: String = e["id"]
	if last_seen.has(id) and day - int(last_seen[id]) < int(e.get("cooldown", 10)):
		return false
	var req: Dictionary = e.get("requires", {})
	for k in req:
		match k:
			"morale_below":
				if morale >= float(req[k]):
					return false
			"no_mod":
				if modifiers.has(req[k]):
					return false
			"dust_below":
				if dust >= float(req[k]):
					return false
			_:
				if buildings.get(k, 0) < int(req[k]):
					return false
	return true


func _trigger(e: Dictionary) -> Dictionary:
	var ev: Dictionary = e.duplicate(true)
	pending.clear()
	var vars := {}
	match ev["id"]:
		"spe":
			stats["spe_count"] += 1
			var raw := rng.randf_range(40.0, 180.0) * float(loc()["spe_factor"])
			pending["spe_raw"] = raw
			vars["work"] = "%.0f" % (raw * (1.0 - shield_fraction()))
			vars["shelter"] = "%.0f" % (raw * shelter_factor())
			vars["wall"] = "com a parede de água" if buildings.get("water_wall", 0) > 0 else "sem parede de água (construa uma!)"
		"illness":
			var a := alive_crew()
			var c: Dictionary = a[rng.randi_range(0, a.size() - 1)]
			pending["sick"] = c
			c["health"] = maxf(1.0, c["health"] - 20.0)
			vars["name"] = c["name"]
	if ev.has("on_trigger"):
		apply_effects(ev["on_trigger"])
	ev["title"] = String(ev["title"]).format(vars)
	ev["text"] = String(ev["text"]).format(vars)
	for ch in ev["choices"]:
		ch["desc"] = String(ch.get("desc", "")).format(vars)
	add_log("[color=#58a6ff][b]Evento:[/b] %s[/color]" % ev["title"])
	return ev


func choice_blocked(ch: Dictionary) -> String:
	var cost: Dictionary = ch.get("cost", {})
	if cost.has("parts") and parts < int(cost["parts"]):
		return "Peças insuficientes"
	if cost.has("water") and water < float(cost["water"]):
		return "Água insuficiente"
	return ""


func apply_choice(ev: Dictionary, idx: int) -> void:
	var ch: Dictionary = ev["choices"][idx]
	var cost: Dictionary = ch.get("cost", {})
	if cost.has("parts"):
		parts -= int(cost["parts"])
	if cost.has("water"):
		water -= float(cost["water"])
	apply_effects(ch.get("effects", {}))
	if ev["choices"].size() > 1:
		decisions.append("%s %d: %s -> %s" % [day_word(), day, ev["title"], ch["label"]])
	add_log("Decisão: %s" % ch["label"])
	_check_deaths()
	_check_end()


func _val(v) -> float:
	if v is Array:
		return rng.randf_range(float(v[0]), float(v[1]))
	return float(v)


func apply_effects(eff: Dictionary) -> void:
	for key in eff:
		var v = eff[key]
		match key:
			"o2":
				o2 = maxf(0.0, o2 + _val(v))
			"water":
				water = maxf(0.0, water + _val(v))
			"food":
				food = maxf(0.0, food + _val(v))
			"parts":
				parts = maxi(0, parts + int(round(_val(v))))
			"morale":
				morale = clampf(morale + _val(v), 0.0, 100.0)
			"integrity":
				integrity = clampf(integrity + _val(v), 0.0, 100.0)
			"science":
				science += _val(v)
			"crop_health":
				crop_health = clampf(crop_health + _val(v), 0.0, 100.0)
			"battery":
				battery = clampf(battery + _val(v), 0.0, battery_capacity())
			"dust":
				dust = clampf(dust + _val(v), 0.2, 1.0)
			"health_all":
				var hv := _val(v)
				for c in alive_crew():
					c["health"] = clampf(c["health"] + hv, 0.0, 100.0)
			"health_random":
				var a := alive_crew()
				if not a.is_empty():
					var c: Dictionary = a[rng.randi_range(0, a.size() - 1)]
					c["health"] = clampf(c["health"] + _val(v), 0.0, 100.0)
			"health_sick":
				if pending.has("sick"):
					var c: Dictionary = pending["sick"]
					c["health"] = clampf(c["health"] + _val(v), 0.0, 100.0)
			"dose_all":
				var dv := _val(v)
				for c in alive_crew():
					c["dose"] += dv
			"dose_team":
				var team := alive_crew()
				team.shuffle()
				for i in mini(2, team.size()):
					team[i]["dose"] += _val(v)
			"spe":
				var raw: float = pending.get("spe_raw", 0.0)
				var dose := raw * (shelter_factor() if v == "shelter" else 1.0 - shield_fraction())
				if v == "shelter":
					stats["spe_shelter"] += 1
					work_block = "shelter"
				for c in alive_crew():
					c["dose"] += dose
					if dose > 100.0:
						c["health"] = maxf(0.0, c["health"] - (dose - 100.0) * 0.4)
				stats["max_dose_day"] = maxf(stats["max_dose_day"], dose)
				add_log("Dose da tempestade solar: %.0f mSv por tripulante." % dose)
			"mods":
				for m in v:
					modifiers[m] = int(round(_val(v[m])))
			"remove_mods":
				for m in v:
					modifiers.erase(m)
			"work_block":
				work_block = v
			"set_alloc":
				for s in v:
					alloc[s] = float(v[s])
			"lose_building":
				buildings[v] = maxi(0, buildings.get(v, 0) - 1)
				battery = minf(battery, battery_capacity())
			"add_building":
				buildings[v] = buildings.get(v, 0) + 1
			"risk":
				if rng.randf() < float(v["chance"]):
					add_log("[color=#d29922]%s[/color]" % v["log"])
					apply_effects(v["effects"])
			"log":
				add_log(v)


func add_log(text: String) -> void:
	log_lines.append("[color=#8b949e]%s %d[/color]  %s" % [day_word(), day, text])


# ---------------------------------------------------------------- resultado

func grade() -> Dictionary:
	var alive := alive_count()
	var target: float = loc()["science_target"]
	var score := 0.0
	score += alive * 12.0                                  # até 48
	score += minf(1.0, science / target) * 25.0           # até 25
	score += clampf(1.0 - avg_dose() / DOSE_LIMIT, 0.0, 1.0) * 17.0
	score += morale / 100.0 * 10.0
	if avg_dose() > DOSE_LIMIT:
		score = minf(score, 70.0)                          # no máximo B
	if not victory:
		score = minf(score, 30.0)
	var letter := "D"
	if score >= 90.0:
		letter = "S"
	elif score >= 78.0:
		letter = "A"
	elif score >= 62.0:
		letter = "B"
	elif score >= 45.0:
		letter = "C"
	return {"score": score, "letter": letter}


## Lições geradas a partir do que aconteceu na partida.
func lessons() -> Array:
	var out: Array = []
	if stats["o2_empty_days"] > 0:
		out.append("O oxigênio acabou. Na ISS, o O2 vem da eletrólise da água: corte de energia no suporte de vida ou falta de água viram falta de ar em poucos dias.")
	if stats["co2_days"] > 0:
		out.append("O CO2 se acumulou por %d dia(s). Na Apollo 13, a tripulação precisou improvisar filtros de CO2 com fita e papelão para sobreviver." % stats["co2_days"])
	if stats["water_empty_days"] > 0:
		out.append("A água acabou. Água é bebida, oxigênio e escudo de radiação ao mesmo tempo, por isso a ISS recicla até 98% dela.")
	if stats["food_empty_days"] > 0:
		out.append("A comida acabou. Estufas exigem energia e tempo: plantas que morrem por falta de luz demoram para se recuperar.")
	if stats["brownout_days"] > 0:
		out.append("Houve %d dia(s) de apagão. Cortar sistemas menos essenciais (laboratório, ISRU) antes de esvaziar a bateria evita que tudo pare ao mesmo tempo." % stats["brownout_days"])
	if stats["cold_days"] > 0:
		out.append("O habitat passou frio em %d dia(s). Na noite lunar a temperatura chega a -170 °C; o aquecimento é tão vital quanto o ar." % stats["cold_days"])
	if stats["spe_count"] > 0:
		if stats["spe_shelter"] < stats["spe_count"]:
			out.append("Em uma tempestade solar a tripulação não foi para o abrigo. Em agosto de 1972, uma tempestade entre as Apollo 16 e 17 poderia ter causado doença aguda da radiação em astronautas na superfície.")
		else:
			out.append("A tripulação se abrigou em todas as tempestades solares. Alertas antecipados de satélites como o SOHO dão minutos a horas para isso.")
	if avg_dose() > DOSE_LIMIT:
		out.append("A dose média passou do limite da missão (%d mSv). A NASA limita a dose de carreira a 600 mSv; blindagem com regolito e água reduz muito a exposição." % int(DOSE_LIMIT))
	elif shield_layers < 1.0:
		out.append("Nenhuma camada de regolito foi construída. Cobrir o habitat com 1 a 3 m de solo local é uma das formas mais baratas de bloquear radiação.")
	if stats["eva_accidents"] > 0:
		out.append("Houve %d acidente(s) em EVA. Cada atividade externa é um risco: poeira abrasiva, quedas e falhas no traje." % stats["eva_accidents"])
	if stats["deaths"] > 0:
		out.append("%d tripulante(s) morreram. O moral despenca a cada perda e a produtividade de todos cai junto." % stats["deaths"])
	if science < float(loc()["science_target"]):
		out.append("A meta científica (%d pts) não foi atingida. Sobreviver é o mínimo; uma missão existe para produzir conhecimento." % int(loc()["science_target"]))
	if out.is_empty():
		out.append("Missão exemplar: energia, ar, água, comida e radiação sob controle. É assim que se planeja uma base fora da Terra.")
	return out
