extends Control
signal swap_requested(a: Vector2i, b: Vector2i)
signal tile_pressed(cell: Vector2i)
const Cats = preload("res://scripts/cat_texture.gd")
var cells: Array = []
var selected := Vector2i(-1,-1)
var hint_cells: Array = []
var active_touch := -1
var pressed_at := Vector2.ZERO
var origin := Vector2i(-1,-1)
var mouse_held := false
var consumed_drag := false
var tiles: Array[TextureRect] = []
var enabled := true
var show_hammer := false
var tile_materials: Array[ShaderMaterial]=[]
var motion_tween: Tween
var selection_tween: Tween
var reduce_motion: bool=false
var effect_level: String="full"
var transient_nodes: Array=[]

class MatchSpark:
	extends Control
	var color: Color=Color.WHITE
	func _draw() -> void:
		draw_circle(size/2.0,2.4,color)

func configure_motion(reduce: bool, effects: String) -> void:
	reduce_motion=reduce
	effect_level=effects

func pause_presentation(value: bool) -> void:
	for tween in [motion_tween,selection_tween]:
		if tween!=null and tween.is_valid():
			if value: tween.pause()
			else: tween.play()

func clear_transients() -> void:
	for item in transient_nodes:
		if is_instance_valid(item): item.queue_free()
	transient_nodes.clear()

