extends Control
## Desenho procedural da base: cúpula central em corte (interior visível) e as
## estruturas ao redor, que aparecem conforme são construídas.
## Passar o mouse sobre qualquer elemento mostra um tooltip com seus números.

var state = null
var _t := 0.0
var _stars: Array[Vector3] = []
var _hits: Array = []        # [{"rect": Rect2, "key": String}] reconstruído a cada quadro

const C_SHELL := Color(0.86, 0.88, 0.92)
const C_ROOM := Color(0.13, 0.17, 0.24)
const C_ROOM_LINE := Color(0.32, 0.38, 0.48)
const C_GROUND := Color(0.42, 0.42, 0.44)
const C_TEXT := Color(1, 1, 1, 0.85)

const TASK_COLORS := {
	"maintenance": Color(1.0, 0.75, 0.3),
	"farming": Color(0.45, 0.9, 0.45),
	"construction": Color(1.0, 0.55, 0.2),
	"eva": Color(0.95, 0.95, 0.95),
	"rest": Color(0.55, 0.7, 1.0),
	"shelter": Color(1.0, 0.45, 0.45),
}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 140:
		_stars.append(Vector3(r.randf(), r.randf() * 0.6, r.randf_range(0.6, 1.8)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


# ================================================================== tooltip

func _hit(rect: Rect2, key: String) -> void:
	_hits.append({"rect": rect, "key": key})


func _get_tooltip(at_position: Vector2) -> String:
	if state == null:
		return ""
	for i in range(_hits.size() - 1, -1, -1):
		var h: Dictionary = _hits[i]
		if (h["rect"] as Rect2).has_point(at_position):
			return _tooltip_for(h["key"])
	return ""


func _tooltip_for(key: String) -> String:
	var parts := key.split(":")
	match parts[0]:
		"b":
			return state.building_tooltip(parts[1])
		"s":
			return state.system_tooltip(parts[1])
		"q":
			var idx := int(parts[1])
			if idx >= state.queue.size():
				return ""
			var q: Dictionary = state.queue[idx]
			var done: float = q["work_total"] - q["work_left"]
			var builders: int = state.tasks["construction"]
			var txt = "EM OBRA: %s\nProgresso: %.1f de %.0f pessoas-dia" % [state.BUILDINGS[q["kind"]]["name"], done, q["work_total"]]
			if idx > 0:
				txt += "\nPosição na fila: %d (as obras são feitas em ordem)" % (idx + 1)
			if builders > 0:
				var ahead := 0.0
				for j in idx + 1:
					ahead += state.queue[j]["work_left"]
				txt += "\nPronta em ~%d dia(s) com %d construtor(es)." % [ceili(ahead / builders), builders]
			else:
				txt += "\nNinguém na tarefa Construção: a obra está parada."
			return txt + "\n\n" + state.building_tooltip(q["kind"])
		"dome":
			return "CÚPULA PRINCIPAL\nO coração da base: todo o ar, a água e a vida estão aqui dentro.\n\nIntegridade: %d%% (desgaste de 0,8%%/dia; Manutenção repara)\nBlindagem de regolito: %d camada(s), bloqueia %d%% da radiação\nDose dentro da cúpula: %.2f mSv/dia por pessoa" % [int(state.integrity), int(state.shield_layers), int(state.shield_fraction() * 100), 1.35 * (1.0 - state.shield_fraction())]
		"room":
			match parts[1]:
				"life":
					var t: String = state.system_tooltip("life_support")
					t += "\n\nReciclador: recupera %d%% da água%s." % [int(state.water_recovery() * 100), " (avançado)" if state.count("recycler") > 0 else ""]
					return t
				"shelter":
					return "ABRIGO DE RADIAÇÃO\nNúcleo da cúpula, cercado por suprimentos e equipamentos.\nEm um evento de radiação, a dose aqui é %d%% da dose lá fora.\n%s" % [int(state.shelter_factor() * 100), "Parede de água instalada: proteção máxima." if state.count("water_wall") > 0 else "Construa a Parede de água para reduzir para 6%."]
				"bunks":
					return "DORMITÓRIO\nTripulantes em Descanso recuperam saúde mais rápido (+1/dia)."
				"greenhouse":
					return state.system_tooltip("greenhouse") + "\n\nSaúde das plantas: %d%%" % int(state.crop_health)
		"crew":
			var c: Dictionary = state.crew[int(parts[1])]
			return "%s\nTarefa: %s\nSaúde: %d%%\nDose acumulada: %.0f mSv (limite %d)" % [c["name"], parts[2], int(c["health"]), c["dose"], int(state.DOSE_LIMIT)]
		"peak":
			return "CRISTA ILUMINADA\nUm pico vizinho que recebe sol quando a base está no escuro.\nConstrua a 'Linha até a crista iluminada' para aproveitar."
	return ""


# ================================================================== desenho

func _draw() -> void:
	_hits.clear()
	_last_scaffold.clear()
	if state == null:
		return
	var w := size.x
	var h := size.y
	var gy := h * 0.76
	var sun: float = state.sun_factor()
	var font := get_theme_default_font()
	var R := minf(w * 0.30, h * 0.70)
	var cx := w * 0.5

	# --- céu, estrelas, Terra, Sol
	draw_rect(Rect2(0, 0, w, gy), Color(0.02, 0.02, 0.05))
	for s in _stars:
		var tw := 0.6 + 0.4 * sin(_t * s.z * 2.0 + s.x * 40.0)
		draw_circle(Vector2(s.x * w, s.y * gy), s.z * 0.8, Color(1, 1, 1, 0.5 * tw))
	var ep := Vector2(w * 0.9, gy * 0.18)
	draw_circle(ep, 15, Color(0.2, 0.45, 0.9))
	draw_circle(ep + Vector2(-4, -3), 6, Color(0.3, 0.7, 0.35, 0.9))
	if sun > 0.0:
		var sp := Vector2(w * 0.06, gy - 14.0 - 30.0 * sun)
		draw_circle(sp, 24, Color(1, 0.95, 0.7, 0.15 * sun))
		draw_circle(sp, 11, Color(1, 0.95, 0.7, sun))

	# --- crista iluminada no horizonte (direita)
	var peak := Vector2(w - 70.0, gy - 70.0)
	var ridge := PackedVector2Array([Vector2(w - 170, gy), peak + Vector2(-20, 6), peak, peak + Vector2(25, 8), Vector2(w + 10, gy)])
	draw_colored_polygon(ridge, C_GROUND.darkened(0.35))
	draw_line(peak + Vector2(-20, 6), peak, Color(1, 0.95, 0.7, 0.9), 2.0)
	draw_line(peak, peak + Vector2(25, 8), Color(1, 0.95, 0.7, 0.9), 2.0)
	_hit(Rect2(peak.x - 40, peak.y - 10, 80, 50), "peak")

	# --- solo
	var pts := PackedVector2Array([Vector2(0, h)])
	for i in 25:
		var x := w * i / 24.0
		pts.append(Vector2(x, gy - 6.0 * sin(i * 0.9) - 4.0 * sin(i * 2.3)))
	pts.append(Vector2(w, h))
	draw_colored_polygon(pts, C_GROUND.darkened(0.25))
	draw_rect(Rect2(0, gy + 5, w, h - gy), C_GROUND)

	# --- estruturas externas
	var left_x0 := 10.0
	var left_x1 := cx - R - 16.0
	var right_x0 := cx + R + 16.0
	var right_x1 := w - 10.0
	_draw_energy_zone(font, left_x0, left_x1, gy, h, sun)
	_draw_right_zone(font, right_x0, right_x1, gy, h, peak)

	# --- penumbra / escuridão (escurece o exterior; o interior da cúpula continua visível)
	if sun < 1.0:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0.05, 0.45 * (1.0 - sun)))

	# --- cúpula em corte
	_draw_dome(font, Vector2(cx, gy), R)
	if sun < 1.0:
		_draw_dome_lights(Vector2(cx, gy), R)

	# --- avisos
	if state.work_block == "shelter":
		_label(font, Vector2(cx - 140, 24), "TRIPULAÇÃO NO ABRIGO DE RADIAÇÃO", 15, Color(1, 0.5, 0.45))
	_label(font, Vector2(12, 22), "Lua  |  %s" % state.period_name(), 15, Color(1, 1, 1, 0.9))


