extends Control
## Native mobile shell. UI state is separate from durable progression.
const Profile=preload("res://scripts/level_profile.gd")
const Model = preload("res://scripts/cafe_model.gd")
const Puzzle = preload("res://scripts/puzzle_engine.gd")
const Board = preload("res://scripts/board_view.gd")
const Overlay = preload("res://scripts/board_overlay.gd")
const Garden = preload("res://scripts/garden_view.gd")
const Cats = preload("res://scripts/cat_texture.gd")
const SafeArea = preload("res://scripts/safe_area.gd")
const SessionStore=preload("res://scripts/session_store.gd")
const TitleScreen=preload("res://scenes/title_screen.tscn")
const CompletionScreen=preload("res://scenes/completion_screen.tscn")
const PuzzleScreen=preload("res://scenes/puzzle_screen.tscn")
const HomeScreen=preload("res://scenes/home_screen.tscn")
const QuietBackground=preload("res://scripts/quiet_background.gd")
const BOLD_FONT=preload("res://assets/fonts/NotoSansKR-Game-Bold.otf")
const FONT = preload("res://assets/fonts/NotoSansKR-Game.otf")
const CREAM=Color("fff8e9")
const INK=Color("52392e")
const GREEN=Color("446f56")
var model
var session
var session_state: Dictionary={}
var completion_reward: int=0
var save_blocked: bool=false
var engine
var sound_fx
var state: Dictionary={}
var catalog: Dictionary={}
var progress: Dictionary={"version":1,"unlocked":1,"stars":[0,0,0,0,0,0,0,0]}
var current_page: String="home"
var root_column: VBoxContainer
var content: VBoxContainer
var safe_margin: MarginContainer
var frame: Control
var scenery: TextureRect
var quiet_background: Control
var puzzle_screen: Control
var home_screen: Control
var show_first_arrival:=false
var paused_ui:=false
var status: Label
var balance: Label
var board_view: Control
var overlay: Control
var garden: Control
var hammer_button: Button
var plus_button: Button
var puzzle_hud: Label
var goal_box: HBoxContainer
var attempt_id: String=""
var animating: bool=false
var hammer_armed: bool=false
var queued_swap: Array=[]
var animation_epoch: int=0
var facility_draft: Dictionary={}
var decor_draft: Dictionary={}
var draft_revision: int=-1
var undo_layout: Array=[]
var edit_selection: String=""
var edit_decor: bool=false
var popup_layer: Control
var progress_error: String=""

func _ready() -> void:
	get_tree().auto_accept_quit=false
	_configure_canvas()
	_setup_theme()
	sound_fx=preload("res://scripts/sound_fx.gd").new()
	add_child(sound_fx)
	model=Model.new()
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	state=model.read()
	session=SessionStore.new()
	session_state=session.load_state()
	_load_progress()
	_build_shell()
	get_viewport().size_changed.connect(_safe_layout)
	_safe_layout()
	if state.is_empty(): _show_storage_error()
	elif session_state.is_empty(): _session_error()
	else: _navigate("title")

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if save_blocked: return
		if is_instance_valid(popup_layer): _close_popup()
		elif draft_revision>=0: _confirm("배치 편집을 나갈까요?", "저장하지 않은 변경은 취소됩니다",func(): _cancel_edit())
		elif current_page=="puzzle" and engine!=null and engine.phase=="idle": _open_pause()
		elif current_page=="completion": return
		elif current_page in ["home","title"]: _confirm("카페를 나갈까요?","진행은 이 기기에 저장돼 있어요",func(): get_tree().quit())
		else: _navigate("home")
	elif what==NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
	elif what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(board_view): board_view.cancel_touch()
		if is_instance_valid(garden): garden.cancel_touch()
		if current_page=="puzzle" and not is_instance_valid(popup_layer) and not save_blocked: _open_pause()

func _setup_theme() -> void:
	theme=Theme.new()
	theme.default_font=FONT
	theme.default_font_size=18
	theme.set_font("font","Button",BOLD_FONT)
	theme.set_color("font_color","Label",INK)
	theme.set_color("font_color","Button",INK)
	theme.set_color("font_hover_color","Button",INK)
	theme.set_color("font_pressed_color","Button",INK)
	theme.set_color("font_disabled_color","Button",Color("a5a295"))
	for kind in ["normal","hover","pressed","disabled","focus"]:
		var box=StyleBoxFlat.new()
		box.bg_color=CREAM if kind=="normal" else Color("ede2ce")
		if kind=="disabled": box.bg_color=Color("e9e8e0")
		box.set_corner_radius_all(23)
		box.content_margin_left=12
		box.content_margin_right=12
		box.content_margin_top=8
		box.content_margin_bottom=8
		if kind=="focus":
			box.bg_color=Color.TRANSPARENT
			box.border_color=GREEN
			box.set_border_width_all(2)
		theme.set_stylebox(kind,"Button",box)
	theme.set_constant("separation","VBoxContainer",12)
	theme.set_constant("separation","HBoxContainer",10)

func _build_shell() -> void:
	var bg=ColorRect.new()
	bg.color=CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(bg)
	quiet_background=QuietBackground.new()
	quiet_background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(quiet_background)
	scenery=TextureRect.new()
	scenery.name="ArtBackground"
	scenery.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	scenery.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scenery.mouse_filter=MOUSE_FILTER_IGNORE
	scenery.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(scenery)
	frame=Control.new()
	add_child(frame)
	safe_margin=MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(safe_margin)
	root_column=VBoxContainer.new()
	safe_margin.add_child(root_column)
	var header=HBoxContainer.new()
	root_column.add_child(header)
	var title=_label("카페 메뉴",20)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(title)
	balance=_label("0 방울",19)
	header.add_child(balance)
	header.add_child(_button("설정",func(): _show_settings(),false,62))
	var scroll=ScrollContainer.new()
	scroll.name="PageScroll"
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	root_column.add_child(scroll)
	content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	status=_label("",14)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y=22
	status.mouse_filter=MOUSE_FILTER_IGNORE
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.visible=false
	frame.add_child(status)
	var nav=HBoxContainer.new()
	nav.name="Navigation"
	root_column.add_child(nav)
	for entry in [["home","내 카페"],["levels","퍼즐"],["workshop","작업대"],["collection","도감"]]:
		var page: String=entry[0]
		var b=_button(entry[1],func(): _request_navigation(page))
		b.name=page
		b.add_theme_font_size_override("font_size",15)
		nav.add_child(b)

