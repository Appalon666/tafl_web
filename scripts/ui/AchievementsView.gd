extends Control
## Экран достижений + краткая статистика. Заработанные — золотом, остальные приглушены.

const Achievements = preload("res://scripts/systems/Achievements.gd")
const COL_BG := Color(0.09, 0.11, 0.14)

var root: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _relayout() -> void:
	if root == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var w: float = minf(vp.x - 24.0, 560.0)
	var m: float = (vp.x - w) * 0.5
	root.offset_left = m
	root.offset_right = -m
	root.offset_top = 20.0
	root.offset_bottom = -20.0


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = tr("Достижения")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	root.add_child(title)

	var stats := Label.new()
	stats.text = "%s: %d    %s: %d" % [tr("Игр"), Progress.games_played, tr("Побед"), Progress.wins]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	stats.modulate = Color(1, 1, 1, 0.6)
	root.add_child(stats)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)

	for a in Achievements.all():
		list.add_child(_row(a, Progress.achievements.has(a.id)))

	root.add_child(_button(tr("Назад"), _on_back))


func _row(a: Dictionary, earned: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var t := Label.new()
	t.text = tr(String(a.title))
	t.add_theme_font_size_override("font_size", 22)
	t.modulate = Color(1.0, 0.85, 0.35) if earned else Color(1, 1, 1, 0.32)
	box.add_child(t)

	var d := Label.new()
	d.text = tr(String(a.desc))
	d.add_theme_font_size_override("font_size", 15)
	d.modulate = Color(1, 1, 1, 0.55) if earned else Color(1, 1, 1, 0.28)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # перенос по ширине колонки
	box.add_child(d)
	return box


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
