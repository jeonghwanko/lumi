extends Control
var board_view: Control
func _draw() -> void:
	if board_view == null or board_view.cells.size()!=8: return
	var unit: float=minf(size.x,size.y)/8.0
	for r in 8:
		for c in 8:
			var data=board_view.cells[r][c]
			if data==null or bool(data.get("crate",false)): continue
			var rect=Rect2(Vector2(c,r)*unit+Vector2.ONE*4,Vector2.ONE*(unit-8))
			if int(data.get("ice",0))>0:
				draw_rect(rect,Color(0.5,0.87,1,0.48),true)
				draw_rect(rect,Color("ddfaff"),false,2)
			var sp=int(data.get("special",0))
			var center=rect.get_center()
			if sp==1 or sp==2:
				var d=Vector2(unit*0.31,0) if sp==1 else Vector2(0,unit*0.31)
				draw_line(center-d,center+d,Color("59382d"),7,true)
				draw_line(center-d,center+d,Color("fff8df"),3,true)
			elif sp==3:
				draw_circle(center,unit*0.2,Color("fff8df"),false,4,true)
				draw_circle(center,unit*0.11,Color("59382d"),true,-1,true)
			elif sp==4:
				for k in 6:
					var angle=float(k)/6.0*TAU
					draw_circle(center+Vector2.from_angle(angle)*unit*0.19,unit*0.065,preload("res://scripts/cat_texture.gd").COLORS[k],true,-1,true)