func _configure_canvas() -> void:
	if DisplayServer.get_name()=="headless": return
	var pixels=Vector2(DisplayServer.window_get_size())
	if pixels.x<=0 or pixels.y<=0: return
	var target=Vector2i(390,roundi(390*pixels.y/pixels.x)) if pixels.y>=pixels.x else Vector2i(roundi(390*pixels.x/pixels.y),390)
	if get_window().content_scale_size!=target: get_window().content_scale_size=target

func _safe_layout() -> void:
	_configure_canvas()
	var viewport_size=get_viewport_rect().size
	var inset=Vector4.ZERO
	if OS.get_name() in ["Android","iOS"]:
		inset=SafeArea.insets(Rect2(DisplayServer.get_display_safe_area()),Vector2(DisplayServer.window_get_size()),viewport_size)
	var available_width=maxf(240,viewport_size.x-inset.x-inset.z)
	var width=minf(580,available_width)
	frame.position=Vector2(inset.x+(available_width-width)/2,inset.y)
	frame.size=Vector2(width,maxf(320,viewport_size.y-inset.y-inset.w))
	for side in ["left","right","top","bottom"]:
		safe_margin.add_theme_constant_override("margin_"+side,15 if side in ["left","right"] else 8)
	status.position=Vector2(18,70)
	status.size=Vector2(frame.size.x-36,40)
	_resize_popup()

func _resize_popup() -> void:
	if not is_instance_valid(popup_layer): return
	for scroller in popup_layer.find_children("*","ScrollContainer",true,false):
		scroller.custom_minimum_size.y=minf(610,maxf(200,size.y-150))
	for child in popup_layer.get_children():
		if child is MarginContainer:
			for side in ["left","right"]: child.add_theme_constant_override("margin_"+side,int((size.x-minf(size.x-36,510))/2))

func _label(text_value: String, font_size: int=18) -> Label:
	var result=Label.new()
	result.text=text_value
	result.add_theme_font_size_override("font_size",font_size)
	return result

func _body(text_value: String, font_size: int=17) -> Label:
	var result=_label(text_value,font_size)
	result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	return result

func _button(text_value: String, action: Callable, expand: bool=true, min_width: int=0) -> Button:
	var b=Button.new()
	b.text=text_value
	b.custom_minimum_size=Vector2(min_width,60)
	if expand: b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	return b

func _card(parent: Node, color: Color=Color("ffffff")) -> VBoxContainer:
	var panel=PanelContainer.new()
	var style=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(20)
	style.content_margin_left=16
	style.content_margin_right=16
	style.content_margin_top=14
	style.content_margin_bottom=14
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var inner=VBoxContainer.new()
	panel.add_child(inner)
	return inner

func _clear_content() -> void:
	for node in content.get_children():
		content.remove_child(node)
		node.queue_free()
	board_view=null
	overlay=null
	garden=null
	puzzle_screen=null
	home_screen=null

func _request_navigation(page: String) -> void:
	if animating or save_blocked or current_page=="completion": return
	if session.should_first_puzzle() and page!="title":
		_toast("첫 퍼즐을 완료하면 고양이 커피숍이 열려요")
		return
	if draft_revision>=0:
		_confirm("배치 편집을 나갈까요?","저장하지 않은 변경은 취소됩니다",func(): _cancel_edit(); _navigate(page))
	elif current_page=="puzzle" and engine!=null and engine.phase=="idle": _confirm_abandon(page)
	else: _navigate(page)

func _navigate(page: String) -> void:
	if session!=null and not session.state.is_empty() and session.should_first_puzzle() and page in ["home","levels","workshop","collection"]:
		page="title"
	current_page=page
	_clear_content()
	state=model.read()
	if state.is_empty(): _show_storage_error(); return
	balance.text=str(int(state.balance))+" 방울"
	status.text=progress_error
	status.visible=not progress_error.is_empty()
	_apply_backdrop(page)
	var core: bool=page in ["title","completion","puzzle","home"]
	root_column.get_child(0).visible=not core
	root_column.get_node("Navigation").visible=not core
	root_column.get_node("PageScroll").vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED if core else ScrollContainer.SCROLL_MODE_AUTO
	content.add_theme_constant_override("separation",0 if core else 12)
	for node in root_column.get_node("Navigation").get_children():
		node.modulate=Color("c8e0cb") if node.name==page or (page=="puzzle" and node.name=="levels") else Color.WHITE
	match page:
		"title": _title()
		"completion": _completion()
		"home": _home()
		"levels": _levels()
		"workshop": _workshop()
		"collection": _collection()
		"puzzle": _puzzle()

func _apply_backdrop(page: String) -> void:
	var paths={"title":"res://assets/art/title-background.png","completion":"res://assets/art/completion-background.png","home":"res://assets/art/garden-empty-background.png"}
	scenery.visible=paths.has(page)
	quiet_background.visible=page=="puzzle"
	if scenery.visible:
		scenery.texture=load(paths[page])
		scenery.modulate=Color.WHITE
		if page=="home":
			if state.settings.lighting=="sunset": scenery.modulate=Color(1,0.85,0.71)
			elif state.settings.lighting=="night": scenery.modulate=Color(0.48,0.61,0.69)

