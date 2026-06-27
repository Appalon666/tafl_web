extends Control
## Главное меню Тафла — точка входа (main_scene).
## UI строится в коде: дизайн/тема — отдельный трек, тут только структура и поток.

const COL_BG := Color(0.09, 0.11, 0.14)


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
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	center.add_child(col)

	var title := Label.new()
	title.text = "TAFL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	if Settings.title_font:  # декоративный «нордический» шрифт логотипа, если положен
		title.add_theme_font_override("font", Settings.title_font)
	col.add_child(title)

	var sub := Label.new()
	sub.text = tr("Скандинавская стратегия викингов")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(1, 1, 1, 0.6)
	col.add_child(sub)

	col.add_child(_gap(24))

	col.add_child(_button(tr("Играть"), _on_play))
	col.add_child(_button(tr("Как играть"), _on_tutorial))       # M2 — онбординг
	col.add_child(_button(tr("Таблица лидеров"), _on_leaderboard))  # M3 — рейтинг
	col.add_child(_button(tr("Достижения"), _on_achievements))     # M3 — ачивки
	col.add_child(_button(tr("Настройки"), _on_settings))
	col.add_child(_button(tr("Выход"), _on_quit))

	# Текущий рейтинг игрока (накопленные очки за победы).
	var rating := Label.new()
	rating.text = tr("Рейтинг") + ": " + str(Progress.score)
	rating.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating.add_theme_font_size_override("font_size", 18)
	rating.modulate = Color(1, 1, 1, 0.6)
	col.add_child(_gap(8))
	col.add_child(rating)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b


func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/ModeSelect.tscn")


func _on_tutorial() -> void:
	get_tree().change_scene_to_file("res://scenes/Tutorial.tscn")


func _on_leaderboard() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Leaderboard.tscn")


func _on_achievements() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/Achievements.tscn")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SettingsMenu.tscn")


func _on_quit() -> void:
	get_tree().quit()
