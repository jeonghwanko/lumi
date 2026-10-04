extends Control
## Live result values rendered over separate text-free celebration artwork.
signal continue_requested
signal retry_requested
const FONT = preload("res://assets/fonts/NotoSansKR-Game.otf")
const BOLD = preload("res://assets/fonts/NotoSansKR-Game-Bold.otf")
const INK = Color("52392e")
const CREAM = Color("fff8e9")
const FOREST = Color("446f56")
var won := false
var first_run := true
var reward := 0
var score := 0
var stars := 0
var reduce_motion := false
var committed := false
## Zero uses a neutral subtitle rather than inventing a puzzle number.
var level_number := 0
var _title: Label
var _subtitle: Label
var _stars: Control
var _reward_badge: PanelContainer
var _reward_label: Label
var _note: Label
var _score: Label
var _continue: Button
var _retry: Button

class ResultStars:
	extends Control
	var filled := 0
	func _draw() -> void:
		var spacing := minf(77, size.x / 3.5)
		var radius := minf(32, size.y * 0.40)
		for i in 3:
			var center := Vector2(size.x / 2.0 + float(i - 1) * spacing, size.y / 2.0 + (0 if i == 1 else 5))
			var points := PackedVector2Array()
			for corner in 10:
				var angle := -PI / 2.0 + float(corner) * PI / 5.0
				points.append(center + Vector2.from_angle(angle) * radius * (1.0 if corner % 2 == 0 else 0.49))
			var is_filled := i < filled
			var shadow := PackedVector2Array()
			for p in points: shadow.append(p + Vector2(0, 3))
			draw_colored_polygon(shadow, Color(0.47, 0.29, 0.10, 0.18))
			draw_colored_polygon(points, Color("edb655") if is_filled else Color("ede4cd"))
			points.append(points[0])
			draw_polyline(points, Color("bd7c32") if is_filled else Color("b5a68b"), 2.5, true)
			if is_filled:
				var highlight := PackedVector2Array([center + Vector2(0, -radius * 0.85), center + Vector2(-radius * 0.30, -radius * 0.10), center + Vector2(-radius * 0.85, -radius * 0.25)])
				draw_colored_polygon(highlight, Color("fff1a4"))

class CoffeeDrop:
	extends Control
	func _draw() -> void:
		var s := minf(size.x / 36.0, size.y / 42.0)
		draw_set_transform((size - Vector2(36, 42) * s) / 2.0, 0, Vector2.ONE * s)
		var outline := PackedVector2Array([Vector2(18, 2), Vector2(9, 15), Vector2(5, 23), Vector2(5, 30), Vector2(9, 37), Vector2(16, 40), Vector2(23, 39), Vector2(29, 34), Vector2(31, 28), Vector2(29, 21), Vector2(24, 12)])
		draw_colored_polygon(outline, Color("874b2d"))
		outline.append(outline[0])
		draw_polyline(outline, Color("52392e"), 2.4, true)
		draw_arc(Vector2(18, 28), 9, 0.1, PI - 0.25, 18, Color("a96a3e"), 3.2, true)
		draw_line(Vector2(13, 17), Vector2(10, 24), Color("fff0ca"), 3.3, true)

class Chevron:
	extends Control
	func _draw() -> void:
		draw_polyline(PackedVector2Array([Vector2(6, size.y / 2 - 6), Vector2(12, size.y / 2), Vector2(6, size.y / 2 + 6)]), Color("fff8e9"), 3.5, true)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title = _label("함께 해냈어요!" if won else "다시 함께 도전해요", 32, true)
	_title.name = "ResultTitle"
	add_child(_title)
	var subtitle := "퍼즐 완료" if won else "조금만 더 힘을 내요"
	if won and level_number > 0:
		subtitle = "첫 번째 퍼즐 완료" if level_number == 1 else "%d번째 퍼즐 완료" % level_number
	_subtitle = _label(subtitle, 19, true)
	_subtitle.name = "ResultSubtitle"
	add_child(_subtitle)
	_stars = ResultStars.new()
	_stars.name = "Stars"
	_stars.filled = clampi(stars, 0, 3) if won else 0
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.visible = won
	add_child(_stars)
	_reward_badge = PanelContainer.new()
	_reward_badge.name = "RewardBadge"
	_reward_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_box := StyleBoxFlat.new()
	badge_box.bg_color = CREAM
	badge_box.set_corner_radius_all(30)
	badge_box.content_margin_left = 19
	badge_box.content_margin_right = 19
	badge_box.content_margin_top = 8
	badge_box.content_margin_bottom = 8
	badge_box.shadow_color = Color(0.40, 0.27, 0.14, 0.13)
	badge_box.shadow_size = 5
	badge_box.shadow_offset = Vector2(0, 3)
	_reward_badge.add_theme_stylebox_override("panel", badge_box)
	_reward_badge.visible = won
	add_child(_reward_badge)
	var reward_row := HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 10)
	reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_badge.add_child(reward_row)
	var drop := CoffeeDrop.new()
	drop.name = "CoffeeDrop"
	drop.custom_minimum_size = Vector2(31, 39)
	drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_row.add_child(drop)
	_reward_label = _label("커피 방울 +%d" % reward, 23, true)
	_reward_label.name = "RewardValue"
	reward_row.add_child(_reward_label)
	_note = _label("정원 카페가 기다리고 있어요" if won else "보상 없이 같은 퍼즐에\n다시 도전할 수 있어요", 17, true)
	_note.name = "ResultNote"
	add_child(_note)
	_score = _label("%d점" % score, 14)
	_score.name = "Score"
	_score.add_theme_color_override("font_color", Color("6f5948"))
	add_child(_score)
	if won or not first_run:
		_continue = _button("카페로 가기", "ContinueButton", won)
		_continue.pressed.connect(func(): _commit_action(false))
		add_child(_continue)
	if not won:
		_retry = _button("다시 시작하기", "RetryButton", true)
		_retry.pressed.connect(func(): _commit_action(true))
		add_child(_retry)
	resized.connect(_layout)
	_layout()
	if not reduce_motion and won:
		_stars.modulate.a = 0
		create_tween().tween_property(_stars, "modulate:a", 1.0, 0.45)

