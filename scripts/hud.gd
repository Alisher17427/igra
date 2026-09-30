extends CanvasLayer
## Camera HUD: viewfinder frame, lens/film/spirit readout, signal meter, shutter flash, toasts.
## Lives outside the PSX SubViewport so the UI stays sharp.

signal language_chosen(lang: String)

const Loc := preload("res://scripts/loc.gd")

const FRAME_HALF := Vector2(0.22, 0.22)
const COLOR_LOCK := Color(1.0, 0.78, 0.25, 1.0)
const HINT_SECONDS := 14.0
const LENS_NAMES: Array[String] = ["ECTO", "THERMAL", "UV"]
const LENS_COLORS: Array[Color] = [
	Color(0.72, 0.95, 1.0),
	Color(1.0, 0.62, 0.35),
	Color(0.78, 0.6, 1.0),
]

var player: Node3D
var aiming := false
var locked := false
var lens := 0
var film_left := 24
var film_max := 24
var captured_total := 0
var spirits_needed := 3
var objective_kind := "spirit"
var objective_label := "SPIRITS"
var hint_time := 0.0

var tint: ColorRect
var vignette: TextureRect
var viewfinder: Control
var info_label: Label
var hint_label: Label
var toast_label: Label
var flash: ColorRect
var toast_tween: Tween
var hud_font: Font
var prompt_label: Label
var ringing := false
var prompt_time := 0.0
var phone: Node
var subtitle_label: Label
var fade_rect: ColorRect
var title_label: Label
var g_prompt: Label
var g_prompt_time := 0.0
var choice_panel: PanelContainer
var yes_button: Button
var no_button: Button
var choice_open := false
var choice_title: Label
var hint_key := ""
var blur_rect: ColorRect
var language_panel: PanelContainer
var english_button: Button
var russian_button: Button
var language_open := false


func _load_font() -> Font:
	var path := "res://fonts/CuanoFree-Bold.otf"
	if ResourceLoader.exists(path):
		return load(path) as Font
	var font := FontFile.new()
	font.data = FileAccess.get_file_as_bytes(path)
	return font


