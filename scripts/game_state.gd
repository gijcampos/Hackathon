extends RefCounted
## Estado e simulação do posto avançado lunar.
## Não depende de nenhuma UI: pode ser testado em modo headless (tests/balance_test.gd).
## Unidade de energia usada em todo o jogo: kWh (quilowatt-hora) por dia.

const EventsDB := preload("res://scripts/events_db.gd")

# ---------------------------------------------------------------- sistemas (consumo)

const SYSTEMS := ["life_support", "greenhouse", "thermal", "isru"]
const SYSTEM_NAMES := {
	"life_support": "Suporte de vida",
	"greenhouse": "Estufa (iluminação)",
	"thermal": "Controle térmico",
	"isru": "ISRU (recursos locais)",
}

# ---------------------------------------------------------------- tarefas

const TASKS := ["maintenance", "farming", "construction", "eva", "rest"]
const TASK_NAMES := {
	"maintenance": "Manutenção",
	"farming": "Agricultura",
	"construction": "Construção",
	"eva": "EVA: blindagem",
	"rest": "Descanso",
}
const TASK_HELP := {
	"maintenance": "+1,3% de integridade por pessoa/dia. O habitat se desgasta 0,8% por dia.",
	"farming": "Cuidar das plantas. Ideal: 1 agricultor para cada 2 racks de estufa.\nSem agricultor a estufa rende só 65%.",
	"construction": "Cada pessoa adiciona 1 ponto de obra por dia à fila de construção.\nSem construtores, nada novo fica pronto.",
	"eva": "Empilha regolito sobre a cúpula: 4 pessoas-dia = 1 camada (-15% de radiação, até 4).\nDose extra de radiação e 3% de risco de acidente por saída.",
	"rest": "Recuperação de saúde mais rápida (+1 por dia).",
}

# ---------------------------------------------------------------- constantes físicas

const O2_PER_PERSON := 0.84        # kg/dia
const WATER_PER_PERSON := 3.5      # L/dia
const FOOD_PER_PERSON := 1.0       # rações/dia
const WATER_PER_KG_O2 := 1.125     # L de água por kg de O2 na eletrólise
const DOSE_LIMIT := 250.0          # mSv (limite da missão)
const LS_KWH_PER_PERSON := 12.0
const GH_KWH := 35.0
const ISRU_KWH := 30.0
const FOOD_PER_GH := 1.5
const MAX_LAYERS := 4.0
const CREW_SIZE := 4

# ---------------------------------------------------------------- catálogo de construções
# cost = peças · work = pessoas-dia de obra · limit = máximo

const BUILD_CATEGORIES := [
	["Geração de energia", ["solar", "vsat", "rtg", "ridge_cable", "reactor"]],
	["Armazenamento de energia", ["battery", "rfc", "wadi"]],
	["Suporte à vida", ["greenhouse", "led", "recycler", "isru", "water_wall"]],
]

