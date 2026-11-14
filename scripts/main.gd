extends Control
## Interface do jogo: menu, painel de comando, diálogo de eventos e tela final.
## Toda a UI é construída por código para manter a cena simples.

const GS := preload("res://scripts/game_state.gd")
const BaseView := preload("res://scripts/base_view.gd")

const C_BG := Color("0d1117")
const C_PANEL := Color("161b22")
const C_PANEL2 := Color("1c2330")
const C_BORDER := Color("30363d")
const C_TEXT := Color("e6edf3")
const C_MUTED := Color("8b949e")
const C_GOOD := Color("3fb950")
const C_WARN := Color("d29922")
const C_BAD := Color("f85149")
const C_ACCENT := Color("58a6ff")

var state: GS
var screen: Control
var overlay: Control

var stat_value := {}
var stat_delta := {}
var sliders := {}
var slider_value := {}
var slider_kwh := {}
var spinboxes := {}
var build_buttons := {}
var crew_box: VBoxContainer
var log_label: RichTextLabel
var forecast_label: RichTextLabel
var power_label: Label
var battery_bar: ProgressBar
var battery_label: Label
var free_label: Label
var day_label: Label
var advance_btn: Button
var base_view: Control
var _refreshing := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	show_menu()
	# Atalho de desenvolvimento: godot --path . -- --autostart=moon --days=18
	var days := 0
	var auto := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autostart="):
			auto = a.get_slice("=", 1)
		elif a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	if auto in GS.LOCATIONS:
		start_game(auto)
		for i in days:
			var ev := state.advance_day()
			if state.game_over:
				show_end()
				return
			if not ev.is_empty():
				if i == days - 1:
					refresh()
					show_event(ev)
					return
				state.apply_choice(ev, 0)
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if advance_btn and is_instance_valid(advance_btn) and overlay == null and state and not state.game_over:
			_on_advance()


# ================================================================== utilidades de UI

func _clear_screen() -> void:
	if screen:
		screen.queue_free()
	if overlay:
		overlay.queue_free()
		overlay = null
	screen = null


func _panel(col: Color = C_PANEL, pad: int = 10) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = C_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(pad)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _label(text: String, size: int = 14, col: Color = C_TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _rich(min_h: int = 0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = min_h == 0
	r.custom_minimum_size = Vector2(0, min_h)
	r.add_theme_color_override("default_color", C_TEXT)
	r.add_theme_font_size_override("normal_font_size", 13)
	r.add_theme_font_size_override("bold_font_size", 13)
	return r


func _button(text: String, size: int = 14) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	return b


func _margin(child: Control, m: int) -> MarginContainer:
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, m)
	mc.add_child(child)
	return mc


func _pct_color(v: float) -> Color:
	if v >= 60.0:
		return C_GOOD
	if v >= 30.0:
		return C_WARN
	return C_BAD


func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


# ================================================================== menu

func show_menu() -> void:
	_clear_screen()
	var root := ScrollContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(root)
	screen = root

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(980, 0)
	v.add_theme_constant_override("separation", 14)
	center.add_child(_margin(v, 24))

	v.add_child(_label("POSTO AVANÇADO", 42, C_ACCENT))
	v.add_child(_label("Você comanda uma base com 4 tripulantes. Ar, água, comida, energia e radiação estão todos ligados: cada decisão resolve um problema e cria outro. Leve a tripulação viva até o fim da missão e cumpra a meta científica.", 16, C_TEXT, true))

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	v.add_child(cards)
	cards.add_child(_location_card("moon", [
		"60 dias na borda da cratera Shackleton",
		"Radiação alta: 1,35 mSv/dia (sem atmosfera)",
		"Sol forte, mas 5 dias de escuridão a cada ~29 dias",
		"Cargas da Terra nos dias 20 e 40",
		"Água: só com ISRU (gelo) ou reabastecimento",
	]))
	cards.add_child(_location_card("mars", [
		"80 sóis na cratera Jezero",
		"Radiação menor: 0,65 mSv/sol",
		"Sol fraco, poeira nos painéis e tempestades",
		"Começa com reator e ISRU de oxigênio",
		"Sem reabastecimento. Conjunção solar no sol 45",
	]))

	var how := _panel(C_PANEL)
	var hv := VBoxContainer.new()
	how.add_child(hv)
	hv.add_child(_label("Como jogar", 18, C_ACCENT))
	var r := _rich()
	r.text = """• [b]Energia:[/b] use os controles deslizantes para distribuir energia entre os sistemas. Se a demanda passar de geração + bateria, há apagão e TODOS os sistemas perdem força.
• [b]Tripulação:[/b] distribua as 4 pessoas entre manutenção, agricultura, ciência, EVA e descanso.
• [b]Construção:[/b] gaste peças para expandir a base (1 obra por dia).
• [b]Previsão:[/b] antes de avançar, confira o saldo previsto e os alertas. Passe o mouse sobre os controles para ver explicações.
• [b]Eventos:[/b] tempestades solares, falhas e descobertas exigem decisões. Cada uma traz um fato real.
• Atalho: [b]Espaço[/b] avança o dia."""
	hv.add_child(r)
	v.add_child(how)


func _location_card(id: String, bullets: Array) -> Control:
	var L: Dictionary = GS.LOCATIONS[id]
	var p := _panel(C_PANEL, 16)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_label(L["short"].to_upper(), 26, C_WARN if id == "mars" else C_TEXT))
	v.add_child(_label(L["name"], 13, C_MUTED, true))
	for b in bullets:
		v.add_child(_label("• " + b, 14, C_TEXT, true))
	var btn := _button("Comandar esta missão", 16)
	btn.custom_minimum_size = Vector2(0, 40)
	btn.pressed.connect(func(): start_game(id))
	v.add_child(btn)
	return p


