extends Node2D
## Отрисовка доски Тафла и ввод (мышь/тач). Логику правил не знает.
## Размер клетки подстраивается под вариант (7/9/11) — доска вписана в 640px.

signal point_clicked(idx)

const BOARD_PX := 640.0
const VIEW := Vector2(1280, 720)
const SLIDE_DUR := 0.16  # сек — скольжение фигуры при ходе
const CAP_DUR := 0.24    # сек — «поп» взятой фигуры
const ATK_BODY := Color(0.22, 0.24, 0.30)
const ATK_EDGE := Color(0.10, 0.11, 0.14)
const DEF_BODY := Color(0.95, 0.93, 0.88)
const DEF_EDGE := Color(0.70, 0.66, 0.58)

var board                 # TaflBoard
var state                 # GameState (для отрисовки фигур)
var sel: int = -1
var moves: Array = []     # подсвеченные клетки-цели
var threats: Array = []   # клетки своих фигур под боем (красные кольца)
var hint_from: int = -1   # фигура-подсказка обучения (пульсирующее кольцо)
var hint_cells: Array = []  # клетки-цели подсказки обучения
var _t: float = 0.0       # время для пульсации подсказки
var _anim_active := false
var _anim_from: int = -1
var _anim_to: int = -1
var _anim_caps: Array = []
var _anim_t: float = 0.0  # сек с начала хода
var _anim_end: float = 0.0  # длительность текущей анимации

var _cell: float = 64.0
var _origin: Vector2 = Vector2(320, 40)
var _vp: Vector2 = Vector2(1280, 720)
var _region: Rect2 = Rect2()  # область под доску (задаёт контроллер); пусто → авто


func _ready() -> void:
	get_viewport().size_changed.connect(_relayout)


func setup(board_ref) -> void:
	board = board_ref
	_relayout()


## Контроллер (игра/обучение) задаёт прямоугольник, в который вписать доску.
func set_region(r: Rect2) -> void:
	_region = r
	_relayout()


## Вписывает квадратную доску в доступную область, центрирует. Реагирует на ресайз.
func _relayout() -> void:
	if board == null:
		return
	_vp = get_viewport_rect().size
	var area: Rect2 = _region
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		# По умолчанию — вся вьюпорт с отступом сверху под верхнюю панель HUD.
		area = Rect2(16.0, 56.0, _vp.x - 32.0, _vp.y - 72.0)
	var board_px: float = min(area.size.x, area.size.y)
	_cell = board_px / float(board.size)
	_origin = area.position + (area.size - Vector2(board_px, board_px)) * 0.5
	queue_redraw()


func set_state(s) -> void:
	state = s
	queue_redraw()


func show_moves(from_idx: int, targets: Array) -> void:
	sel = from_idx
	moves = targets
	queue_redraw()


func clear_highlights() -> void:
	sel = -1
	moves = []
	queue_redraw()


## Клетки своих фигур, которые противник берёт следующим ходом (подсветка угроз).
func set_threats(arr: Array) -> void:
	threats = arr
	queue_redraw()


## Обучающая подсветка «glowing choice»: фигура-подсказка + клетки-цели.
func set_hint(from_idx: int, cells: Array) -> void:
	hint_from = from_idx
	hint_cells = cells
	queue_redraw()


## Запускает анимацию хода: скольжение from→to и «поп» взятых фигур.
func animate_move(from_idx: int, to_idx: int, captured: Array = []) -> void:
	_anim_from = from_idx
	_anim_to = to_idx
	_anim_caps = captured
	_anim_t = 0.0
	_anim_end = CAP_DUR if not captured.is_empty() else SLIDE_DUR
	_anim_active = true
	queue_redraw()


func _process(delta: float) -> void:
	var redraw := false
	if _anim_active:
		_anim_t += delta
		if _anim_t >= _anim_end:
			_anim_active = false
		redraw = true
	# Пульсация подсказки — только когда она активна (в обычной игре не тратимся).
	if hint_from != -1 or not hint_cells.is_empty():
		_t += delta
		redraw = true
	if redraw:
		queue_redraw()


func cell_center(idx: int) -> Vector2:
	var c: Vector2i = board.xy(idx)
	return _origin + Vector2(c.x + 0.5, c.y + 0.5) * _cell


