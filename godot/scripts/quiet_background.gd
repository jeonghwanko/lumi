extends Control
## Native low-contrast leaf framing for the puzzle; no mockup bitmap is used.
func _ready() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("dfefda"))
	for side in [-1,1]:
		for i in 12:
			var x=(10 if side<0 else size.x-10)+sin(i*1.77)*22
			var y=float(i)/11*size.y
			var color=Color("a9c49b") if i%3==0 else Color("c2d5a4")
			color.a=0.50
			var points=PackedVector2Array()
			var center=Vector2(x,y)
			for j in 18:
				var angle=float(j)/18*TAU
				points.append(center+Vector2(cos(angle)*34,sin(angle)*14).rotated(side*0.65+i*0.19))
			draw_colored_polygon(points,color)
			if i%3==0:
				for petal in 5:
					var point=center+Vector2.from_angle(float(petal)/5*TAU)*8
					draw_circle(point,6,Color(1,0.99,0.89,0.7),true,-1,true)
				draw_circle(center,4,Color("eed37c"),true,-1,true)