func _home() -> void:
	home_screen=HomeScreen.instantiate()
	home_screen.state=state
	home_screen.catalog=catalog
	home_screen.first_arrival=show_first_arrival
	show_first_arrival=false
	home_screen.play_requested.connect(func(): _start_level(0 if Profile.enabled() else clampi(int(progress.unlocked)-1,0,7)))
	home_screen.project_requested.connect(_project_popup)
	home_screen.settings_requested.connect(_show_settings)
	home_screen.facility_selected.connect(_facility_popup)
	home_screen.decoration_selected.connect(func(_id): _toast("꾸미기는 카페 메뉴의 배치 편집에서 옮겨요"))
	content.add_child(home_screen)
	garden=home_screen.garden

func _project_popup() -> void:
	var id=state.project
	if id==null: _request_navigation("workshop"); return
	if state.owned.has(id): _facility_popup(id); return
	var f: Dictionary=model.by_id(id)
	var card=_popup("다음: "+str(f.name))
	card.add_child(_body(str(f.catName)+" · "+str(f.personality),17))
	card.add_child(_body(str(f.action),16))
	card.add_child(_button("입주 · %d 방울"%int(f.price),func():
		var result=_perform("purchase",[id])
		if result.ok:
			_close_popup()
			_navigate("home")
			_toast("입주했어요. 배치 편집에서 정원에 놓을 수 있어요")))

func _orders_popup() -> void:
	var card=_popup("카페 손님 주문")
	if state.order!=null:
		var order: Dictionary=state.order
		var f: Dictionary=model.by_id(order.facility)
		card.add_child(_body(str(f.story.request)))
		card.add_child(_label("준비한 퍼즐 %d / 2"%int(order.completed),20))
		if int(order.completed)>=2:
			card.add_child(_button("손님 맞이하기",func(): _perform("serve_order"); _close_popup(); _navigate("home")))
	for id in state.owned:
		var facility_id: String=id
		card.add_child(_button(str(model.by_id(id).name)+" 주문",func(): _perform("begin_order",[facility_id]); _orders_popup()))

func _companion_facility() -> Dictionary:
	for f in catalog.facilities:
		if f.catId==state.companion: return f
	return {}

func _levels() -> void:
	content.add_child(_label("고양이 퍼즐",27))
	content.add_child(_body("같은 색을 세 마리 이상 맞춰요. 첫 클리어 100 방울, 다시 클리어하면 35 방울을 받아요"))
	for i in 8:
		var index: int=i
		var row=_card(content,Color("edf1e5") if i<int(progress.unlocked) else Color("efeee8"))
		var head=HBoxContainer.new()
		head.add_child(_label("레벨 %d"%(i+1),22))
		var stars=_label("★".repeat(int(progress.stars[i]))+"☆".repeat(3-int(progress.stars[i])),21)
		stars.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		stars.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(stars)
		row.add_child(head)
		var b=_button("함께 시작" if i<int(progress.unlocked) else "앞 레벨을 먼저 완료해 주세요",func(): _start_level(index))
		b.disabled=i>=int(progress.unlocked)
		row.add_child(b)

func _unlock_launch_controls() -> void:
	if current_page=="title":
		for child in content.get_children():
			if child.get_script()==preload("res://scripts/title_screen.gd"):
				child.transition_started=false
				child.get_node("StartButton").disabled=false
				child.get_node("SettingsButton").disabled=false
	elif current_page=="home" and is_instance_valid(home_screen):
		home_screen.transition_started=false
		home_screen.play_button.disabled=false

func _start_level(index: int) -> void:
	if save_blocked or animating: return
	if index<0 or index>=int(progress.unlocked): return
	var new_attempt_id="native-attempt:"+str(Time.get_unix_time_from_system()).replace(".","-")+":"+str(Time.get_ticks_usec())
	var started: Dictionary=model.begin_attempt(index+1,new_attempt_id)
	if not started.ok:
		if current_page in ["title","home"]: _unlock_launch_controls()
		_toast(started.get("message","저장 실패로 퍼즐을 시작하지 않았어요"))
		return
	var new_engine=Puzzle.new()
	new_engine.initialize(index,int(Time.get_ticks_usec()))
	var saved: Dictionary=session.begin_puzzle(new_attempt_id,new_engine,session.should_first_puzzle())
	if not saved.ok:
		_session_error()
		return
	attempt_id=new_attempt_id
	engine=new_engine
	hammer_armed=false
	queued_swap=[]
	animation_epoch+=1
	_navigate("puzzle")

func _puzzle() -> void:
	if engine==null: _navigate("levels"); return
	puzzle_screen=PuzzleScreen.instantiate()
	puzzle_screen.engine=engine
	puzzle_screen.review_mode=Profile.enabled() and engine.level_index==0
	puzzle_screen.pause_requested.connect(_open_pause)
	puzzle_screen.settings_requested.connect(_show_settings)
	puzzle_screen.swap_requested.connect(_swap)
	puzzle_screen.tile_pressed.connect(_tile_press)
	puzzle_screen.hammer_requested.connect(func():
		if animating or paused_ui or save_blocked: return
		hammer_armed=not hammer_armed
		board_view.show_hammer=hammer_armed
		_toast("지울 고양이 또는 상자를 눌러 주세요" if hammer_armed else "망치 선택 취소"))
	puzzle_screen.plus_requested.connect(_plus)
	content.add_child(puzzle_screen)
	board_view=puzzle_screen.board_view
	overlay=puzzle_screen.overlay
	hammer_button=puzzle_screen.hammer_button
	plus_button=puzzle_screen.plus_button
	puzzle_hud=puzzle_screen.puzzle_hud
	goal_box=puzzle_screen.goal_box
	_refresh_puzzle()

func _set_puzzle_paused(value: bool) -> void:
	paused_ui=value
	if is_instance_valid(puzzle_screen): puzzle_screen.set_input_enabled(not value and not save_blocked and not animating)
	if is_instance_valid(board_view): board_view.pause_presentation(value)