func _ready() -> void:
	layer = 10
	hud_font = _load_font()

	tint = ColorRect.new()
	_add_overlay(tint)

	vignette = TextureRect.new()
	vignette.texture = _make_vignette()
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_add_overlay(vignette)

	viewfinder = Control.new()
	_add_overlay(viewfinder)
	viewfinder.draw.connect(_draw_viewfinder)

	flash = ColorRect.new()
	flash.color = Color.WHITE
	_add_overlay(flash)
	flash.visible = true
	flash.modulate.a = 0.0

	info_label = _make_label(22, HORIZONTAL_ALIGNMENT_LEFT)
	hint_label = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label = _make_label(28, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.visible = false
	prompt_label = _make_label(34, HORIZONTAL_ALIGNMENT_CENTER)
	prompt_label.visible = false
	subtitle_label = _make_label(32, HORIZONTAL_ALIGNMENT_CENTER)
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.visible = false
	g_prompt = _make_label(38, HORIZONTAL_ALIGNMENT_CENTER)
	g_prompt.visible = false
	_build_choice_panel()

	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	_add_overlay(fade_rect)
	fade_rect.modulate.a = 0.0
	move_child(subtitle_label, -1)
	title_label = _make_label(72, HORIZONTAL_ALIGNMENT_CENTER)
	title_label.visible = false

	blur_rect = ColorRect.new()
	var blur_material := ShaderMaterial.new()
	blur_material.shader = load("res://shaders/blur.gdshader") as Shader
	blur_rect.material = blur_material
	_add_overlay(blur_rect)
	blur_rect.visible = false
	_build_language_panel()

	_apply_lens_look()
	_set_overlays_visible(false)
	refresh_texts()


func set_hint(text: String) -> void:
	hint_key = text
	hint_label.text = Loc.t(hint_key)
	hint_label.reset_size()
	hint_label.visible = true
	hint_time = 0.0


func refresh_texts() -> void:
	prompt_label.text = Loc.t("INCOMING CALL\nPress F to answer")
	g_prompt.text = Loc.t("Press G")
	choice_title.text = Loc.t("YOUR ANSWER")
	yes_button.text = Loc.t("Yes")
	no_button.text = Loc.t("No")
	if not hint_key.is_empty():
		hint_label.text = Loc.t(hint_key)
		hint_label.reset_size()
	if aiming:
		_update_info()


func show_language_menu() -> void:
	language_open = true
	blur_rect.visible = true
	language_panel.visible = true
	language_panel.reset_size()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	english_button.grab_focus()


func _choose_language(chosen: String) -> void:
	if not language_open:
		return
	language_open = false
	Loc.lang = chosen
	language_panel.visible = false
	blur_rect.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	refresh_texts()
	language_chosen.emit(chosen)


func _build_language_panel() -> void:
	language_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.07, 0.9)
	panel_style.border_color = Color(0.72, 0.95, 1.0, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(36)
	language_panel.add_theme_stylebox_override("panel", panel_style)
	language_panel.visible = false

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	language_panel.add_child(box)

	var title := Label.new()
	title.text = "Choose language  /  Выберите язык"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", hud_font)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0))
	box.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	english_button = _make_choice_button("English")
	russian_button = _make_choice_button("Русский")
	english_button.custom_minimum_size = Vector2(220.0, 62.0)
	russian_button.custom_minimum_size = Vector2(220.0, 62.0)
	english_button.pressed.connect(_choose_language.bind("en"))
	russian_button.pressed.connect(_choose_language.bind("ru"))
	row.add_child(english_button)
	row.add_child(russian_button)
	add_child(language_panel)


func bind_player(p: Node) -> void:
	captured_total = 0
	ringing = false
	choice_open = false
	prompt_label.visible = false
	g_prompt.visible = false
	choice_panel.visible = false
	subtitle_label.visible = false
	_set_overlays_visible(false)
	aiming = false
	player = p as Node3D
	film_left = int(p.get("film_left"))
	film_max = film_left
	p.connect(&"aim_changed", _on_aim_changed)
	p.connect(&"lens_changed", _on_lens_changed)
	p.connect(&"frame_lock_changed", _on_frame_lock_changed)
	p.connect(&"photo_taken", _on_photo_taken)
	p.connect(&"out_of_film", _on_out_of_film)
	p.connect(&"film_reloaded", _on_film_reloaded)
	var car := p.get_parent().get_node_or_null("CarDrop")
	if car != null:
		car.connect(&"landed", _on_car_landed)
		car.connect(&"blackout", _on_blackout)
		car.connect(&"subtitle_changed", _on_subtitle_changed)
	phone = p.get_node_or_null("PhoneCall")
	if phone != null:
		var night_cfg: Dictionary = phone.get("cfg")
		spirits_needed = int(night_cfg["needed"])
		objective_kind = night_cfg["objective"]
		objective_label = night_cfg["objective_label"]
		phone.connect(&"ring_started", _on_ring_started)
		phone.connect(&"answered", _on_call_answered)
		phone.connect(&"choice_requested", _open_choice)
		phone.connect(&"subtitle_changed", _on_subtitle_changed)


func _process(delta: float) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	if aiming:
		_update_info()
	if hint_label.visible:
		hint_time += delta
		if hint_time > HINT_SECONDS:
			hint_label.visible = false
	info_label.position = Vector2(28.0, vp_size.y - 28.0 - info_label.size.y)
	hint_label.position = Vector2((vp_size.x - hint_label.size.x) * 0.5, vp_size.y - 36.0 - hint_label.size.y)
	toast_label.position = Vector2((vp_size.x - toast_label.size.x) * 0.5, vp_size.y * 0.5)
	subtitle_label.custom_minimum_size.x = vp_size.x * 0.6
	subtitle_label.position = Vector2((vp_size.x - subtitle_label.size.x) * 0.5, vp_size.y * 0.74)
	title_label.position = ((vp_size - title_label.size) * 0.5).floor()
	if g_prompt.visible:
		g_prompt_time += delta
		g_prompt.modulate.a = 0.65 + 0.35 * sin(g_prompt_time * 6.0)
		g_prompt.position = Vector2((vp_size.x - g_prompt.size.x) * 0.5, vp_size.y * 0.16)
	if choice_open:
		choice_panel.position = ((vp_size - choice_panel.size) * 0.5).floor()
	if language_open:
		language_panel.position = ((vp_size - language_panel.size) * 0.5).floor()
	if ringing:
		prompt_time += delta
		prompt_label.modulate.a = 0.65 + 0.35 * sin(prompt_time * 6.0)
		prompt_label.position = Vector2((vp_size.x - prompt_label.size.x) * 0.5, vp_size.y * 0.16)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if language_open:
		if key.physical_keycode == KEY_1 or key.physical_keycode == KEY_E:
			_choose_language("en")
		elif key.physical_keycode == KEY_2 or key.physical_keycode == KEY_R:
			_choose_language("ru")
		return
	if not choice_open:
		return
	if key.physical_keycode == KEY_1 or key.physical_keycode == KEY_Y:
		_choose("Yes")
	elif key.physical_keycode == KEY_2 or key.physical_keycode == KEY_N:
		_choose("No")


func _build_choice_panel() -> void:
	choice_panel = PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.07, 0.94)
	panel_style.border_color = Color(0.72, 0.95, 1.0, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(30)
	choice_panel.add_theme_stylebox_override("panel", panel_style)
	choice_panel.visible = false

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	choice_panel.add_child(box)

	var title := Label.new()
	title.text = "YOUR ANSWER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", hud_font)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0))
	box.add_child(title)
	choice_title = title

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	yes_button = _make_choice_button("Yes")
	no_button = _make_choice_button("No")
	yes_button.pressed.connect(_choose.bind("Yes"))
	no_button.pressed.connect(_choose.bind("No"))
	row.add_child(yes_button)
	row.add_child(no_button)
	add_child(choice_panel)


