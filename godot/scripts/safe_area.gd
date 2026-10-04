extends RefCounted
## Maps physical display safe insets into the expanded logical canvas.
static func insets(safe_rect: Rect2, window_pixels: Vector2, logical_size: Vector2) -> Vector4:
	if window_pixels.x <= 0 or window_pixels.y <= 0 or safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return Vector4.ZERO
	var sx: float = logical_size.x / window_pixels.x
	var sy: float = logical_size.y / window_pixels.y
	return Vector4(maxf(0, safe_rect.position.x) * sx, maxf(0, safe_rect.position.y) * sy,
		maxf(0, window_pixels.x - safe_rect.end.x) * sx, maxf(0, window_pixels.y - safe_rect.end.y) * sy)