func _open_pause() -> void:
	if engine==null or save_blocked: return
	var card=_popup("잠깐 쉬어 갈까요?")
	card.get_child(1).hide()
	card.add_child(_button("계속하기",_close_popup))
	var hint_button=_button("힌트 보기",func(): _close_popup(); board_view.hint_cells=engine.hint(); board_view.queue_redraw())
	hint_button.disabled=animating or engine.phase!="idle"
	card.add_child(hint_button)
	var restart_button=_button("다시 시작",func(): _close_popup(); _restart_request())
	restart_button.disabled=animating or engine.phase!="idle"
	card.add_child(restart_button)
	card.add_child(_button("타이틀로 · 진행 저장",_pause_to_title))

func _pause_to_title() -> void:
	if save_blocked: return
	animation_epoch+=1
	animating=false
	_close_popup()
	if engine!=null and not _checkpoint_session(): return
	_navigate("title")

func _restart_request() -> void:
	if animating or save_blocked: return
	_confirm("다시 시작할까요?","현재 판은 보상 없이 끝나고 이동 횟수가 초기화됩니다",_restart_puzzle)

func _restart_puzzle() -> void:
	var index=engine.level_index
	var previous_attempt=attempt_id
	_start_level(index)
	if not save_blocked and attempt_id!=previous_attempt and session.state.get("attempt_id","")==attempt_id:
		model.abandon(previous_attempt)

func _refresh_puzzle() -> void:
	if not is_instance_valid(puzzle_screen): return
	puzzle_screen.refresh()
	board_view.configure_motion(bool(state.settings.reduceMotion),str(state.settings.effects))
	puzzle_screen.set_input_enabled(not paused_ui and not save_blocked and not animating)

func _swap(a: Vector2i,b: Vector2i) -> void:
	if save_blocked or paused_ui: return
	if engine.phase!="idle": return
	if animating: return
	hammer_armed=false
	board_view.show_hammer=false
	var result: Dictionary=engine.try_swap(a,b)
	if not result.get("accepted",false):
		_toast("세 마리 이상 맞춰지는 이웃 고양이를 바꿔 주세요")
		if result.get("reason","")=="no_match" and not bool(state.settings.reduceMotion): _animate_result(result)
		else: _refresh_puzzle()
		return
	if _checkpoint_session(): _animate_result(result)

func _tile_press(cell: Vector2i) -> void:
	if not hammer_armed or animating or paused_ui or save_blocked: return
	hammer_armed=false
	board_view.show_hammer=false
	var result: Dictionary=engine.use_hammer(cell)
	if result.get("accepted",result.get("ok",false)):
		if _checkpoint_session(): _animate_result(result)
	else: _toast("사용할 망치가 없어요")

func _plus() -> void:
	if animating or save_blocked or paused_ui: return
	var accepted: bool=engine.use_plus()
	if accepted:
		if not _checkpoint_session(): return
		_refresh_puzzle()
		_toast("이동 5회를 더 받았어요")
	else: _toast("이번 판의 추가 이동을 이미 사용했어요")

func _presentation_wait(seconds: float,epoch: int) -> bool:
	var left=seconds
	while left>0:
		if epoch!=animation_epoch: return false
		await get_tree().process_frame
		if not paused_ui: left-=minf(0.04,get_process_delta_time())
	return epoch==animation_epoch

func _animate_result(result: Dictionary) -> void:
	animating=true
	var epoch=animation_epoch
	var quiet: bool=bool(state.settings.reduceMotion) or state.settings.effects=="off"
	if is_instance_valid(puzzle_screen): puzzle_screen.set_input_enabled(false)
	for step in result.get("steps",[]):
		while paused_ui:
			if epoch!=animation_epoch: return
			await get_tree().process_frame
		if epoch!=animation_epoch: return
		if not is_instance_valid(board_view): animating=false; return
		var kind: String=step.get("kind","")
		var duration=0.10 if state.settings.effects=="low" else 0.16
		if kind=="clear": sound_fx.tone("clear",bool(state.settings.sound))
		if quiet:
			if step.has("board"): board_view.set_board(step.board)
		elif kind=="clear":
			board_view.animate_clear(step,duration)
			if not await _presentation_wait(duration,epoch): return
			board_view.set_board(step.board)
		elif kind=="reject":
			board_view.animate_reject(step.a,step.b,0.20)
			if not await _presentation_wait(0.20,epoch): return
		elif step.has("board"):
			duration=0.23 if kind=="fall" else (0.14 if kind=="swap" else 0.07)
			board_view.animate_board(step.board,duration,kind)
			if not await _presentation_wait(duration+0.04,epoch): return
		if is_instance_valid(overlay): overlay.queue_redraw()
	if epoch!=animation_epoch: return
	if engine.phase=="win" and not quiet:
		board_view.animate_finish(0.24)
		if not await _presentation_wait(0.24,epoch): return
	animating=false
	if is_instance_valid(puzzle_screen): puzzle_screen.moved_once=true
	_refresh_puzzle()
	if engine.phase in ["win","lose"]: _finish_puzzle()

func _finish_puzzle() -> void:
	var saved: Dictionary=session.begin_completion(engine)
	if not saved.ok: _session_error(); return
	var won: bool=engine.phase=="win"
	var result: Dictionary=model.finish_attempt(attempt_id,won)
	if not result.ok:
		save_blocked=true
		var card=_popup("보상 저장을 다시 시도해 주세요")
		card.get_child(1).hide()
		card.add_child(_body(result.get("message","이전 저장은 보존했습니다")))
		card.add_child(_button("저장 다시 시도",func(): save_blocked=false; _close_popup(); _finish_puzzle()))
		return
	if won:
		progress.unlocked=maxi(int(progress.unlocked),mini(8,engine.level_index+2))
		progress.stars[engine.level_index]=maxi(int(progress.stars[engine.level_index]),int(engine.stars))
		_save_progress()
	state=model.read()
	completion_reward=0
	for tx in state.ledger:
		if tx.id=="reward:"+attempt_id: completion_reward=int(tx.amount)
	_navigate("completion")