func _make_choice_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170.0, 58.0)
	button.add_theme_font_override("font", hud_font)
	button.add_theme_font_size_override("font_size", 28)
	button.add_theme_color_override("font_color", Color(0.95, 1.0, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.4))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.85, 0.4))
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.2, 0.18, 1.0) if state_name != "hover" else Color(0.2, 0.3, 0.26, 1.0)
		style.border_color = Color(1.0, 0.78, 0.25, 1.0) if state_name == "focus" else Color(0.72, 0.95, 1.0, 0.6)
		style.set_border_width_all(2)
		button.add_theme_stylebox_override(state_name, style)
	return button


func _open_choice() -> void:
	choice_open = true
	choice_panel.visible = true
	choice_panel.reset_size()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	yes_button.grab_focus()


func _choose(answer: String) -> void:
	if not choice_open:
		return
	choice_open = false
	choice_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_toast(Loc.t("YOU ANSWERED: " + answer.to_upper()), Color(0.85, 1.0, 0.85))
	if phone != null:
		phone.call("submit_choice", answer)


func _add_overlay(control: Control) -> void:
	add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_label(font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.add_theme_font_override("font", hud_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.95, 1.0, 0.95))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)
	return label


func _make_vignette() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.75)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _set_overlays_visible(value: bool) -> void:
	tint.visible = value
	vignette.visible = value
	viewfinder.visible = value
	info_label.visible = value


func _apply_lens_look() -> void:
	var c := LENS_COLORS[lens]
	tint.color = Color(c.r, c.g, c.b, 0.13)
	viewfinder.queue_redraw()


func _draw_viewfinder() -> void:
	var vp_size := viewfinder.size
	var half := vp_size * FRAME_HALF
	var center := vp_size * 0.5
	var frame := Rect2(center - half, half * 2.0)
	var base := LENS_COLORS[lens]
	var color := COLOR_LOCK if locked else Color(base.r, base.g, base.b, 0.95)
	var arm := minf(frame.size.x, frame.size.y) * 0.16
	var top_left := frame.position
	var top_right := Vector2(frame.end.x, frame.position.y)
	var bottom_left := Vector2(frame.position.x, frame.end.y)
	var bottom_right := frame.end
	var w := 3.0
	viewfinder.draw_line(top_left, top_left + Vector2(arm, 0.0), color, w)
	viewfinder.draw_line(top_left, top_left + Vector2(0.0, arm), color, w)
	viewfinder.draw_line(top_right, top_right + Vector2(-arm, 0.0), color, w)
	viewfinder.draw_line(top_right, top_right + Vector2(0.0, arm), color, w)
	viewfinder.draw_line(bottom_left, bottom_left + Vector2(arm, 0.0), color, w)
	viewfinder.draw_line(bottom_left, bottom_left + Vector2(0.0, -arm), color, w)
	viewfinder.draw_line(bottom_right, bottom_right + Vector2(-arm, 0.0), color, w)
	viewfinder.draw_line(bottom_right, bottom_right + Vector2(0.0, -arm), color, w)
	viewfinder.draw_line(center - Vector2(10.0, 0.0), center + Vector2(10.0, 0.0), color, 2.0)
	viewfinder.draw_line(center - Vector2(0.0, 10.0), center + Vector2(0.0, 10.0), color, 2.0)


