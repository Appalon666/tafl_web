extends Control
## Настройки. Пока — язык (ru/en). Звук/прочее — M5 (помечено заглушкой).

const COL_BG := Color(0.09, 0.11, 0.14)

var col: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _relayout() -> void:
	if col == null:
		return
	col.custom_minimum_size.x = minf(get_viewport_rect().size.x - 24.0, 520.0)


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)

	var title := Label.new()
	title.text = tr("Настройки")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	col.add_child(title)
	col.add_child(_gap(12))

	# --- Язык ---
	var lang_opts := [["ru", "Русский"], ["en", "English"]]
	_section(col, tr("Язык"), _radio(lang_opts, Settings.locale, func(v): Settings.set_locale_code(v)))

	# --- Заглушка для будущих настроек ---
	var note := Label.new()
	note.text = tr("Звук и другие настройки — скоро")
	note.add_theme_font_size_override("font_size", 18)
	note.modulate = Color(1, 1, 1, 0.5)
	col.add_child(note)

	col.add_child(_gap(16))
	col.add_child(_button(tr("Назад"), _on_back))


func _section(col: VBoxContainer, title: String, content: Control) -> void:
	var h := Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 22)
	h.modulate = Color(1, 1, 1, 0.7)
	col.add_child(h)
	col.add_child(content)


func _radio(options: Array, current, on_pick: Callable) -> Control:
	var grp := ButtonGroup.new()
	var box := HBoxContainer.new()
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


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