func _title() -> void:
	var screen=TitleScreen.instantiate()
	screen.resume_available=session.state.get("phase","") in ["puzzle","completion"] or not session.should_first_puzzle()
	screen.start_requested.connect(_title_start)
	screen.settings_requested.connect(_show_settings)
	content.add_child(screen)

func _title_start() -> void:
	if save_blocked or current_page!="title": return
	if session.state.get("phase","") in ["puzzle","completion"]:
		engine=Puzzle.new()
		if not session.restore_engine(engine): _session_error(); return
		attempt_id=session.state.attempt_id
		if not state.attempts.has(attempt_id):
			_session_error("카페 저장과 진행 중 퍼즐의 기록이 달라요. 원본을 보존했어요")
			return
		var attempt: Dictionary=state.attempts[attempt_id]
		if int(attempt.level)!=engine.level_index+1:
			_session_error("카페 기록과 퍼즐 레벨이 달라 원본을 보존했어요")
			return
		if attempt.status=="abandoned":
			var cleared: Dictionary=session.abandon_puzzle()
			if cleared.ok: _navigate("title")
			else: _session_error()
			return
		if session.state.phase=="puzzle" and attempt.status!="active":
			_session_error("이미 종료된 퍼즐 기록이라 다시 보상받지 않도록 보존했어요")
			return
		if session.state.phase=="completion": _finish_puzzle()
		else: _navigate("puzzle")
	elif session.should_first_puzzle(): _start_level(0)
	else: _navigate("home")

func _completion() -> void:
	sound_fx.tone("win" if engine.phase=="win" else "lose",bool(state.settings.sound))
	var screen=CompletionScreen.instantiate()
	screen.won=engine.phase=="win"
	screen.first_run=session.should_first_puzzle()
	screen.reward=completion_reward
	screen.score=engine.score
	screen.stars=engine.stars
	screen.level_number=engine.level_index+1
	screen.reduce_motion=state.settings.reduceMotion
	screen.continue_requested.connect(func():
		show_first_arrival=session.should_first_puzzle()
		var result: Dictionary=session.acknowledge_completion()
		if result.ok:
			engine=null
			_navigate("home")
		else: _session_error())
	screen.retry_requested.connect(func():
		var index=engine.level_index
		var result: Dictionary=session.acknowledge_completion()
		if result.ok: _start_level(index)
		else: _session_error())
	content.add_child(screen)

func _checkpoint_session() -> bool:
	var result: Dictionary=session.checkpoint(engine)
	if not result.ok:
		save_blocked=true
		var card=_popup("진행 저장을 다시 시도해 주세요")
		card.get_child(1).hide()
		card.add_child(_body(result.get("message","이전 기록을 보존했어요")))
		card.add_child(_button("저장 다시 시도",func():
			save_blocked=false
			_close_popup()
			if _checkpoint_session():
				_refresh_puzzle()
				if engine.phase in ["win","lose"]: _finish_puzzle()))
		return false
	return true

func _return_title() -> void:
	if animating or save_blocked: return
	if engine!=null and engine.phase=="idle" and not _checkpoint_session(): return
	_navigate("title")

func _session_error(message: String="") -> void:
	save_blocked=true
	_clear_content()
	root_column.get_node("Navigation").hide()
	content.add_child(_label("진행 기록을 확인해 주세요",24))
	content.add_child(_body(message if not message.is_empty() else session.last_error))
	content.add_child(_body("파일을 덮어쓰지 않았어요. 저장을 다시 읽어 이어갈 수 있어요",16))
	content.add_child(_button("다시 읽기",func():
		session_state=session.load_state()
		if not session_state.is_empty():
			save_blocked=false
			_navigate("title")))

func _confirm_abandon(page: String) -> void:
	if session.should_first_puzzle(): _return_title(); return
	if engine==null or engine.phase!="idle": _navigate(page); return
	_confirm("퍼즐을 그만할까요?","현재 판은 클리어 보상 없이 끝나요",func():
		var result=model.abandon(attempt_id)
		if result.ok:
			var saved=session.abandon_puzzle()
			if not saved.ok: _session_error(); return
			animation_epoch+=1
			engine=null
			_navigate(page)
		else: _toast(result.get("message","저장하지 못했어요")))

func _workshop() -> void:
	content.add_child(_label("우리 카페 작업대",26))
	content.add_child(_body("퍼즐에서 모은 방울로 시설을 열고 키워요. 시설 그림과 고양이 애니메이션은 임시 제작 상태예요",15))
	for chapter in catalog.chapters:
		content.add_child(_body("%d장 · %s"%[int(chapter.id),str(chapter.get("name",chapter.get("title","카페")))],22))
		for id in chapter.facilities:
			var f: Dictionary=model.by_id(id)
			var card=_card(content)
			card.add_child(_label(str(f.name),21))
			card.add_child(_body(str(f.catName)+" · "+str(f.personality),15))
			var own=state.owned.get(id)
			if own!=null:
				card.add_child(_label("성장 %d / 3 · %s"%[int(own.level),"보관 중" if own.position==null else "정원에 배치됨"],16))
				card.add_child(_button("시설 살펴보기",func(): _facility_popup(id)))
			else:
				var b=_button("입주 · %d 방울"%int(f.price),func(): _perform("purchase",[id]); _navigate("workshop"))
				b.disabled=int(f.chapter)>int(state.chapter)
				card.add_child(b)
	content.add_child(_label("카페 꾸미기 · 19종",24))
	for d in catalog.decorations:
		var id: String=d.id
		var card=_card(content,Color("f1eee6"))
		card.add_child(_label(str(d.name),19))
		var owned: bool=state.decorOwned.has(id)
		if owned and d.kind in ["floor","path"]:
			card.add_child(_button("적용하기",func(): _perform("equip_surface",[id]); _navigate("home")))
		elif owned: card.add_child(_label("보유 중 · 배치 편집에서 놓을 수 있어요",15))
		else: card.add_child(_button("구매 · %d 방울"%int(d.price),func(): _perform("purchase_decoration",[id]); _navigate("workshop")))