func _draw_dome(font: Font, base: Vector2, R: float) -> void:
	var cx := base.x
	var gy := base.y

	# Blindagem de regolito (camadas por cima da casca)
	var layers: float = state.shield_layers
	var full := int(floor(layers))
	for i in range(full, 0, -1):
		_semi(base, R + 6.0 + i * 7.0, C_GROUND.darkened(0.05 + 0.07 * i))
	if layers - full > 0.01:
		draw_arc(base, R + 6.0 + (full + 1) * 7.0 - 3.0, PI, PI + PI * (layers - full), 32, C_GROUND.darkened(0.2), 6.0)
	_hit(Rect2(cx - R - 40, gy - R - 40, 2 * R + 80, 36), "dome")

	# Casca e interior
	_semi(base, R + 5.0, C_SHELL)
	var lit = state.energy > 1.0 or state.sun_factor() > 0.0 or state.count("reactor") + state.count("rtg") + state.count("ridge_cable") > 0
	var room = C_ROOM if lit else Color(0.25, 0.07, 0.07)
	_semi(base, R, room)

	# Andar superior (estufa) e inferior (salas)
	var deck_y := gy - R * 0.45
	var half := sqrt(R * R - (R * 0.45) * (R * 0.45))
	draw_line(Vector2(cx - half, deck_y), Vector2(cx + half, deck_y), C_ROOM_LINE, 3.0)
	draw_line(Vector2(cx - R, gy), Vector2(cx + R, gy), C_ROOM_LINE, 3.0)

	# --- salas inferiores
	var x0 := cx - R * 0.93
	var x1 := cx + R * 0.93
	var room_w := (x1 - x0) / 3.0
	var r_life := Rect2(x0, deck_y + 3, room_w, gy - deck_y - 3)
	var r_shel := Rect2(x0 + room_w, deck_y + 3, room_w, gy - deck_y - 3)
	var r_bunk := Rect2(x0 + 2 * room_w, deck_y + 3, room_w, gy - deck_y - 3)
	for r in [r_life, r_shel, r_bunk]:
		draw_rect(r, C_ROOM_LINE, false, 1.5)
	_hit(r_life, "room:life")
	_hit(r_shel, "room:shelter")
	_hit(r_bunk, "room:bunks")
	_label(font, r_life.position + Vector2(6, 14), "Suporte de vida", 13)
	_label(font, r_shel.position + Vector2(6, 14), "Abrigo", 13)
	_label(font, r_bunk.position + Vector2(6, 14), "Dormitório", 13)

	# Suporte de vida: racks com luzes piscando e ventilador
	var ls_on: bool = state.alloc["life_support"] > 0.0
	for i in 3:
		var rr := Rect2(r_life.position.x + 8 + i * (room_w - 16) / 3.0, r_life.position.y + 22, (room_w - 16) / 3.0 - 6, r_life.size.y - 28)
		draw_rect(rr, Color(0.35, 0.4, 0.48))
		for k in 3:
			var blink := 0.5 + 0.5 * sin(_t * 4.0 + i * 1.7 + k * 2.3)
			draw_circle(rr.position + Vector2(6, 8 + k * 9), 2.2, Color(0.3, 1.0, 0.5, blink if ls_on else 0.15))
	if state.count("recycler") > 0:
		var tank := Vector2(r_life.end.x - 14, r_life.end.y - 14)
		draw_circle(tank, 9, Color(0.3, 0.6, 1.0, 0.9))
		_label(font, tank + Vector2(-12, -12), "98%", 9)
	var fan := r_life.position + Vector2(room_w - 16, 30)
	var ang = _t * 6.0 * state.alloc["life_support"]
	for k in 3:
		var a = ang + k * TAU / 3.0
		draw_line(fan, fan + Vector2(cos(a), sin(a)) * 7.0, Color(0.8, 0.85, 0.9), 2.0)

	# Abrigo: núcleo com parede de água opcional
	var core := Rect2(r_shel.position.x + room_w * 0.2, r_shel.position.y + 22, room_w * 0.6, r_shel.size.y - 28)
	if state.count("water_wall") > 0:
		draw_rect(core.grow(5), Color(0.25, 0.55, 1.0, 0.75))
	draw_rect(core, Color(0.22, 0.24, 0.3))
	draw_rect(core, Color(0.6, 0.65, 0.75), false, 1.0)

	# Dormitório: beliches
	for k in 2:
		var by := r_bunk.position.y + 26 + k * (r_bunk.size.y - 30) / 2.0
		draw_rect(Rect2(r_bunk.position.x + 8, by, room_w - 16, 6), Color(0.45, 0.5, 0.65))
		draw_rect(Rect2(r_bunk.position.x + 8, by - 4, 10, 4), Color(0.85, 0.85, 0.9))

	# --- estufa (andar superior)
	var gh_top := gy - R * 0.86
	var gh_rect := Rect2(cx - R * 0.62, gh_top, R * 1.24, deck_y - gh_top - 3)
	_hit(gh_rect, "room:greenhouse")
	_label(font, Vector2(cx - R * 0.62, gh_top - 4), "Estufa", 13)
	var slot_w := gh_rect.size.x / 4.0
	var built: int = state.count("greenhouse")
	var queued_gh: Array = _queue_indices("greenhouse")
	var light: float = clampf(state.alloc["greenhouse"], 0.0, 1.3)
	var led: bool = state.count("led") > 0
	var crop: float = state.crop_health / 100.0
	for i in 4:
		var rr := Rect2(gh_rect.position.x + i * slot_w + 4, gh_rect.position.y + 4, slot_w - 8, gh_rect.size.y - 6)
		if i < built:
			var glow := Color(0.9, 0.3, 0.9, 0.18 * light) if led else Color(1.0, 0.95, 0.75, 0.15 * light)
			draw_rect(rr, glow)
			draw_rect(rr, Color(0.6, 0.65, 0.7), false, 1.5)
			for shelf in 3:
				var sy := rr.position.y + (shelf + 1) * rr.size.y / 3.0
				draw_line(Vector2(rr.position.x, sy), Vector2(rr.end.x, sy), Color(0.6, 0.65, 0.7), 1.5)
				var plant := Color(0.55, 0.45, 0.2).lerp(Color(0.2, 0.85, 0.3), crop)
				var n := int(rr.size.x / 9.0)
				for p in n:
					var px := rr.position.x + 5 + p * 9
					var ph := (4.0 + 3.0 * sin(p * 1.3 + shelf)) * (0.4 + 0.6 * crop)
					draw_circle(Vector2(px, sy - ph), 3.0 * (0.5 + 0.5 * crop), plant)
			_hit(rr, "b:greenhouse")
		elif i - built < queued_gh.size():
			_scaffold(font, rr, queued_gh[i - built])
		else:
			_dashed_rect(rr, Color(1, 1, 1, 0.15))

	# Melhorias internas em obra (andaimes dentro da cúpula)
	for qi in _queue_indices("water_wall"):
		_scaffold(font, core.grow(6), qi)
	for qi in _queue_indices("recycler"):
		_scaffold(font, Rect2(r_life.end.x - 26, r_life.end.y - 26, 22, 22), qi)
	for qi in _queue_indices("led"):
		_scaffold(font, Rect2(gh_rect.end.x - 40, gh_rect.position.y - 16, 38, 14), qi)
	if state.count("water_wall") > 0:
		_hit(core.grow(5), "b:water_wall")
	if state.count("recycler") > 0:
		_hit(Rect2(r_life.end.x - 24, r_life.end.y - 24, 20, 20), "b:recycler")

	# --- tripulantes
	_draw_crew(font, base, R, r_life, r_shel, r_bunk, gh_rect)


