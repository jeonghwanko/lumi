extends SceneTree
## Native Control integration tests. Never run against real user storage.
## Run with fresh /tmp/lumi-ui-* XDG_DATA_HOME, XDG_CONFIG_HOME and XDG_CACHE_HOME:
## Example from repository root:
## tmp=$(mktemp -d /tmp/lumi-ui-XXXXXX); mkdir -p "$tmp"/{data,config,cache}
## LUMI_UI_TEST=1 XDG_DATA_HOME="$tmp/data" XDG_CONFIG_HOME="$tmp/config" XDG_CACHE_HOME="$tmp/cache" godot --headless --path godot --script res://tests/test_ui.gd
## Optional LUMI_UI_TOUCH_ONLY=1 runs pure board pointer/safe-area assertions.
const SCENE_PATH = "res://scenes/main.tscn"
const Board = preload("res://scripts/board_view.gd")
const SafeArea = preload("res://scripts/safe_area.gd")
const Puzzle = preload("res://scripts/puzzle_engine.gd")
var checks := 0
var failures := 0
var scenarios := 0
var scenario := ""
var app: Control
var swaps: Array = []
var taps: Array = []

class FailOnceStore:
	extends RefCounted
	var wrapped: RefCounted
	var last_error := ""
	var commits := 0
	func _init(storage: RefCounted) -> void:
		wrapped=storage
	func get_item(key: String) -> Variant:
		var value=wrapped.get_item(key)
		last_error=wrapped.last_error
		return value
	func commit(raw: String, backup: Variant=null, before_restore: Variant=null) -> bool:
		commits+=1
		if commits==1:
			last_error="Injected one-time cafe commit failure"
			return false
		var ok: bool=wrapped.commit(raw,backup,before_restore)
		last_error=wrapped.last_error
		return ok

func _initialize() -> void:
	ProjectSettings.set_setting("lumi/review_mode",false)
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL [%s] %s" % [scenario,label])

func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s: expected %s; got %s" % [label,str(expected),str(actual)])

func _case(label: String) -> void:
	scenario = label
	scenarios += 1
	print("UI TEST %02d %s" % [scenarios,label])

func _settle() -> void:
	for i in 5: await process_frame

func _resize(dimensions: Vector2i) -> void:
	root.content_scale_size = Vector2i.ZERO
	root.size = dimensions
	await _settle()
	app._safe_layout()
	await _settle()
	_eq(Vector2i(app.size), dimensions, "native logical viewport dimensions")

func _buttons(node: Node, text_value: String = "") -> Array:
	var result: Array = []
	if node is Button and (text_value.is_empty() or node.text == text_value): result.append(node)
	for child in node.get_children(): result.append_array(_buttons(child,text_value))
	return result

func _press(text_value: String, scope: Node = null) -> void:
	var found := _buttons(app if scope == null else scope,text_value)
	_check(found.size() == 1, "one button named " + text_value)
	if found.size() == 1:
		_check(not found[0].disabled, "button enabled " + text_value)
		found[0].pressed.emit()

func _overflow(node: Node, width: float, out: Array) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		if rect.position.x < -1.0 or rect.end.x > width + 1.0:
			out.append("%s (%s) x=%.1f right=%.1f min=%.1f" % [str(node.get_path()),node.get_class(),rect.position.x,rect.end.x,node.get_combined_minimum_size().x])
	for child in node.get_children(): _overflow(child,width,out)

func _assert_width(label: String) -> void:
	var out: Array = []
	_overflow(app,app.size.x,out)
	_check(out.is_empty(), label + " no horizontal overflow: " + "; ".join(out.slice(0,8)))

func _assert_modal_bounds(label: String) -> void:
	_check(is_instance_valid(app.popup_layer),label+" modal exists")
	if not is_instance_valid(app.popup_layer): return
	for panel in app.popup_layer.find_children("*","PanelContainer",true,false):
		var rect: Rect2=panel.get_global_rect()
		_check(rect.position.y>=-0.5 and rect.end.y<=app.size.y+0.5,label+" modal frame fits vertically: "+str(rect))

func _all_controls(node: Node) -> Array:
	var result: Array=[]
	if node is Control and node.is_visible_in_tree(): result.append(node)
	for child in node.get_children(): result.append_array(_all_controls(child))
	return result

func _core_bounds(label: String) -> void:
	var problems: Array=[]
	for control in _all_controls(app):
		var rect: Rect2=control.get_global_rect()
		if rect.position.x < -0.6 or rect.position.y < -0.6 or rect.end.x > app.size.x+0.6 or rect.end.y > app.size.y+0.6:
			problems.append("%s %s"%[str(control.get_path()),str(rect)])
	_check(problems.is_empty(),label+" all visible native Controls inside screen: "+"; ".join(problems.slice(0,8)))
	for button in _buttons(app):
		if not button.is_visible_in_tree(): continue
		_check(button.size.x>=59.9 and button.size.y>=59.9,label+" 60 logical hit target "+str(button.get_path())+" "+str(button.size))
	_check(not app.root_column.get_node("Navigation").is_visible_in_tree(),label+" no legacy nav over primary screen")
	_check(not app.root_column.get_child(0).is_visible_in_tree(),label+" no legacy header over primary screen")
	if is_instance_valid(app.puzzle_screen):
		var parts=[app.puzzle_screen.top,app.puzzle_screen.goal_panel,app.puzzle_screen.moves_panel,app.puzzle_screen.board_panel,app.puzzle_screen.hint_panel,app.puzzle_screen.tools]
		for i in parts.size():
			for j in range(i+1,parts.size()):
				_check(not parts[i].get_global_rect().grow(-0.6).intersects(parts[j].get_global_rect().grow(-0.6)),label+" separate puzzle regions "+str(parts[i].name)+str(parts[i].get_global_rect())+" / "+str(parts[j].name)+str(parts[j].get_global_rect()))


func _core_size_matrix(page: String) -> void:
	for dimensions in [Vector2i(320,568),Vector2i(360,640),Vector2i(390,844),Vector2i(768,1024),Vector2i(844,390),Vector2i(1024,768)]:
		await _resize(dimensions)
		_core_bounds(page+" "+str(dimensions))
	await _resize(Vector2i(390,844))

func _label_texts(node: Node) -> Array:
	var result: Array=[]
	if node is Label: result.append(node.text)
	for child in node.get_children(): result.append_array(_label_texts(child))
	return result