func _draw() -> void:
	if board == null:
		return
	draw_rect(Rect2(Vector2.ZERO, _vp), Color(0.12, 0.13, 0.16))
	# Поле.
	var light := Color(0.93, 0.86, 0.69)
	var dark := Color(0.58, 0.45, 0.29)
	for y in board.size:
		for x in board.size:
			var idx: int = board.index(x, y)
			var r := Rect2(_origin + Vector2(x, y) * _cell, Vector2(_cell, _cell))
			draw_rect(r, dark if (x + y) % 2 == 0 else light)
	# Спецклетки: трон и углы.
	_mark_square(board.throne, Color(0.66, 0.36, 0.85, 0.95))
	for cidx in board.corners:
		_mark_square(cidx, Color(0.20, 0.62, 0.92, 0.95))
	# Сетка.
	var bpx: float = _cell * board.size
	for i in range(board.size + 1):
		var off: float = i * _cell
		draw_line(_origin + Vector2(off, 0), _origin + Vector2(off, bpx), Color(0, 0, 0, 0.18), 1.5)
		draw_line(_origin + Vector2(0, off), _origin + Vector2(bpx, off), Color(0, 0, 0, 0.18), 1.5)
	# Подсветка выбора и ходов.
	if sel != -1:
		draw_rect(_square_rect(sel), Color(1.0, 0.84, 0.18, 0.60))
	for m in moves:
		draw_circle(cell_center(m), _cell * 0.23, Color(0.25, 0.90, 0.32, 0.95))
	# Фигуры.
	if state != null:
		for idx in state.attackers.keys():
			if _anim_active and idx == _anim_to:
				continue  # эта фигура сейчас «едет» — рисуем её отдельно
			_draw_piece_at(cell_center(idx), ATK_BODY, ATK_EDGE)
		for idx in state.defenders.keys():
			if _anim_active and idx == _anim_to:
				continue
			_draw_piece_at(cell_center(idx), DEF_BODY, DEF_EDGE)
		if state.king != -1 and not (_anim_active and state.king == _anim_to):
			_draw_king_at(cell_center(state.king))
		# Угрозы: свои фигуры под боем — яркое красное кольцо поверх фигуры.
		for tidx in threats:
			draw_arc(cell_center(tidx), _cell * 0.46, 0.0, TAU, 40, Color(0.98, 0.22, 0.18, 1.0), 4.0)
		# Обучающая подсказка «glowing choice»: ярко пульсирующее золото, чтобы было
		# однозначно понятно, что́ передвинуть и куда.
		if hint_from != -1 or not hint_cells.is_empty():
			var pulse: float = 0.55 + 0.45 * sin(_t * 5.0)
			var gold := Color(1.0, 0.80, 0.16)
			# Цель: подсветка всей клетки + крупная пульсирующая точка.
			for hc in hint_cells:
				draw_rect(_square_rect(hc).grow(-_cell * 0.06), Color(1.0, 0.80, 0.16, pulse * 0.5))
				draw_circle(cell_center(hc), _cell * 0.26, Color(gold.r, gold.g, gold.b, pulse))
			# Фигура-подсказка: толстое пульсирующее кольцо.
			if hint_from != -1:
				draw_arc(cell_center(hint_from), _cell * 0.49, 0.0, TAU, 48,
					Color(gold.r, gold.g, gold.b, pulse), 6.0)
		# Анимация хода: «поп» взятых + скользящая фигура поверх всего.
		if _anim_active:
			_draw_anim()


func _square_rect(idx: int) -> Rect2:
	var c: Vector2i = board.xy(idx)
	return Rect2(_origin + Vector2(c.x, c.y) * _cell, Vector2(_cell, _cell))


func _mark_square(idx: int, col: Color) -> void:
	var r := _square_rect(idx)
	draw_rect(r.grow(-_cell * 0.12), col)


func _draw_piece_at(p: Vector2, body: Color, edge: Color) -> void:
	var rad := _cell * 0.34
	draw_circle(p + Vector2(2, 3), rad, Color(0, 0, 0, 0.18))
	draw_circle(p, rad, body)
	draw_arc(p, rad, 0.0, TAU, 32, edge, 2.0)


func _draw_king_at(p: Vector2) -> void:
	var rad := _cell * 0.40
	draw_circle(p + Vector2(2, 3), rad, Color(0, 0, 0, 0.20))
	draw_circle(p, rad, Color(0.95, 0.80, 0.30))
	draw_arc(p, rad, 0.0, TAU, 36, Color(0.65, 0.48, 0.12), 2.5)
	# Маленькая «корона».
	var w := rad * 0.7
	var pts := PackedVector2Array([
		p + Vector2(-w, w * 0.4), p + Vector2(-w, -w * 0.3),
		p + Vector2(-w * 0.5, w * 0.1), p + Vector2(0, -w * 0.5),
		p + Vector2(w * 0.5, w * 0.1), p + Vector2(w, -w * 0.3),
		p + Vector2(w, w * 0.4),
	])
	draw_colored_polygon(pts, Color(0.55, 0.40, 0.10))


## Рисует текущий кадр анимации: затухающий «поп» взятых + скользящую фигуру.
func _draw_anim() -> void:
	if not _anim_caps.is_empty():
		var cp: float = clamp(_anim_t / CAP_DUR, 0.0, 1.0)
		var ca := Color(0.92, 0.92, 0.95, 1.0 - cp)
		var crad: float = _cell * (0.30 + 0.28 * cp)
		for cidx in _anim_caps:
			draw_circle(cell_center(cidx), crad, ca)
	var sp: float = clamp(_anim_t / SLIDE_DUR, 0.0, 1.0)
	var pos: Vector2 = cell_center(_anim_from).lerp(cell_center(_anim_to), _ease(sp))
	if state.king == _anim_to:
		_draw_king_at(pos)
	elif state.attackers.has(_anim_to):
		_draw_piece_at(pos, ATK_BODY, ATK_EDGE)
	elif state.defenders.has(_anim_to):
		_draw_piece_at(pos, DEF_BODY, DEF_EDGE)


## Плавная скорость (smoothstep) для приятного «доезда».
func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _unhandled_input(event: InputEvent) -> void:
	if board == null:
		return
	var pos = null
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = get_global_mouse_position()
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	if pos == null:
		return
	var local: Vector2 = pos - _origin
	if local.x < 0.0 or local.y < 0.0:
		return  # клик в поле слева/сверху от доски — не клетка (0,0)
	var x := int(local.x / _cell)
	var y := int(local.y / _cell)
	if board.in_board(x, y):
		point_clicked.emit(board.index(x, y))
