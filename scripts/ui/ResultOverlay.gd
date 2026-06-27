extends CanvasLayer
## Оверлей итога партии: затемнение + заголовок результата + кнопки действий.
## Переиспользуемый: setup(title) строит UI; кнопки шлют сигналы, решение — у владельца.

signal rematch
signal to_menu

const COL_PANEL := Color(0.12, 0.14, 0.18, 1.0)


func setup(title_text: String, subtitle: String = "") -> void:
	layer = 10  # поверх HUD

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	col.add_child(title)

	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 22)
		sub.modulate = Color(1.0, 0.85, 0.35)  # золотой акцент — «новое открыто»
		col.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)

	row.add_child(_button(tr("Заново"), func(): rematch.emit()))
	row.add_child(_button(tr("В меню"), func(): to_menu.emit()))


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(180, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b