const BUILDINGS := {
	"solar": {
		"name": "Painel solar", "cost": 8, "work": 2, "limit": 12,
		"desc": "Painel fotovoltaico fixo.",
		"fact": "No polo sul o Sol fica sempre rente ao horizonte, então painéis deitados captam pouco.",
	},
	"vsat": {
		"name": "Torre solar vertical", "cost": 14, "work": 3, "limit": 6,
		"desc": "Painel vertical em mastro, girando para seguir o Sol baixo do polo.",
		"fact": "A NASA desenvolve torres solares verticais (VSAT) de até 20 m de altura para o programa Artemis.",
	},
	"rtg": {
		"name": "Gerador de radioisótopo (RTG)", "cost": 18, "work": 2, "limit": 3,
		"desc": "Converte o calor do decaimento de plutônio-238 em eletricidade. Pouca energia, mas constante, e o calor residual aquece a cúpula.",
		"fact": "Os rovers Curiosity e Perseverance e as sondas Voyager usam RTGs.",
	},
	"ridge_cable": {
		"name": "Linha até a crista iluminada", "cost": 24, "work": 8, "limit": 2,
		"desc": "Campo de painéis numa crista vizinha, que fica iluminada quando a base escurece, ligado à base por cabo.",
		"fact": "Algumas cristas perto de Shackleton recebem sol em mais de 80% do tempo: são os 'picos de luz quase eterna'.",
	},
	"reactor": {
		"name": "Reator de fissão", "cost": 40, "work": 10, "limit": 1,
		"desc": "Pequeno reator nuclear enterrado longe da cúpula. Muita energia, constante, de dia e de noite.",
		"fact": "O projeto Fission Surface Power da NASA prevê reatores de 40 kW na Lua. O teste KRUSTY (2018) validou o conceito.",
	},
	"battery": {
		"name": "Bateria de íons de lítio", "cost": 8, "work": 2, "limit": 6,
		"desc": "Armazena energia com pouca perda.",
		"fact": "Baterias de íons de lítio substituíram as de níquel-hidrogênio da ISS a partir de 2017.",
	},
	"rfc": {
		"name": "Célula a combustível regenerativa", "cost": 16, "work": 4, "limit": 3,
		"desc": "Usa o excesso de energia para quebrar água em H2 e O2 e depois recombina os gases para gerar eletricidade. Guarda muito mais que a bateria, mas perde quase metade na conversão.",
		"fact": "Células a combustível geraram a eletricidade das naves Apollo e do ônibus espacial; a água produzida era bebida pela tripulação.",
	},
	"wadi": {
		"name": "Reservatório térmico de regolito", "cost": 10, "work": 3, "limit": 2,
		"desc": "Bloco de regolito sinterizado que acumula calor durante o dia e o devolve à cúpula no escuro, reduzindo o gasto com aquecimento.",
		"fact": "Os 'thermal wadis' foram propostos para manter robôs vivos na noite lunar sem gastar bateria.",
	},
	"greenhouse": {
		"name": "Rack de estufa", "cost": 14, "work": 4, "limit": 4,
		"desc": "Prateleira de cultivo com iluminação LED dentro da cúpula.",
		"fact": "O experimento Veggie, na ISS, cultiva alfaces e outras folhas sob luz LED vermelha e azul desde 2014.",
	},
	"led": {
		"name": "LEDs de alta eficiência", "cost": 10, "work": 3, "limit": 1,
		"desc": "Melhoria: troca a iluminação da estufa por LEDs ajustados ao espectro que as plantas absorvem.",
		"fact": "Plantas usam principalmente luz vermelha e azul; iluminar só esses comprimentos de onda economiza energia.",
	},
	"recycler": {
		"name": "Reciclador de água avançado", "cost": 12, "work": 4, "limit": 1,
		"desc": "Melhoria: recupera mais água da urina e da umidade do ar.",
		"fact": "Em 2023 o sistema de recuperação de água da ISS atingiu 98% de reaproveitamento.",
	},
	"isru": {
		"name": "Unidade ISRU", "cost": 18, "work": 5, "limit": 3,
		"desc": "Extrai gelo do regolito das crateras sombreadas e o transforma em água e oxigênio.",
		"fact": "Em 2009 a missão LCROSS lançou um estágio de foguete numa cratera polar e detectou água na nuvem de detritos.",
	},
	"water_wall": {
		"name": "Parede de água do abrigo", "cost": 5, "work": 2, "limit": 1,
		"desc": "Envolve o abrigo central com 300 L de água: o hidrogênio da água bloqueia bem as partículas de radiação.",
		"fact": "Muitos projetos de habitat usam a própria reserva de água como escudo contra tempestades solares.",
	},
}

## Parâmetros da missão lunar.
const MOON := {
	"name": "Lua: borda da cratera Shackleton (polo sul)",
	"mission_length": 60,
	"base_dose": 1.35,
	"wear": 0.8,
	"start": {"o2": 100.0, "water": 500.0, "food": 180.0, "parts": 90},
	"buildings": {"solar": 4, "battery": 1, "greenhouse": 1},
}

## Modificadores temporários que eventos podem ativar (nome -> descrição na UI).
const MODIFIER_NAMES := {
	"recycler_fail": "Reciclador de água degradado (recuperação pela metade)",
	"blight": "Praga na estufa (-9% de saúde das plantas por dia)",
	"reactor_off": "Reator desligado",
	"solar_dim": "Painéis com geração reduzida (-75%)",
}

var day := 1
var rng := RandomNumberGenerator.new()

var o2 := 0.0
var water := 0.0
var food := 0.0
var energy := 0.0            # kWh armazenados
var parts := 0
var integrity := 100.0
var crop_health := 100.0
var shield_layers := 0.0

var buildings := {}
var queue: Array = []        # obras em andamento: {"kind", "work_left", "work_total"}
var alloc := {"life_support": 1.0, "greenhouse": 1.0, "thermal": 1.0, "isru": 1.0}
var tasks := {"maintenance": 1, "farming": 1, "construction": 2, "eva": 0, "rest": 0}
var crew: Array = []
var modifiers := {}
var work_block := ""         # "" | "shelter" -> vale para o próximo dia
var pending := {}            # dados temporários do evento em andamento
var last_seen := {}          # id do evento -> dia em que ocorreu

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
	"energy_wasted": 0.0,
}


