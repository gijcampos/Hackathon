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
const C_ENERGY := Color("f2cc60")

var state: GS
var screen: Control
var overlay: Control

var stat_panel := {}
var stat_value := {}
var stat_delta := {}
var sliders := {}
var slider_value := {}
var slider_kwh := {}
var slider_name := {}
var spinboxes := {}
var build_buttons := {}
var gen_box: VBoxContainer
var queue_box: VBoxContainer
var crew_box: VBoxContainer
var log_label: RichTextLabel
var forecast_label: RichTextLabel
var balance_label: Label
var storage_bar: ProgressBar
var storage_label: Label
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
	_setup_tooltip_theme()
	show_menu()
	# Atalho de desenvolvimento: godot --path . -- --autostart --days=18
	var days := 0
	var auto := false
	for a in OS.get_cmdline_user_args():
		if a == "--autostart":
			auto = true
		elif a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	if auto:
		start_game()
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


func _setup_tooltip_theme() -> void:
	var th := Theme.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("0b1220")
	sb.border_color = C_ACCENT
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	th.set_stylebox("panel", "TooltipPanel", sb)
	th.set_color("font_color", "TooltipLabel", C_TEXT)
	th.set_font_size("font_size", "TooltipLabel", 13)
	theme = th


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


func _bar(col: Color, h: int = 10) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, h)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(3)
	pb.add_theme_stylebox_override("fill", fill)
	return pb


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
	v.add_child(_label("Você comanda uma base com 4 tripulantes na borda da cratera Shackleton, no polo sul da Lua. A base começa pequena: uma cúpula, 4 painéis solares e uma bateria. Construa ao longo de 60 dias o que for preciso para manter ar, água, comida, calor e proteção contra radiação funcionando, e principalmente para atravessar a escuridão lunar.", 16, C_TEXT, true))

	var how := _panel(C_PANEL)
	var hv := VBoxContainer.new()
	how.add_child(hv)
	hv.add_child(_label("Como jogar", 18, C_ACCENT))
	var r := _rich()
	r.text = """• [b]Energia (kWh):[/b] tudo na base depende dela. Painéis só geram com sol; a cada ~29 dias há 5 dias de escuridão. Guarde energia ou construa fontes que funcionem no escuro.
• [b]Sistemas:[/b] regule quanto cada sistema recebe. Se a demanda passar de geração + energia armazenada, há apagão e TODOS os sistemas perdem força.
• [b]Construção:[/b] escolha uma obra (gasta peças) e coloque tripulantes na tarefa Construção para ela avançar.
• [b]Passe o mouse[/b] sobre qualquer sistema, construção ou parte da base para ver quantos kWh ela gera, guarda ou consome.
• Atalho: [b]Espaço[/b] avança o dia."""
	hv.add_child(r)
	v.add_child(how)

	var btn := _button("Iniciar missão", 18)
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(start_game)
	v.add_child(btn)


# ================================================================== jogo

func start_game() -> void:
	state = GS.new()
	state.setup()
	_build_game_ui()
	refresh()


