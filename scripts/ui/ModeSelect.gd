extends Control
## Выбор партии: вариант + сторона + сложность → запись в GameConfig и старт игры.

const TaflVariants = preload("res://scripts/core/TaflVariants.gd")
const COL_BG := Color(0.09, 0.11, 0.14)
const VARIANT_IDS := ["brandubh", "tablut", "fetlar", "copenhagen"]
const DIFF_IDS := ["easy", "normal", "hard"]

var _variant: String = GameConfig.variant
var _side: String = GameConfig.human_side
var _difficulty: String = GameConfig.difficulty

var desc_label: Label
var root: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()


## Адаптивная ширина колонки: до 600px, но не шире экрана (узкие телефоны).
func _relayout() -> void:
	if root == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var w: float = minf(vp.x - 24.0, 600.0)
	var m: float = (vp.x - w) * 0.5
	root.offset_left = m
	root.offset_right = -m
	root.offset_top = 16.0
	root.offset_bottom = -16.0


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = COL_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Корневая колонка: заголовок (сверху) + прокручиваемая форма + кнопки (снизу,
	# всегда видимы — раньше «Назад/Начать» уезжали за нижний край экрана).
	root = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title := Label.new()
	title.text = tr("Выбор партии")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 10)
	scroll.add_child(form)

	# Если сохранённый режим/сложность ещё закрыты — берём самые дальние открытые.
	if not Progress.is_unlocked(_variant):
		_variant = Progress.highest_unlocked()
	if not Progress.difficulty_unlocked(_difficulty):
		_difficulty = Progress.highest_difficulty()

	# --- Вариант (режим) ---
	var var_opts: Array = []
	var var_tips: Dictionary = {}
	var var_locked: Dictionary = {}
	for id in VARIANT_IDS:
		var unlocked: bool = Progress.is_unlocked(id)
		var label: String = _variant_label(id)
		if not unlocked:
			label += "  ·  " + tr("закрыто")
		var_opts.append([id, label])
		var_tips[id] = _variant_desc(id) if unlocked else _locked_hint(id)
		var_locked[id] = not unlocked
	_section(form, tr("Режим"), _radio(var_opts, _variant, _on_variant_pick, true, var_tips, var_locked))

	# Описание выбранного режима (работает и на тач-устройствах, без hover).
	desc_label = Label.new()
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.modulate = Color(1, 1, 1, 0.8)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(520, 0)
	form.add_child(desc_label)
	form.add_child(_gap(4))
	_update_desc(_variant)

	# --- Сторона ---
	var side_opts := [
		["defenders", tr("Защитники (король)")],
		["attackers", tr("Осаждающие")],
	]
	_section(form, tr("Сторона"), _radio(side_opts, _side, func(v): _side = v, false))

	# --- Сложность ИИ (открывается по прохождению) ---
	var diff_labels := {"easy": tr("Лёгкий"), "normal": tr("Обычный"), "hard": tr("Сложный")}
	var diff_opts: Array = []
	var diff_tips: Dictionary = {}
	var diff_locked: Dictionary = {}
	for d in DIFF_IDS:
		var d_unlocked: bool = Progress.difficulty_unlocked(d)
		# Кнопки сложности узкие (3 в ряд) — приписку не лепим, закрытая просто серая
		# и неактивная, плюс подсказка при наведении.
		diff_opts.append([d, String(diff_labels[d])])
		diff_locked[d] = not d_unlocked
		if not d_unlocked:
			diff_tips[d] = _diff_locked_hint(d, diff_labels)
	_section(form, tr("Сложность ИИ"), _radio(diff_opts, _difficulty, func(v): _difficulty = v, false, diff_tips, diff_locked))

	# --- Кнопки (фиксированы внизу экрана) ---
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var back := _button(tr("Назад"), _on_back)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var start := _button(tr("Начать"), _on_start)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(back)
	row.add_child(start)
	root.add_child(row)


func _variant_label(id: String) -> String:
	var v: Dictionary = TaflVariants.get_variant(id)
	return String(v.get("label_" + Settings.locale, v.get("label_en", id)))


func _variant_desc(id: String) -> String:
	var v: Dictionary = TaflVariants.get_variant(id)
	return String(v.get("desc_" + Settings.locale, v.get("desc_en", "")))


## Подсказка для закрытого режима: какой предыдущий режим надо пройти.
func _locked_hint(id: String) -> String:
	var i: int = VARIANT_IDS.find(id)
	var prev: String = _variant_label(VARIANT_IDS[i - 1]) if i > 0 else ""
	return tr("Откроется после победы на «Обычном» в режиме") + ": " + prev


## Подсказка для закрытой сложности: какую предыдущую надо пройти.
func _diff_locked_hint(d: String, labels: Dictionary) -> String:
	var i: int = DIFF_IDS.find(d)
	var prev: String = String(labels.get(DIFF_IDS[i - 1], "")) if i > 0 else ""
	return tr("Откроется после победы на сложности") + ": " + prev


func _update_desc(id) -> void:
	desc_label.text = _variant_desc(String(id))


func _on_variant_pick(v) -> void:
	_variant = String(v)
	_update_desc(v)


func _section(col: VBoxContainer, title: String, content: Control) -> void:
	var h := Label.new()
	h.text = title
	h.add_theme_font_size_override("font_size", 22)
	h.modulate = Color(1, 1, 1, 0.7)
	col.add_child(h)
	col.add_child(content)
	col.add_child(_gap(4))


## Группа взаимоисключающих кнопок (radio). options: Array of [value, text].
## tips (optional): value → текст всплывающей подсказки (hover на десктопе).
func _radio(options: Array, current, on_pick: Callable, vertical: bool,
		tips: Dictionary = {}, locked: Dictionary = {}) -> Control:
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
		if tips.has(opt[0]):
			b.tooltip_text = String(tips[opt[0]])
		if bool(locked.get(opt[0], false)):
			b.disabled = true  # закрытый режим — выбрать нельзя
		elif opt[0] == current:
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