func _commit_action(retry: bool) -> void:
	if committed: return
	committed = true
	if is_instance_valid(_continue): _continue.disabled = true
	if is_instance_valid(_retry): _retry.disabled = true
	if retry: retry_requested.emit()
	else: continue_requested.emit()

func _layout() -> void:
	if not is_instance_valid(_title): return
	var w := size.x
	var h := size.y
	var compact := h < 540.0
	var margin := clampf(w * 0.082, 20.0, 48.0)
	var button_y := maxf(0, h - 80.0)
	var title_y := clampf(h * 0.112, 12.0, 95.0)
	if compact: title_y = 8.0
	_title.add_theme_font_size_override("font_size", clampi(int(w * (0.082 if won else 0.072)), 23, 36))
	_title.position = Vector2(10, title_y)
	_title.size = Vector2(w - 20.0, 52)
	_subtitle.position = Vector2(10, _title.position.y + _title.size.y + 2.0)
	_subtitle.size = Vector2(w - 20.0, 33)
	_subtitle.add_theme_font_size_override("font_size", 17 if w < 350 else 19)
	var stars_y := maxf(_subtitle.position.y + _subtitle.size.y + 12.0, clampf(h * 0.255, 105.0, 217.0))
	_stars.position = Vector2(20, stars_y)
	_stars.size = Vector2(w - 40.0, 80.0 if not compact else 62.0)
	_stars.visible = won
	var badge_width := minf(w - 40.0, 300.0)
	_reward_badge.position = Vector2((w - badge_width) / 2.0, button_y - 120.0)
	_reward_badge.size = Vector2(badge_width, 57)
	_reward_label.add_theme_font_size_override("font_size", 21 if w < 350 else 23)
	_note.position = Vector2(12, button_y - 52.0)
	_note.size = Vector2(w - 24.0, 34)
	_note.add_theme_font_size_override("font_size", 15 if w < 350 else 17)
	_note.visible = true
	_score.position = Vector2(12, _subtitle.position.y + _subtitle.size.y + 2.0)
	_score.size = Vector2(w - 24.0, 25)
	_score.visible = not won and h >= 370.0
	if is_instance_valid(_continue):
		_continue.position = Vector2(margin, button_y)
		_continue.size = Vector2(w - margin * 2.0, 60)
	if is_instance_valid(_retry):
		_retry.position = Vector2(margin, button_y)
		_retry.size = Vector2(w - margin * 2.0, 60)
		if is_instance_valid(_continue):
			_continue.position.y = button_y - 72.0
			_note.position.y = button_y - 131.0
			_note.size.y = 48
		else:
			_note.position.y = button_y - 65.0
			_note.size.y = 48
	# Surrender illustration/ornament space before interactive controls.
	if compact and won:
		_stars.position.y = _subtitle.position.y + _subtitle.size.y + 8.0
		_stars.size.y = clampf(h - 266.0, 32.0, 58.0)
		_note.visible = h >= 440.0
		if not _note.visible: _reward_badge.position.y = button_y - 75.0
		_reward_badge.position.y = maxf(_reward_badge.position.y, _stars.position.y + _stars.size.y + 4.0)
	_stars.queue_redraw()

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

func _button(value: String, node_name: String, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = value
	button.custom_minimum_size.y = 60
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", BOLD)
	button.add_theme_font_size_override("font_size", 21)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = FOREST if primary else CREAM
		if state == "hover": box.bg_color = Color("507d60") if primary else Color("f2ead8")
		if state == "pressed": box.bg_color = Color("335942") if primary else Color("e9ddc5")
		if state == "disabled": box.bg_color = Color("819780") if primary else Color("e7dfd0")
		box.border_color = CREAM if primary else Color("b5c5ac")
		box.set_border_width_all(2)
		box.set_corner_radius_all(30)
		box.content_margin_left = 34
		box.content_margin_right = 34
		if state == "normal":
			box.shadow_color = Color(0.21, 0.25, 0.16, 0.20)
			box.shadow_size = 5
			box.shadow_offset = Vector2(0, 3)
		if state == "focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = Color("edb655")
			box.set_border_width_all(3)
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		button.add_theme_color_override(state, CREAM if primary else INK)
	if primary:
		var chevron := Chevron.new()
		chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chevron.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		chevron.offset_left = -33
		chevron.offset_right = -15
		button.add_child(chevron)
	return button