func _build_game_ui() -> void:
	_clear_screen()
	for d in [stat_panel, stat_value, stat_delta, sliders, slider_value, slider_kwh, slider_name, spinboxes, build_buttons]:
		d.clear()

	var root := VBoxContainer.new()
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
	day_label.mouse_filter = Control.MOUSE_FILTER_PASS
	dp.add_child(day_label)
	top.add_child(dp)
	for k in [["energy", "Energia"], ["o2", "Oxigênio"], ["water", "Água"], ["food", "Comida"], ["parts", "Peças"], ["integrity", "Integridade"], ["dose", "Radiação média"], ["crew", "Tripulação"]]:
		var p := _panel(C_PANEL, 8)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if k[0] == "energy":
			p.size_flags_stretch_ratio = 1.5
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(v)
		var t := _label(k[1], 11, C_ENERGY if k[0] == "energy" else C_MUTED)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(t)
		var val := _label("", 17)
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(val)
		var d := _label("", 11, C_MUTED)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(d)
		stat_panel[k[0]] = p
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
	base_view.custom_minimum_size = Vector2(0, 380)
	bvp.add_child(base_view)
	center.add_child(bvp)

	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 8)
	lower.custom_minimum_size = Vector2(0, 170)
	center.add_child(lower)
	var fp := _panel(C_PANEL, 8)
	fp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fv := VBoxContainer.new()
	fp.add_child(fv)
	fv.add_child(_label("Previsão para amanhã", 14, C_ACCENT))
	forecast_label = _rich(130)
	forecast_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fv.add_child(forecast_label)
	lower.add_child(fp)
	var lp := _panel(C_PANEL, 8)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	lv.add_child(_label("Diário de bordo", 14, C_ACCENT))
	log_label = _rich(130)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	lv.add_child(log_label)
	lower.add_child(lp)

	body.add_child(_build_right_panel())

	# --- rodapé
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	var menu_btn := _button("Abandonar missão")
	menu_btn.pressed.connect(show_menu)
	bottom.add_child(menu_btn)
	bottom.add_child(_label("   Passe o mouse sobre qualquer item para ver os valores em kWh.", 12, C_MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	advance_btn = _button("Avançar dia  ▶", 18)
	advance_btn.custom_minimum_size = Vector2(260, 44)
	advance_btn.pressed.connect(_on_advance)
	bottom.add_child(advance_btn)


func _build_power_panel() -> Control:
	var p := _panel(C_PANEL, 10)
	p.custom_minimum_size = Vector2(310, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 5)
	scroll.add_child(v)

	v.add_child(_label("Energia", 17, C_ENERGY))
	balance_label = _label("", 13, C_TEXT, true)
	v.add_child(balance_label)
	storage_label = _label("", 12, C_MUTED)
	v.add_child(storage_label)
	storage_bar = _bar(C_ENERGY, 12)
	v.add_child(storage_bar)

	v.add_child(_label("Geração hoje", 13, C_MUTED))
	gen_box = VBoxContainer.new()
	gen_box.add_theme_constant_override("separation", 1)
	v.add_child(gen_box)

	v.add_child(HSeparator.new())
	v.add_child(_label("Consumo dos sistemas", 13, C_MUTED))
	for s in GS.SYSTEMS:
		var row := HBoxContainer.new()
		var nl := _label(GS.SYSTEM_NAMES[s], 13)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(nl)
		var val := _label("", 13, C_ACCENT)
		row.add_child(val)
		v.add_child(row)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.5
		sl.step = 0.05
		sl.value_changed.connect(func(x): _on_slider(s, x))
		v.add_child(sl)
		var kwh := _label("", 11, C_MUTED)
		kwh.mouse_filter = Control.MOUSE_FILTER_PASS
		v.add_child(kwh)
		sliders[s] = sl
		slider_value[s] = val
		slider_kwh[s] = kwh
		slider_name[s] = nl
	return p


func _build_right_panel() -> Control:
	var p := _panel(C_PANEL, 10)
	p.custom_minimum_size = Vector2(350, 0)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)

	v.add_child(_label("Tarefas da tripulação", 16, C_ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
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
	crew_box = VBoxContainer.new()
	crew_box.add_theme_constant_override("separation", 2)
	v.add_child(crew_box)

	v.add_child(HSeparator.new())
	v.add_child(_label("Construir", 16, C_ACCENT))
	v.add_child(_label("A obra gasta as peças na hora e avança com a tarefa Construção.", 11, C_MUTED, true))
	for cat in GS.BUILD_CATEGORIES:
		v.add_child(_label(cat[0], 12, C_ENERGY if String(cat[0]).contains("energia") else C_GOOD))
		var bgrid := GridContainer.new()
		bgrid.columns = 1
		bgrid.add_theme_constant_override("h_separation", 4)
		bgrid.add_theme_constant_override("v_separation", 4)
		v.add_child(bgrid)
		for k in cat[1]:
			var b := _button("", 12)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			b.pressed.connect(func(): _on_build(k))
			bgrid.add_child(b)
			build_buttons[k] = b

	v.add_child(HSeparator.new())
	v.add_child(_label("Fila de obras", 14, C_ACCENT))
	queue_box = VBoxContainer.new()
	queue_box.add_theme_constant_override("separation", 3)
	v.add_child(queue_box)
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
	if state.start_build(k):
		refresh()


func _on_cancel(i: int) -> void:
	state.cancel_build(i)
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
	day_label.text = "Dia %d/%d" % [state.day, state.mission_length()]
	var dd := state.days_until_dark()
	day_label.tooltip_text = "Período: %s" % state.period_name()
	if dd > 0:
		day_label.tooltip_text += "\nEscuridão começa em %d dia(s)." % dd

	# --- topo
	var cap := state.storage_capacity()
	var ed: float = f["energy_delta"]
	var ecol := C_BAD if f["pf"] < 0.999 else (C_WARN if ed < 0 else C_TEXT)
	stat_value["energy"].text = "%.0f / %.0f kWh" % [state.energy, cap]
	stat_value["energy"].add_theme_color_override("font_color", ecol)
	stat_delta["energy"].text = "gera %.0f · usa %.0f · %+.0f/dia" % [f["gen"], f["total_demand"], ed]
	stat_delta["energy"].add_theme_color_override("font_color", C_GOOD if ed >= 0 else C_WARN)
	stat_panel["energy"].tooltip_text = state.energy_tooltip()
	_set_stat("o2", "%.0f kg" % state.o2, f["o2_delta"], state.o2)
	stat_panel["o2"].tooltip_text = "OXIGÊNIO\nA tripulação respira %.1f kg/dia.\nO suporte de vida gera O2 quebrando água (eletrólise).\nMais energia no suporte de vida = mais O2 (e mais água gasta)." % (GS.O2_PER_PERSON * alive)
	_set_stat("water", "%.0f L" % state.water, f["water_delta"], state.water)
	stat_panel["water"].tooltip_text = "ÁGUA\nConsumo: %.1f L/dia. Reciclagem: %d%%.\nA eletrólise usa 1,125 L para cada kg de O2.\nISRU extrai água do gelo (8 L/dia por unidade, 30 kWh)." % [GS.WATER_PER_PERSON * alive, int(state.water_recovery() * 100)]
	_set_stat("food", "%.0f rações" % state.food, f["food_delta"], state.food)
	stat_panel["food"].tooltip_text = "COMIDA\nConsumo: %d rações/dia.\nA estufa produz %.1f/dia hoje.\nCada ração cultivada custa ~%.0f kWh de luz." % [alive, f["food_produced"], state.greenhouse_kwh_per_rack() / GS.FOOD_PER_GH]
	_set_plain("parts", "%d" % state.parts, "para construir", C_TEXT)
	stat_panel["parts"].tooltip_text = "PEÇAS SOBRESSALENTES\nUsadas nas construções. Não há reabastecimento: planeje bem o que construir."
	_set_plain("integrity", "%.0f%%" % state.integrity, "%+.1f/dia" % f["integrity_delta"], _pct_color(state.integrity))
	stat_panel["integrity"].tooltip_text = "INTEGRIDADE DA CÚPULA\nDesgaste: 0,8%/dia. Cada tripulante em Manutenção repara ~1,3%/dia.\nAbaixo de 50%: vazamento de O2 e máquinas menos eficientes. Em 0%: perda da base."
	var dcol := C_GOOD if state.avg_dose() < 150 else (C_WARN if state.avg_dose() < GS.DOSE_LIMIT else C_BAD)
	_set_plain("dose", "%.0f mSv" % state.avg_dose(), "+%.2f/dia · limite %d" % [f["dose_hab"], int(GS.DOSE_LIMIT)], dcol)
	stat_panel["dose"].tooltip_text = "RADIAÇÃO\nSuperfície lunar: 1,35 mSv/dia.\nA cúpula bloqueia %d%% (cada camada de regolito: +15%%).\nLimite da missão: %d mSv." % [int(state.shield_fraction() * 100), int(GS.DOSE_LIMIT)]
	_set_plain("crew", "%d / %d" % [alive, GS.CREW_SIZE], "produtividade %d%%" % int(state.crew_efficiency() * 100), C_TEXT if alive == GS.CREW_SIZE else C_BAD)
	stat_panel["crew"].tooltip_text = "TRIPULAÇÃO\nA produtividade cai quando a saúde média cai."

	# --- energia (painel esquerdo)
	var bal: float = f["gen"] - f["total_demand"]
	balance_label.text = "Saldo do dia: %+.0f kWh  (gera %.0f, usa %.0f)" % [bal, f["gen"], f["total_demand"]]
	balance_label.add_theme_color_override("font_color", C_BAD if f["pf"] < 0.999 else (C_WARN if bal < 0 else C_GOOD))
	storage_bar.max_value = maxf(cap, 1.0)
	storage_bar.value = state.energy
	(storage_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = _pct_color(100.0 * state.energy / maxf(cap, 1.0))
	storage_label.text = "Armazenado: %.0f / %.0f kWh · carga %d%%" % [state.energy, cap, int(state.charge_efficiency() * 100)]
	storage_label.tooltip_text = state.energy_tooltip()
	storage_label.mouse_filter = Control.MOUSE_FILTER_PASS
	for c in gen_box.get_children():
		c.queue_free()
	var gp: Dictionary = f["gen_parts"]
	for k in ["solar", "vsat", "rtg", "ridge_cable", "reactor"]:
		if state.count(k) == 0:
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.tooltip_text = state.building_tooltip(k)
		var nl := _label("%s x%d" % [GS.BUILDINGS[k]["name"], state.count(k)], 12)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(nl)
		var vl := _label("+%.0f kWh" % gp.get(k, 0.0), 12, C_ENERGY if gp.get(k, 0.0) > 0 else C_MUTED)
		vl.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(vl)
		gen_box.add_child(row)

	var demand: Dictionary = f["demand"]
	for s in GS.SYSTEMS:
		sliders[s].set_value_no_signal(state.alloc[s])
		slider_value[s].text = "%d%%" % int(round(state.alloc[s] * 100))
		var disabled: bool = (s == "isru" and state.count("isru") == 0) or (s == "greenhouse" and state.count("greenhouse") == 0)
		sliders[s].editable = not disabled
		var full := state.system_full_demand(s)
		slider_kwh[s].text = "não construído" if disabled else "usa %.0f kWh/dia  (100%% = %.0f)" % [demand[s], full]
		var tip := state.system_tooltip(s)
		sliders[s].tooltip_text = tip
		slider_kwh[s].tooltip_text = tip
		slider_name[s].tooltip_text = tip

	# --- tarefas e tripulantes
	for t in GS.TASKS:
		spinboxes[t].max_value = alive
		spinboxes[t].set_value_no_signal(state.tasks[t])
	var free := alive - state.assigned_count()
	free_label.text = "Livres: %d de %d" % [free, alive]
	free_label.add_theme_color_override("font_color", C_WARN if free > 0 else C_MUTED)
	for c in crew_box.get_children():
		c.queue_free()
	for c in state.crew:
		var h := HBoxContainer.new()
		var nl := _label(c["name"], 11, C_TEXT if c["alive"] else C_BAD)
		nl.custom_minimum_size = Vector2(76, 0)
		h.add_child(nl)
		if c["alive"]:
			var pb := _bar(_pct_color(c["health"]), 8)
			pb.max_value = 100
			pb.value = c["health"]
			h.add_child(pb)
			h.add_child(_label(" %d%% · %dmSv" % [int(c["health"]), int(c["dose"])], 11, C_BAD if c["dose"] > GS.DOSE_LIMIT else C_MUTED))
		else:
			h.add_child(_label("falecido(a)", 11, C_BAD))
		crew_box.add_child(h)

	# --- construções
	for k in build_buttons:
		var b: Button = build_buttons[k]
		var why := state.can_build(k)
		var info: Dictionary = GS.BUILDINGS[k]
		b.text = "%s   ·  %d peças  ·  tem %d" % [info["name"], int(info["cost"]), state.count(k)]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = why != ""
		var tip := state.building_tooltip(k)
		if why != "":
			tip = "INDISPONÍVEL: " + why + "\n\n" + tip
		b.tooltip_text = tip

	for c in queue_box.get_children():
		c.queue_free()
	if state.queue.is_empty():
		queue_box.add_child(_label("Nenhuma obra em andamento.", 12, C_MUTED))
	var builders: int = state.tasks["construction"]
	var ahead := 0.0
	for i in state.queue.size():
		var q: Dictionary = state.queue[i]
		ahead += q["work_left"]
		var row := HBoxContainer.new()
		row.tooltip_text = state.building_tooltip(q["kind"])
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var txt := "%s" % GS.BUILDINGS[q["kind"]]["name"]
		var nl := _label(txt, 12)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		nl.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(nl)
		var pb := _bar(Color(1.0, 0.6, 0.2), 8)
		pb.custom_minimum_size = Vector2(70, 8)
		pb.size_flags_horizontal = Control.SIZE_FILL
		pb.max_value = q["work_total"]
		pb.value = q["work_total"] - q["work_left"]
		row.add_child(pb)
		var eta := "parada" if builders == 0 else "~%dd" % ceili(ahead / builders)
		row.add_child(_label(" " + eta, 11, C_MUTED))
		var x := _button("✕", 11)
		x.tooltip_text = "Cancelar e devolver as peças"
		var idx := i
		x.pressed.connect(func(): _on_cancel(idx))
		row.add_child(x)
		queue_box.add_child(row)

	forecast_label.text = _forecast_text(f)
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
	var ed: float = f["energy_delta"]
	if ed < -0.5 and f["pf"] >= 0.999:
		var edays := state.energy / -ed
		lines.append("[color=%s]▲ Energia armazenada dura ~%.1f dia(s) neste ritmo[/color]" % [_hex(C_BAD if edays < 2.0 else C_WARN), edays])
	if f["wasted"] > 1.0:
		lines.append("[color=%s]● Armazenamento cheio: %.0f kWh serão desperdiçados[/color]" % [_hex(C_MUTED), f["wasted"]])
	if state.work_block == "shelter":
		lines.append("[color=%s]Amanhã a tripulação fica no abrigo: nenhuma tarefa será executada.[/color]" % _hex(C_WARN))
	var dd := state.days_until_dark()
	if dd > 0 and dd <= 6:
		var night_thermal := maxf(3.0, 30.0 - state.count("rtg") * 4.0 - state.count("wadi") * 10.0)
		var night_need: float = night_thermal * state.alloc["thermal"]
		for s in ["life_support", "greenhouse", "isru"]:
			night_need += state.system_full_demand(s) * state.alloc[s]
		var night_gen: float = state.count("rtg") * 12.0 + state.count("ridge_cable") * 40.0
		if not state.modifiers.has("reactor_off"):
			night_gen += state.count("reactor") * 120.0
		var short := maxf(0.0, night_need - night_gen) * 5.0
		lines.append("[color=%s]Escuridão em %d dia(s): consumo ~%.0f kWh/dia, geração sem sol %.0f. Para 5 dias faltariam ~%.0f kWh (armazenamento máx. %.0f).[/color]" % [_hex(C_WARN), dd, night_need, night_gen, short, state.storage_capacity()])
	for m in state.modifiers:
		lines.append("[color=%s]● %s: %d dia(s)[/color]" % [_hex(C_WARN), GS.MODIFIER_NAMES.get(m, m), state.modifiers[m]])
	if state.o2 + f["o2_delta"] < 0 or state.water + f["water_delta"] < 0 or state.food + f["food_delta"] < 0:
		lines.append("[color=%s][b]Algum estoque vai ZERAR amanhã![/b][/color]" % _hex(C_BAD))
	lines.append("Energia %+.0f kWh  |  O2 %+.1f kg  |  Água %+.1f L  |  Comida %+.1f" % [ed, f["o2_delta"], f["water_delta"], f["food_delta"]])
	lines.append("Obra %+.1f pessoas-dia  |  Blindagem %.2f camada(s)  |  Dose %.2f mSv/dia" % [f["build_work"], state.shield_layers, f["dose_hab"]])
	if warn.is_empty() and state.work_block == "" and ed >= -0.5:
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
	v.add_child(_label("Dia %d" % state.day, 12, C_MUTED))
	v.add_child(_label(ev["title"], 22, C_ACCENT, true))
	var t := _rich()
	t.add_theme_font_size_override("normal_font_size", 15)
	t.add_theme_font_size_override("bold_font_size", 15)
	t.text = ev["text"]
	v.add_child(t)
	if String(ev.get("fact", "")) != "":
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
		if String(ch.get("desc", "")) != "":
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
	var built := 0
	for k in s.buildings:
		built += s.count(k)
	st.text = "[b]Dias:[/b] %d de %d   [b]Sobreviventes:[/b] %d/%d   [b]Dose média:[/b] %.0f mSv   [b]Integridade:[/b] %.0f%%\n[b]Obras concluídas:[/b] %d   [b]Dias de apagão:[/b] %d   [b]Energia desperdiçada:[/b] %.0f kWh" % [
		mini(s.day - 1, s.mission_length()), s.mission_length(), s.alive_count(), GS.CREW_SIZE, s.avg_dose(), s.integrity,
		s.stats["builds"], s.stats["brownout_days"], s.stats["energy_wasted"]]
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
	var again := _button("Jogar novamente", 16)
	again.pressed.connect(start_game)
	h.add_child(again)
	var menu := _button("Menu principal", 16)
	menu.pressed.connect(show_menu)
	h.add_child(menu)
	v.add_child(h)