func _draw_dome_lights(base: Vector2, R: float) -> void:
	# Mantém o interior visível mesmo no escuro (janelas acesas)
	var lit: bool = state.energy > 1.0 or state.count("reactor") + state.count("rtg") + state.count("ridge_cable") > 0
	if lit:
		draw_arc(base, R + 2.0, PI, TAU, 48, Color(1.0, 0.85, 0.5, 0.25), 3.0)


func _draw_crew(font: Font, base: Vector2, R: float, r_life: Rect2, r_shel: Rect2, r_bunk: Rect2, gh_rect: Rect2) -> void:
	var slots := []
	if state.work_block == "shelter":
		for c in state.crew.size():
			slots.append("shelter")
	else:
		for t in state.TASKS:
			for i in int(state.tasks[t]):
				slots.append(t)
	var idx := 0
	var per_task := {}
	for ci in state.crew.size():
		var c: Dictionary = state.crew[ci]
		if not c["alive"]:
			continue
		var task: String = slots[idx] if idx < slots.size() else "rest"
		idx += 1
		var n: int = per_task.get(task, 0)
		per_task[task] = n + 1
		var pos := Vector2.ZERO
		var bob := sin(_t * 3.0 + ci) * 1.5
		match task:
			"maintenance":
				pos = Vector2(r_life.position.x + 20 + n * 18, r_life.end.y - 2)
			"farming":
				pos = Vector2(gh_rect.position.x + 20 + n * 40, gh_rect.end.y + 1)
			"rest":
				pos = Vector2(r_bunk.position.x + 20 + n * 16, r_bunk.end.y - 2)
			"shelter":
				pos = Vector2(r_shel.position.x + 16 + n * 14, r_shel.end.y - 2)
			"eva":
				var a := PI + PI * (0.35 + 0.12 * n) + sin(_t * 0.5) * 0.03
				pos = base + Vector2(cos(a), sin(a)) * (R + 8.0 + state.shield_layers * 7.0)
			"construction":
				pos = _construction_pos(n)
		pos.y += bob if task in ["eva", "construction"] else 0.0
		var col: Color = TASK_COLORS.get(task, Color.WHITE)
		_person(pos, col, task in ["eva", "construction"])
		_hit(Rect2(pos.x - 7, pos.y - 22, 14, 24), "crew:%d:%s" % [ci, state.TASK_NAMES.get(task, "Abrigo")])