func _facility_popup(id: String) -> void:
	var f: Dictionary=model.by_id(id)
	var own: Dictionary=state.owned[id]
	var card=_popup(str(f.name)+" · "+str(f.catName))
	card.add_child(_body(str(f.action)))
	card.add_child(_body("임시 시설 그림 · 최종 6상태 애니메이션은 아직 제작되지 않았어요",14))
	card.add_child(_label("성장 %d / 3"%int(own.level),20))
	if int(own.level)<3: card.add_child(_button("성장 · %d 방울"%int(f.upgrades[int(own.level)-1]),func(): _perform("upgrade",[id]); _close_popup(); _navigate(current_page)))
	card.add_child(_button("오늘의 동행으로",func(): _perform("set_companion",[f.catId]); _close_popup(); _navigate("home")))
	card.add_child(_button("손님 주문 받기",func(): _perform("begin_order",[id]); _close_popup(); _navigate("home")))
	card.add_child(_button("목표 프로젝트로",func(): _perform("set_project",[id]); _close_popup()))
	for stage in range(1,int(own.level)+1):
		var value=stage
		card.add_child(_button("%d단계 행동 선택"%stage,func(): _perform("behavior",[id,value]); _close_popup()))

func _collection() -> void:
	content.add_child(_label("고양이 도감",26))
	content.add_child(_body("입주한 고양이 %d / 36 · 추억 %d개"%[state.owned.size(),state.memories.size()]))
	for f in catalog.facilities:
		var card=_card(content,Color("eef1e7") if state.owned.has(f.id) else Color("f0efea"))
		card.add_child(_label(str(f.catName)+(" · 입주" if state.owned.has(f.id) else " · 아직 만나기 전"),21))
		card.add_child(_body(str(f.personality),16))
		if state.owned.has(f.id):
			var record: Dictionary=state.companionRecords.get(f.catId,{"runs":0,"wins":0})
			card.add_child(_label("함께한 퍼즐 %d · 클리어 %d"%[int(record.runs),int(record.wins)],15))
	content.add_child(_label("우리의 추억",25))
	for memory in state.memories:
		var card=_card(content,Color("f7ecda"))
		card.add_child(_body(_memory_title(memory),17))
		if memory.kind=="photo":
			var remembered: Dictionary=state.duplicate(true)
			remembered.owned=memory.layout
			remembered.decorOwned=memory.get("decor",{})
			remembered.surfaces=memory.get("surfaces",{"floor":null,"path":null})
			remembered.settings.lighting=memory.lighting
			var view=Garden.new()
			view.custom_minimum_size.y=230
			view.set_state(remembered,catalog)
			card.add_child(view)

func _memory_title(memory: Dictionary) -> String:
	if memory.kind=="photo": return "우리 카페의 한 장면 · "+str(memory.lighting)
	var f=model.by_id(memory.get("facility",""))
	var kinds={"arrival":"입주","growth":"성장","story":"첫 주문","visit":"손님 방문","companion":"함께한 첫 클리어"}
	return str(f.get("catName","고양이"))+" · "+str(kinds.get(memory.kind,memory.kind))

func _begin_edit() -> void:
	state=model.read()
	draft_revision=int(state.revision)
	facility_draft={}
	decor_draft={}
	for id in state.owned: facility_draft[id]=state.owned[id].position
	for id in state.decorOwned: decor_draft[id]=state.decorOwned[id].position
	facility_draft=facility_draft.duplicate(true)
	decor_draft=decor_draft.duplicate(true)
	undo_layout=[]
	edit_selection=""
	_render_editor()

func _render_editor() -> void:
	_clear_content()
	root_column.get_node("PageScroll").vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	root_column.get_node("Navigation").show()
	root_column.get_child(0).show()
	content.add_theme_constant_override("separation",12)
	content.add_child(_label("카페 배치 편집",25))
	content.add_child(_body("목록에서 고른 뒤 정원에 놓고 드래그해요. 저장하기 전까지 실제 배치는 바뀌지 않아요",15))
	garden=Garden.new()
	garden.custom_minimum_size.y=360
	garden.editing=true
	garden.facility_layout=facility_draft
	garden.decor_layout=decor_draft
	garden.highlighted=edit_selection
	garden.set_state(state,catalog)
	garden.position_changed.connect(func(id,deco,_position):
		edit_selection=id
		edit_decor=deco
		_toast("선택한 위치를 저장하거나 되돌릴 수 있어요"))
	content.add_child(garden)
	var actions=HBoxContainer.new()
	actions.add_child(_button("되돌리기",func():
		if not undo_layout.is_empty():
			var last=undo_layout.pop_back()
			facility_draft=last[0]
			decor_draft=last[1]
			_render_editor()))
	actions.add_child(_button("취소",_cancel_edit))
	actions.add_child(_button("저장",func():
		var result: Dictionary=model.save_layout(facility_draft,draft_revision,decor_draft)
		if result.ok:
			draft_revision=-1
			_navigate("home")
			_toast("배치를 저장했어요")
		else: _toast(result.get("message","배치가 겹치거나 저장이 변경됐어요"))))
	content.add_child(actions)
	for deco in [false,true]:
		var list: Dictionary=decor_draft if deco else facility_draft
		for item_id in list:
			var id: String=item_id
			var is_decor: bool=deco
			var info: Dictionary=model.decor_by_id(id) if deco else model.by_id(id)
			if deco and info.kind in ["floor","path"]: continue
			var row=HBoxContainer.new()
			var label=_label(str(info.name),16)
			label.size_flags_horizontal=SIZE_EXPAND_FILL
			row.add_child(label)
			row.add_child(_button("정원에 놓기" if list[id]==null else "보관",func():
				_checkpoint_layout()
				var target: Dictionary=decor_draft if is_decor else facility_draft
				if target[id]!=null: target[id]=null
				else: target[id]=_free_position(is_decor)
				edit_selection=id
				edit_decor=is_decor
				_render_editor(),false))
			content.add_child(row)
	# Record a snapshot before each physical drag, so undo also restores movement.
	garden.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.device==InputEvent.DEVICE_ID_EMULATION: return
		if (event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed): _checkpoint_layout())

