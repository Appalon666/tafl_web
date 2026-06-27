extends Node2D
## Оркестратор партии Тафла: состояние, правила, ИИ, доска, HUD.
## Самодостаточен — создаёт BoardView и HUD в коде (меню/сцены добавим позже).

const TaflBoard = preload("res://scripts/core/TaflBoard.gd")
const TaflVariants = preload("res://scripts/core/TaflVariants.gd")
const RulesEngine = preload("res://scripts/core/RulesEngine.gd")
const RandomAI = preload("res://scripts/ai/RandomAI.gd")
const TaflAI = preload("res://scripts/ai/TaflAI.gd")
const BoardViewScript = preload("res://scripts/game/BoardView.gd")
const ResultOverlayScript = preload("res://scripts/ui/ResultOverlay.gd")
const Achievements = preload("res://scripts/systems/Achievements.gd")

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

	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	# Верхняя панель: статус слева, экранные кнопки справа (тач-доступ).
	var topbar := HBoxContainer.new()
	topbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	topbar.offset_left = 24
	topbar.offset_right = -24
	topbar.offset_top = 12
	topbar.add_theme_constant_override("separation", 8)
	ui_layer.add_child(topbar)

	hud = Label.new()
	hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_theme_font_size_override("font_size", 22)
	topbar.add_child(hud)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(spacer)

	topbar.add_child(_bar_button(tr("Заново"), _restart))
	topbar.add_child(_bar_button(tr("Меню"), _to_menu))

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
		board_view.set_threats([])
		_ai_turn()
	else:
		# В свой ход подсвечиваем свои фигуры, которые ИИ может взять следующим ходом.
		board_view.set_threats(rules.threatened_pieces(state, human_side))


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
		var caps: Array = rules.apply(state, mv)
		board_view.animate_move(int(mv.from), int(mv.to), caps)
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
		var from_i := sel
		var caps: Array = rules.apply(state, {"from": from_i, "to": idx})
		sel = -1
		board_view.clear_highlights()
		board_view.animate_move(from_i, idx, caps)
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
	board_view.set_threats([])
	YandexSDK.gameplay_stop()
	var msg: String = _winner_text(winner)
	hud.text = msg
	# Победа человека на «Обычном»+ засчитывает прохождение и может открыть режим.
	var lines := PackedStringArray()
	if winner == human_side:
		var opened: String = Progress.mark_completed(GameConfig.variant, GameConfig.difficulty)
		if opened != "":
			var ov: Dictionary = TaflVariants.get_variant(opened)
			var lbl: String = String(ov.get("label_" + Settings.locale, ov.get("label_en", opened)))
			lines.append(tr("Открыт режим:") + " " + lbl)
		var pts: int = Progress.add_win(GameConfig.variant, GameConfig.difficulty)
		if pts > 0:
			lines.append("+%d %s" % [pts, tr("рейтинга")])
			YandexSDK.submit_score(Progress.score)
	# Статистика и достижения — для любого исхода.
	var outcome := "draw"
	if winner == human_side:
		outcome = "win"
	elif winner == "attackers" or winner == "defenders":
		outcome = "loss"
	Progress.record_game(outcome, human_side, GameConfig.variant, GameConfig.difficulty)
	for aid in Achievements.refresh(Progress):
		lines.append(tr("Достижение") + ": " + tr(Achievements.title_of(aid)))
	var subtitle: String = "\n".join(lines)
	var overlay = ResultOverlayScript.new()
	add_child(overlay)
	overlay.setup(msg, subtitle)
	overlay.rematch.connect(_restart)
	overlay.to_menu.connect(_to_menu)


func _winner_text(winner: String) -> String:
	match winner:
		"attackers":
			return tr("Победа осаждающих")
		"defenders":
			return tr("Победа защитников")
		_:
			return tr("Ничья")


func _bar_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(0, 36)
	b.focus_mode = Control.FOCUS_NONE  # не перехватывать клавиши R/ESC
	b.pressed.connect(cb)
	return b


func _restart() -> void:
	# Логическая пауза (4.4): тут можно показать рекламу-вставку.
	# gameplay_stop только если партия ещё шла (после _end_game уже остановлено).
	if not game_over:
		YandexSDK.gameplay_stop()
	YandexSDK.show_interstitial()
	get_tree().reload_current_scene()


func _to_menu() -> void:
	if not game_over:
		YandexSDK.gameplay_stop()
	YandexSDK.show_interstitial()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_restart()
		elif event.keycode == KEY_ESCAPE:
			_to_menu()
