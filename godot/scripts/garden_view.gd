extends Control
signal item_selected(id: String, decoration: bool)
signal position_changed(id: String, decoration: bool, position: Dictionary)

const FacilityVisual = preload("res://scripts/facility_visual.gd")
var state: Dictionary = {}
var catalog: Dictionary = {}
var editing := false
var facility_layout: Dictionary = {}
var decor_layout: Dictionary = {}
var drag_id := ""
var drag_decor := false
var touch_id := -1
var highlighted := ""
# Home overlays the parent's full-bleed landscape. Editor/memory views remain self-contained.
var presentation_mode := false:
	set(value):
		presentation_mode = value
		_refresh_visuals()
# Logical placement data stays in the original 0–100 coordinate system.
# This one affine mapping controls both drawing and pointer input in the home scene.
var presentation_rect := Rect2(0.10, 0.30, 0.54, 0.58):
	set(value):
		presentation_rect = value
		_refresh_visuals()
var entrance_contains_cat := false:
	set(value):
		entrance_contains_cat = value
		_refresh_visuals()
var entrance_texture: Texture2D
var cat_texture: Texture2D
var _visuals: Dictionary = {}
# Settings/developer diagnostics may show these IDs without covering the home landscape.
var needs_art: Array[String] = []

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	var minimum := Vector2(120, 120) if presentation_mode and not editing else Vector2(260, 300)
	custom_minimum_size = Vector2(maxf(custom_minimum_size.x, minimum.x), maxf(custom_minimum_size.y, minimum.y))
	resized.connect(_refresh_visuals)
	_refresh_visuals()

func set_state(value: Dictionary, data: Dictionary) -> void:
	state = value
	catalog = data
	_refresh_visuals()

func set_art(entrance: Texture2D = null, cat: Texture2D = null, entrance_has_cat := false) -> void:
	# No hard-coded preload: missing production art is a clearly labeled vector placeholder.
	entrance_texture = _trim_transparent_texture(entrance)
	cat_texture = _trim_transparent_texture(cat)
	entrance_contains_cat = entrance_has_cat
	_refresh_visuals()

func _trim_transparent_texture(texture: Texture2D) -> Texture2D:
	if texture == null: return null
	var image := texture.get_image()
	if image == null or image.is_empty(): return texture
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0: return texture
	if used == Rect2i(Vector2i.ZERO, image.get_size()): return texture
	var trimmed := AtlasTexture.new()
	trimmed.atlas = texture
	trimmed.region = Rect2(used)
	trimmed.filter_clip = true
	return trimmed

func positions(decor: bool) -> Dictionary:
	if editing: return decor_layout if decor else facility_layout
	var out: Dictionary = {}
	for id in state.get("decorOwned" if decor else "owned", {}):
		out[id] = state["decorOwned" if decor else "owned"][id].position
	return out

func placement_rect() -> Rect2:
	if presentation_mode and not editing:
		return Rect2(presentation_rect.position * size, presentation_rect.size * size)
	return Rect2(Vector2.ZERO, size)

func normalized_to_local(value: Dictionary) -> Vector2:
	var area := placement_rect()
	return area.position + Vector2(float(value.x), float(value.y)) / 100.0 * area.size

func local_to_normalized(point: Vector2) -> Dictionary:
	var area := placement_rect()
	var relative := (point - area.position) / Vector2(maxf(area.size.x, 1), maxf(area.size.y, 1)) * 100.0
	return {"x": clampf(relative.x, 8, 92), "y": clampf(relative.y, 12, 87)}

func _item_data(id: String, decor: bool) -> Dictionary:
	for item in catalog.get("decorations" if decor else "facilities", []):
		if str(item.id) == id: return item
	return {}

func _refresh_visuals() -> void:
	var present: Dictionary = {}
	needs_art.clear()
	var scale_factor := clampf(size.x / 390.0, 0.65, 1.55) if presentation_mode and not editing else clampf(size.x / 390.0, 0.7, 1.05)
	for decor in [true, false]:
		var owned: Dictionary = state.get("decorOwned" if decor else "owned", {})
		var layout := positions(decor)
		for id in layout:
			# A draft never grants ownership. Null positions are in storage, not on the ground.
			if not owned.has(id) or layout[id] == null: continue
			var data := _item_data(str(id), decor)
			# Floor/path purchases are surface state, not potted plants or movable objects.
			if decor and data.get("kind", "") in ["floor", "path"]: continue
			var key := ("decor:" if decor else "facility:") + str(id)
			present[key] = true
			if not _visuals.has(key):
				var visual := FacilityVisual.new()
				visual.name = ("Decoration_" if decor else "Facility_") + str(id)
				add_child(visual)
				_visuals[key] = visual
			var node: Control = _visuals[key]
			var facility_art: Texture2D = entrance_texture if not decor and id == "f19" else null
			var natural_cat_art: Texture2D = cat_texture if not decor and data.get("catId", "") == "cat19" else null
			var has_embedded_cat: bool = entrance_contains_cat and id == "f19" and facility_art != null
			if facility_art == null: needs_art.append(str(id))
			if not decor and not str(data.get("catId", "")).is_empty() and natural_cat_art == null and not has_embedded_cat:
				needs_art.append(str(data.catId))
			var point := normalized_to_local(layout[id])
			var item_scale := scale_factor
			if presentation_mode and not editing:
				# Keep the complete owned visual in view at every valid saved edge position.
				# Only the visual scale adapts; saved positions and their hit anchors do not.
				var extent := Vector4(93, 166, 93, 55) if facility_art != null else Vector4(67, 54, 67, 68)
				item_scale = minf(item_scale, maxf(0.1, point.x / extent.x))
				item_scale = minf(item_scale, maxf(0.1, point.y / extent.y))
				item_scale = minf(item_scale, maxf(0.1, (size.x - point.x) / extent.z))
				item_scale = minf(item_scale, maxf(0.1, (size.y - point.y) / extent.w))
			node.configure(str(id), decor, data, owned[id], facility_art, natural_cat_art,
				has_embedded_cat, item_scale, highlighted == id)
			node.position = point
			# Keep z_index local-neutral so scenery cannot jump above the parent's HUD.
			node.z_index = 0
	for key in _visuals.keys():
		if not present.has(key):
			var stale: Control = _visuals[key]
			remove_child(stale)
			stale.queue_free()
			_visuals.erase(key)
	var depth_order: Array = _visuals.values()
	depth_order.sort_custom(func(a: Control, b: Control): return a.position.y < b.position.y)
	for index in depth_order.size(): move_child(depth_order[index], index)
	queue_redraw()