func _checkpoint_layout() -> void:
	undo_layout.append([facility_draft.duplicate(true),decor_draft.duplicate(true)])
	if undo_layout.size()>40: undo_layout.pop_front()

func _free_position(deco: bool) -> Dictionary:
	for y in range(20,85,16):
		for x in range(15,92,18):
			var ok=true
			for p in facility_draft.values():
				if p!=null and Vector2((float(p.x)-x)/1.3,float(p.y)-y).length()<(8 if deco else 12): ok=false
			for p in decor_draft.values():
				if p!=null and Vector2((float(p.x)-x)/1.3,float(p.y)-y).length()<(4 if deco else 8): ok=false
			if ok: return {"x":x,"y":y}
	return {"x":48,"y":65}

func _cancel_edit() -> void:
	draft_revision=-1
	facility_draft={}
	decor_draft={}
	undo_layout=[]
	_navigate("home")

func _perform(method: String, args: Array=[]) -> Dictionary:
	var result: Dictionary=model.callv(method,args)
	if not result.ok: _toast(result.get("message","변경을 저장하지 못했어요"))
	else:
		state=model.read()
		balance.text=str(int(state.balance))+" 방울"
		if is_instance_valid(home_screen): home_screen.balance_label.text=str(int(state.balance))
	return result

func _toast(message: String) -> void:
	if is_instance_valid(popup_layer):
		var feedback=popup_layer.find_child("Feedback",true,false)
		if feedback!=null:
			feedback.text=message
			feedback.visible=not message.is_empty()
			return
	if is_instance_valid(puzzle_screen): puzzle_screen.notice(message)
	else:
		status.text=message
		status.visible=not message.is_empty()

func _popup(title: String) -> VBoxContainer:
	_close_popup()
	if current_page=="puzzle": _set_puzzle_paused(true)
	popup_layer=Control.new()
	popup_layer.name="Modal"
	popup_layer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(popup_layer)
	var shade=ColorRect.new()
	shade.color=Color(0.18,0.2,0.16,0.58)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	popup_layer.add_child(shade)
	var margin=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,int((size.x-minf(size.x-36,510))/2))
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,48)
	popup_layer.add_child(margin)
	var center=VBoxContainer.new()
	center.alignment=BoxContainer.ALIGNMENT_CENTER
	margin.add_child(center)
	var panel=PanelContainer.new()
	panel.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var style=StyleBoxFlat.new()
	style.bg_color=CREAM
	style.set_corner_radius_all(24)
	style.content_margin_left=20
	style.content_margin_right=20
	style.content_margin_top=20
	style.content_margin_bottom=20
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y=minf(610,maxf(200,size.y-150))
	panel.add_child(scroll)
	var card=VBoxContainer.new()
	card.size_flags_horizontal=SIZE_EXPAND_FILL
	scroll.add_child(card)
	card.add_child(_body(title,23))
	card.add_child(_button("닫기",_close_popup))
	var feedback=_body("",15)
	feedback.name="Feedback"
	feedback.visible=false
	feedback.add_theme_color_override("font_color",Color("8c3b24"))
	card.add_child(feedback)
	return card

func _close_popup() -> void:
	if is_instance_valid(popup_layer):
		remove_child(popup_layer)
		popup_layer.queue_free()
	popup_layer=null
	_set_puzzle_paused(false)

func _confirm(title: String, detail: String, action: Callable) -> void:
	var card=_popup(title)
	card.add_child(_body(detail))
	card.add_child(_button("계속",func(): _close_popup(); action.call()))

