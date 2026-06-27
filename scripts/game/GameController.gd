extends Node2D
## Оркестратор партии Тафла: состояние, правила, ИИ, доска, HUD.
## Самодостаточен — создаёт BoardView и HUD в коде (меню/сцены добавим позже).

const TaflBoard = preload("res://scripts/core/TaflBoard.gd")
const TaflVariants = preload("res://scripts/core/TaflVariants.gd")
const RulesEngine = preload("res://scripts/core/RulesEngine.gd")
const RandomAI = preload("res://scripts/ai/RandomAI.gd")
const TaflAI = preload("res://scripts/ai/TaflAI.gd")
const BoardViewScript = preload("res://scripts/game/BoardView.gd")

var board
var rules
var ai
var state

var human_side := "defenders"
var ai_side := "attackers"
var busy := false
var game_over := false
var sel := -1

var board_view
var hud: Label


func _ready() -> void:
	var variant_id: String = GameConfig.variant
	var vdata: Dictionary = TaflVariants.get_variant(variant_id)
	board = TaflBoard.new(int(vdata.size))
	rules = RulesEngine.new(board, vdata)
	ai = _make_ai(GameConfig.difficulty)
	human_side = GameConfig.human_side
	ai_side = "attackers" if human_side == "defenders" else "defenders"
	state = TaflVariants.build_state(variant_id)

	board_view = BoardViewScript.new()
	add_child(board_view)
	board_view.setup(board)
	board_view.point_clicked.connect(_on_point_clicked)

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 14)
	hud.add_theme_font_size_override("font_size", 24)
	layer.add_child(hud)

	YandexSDK.gameplay_start()
	_refresh()


## Уровень сложности задаётся честно — глубиной/временем перебора.
func _make_ai(difficulty: String):
	match difficulty:
		"easy":
			return RandomAI.new()  # жадность на 1 ход
		"hard":
			return TaflAI.new(6, 4000)
		_:  # "normal"
			return TaflAI.new(3, 1500)


func _refresh() -> void:
	board_view.set_state(state)
	_update_hud()
	var w: String = rules.check_winner(state)
	if w != "":
		_end_game(w)
		return
	if state.turn == ai_side:
		_ai_turn()


func _update_hud() -> void:
	var vdata: Dictionary = TaflVariants.get_variant(GameConfig.variant)
	var label: String = vdata.get("label_" + Settings.locale, vdata.get("label_en", ""))
	var who: String = tr("Ход осаждающих") if state.turn == "attackers" else tr("Ход защитников")
	var you: String = tr("Осаждающие") if human_side == "attackers" else tr("Защитники")
	hud.text = "%s  ·  %s: %s  ·  %s" % [label, tr("Вы"), you, who]


func _ai_turn() -> void:
	busy = true
	await get_tree().create_timer(0.35).timeout
	var mv = ai.choose_move(rules, state)
	if mv != null:
		rules.apply(state, mv)
	busy = false
	board_view.clear_highlights()
	_refresh()


func _on_point_clicked(idx: int) -> void:
	if busy or game_over or state.turn != human_side:
		return
	if sel == -1:
		_try_select(idx)
		return
	# Клик по легальной цели — ходим.
	var targets: Array = rules.legal_moves(state, sel)
	if targets.has(idx):
		rules.apply(state, {"from": sel, "to": idx})
		sel = -1
		board_view.clear_highlights()
		_refresh()
	else:
		# Иначе — переселект на другую свою фигуру или сброс.
		sel = -1
		board_view.clear_highlights()
		_try_select(idx)


func _try_select(idx: int) -> void:
	if state.side_at(idx) != human_side:
		return
	sel = idx
	board_view.show_moves(idx, rules.legal_moves(state, idx))


func _end_game(winner: String) -> void:
	game_over = true
	board_view.clear_highlights()
	YandexSDK.gameplay_stop()
	var msg := tr("Ничья")
	if winner == "attackers":
		msg = tr("Победа осаждающих")
	elif winner == "defenders":
		msg = tr("Победа защитников")
	hud.text = msg + "  ·  " + tr("R — заново")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Быстрый рестарт по R (для теста скелета).
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
		# ESC — выход в главное меню.
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
