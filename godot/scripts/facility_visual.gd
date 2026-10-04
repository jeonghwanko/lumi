extends Control
## One placed, owned facility or decoration. Static art does not imply an animation atlas.
var item_id := ""
var cat_id := ""
var decoration := false
var selected := false
var display_name := ""
var level := 1
var visual_scale := 1.0
var has_entrance_art := false
var embedded_cat := false
var _facility_art: TextureRect
var _cat_art: TextureRect
var _placeholder_label: Label
var _cat_label: Label

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_facility_art = _image_node("FacilityArt")
	_cat_art = _image_node("CatArt")
	_placeholder_label = _text_node("PlaceholderLabel")
	_cat_label = _text_node("CatPlaceholderLabel")

func _image_node(node_name: String) -> TextureRect:
	var node := TextureRect.new()
	node.name = node_name
	node.mouse_filter = MOUSE_FILTER_IGNORE
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(node)
	return node

func _text_node(node_name: String) -> Label:
	var node := Label.new()
	node.name = node_name
	node.mouse_filter = MOUSE_FILTER_IGNORE
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_color_override("font_color", Color("655348"))
	node.add_theme_color_override("font_outline_color", Color("fff8e9"))
	node.add_theme_constant_override("outline_size", 3)
	node.add_theme_font_size_override("font_size", 11)
	add_child(node)
	return node

func configure(id: String, is_decor: bool, data: Dictionary, owned: Dictionary,
		art: Texture2D, cat_art: Texture2D, art_has_cat: bool, scale_factor: float, is_selected: bool) -> void:
	item_id = id
	decoration = is_decor
	display_name = str(data.get("name", id))
	cat_id = "" if decoration else str(data.get("catId", ""))
	level = int(owned.get("level", 1))
	selected = is_selected
	visual_scale = scale_factor
	embedded_cat = art_has_cat and art != null and not decoration
	has_entrance_art = art != null and not decoration
	set_meta("item_id", item_id)
	set_meta("decoration", decoration)
	set_meta("cat_id", cat_id)
	set_meta("static_art_only", true)
	# No timeline, tween or fabricated frames. Catalog atlas contracts remain unchanged.
	_facility_art.texture = art
	_facility_art.visible = has_entrance_art
	_facility_art.position = Vector2(-93, -166) * visual_scale
	_facility_art.size = Vector2(186, 194) * visual_scale
	_cat_art.texture = cat_art
	_cat_art.visible = not cat_id.is_empty() and cat_art != null and not embedded_cat
	_cat_art.set_meta("cat_id", cat_id)
	# Natural cats stay small relative to their entrance, including on wide layouts.
	_cat_art.position = Vector2(-19, -30) * visual_scale
	_cat_art.size = Vector2(38, 48) * visual_scale
	_placeholder_label.visible = not has_entrance_art
	_placeholder_label.text = display_name + ("" if decoration else " · " + str(level)) + "\n임시 그림"
	_placeholder_label.position = Vector2(-67, 35) * visual_scale
	_placeholder_label.size = Vector2(134, 32) * visual_scale
	_cat_label.visible = has_entrance_art and not embedded_cat and not cat_id.is_empty() and cat_art == null
	_cat_label.text = "고양이 임시 그림"
	_cat_label.position = Vector2(-64, 22) * visual_scale
	_cat_label.size = Vector2(128, 20) * visual_scale
	queue_redraw()