func _assert_first_puzzle_data() -> void:
	_eq(app.engine.moves,18,"first puzzle has actual 18 moves")
	_eq(app.engine.hammers,2,"first puzzle has two hammers")
	_eq(app.engine.plus_left,1,"first puzzle has one +5 booster")
	_eq(app.engine.goals.size(),1,"first puzzle has exactly one goal")
	_eq(int(app.engine.goals[0].type),1,"first goal uses yellow cat type")
	_eq(int(app.engine.goals[0].target),12,"first goal target is 12")
	_eq(app.puzzle_hud.text,"18","moves HUD bound to engine")
	_check(_label_texts(app.goal_box).has("0 / 12"),"goal HUD bound to engine target and current count")
	_eq(app.board_view.tiles.size(),64,"native board has 64 separate cell textures")
	var ids: Dictionary={}
	for tile in app.board_view.tiles:
		_check(tile is TextureRect,"each board tile is a native TextureRect")
		_check(tile.texture is AtlasTexture,"each board tile uses an independent atlas frame")
		if tile.texture is AtlasTexture:
			_eq(tile.texture.atlas.resource_path,"res://assets/cats/colored-cat-tokens-v4.png","approved six-color token atlas source")
		ids[tile.get_instance_id()]=true
	_eq(ids.size(),64,"all native cell nodes are distinct")
	_check(not app.scenery.visible,"puzzle background does not use a flattened board mockup")

func _assert_result_data() -> void:
	var screen=app.content.get_child(0)
	_eq(screen.reward,100,"first result uses actual 100-drop reward")
	_eq(screen.score,app.engine.score,"result score uses engine result")
	_eq(screen.stars,app.engine.stars,"result stars use earned value")
	_eq(screen.get_node("Stars").filled,app.engine.stars,"visible star count matches result")
	_check(_label_texts(screen).has("커피 방울 +100"),"reward badge shows ledger-backed amount")
	_check(_label_texts(screen).has("첫 번째 퍼즐 완료"),"result level label uses actual level")

func _assert_first_home_data() -> void:
	_eq(app.state.owned.size(),1,"first cafe owns exactly one facility")
	_check(app.state.owned.has("f19"),"first cafe owns bell entrance f19")
	_eq(app.state.companion,"cat19","first cafe companion is Jongjong cat19")
	_eq(app.garden._visuals.size(),1,"garden renders only one owned facility")
	var facility=app.garden._visuals.get("facility:f19")
	_check(facility!=null,"owned bell entrance has native visual node")
	if facility!=null:
		_eq(facility.cat_id,"cat19","rendered entrance belongs to actual owned cat")
		_check(facility.embedded_cat,"entrance art contains the single owned cat")
	_eq(app.home_screen.balance_label.text,"100","cafe balance displays credited amount")
	_eq(app.home_screen.project_title.text,"다음: 핸드드립 바","project uses actual f05 catalog name")
	_eq(app.home_screen.project_cost.text,"커피 방울 80","project cost uses actual catalog price")
	_eq(app.home_screen.welcome.text,"우리의 첫 카페","first-arrival greeting only on initial cafe")
	_check(not app.state.owned.has("f05"),"project preview does not grant unpurchased facility")