func setup(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var s: Dictionary = MOON["start"]
	o2 = s["o2"]
	water = s["water"]
	food = s["food"]
	parts = s["parts"]
	buildings.clear()
	for k in BUILDINGS:
		buildings[k] = int(MOON["buildings"].get(k, 0))
	energy = storage_capacity() * 0.8
	crew.clear()
	for i in CREW_SIZE:
		crew.append({"name": "Tripulante %d" % (i + 1), "health": 100.0, "dose": 0.0, "alive": true})
	add_log("[b]Missão iniciada:[/b] %s. Duração: %d dias." % [MOON["name"], mission_length()])


# ---------------------------------------------------------------- consultas

func mission_length() -> int:
	return MOON["mission_length"]


func count(kind: String) -> int:
	return int(buildings.get(kind, 0))


func queued(kind: String) -> int:
	var n := 0
	for q in queue:
		if q["kind"] == kind:
			n += 1
	return n


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


## Produtividade da equipe: cai quando a saúde média cai.
func crew_efficiency() -> float:
	var a := alive_crew()
	if a.is_empty():
		return 0.0
	var h := 0.0
	for c in a:
		h += c["health"]
	return 0.5 + 0.5 * (h / a.size()) / 100.0


## Ciclo de iluminação no polo sul lunar: picos de "luz quase eterna", mas com
## alguns dias de escuridão a cada ciclo de ~29 dias.
func moon_phase() -> int:
	return (day - 1) % 29


func sun_factor() -> float:
	var p := moon_phase()
	if p >= 21 and p <= 25:
		return 0.0
	if p in [19, 20, 26, 27]:
		return 0.4
	return 1.0


func period_name() -> String:
	var s := sun_factor()
	if s == 0.0:
		return "Escuridão"
	if s < 1.0:
		return "Penumbra"
	return "Sol"


func days_until_dark() -> int:
	var p := moon_phase()
	if p < 19:
		return 19 - p
	return 0


func shield_fraction() -> float:
	return minf(0.85, 0.2 + 0.15 * floorf(shield_layers))


func shelter_factor() -> float:
	if count("water_wall") > 0:
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


# ---------------------------------------------------------------- energia

## Energia gerada por UMA unidade de cada fonte, nas condições de hoje (kWh/dia).
func unit_generation(kind: String) -> float:
	var s := sun_factor()
	var dim := 0.25 if modifiers.has("solar_dim") else 1.0
	match kind:
		"solar":
			return 30.0 * s * dim
		"vsat":
			var v := 1.0 if s == 1.0 else (0.7 if s > 0.0 else 0.0)
			return 45.0 * v * dim
		"rtg":
			return 12.0
		"ridge_cable":
			return 40.0
		"reactor":
			return 0.0 if modifiers.has("reactor_off") else 120.0
	return 0.0


func generation_breakdown() -> Dictionary:
	var out := {}
	for k in ["solar", "vsat", "rtg", "ridge_cable", "reactor"]:
		if count(k) > 0:
			out[k] = unit_generation(k) * count(k)
	return out


func storage_capacity() -> float:
	return count("battery") * 150.0 + count("rfc") * 400.0


## Eficiência de carga: média ponderada pela capacidade (bateria 90%, célula 55%).
func charge_efficiency() -> float:
	var cap := storage_capacity()
	if cap <= 0.0:
		return 1.0
	return (count("battery") * 150.0 * 0.9 + count("rfc") * 400.0 * 0.55) / cap


func thermal_base() -> float:
	var s := sun_factor()
	if s == 0.0:
		return 30.0
	if s < 1.0:
		return 18.0
	return 8.0


## Economia de aquecimento das construções (kWh/dia).
func thermal_savings() -> float:
	var sav := count("rtg") * 4.0
	if sun_factor() < 1.0:
		sav += count("wadi") * 10.0
	return sav


func thermal_demand() -> float:
	return maxf(3.0, thermal_base() - thermal_savings())


func greenhouse_kwh_per_rack() -> float:
	return GH_KWH * (0.65 if count("led") > 0 else 1.0)


func water_recovery() -> float:
	var r := 0.98 if count("recycler") > 0 else 0.93
	if modifiers.has("recycler_fail"):
		r *= 0.5
	return r


## Consumo de cada sistema a 100% (kWh/dia), nas condições de hoje.
func system_full_demand(sys: String) -> float:
	match sys:
		"life_support":
			return LS_KWH_PER_PERSON * alive_count()
		"greenhouse":
			return greenhouse_kwh_per_rack() * count("greenhouse")
		"thermal":
			return thermal_demand()
		"isru":
			return ISRU_KWH * count("isru")
	return 0.0


# ---------------------------------------------------------------- simulação

## Calcula os fluxos de um dia sem alterar o estado (usado na previsão e no avanço).
func compute_flows() -> Dictionary:
	var f := {}
	var alive := alive_count()
	var blocked := work_block != ""
	var t := {}
	for k in TASKS:
		t[k] = 0 if blocked else int(tasks[k])
	if blocked:
		t["rest"] = alive
	var ce := crew_efficiency()

	# --- Energia
	var demand := {}
	var total_demand := 0.0
	for s in SYSTEMS:
		demand[s] = system_full_demand(s) * alloc[s]
		total_demand += demand[s]
	var gen_parts := generation_breakdown()
	var gen := 0.0
	for k in gen_parts:
		gen += gen_parts[k]
	var cap := storage_capacity()
	var pf := 1.0
	var energy_next := energy
	var wasted := 0.0
	if gen >= total_demand:
		var stored := (gen - total_demand) * charge_efficiency()
		energy_next = energy + stored
		if energy_next > cap:
			wasted = (energy_next - cap) / maxf(charge_efficiency(), 0.01)
			energy_next = cap
	else:
		var deficit := total_demand - gen
		if energy >= deficit:
			energy_next = energy - deficit
		else:
			pf = (gen + energy) / total_demand
			energy_next = 0.0

	var eff := {}
	for k in SYSTEMS:
		eff[k] = alloc[k] * pf
	var machine := 1.0 if integrity >= 50.0 else 0.5 + integrity / 100.0
	var gh := count("greenhouse")
	var isru := count("isru")

	# --- Oxigênio
	var ls_eff: float = eff["life_support"]
	var o2_ls := O2_PER_PERSON * alive * 1.05 * ls_eff * machine
	var gh_eff: float = minf(eff["greenhouse"], 1.3)
	var o2_gh := 0.25 * gh * gh_eff * crop_health / 100.0
	var o2_isru: float = 1.0 * isru * eff["isru"] * machine
	var o2_leak := 0.0
	if integrity < 50.0:
		o2_leak = (50.0 - integrity) * 0.06
	f["o2_delta"] = o2_ls + o2_gh + o2_isru - O2_PER_PERSON * alive - o2_leak

	# --- Água
	var water_use := WATER_PER_PERSON * alive
	var water_in: float = water_use * water_recovery() * minf(ls_eff, 1.0) * machine + 8.0 * isru * eff["isru"] * machine
	var water_out := water_use + o2_ls * WATER_PER_KG_O2 + 0.5 * gh
	f["water_delta"] = water_in - water_out

	# --- Comida
	var farm_factor := 0.65 + 0.35 * minf(1.0, float(t["farming"]) * 2.0 / maxf(1.0, gh))
	var food_prod := gh * FOOD_PER_GH * gh_eff * crop_health / 100.0 * farm_factor * ce
	f["food_produced"] = food_prod
	f["food_delta"] = food_prod - FOOD_PER_PERSON * alive
	var crop_delta := 4.0
	if gh > 0 and eff["greenhouse"] < 0.5:
		crop_delta = -14.0 * (0.5 - eff["greenhouse"]) / 0.5 - 2.0
	if modifiers.has("blight"):
		crop_delta -= 9.0
	f["crop_delta"] = crop_delta

	# --- Integridade, obra, blindagem
	f["integrity_delta"] = -float(MOON["wear"]) + 1.3 * t["maintenance"] * ce
	f["build_work"] = float(t["construction"]) * ce
	f["shield_delta"] = 0.25 * t["eva"] * ce if shield_layers < MAX_LAYERS else 0.0

	# --- Radiação (mSv)
	var base_dose: float = MOON["base_dose"]
	var dose_hab := base_dose * (1.0 - shield_fraction())
	if work_block == "shelter":
		dose_hab = base_dose * shelter_factor()
	f["dose_hab"] = dose_hab
	f["dose_eva_extra"] = base_dose * 0.25

	# --- Saúde e alertas
	var hp := 0.0
	var warnings: Array = []
	if ls_eff < 0.6:
		hp += (0.6 - ls_eff) * 25.0
		warnings.append("CO2 acumulando: suporte de vida abaixo de 60%")
	var th_eff: float = eff["thermal"]
	if th_eff < 0.7:
		hp += (0.7 - th_eff) * 20.0
		warnings.append("Frio na cúpula: controle térmico abaixo de 70%")
	f["health_penalty"] = hp
	f["co2"] = ls_eff < 0.6
	f["cold"] = th_eff < 0.7
	if pf < 0.999:
		warnings.append("APAGÃO: demanda maior que geração + energia armazenada (%d%% atendido)" % int(pf * 100))
	if gh > 0 and eff["greenhouse"] < 0.5:
		warnings.append("Plantas morrendo: estufa com menos de 50% de luz")
	if integrity < 50.0:
		warnings.append("Integridade baixa: vazamento de O2 e máquinas menos eficientes")
	if not queue.is_empty() and t["construction"] == 0 and not blocked:
		warnings.append("Há obras na fila, mas ninguém está na construção")
	if alive - assigned_count() > 0 and not blocked:
		warnings.append("%d tripulante(s) sem tarefa" % (alive - assigned_count()))

	f["warnings"] = warnings
	f["gen_parts"] = gen_parts
	f["gen"] = gen
	f["demand"] = demand
	f["total_demand"] = total_demand
	f["pf"] = pf
	f["energy_next"] = energy_next
	f["energy_delta"] = energy_next - energy
	f["wasted"] = wasted
	f["eff"] = eff
	return f


## Avança um dia. Retorna o evento sorteado para o novo dia (ou {}).
func advance_day() -> Dictionary:
	if game_over:
		return {}
	var f := compute_flows()
	var alive_before := alive_count()
	var eva_today: int = 0 if work_block != "" else int(tasks["eva"])

	energy = f["energy_next"]
	stats["energy_wasted"] += f["wasted"]
	o2 += f["o2_delta"]
	water += f["water_delta"]
	food += f["food_delta"]
	integrity = clampf(integrity + f["integrity_delta"], 0.0, 100.0)
	if count("greenhouse") > 0:
		crop_health = clampf(crop_health + f["crop_delta"], 0.0, 100.0)
	shield_layers = minf(MAX_LAYERS, shield_layers + f["shield_delta"])
	_progress_construction(f["build_work"])

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
			add_log("Fim do efeito: %s." % MODIFIER_NAMES.get(k, k))

	work_block = ""
	history.append({
		"day": day, "o2": o2, "water": water, "food": food, "energy": energy,
		"integrity": integrity, "dose": avg_dose(), "alive": alive_count(),
	})
	day += 1
	if alive_count() < alive_before:
		add_log("A tripulação perdeu um integrante. Todo o trabalho fica mais pesado.")
	_check_end()
	if game_over:
		return {}
	return roll_event()


func _progress_construction(work: float) -> void:
	while work > 0.0 and not queue.is_empty():
		var q: Dictionary = queue[0]
		var used := minf(work, q["work_left"])
		q["work_left"] -= used
		work -= used
		if q["work_left"] <= 0.001:
			queue.pop_front()
			_finish_building(q["kind"])


func _finish_building(kind: String) -> void:
	buildings[kind] = count(kind) + 1
	stats["builds"] += 1
	if kind == "battery" or kind == "rfc":
		energy = minf(energy + 20.0, storage_capacity())
	add_log("[color=#3fb950]Obra concluída: %s.[/color]" % BUILDINGS[kind]["name"])


func _check_deaths() -> void:
	for c in crew:
		if c["alive"] and c["health"] <= 0.0:
			c["alive"] = false
			stats["deaths"] += 1
			add_log("[color=#f85149][b]%s morreu.[/b][/color]" % c["name"])
	while assigned_count() > alive_count():
		for k in ["rest", "eva", "construction", "farming", "maintenance"]:
			if tasks[k] > 0 and assigned_count() > alive_count():
				tasks[k] -= 1


func _check_end() -> void:
	if alive_count() == 0:
		_end(false, "Toda a tripulação morreu.")
	elif integrity <= 0.0:
		_end(false, "A cúpula perdeu a integridade estrutural e despressurizou.")
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
	var b: Dictionary = BUILDINGS[kind]
	if count(kind) + queued(kind) >= int(b["limit"]):
		return "Limite atingido (%d)." % int(b["limit"])
	if parts < int(b["cost"]):
		return "Peças insuficientes."
	if kind == "water_wall" and water < 320.0:
		return "Precisa de 300 L de água (e uma margem)."
	return ""


## Coloca uma obra na fila. As peças são gastas na hora; a obra avança com a tarefa Construção.
func start_build(kind: String) -> bool:
	if can_build(kind) != "":
		return false
	var b: Dictionary = BUILDINGS[kind]
	parts -= int(b["cost"])
	if kind == "water_wall":
		water -= 300.0
	queue.append({"kind": kind, "work_left": float(b["work"]), "work_total": float(b["work"])})
	add_log("Obra iniciada: %s (%d pessoas-dia)." % [b["name"], int(b["work"])])
	decisions.append("Dia %d: iniciou %s" % [day, b["name"]])
	return true


## Cancela uma obra da fila e devolve as peças.
func cancel_build(index: int) -> void:
	if index < 0 or index >= queue.size():
		return
	var q: Dictionary = queue[index]
	var b: Dictionary = BUILDINGS[q["kind"]]
	parts += int(b["cost"])
	if q["kind"] == "water_wall":
		water += 300.0
	queue.remove_at(index)
	add_log("Obra cancelada: %s (peças devolvidas)." % b["name"])


func set_task(task: String, value: int) -> int:
	## Ajusta a tarefa respeitando o total de tripulantes vivos. Retorna o valor aplicado.
	var others := assigned_count() - int(tasks[task])
	var v := clampi(value, 0, alive_count() - others)
	tasks[task] = v
	return v


# ---------------------------------------------------------------- textos de ajuda (tooltips)

func _kwh(v: float) -> String:
	return "%.0f kWh/dia" % v


## Explica o que uma construção faz, em kWh, com os números de hoje.
func building_tooltip(kind: String) -> String:
	var b: Dictionary = BUILDINGS[kind]
	var lines: Array = []
	lines.append(String(b["name"]).to_upper())
	lines.append(b["desc"])
	lines.append("")
	match kind:
		"solar":
			lines.append("Energia: +30 kWh/dia com sol, +12 na penumbra, 0 na escuridão.")
		"vsat":
			lines.append("Energia: +45 kWh/dia com sol, +31 na penumbra, 0 na escuridão.")
			lines.append("Comparação: 1,5x um painel comum, e rende bem mais na penumbra.")
		"rtg":
			lines.append("Energia: +12 kWh/dia sempre (sol ou escuridão).")
			lines.append("Calor residual: aquecimento -4 kWh/dia.")
		"ridge_cable":
			lines.append("Energia: +40 kWh/dia sempre, inclusive na escuridão da base.")
		"reactor":
			lines.append("Energia: +120 kWh/dia sempre.")
			lines.append("Equivale a 4 painéis solares com sol, e não para no escuro.")
		"battery":
			lines.append("Armazena: +150 kWh. Eficiência de carga: 90%")
			lines.append("(de cada 10 kWh que sobram, 9 ficam guardados).")
		"rfc":
			lines.append("Armazena: +400 kWh. Eficiência de carga: 55%")
			lines.append("(de cada 10 kWh que sobram, só 5,5 ficam guardados).")
		"wadi":
			lines.append("Aquecimento: -10 kWh/dia na penumbra e na escuridão.")
		"greenhouse":
			lines.append("Consome: +%.0f kWh/dia de luz (a 100%%)." % greenhouse_kwh_per_rack())
			lines.append("Produz: até 1,5 ração/dia e 0,25 kg de O2/dia.")
			lines.append("Cada ração custa ~%.0f kWh de luz." % (greenhouse_kwh_per_rack() / FOOD_PER_GH))
		"led":
			var racks := maxi(1, count("greenhouse"))
			lines.append("Estufa: -35% de consumo (de 35 para 23 kWh/dia por rack).")
			lines.append("Com %d rack(s): economia de ~%.0f kWh/dia." % [racks, GH_KWH * 0.35 * racks])
		"recycler":
			lines.append("Água: recuperação de 93% para 98%.")
			lines.append("Para 4 pessoas: ~0,7 L/dia a menos de perda. Não consome energia extra.")
		"isru":
			lines.append("Consome: +30 kWh/dia (a 100%).")
			lines.append("Produz: +8 L de água e +1 kg de O2 por dia.")
			lines.append("Cada litro de água custa ~3,75 kWh.")
		"water_wall":
			lines.append("Custo extra: 300 L de água da reserva.")
			lines.append("Abrigo: a dose de eventos de radiação cai para 6%.")
	lines.append("")
	lines.append("Custo: %d peças  ·  Obra: %d pessoas-dia" % [int(b["cost"]), int(b["work"])])
	lines.append("Construídos: %d  ·  Em obra: %d  ·  Máximo: %d" % [count(kind), queued(kind), int(b["limit"])])
	if kind in ["solar", "vsat", "rtg", "ridge_cable", "reactor"]:
		lines.append("Hoje (%s), cada unidade geraria %s." % [period_name().to_lower(), _kwh(unit_generation(kind))])
	lines.append("")
	lines.append("Fato real: " + String(b["fact"]))
	return "\n".join(lines)


## Explica o consumo de um sistema em kWh e o que ele entrega na regulagem atual.
func system_tooltip(sys: String) -> String:
	var full := system_full_demand(sys)
	var a: float = alloc[sys]
	var lines: Array = []
	lines.append(String(SYSTEM_NAMES[sys]).to_upper())
	match sys:
		"life_support":
			lines.append("Eletrólise gera O2 a partir da água, filtros removem CO2 e o reciclador recupera água.")
			lines.append("")
			lines.append("Consumo a 100%%: %s (12 por tripulante)." % _kwh(full))
			lines.append("Na regulagem atual (%d%%): %s." % [int(a * 100), _kwh(full * a)])
			lines.append("Cada +10%% custa %.1f kWh/dia." % (full * 0.1))
			lines.append("Produz %.1f kg de O2/dia (a tripulação respira %.1f)." % [O2_PER_PERSON * alive_count() * 1.05 * a, O2_PER_PERSON * alive_count()])
			lines.append("Abaixo de 60%: CO2 se acumula e prejudica a saúde.")
			lines.append("Acima de 100%: estoca O2, mas gasta mais água.")
		"greenhouse":
			lines.append("Luz para os racks de cultivo.")
			lines.append("")
			lines.append("Consumo a 100%%: %s (%.0f por rack, %d rack(s))." % [_kwh(full), greenhouse_kwh_per_rack(), count("greenhouse")])
			lines.append("Na regulagem atual (%d%%): %s." % [int(a * 100), _kwh(full * a)])
			lines.append("Cada +10%% custa %.1f kWh/dia." % (full * 0.1))
			lines.append("Abaixo de 50% as plantas começam a morrer.")
		"thermal":
			lines.append("Aquecimento e radiadores da cúpula.")
			lines.append("")
			lines.append("Necessidade hoje (%s): %s." % [period_name().to_lower(), _kwh(thermal_base())])
			if thermal_savings() > 0.0:
				lines.append("Economia de RTG/reservatório térmico: -%s." % _kwh(thermal_savings()))
			lines.append("Consumo a 100%%: %s. Sol: 8 · Penumbra: 18 · Escuridão: 30." % _kwh(full))
			lines.append("Abaixo de 70%: frio, a tripulação perde saúde.")
		"isru":
			lines.append("Extração de gelo e produção de água e O2.")
			lines.append("")
			if count("isru") == 0:
				lines.append("Nenhuma unidade ISRU construída.")
			lines.append("Consumo a 100%%: %s (30 por unidade)." % _kwh(full))
			lines.append("Na regulagem atual (%d%%): %s." % [int(a * 100), _kwh(full * a)])
			lines.append("Produz %.1f L de água e %.1f kg de O2 por dia." % [8.0 * count("isru") * a, 1.0 * count("isru") * a])
	return "\n".join(lines)


## Resumo da energia para o topo da tela.
func energy_tooltip() -> String:
	var f := compute_flows()
	var lines: Array = ["ENERGIA (kWh)", ""]
	lines.append("Geração hoje:")
	var gp: Dictionary = f["gen_parts"]
	if gp.is_empty():
		lines.append("  nenhuma")
	for k in gp:
		lines.append("  %s x%d: +%.0f" % [BUILDINGS[k]["name"], count(k), gp[k]])
	lines.append("Consumo:")
	for s in SYSTEMS:
		if f["demand"][s] > 0.0:
			lines.append("  %s: -%.0f" % [SYSTEM_NAMES[s], f["demand"][s]])
	lines.append("")
	lines.append("Armazenado: %.0f de %.0f kWh" % [energy, storage_capacity()])
	lines.append("Eficiência de carga: %d%%" % int(charge_efficiency() * 100))
	if f["wasted"] > 0.0:
		lines.append("Desperdício amanhã (armazenamento cheio): %.0f kWh" % f["wasted"])
	return "\n".join(lines)


# ---------------------------------------------------------------- eventos
# Os eventos ficam em scripts/events_db.gd. Veja o modelo comentado lá.

const EVENT_CHANCE := 0.38   # chance de um evento aleatório por dia


func roll_event() -> Dictionary:
	var all_events: Array = EventsDB.all()
	for e in all_events:
		if day in e.get("on_days", []) or moon_phase() == int(e.get("on_moon_phase", -1)):
			last_seen[e["id"]] = day
			return _trigger(e)
	if day < 3 or rng.randf() >= EVENT_CHANCE:
		return {}
	var pool: Array = []
	var total := 0.0
	for e in all_events:
		if _eligible(e):
			pool.append(e)
			total += float(e.get("weight", 1.0))
	if pool.is_empty():
		return {}
	var r := rng.randf() * total
	var ev: Dictionary = pool.back()
	for e in pool:
		r -= float(e.get("weight", 1.0))
		if r <= 0.0:
			ev = e
			break
	last_seen[ev["id"]] = day
	return _trigger(ev)


func _eligible(e: Dictionary) -> bool:
	if e.has("on_days") or e.has("on_moon_phase"):
		return false
	if day < int(e.get("min_day", 3)):
		return false
	var id: String = e["id"]
	if last_seen.has(id) and day - int(last_seen[id]) < int(e.get("cooldown", 10)):
		return false
	var req: Dictionary = e.get("requires", {})
	for k in req:
		match k:
			"integrity_below":
				if integrity >= float(req[k]):
					return false
			"energy_below":
				if energy >= float(req[k]):
					return false
			"no_mod":
				if modifiers.has(req[k]):
					return false
			"dark":
				if (sun_factor() == 0.0) != bool(req[k]):
					return false
			_:
				if count(k) < int(req[k]):
					return false
	return true


func _trigger(e: Dictionary) -> Dictionary:
	var ev: Dictionary = e.duplicate(true)
	pending.clear()
	var vars := {}
	if ev.has("radiation"):
		stats["spe_count"] += 1
		var rr: Array = ev["radiation"]
		var raw := rng.randf_range(float(rr[0]), float(rr[1]))
		pending["radiation_raw"] = raw
		vars["work"] = "%.0f" % (raw * (1.0 - shield_fraction()))
		vars["shelter"] = "%.0f" % (raw * shelter_factor())
	var a := alive_crew()
	if not a.is_empty():
		var c: Dictionary = a[rng.randi_range(0, a.size() - 1)]
		pending["target"] = c
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
	if cost.has("energy") and energy < float(cost["energy"]):
		return "Energia insuficiente"
	return ""


func apply_choice(ev: Dictionary, idx: int) -> void:
	var ch: Dictionary = ev["choices"][idx]
	var cost: Dictionary = ch.get("cost", {})
	if cost.has("parts"):
		parts -= int(cost["parts"])
	if cost.has("water"):
		water -= float(cost["water"])
	if cost.has("energy"):
		energy -= float(cost["energy"])
	apply_effects(ch.get("effects", {}))
	if ev["choices"].size() > 1:
		decisions.append("Dia %d: %s -> %s" % [day, ev["title"], ch["label"]])
	add_log("Decisão: %s" % ch["label"])
	_check_deaths()
	_check_end()


func _val(v) -> float:
	if v is Array:
		return rng.randf_range(float(v[0]), float(v[1]))
	return float(v)


## Aplica um dicionário de efeitos. Lista completa de chaves em events_db.gd.
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
			"energy":
				energy = clampf(energy + _val(v), 0.0, storage_capacity())
			"integrity":
				integrity = clampf(integrity + _val(v), 0.0, 100.0)
			"crop_health":
				crop_health = clampf(crop_health + _val(v), 0.0, 100.0)
			"shield_layers":
				shield_layers = clampf(shield_layers + _val(v), 0.0, MAX_LAYERS)
			"health_all":
				var hv := _val(v)
				for c in alive_crew():
					c["health"] = clampf(c["health"] + hv, 0.0, 100.0)
			"health_target":
				if pending.has("target"):
					var c: Dictionary = pending["target"]
					c["health"] = clampf(c["health"] + _val(v), 0.0, 100.0)
			"health_random":
				var a := alive_crew()
				if not a.is_empty():
					var c: Dictionary = a[rng.randi_range(0, a.size() - 1)]
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
			"radiation":
				_apply_radiation(String(v))
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
				buildings[v] = maxi(0, count(v) - 1)
				energy = minf(energy, storage_capacity())
			"add_building":
				buildings[v] = count(v) + 1
			"risk":
				if rng.randf() < float(v["chance"]):
					add_log("[color=#d29922]%s[/color]" % v["log"])
					apply_effects(v["effects"])
			"log":
				add_log(v)
			_:
				push_warning("Efeito desconhecido em evento: %s" % key)


## mode = "shelter" (abrigo) ou "work" (continuar trabalhando).
func _apply_radiation(mode: String) -> void:
	var raw: float = pending.get("radiation_raw", 0.0)
	var dose := raw * (shelter_factor() if mode == "shelter" else 1.0 - shield_fraction())
	if mode == "shelter":
		stats["spe_shelter"] += 1
		work_block = "shelter"
	for c in alive_crew():
		c["dose"] += dose
		if dose > 100.0:
			c["health"] = maxf(0.0, c["health"] - (dose - 100.0) * 0.4)
	stats["max_dose_day"] = maxf(stats["max_dose_day"], dose)
	add_log("Dose de radiação do evento: %.0f mSv por tripulante." % dose)


func add_log(text: String) -> void:
	log_lines.append("[color=#8b949e]Dia %d[/color]  %s" % [day, text])


# ---------------------------------------------------------------- resultado

func grade() -> Dictionary:
	var score := 0.0
	score += alive_count() * 15.0                                       # até 60
	score += clampf(1.0 - avg_dose() / DOSE_LIMIT, 0.0, 1.0) * 25.0      # até 25
	score += integrity / 100.0 * 15.0                                   # até 15
	if avg_dose() > DOSE_LIMIT:
		score = minf(score, 70.0)
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
		out.append("Houve %d dia(s) de apagão. Fontes que funcionam no escuro (reator, RTG, linha até a crista) ou mais armazenamento evitam que tudo pare ao mesmo tempo." % stats["brownout_days"])
	if stats["cold_days"] > 0:
		out.append("A cúpula passou frio em %d dia(s). Sem sol, a superfície lunar chega a -170 °C; o aquecimento é tão vital quanto o ar." % stats["cold_days"])
	if stats["energy_wasted"] > 200.0:
		out.append("Cerca de %.0f kWh foram desperdiçados com o armazenamento cheio. Mais baterias teriam guardado essa energia para a escuridão." % stats["energy_wasted"])
	if stats["spe_count"] > 0:
		if stats["spe_shelter"] < stats["spe_count"]:
			out.append("Em um evento de radiação a tripulação não foi para o abrigo. Em agosto de 1972, uma tempestade solar entre as Apollo 16 e 17 poderia ter causado doença aguda da radiação em astronautas na superfície.")
		else:
			out.append("A tripulação se abrigou em todos os eventos de radiação. Alertas antecipados de satélites como o SOHO dão minutos a horas para isso.")
	if avg_dose() > DOSE_LIMIT:
		out.append("A dose média passou do limite da missão (%d mSv). A NASA limita a dose de carreira a 600 mSv; blindagem com regolito e água reduz muito a exposição." % int(DOSE_LIMIT))
	elif shield_layers < 1.0:
		out.append("Nenhuma camada de regolito foi colocada sobre a cúpula. Cobrir o habitat com 1 a 3 m de solo local é uma das formas mais baratas de bloquear radiação.")
	if stats["eva_accidents"] > 0:
		out.append("Houve %d acidente(s) em EVA. Cada atividade externa é um risco: poeira abrasiva, quedas e falhas no traje." % stats["eva_accidents"])
	if stats["deaths"] > 0:
		out.append("%d tripulante(s) morreram. Com menos gente, cada tarefa fica mais lenta e a base mais frágil." % stats["deaths"])
	if out.is_empty():
		out.append("Missão exemplar: energia, ar, água, comida e radiação sob controle. É assim que se planeja uma base fora da Terra.")
	return out
