extends Control
var review_mode: bool=false
signal pause_requested
signal settings_requested
signal swap_requested(a: Vector2i,b: Vector2i)
signal tile_pressed(cell: Vector2i)
signal hammer_requested
signal plus_requested
const Board=preload("res://scripts/board_view.gd")
const Overlay=preload("res://scripts/board_overlay.gd")
const Cats=preload("res://scripts/cat_texture.gd")
const Icon=preload("res://scripts/ui_icon.gd")
const Bold=preload("res://assets/fonts/NotoSansKR-Game-Bold.otf")
var engine
var board_view: Control
var overlay: Control
var hammer_button: Button
var plus_button: Button
var puzzle_hud: Label
var goal_box: HBoxContainer
var top: Control
var goal_panel: PanelContainer
var moves_panel: PanelContainer
var board_panel: PanelContainer
var hint_panel: PanelContainer
var hint_label: Label
var tools: HBoxContainer
var moved_once:=false
var back_button: Button
var settings_button: Button

func _ready() -> void:
	name="PuzzleScreen"
	size_flags_horizontal=SIZE_EXPAND_FILL
	size_flags_vertical=SIZE_EXPAND_FILL
	custom_minimum_size=Vector2(240,260)
	_build()
	resized.connect(_layout)
	refresh()
	_layout()
	call_deferred("_layout")

func _panel() -> PanelContainer:
	var panel=PanelContainer.new()
	var style=StyleBoxFlat.new()
	style.bg_color=Color("fff8e9")
	style.border_color=Color("fffcf1")
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.shadow_color=Color(0.2,0.31,0.17,0.12)
	style.shadow_size=4
	style.shadow_offset=Vector2(0,3)
	style.content_margin_left=9
	style.content_margin_right=9
	style.content_margin_top=6
	style.content_margin_bottom=6
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	return panel

func _label(value: String, font_size: int=18) -> Label:
	var label=Label.new()
	label.text=value
	label.add_theme_font_override("font",Bold)
	label.add_theme_font_size_override("font_size",font_size)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter=MOUSE_FILTER_IGNORE
	return label

func _icon_button(kind: String, caption: String) -> Button:
	var b=Button.new()
	b.custom_minimum_size=Vector2(60,60)
	b.tooltip_text=caption
	b.accessibility_name=caption
	var icon=Icon.new()
	icon.kind=kind
	icon.position=Vector2(15,15)
	icon.size=Vector2(30,30)
	b.add_child(icon)
	return b

func _build() -> void:
	top=Control.new()
	add_child(top)
	back_button=_icon_button("back","퍼즐 일시정지")
	back_button.name="PauseButton"
	back_button.pressed.connect(func(): pause_requested.emit())
	top.add_child(back_button)
	settings_button=_icon_button("gear","퍼즐 설정")
	settings_button.name="SettingsButton"
	settings_button.pressed.connect(func(): settings_requested.emit())
	top.add_child(settings_button)
	var title=_label("흐름 확인 퍼즐" if review_mode else "첫 번째 퍼즐" if engine.level_index==0 else "%d번째 퍼즐"%(engine.level_index+1),24)
	title.name="LevelTitle"
	top.add_child(title)
	goal_panel=_panel()
	goal_panel.name="GoalCard"
	goal_box=HBoxContainer.new()
	goal_box.alignment=BoxContainer.ALIGNMENT_CENTER
	goal_box.add_theme_constant_override("separation",4)
	goal_panel.add_child(goal_box)
	moves_panel=_panel()
	moves_panel.name="MovesCard"
	var moves=VBoxContainer.new()
	moves.add_theme_constant_override("separation",0)
	moves_panel.add_child(moves)
	moves.add_child(_label("남은 횟수",14))
	puzzle_hud=_label("",34)
	puzzle_hud.size_flags_vertical=SIZE_EXPAND_FILL
	moves.add_child(puzzle_hud)
	board_panel=_panel()
	board_panel.name="BoardFrame"
	var style=board_panel.get_theme_stylebox("panel").duplicate()
	style.bg_color=Color("f0f7df")
	style.content_margin_left=5
	style.content_margin_right=5
	style.content_margin_top=5
	style.content_margin_bottom=5
	board_panel.add_theme_stylebox_override("panel",style)
	board_view=Board.new()
	board_view.custom_minimum_size=Vector2(120,120)
	board_panel.add_child(board_view)
	board_view.swap_requested.connect(func(a,b): swap_requested.emit(a,b))
	board_view.tile_pressed.connect(func(cell): tile_pressed.emit(cell))
	overlay=Overlay.new()
	overlay.board_view=board_view
	overlay.mouse_filter=MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	board_view.add_child(overlay)
	hint_panel=_panel()
	hint_panel.name="TutorialPill"
	hint_label=_label("노랑 3마리 · 밝게 표시된 두 칸을 바꿔요" if review_mode else "옆 고양이와 자리를 바꿔 보세요",15)
	hint_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint_panel.add_child(hint_label)
	hint_label.minimum_size_changed.connect(_queue_layout)
	tools=HBoxContainer.new()
	tools.alignment=BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation",16)
	add_child(tools)
	hammer_button=Button.new()
	hammer_button.name="HammerButton"
	hammer_button.custom_minimum_size=Vector2(116,60)
	hammer_button.pressed.connect(func(): hammer_requested.emit())
	tools.add_child(hammer_button)
	plus_button=Button.new()
	plus_button.name="PlusButton"
	plus_button.custom_minimum_size=Vector2(116,60)
	plus_button.pressed.connect(func(): plus_requested.emit())
	tools.add_child(plus_button)