func selection_feedback() -> void:
	if selection_tween!=null and selection_tween.is_valid(): selection_tween.kill()
	if reduce_motion or effect_level=="off" or selected.x<0: return
	var tile=tiles[selected.y*8+selected.x]
	selection_tween=create_tween().set_parallel(true)
	selection_tween.tween_property(tile,"scale",Vector2.ONE*1.07,0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	selection_tween.tween_property(tile,"position",tile.position-Vector2(0,3),0.10)

func animate_reject(a: Vector2i,b: Vector2i,seconds: float) -> void:
	if motion_tween!=null and motion_tween.is_valid(): motion_tween.kill()
	var first=tiles[a.y*8+a.x]
	var second=tiles[b.y*8+b.x]
	var pa=first.position;var pb=second.position
	motion_tween=create_tween().set_parallel(true)
	motion_tween.tween_property(first,"position",pb,seconds/2).set_trans(Tween.TRANS_QUAD)
	motion_tween.tween_property(second,"position",pa,seconds/2).set_trans(Tween.TRANS_QUAD)
	motion_tween.tween_property(first,"position",pa,seconds/2).set_delay(seconds/2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(second,"position",pb,seconds/2).set_delay(seconds/2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func animate_clear(step: Dictionary,seconds: float) -> void:
	if motion_tween!=null and motion_tween.is_valid(): motion_tween.kill()
	motion_tween=create_tween().set_parallel(true)
	var unit: float=size.x/8.0
	for cell in step.get("cells",[]):
		var tile=tiles[cell.y*8+cell.x]
		if not tile.visible: continue
		motion_tween.tween_property(tile,"scale",Vector2(1.12,0.85),seconds*0.35).set_trans(Tween.TRANS_QUAD)
		motion_tween.tween_property(tile,"scale",Vector2.ONE*0.1,seconds*0.65).set_delay(seconds*0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		motion_tween.tween_property(tile,"modulate:a",0.0,seconds*0.65).set_delay(seconds*0.35)
		if effect_level=="full":
			var data=cells[cell.y][cell.x]
			for k in 5:
				var spark=MatchSpark.new();spark.color=Cats.COLORS[clampi(int(data.type),0,5)]
				spark.mouse_filter=Control.MOUSE_FILTER_IGNORE;spark.size=Vector2(6,6);spark.position=tile.position+tile.size/2.0; spark.z_index=5
				add_child(spark);transient_nodes.append(spark)
				var drift=Vector2.from_angle(float(k)/5*TAU)*unit*0.35
				motion_tween.tween_property(spark,"position",spark.position+drift,seconds)
				motion_tween.tween_property(spark,"modulate:a",0.0,seconds)
	var count=int(step.get("combo",1))
	if count>1 and effect_level!="off":
		var label=Label.new();label.text="%d 연쇄"%count;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",24);label.add_theme_color_override("font_color",Color("735331"))
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.position=Vector2(0,size.y*0.4);label.size=Vector2(size.x,40);label.z_index=6
		add_child(label);transient_nodes.append(label)
		motion_tween.tween_property(label,"position:y",label.position.y-10,seconds)
		motion_tween.tween_property(label,"modulate:a",0.0,seconds)

func animate_finish(seconds: float) -> void:
	if motion_tween!=null and motion_tween.is_valid(): motion_tween.kill()
	motion_tween=create_tween().set_parallel(true)
	for tile in tiles:
		if tile.visible:
			motion_tween.tween_property(tile,"scale",Vector2.ONE*1.035,seconds/2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			motion_tween.tween_property(tile,"scale",Vector2.ONE,seconds/2).set_delay(seconds/2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(240,240)
	var shader = Shader.new()
	shader.code = "shader_type canvas_item; uniform vec2 frame_origin; uniform vec2 frame_size; void fragment(){ vec4 c=texture(TEXTURE,UV); vec2 local_uv=(UV-frame_origin)/frame_size; vec2 p=abs(local_uv-vec2(0.5))-vec2(0.28); float d=length(max(p,vec2(0.0)))+min(max(p.x,p.y),0.0)-0.22; c.a*=1.0-smoothstep(-0.006,0.006,d); COLOR=c*COLOR; }"
	for frame in Cats.FRAMES:
		var material=ShaderMaterial.new()
		material.shader=shader
		material.set_shader_parameter("frame_origin",frame.position/Vector2(1536,1024))
		material.set_shader_parameter("frame_size",frame.size/Vector2(1536,1024))
		tile_materials.append(material)
	for i in 64:
		var tile = TextureRect.new()
		tile.mouse_filter = MOUSE_FILTER_IGNORE
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_SCALE
		tile.material = tile_materials[0]
		add_child(tile)
		tiles.append(tile)
	resized.connect(_refresh)
	_refresh()

func set_board(value: Array) -> void:
	clear_transients()
	if selection_tween!=null and selection_tween.is_valid(): selection_tween.kill()
	if motion_tween!=null and motion_tween.is_valid(): motion_tween.kill()
	cells = value.duplicate(true)
	_refresh()

func animate_board(value: Array, seconds: float, kind: String="fall") -> void:
	var previous: Dictionary={}
	if cells.size()==8:
		for r in 8:
			for c in 8:
				if cells[r][c]!=null: previous[int(cells[r][c].id)]=tiles[r*8+c].position
	set_board(value)
	motion_tween=null
	for r in 8:
		for c in 8:
			if cells[r][c]==null or bool(cells[r][c].get("crate",false)): continue
			var tile=tiles[r*8+c]
			var target=tile.position
			var id=int(cells[r][c].id)
			if previous.has(id) and previous[id]!=target:
				if motion_tween==null: motion_tween=create_tween().set_parallel(true)
				tile.position=previous[id]
				var delay=0.009*c if kind=="fall" else 0.0
				motion_tween.tween_property(tile,"position",target,seconds-delay).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				if kind=="fall":
					motion_tween.tween_property(tile,"scale",Vector2(1.04,0.96),0.035).set_delay(seconds-0.035)
					motion_tween.tween_property(tile,"scale",Vector2.ONE,0.035).set_delay(seconds)
			elif not previous.has(id):
				if motion_tween==null: motion_tween=create_tween().set_parallel(true)
				tile.position=target-Vector2(0,12)
				tile.modulate.a=0.25
				motion_tween.tween_property(tile,"position",target,seconds)
				motion_tween.tween_property(tile,"modulate:a",1.0,seconds)

func _refresh() -> void:
	if tiles.size() != 64: return
	var cell_size: float = minf(size.x,size.y) / 8.0
	for r in 8:
		for c in 8:
			var tile := tiles[r*8+c]
			tile.position = Vector2(c,r)*cell_size+Vector2.ONE*3
			tile.size = Vector2.ONE*(cell_size-6)
			tile.pivot_offset=tile.size/2.0
			tile.scale=Vector2.ONE
			if cells.size() != 8 or cells[r][c] == null:
				tile.visible = false
				continue
			var data: Dictionary = cells[r][c]
			tile.visible = not bool(data.get("crate", false))
			tile.texture = Cats.texture(int(data.get("type",0)))
			tile.material=tile_materials[clampi(int(data.get("type",0)),0,5)]
			tile.modulate = Color(0.7,0.91,1.0) if int(data.get("ice",0)) > 0 else Color.WHITE
	queue_redraw()

func _draw() -> void:
	var cell_size: float = minf(size.x,size.y)/8.0
	for r in 8:
		for c in 8:
			var rect := Rect2(Vector2(c,r)*cell_size+Vector2.ONE,Vector2.ONE*(cell_size-2))
			var style := StyleBoxFlat.new()
			style.bg_color = Color("e9e2d7") if (r+c)%2 == 0 else Color("e2dbcf")
			style.set_corner_radius_all(9)
			if Vector2i(c,r) == selected or hint_cells.has(Vector2i(c,r)):
				style.bg_color = Color("ffda73")
				style.border_color = Color("fff3ba")
				style.set_border_width_all(3)
			draw_style_box(style,rect)
			if cells.size()!=8 or cells[r][c]==null: continue
			var data: Dictionary = cells[r][c]
			if bool(data.get("crate",false)):
				var inner = rect.grow(-5)
				draw_rect(inner,Color("b87c4d"))
				draw_rect(inner,Color("895839"),false,3)
				draw_line(inner.position+Vector2(2,2),inner.end-Vector2(2,2),Color("e8bc83"),5)
				draw_line(Vector2(inner.end.x-2,inner.position.y+2),Vector2(inner.position.x+2,inner.end.y-2),Color("e8bc83"),5)
	# Special symbols are drawn by a foreground child after sprites.

func cell_at(point: Vector2) -> Vector2i:
	var unit: float = minf(size.x,size.y)/8.0
	if unit <= 0: return Vector2i(-1,-1)
	var cell := Vector2i(floori(point.x/unit),floori(point.y/unit))
	return cell if cell.x >= 0 and cell.x < 8 and cell.y >= 0 and cell.y < 8 else Vector2i(-1,-1)

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device==InputEvent.DEVICE_ID_EMULATION: return
	if not enabled: return
	if event is InputEventScreenTouch:
		if event.canceled and event.index==active_touch:
			cancel_touch()
			accept_event()
			return
		if event.pressed and active_touch == -1:
			active_touch = event.index
			_begin(event.position)
		elif not event.pressed and event.index == active_touch:
			_end(event.position)
			active_touch = -1
		accept_event()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_move(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and active_touch == -1:
		var was_held=mouse_held
		mouse_held = event.pressed
		if event.pressed: _begin(event.position)
		elif was_held: _end(event.position)
		accept_event()
	elif event is InputEventMouseMotion and mouse_held and active_touch == -1:
		_move(event.position)
		accept_event()

func _begin(point: Vector2) -> void:
	pressed_at = point
	origin = cell_at(point)
	consumed_drag = false

func _move(point: Vector2) -> void:
	if consumed_drag or origin.x < 0: return
	var delta: Vector2 = point-pressed_at
	if delta.length() < maxf(12.0,minf(size.x,size.y)/8.0*0.3): return
	var direction := Vector2i(signi(int(delta.x)),0) if absf(delta.x)>=absf(delta.y) else Vector2i(0,signi(int(delta.y)))
	var target := origin+direction
	consumed_drag = true
	if target.x >=0 and target.x<8 and target.y>=0 and target.y<8:
		selected=Vector2i(-1,-1)
		swap_requested.emit(origin,target)
	queue_redraw()

func _end(point: Vector2) -> void:
	if consumed_drag: return
	var cell := cell_at(point)
	if cell.x<0 or cell != origin: return
	var was_hammer=show_hammer
	tile_pressed.emit(cell)
	if was_hammer: return
	if selected.x >=0 and absi(cell.x-selected.x)+absi(cell.y-selected.y)==1:
		var previous:=selected
		selected=Vector2i(-1,-1)
		swap_requested.emit(previous,cell)
	else:
		selected=cell if selected!=cell else Vector2i(-1,-1)
		_refresh()
		selection_feedback()
	queue_redraw()

func cancel_touch() -> void:
	active_touch=-1
	mouse_held=false
	consumed_drag=false
	origin=Vector2i(-1,-1)
	selected=Vector2i(-1,-1)
	queue_redraw()