func _construction_pos(n: int) -> Vector2:
	# Perto da primeira obra da fila (ou ao lado da cúpula se a fila estiver vazia)
	if state.queue.size() > 0 and _last_scaffold.has(0):
		var r: Rect2 = _last_scaffold[0]
		return Vector2(r.position.x + 6 + n * 12, r.end.y + 2)
	return Vector2(size.x * 0.5 - minf(size.x * 0.30, size.y * 0.70) - 10 - n * 12, size.y * 0.76 + 14)


var _last_scaffold := {}


func _person(feet: Vector2, col: Color, suit: bool) -> void:
	var head := feet + Vector2(0, -17)
	draw_line(feet + Vector2(-3, 0), feet + Vector2(0, -7), col, 2.0)
	draw_line(feet + Vector2(3, 0), feet + Vector2(0, -7), col, 2.0)
	draw_line(feet + Vector2(0, -7), feet + Vector2(0, -13), col, 3.0)
	draw_line(feet + Vector2(-4, -11), feet + Vector2(4, -11), col, 2.0)
	draw_circle(head, 4.0 if suit else 3.2, col)
	if suit:
		draw_circle(head + Vector2(1, 0), 2.0, Color(0.9, 0.7, 0.2))


# ------------------------------------------------------------------ zona de energia (esquerda)

