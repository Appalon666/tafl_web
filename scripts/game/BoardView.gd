extends Node2D
## Отрисовка доски Тафла и ввод (мышь/тач). Логику правил не знает.
## Размер клетки подстраивается под вариант (7/9/11) — доска вписана в 640px.

signal point_clicked(idx)

const BOARD_PX := 640.0
const VIEW := Vector2(1280, 720)

var board                 # TaflBoard
var state                 # GameState (для отрисовки фигур)
var sel: int = -1
var moves: Array = []     # подсвеченные клетки-цели

var _cell: float = 64.0
var _origin: Vector2 = Vector2(320, 40)


func setup(board_ref) -> void:
	board = board_ref
	_cell = BOARD_PX / float(board.size)
	_origin = Vector2((VIEW.x - BOARD_PX) * 0.5, (VIEW.y - BOARD_PX) * 0.5)
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


func cell_center(idx: int) -> Vector2:
	var c: Vector2i = board.xy(idx)
	return _origin + Vector2(c.x + 0.5, c.y + 0.5) * _cell


func _draw() -> void:
	if board == null:
		return
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color(0.12, 0.13, 0.16))
	# Поле.
	var light := Color(0.86, 0.80, 0.66)
	var dark := Color(0.78, 0.71, 0.55)
	for y in board.size:
		for x in board.size:
			var idx: int = board.index(x, y)
			var r := Rect2(_origin + Vector2(x, y) * _cell, Vector2(_cell, _cell))
			draw_rect(r, dark if (x + y) % 2 == 0 else light)
	# Спецклетки: трон и углы.
	_mark_square(board.throne, Color(0.55, 0.42, 0.66, 0.85))
	for cidx in board.corners:
		_mark_square(cidx, Color(0.42, 0.55, 0.66, 0.85))
	# Сетка.
	for i in range(board.size + 1):
		var off: float = i * _cell
		draw_line(_origin + Vector2(off, 0), _origin + Vector2(off, BOARD_PX), Color(0, 0, 0, 0.18), 1.5)
		draw_line(_origin + Vector2(0, off), _origin + Vector2(BOARD_PX, off), Color(0, 0, 0, 0.18), 1.5)
	# Подсветка выбора и ходов.
	if sel != -1:
		draw_rect(_square_rect(sel), Color(0.98, 0.85, 0.25, 0.45))
	for m in moves:
		draw_circle(cell_center(m), _cell * 0.18, Color(0.40, 0.78, 0.40, 0.85))
	# Фигуры.
	if state != null:
		for idx in state.attackers.keys():
			_draw_piece(idx, Color(0.22, 0.24, 0.30), Color(0.10, 0.11, 0.14))
		for idx in state.defenders.keys():
			_draw_piece(idx, Color(0.95, 0.93, 0.88), Color(0.70, 0.66, 0.58))
		if state.king != -1:
			_draw_king(state.king)


func _square_rect(idx: int) -> Rect2:
	var c: Vector2i = board.xy(idx)
	return Rect2(_origin + Vector2(c.x, c.y) * _cell, Vector2(_cell, _cell))


func _mark_square(idx: int, col: Color) -> void:
	var r := _square_rect(idx)
	draw_rect(r.grow(-_cell * 0.12), col)


func _draw_piece(idx: int, body: Color, edge: Color) -> void:
	var p := cell_center(idx)
	var rad := _cell * 0.34
	draw_circle(p + Vector2(2, 3), rad, Color(0, 0, 0, 0.18))
	draw_circle(p, rad, body)
	draw_arc(p, rad, 0.0, TAU, 32, edge, 2.0)


func _draw_king(idx: int) -> void:
	var p := cell_center(idx)
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
	var x := int(local.x / _cell)
	var y := int(local.y / _cell)
	if board.in_board(x, y):
		point_clicked.emit(board.index(x, y))
