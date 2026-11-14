extends Control
## Desenho procedural da base. Lê o GameState e redesenha a cada quadro.

var state = null
var _t := 0.0
var _stars: Array[Vector3] = []
var _particles: Array[Vector3] = []


func _ready() -> void:
	clip_contents = true
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 140:
		_stars.append(Vector3(r.randf(), r.randf() * 0.65, r.randf_range(0.6, 1.8)))
	for i in 90:
		_particles.append(Vector3(r.randf(), r.randf(), r.randf_range(0.5, 1.5)))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if state == null:
		return
	var w := size.x
	var h := size.y
	var gy := h * 0.70
	var mars: bool = state.location == "mars"
	var sun: float = state.sun_factor()
	var storm: bool = state.modifiers.has("dust_storm")
	var font := get_theme_default_font()

	# Céu
	var sky := Color(0.02, 0.02, 0.05)
	if mars:
		sky = Color(0.78, 0.58, 0.42).lerp(Color(0.45, 0.28, 0.18), 0.6 if storm else 0.0)
	draw_rect(Rect2(0, 0, w, gy), sky)
	if not mars:
		for s in _stars:
			var tw := 0.6 + 0.4 * sin(_t * s.z * 2.0 + s.x * 40.0)
			draw_circle(Vector2(s.x * w, s.y * gy), s.z * 0.8, Color(1, 1, 1, 0.5 * tw))
	# Terra no céu lunar / Sol
	if not mars:
		var ep := Vector2(w * 0.86, gy * 0.22)
		draw_circle(ep, 16, Color(0.2, 0.45, 0.9))
		draw_circle(ep + Vector2(-4, -3), 6, Color(0.3, 0.7, 0.35, 0.9))
		draw_circle(ep + Vector2(5, 5), 5, Color(1, 1, 1, 0.7))
	if sun > 0.0:
		var sp := Vector2(w * 0.1, gy - 18.0 - 40.0 * sun)
		var sc := Color(1.0, 0.95, 0.7) if not mars else Color(0.85, 0.9, 1.0)
		draw_circle(sp, 26, Color(sc.r, sc.g, sc.b, 0.15 * sun))
		draw_circle(sp, 13, Color(sc.r, sc.g, sc.b, sun))

	# Solo
	var ground := Color(0.42, 0.42, 0.44) if not mars else Color(0.62, 0.33, 0.2)
	var pts := PackedVector2Array()
	pts.append(Vector2(0, h))
	var steps := 24
	for i in steps + 1:
		var x := w * i / steps
		pts.append(Vector2(x, gy - 10.0 * sin(i * 0.9) - 6.0 * sin(i * 2.3)))
	pts.append(Vector2(w, h))
	draw_colored_polygon(pts, ground.darkened(0.25))
	draw_rect(Rect2(0, gy + 8, w, h - gy), ground)
	for i in 12:
		var cx := fmod(i * 173.0, w)
		var cy := gy + 20.0 + fmod(i * 61.0, h - gy - 25.0)
		draw_arc(Vector2(cx, cy), 6.0 + (i % 4) * 3.0, PI, TAU, 10, ground.darkened(0.3), 2.0)

	var b: Dictionary = state.buildings
	var base_y := gy + 30.0

	# Painéis solares (esquerda)
	var n_solar: int = b.get("solar", 0)
	var panel_col := Color(0.15, 0.25, 0.55).lerp(Color(0.5, 0.35, 0.2), 1.0 - state.dust)
	for i in n_solar:
		var col := i % 7
		var row := i / 7
		var px := 20.0 + col * 30.0
		var py := base_y - 20.0 + row * 34.0
		draw_line(Vector2(px + 10, py + 8), Vector2(px + 10, py + 22), Color(0.6, 0.6, 0.6), 2)
		var poly := PackedVector2Array([Vector2(px, py + 10), Vector2(px + 22, py), Vector2(px + 26, py + 6), Vector2(px + 4, py + 16)])
		draw_colored_polygon(poly, panel_col.lightened(0.2 * sun))
	_label(font, Vector2(20, base_y + 52), "Painéis: %d" % n_solar)

	# Baterias
	var n_bat: int = b.get("battery", 0)
	var cap: float = state.battery_capacity()
	var frac: float = state.battery / cap if cap > 0 else 0.0
	for i in n_bat:
		var bx := 20.0 + i * 22.0
		var by := base_y + 62.0
		draw_rect(Rect2(bx, by, 16, 26), Color(0.25, 0.25, 0.28))
		draw_rect(Rect2(bx + 2, by + 2 + 22 * (1.0 - frac), 12, 22 * frac), Color(0.25, 0.8, 0.4) if frac > 0.25 else Color(0.9, 0.3, 0.25))

	# Habitat central com camadas de regolito
	var hc := Vector2(w * 0.48, base_y + 22.0)
	var layers: float = state.shield_layers
	var full := int(floor(layers))
	for i in range(full, 0, -1):
		_dome(hc, 52.0 + i * 7.0, ground.darkened(0.1 + 0.08 * i))
	if layers - full > 0.01:
		var r := 52.0 + (full + 1) * 7.0
		draw_arc(hc, r - 3, PI, PI + PI * (layers - full), 20, ground.darkened(0.2), 6.0)
	_dome(hc, 52.0, Color(0.85, 0.87, 0.9))
	_dome(hc, 44.0, Color(0.72, 0.75, 0.8))
	var lit := 0.9 if state.battery > 1.0 or sun > 0.0 or b.get("reactor", 0) > 0 else 0.2
	for i in 3:
		draw_circle(hc + Vector2(-20 + i * 20, -22), 4, Color(1.0, 0.85, 0.4, lit))
	draw_rect(Rect2(hc.x - 8, hc.y - 16, 16, 16), Color(0.4, 0.42, 0.48))
	var hab_txt := "Habitat (blindagem %d%%)" % int(state.shield_fraction() * 100)
	_label(font, hc + Vector2(-70, 22), hab_txt)

	# Estufas
	var n_gh: int = b.get("greenhouse", 0)
	var crop: float = state.crop_health / 100.0
	for i in n_gh:
		var gc := Vector2(w * 0.48 + 90.0 + i * 52.0, base_y + 22.0)
		_dome(gc, 22.0, Color(0.75, 0.9, 0.85, 0.5))
		var plant := Color(0.55, 0.45, 0.2).lerp(Color(0.2, 0.8, 0.3), crop)
		for k in 4:
			draw_circle(gc + Vector2(-12 + k * 8, -5), 4.0 * (0.5 + crop * 0.5), plant)
	if n_gh > 0:
		_label(font, Vector2(w * 0.48 + 70.0, base_y + 62.0), "Estufas: %d (plantas %d%%)" % [n_gh, int(state.crop_health)])

	# ISRU
	var n_isru: int = b.get("isru", 0)
	for i in n_isru:
		var ix := w * 0.26 + i * 34.0
		draw_rect(Rect2(ix, base_y - 4, 26, 22), Color(0.7, 0.55, 0.25))
		draw_line(Vector2(ix + 13, base_y - 4), Vector2(ix + 13, base_y - 26), Color(0.7, 0.7, 0.7), 3)
		var ang := _t * 3.0 + i
		draw_line(Vector2(ix + 13, base_y - 26), Vector2(ix + 13 + 8 * cos(ang), base_y - 26 + 8 * sin(ang)), Color(0.9, 0.9, 0.9), 2)
	if n_isru > 0:
		_label(font, Vector2(w * 0.26, base_y + 32), "ISRU: %d" % n_isru)

	# Reatores (direita, afastados)
	var n_re: int = b.get("reactor", 0)
	var on: bool = not state.modifiers.has("reactor_off")
	for i in n_re:
		var rx := w - 70.0 - i * 50.0
		var ry := base_y - 10.0
		draw_rect(Rect2(rx, ry, 18, 30), Color(0.55, 0.57, 0.6))
		for k in 4:
			draw_line(Vector2(rx - 14, ry + 4 + k * 7), Vector2(rx + 32, ry + 4 + k * 7), Color(0.75, 0.3, 0.2) if on else Color(0.35, 0.35, 0.4), 2)
		draw_circle(Vector2(rx + 9, ry + 8), 3, Color(0.3, 1.0, 0.4) if on else Color(1, 0.2, 0.2))
	if n_re > 0:
		_label(font, Vector2(w - 120.0, base_y + 32), "Reator: %s" % ("ligado" if on else "DESLIGADO"))

	# Parede de água
	if b.get("water_wall", 0) > 0:
		draw_rect(Rect2(hc.x - 30, hc.y - 2, 60, 6), Color(0.3, 0.6, 1.0, 0.8))

	# Noite / penumbra
	if not mars and sun < 1.0:
		draw_rect(Rect2(0, 0, w, h), Color(0.0, 0.0, 0.05, 0.55 * (1.0 - sun)))

	# Tempestade de poeira
	if storm:
		draw_rect(Rect2(0, 0, w, h), Color(0.6, 0.35, 0.2, 0.35))
		for p in _particles:
			var x := fmod(p.x * w + _t * 160.0 * p.z, w)
			var y := p.y * h
			draw_line(Vector2(x, y), Vector2(x + 14 * p.z, y + 2), Color(0.9, 0.7, 0.5, 0.6), 1.5)

	# Abrigo
	if state.work_block == "shelter":
		draw_rect(Rect2(0, 0, w, h), Color(0.8, 0.1, 0.1, 0.12))
		_label(font, Vector2(w * 0.5 - 150, 26), "TRIPULAÇÃO NO ABRIGO DE RADIAÇÃO", 16, Color(1, 0.5, 0.45))
	elif state.work_block == "day_off":
		_label(font, Vector2(w * 0.5 - 70, 26), "DIA DE FOLGA", 16, Color(0.6, 0.9, 1.0))

	# Estado do período
	_label(font, Vector2(12, 22), "%s  |  %s" % [state.loc()["short"], state.period_name()], 15, Color(1, 1, 1, 0.9))


func _dome(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var a := PI + PI * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


func _label(font: Font, pos: Vector2, text: String, fs: int = 12, col: Color = Color(1, 1, 1, 0.85)) -> void:
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
