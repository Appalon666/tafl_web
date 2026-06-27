extends Node2D
## Интерактивное обучение: серия мини-уроков (песочница) с «glowing choice»,
## блокировкой нелегальных ходов и ранней победой (§6). Данные — TutorialLessons.
## Доска центрирована (x≥320), инструкция — в левой панели (не перекрывает поле).

const TaflBoard = preload("res://scripts/core/TaflBoard.gd")
const RulesEngine = preload("res://scripts/core/RulesEngine.gd")
const BoardViewScript = preload("res://scripts/game/BoardView.gd")
const Lessons = preload("res://scripts/game/TutorialLessons.gd")
const Achievements = preload("res://scripts/systems/Achievements.gd")

const COL_PANEL := Color(0.10, 0.12, 0.16, 0.97)

var _all: Array
var _i: int = 0
var cur: Dictionary
var board
var rules
var state
var board_view
var sel: int = -1
var solved: bool = false

var panel: PanelContainer
var title_label: Label
var text_label: Label
var progress_label: Label
var verdict_label: Label
var next_btn: Button


func _ready() -> void:
	_all = Lessons.all()
	board_view = BoardViewScript.new()
	add_child(board_view)
	board_view.point_clicked.connect(_on_point_clicked)
	_build_ui()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	_load_lesson(0)
	YandexSDK.gameplay_start()


## Адаптивная раскладка: альбом — панель слева, доска справа; портрет — панель
## сверху, доска снизу. Пересчитывается при ресайзе/повороте экрана.
func _relayout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x >= vp.y:
		var pw: float = clampf(vp.x * 0.30, 240.0, 340.0)
		panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		panel.offset_right = pw
		board_view.set_region(Rect2(pw + 12.0, 12.0, vp.x - pw - 24.0, vp.y - 24.0))
	else:
		var ph: float = clampf(vp.y * 0.34, 200.0, 300.0)
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		panel.offset_bottom = ph
		board_view.set_region(Rect2(12.0, ph + 12.0, vp.x - 24.0, vp.y - ph - 24.0))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	panel = PanelContainer.new()  # позиция/размер задаются в _relayout (адаптивно)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head := Label.new()
	head.text = tr("Как играть")
	head.add_theme_font_size_override("font_size", 16)
	head.modulate = Color(1, 1, 1, 0.5)
	col.add_child(head)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(title_label)

	text_label = Label.new()
	text_label.add_theme_font_size_override("font_size", 18)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(264, 0)
	col.add_child(text_label)

	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 16)
	progress_label.modulate = Color(1, 1, 1, 0.6)
	col.add_child(progress_label)

	verdict_label = Label.new()
	verdict_label.text = tr("Верно!")
	verdict_label.add_theme_font_size_override("font_size", 22)
	verdict_label.modulate = Color(0.45, 0.85, 0.45)
	verdict_label.visible = false
	col.add_child(verdict_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	next_btn = _button(tr("Далее"), _on_next)
	next_btn.visible = false
	col.add_child(next_btn)

	col.add_child(_button(tr("В меню"), _to_menu))


func _load_lesson(i: int) -> void:
	_i = i
	cur = Lessons.compiled(_all[i])
	board = TaflBoard.new(int(cur.size))
	rules = RulesEngine.new(board, cur.variant)
	state = Lessons.build_state(cur)
	board_view.setup(board)
	board_view.set_state(state)
	board_view.clear_highlights()
	board_view.set_hint(int(cur.hint_from), cur.hint_to)
	sel = -1
	solved = false
	title_label.text = tr(cur.title)
	text_label.text = tr(cur.text)
	progress_label.text = "%d / %d" % [i + 1, _all.size()]
	verdict_label.visible = false
	next_btn.visible = false
	next_btn.text = tr("Завершить") if i == _all.size() - 1 else tr("Далее")


func _on_point_clicked(idx: int) -> void:
	if solved:
		return
	if sel == -1:
		# Выбрать можно только подсвеченную фигуру (энфорсмент).
		if idx == int(cur.hint_from):
			sel = idx
			board_view.show_moves(idx, cur.hint_to)
		return
	if cur.hint_to.has(idx):
		var from_i := sel
		var caps: Array = rules.apply(state, {"from": from_i, "to": idx})
		sel = -1
		board_view.set_state(state)
		board_view.clear_highlights()
		board_view.set_hint(-1, [])
		board_view.animate_move(from_i, idx, caps)
		if Lessons.goal_met(rules, state, cur, idx, caps):
			_on_solved()
		else:
			_load_lesson(_i)  # подстраховка: вернуть позицию
	elif idx == int(cur.hint_from):
		return  # фигура уже выбрана
	else:
		sel = -1
		board_view.clear_highlights()  # подсказка-золото остаётся


func _on_solved() -> void:
	solved = true
	verdict_label.visible = true
	next_btn.visible = true


func _on_next() -> void:
	if _i + 1 < _all.size():
		_load_lesson(_i + 1)
	else:
		Progress.mark_tutorial_done()
		Achievements.refresh(Progress)
		_to_menu()


func _to_menu() -> void:
	YandexSDK.gameplay_stop()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_to_menu()