func _draw_energy_zone(font: Font, x0: float, x1: float, gy: float, h: float, sun: float) -> void:
	var zw := x1 - x0
	if zw < 60:
		return
	# Torres solares verticais: fileira no horizonte
	var vs_slots := 6
	var vs_step := zw / vs_slots
	_draw_kind_row("vsat", vs_slots, func(i): return Rect2(x0 + i * vs_step + vs_step * 0.3, gy - 58, 10, 58), font)

	# Painéis solares: grade 4 x 3 no chão
	var cols := 4
	var cw := zw / cols
	_draw_kind_row("solar", 12, func(i): return Rect2(x0 + (i % cols) * cw + 2, gy + 10 + (i / cols) * 24, cw - 6, 18), font)

	# Armazenamento: baterias, células e reservatórios térmicos
	var sy := h - 34.0
	var bw := zw / 11.0
	_draw_kind_row("battery", 6, func(i): return Rect2(x0 + i * bw + 2, sy, bw - 5, 26), font)
	_draw_kind_row("rfc", 3, func(i): return Rect2(x0 + 6 * bw + i * bw + 1, sy - 2, bw - 3, 28), font)
	_draw_kind_row("wadi", 2, func(i): return Rect2(x0 + 9 * bw + i * bw + 1, sy + 8, bw - 3, 18), font)
	_label(font, Vector2(x0, sy - 6), "Armazenamento: %.0f/%.0f kWh" % [state.energy, state.storage_capacity()], 10)