func _show_settings() -> void:
	if state.is_empty(): _show_storage_error(); return
	var card=_popup("카페 메뉴와 설정")
	if not session.should_first_puzzle() and current_page!="puzzle":
		card.add_child(_button("작업대",func(): _close_popup(); _request_navigation("workshop")))
		card.add_child(_button("도감",func(): _close_popup(); _request_navigation("collection")))
		card.add_child(_button("레벨 선택",func(): _close_popup(); _request_navigation("levels")))
		card.add_child(_button("배치 편집",func(): _close_popup(); _begin_edit()))
		card.add_child(_button("손님 주문",_orders_popup))
		card.add_child(_button("추억 남기기",func(): _perform("remember",["photo-native:"+str(Time.get_unix_time_from_system()).replace(".","-")]); _close_popup(); _toast("카페의 한 장면을 남겼어요")))
	card.add_child(_body("현재 기기에 저장됩니다. 계정·클라우드 동기화는 없어요",15))
	var motion=CheckButton.new()
	motion.text="움직임 줄이기"
	motion.button_pressed=state.settings.reduceMotion
	motion.custom_minimum_size.y=60
	motion.toggled.connect(func(value): _perform("setting",[value]))
	card.add_child(motion)
	var sound=CheckButton.new()
	sound.text="효과음"
	sound.button_pressed=state.settings.sound
	sound.custom_minimum_size.y=60
	sound.toggled.connect(func(value): _perform("sound",[value]))
	card.add_child(sound)
	var effects=CheckButton.new()
	effects.text="효과 줄이기"
	effects.button_pressed=state.settings.effects=="low"
	effects.custom_minimum_size.y=60
	effects.toggled.connect(func(value): _perform("effects",["low" if value else "full"]))
	var effects_off=CheckButton.new()
	effects_off.text="효과 끄기"
	effects_off.button_pressed=state.settings.effects=="off"
	effects_off.toggled.connect(func(value): _perform("effects",["off" if value else "full"]))
	card.add_child(effects_off)
	card.add_child(effects)
	if current_page=="puzzle": return
	var row=HBoxContainer.new()
	for light in [["day","낮"],["sunset","노을"],["night","밤"]]:
		var key=light[0]
		row.add_child(_button(light[1],func(): _perform("lighting",[key]); _close_popup(); _navigate(current_page)))
	card.add_child(row)
	card.add_child(_button("카페 JSON 내보내기",func(): _save_dialog(false)))
	var can_restore: bool=session.state.get("phase","") not in ["puzzle","completion"]
	var import_button=_button("카페 JSON 가져오기",func(): _import_dialog())
	import_button.disabled=not can_restore
	card.add_child(import_button)
	var restore_button=_button("이전 저장 복원",func():
		_confirm("이전 저장을 복원할까요?","현재 파일은 별도 보관한 뒤 검증된 백업을 적용합니다",func():
			var result=model.restore_backup()
			if result.ok: _navigate("home")
			else: _toast(result.get("message","백업을 읽을 수 없어요"))))
	restore_button.disabled=not can_restore
	card.add_child(restore_button)
	if not can_restore: card.add_child(_body("진행 중인 퍼즐을 마친 뒤 카페 저장을 가져올 수 있어요",14))
	card.add_child(_body("브라우저 카페 내보내기 JSON은 가져올 수 있어요. 브라우저의 퍼즐 별·잠금 해제 기록은 별도이며 자동으로 옮겨지지 않아요",14))
	card.add_child(_body("원본 코드: PolyForm Noncommercial License 1.0.0. 상업 배포 권리 확인 필요",13))

func _save_dialog(_full: bool) -> void:
	var dialog=FileDialog.new()
	dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog=true
	dialog.add_filter("*.json","카페 저장 JSON")
	dialog.current_file="cats-and-coffee-save.json"
	add_child(dialog)
	dialog.file_selected.connect(func(path):
		var raw: String=model.export_save()
		var file=FileAccess.open(path,FileAccess.WRITE)
		if file==null: _toast("선택한 파일에 저장할 수 없어요")
		else:
			file.store_string(raw)
			file.flush()
			_toast("카페 JSON을 저장했어요" if file.get_error()==OK else "파일 저장에 실패했어요")
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.8)

func _import_dialog() -> void:
	var dialog=FileDialog.new()
	dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog=true
	dialog.add_filter("*.json","카페 저장 JSON")
	add_child(dialog)
	dialog.file_selected.connect(func(path):
		var file=FileAccess.open(path,FileAccess.READ)
		if file==null or file.get_length()>10*1024*1024:
			_toast("읽을 수 없는 파일이거나 10MB를 초과했어요")
		else:
			var raw=file.get_as_text()
			_confirm("카페 저장을 가져올까요?","현재 카페는 별도 보관하고 선택한 JSON으로 복원합니다. 퍼즐 별 기록은 바뀌지 않아요",func():
				var result=model.restore_save(raw)
				if result.ok: _navigate("home"); _toast("카페 저장을 가져왔어요")
				else: _toast(result.get("message","저장 형식이 맞지 않아요")))
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(0.8)

func _show_storage_error() -> void:
	_clear_content()
	content.add_child(_label("저장 파일을 확인해 주세요",24))
	content.add_child(_body(model.last_error+" 원본 파일은 변경하지 않았어요"))
	content.add_child(_button("검증된 백업 복원",func():
		var result=model.restore_backup()
		if result.ok: _navigate("home")
		else: _toast(result.get("message","복원할 수 없어요"))))
	content.add_child(_button("카페 JSON 가져오기",_import_dialog))

func _valid_progress(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1 or not value.get("stars") is Array: return false
	if value.stars.size()!=8 or not _whole_number(value.get("unlocked"),1,8): return false
	for star in value.stars:
		if not _whole_number(star,0,3): return false
	return true

func _whole_number(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high

func _load_progress() -> void:
	if not FileAccess.file_exists(Profile.save_path("user://puzzle-progress.json")): return
	var parser=JSON.new()
	var error=parser.parse(FileAccess.get_file_as_string(Profile.save_path("user://puzzle-progress.json")))
	var value=parser.data if error==OK else null
	if _valid_progress(value): progress=value
	else:
		progress_error="퍼즐 진행 파일이 손상되어 원본을 보존했어요. 카페의 클리어 기록으로 재구성합니다"
		if not state.is_empty():
			for level in state.claimedLevels:
				progress.unlocked=maxi(int(progress.unlocked),mini(8,int(level)+1))
				progress.stars[int(level)-1]=1

func _save_progress() -> bool:
	if not _valid_progress(progress): return false
	var path=Profile.save_path("user://puzzle-progress.json")
	var raw=JSON.stringify(progress)
	var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:
		progress_error="퍼즐 진행 저장 실패. 카페 보상은 따로 보존돼 있어요"
		return false
	file.store_string(raw)
	file.flush()
	var err=file.get_error()
	file.close()
	if err!=OK or FileAccess.get_file_as_string(path+".tmp")!=raw: return false
	if FileAccess.file_exists(path):
		# Preserve the former raw progress before replacing it, including invalid data.
		err=DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(path+".backup"))
		if err!=OK: return false
	err=DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
	if err!=OK: progress_error="퍼즐 진행을 교체하지 못했어요. 이전 기록은 그대로예요"
	return err==OK
