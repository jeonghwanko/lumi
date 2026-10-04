extends SceneTree
const Board=preload("res://scripts/board_view.gd")
const Puzzle=preload("res://scripts/puzzle_engine.gd")
var checks=0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		push_error(message)
		quit(1)
func _initialize() -> void:
	ProjectSettings.set_setting("lumi/review_mode",false)
	call_deferred("run")
func run() -> void:
	var board=Board.new();board.size=Vector2(320,320);root.add_child(board)
	await process_frame
	var engine=Puzzle.new();engine.initialize(0,2);board.set_board(engine.board)
	await create_timer(0.12).timeout
	var first=board.tiles[0];var second=board.tiles[1]
	var original=first.position;var other=second.position
	board.animate_reject(Vector2i(0,0),Vector2i(1,0),0.2)
	await create_timer(0.05).timeout
	check(first.position!=original,"Rejected swap visibly begins")
	board.pause_presentation(true)
	var paused=first.position
	await create_timer(0.12).timeout
	check(first.position==paused,"Paused presentation has no transform drift")
	board.pause_presentation(false)
	await create_timer(0.25).timeout
	check(first.position.is_equal_approx(original) and second.position.is_equal_approx(other),"Rejected swap returns exactly")
	var children=board.get_child_count()
	for i in 20:
		board.animate_clear({"cells":[Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)],"combo":2},0.12)
		check(board.transient_nodes.size()==16,"Match particles and cascade label are bounded")
		board.set_board(engine.board)
		await process_frame
		check(board.transient_nodes.is_empty() and board.get_child_count()==children,"Canceled effects leave no accumulated nodes")
	board.configure_motion(false,"off");board.selected=Vector2i(0,0);board.selection_feedback()
	check(board.selection_tween==null or not board.selection_tween.is_running(),"Effects off produces no selection motion")
	board.configure_motion(true,"full");board.selection_feedback()
	check(board.selection_tween==null or not board.selection_tween.is_running(),"Reduced motion suppresses selection lift")
	board.queue_free();await process_frame
	print("FEEDBACK: ",checks," checks, 0 failures; rollback, pause, cleanup, effects off")
	quit(0)
