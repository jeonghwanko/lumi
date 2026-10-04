extends Control
## Transparent native branding and controls above separate text-free garden art.
signal start_requested
signal settings_requested
const FONT = preload("res://assets/fonts/NotoSansKR-Game.otf")
const BOLD = preload("res://assets/fonts/NotoSansKR-Game-Bold.otf")
const INK = Color("52392e")
const CREAM = Color("fff8e9")
const FOREST = Color("446f56")
var resume_available := false
var transition_started := false
var _logo: Control
var _title: Label
var _subtitle: Label
var _start: Button
var _settings: Button

class CatCup:
	extends Control
	func _draw() -> void:
		var s := minf(size.x / 80.0, size.y / 86.0)
		draw_set_transform(Vector2((size.x - 80.0 * s) / 2.0, 0), 0, Vector2.ONE * s)
		var brown := Color("52392e")
		var cream := Color("fff8e9")
		draw_arc(Vector2(62, 53), 12, -PI * 0.65, PI * 0.65, 28, brown, 4.0, true)
		var cup := StyleBoxFlat.new()
		cup.bg_color = brown
		cup.set_corner_radius_all(13)
		draw_style_box(cup, Rect2(12, 38, 51, 40))
		draw_colored_polygon(PackedVector2Array([Vector2(13, 47), Vector2(15, 25), Vector2(30, 42)]), brown)
		draw_colored_polygon(PackedVector2Array([Vector2(45, 41), Vector2(59, 25), Vector2(63, 49)]), brown)
		draw_circle(Vector2(29, 56), 2.5, cream, true, -1, true)
		draw_circle(Vector2(49, 56), 2.5, cream, true, -1, true)
		draw_circle(Vector2(39, 62), 2.2, cream, true, -1, true)
		draw_arc(Vector2(35.5, 63), 3.5, 0, PI, 12, cream, 1.6, true)
		draw_arc(Vector2(42.5, 63), 3.5, 0, PI, 12, cream, 1.6, true)
		for x in [26.0, 40.0, 54.0]:
			var steam := Curve2D.new()
			steam.add_point(Vector2(x, 20), Vector2.ZERO, Vector2(8, -10))
			steam.add_point(Vector2(x, 3), Vector2(-7, 10), Vector2.ZERO)
			draw_polyline(steam.tessellate(), brown, 3.0, true)

class GearIcon:
	extends Control
	func _draw() -> void:
		var c := size / 2.0
		var brown := Color("52392e")
		for i in 8:
			var direction := Vector2.from_angle(float(i) * TAU / 8.0)
			draw_line(c + direction * 9.0, c + direction * 12.5, brown, 3.5, true)
		draw_arc(c, 8.5, 0, TAU, 36, brown, 3.4, true)
		draw_arc(c, 3.0, 0, TAU, 24, brown, 2.0, true)

class Chevron:
	extends Control
	func _draw() -> void:
		draw_polyline(PackedVector2Array([Vector2(6, size.y / 2 - 6), Vector2(12, size.y / 2), Vector2(6, size.y / 2 + 6)]), Color("fff8e9"), 3.5, true)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_logo = CatCup.new()
	_logo.name = "CatCupLogo"
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	_title = _label("고양이와\n커피", 53, true)
	_title.name = "Title"
	_title.add_theme_constant_override("line_spacing", -3)
	add_child(_title)
	_subtitle = _label("작은 정원에서 시작하는 하루", 18, true)
	_subtitle.name = "Subtitle"
	add_child(_subtitle)
	_start = Button.new()
	_start.name = "StartButton"
	_start.text = "이어하기" if resume_available else "시작하기"
	_start.custom_minimum_size.y = 60
	_start.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_start.add_theme_font_override("font", BOLD)
	_start.add_theme_font_size_override("font_size", 22)
	_style_cta(_start)
	_start.pressed.connect(_start_once)
	add_child(_start)
	var chevron := Chevron.new()
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	chevron.offset_left = -33
	chevron.offset_right = -15
	_start.add_child(chevron)
	_settings = Button.new()
	_settings.name = "SettingsButton"
	_settings.tooltip_text = "설정"
	_settings.accessibility_name = "설정"
	_settings.custom_minimum_size = Vector2(60, 60)
	_settings.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_settings(_settings)
	_settings.pressed.connect(func():
		if not transition_started: settings_requested.emit())
	add_child(_settings)
	var gear := GearIcon.new()
	gear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings.add_child(gear)
	resized.connect(_layout)
	_layout()

func _start_once() -> void:
	if transition_started: return
	transition_started = true
	_start.disabled = true
	_settings.disabled = true
	start_requested.emit()

func _layout() -> void:
	if not is_instance_valid(_start): return
	var w := size.x
	var h := size.y
	var compact := h < 540.0
	var margin := clampf(w * 0.082, 20.0, 48.0)
	var title_size := clampi(int(w * 0.135), 40, 57)
	var logo_y := clampf(h * 0.052, 12.0, 43.0)
	var logo_height := 68.0 if not compact else 45.0
	_logo.visible = h >= 350.0
	_logo.position = Vector2((w - 74.0) / 2.0, logo_y)
	_logo.size = Vector2(74, logo_height)
	_logo.queue_redraw()
	_title.text = "고양이와 커피" if compact else "고양이와\n커피"
	if compact: title_size = clampi(int(w * 0.094), 28, 42)
	_title.add_theme_font_size_override("font_size", title_size)
	var title_y := logo_y + logo_height + (4.0 if compact else 7.0)
	if not _logo.visible: title_y = 65.0
	_title.position = Vector2(margin, title_y)
	# The Korean font's line metrics are taller than its nominal point size.
	var title_height := maxf(64.0, title_size * 1.6) if compact else title_size * 3.0
	_title.size = Vector2(w - margin * 2.0, title_height)
	_subtitle.position = Vector2(12, _title.position.y + _title.size.y + 4.0)
	_subtitle.size = Vector2(w - 24.0, 34.0)
	_subtitle.add_theme_font_size_override("font_size", 16 if w < 350 else 18)
	_subtitle.visible = h >= 280.0
	_start.position = Vector2(margin, maxf(0, h - 80.0))
	_start.size = Vector2(maxf(0, w - margin * 2.0), 60)
	_settings.position = Vector2(maxf(0, w - 66.0), 0)
	_settings.size = Vector2(60, 60)

func _label(value: String, font_size: int, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_override("font", BOLD if bold else FONT)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _style_cta(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = FOREST
		if state == "hover": box.bg_color = Color("507d60")
		if state == "pressed": box.bg_color = Color("335942")
		if state == "disabled": box.bg_color = Color("819780")
		box.border_color = CREAM
		box.set_border_width_all(2)
		box.set_corner_radius_all(30)
		box.content_margin_left = 36
		box.content_margin_right = 36
		if state == "normal":
			box.shadow_color = Color(0.21, 0.25, 0.16, 0.22)
			box.shadow_size = 5
			box.shadow_offset = Vector2(0, 3)
		if state == "focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = Color("edb655")
			box.set_border_width_all(3)
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, CREAM)

func _style_settings(button: Button) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1.0, 0.973, 0.914, 0.78)
		if state == "hover": box.bg_color = CREAM
		if state == "pressed": box.bg_color = Color("e7e4cf")
		if state == "disabled": box.bg_color.a = 0.45
		box.set_corner_radius_all(30)
		if state == "focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = FOREST
			box.set_border_width_all(3)
		button.add_theme_stylebox_override(state, box)