func _touch(view: Control, index: int, pressed: bool, point: Vector2, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index
	event.pressed=pressed
	event.position=point
	event.canceled=canceled
	view._gui_input(event)

func _drag(view: Control, index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=index
	event.position=point
	view._gui_input(event)

func _tap(view: Control, point: Vector2) -> void:
	_touch(view,0,true,point)
	_touch(view,0,false,point)

func _mouse(view: Control, pressed: bool, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	event.position=point
	view._gui_input(event)

func _native_touch(view: Control, index: int, pressed: bool, point: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index
	event.pressed=pressed
	event.position=view.get_global_transform_with_canvas()*point
	root.push_input(event,true)

func _native_drag(view: Control, index: int, point: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=index
	event.position=view.get_global_transform_with_canvas()*point
	event.relative=relative
	root.push_input(event,true)

func _native_tap(view: Control, point: Vector2) -> void:
	_native_touch(view,0,true,point)
	_native_touch(view,0,false,point)

func _physical_touch(view: Control, index: int, pressed: bool, point: Vector2) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=index
	event.pressed=pressed
	event.position=view.get_global_transform_with_canvas()*point
	Input.parse_input_event(event)

func _physical_drag(view: Control, index: int, point: Vector2, relative: Vector2) -> void:
	var event:=InputEventScreenDrag.new()
	event.index=index
	event.position=view.get_global_transform_with_canvas()*point
	event.relative=relative
	Input.parse_input_event(event)

func _physical_tap(view: Control, point: Vector2) -> void:
	_physical_touch(view,0,true,point)
	_physical_touch(view,0,false,point)

func _native_button_tap(view: Control) -> void:
	_physical_tap(view,view.size/2)

func _probe_native_buttons() -> void:
	_case("physical touch activates native buttons exactly once")
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(390,844)
	var probe:=Button.new()
	probe.text="Touch probe"
	probe.size=Vector2(200,60)
	root.add_child(probe)
	var hits: Array=[0]
	probe.pressed.connect(func(): hits[0]+=1)
	await _settle()
	_native_button_tap(probe)
	await _settle()
	_eq(hits[0],1,"physical ScreenTouch plus platform mouse emulation activates button once")
	probe.queue_free()
	await _settle()

func _run() -> void:
	var data_dir := OS.get_environment("XDG_DATA_HOME")
	var isolated: bool=data_dir.begins_with("/tmp/lumi-ui-")
	if OS.get_name()=="Windows":
		isolated=str(ProjectSettings.get_setting("application/config/name", "")).begins_with("Lumi-Isolated-")
	if OS.get_environment("LUMI_UI_TEST") != "1" or not isolated:
		push_error("Refusing to touch production saves. Set LUMI_UI_TEST=1 and fresh /tmp/lumi-ui-* XDG storage, or on Windows use a copied project named Lumi-Isolated-<unique id>.")
		quit(2)
		return
	print("Isolated native user storage: " + OS.get_user_data_dir())
	if OS.get_environment("LUMI_UI_BUTTON_PROBE")=="1":
		await _probe_native_buttons()
		quit(0 if failures==0 else 1)
		return
	if OS.get_environment("LUMI_UI_TOUCH_ONLY") == "1":
		await _touch_tests()
		_safe_area_tests()
		print("UI TOUCH TESTS: %d scenarios, %d assertions, %d failures" % [scenarios,checks,failures])
		quit(0 if failures == 0 else 1)
		return
	if FileAccess.file_exists("user://cafe-save.json") or FileAccess.file_exists("user://session-save.json"):
		push_error("UI suite needs a fresh isolated XDG directory; existing test saves were not touched.")
		quit(2)
		return
	app = load(SCENE_PATH).instantiate()
	root.add_child(app)
	await _settle()
	_case("native scene boot and initial persistence")
	_eq(app.current_page,"title","launch opens title")
	_check(not app.state.is_empty(),"valid cafe state loaded")
	_check(app.content.get_child(0).name == "TitleScreen","native title scene exists")
	_check(app.model.storage.path.begins_with("user://"),"native save path")
	_eq(app.root_column.get_node("Navigation").get_child_count(),4,"four navigation destinations")
	_check(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"),"native buttons receive emulated mouse from physical touch")
	await _first_run_flow()
	await _navigation_and_sizes()
	await _touch_tests()
	await _probe_native_buttons()
	await _layout_tests()
	await _lifecycle_tests()
	await _pause_tests()
	await _puzzle_input_integration()
	await _restart_tests()
	await _reward_tests()
	await _progress_tests()
	_safe_area_tests()
	app._close_popup()
	app.sound_fx.stop()
	await _settle()
	app.queue_free()
	await _settle()
	print("UI TESTS: %d scenarios, %d assertions, %d failures" % [scenarios,checks,failures])
	quit(0 if failures == 0 else 1)

func _navigation_and_sizes() -> void:
	_case("home workshop collection level navigation and locked level guard")
	for entry in [["workshop","작업대"],["collection","도감"],["levels","레벨 선택"]]:
		var page: String=entry[0]
		app._navigate("home")
		await _settle()
		_native_button_tap(app.home_screen.settings_button)
		await _settle()
		_check(is_instance_valid(app.popup_layer),"native home gear opens menu")
		_press(entry[1],app.popup_layer)
		await _settle()
		_eq(app.current_page,page,"menu navigation " + page)
		_check(app.content.get_child_count() > 0,page + " has native content")
		app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
		_eq(app.current_page,"home","secondary page returns to cafe")
	app._navigate("levels")
	var old_id: String = app.attempt_id
	app._start_level(2)
	_eq(app.current_page,"levels","locked third level cannot start")
	_eq(app.attempt_id,old_id,"locked start creates no attempt")
	app._start_level(-1)
	_eq(app.current_page,"levels","negative level blocked")
	_case("phone tablet landscape viewport matrix and overlays")
	for dimensions in [Vector2i(320,568),Vector2i(360,640),Vector2i(390,844),Vector2i(768,1024),Vector2i(844,390),Vector2i(1024,768)]:
		await _resize(dimensions)
		for page in ["home","workshop","collection","levels"]:
			app._navigate(page)
			await _settle()
			_assert_width(str(dimensions)+" "+page)
			_check(app.frame.size.x <= 580.1,"centered content max width 580")
			_check(app.frame.position.x >= -0.1,"content starts on screen")
		app._show_settings()
		await _settle()
		_assert_width(str(dimensions)+" settings modal")
		_assert_modal_bounds(str(dimensions)+" settings")
		_check(is_instance_valid(app.popup_layer),"settings popup exists")
		app._close_popup()
		app._facility_popup("f19")
		await _settle()
		_assert_width(str(dimensions)+" facility modal")
		_assert_modal_bounds(str(dimensions)+" facility")
		app._close_popup()
		app._start_level(0)
		await _settle()
		_assert_width(str(dimensions)+" puzzle")
		_check(app.board_view is Control,"native puzzle board is Control")
		_eq(app.board_view.tiles.size(),64,"64 native tile textures")
		_check(absf(app.board_view.size.x-app.board_view.size.y)<1.0,"square board")
		_check(app.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE,"overlay passes pointer events through")
		app.model.abandon(app.attempt_id)
		app.session.abandon_puzzle()
		app.engine=null
		app._navigate("home")
	_case("native later-level HUD goal density at phone and landscape sizes")
	for dimensions in [Vector2i(320,568),Vector2i(390,844),Vector2i(844,390)]:
		await _resize(dimensions)
		for index in [1,6,7]:
			app.engine=Puzzle.new()
			app.engine.initialize(index,34123)
			app._navigate("puzzle")
			await _settle()
			_core_bounds("level %d at %s"%[index+1,str(dimensions)])
			_eq(app.goal_box.get_child_count(),app.engine.goals.size(),"every live goal rendered")
	app.engine=null
	app._navigate("home")
	_case("open popup survives rotation without horizontal overflow")
	await _resize(Vector2i(768,1024))
	app._show_settings()
	await _settle()
	await _resize(Vector2i(360,640))
	_assert_width("rotated settings popup")
	_assert_modal_bounds("rotated phone settings")
	await _resize(Vector2i(844,390))
	_assert_width("rotated landscape settings popup")
	_assert_modal_bounds("rotated landscape settings")
	app._close_popup()
	await _resize(Vector2i(360,640))

func _touch_tests() -> void:
	_case("board tap adjacency toggling bounds and hammer interception")
	var board: Control = Board.new()
	root.add_child(board)
	board.size=Vector2(320,320)
	var puzzle = Puzzle.new()
	puzzle.initialize(0,34123)
	board.set_board(puzzle.board)
	board.swap_requested.connect(func(a,b): swaps.append([a,b]))
	board.tile_pressed.connect(func(cell): taps.append(cell))
	_eq(board.cell_at(Vector2(0,0)),Vector2i(0,0),"upper-left bound")
	_eq(board.cell_at(Vector2(319.9,319.9)),Vector2i(7,7),"lower-right bound")
	_eq(board.cell_at(Vector2(320,100)),Vector2i(-1,-1),"outside right edge")
	_eq(board.cell_at(Vector2(-1,10)),Vector2i(-1,-1),"outside left edge")
	_tap(board,Vector2(20,20))
	_eq(board.selected,Vector2i(0,0),"first tap selects")
	_tap(board,Vector2(60,20))
	_eq(swaps.size(),1,"adjacent tap pair requests one swap")
	_eq(swaps[0],[Vector2i(0,0),Vector2i(1,0)],"tap swap coordinates")
	_eq(board.selected,Vector2i(-1,-1),"swap clears selection")
	_tap(board,Vector2(100,100))
	_tap(board,Vector2(100,100))
	_eq(board.selected,Vector2i(-1,-1),"repeated same tap toggles off")
	_tap(board,Vector2(20,20))
	_tap(board,Vector2(220,220))
	_eq(swaps.size(),1,"nonadjacent tap never swaps")
	_eq(board.selected,Vector2i(5,5),"nonadjacent tap changes selection")
	board.cancel_touch()
	board.show_hammer=true
	_tap(board,Vector2(20,20))
	_eq(board.selected,Vector2i(-1,-1),"hammer tap does not select ordinary tile")
	board.show_hammer=false
	_case("touch swipe threshold one-swap-per-gesture and edge rejection")
	swaps.clear()
	taps.clear()
	_touch(board,7,true,Vector2(20,20))
	_drag(board,7,Vector2(25,20))
	_eq(swaps.size(),0,"jitter below threshold ignored")
	_drag(board,7,Vector2(60,20))
	_drag(board,7,Vector2(140,20))
	_touch(board,7,false,Vector2(140,20))
	_eq(swaps.size(),1,"long repeated drag emits one swap")
	_eq(taps.size(),0,"drag release emits no tap")
	_touch(board,8,true,Vector2(20,20))
	_drag(board,8,Vector2(-40,20))
	_touch(board,8,false,Vector2(20,20))
	_eq(swaps.size(),1,"outward edge swipe ignored")
	_eq(taps.size(),0,"outward edge swipe does not become tap")
	_case("multitouch ownership repeated release and canceled touch")
	swaps.clear()
	taps.clear()
	_touch(board,1,true,Vector2(20,20))
	_touch(board,2,true,Vector2(100,100))
	_drag(board,2,Vector2(140,100))
	_touch(board,2,false,Vector2(100,100))
	_eq(board.active_touch,1,"secondary finger cannot steal owner")
	_eq(swaps.size(),0,"secondary finger cannot swap")
	_eq(taps.size(),0,"secondary release cannot tap")
	_touch(board,1,false,Vector2(20,20))
	_eq(taps.size(),1,"owner releases once")
	_touch(board,1,false,Vector2(20,20))
	_eq(taps.size(),1,"repeated owner release ignored")
	board.cancel_touch()
	taps.clear()
	_touch(board,3,true,Vector2(20,20))
	_touch(board,3,false,Vector2(20,20),true)
	_eq(taps.size(),0,"OS-canceled touch must not commit a tap")
	_eq(board.active_touch,-1,"OS-canceled touch clears owner")
	_eq(board.selected,Vector2i(-1,-1),"OS-canceled touch clears selection")
	_case("focus cancellation and disabled board ignore stale pointer releases")
	board.cancel_touch()
	taps.clear()
	_touch(board,4,true,Vector2(20,20))
	board.cancel_touch()
	_touch(board,4,false,Vector2(20,20))
	_eq(taps.size(),0,"touch release after cancellation ignored")
	_mouse(board,true,Vector2(20,20))
	board.cancel_touch()
	_mouse(board,false,Vector2(20,20))
	_eq(taps.size(),0,"mouse release after cancellation ignored")
	board.enabled=false
	swaps.clear()
	taps.clear()
	_tap(board,Vector2(20,20))
	_eq(taps.size(),0,"disabled board emits no tap")
	_eq(swaps.size(),0,"disabled board emits no swap")
	board.queue_free()
	await _settle()

func _layout_tests() -> void:
	_case("compact editor menu entry preserves scrolling to save and cancel")
	await _resize(Vector2i(320,568))
	app._navigate("home")
	await _settle()
	_native_button_tap(app.home_screen.settings_button)
	await _settle()
	_press("배치 편집",app.popup_layer)
	await _settle()
	_check(app.draft_revision>=0,"home menu opens editor")
	var page_scroll: ScrollContainer=app.root_column.get_node("PageScroll")
	_check(page_scroll.vertical_scroll_mode!=ScrollContainer.SCROLL_MODE_DISABLED,"editor restores vertical scrolling on compact phone")
	page_scroll.scroll_vertical=10000
	await _settle()
	var save_buttons=_buttons(app.content,"저장")
	_check(save_buttons.size()==1,"editor has one save action")
	if save_buttons.size()==1:
		var rect: Rect2=save_buttons[0].get_global_rect()
		_check(rect.position.y>=0 and rect.end.y<=app.size.y,"compact editor save reachable after scrolling "+str(rect))
	_press("취소")
	await _settle()
	await _resize(Vector2i(390,844))
	_case("layout edit draft cancel save undo and storage isolation")
	app._navigate("home")
	await _settle()
	var original: Dictionary = app.model.read().owned.f19.position.duplicate(true)
	app._begin_edit()
	await _settle()
	_check(app.draft_revision>=0,"editor captures save revision")
	_check(app.garden.editing,"garden editor mode")
	app._checkpoint_layout()
	app.facility_draft.f19={"x":65,"y":45}
	_eq(app.model.read().owned.f19.position,original,"draft does not change persisted state")
	_press("되돌리기")
	await _settle()
	_eq(app.facility_draft.f19,original,"undo restores previous position")
	app.facility_draft.f19={"x":65,"y":45}
	_press("취소")
	await _settle()
	_eq(app.draft_revision,-1,"cancel exits editing")
	_eq(app.model.read().owned.f19.position,original,"cancel keeps durable layout")
	app._begin_edit()
	await _settle()
	app.facility_draft.f19={"x":64,"y":44}
	_press("저장")
	await _settle()
	_eq(app.current_page,"home","save returns home")
	_eq(app.draft_revision,-1,"save ends edit transaction")
	_eq(float(app.model.read().owned.f19.position.x),64.0,"save commits draft x")
	_eq(float(app.model.read().owned.f19.position.y),44.0,"save commits draft y")
	app._begin_edit()
	await _settle()
	_press("보관")
	await _settle()
	_check(app.facility_draft.f19==null,"storage button removes draft item from garden")
	_press("되돌리기")
	await _settle()
	_check(app.facility_draft.f19!=null,"undo restores stored draft item")
	app._cancel_edit()
	_case("layout physical drag coordinates clamping and cancel")
	app._begin_edit()
	await _settle()
	var garden: Control = app.garden
	var point=Vector2(float(app.facility_draft.f19.x)/100*garden.size.x,float(app.facility_draft.f19.y)/100*garden.size.y)
	_touch(garden,5,true,point)
	_eq(garden.drag_id,"f19","garden touch hits facility")
	_drag(garden,5,Vector2(garden.size.x*2,-20))
	_touch(garden,5,false,Vector2(garden.size.x*2,-20))
	_eq(float(app.facility_draft.f19.x),92.0,"drag clamps right boundary")
	_eq(float(app.facility_draft.f19.y),12.0,"drag clamps top boundary")
	_eq(garden.touch_id,-1,"drag release clears touch owner")
	_eq(garden.drag_id,"","drag release clears item")
	_eq(float(app.model.read().owned.f19.position.x),64.0,"physical drag still uncommitted")
	app._cancel_edit()
	_case("real viewport garden drag dispatch records undo checkpoint")
	app._begin_edit()
	await _settle()
	garden=app.garden
	point=Vector2(float(app.facility_draft.f19.x)/100*garden.size.x,float(app.facility_draft.f19.y)/100*garden.size.y)
	var target=Vector2(garden.size.x*0.8,garden.size.y*0.65)
	_physical_touch(garden,0,true,point)
	await _settle()
	_eq(app.undo_layout.size(),1,"native GUI touch records exactly one undo checkpoint")
	_physical_drag(garden,0,target,target-point)
	_physical_touch(garden,0,false,target)
	await _settle()
	_check(absf(float(app.facility_draft.f19.x)-80)<0.1,"native screen drag routes to garden")
	_press("되돌리기")
	await _settle()
	_eq(float(app.facility_draft.f19.x),64.0,"undo restores real pointer-driven drag")
	app._cancel_edit()
	_case("stale layout revision rejects without closing editor")
	app._begin_edit()
	await _settle()
	app.model.setting(true)
	app.facility_draft.f19={"x":20,"y":40}
	_press("저장")
	await _settle()
	_check(app.draft_revision>=0,"stale revision leaves editor open")
	_eq(float(app.model.read().owned.f19.position.x),64.0,"stale save preserves actual layout")
	app._cancel_edit()

func _lifecycle_tests() -> void:
	_case("back dismisses popup and protects unsaved editor")
	app._navigate("workshop")
	app._show_settings()
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not is_instance_valid(app.popup_layer),"back closes modal first")
	_eq(app.current_page,"workshop","modal back preserves page")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_eq(app.current_page,"home","secondary page back returns cafe")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(is_instance_valid(app.popup_layer),"root cafe back opens exit confirmation")
	_press("닫기",app.popup_layer)
	_eq(app.current_page,"home","cancel root exit keeps cafe")
	await _settle()
	app._begin_edit()
	app.facility_draft.f19={"x":20,"y":50}
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(is_instance_valid(app.popup_layer),"unsaved editor back asks before discarding")
	_check(app.draft_revision>=0,"confirmation retains draft")
	_press("닫기",app.popup_layer)
	_check(app.draft_revision>=0,"dismiss confirmation keeps editor")
	app._request_navigation("collection")
	_press("계속",app.popup_layer)
	await _settle()
	_eq(app.current_page,"collection","confirmed navigation changes page")
	_eq(app.draft_revision,-1,"confirmed navigation discards draft")
	_case("focus loss cancels active board and garden gesture")
	app._start_level(0)
	await _settle()
	_touch(app.board_view,9,true,Vector2(20,20))
	app._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_eq(app.board_view.active_touch,-1,"focus loss cancels board owner")
	_eq(app.board_view.selected,Vector2i(-1,-1),"focus loss clears tile selection")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_eq(app.current_page,"puzzle","back dismisses focus pause without leaving puzzle")
	_check(not app.paused_ui,"dismiss focus pause resumes board")
	await _settle()
	app._confirm_abandon("home")
	_check(is_instance_valid(app.popup_layer),"explicit abandon asks before abandoning")
	_press("계속",app.popup_layer)
	await _settle()
	_eq(app.current_page,"home","confirmed abandon returns home")
	_check(app.engine==null,"abandon releases engine")
	_eq(app.session.state.phase,"cafe","abandon clears durable puzzle snapshot")
	app._begin_edit()
	await _settle()
	var garden: Control=app.garden
	var p=app.facility_draft.f19
	_touch(garden,11,true,Vector2(p.x/100*garden.size.x,p.y/100*garden.size.y))
	app._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_eq(garden.touch_id,-1,"focus loss cancels garden owner")
	_eq(garden.drag_id,"","focus loss clears garden drag")
	app._cancel_edit()

func _pause_tests() -> void:
	_case("pause modal locks board boosters repeated input and exact progress")
	app._start_level(0)
	await _settle()
	var snapshot=JSON.stringify(app.session.state,"",true,true)
	var before_moves: int=app.engine.moves
	var before_hammers: int=app.engine.hammers
	var before_plus: int=app.engine.plus_left
	var pair: Array=app.engine.hint()
	app.puzzle_screen.back_button.pressed.emit()
	await _settle()
	_check(app.paused_ui,"native pause icon opens paused state")
	_check(is_instance_valid(app.popup_layer),"pause modal exists")
	_check(not app.board_view.enabled,"pause disables native board")
	_check(app.hammer_button.disabled and app.plus_button.disabled,"pause disables both tools")
	for i in 4:
		app._plus()
		app.hammer_armed=true
		app._tile_press(Vector2i(0,0))
		if pair.size()==2: app._swap(pair[0],pair[1])
		_native_tap(app.board_view,Vector2(20,20))
	_eq(app.engine.moves,before_moves,"paused repeat input spends no moves")
	_eq(app.engine.hammers,before_hammers,"paused repeat input spends no hammers")
	_eq(app.engine.plus_left,before_plus,"paused repeat input spends no +5")
	_eq(JSON.stringify(app.session.state,"",true,true),snapshot,"pause preserves exact durable puzzle")
	app.hammer_armed=false
	_press("계속하기",app.popup_layer)
	_check(not app.paused_ui and app.board_view.enabled,"continue restores board input")
	_check(not app.hammer_button.disabled and not app.plus_button.disabled,"continue restores available tools")
	app.puzzle_screen.settings_button.pressed.emit()
	_check(app.paused_ui,"puzzle settings also pause play")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not app.paused_ui,"back dismisses settings and resumes")
	_case("pausing mid-animation preserves checkpoint and safe title resume")
	app.model.setting(false)
	app.state=app.model.read()
	app.engine.initialize(0,34123)
	app.session.checkpoint(app.engine)
	app._refresh_puzzle()
	pair=app.engine.hint()
	app._swap(pair[0],pair[1])
	_check(app.animating,"ordinary move starts native presentation animation")
	app._open_pause()
	var paused_board=JSON.stringify(app.board_view.cells,"",true,true)
	await create_timer(0.18).timeout
	_eq(JSON.stringify(app.board_view.cells,"",true,true),paused_board,"paused animation does not advance displayed board")
	var durable=JSON.stringify(app.session.state.puzzle_snapshot,"",true,true)
	_press("타이틀로 · 진행 저장",app.popup_layer)
	await create_timer(0.18).timeout
	_eq(app.current_page,"title","mid-animation pause can save and return title")
	_check(not app.animating and not app.paused_ui,"old animation and pause flags cleared")
	_eq(JSON.stringify(app.session.state.puzzle_snapshot,"",true,true),durable,"title preserves already-resolved native checkpoint")
	app._title_start()
	await _settle()
	_eq(app.current_page,"puzzle","mid-animation return resumes playable puzzle")
	_eq(app.engine.moves,int(app.session.state.puzzle_snapshot.moves),"resumed puzzle retains move count")
	_case("stale canceled animation cannot clear a rapid resumed animation flag")
	# Presentation-only fixtures isolate coroutine ownership without changing
	# engine progress; engine transactions are covered by the native input cases.
	app._animate_result({"steps":[{"board":app.engine.board}]})
	app._open_pause()
	app._pause_to_title()
	app._title_start()
	app._animate_result({"steps":[{"board":app.engine.board},{"board":app.engine.board},{"board":app.engine.board},{"board":app.engine.board}]})
	await create_timer(0.15).timeout
	_check(app.animating,"stale old coroutine cannot clear newer animation busy flag")
	await create_timer(0.45).timeout
	_check(not app.animating,"new animation completes and clears its own busy flag")
	_eq(app.current_page,"puzzle","rapid resume stays in active puzzle")
	app.model.abandon(app.attempt_id)
	app.session.abandon_puzzle()
	app.engine=null
	app._navigate("home")

func _puzzle_input_integration() -> void:
	_case("cafe direct puzzle action and real engine tap swap integration")
	app._navigate("home")
	app.model.setting(true)
	await _settle()
	var attempts_before: int=app.model.read().attempts.size()
	var play=app.home_screen.play_button
	_native_button_tap(play)
	play.pressed.emit()
	await _settle()
	_eq(app.model.read().attempts.size(),attempts_before+1,"rapid repeated cafe CTA creates exactly one attempt")
	_eq(app.current_page,"puzzle","cafe primary button directly starts puzzle")
	_eq(app.engine.level_index,int(app.progress.unlocked)-1,"cafe starts latest unlocked level")
	# Deterministic live-engine fixture prevents cascade randomness making the
	# booster assertions disappear behind a chance early completion.
	app.engine.initialize(app.engine.level_index,34123)
	_check(app.session.checkpoint(app.engine).ok,"deterministic native input fixture checkpoint")
	app._refresh_puzzle()
	var pair: Array=app.engine.hint()
	_check(pair.size()==2,"live puzzle offers legal hint")
	if pair.size()==2:
		var unit: float=app.board_view.size.x/8
		var moves: int=app.engine.moves
		_physical_tap(app.board_view,(Vector2(pair[0])+Vector2.ONE*0.5)*unit)
		_physical_tap(app.board_view,(Vector2(pair[1])+Vector2.ONE*0.5)*unit)
		await _settle()
		_eq(app.engine.moves,moves-1,"native tap pair reaches engine exactly once")
		_eq(int(app.session.state.puzzle_snapshot.moves),app.engine.moves,"swap persisted before presentation")
		_eq(app.board_view.cells,app.engine.board,"board refresh equals resolved engine board")
	_case("native hammer tap interception and displayed booster counts")
	if app.engine.phase=="idle":
		var hammers: int=app.engine.hammers
		_press("망치  ·  %d"%hammers)
		_check(app.hammer_armed,"hammer button arms tool")
		_physical_tap(app.board_view,Vector2.ONE*(app.board_view.size.x/16))
		await _settle()
		_eq(app.engine.hammers,hammers-1,"hammer tap consumes one tool")
		_eq(app.board_view.selected,Vector2i(-1,-1),"hammer tap must not leave ordinary tile selected")
		_check(_buttons(app.content,"망치  ·  %d"%app.engine.hammers).size()==1,"hammer label refreshes remaining count")
		_press("+5   ·  %d"%app.engine.plus_left)
		await _settle()
		_check(_buttons(app.content,"+5   ·  0").size()==1,"extra moves label refreshes consumed count")
	app.model.abandon(app.attempt_id)
	app.session.abandon_puzzle()
	app.engine=null
	app._navigate("home")
	_case("puzzle checkpoint write failure freezes controls and retries same action")
	app._start_level(0)
	await _settle()
	var before: int=app.engine.moves
	app.session.storage.fail_writes=true
	app._plus()
	_check(app.save_blocked,"failed checkpoint blocks new actions")
	_eq(app.engine.moves,before+5,"pending action held in memory for retry")
	_eq(int(app.session.state.puzzle_snapshot.moves),before,"durable snapshot preserved on failure")
	app._plus()
	_eq(app.engine.moves,before+5,"repeat blocked action has no further effect")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_eq(app.current_page,"puzzle","back cannot abandon unresolved checkpoint")
	_check(is_instance_valid(app.popup_layer),"checkpoint retry dialog remains open")
	app.session.storage.fail_writes=false
	_press("저장 다시 시도",app.popup_layer)
	await _settle()
	_check(not app.save_blocked,"successful retry unblocks puzzle")
	_eq(int(app.session.state.puzzle_snapshot.moves),before+5,"retry commits existing action exactly once")
	_eq(int(app.session.state.puzzle_snapshot.plus_left),0,"retry preserves spent booster")
	app.model.abandon(app.attempt_id)
	app.session.abandon_puzzle()
	app.engine=null
	app._navigate("home")

func _restart_tests() -> void:
	_case("restart confirmation resets puzzle and replacement survives native relaunch")
	app._start_level(0)
	await _settle()
	var old_id: String=app.attempt_id
	app._plus()
	app._restart_request()
	_check(is_instance_valid(app.popup_layer),"restart presents confirmation")
	_press("닫기",app.popup_layer)
	_eq(app.attempt_id,old_id,"dismissed restart keeps original attempt")
	app._restart_request()
	_press("계속",app.popup_layer)
	await _settle()
	var new_id: String=app.attempt_id
	_check(new_id!=old_id,"confirmed restart creates distinct attempt")
	_eq(app.model.read().attempts[old_id].status,"abandoned","old attempt abandoned after replacement")
	_eq(app.model.read().attempts[new_id].status,"active","replacement attempt active")
	_eq(app.session.state.attempt_id,new_id,"replacement snapshot persisted")
	_eq(app.engine.moves,int(app.engine.level_data.moves),"restart resets move budget")
	_eq(app.engine.plus_left,1,"restart resets booster budget")
	await _restart_app()
	app._title_start()
	await _settle()
	_eq(app.attempt_id,new_id,"relaunch resumes replacement attempt")
	_eq(app.current_page,"puzzle","relaunch keeps restarted game playable")
	_case("cafe write failure during restart preserves active attempt identity")
	old_id=app.attempt_id
	var snapshot=JSON.stringify(app.engine.board,"",true,true)
	app.model.storage.fail_writes=true
	app._restart_puzzle()
	_eq(app.attempt_id,old_id,"failed begin must not replace attempt identifier")
	_eq(JSON.stringify(app.engine.board,"",true,true),snapshot,"failed begin preserves active board")
	_eq(app.session.state.attempt_id,old_id,"failed begin preserves durable attempt")
	_eq(app.current_page,"puzzle","failed begin keeps puzzle page")
	app.model.storage.fail_writes=false
	await _restart_app()
	app._title_start()
	await _settle()
	_eq(app.attempt_id,old_id,"failed restart recovers original attempt on relaunch")
	_case("transient restart failure never abandons unchanged original attempt")
	var original_storage: RefCounted=app.model.storage
	var transient=FailOnceStore.new(original_storage)
	app.model.storage=transient
	app._restart_puzzle()
	_eq(app.attempt_id,old_id,"one-time begin failure preserves active ID")
	_eq(app.model.read().attempts[old_id].status,"active","one-time failure cannot abandon original")
	_eq(transient.commits,1,"failed restart must not make abandonment commit")
	app.model.storage=original_storage
	if app.model.read().attempts[old_id].status!="active":
		app._start_level(0)
		old_id=app.attempt_id
		await _settle()
	_case("session write failure during restart preserves previous resumable puzzle")
	app.session.storage.fail_writes=true
	app._restart_puzzle()
	_check(app.save_blocked,"failed replacement snapshot blocks gameplay")
	_eq(app.session.state.attempt_id,old_id,"failed replacement retains durable original ID")
	_eq(app.model.read().attempts[old_id].status,"active","original attempt remains active until replacement saved")
	app.session.storage.fail_writes=false
	_press("다시 읽기")
	app._title_start()
	await _settle()
	_eq(app.attempt_id,old_id,"reread recovers original playable attempt")
	_eq(app.current_page,"puzzle","reread resumes puzzle")
	_check(not app.save_blocked,"successful reread clears blocked state")
	_case("interrupted abandonment clears stale durable snapshot on title resume")
	app.model.abandon(app.attempt_id)
	await _restart_app()
	app._title_start()
	await _settle()
	_eq(app.current_page,"title","abandoned saved attempt cannot resume gameplay")
	_eq(app.session.state.phase,"cafe","stale abandoned checkpoint cleared safely")
	_check(not app.save_blocked,"recoverable abandoned checkpoint does not block player")
	app._title_start()
	await _settle()
	_eq(app.current_page,"home","returning player can continue into cafe after recovery")

func _mark_win() -> void:
	app.engine.got_fruit=app.engine.need_fruit.duplicate()
	app.engine.got_ice=app.engine.need_ice
	app.engine.got_crate=app.engine.need_crate
	app.engine.phase="win"
	app.engine.score=900
	app.engine.stars=Puzzle.stars_for(app.engine.moves,app.engine.level_data.moves)
	app.engine._sync_goals()

func _mark_loss() -> void:
	app.engine.moves=0
	app.engine.phase="lose"
	app.engine.stars=0

func _restart_app() -> void:
	app.sound_fx.stop()
	await _settle()
	app.queue_free()
	await _settle()
	app=load(SCENE_PATH).instantiate()
	root.add_child(app)
	await _settle()

func _first_run_flow() -> void:
	_case("mandatory title to first puzzle gate and repeated start suppression")
	await _resize(Vector2i(360,640))
	_assert_width("fresh title")
	await _core_size_matrix("title")
	app._navigate("home")
	_eq(app.current_page,"title","new install cannot bypass first puzzle into cafe")
	app.model.storage.fail_writes=true
	_native_button_tap(app.content.get_child(0).get_node("StartButton"))
	await _settle()
	_eq(app.current_page,"title","failed initial save stays on title")
	_eq(app.model.read().attempts.size(),0,"failed initial save creates no orphan attempt")
	_check(not app.content.get_child(0).get_node("StartButton").disabled,"failed initial save re-enables title CTA")
	app.model.storage.fail_writes=false
	var start=app.content.get_child(0).get_node("StartButton")
	_native_button_tap(start)
	start.pressed.emit()
	await _settle()
	_eq(app.current_page,"puzzle","title start opens first puzzle")
	_eq(app.model.read().attempts.size(),1,"repeated start creates exactly one attempt")
	_eq(app.engine.level_index,0,"first puzzle is level one")
	await _core_size_matrix("puzzle")
	_assert_first_puzzle_data()
	_eq(app.session.state.phase,"puzzle","first puzzle has durable snapshot")
	_check(app.session.should_first_puzzle(),"cafe gate remains locked during first puzzle")
	app._request_navigation("home")
	_eq(app.current_page,"puzzle","first puzzle navigation cannot open cafe")
	_check(not app.root_column.get_node("Navigation").visible,"puzzle hides cafe navigation")
	_case("puzzle action checkpoint survives title return and native scene reload")
	var id: String=app.attempt_id
	var moves: int=app.engine.moves
	app._plus()
	_eq(app.engine.moves,moves+5,"native plus button action grants five moves")
	_eq(app.engine.plus_left,0,"plus consumed once")
	app._plus()
	_eq(app.engine.moves,moves+5,"repeat plus cannot grant twice")
	var snapshot=JSON.stringify(app.engine.board,"",true,true)
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_eq(app.current_page,"puzzle","back pauses first puzzle")
	_check(app.paused_ui,"back sets explicit pause state")
	_press("타이틀로 · 진행 저장",app.popup_layer)
	_eq(app.current_page,"title","pause menu can save and return to title")
	await _restart_app()
	_eq(app.current_page,"title","native relaunch always presents title")
	app._title_start()
	await _settle()
	_eq(app.current_page,"puzzle","continue restores live puzzle")
	_eq(app.attempt_id,id,"resume keeps reward attempt identifier")
	_eq(app.engine.moves,moves+5,"resume keeps remaining moves")
	_eq(app.engine.plus_left,0,"resume keeps consumed booster")
	_eq(JSON.stringify(app.engine.board,"",true,true),snapshot,"resume restores exact board")
	_case("first loss cannot unlock cafe and completion resumes after relaunch")
	_mark_loss()
	app._finish_puzzle()
	await _settle()
	_eq(app.current_page,"completion","loss routes to dedicated completion scene")
	_check(_buttons(app.content,"카페로 가기").is_empty(),"first loss offers no cafe bypass")
	_check(app.session.should_first_puzzle(),"loss keeps first-run lock")
	_eq(int(app.model.read().balance),0,"first loss grants no reward")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_eq(app.current_page,"completion","back cannot skip first result")
	await _restart_app()
	app._title_start()
	await _settle()
	_eq(app.current_page,"completion","pending completion resumes after native relaunch")
	_eq(int(app.model.read().balance),0,"resumed loss remains unrewarded")
	_press("다시 시작하기")
	await _settle()
	_eq(app.current_page,"puzzle","first loss retry enters puzzle")
	_check(app.attempt_id!=id,"retry has distinct reward attempt")
	_case("first win completion acknowledgment unlocks cafe exactly once")
	_mark_win()
	app._finish_puzzle()
	await _settle()
	_eq(app.current_page,"completion","win enters dedicated completion scene")
	_assert_width("first win completion")
	await _core_size_matrix("completion")
	_assert_result_data()
	_eq(int(app.model.read().balance),100,"first win credited once")
	_check(app.session.should_first_puzzle(),"cafe stays locked until completion acknowledged")
	app._request_navigation("home")
	_eq(app.current_page,"completion","navigation cannot skip completion")
	app._finish_puzzle()
	_eq(int(app.model.read().balance),100,"duplicate finish has no additional reward")
	await _restart_app()
	app._title_start()
	await _settle()
	_eq(app.current_page,"completion","unacknowledged winning completion resumes")
	_eq(int(app.model.read().balance),100,"resumed win does not credit reward twice")
	_eq(app.completion_reward,100,"resumed completion recovers original reward display")
	var next=app.content.get_child(0).get_node("ContinueButton")
	next.pressed.emit()
	next.pressed.emit()
	await _settle()
	_eq(app.current_page,"home","completion continue opens cafe")
	_check(not app.session.should_first_puzzle(),"acknowledged first win unlocks cafe")
	_eq(app.session.state.phase,"cafe","acknowledgment saved cafe session phase")
	_check(is_instance_valid(app.garden),"native cafe garden loaded")
	await _core_size_matrix("home")
	_assert_first_home_data()
	await _restart_app()
	app._title_start()
	await _settle()
	_eq(app.current_page,"home","returning player starts at unlocked cafe")
	_case("failed home launch re-enables primary puzzle CTA")
	var attempts_before: int=app.model.read().attempts.size()
	app.model.storage.fail_writes=true
	_native_button_tap(app.home_screen.play_button)
	await _settle()
	_eq(app.current_page,"home","failed cafe launch stays on home")
	_eq(app.model.read().attempts.size(),attempts_before,"failed cafe launch creates no new attempt")
	_check(not app.home_screen.play_button.disabled,"failed cafe launch re-enables play CTA")
	app.model.storage.fail_writes=false


func _reward_tests() -> void:
	_case("subsequent puzzle win reward idempotence progress unlock and completion")
	var before: int=app.model.read().balance
	app._start_level(1)
	await _settle()
	var completed_id: String=app.attempt_id
	_mark_win()
	app._finish_puzzle()
	await _settle()
	_eq(int(app.model.read().balance),before+100,"new level first win gives 100 once")
	_eq(int(app.progress.unlocked),3,"second win unlocks third level")
	_eq(int(app.progress.stars[1]),3,"win writes stars")
	_eq(app.current_page,"completion","win completion scene shown")
	app._finish_puzzle()
	_eq(int(app.model.read().balance),before+100,"duplicate UI completion does not double reward")
	_eq(app.attempt_id,completed_id,"duplicate completion keeps same attempt")
	_press("카페로 가기")
	await _settle()
	_eq(app.current_page,"home","result continue opens cafe")
	_check(not is_instance_valid(app.popup_layer),"result route leaves no stale popup")
	app._start_level(1)
	await _settle()
	app.engine.moves=1
	_mark_win()
	app._finish_puzzle()
	_eq(int(app.model.read().balance),before+135,"new repeat win gives 35")
	_eq(int(app.progress.stars[1]),3,"lower stars do not replace personal best")
	_press("카페로 가기")
	await _settle()
	app._start_level(2)
	await _settle()
	_mark_loss()
	app._finish_puzzle()
	_eq(int(app.model.read().balance),before+135,"loss gives no reward")
	app._finish_puzzle()
	_eq(int(app.model.read().balance),before+135,"repeated loss completion remains idempotent")
	_press("카페로 가기")
	await _settle()
	_case("failed reward save is retryable without duplicate reward")
	app._start_level(2)
	await _settle()
	_mark_win()
	app.model.storage.fail_writes=true
	app._finish_puzzle()
	_eq(int(app.model.read().balance),before+135,"failed write does not credit memory-only reward")
	_check(is_instance_valid(app.popup_layer),"save failure exposes modal")
	_check(_buttons(app.popup_layer,"저장 다시 시도").size()==1,"save retry is exposed")
	app._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(is_instance_valid(app.popup_layer),"back cannot dismiss mandatory retry")
	app.model.storage.fail_writes=false
	_press("저장 다시 시도",app.popup_layer)
	_eq(int(app.model.read().balance),before+235,"retry commits one first-clear reward")
	app._finish_puzzle()
	_eq(int(app.model.read().balance),before+235,"repeated retry cannot double reward")
	_press("카페로 가기")
	await _settle()

func _progress_tests() -> void:
	_case("progress schema validation rejects malformed numeric fields")
	var valid={"version":1,"unlocked":3,"stars":[3,2,0,0,0,0,0,0]}
	_check(app._valid_progress(valid),"canonical progress valid")
	for invalid in [null,[],{}, {"version":1,"unlocked":0,"stars":[0,0,0,0,0,0,0,0]}, {"version":1,"unlocked":1.5,"stars":[0,0,0,0,0,0,0,0]}, {"version":1,"unlocked":1,"stars":[0,0,0,0,0,0,0,4]}, {"version":1,"unlocked":1,"stars":[0]}, {"version":1,"unlocked":true,"stars":[0,0,0,0,0,0,0,0]}]:
		_check(not app._valid_progress(invalid),"malformed progress rejected " + str(invalid))
	_case("corrupted progress preserved and rebuilt from cafe clear ledger")
	var path="user://puzzle-progress.json"
	var corrupt="{ broken-ui-test-progress"
	var file=FileAccess.open(path,FileAccess.WRITE)
	_check(file!=null,"isolated progress test writable")
	file.store_string(corrupt)
	file.close()
	app.progress={"version":1,"unlocked":1,"stars":[0,0,0,0,0,0,0,0]}
	app.state=app.model.read()
	app._load_progress()
	_eq(FileAccess.get_file_as_string(path),corrupt,"load does not overwrite corrupted original")
	_eq(int(app.progress.unlocked),4,"cafe level claims reconstruct unlocked frontier")
	_eq(int(app.progress.stars[0]),1,"claimed first level gets conservative star")
	_eq(int(app.progress.stars[1]),1,"claimed second level gets conservative star")
	_check(not app.progress_error.is_empty(),"corruption displayed to player")
	_check(app._save_progress(),"reconstructed progress saved atomically")
	_eq(FileAccess.get_file_as_string(path+".backup"),corrupt,"corrupted original backed up before replacement")
	_check(app._valid_progress(JSON.parse_string(FileAccess.get_file_as_string(path))),"replacement is schema-valid")

func _safe_area_tests() -> void:
	_case("safe-area physical to logical mapping in portrait landscape and invalid reports")
	_eq(SafeArea.insets(Rect2(0,141,1170,2289),Vector2(1170,2532),Vector2(390,844)),Vector4(0,47,0,34),"3x portrait notch and home indicator")
	_eq(SafeArea.insets(Rect2(141,0,2250,1080),Vector2(2532,1170),Vector2(844,390)),Vector4(47,0,47,30),"landscape left right bottom safe areas")
	_eq(SafeArea.insets(Rect2(0,0,768,1024),Vector2(768,1024),Vector2(768,1024)),Vector4.ZERO,"tablet without safe insets")
	_eq(SafeArea.insets(Rect2(),Vector2(360,640),Vector2(360,640)),Vector4.ZERO,"missing platform rect safe fallback")
	_eq(SafeArea.insets(Rect2(10,20,320,600),Vector2.ZERO,Vector2(360,640)),Vector4.ZERO,"invalid physical dimensions safe fallback")
	_eq(SafeArea.insets(Rect2(-10,-20,400,700),Vector2(360,640),Vector2(360,640)),Vector4.ZERO,"oversized platform rect never gives negative insets")