func _update_info() -> void:
	var strength := _signal_strength()
	var meter := "#".repeat(strength) + "-".repeat(5 - strength)
	info_label.text = "%s  %s  (%d/%d)\n%s  %02d/%02d\n%s  %d/%d\n%s  [%s]" % [
		Loc.t("LENS"), Loc.t(LENS_NAMES[lens]), lens + 1, LENS_NAMES.size(),
		Loc.t("FILM"), film_left, film_max,
		Loc.t(objective_label), captured_total, spirits_needed,
		Loc.t("SIGNAL"), meter
	]
	info_label.reset_size()


func _signal_strength() -> int:
	if player == null:
		return 0
	var origin := player.global_position
	var nearest := 1000.0
	for node in get_tree().get_nodes_in_group("spirits"):
		var spirit := node as Node3D
		if spirit == null or not spirit.call("is_capturable"):
			continue
		if int(spirit.get("lens")) != lens or String(spirit.get("kind")) != objective_kind:
			continue
		nearest = minf(nearest, origin.distance_to(spirit.global_position))
	if nearest < 6.0:
		return 5
	if nearest < 10.0:
		return 4
	if nearest < 15.0:
		return 3
	if nearest < 22.0:
		return 2
	if nearest < 32.0:
		return 1
	return 0


func _show_toast(text: String, color: Color) -> void:
	toast_label.text = text
	toast_label.reset_size()
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	toast_label.visible = true
	if toast_tween != null and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(1.8)
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)


func _on_aim_changed(is_aiming: bool) -> void:
	aiming = is_aiming
	_set_overlays_visible(aiming)
	if aiming:
		hint_label.visible = false
		_update_info()


func _on_lens_changed(index: int) -> void:
	lens = index
	_apply_lens_look()
	_update_info()


func _on_frame_lock_changed(is_locked: bool) -> void:
	locked = is_locked
	viewfinder.queue_redraw()


func _on_photo_taken(report: Array, film: int) -> void:
	film_left = film
	flash.modulate.a = 0.9
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.45)
	if report.is_empty():
		_show_toast(Loc.t("Nothing in frame"), Color(0.78, 0.82, 0.8))
	else:
		var lines := PackedStringArray()
		var found_clue := false
		var clue_note := ""
		for entry in report:
			lines.append("%s  %d%%" % [Loc.t(entry["name"]), int(round(float(entry["score"]) * 100.0))])
			if entry["kind"] == objective_kind:
				captured_total += 1
			if entry["kind"] == "clue":
				found_clue = true
				clue_note = entry["note"]
		var header := Loc.t("CLUE FOUND" if found_clue else "SPIRIT CAPTURED")
		_show_toast(header + "\n" + "\n".join(lines), COLOR_LOCK)
		if found_clue and not clue_note.is_empty():
			_show_note(clue_note)
	_update_info()


func _show_note(text: String) -> void:
	_on_subtitle_changed(text)
	await get_tree().create_timer(5.0).timeout
	if subtitle_label.text == Loc.t(text):
		_on_subtitle_changed("")


func _on_ring_started() -> void:
	ringing = true
	prompt_time = 0.0
	prompt_label.reset_size()
	prompt_label.visible = true


func _set_master_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(0, db)


func show_title(text: String) -> void:
	title_label.text = Loc.t(text)
	title_label.reset_size()
	title_label.visible = true


func hide_title() -> void:
	title_label.visible = false


func fade_in(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)


func _on_car_landed() -> void:
	g_prompt_time = 0.0
	g_prompt.reset_size()
	g_prompt.visible = true


func _on_blackout() -> void:
	g_prompt.visible = false
	var audio_tween := create_tween()
	audio_tween.tween_method(_set_master_volume, AudioServer.get_bus_volume_db(0), -80.0, 1.6)
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.6)


func _on_subtitle_changed(text: String) -> void:
	subtitle_label.text = Loc.t(text)
	subtitle_label.reset_size()
	subtitle_label.visible = not text.is_empty()


func _on_call_answered() -> void:
	ringing = false
	prompt_label.visible = false
	_show_toast(Loc.t("CALL CONNECTED"), Color(0.85, 1.0, 0.85))


func _on_out_of_film() -> void:
	_show_toast(Loc.t("OUT OF FILM - changing roll..."), Color(1.0, 0.6, 0.5))


func _on_film_reloaded(film: int) -> void:
	film_left = film
	_show_toast(Loc.t("New roll loaded"), Color(0.85, 1.0, 0.85))
	_update_info()
