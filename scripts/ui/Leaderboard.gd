extends Control
## Таблица лидеров. Запись в лидерборд требует авторизации в профиле Яндекса
## (требование SDK). Аноним видит свой локальный рейтинг и приглашение войти —
## сама таблица для него неактивна, пока он не авторизуется.

const COL_BG := Color(0.09, 0.11, 0.14)

var col: VBoxContainer
var status_label: Label
var auth_box: VBoxContainer
var list_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	if YandexSDK.available:
		_start_online()
	elif OS.has_feature("web"):
		# SDK ещё инициализируется (~1с) — ждём готовности, не падаем в офлайн.
		status_label.text = tr("Загрузка…")
		YandexSDK.sdk_ready.connect(_start_online, CONNECT_ONE_SHOT)
	else:
		# Вне Яндекса (десктоп/локально) — только локальный рейтинг.
		status_label.text = tr("Таблица лидеров доступна в Яндекс.Играх")


func _relayout() -> void:
	if col == null:
		return
	var w: float = minf(get_viewport_rect().size.x - 24.0, 560.0)
	col.custom_minimum_size.x = w
	if status_label:
		status_label.custom_minimum_size.x = w - 20.0


func _start_online() -> void:
	YandexSDK.leaderboard_loaded.connect(_on_loaded)
	YandexSDK.auth_changed.connect(_on_auth)
	if YandexSDK.is_authorized():
		_load_entries()
	else:
		_show_auth_prompt()


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
	title.text = tr("Таблица лидеров")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	col.add_child(title)

	var mine := Label.new()
	mine.text = tr("Ваш рейтинг") + ": " + str(Progress.score)
	mine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mine.add_theme_font_size_override("font_size", 22)
	mine.modulate = Color(1.0, 0.85, 0.35)
	col.add_child(mine)
	col.add_child(_gap(8))

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.modulate = Color(1, 1, 1, 0.65)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(540, 0)
	col.add_child(status_label)

	auth_box = VBoxContainer.new()
	auth_box.add_theme_constant_override("separation", 8)
	col.add_child(auth_box)

	list_box = VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 6)
	col.add_child(list_box)

	col.add_child(_gap(12))
	col.add_child(_button(tr("Назад"), _on_back))


## Авторизован — грузим записи таблицы.
func _load_entries() -> void:
	for c in auth_box.get_children():
		c.queue_free()
	status_label.visible = true
	status_label.text = tr("Загрузка…")
	YandexSDK.request_leaderboard()


## Аноним — приглашение войти; таблица неактивна.
func _show_auth_prompt() -> void:
	status_label.visible = true
	status_label.text = tr("Войдите в профиль Яндекса, чтобы участвовать в таблице")
	auth_box.add_child(_button(tr("Войти"), _on_login))


func _on_login() -> void:
	YandexSDK.prompt_auth()


func _on_auth(ok: bool) -> void:
	if not ok:
		return  # вход отменён — оставляем приглашение
	YandexSDK.submit_score(Progress.score)  # дослать накопленный рейтинг
	_load_entries()


func _on_loaded(entries: Array) -> void:
	for child in list_box.get_children():
		child.queue_free()
	if entries.is_empty():
		status_label.text = tr("Пока нет записей")
		return
	status_label.visible = false
	for e in entries:
		var row := Label.new()
		var nm: String = String(e.get("name", ""))
		if nm == "":
			nm = tr("Игрок")
		row.text = "%d.  %s  —  %d" % [int(e.get("rank", 0)), nm, int(e.get("score", 0))]
		row.add_theme_font_size_override("font_size", 20)
		list_box.add_child(row)


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