# ================================================================== jogo

func start_game(loc_id: String) -> void:
	state = GS.new()
	state.setup(loc_id)
	_build_game_ui()
	refresh()


func _build_game_ui() -> void:
	_clear_screen()
	stat_value.clear()
	stat_delta.clear()
	sliders.clear()
	slider_value.clear()
	slider_kwh.clear()
	spinboxes.clear()
	build_buttons.clear()

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	var m := _margin(root, 10)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(m)
	screen = m

	# --- barra superior
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	root.add_child(top)
	var dp := _panel(C_PANEL2, 8)
	dp.custom_minimum_size = Vector2(130, 0)
	day_label = _label("", 20, C_ACCENT)
	dp.add_child(day_label)
	top.add_child(dp)
	for k in [["o2", "Oxigênio"], ["water", "Água"], ["food", "Comida"], ["parts", "Peças"], ["integrity", "Integridade"], ["morale", "Moral"], ["dose", "Radiação média"], ["science", "Ciência"]]:
		var p := _panel(C_PANEL, 8)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		p.add_child(v)
		v.add_child(_label(k[1], 11, C_MUTED))
		var val := _label("", 17)
		v.add_child(val)
		var d := _label("", 11, C_MUTED)
		v.add_child(d)
		stat_value[k[0]] = val
		stat_delta[k[0]] = d
		top.add_child(p)

	# --- corpo
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)
	body.add_child(_build_power_panel())

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	body.add_child(center)
	var bvp := _panel(C_PANEL, 0)
	bvp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base_view = BaseView.new()
	base_view.state = state
	base_view.custom_minimum_size = Vector2(0, 240)
	bvp.add_child(base_view)
	center.add_child(bvp)

	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 8)
	lower.custom_minimum_size = Vector2(0, 210)
	center.add_child(lower)
	var fp := _panel(C_PANEL, 8)
	fp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fv := VBoxContainer.new()
	fp.add_child(fv)
	fv.add_child(_label("Previsão para amanhã", 14, C_ACCENT))
	forecast_label = _rich(170)
	forecast_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fv.add_child(forecast_label)
	lower.add_child(fp)
	var lp := _panel(C_PANEL, 8)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	lv.add_child(_label("Diário de bordo", 14, C_ACCENT))
	log_label = _rich(170)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	lv.add_child(log_label)
	lower.add_child(lp)

	body.add_child(_build_crew_panel())

	# --- rodapé
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	var menu_btn := _button("Abandonar missão")
	menu_btn.pressed.connect(show_menu)
	bottom.add_child(menu_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	advance_btn = _button("Avançar dia  ▶", 18)
	advance_btn.custom_minimum_size = Vector2(260, 44)
	advance_btn.pressed.connect(_on_advance)
	bottom.add_child(advance_btn)


func _build_power_panel() -> Control:
	var p := _panel(C_PANEL, 10)
	p.custom_minimum_size = Vector2(300, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)
	v.add_child(_label("Energia", 17, C_ACCENT))
	power_label = _label("", 12, C_TEXT, true)
	v.add_child(power_label)
	battery_label = _label("", 12, C_MUTED)
	v.add_child(battery_label)
	battery_bar = ProgressBar.new()
	battery_bar.show_percentage = false
	battery_bar.custom_minimum_size = Vector2(0, 12)
	var bfill := StyleBoxFlat.new()
	bfill.bg_color = C_GOOD
	bfill.set_corner_radius_all(3)
	battery_bar.add_theme_stylebox_override("fill", bfill)
	v.add_child(battery_bar)
	v.add_child(HSeparator.new())
	for s in GS.SYSTEMS:
		var row := HBoxContainer.new()
		var nl := _label(GS.SYSTEM_NAMES[s], 13)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.tooltip_text = GS.SYSTEM_HELP[s]
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(nl)
		var val := _label("", 13, C_ACCENT)
		row.add_child(val)
		v.add_child(row)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.5
		sl.step = 0.05
		sl.tooltip_text = GS.SYSTEM_HELP[s]
		sl.value_changed.connect(func(x): _on_slider(s, x))
		v.add_child(sl)
		var kwh := _label("", 11, C_MUTED)
		v.add_child(kwh)
		sliders[s] = sl
		slider_value[s] = val
		slider_kwh[s] = kwh
	return p


func _build_crew_panel() -> Control:
	var p := _panel(C_PANEL, 10)
	p.custom_minimum_size = Vector2(320, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)

	v.add_child(_label("Tarefas da tripulação", 17, C_ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	v.add_child(grid)
	for t in GS.TASKS:
		var l := _label(GS.TASK_NAMES[t], 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.tooltip_text = GS.TASK_HELP[t]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(l)
		var sb := SpinBox.new()
		sb.min_value = 0
		sb.max_value = 4
		sb.step = 1
		sb.tooltip_text = GS.TASK_HELP[t]
		sb.value_changed.connect(func(x): _on_task(t, x))
		grid.add_child(sb)
		spinboxes[t] = sb
	free_label = _label("", 12, C_MUTED)
	v.add_child(free_label)

	v.add_child(HSeparator.new())
	v.add_child(_label("Tripulantes", 15, C_ACCENT))
	crew_box = VBoxContainer.new()
	crew_box.add_theme_constant_override("separation", 4)
	v.add_child(crew_box)

	v.add_child(HSeparator.new())
	v.add_child(_label("Construir (1 por dia)", 15, C_ACCENT))
	var bgrid := GridContainer.new()
	bgrid.columns = 2
	v.add_child(bgrid)
	var help := {
		"solar": "Gera energia apenas com sol. Lua: 30 kWh/dia. Marte: 14 kWh/sol, menos com poeira.",
		"battery": "+150 kWh de armazenamento. Essencial para atravessar escuridão e tempestades.",
		"reactor": "+120 kWh/dia constantes, com ou sem sol. Caro, mas muda o jogo.",
		"greenhouse": "+1 módulo: até 1,5 rações/dia com luz plena e agricultor. Demanda 35 kWh.",
		"isru": "Lua: +8 L água e +1 kg O2 por dia. Marte: +1,5 kg O2 e +4 L água. Demanda 30 kWh.",
		"water_wall": "Usa 300 L de água como escudo no abrigo: reduz a dose de tempestades solares para 6%.",
	}
	for k in GS.BUILD_ORDER:
		var b := _button("%s (%d)" % [GS.BUILD_NAMES[k], GS.BUILD_COSTS[k]], 12)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = help[k]
		b.pressed.connect(func(): _on_build(k))
		bgrid.add_child(b)
		build_buttons[k] = b
	return p


# ================================================================== callbacks

func _on_slider(s: String, x: float) -> void:
	if _refreshing:
		return
	state.alloc[s] = x
	refresh()


func _on_task(t: String, x: float) -> void:
	if _refreshing:
		return
	var applied := state.set_task(t, int(x))
	if applied != int(x):
		spinboxes[t].set_value_no_signal(applied)
	refresh()


func _on_build(k: String) -> void:
	if state.build(k):
		refresh()


func _on_advance() -> void:
	if state.game_over or overlay != null:
		return
	var ev := state.advance_day()
	if state.game_over:
		show_end()
		return
	refresh()
	if not ev.is_empty():
		show_event(ev)


# ================================================================== atualização

func refresh() -> void:
	if state == null or screen == null:
		return
	_refreshing = true
	var f := state.compute_flows()
	var alive := state.alive_count()
	day_label.text = "%s %d/%d" % [state.day_word(), state.day, state.mission_length()]
	var dd := state.days_until_dark()
	day_label.tooltip_text = state.period_name()
	if dd > 0:
		day_label.tooltip_text += "\nEscuridão em %d dia(s)" % dd

	_set_stat("o2", "%.0f kg" % state.o2, f["o2_delta"], state.o2)
	_set_stat("water", "%.0f L" % state.water, f["water_delta"], state.water)
	_set_stat("food", "%.0f rações" % state.food, f["food_delta"], state.food)
	_set_plain("parts", "%d" % state.parts, "", C_TEXT)
	_set_plain("integrity", "%.0f%%" % state.integrity, "%+.1f/dia" % f["integrity_delta"], _pct_color(state.integrity))
	_set_plain("morale", "%.0f%%" % state.morale, "%+.1f/dia" % f["morale_delta"], _pct_color(state.morale))
	var dcol := C_GOOD if state.avg_dose() < 150 else (C_WARN if state.avg_dose() < GS.DOSE_LIMIT else C_BAD)
	_set_plain("dose", "%.0f mSv" % state.avg_dose(), "+%.2f/dia  limite %d" % [f["dose_hab"], int(GS.DOSE_LIMIT)], dcol)
	var target: float = state.loc()["science_target"]
	_set_plain("science", "%.0f/%d" % [state.science, int(target)], "+%.1f/dia" % f["science_delta"], C_GOOD if state.science >= target else C_TEXT)

	# energia
	var gen_txt := "Geração: %.0f kWh" % f["gen"]
	var parts_txt: Array = []
	if state.buildings["solar"] > 0:
		parts_txt.append("solar %.0f" % f["solar"])
	if state.buildings["reactor"] > 0:
		parts_txt.append("reator %.0f" % f["reactor"])
	if not parts_txt.is_empty():
		gen_txt += " (" + ", ".join(parts_txt) + ")"
	var bal: float = f["gen"] - f["total_demand"]
	power_label.text = "%s\nDemanda: %.0f kWh   Saldo: %+.0f kWh" % [gen_txt, f["total_demand"], bal]
	power_label.add_theme_color_override("font_color", C_BAD if f["pf"] < 0.999 else (C_WARN if bal < 0 else C_TEXT))
	var cap := state.battery_capacity()
	battery_bar.max_value = maxf(cap, 1.0)
	battery_bar.value = state.battery
	var bsb: StyleBoxFlat = battery_bar.get_theme_stylebox("fill")
	bsb.bg_color = _pct_color(100.0 * state.battery / maxf(cap, 1.0))
	battery_label.text = "Bateria: %.0f / %.0f kWh  (amanhã %.0f)" % [state.battery, cap, f["battery_next"]]
	if state.location == "mars":
		battery_label.text += "\nPainéis limpos: %d%%" % int(state.dust * 100)
	var demand: Dictionary = f["demand"]
	for s in GS.SYSTEMS:
		sliders[s].set_value_no_signal(state.alloc[s])
		slider_value[s].text = "%d%%" % int(round(state.alloc[s] * 100))
		var disabled: bool = (s == "isru" and state.buildings["isru"] == 0) or (s == "greenhouse" and state.buildings["greenhouse"] == 0)
		sliders[s].editable = not disabled
		slider_kwh[s].text = "não instalado" if disabled else "%.0f kWh/dia" % demand[s]

	# tarefas
	for t in GS.TASKS:
		spinboxes[t].max_value = alive
		spinboxes[t].set_value_no_signal(state.tasks[t])
	var free := alive - state.assigned_count()
	free_label.text = "Livres: %d de %d tripulantes" % [free, alive]
	free_label.add_theme_color_override("font_color", C_WARN if free > 0 else C_MUTED)

	# tripulantes
	for c in crew_box.get_children():
		c.queue_free()
	for c in state.crew:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		var head := "%s  (%s)" % [c["name"], c["role"]]
		if not c["alive"]:
			row.add_child(_label(head + "  falecido(a)", 12, C_BAD))
		else:
			row.add_child(_label(head, 12))
			var h := HBoxContainer.new()
			var pb := ProgressBar.new()
			pb.max_value = 100
			pb.value = c["health"]
			pb.show_percentage = false
			pb.custom_minimum_size = Vector2(0, 8)
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var fill := StyleBoxFlat.new()
			fill.bg_color = _pct_color(c["health"])
			pb.add_theme_stylebox_override("fill", fill)
			h.add_child(pb)
			h.add_child(_label(" %d%%  %d mSv" % [int(c["health"]), int(c["dose"])], 11, C_BAD if c["dose"] > GS.DOSE_LIMIT else C_MUTED))
			row.add_child(h)
		crew_box.add_child(row)

	# construções
	for k in GS.BUILD_ORDER:
		var why := state.can_build(k)
		build_buttons[k].disabled = why != ""
		build_buttons[k].text = "%s (%d) [%d]" % [GS.BUILD_NAMES[k], GS.BUILD_COSTS[k], state.buildings.get(k, 0)]

	# previsão
	forecast_label.text = _forecast_text(f)

	# diário
	log_label.text = "\n".join(state.log_lines.slice(maxi(0, state.log_lines.size() - 60)))
	_refreshing = false


func _set_stat(key: String, text: String, delta: float, stock: float) -> void:
	var col := C_TEXT
	var dtxt := "%+.1f/dia" % delta
	if delta < -0.01:
		var days := stock / -delta
		dtxt += "  (%d dias)" % int(days)
		col = C_BAD if days < 7 else (C_WARN if days < 20 else C_TEXT)
	if stock <= 0.0:
		col = C_BAD
	stat_value[key].text = text
	stat_value[key].add_theme_color_override("font_color", col)
	stat_delta[key].text = dtxt
	stat_delta[key].add_theme_color_override("font_color", C_GOOD if delta >= 0 else C_WARN)


func _set_plain(key: String, text: String, sub: String, col: Color) -> void:
	stat_value[key].text = text
	stat_value[key].add_theme_color_override("font_color", col)
	stat_delta[key].text = sub


func _forecast_text(f: Dictionary) -> String:
	var lines: Array = []
	var warn: Array = f["warnings"]
	for w in warn:
		lines.append("[color=%s]▲ %s[/color]" % [_hex(C_BAD if w.begins_with("APAGÃO") or w.begins_with("CO2") else C_WARN), w])
	if state.work_block == "shelter":
		lines.append("[color=%s]Amanhã a tripulação fica no abrigo: nenhuma tarefa será executada.[/color]" % _hex(C_WARN))
	elif state.work_block == "day_off":
		lines.append("[color=%s]Amanhã é dia de folga: ninguém trabalha.[/color]" % _hex(C_ACCENT))
	var bdelta: float = f["battery_delta"]
	if bdelta < -0.5 and f["pf"] >= 0.999:
		var bdays := state.battery / -bdelta
		var bcol := C_BAD if bdays < 2.0 else C_WARN
		lines.append("[color=%s]▲ Bateria descarregando: dura ~%.1f dia(s) neste ritmo[/color]" % [_hex(bcol), bdays])
	var dd := state.days_until_dark()
	if dd > 0 and dd <= 5:
		lines.append("[color=%s]Escuridão lunar em %d dia(s): bateria precisa estar cheia.[/color]" % [_hex(C_WARN), dd])
	for m in state.modifiers:
		var names := {"dust_storm": "Tempestade de poeira", "recycler_fail": "Reciclador de água degradado", "blight": "Fungo na estufa", "reactor_off": "Reator desligado", "conjunction": "Conjunção solar (sem comunicação)"}
		lines.append("[color=%s]● %s: %d dia(s)[/color]" % [_hex(C_WARN), names.get(m, m), state.modifiers[m]])
	if state.o2 + f["o2_delta"] < 0 or state.water + f["water_delta"] < 0 or state.food + f["food_delta"] < 0:
		lines.append("[color=%s][b]Algum estoque vai ZERAR amanhã![/b][/color]" % _hex(C_BAD))
	lines.append("O2 %+.1f kg  |  Água %+.1f L  |  Comida %+.1f  |  Bateria %+.0f kWh" % [f["o2_delta"], f["water_delta"], f["food_delta"], f["battery_delta"]])
	lines.append("Plantas %+.0f%%  |  Blindagem %d camada(s) (%.1f)  |  Dose %.2f mSv/dia" % [f["crop_delta"] if state.buildings["greenhouse"] > 0 else 0.0, int(state.shield_layers), state.shield_layers, f["dose_hab"]])
	if warn.is_empty() and state.work_block == "" and bdelta >= -0.5:
		lines.append("[color=%s]Todos os sistemas nominais.[/color]" % _hex(C_GOOD))
	return "\n".join(lines)


# ================================================================== evento

func show_event(ev: Dictionary) -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var p := _panel(C_PANEL2, 20)
	p.custom_minimum_size = Vector2(640, 0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(_label("%s %d" % [state.day_word(), state.day], 12, C_MUTED))
	v.add_child(_label(ev["title"], 22, C_ACCENT, true))
	var t := _rich()
	t.add_theme_font_size_override("normal_font_size", 15)
	t.add_theme_font_size_override("bold_font_size", 15)
	t.text = ev["text"]
	v.add_child(t)
	var fact := _panel(Color("10261a"), 10)
	var fl := _rich()
	fl.text = "[color=#3fb950][b]Fato real[/b][/color]\n[i]%s[/i]" % ev["fact"]
	fact.add_child(fl)
	v.add_child(fact)
	for i in ev["choices"].size():
		var ch: Dictionary = ev["choices"][i]
		var b := _button(ch["label"], 15)
		b.custom_minimum_size = Vector2(0, 38)
		var why := state.choice_blocked(ch)
		if why != "":
			b.disabled = true
			b.text += "  (%s)" % why
		var idx: int = i
		b.pressed.connect(func(): _on_choice(ev, idx))
		v.add_child(b)
		if String(ch.get("desc")) != "":
			v.add_child(_label("    " + ch["desc"], 12, C_MUTED, true))


func _on_choice(ev: Dictionary, idx: int) -> void:
	state.apply_choice(ev, idx)
	overlay.queue_free()
	overlay = null
	if state.game_over:
		show_end()
	else:
		refresh()


# ================================================================== fim

func show_end() -> void:
	var s := state
	_clear_screen()
	var root := ScrollContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(root)
	screen = root
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(860, 0)
	v.add_theme_constant_override("separation", 12)
	cc.add_child(_margin(v, 24))

	var g := s.grade()
	v.add_child(_label("MISSÃO CONCLUÍDA" if s.victory else "MISSÃO FRACASSADA", 36, C_GOOD if s.victory else C_BAD))
	v.add_child(_label(s.end_reason, 16, C_TEXT, true))
	v.add_child(_label("Nota: %s  (%d pontos)" % [g["letter"], int(g["score"])], 26, C_ACCENT))

	var sp := _panel()
	var st := _rich()
	var target: float = s.loc()["science_target"]
	st.text = "[b]%s:[/b] %d de %d   [b]Sobreviventes:[/b] %d/4   [b]Ciência:[/b] %.0f/%d\n[b]Dose média:[/b] %.0f mSv   [b]Moral final:[/b] %.0f%%   [b]Construções:[/b] %d   [b]Dias de apagão:[/b] %d" % [
		s.day_word() + "s", mini(s.day - 1, s.mission_length()), s.mission_length(), s.alive_count(), s.science, int(target),
		s.avg_dose(), s.morale, s.stats["builds"], s.stats["brownout_days"]]
	sp.add_child(st)
	v.add_child(sp)

	v.add_child(_label("Lições da missão", 20, C_ACCENT))
	for l in s.lessons():
		v.add_child(_label("• " + l, 14, C_TEXT, true))

	if not s.decisions.is_empty():
		v.add_child(_label("Suas decisões", 20, C_ACCENT))
		var dp := _panel()
		var dl := _rich()
		dl.text = "\n".join(s.decisions)
		dp.add_child(dl)
		v.add_child(dp)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var again := _button("Repetir esta missão", 16)
	var loc_id := s.location
	again.pressed.connect(func(): start_game(loc_id))
	h.add_child(again)
	var menu := _button("Menu principal", 16)
	menu.pressed.connect(show_menu)
	h.add_child(menu)
	v.add_child(h)