func refresh() -> void:
	if engine==null or not is_instance_valid(board_view): return
	puzzle_hud.text=str(engine.moves)
	hammer_button.text="망치  ·  %d"%engine.hammers
	hammer_button.disabled=engine.hammers<=0
	plus_button.text="+5   ·  %d"%engine.plus_left
	plus_button.disabled=engine.plus_left<=0
	for child in goal_box.get_children(): goal_box.remove_child(child); child.queue_free()
	for goal in engine.goals:
		var item=VBoxContainer.new()
		item.size_flags_horizontal=SIZE_EXPAND_FILL
		item.add_theme_constant_override("separation",0)
		goal_box.add_child(item)
		var title=_label("목표" if engine.goals.size()==1 else ("얼음" if goal.kind=="ice" else ("상자" if goal.kind=="crate" else Cats.LABELS[int(goal.type)].replace(" 고양이",""))),14)
		item.add_child(title)
		var row: BoxContainer=HBoxContainer.new() if engine.goals.size()==1 else VBoxContainer.new()
		row.alignment=BoxContainer.ALIGNMENT_CENTER
		row.size_flags_vertical=SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation",6 if engine.goals.size()==1 else 0)
		item.add_child(row)
		if goal.kind=="fruit":
			var texture=TextureRect.new()
			texture.texture=Cats.texture(int(goal.type))
			texture.accessibility_name=Cats.LABELS[int(goal.type)]
			texture.custom_minimum_size=Vector2(38,38) if engine.goals.size()==1 else Vector2(18,18)
			texture.size_flags_horizontal=SIZE_SHRINK_CENTER
			texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(texture)
		var value=_label(("%d / %d" if engine.goals.size()==1 else "%d/%d")%[mini(int(goal.current),int(goal.target)),int(goal.target)],30 if engine.goals.size()==1 else 14)
		row.add_child(value)
	board_view.set_board(engine.board)
	board_view.hint_cells=engine.hint() if review_mode and not moved_once else []
	overlay.queue_redraw()
	if moved_once: hint_label.text="같은 고양이 3마리를 모아 주세요"
	_layout()

func notice(message: String) -> void:
	hint_label.text=message

func set_input_enabled(value: bool) -> void:
	board_view.enabled=value
	if not value: board_view.cancel_touch()
	hammer_button.disabled=not value or engine.hammers<=0
	plus_button.disabled=not value or engine.plus_left<=0

func _queue_layout() -> void:
	call_deferred("_layout")

func _layout() -> void:
	if size.x<200 or size.y<240: return
	if not is_instance_valid(top): return
	var w=size.x
	var h=size.y
	var landscape=w>h*1.2
	top.position=Vector2.ZERO
	top.size=Vector2(w,60)
	back_button.position=Vector2.ZERO
	back_button.size=Vector2(60,60)
	settings_button.position=Vector2(w-60,0)
	settings_button.size=Vector2(60,60)
	var title=top.get_node("LevelTitle")
	title.position=Vector2(64,0)
	title.size=Vector2(maxf(80,w-128),60)
	title.add_theme_font_size_override("font_size",21 if w<340 else 24)
	if landscape:
		var side=minf(h-76,w*0.55)
		board_panel.position=Vector2(0,70)
		board_panel.size=Vector2.ONE*side
		var x=side+12
		var right=w-x
		goal_panel.position=Vector2(x,70)
		goal_panel.size=Vector2(right*0.62,88)
		moves_panel.position=Vector2(x+right*0.65,70)
		moves_panel.size=Vector2(right*0.35,88)
		hint_panel.position=Vector2(x,171)
		hint_panel.size=Vector2(right,58)
		tools.position=Vector2(x,242)
		tools.size=Vector2(right,60)
		hammer_button.custom_minimum_size.x=maxf(72,(right-16)/2)
		plus_button.custom_minimum_size.x=maxf(72,(right-16)/2)
		hammer_button.add_theme_font_size_override("font_size",14)
		plus_button.add_theme_font_size_override("font_size",14)
	else:
		var compact=h<700
		var hud_height=80.0 if compact else 88.0
		puzzle_hud.add_theme_font_size_override("font_size",30 if compact else 34)
		var gap=6.0 if compact else 12.0
		goal_panel.position=Vector2(0,60+gap)
		goal_panel.size=Vector2(w*0.64-4,hud_height)
		moves_panel.position=Vector2(w*0.64+4,60+gap)
		moves_panel.size=Vector2(w*0.36-4,hud_height)
		var hint_h=34.0 if compact else 42.0
		var reserved=60+gap+hud_height+gap+hint_h+gap+60+gap
		var edge=minf(w,maxf(160,h-reserved))
		var free=maxf(0,h-reserved-edge)
		var board_y=60+gap+hud_height+gap+free*0.32
		board_panel.position=Vector2((w-edge)/2,board_y)
		board_panel.size=Vector2.ONE*edge
		hint_panel.position=Vector2(8,board_y+edge+gap+free*0.2)
		hint_panel.size=Vector2(w-16,hint_h)
		tools.position=Vector2(0,minf(h-60,hint_panel.position.y+hint_h+gap+free*0.48))
		tools.size=Vector2(w,60)
		hammer_button.custom_minimum_size.x=116
		plus_button.custom_minimum_size.x=116
		hammer_button.add_theme_font_size_override("font_size",18)
		plus_button.add_theme_font_size_override("font_size",18)
