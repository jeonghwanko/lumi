extends RefCounted
const ATLAS = preload("res://assets/cats/colored-cat-tokens-v4.png")
const FRAMES = [Rect2(78,54,444,435), Rect2(543,52,444,437), Rect2(1011,52,445,436), Rect2(78,509,443,434), Rect2(543,510,443,434), Rect2(1011,508,444,436)]
const COLORS = [Color("ef3343"), Color("f6c91a"), Color("56c845"), Color("278bea"), Color("a655e6"), Color("ff912c")]
const LABELS = ["빨강 고양이", "노랑 고양이", "초록 고양이", "파랑 고양이", "보라 고양이", "주황 고양이"]
static var _textures: Array[AtlasTexture] = []
static func texture(index: int) -> AtlasTexture:
	if _textures.is_empty():
		for frame in FRAMES:
			var item = AtlasTexture.new()
			item.atlas = ATLAS
			item.region = frame
			item.filter_clip = true
			_textures.append(item)
	return _textures[clampi(index, 0, 5)]