# ------------------------------------------------------------------ zona direita

func _draw_right_zone(font: Font, x0: float, x1: float, gy: float, h: float, peak: Vector2) -> void:
	var zw := x1 - x0
	if zw < 60:
		return
	# Linha até a crista: cabo da cúpula até o pico
	var cables: int = state.count("ridge_cable")
	for i in cables:
		var start := Vector2(x0 - 10, gy - 4 - i * 4)
		draw_line(start, peak + Vector2(-6 + i * 10, 4), Color(0.95, 0.75, 0.3, 0.9), 2.0)
		for k in 3:
			draw_rect(Rect2(peak.x - 18 + k * 12 + i * 4, peak.y - 10 - i * 6, 9, 6), Color(0.2, 0.35, 0.75))
	if cables > 0:
		_hit(Rect2(peak.x - 30, peak.y - 20, 60, 30), "b:ridge_cable")
	var qcable := _queue_indices("ridge_cable")
	if not qcable.is_empty():
		_scaffold(font, Rect2(peak.x - 26, peak.y - 34, 52, 26), qcable[0])

	# ISRU: fileira no chão
	var step := zw / 3.0
	_draw_kind_row("isru", 3, func(i): return Rect2(x0 + i * step + 4, gy + 6, step - 14, 30), font)
	# RTGs: fileira abaixo
	_draw_kind_row("rtg", 3, func(i): return Rect2(x0 + i * step + step * 0.25, gy + 50, step * 0.4, 26), font)
	# Reator: longe, perto da borda
	_draw_kind_row("reactor", 1, func(i): return Rect2(x1 - 46, h - 44, 34, 36), font)


# ------------------------------------------------------------------ helpers de construções

## Desenha as unidades construídas de um tipo, depois as obras em andamento, e
## deixa contornos vagos para o resto (até o limite).
func _draw_kind_row(kind: String, slots: int, rect_of: Callable, font: Font) -> void:
	var built: int = state.count(kind)
	var qi: Array = _queue_indices(kind)
	for i in slots:
		var r: Rect2 = rect_of.call(i)
		if i < built:
			_draw_building(kind, r)
			_hit(r.grow(3), "b:" + kind)
		elif i - built < qi.size():
			_scaffold(font, r, qi[i - built])


func _queue_indices(kind: String) -> Array:
	var out: Array = []
	for i in state.queue.size():
		if state.queue[i]["kind"] == kind:
			out.append(i)
	return out


func _scaffold(font: Font, r: Rect2, qidx: int) -> void:
	var q: Dictionary = state.queue[qidx]
	var prog: float = 1.0 - q["work_left"] / q["work_total"]
	var col := Color(1.0, 0.6, 0.2, 0.9)
	draw_rect(r, Color(1.0, 0.6, 0.2, 0.08))
	draw_rect(r, col, false, 1.5)
	draw_line(r.position, r.end, Color(1.0, 0.6, 0.2, 0.5), 1.0)
	draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), Color(1.0, 0.6, 0.2, 0.5), 1.0)
	draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x * prog, 3), Color(0.3, 1.0, 0.4))
	_label(font, Vector2(r.position.x, r.position.y - 2), "%d%%" % int(prog * 100), 9, Color(1, 0.75, 0.4))
	_hit(r.grow(3), "q:%d" % qidx)
	_last_scaffold[qidx] = r