func visual_bounds() -> Rect2:
	if decoration: return Rect2(Vector2(-24, -28) * visual_scale, Vector2(48, 58) * visual_scale)
	if has_entrance_art: return Rect2(Vector2(-93, -166) * visual_scale, Vector2(186, 194) * visual_scale)
	return Rect2(Vector2(-48, -54) * visual_scale, Vector2(96, 86) * visual_scale)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * visual_scale)
	if decoration:
		_ellipse(Vector2(0, 14), Vector2(20, 6), Color(0.22, 0.29, 0.19, 0.13))
		var pot := PackedVector2Array([Vector2(-12, -2), Vector2(12, -2), Vector2(9, 17), Vector2(-9, 17)])
		draw_colored_polygon(pot, Color("cfb18b"))
		draw_circle(Vector2(-7, -11), 11, Color("94b787"))
		draw_circle(Vector2(7, -15), 12, Color("b8cba0"))
		draw_circle(Vector2(0, -21), 10, Color("a5bf8e"))
	else:
		if not has_entrance_art:
			_ellipse(Vector2(0, 23), Vector2(44, 10), Color(0.22, 0.29, 0.19, 0.13))
			if item_id == "f19": _draw_entrance_placeholder()
			else: _draw_facility_placeholder()
		if not cat_id.is_empty() and not embedded_cat and _cat_art.texture == null:
			_draw_cat_placeholder()
	if selected:
		_ellipse(Vector2(0, 22), Vector2(46 if not decoration else 25, 12), Color("edb655"), false)
	draw_set_transform(Vector2.ZERO)

func _draw_entrance_placeholder() -> void:
	# Explicit draft entrance silhouette, replaced only when entrance art is supplied.
	_round_rect(Rect2(-37, -53, 8, 73), Color("bd9c72"), 3)
	_round_rect(Rect2(29, -53, 8, 73), Color("bd9c72"), 3)
	_round_rect(Rect2(-43, -58, 86, 13), Color("8eae89"), 5)
	_round_rect(Rect2(-35, -45, 70, 12), Color("fff8e9"), 3)
	for x in [-26, -3, 20]:
		_round_rect(Rect2(x, -45, 13, 12), Color("b8cba0"), 3)
	draw_line(Vector2(23, -32), Vector2(23, -22), Color("9f8460"), 2)
	draw_circle(Vector2(23, -19), 5, Color("dbba78"))
	_round_rect(Rect2(-40, 14, 80, 12), Color("e8d8b6"), 4)

func _draw_facility_placeholder() -> void:
	# An understated labeled stand, never a claim that a missing facility is final art.
	_round_rect(Rect2(-37, -21, 74, 41), Color("e2d9c4"), 10)
	_round_rect(Rect2(-40, -25, 80, 12), Color("b8cba0"), 5)
	_round_rect(Rect2(-32, 16, 7, 12), Color("bdac8d"), 2)
	_round_rect(Rect2(25, 16, 7, 12), Color("bdac8d"), 2)

func _draw_cat_placeholder() -> void:
	# Small natural-coat placeholder, never one of the six puzzle tokens.
	var origin := Vector2(-3, 5)
	_ellipse(origin + Vector2(0, 11), Vector2(13, 4), Color(0.22, 0.29, 0.19, 0.15))
	draw_arc(origin + Vector2(-10, 3), 8, 0.4, 4.9, 12, Color("9a7861"), 4, true)
	_ellipse(origin + Vector2(0, 2), Vector2(9, 12), Color("fff8e9"))
	draw_colored_polygon(PackedVector2Array([origin + Vector2(-9, -8), origin + Vector2(-9, -21), origin + Vector2(-1, -14)]), Color("be916e"))
	draw_colored_polygon(PackedVector2Array([origin + Vector2(1, -14), origin + Vector2(9, -21), origin + Vector2(9, -8)]), Color("66574c"))
	draw_circle(origin + Vector2(0, -10), 10, Color("fff8e9"))
	draw_circle(origin + Vector2(-6, -13), 5, Color("cda47f"))
	draw_circle(origin + Vector2(-4, -10), 1.2, Color("52392e"))
	draw_circle(origin + Vector2(4, -10), 1.2, Color("52392e"))
	draw_circle(origin + Vector2(0, -6), 1.3, Color("b08073"))
	draw_line(origin + Vector2(-6, 0), origin + Vector2(6, 0), Color("8dad8d"), 4, true)

func _round_rect(rect: Rect2, color: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func _ellipse(center: Vector2, radius: Vector2, color: Color, filled := true) -> void:
	var points := PackedVector2Array()
	for index in 32:
		points.append(center + Vector2.from_angle(float(index) / 32.0 * TAU) * radius)
	if filled: draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		draw_polyline(points, color, 2, true)