func _draw() -> void:
	if presentation_mode and not editing:
		_draw_presentation_surfaces()
		return
	var light: String = state.get("settings", {}).get("lighting", "day")
	var floor_color := Color("e5ead6") if light == "day" else (Color("efdfcc") if light == "sunset" else Color("748c88"))
	var style := StyleBoxFlat.new()
	style.bg_color = floor_color
	style.set_corner_radius_all(24)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	# The layout grid belongs to editing only; it is not scenery painted under final home art.
	if editing:
		for index in range(1, 7):
			var y := size.y * index / 7.0
			draw_line(Vector2(12, y), Vector2(size.x - 12, y), Color(1, 1, 1, 0.20), 1)
	if state.get("surfaces", {}).get("floor", null) != null:
		for index in range(1, 9):
			draw_line(Vector2(size.x * index / 9.0, 8), Vector2(size.x * index / 9.0, size.y - 8), Color(0.53, 0.4, 0.28, 0.12), 2)
	if state.get("surfaces", {}).get("path", null) != null:
		draw_line(Vector2(size.x * 0.48, size.y * 0.90), Vector2(size.x * 0.48, size.y * 0.25), Color("f8efd9"), 28, true)

func _draw_presentation_surfaces() -> void:
	var surfaces: Dictionary=state.get("surfaces",{})
	var floor_id=surfaces.get("floor",null)
	var path_id=surfaces.get("path",null)
	if floor_id!=null:
		var patch=placement_rect().grow(-10)
		var style=StyleBoxFlat.new()
		style.bg_color=Color("ddc4a1") if floor_id=="d-wood-floor" else Color("e7dfcf")
		style.bg_color.a=0.94
		style.set_corner_radius_all(14)
		draw_style_box(style,patch)
		for i in range(1,7):
			var y=patch.position.y+patch.size.y*i/7.0
			draw_line(Vector2(patch.position.x+8,y),Vector2(patch.end.x-8,y),Color(0.55,0.44,0.30,0.28),1.5,true)
		if floor_id=="d-stone-floor":
			for i in range(1,5):
				var x=patch.position.x+patch.size.x*i/5.0
				draw_line(Vector2(x,patch.position.y+8),Vector2(x,patch.end.y-8),Color(0.55,0.5,0.40,0.22),1.5,true)
	if path_id!=null:
		for i in 8:
			var t=float(i)/7.0
			var point=normalized_to_local({"x":lerpf(48,78,t),"y":lerpf(24,87,t)})
			var rect=Rect2(point-Vector2(13,5),Vector2(26,10))
			var style=StyleBoxFlat.new()
			style.bg_color=Color("acc196") if path_id=="d-leaf-path" else Color("cdaa8c")
			style.set_corner_radius_all(6)
			draw_style_box(style,rect)

func _hit(point: Vector2) -> void:
	drag_id = ""
	for decor in [false, true]:
		var owned: Dictionary = state.get("decorOwned" if decor else "owned", {})
		var layout := positions(decor)
		for id in layout:
			if not owned.has(id) or layout[id] == null: continue
			if decor and _item_data(str(id), true).get("kind", "") in ["floor", "path"]: continue
			var center := normalized_to_local(layout[id])
			var hit := point.distance_to(center) < (22 if decor else 35)
			# Full facility art can be tapped; editor preserves the original point-based hit radius.
			if presentation_mode and not editing:
				var key := ("decor:" if decor else "facility:") + str(id)
				if _visuals.has(key): hit = hit or _visuals[key].visual_bounds().has_point(point - center)
			if hit:
				drag_id = id
				drag_decor = decor
				highlighted = id
				_refresh_visuals()
				return

func _drag(point: Vector2) -> void:
	if not editing or drag_id.is_empty(): return
	var value := local_to_normalized(point)
	if drag_decor: decor_layout[drag_id] = value
	else: facility_layout[drag_id] = value
	_refresh_visuals()

func _release() -> void:
	if drag_id.is_empty(): return
	if editing: position_changed.emit(drag_id, drag_decor, positions(drag_decor)[drag_id])
	else: item_selected.emit(drag_id, drag_decor)
	drag_id = ""

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch:
		if event.canceled and touch_id == event.index:
			cancel_touch()
			accept_event()
			return
		if event.pressed and touch_id == -1:
			touch_id = event.index
			_hit(event.position)
		elif not event.pressed and touch_id == event.index:
			_release()
			touch_id = -1
		accept_event()
	elif event is InputEventScreenDrag and event.index == touch_id:
		_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and touch_id == -1:
		if event.pressed: _hit(event.position)
		else: _release()
		accept_event()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT and touch_id == -1:
		_drag(event.position)
		accept_event()

func cancel_touch() -> void:
	touch_id = -1
	drag_id = ""