func _draw_building(kind: String, r: Rect2) -> void:
	var sun: float = state.sun_factor()
	match kind:
		"solar":
			var poly := PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.position.x + 4, r.position.y), Vector2(r.end.x, r.position.y), Vector2(r.end.x - 4, r.end.y)])
			draw_colored_polygon(poly, Color(0.15, 0.25, 0.55).lightened(0.25 * sun))
			draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color(0.5, 0.6, 0.8, 0.6), 1.0)
		"vsat":
			draw_line(Vector2(r.get_center().x, r.end.y), Vector2(r.get_center().x, r.position.y), Color(0.7, 0.7, 0.72), 2.0)
			var face := 0.5 + 0.5 * sin(_t * 0.3)
			draw_rect(Rect2(r.position.x - 3, r.position.y, r.size.x + 6 * face, r.size.y * 0.55), Color(0.2, 0.35, 0.75).lightened(0.25 * sun))
		"battery":
			var cap: float = state.storage_capacity()
			var frac: float = state.energy / cap if cap > 0 else 0.0
			draw_rect(r, Color(0.25, 0.25, 0.28))
			var inner := r.grow(-2)
			draw_rect(Rect2(inner.position.x, inner.end.y - inner.size.y * frac, inner.size.x, inner.size.y * frac), Color(0.25, 0.8, 0.4) if frac > 0.25 else Color(0.9, 0.3, 0.25))
		"rfc":
			var c := r.get_center()
			draw_circle(c + Vector2(0, -r.size.y * 0.2), r.size.x * 0.4, Color(0.85, 0.85, 0.9))
			draw_circle(c + Vector2(0, r.size.y * 0.25), r.size.x * 0.32, Color(0.6, 0.75, 0.95))
			draw_string(get_theme_default_font(), c + Vector2(-5, -r.size.y * 0.15), "H2", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.2, 0.2, 0.3))
		"wadi":
			var warm := 0.4 + 0.3 * sin(_t * 1.5)
			draw_rect(r, Color(0.55, 0.42, 0.35))
			draw_rect(r.grow(-3), Color(1.0, 0.45, 0.2, warm * (1.0 if sun < 1.0 else 0.35)))
		"isru":
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.35, r.size.x, r.size.y * 0.65), Color(0.7, 0.55, 0.25))
			var mx := r.position.x + r.size.x * 0.5
			draw_line(Vector2(mx, r.position.y + r.size.y * 0.35), Vector2(mx, r.position.y - 6), Color(0.75, 0.75, 0.75), 3.0)
			var ang = _t * 3.0 * state.alloc["isru"]
			draw_line(Vector2(mx, r.position.y - 6), Vector2(mx + 8 * cos(ang), r.position.y - 6 + 8 * sin(ang)), Color(0.95, 0.95, 0.95), 2.0)
		"rtg":
			draw_rect(Rect2(r.position.x + r.size.x * 0.3, r.position.y, r.size.x * 0.4, r.size.y), Color(0.5, 0.5, 0.55))
			for k in 4:
				var fy := r.position.y + 3 + k * r.size.y / 4.0
				draw_line(Vector2(r.position.x, fy), Vector2(r.end.x, fy), Color(0.8, 0.35, 0.2), 2.0)
		"reactor":
			var on: bool = not state.modifiers.has("reactor_off")
			draw_rect(Rect2(r.position.x + r.size.x * 0.3, r.position.y, r.size.x * 0.4, r.size.y), Color(0.55, 0.57, 0.6))
			for k in 4:
				var fy := r.position.y + 5 + k * r.size.y / 4.5
				draw_line(Vector2(r.position.x - 6, fy), Vector2(r.end.x + 6, fy), Color(0.75, 0.3, 0.2) if on else Color(0.35, 0.35, 0.4), 2.0)
			draw_circle(Vector2(r.get_center().x, r.position.y + 6), 3, Color(0.3, 1.0, 0.4) if on else Color(1, 0.2, 0.2))


func _semi(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 48
	for i in n + 1:
		var a := PI + PI * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


func _dashed_rect(r: Rect2, col: Color) -> void:
	var seg := 5.0
	var edges := [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]
	for e in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var L = a.distance_to(b)
		var d = (b - a).normalized()
		var t := 0.0
		while t < L:
			draw_line(a + d * t, a + d * minf(t + seg, L), col, 1.0)
			t += seg * 2.0


func _label(font: Font, pos: Vector2, text: String, fs: int = 12, col: Color = C_TEXT) -> void:
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
