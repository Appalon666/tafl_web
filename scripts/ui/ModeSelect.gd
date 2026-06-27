extends Control
## Выбор партии: вариант + сторона + сложность → запись в GameConfig и старт игры.

const TaflVariants = preload("res://scripts/core/TaflVariants.gd")
const COL_BG := Color(0.09, 0.11, 0.14)
const VARIANT_IDS := ["brandubh", "tablut", "fetlar", "copenhagen"]

var _variant: String = GameConfig.variant
var _side: String = GameConfig.human_side
var _difficulty: String = GameConfig.difficulty


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(580, 0)
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	var title := Label.new()
	title.text = tr("Выбор партии")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	col.add_child(title)
	col.add_child(_gap(8))

	# --- Вариант (режим) ---
	var var_opts: Array = []
	for id in VARIANT_IDS:
		var_opts.append([id, _variant_label(id)])
	_section(col, tr("Режим"), _radio(var_opts, _variant, func(v): _variant = v, true))

	# --- Сторона ---
	var side_opts := [
		["defenders", tr("Защитники (король)")],
		["attackers", tr("Осаждающие")],
	]
	_section(col, tr("Сторона"), _radio(side_opts, _side, func(v): _side = v, false))

	# --- Сложность ---
	var diff_opts := [
		["easy", tr("Лёгкий")],
		["normal", tr("Обычный")],
		["hard", tr("Сложный")],
	]
	_section(col, tr("Сложность ИИ"), _radio(diff_opts, _difficulty, func(v): _difficulty = v, false))

	col.add_child(_gap(12))

	# --- Кнопки ---
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var back := _button(tr("Назад"), _on_back)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var start := _button(tr("Начать"), _on_start)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	row.add_child(start)
	col.add_child(row)


func _variant_label(id: String) -> String:
	var v: Dictionary = TaflVariants.get_variant(id)
	return String(v.get("label_" + Settings.locale, v.get("label_en", id)))


func _section(col: VBoxContainer, title: String, content: Control) -> void:
	var h := Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 22)
	h.modulate = Color(1, 1, 1, 0.7)
	col.add_child(h)
	col.add_child(content)
	col.add_child(_gap(4))


## Группа взаимоисключающих кнопок (radio). options: Array of [value, text].
func _radio(options: Array, current, on_pick: Callable, vertical: bool) -> Control:
	var grp := ButtonGroup.new()
	var box: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	for opt in options:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grp
		b.text = String(opt[1])
		b.custom_minimum_size = Vector2(0, 46)
		b.add_theme_font_size_override("font_size", 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if opt[0] == current:
			b.button_pressed = true
		var val = opt[0]
		b.pressed.connect(func(): on_pick.call(val))
		box.add_child(b)
	return box


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _on_start() -> void:
	GameConfig.variant = _variant
	GameConfig.human_side = _side
	GameConfig.difficulty = _difficulty
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
