class_name CafeModel
extends RefCounted
## Native port of cafe-model.js. State/catalog field names preserve the original
## schema; callable API uses snake_case. Every successful change is validated and
## committed atomically before it is exposed. On error read() returns {} and sets
## last_error; commands return {ok:false, reason, message} without spending.

const SaveStore = preload("res://scripts/save_store.gd")
const KEY = "cats-and-coffee-v2"
const OLD = "cats-and-coffee-cafe-v1"
const MAX_SAFE_INTEGER = 9007199254740991
const MAX_SAVE_BYTES = 16 * 1024 * 1024
const GIFTS = {"f05":"d-coaster", "f13":"d-books", "f07":"d-cups", "f26":"d-plant", "f22":"d-cushion", "f31":"d-garden-lamp"}
var key = KEY
var catalog: Dictionary = {}
var storage: RefCounted
var last_error = ""
var _facilities: Dictionary = {}
var _decorations: Dictionary = {}
var _memory_id_pattern = RegEx.new()

func _init(store: Variant = null, catalog_override: Variant = null) -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json")) if catalog_override == null else catalog_override.duplicate(true)
	storage = SaveStore.new() if store == null else (SaveStore.MemoryStore.new(store) if store is Dictionary else store)
	for facility in catalog.get("facilities", []): _facilities[facility.id] = facility
	for decoration in catalog.get("decorations", []): _decorations[decoration.id] = decoration
	_memory_id_pattern.compile("^[A-Za-z0-9:-]{1,128}$")

func by_id(id: Variant) -> Dictionary:
	return _facilities.get(id, {})

func decor_by_id(id: Variant) -> Dictionary:
	return _decorations.get(id, {})

func fresh() -> Dictionary:
	return {"version":2, "revision":0, "balance":0, "openingBalance":0, "chapter":1, "project":"f05", "companion":"cat19", "owned":{"f19":{"level":1,"position":{"x":48,"y":19}}}, "claimedLevels":[], "attempts":{}, "ledger":[], "settings":{"reduceMotion":false,"lighting":"day","sound":true,"effects":"full"}, "memories":[], "order":null, "orderBook":{}, "visits":{}, "companionRecords":{}, "decorOwned":{}, "surfaces":{"floor":null,"path":null}, "migration":null}

func _fail(reason: String, message: String) -> Dictionary:
	return {"ok":false, "reason":reason, "message":message}

func _int(value: Variant, minimum: float = -MAX_SAFE_INTEGER, maximum: float = MAX_SAFE_INTEGER) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) and value >= minimum and value <= maximum

func valid_position(position: Variant) -> bool:
	return position is Dictionary and (position.get("x") is int or position.get("x") is float) and (position.get("y") is int or position.get("y") is float) and is_finite(float(position.x)) and is_finite(float(position.y)) and position.x >= 8 and position.x <= 92 and position.y >= 12 and position.y <= 87

func collides(a: Dictionary, b: Dictionary) -> bool:
	return dec_collides(a, b, 12)

func dec_collides(a: Dictionary, b: Dictionary, radius: float) -> bool:
	return Vector2((float(a.x) - float(b.x)) / 1.3, float(a.y) - float(b.y)).length() < radius

func _owned_cat(state: Dictionary, id: Variant) -> bool:
	for facility_id in state.owned:
		if by_id(facility_id).get("catId") == id: return true
	return false

func _facility_for_cat(state: Dictionary, id: Variant) -> String:
	for facility_id in state.owned:
		if by_id(facility_id).get("catId") == id: return facility_id
	return ""

func _has_memory(state: Dictionary, id: String) -> bool:
	for memory in state.memories:
		if memory.id == id: return true
	return false

func normalize(state: Variant) -> Variant:
	if not state is Dictionary or state.get("version") != 2: return state
	if state.get("settings") is Dictionary:
		if state.settings.get("sound") == null: state.settings.sound = true
		if state.settings.get("effects") == null: state.settings.effects = "full"
	for field in ["decorOwned", "orderBook", "visits", "companionRecords"]:
		if state.get(field) == null: state[field] = {}
	if state.get("surfaces") == null: state.surfaces = {"floor":null, "path":null}
	if state.get("order") is Dictionary:
		if state.order.get("served") == null: state.order.served = false
		if state.order.has("facility") and state.orderBook is Dictionary and not state.orderBook.has(state.order.facility):
			state.orderBook[state.order.facility] = {"completed":state.order.get("completed"), "served":state.order.served}
	return state

func _validation_error(s: Variant) -> String:
	if not s is Dictionary: return "저장 형식이 맞지 않아요. 원본을 보존했습니다."
	if s.get("version") != 2 or not _int(s.get("revision"), 0) or not _int(s.get("balance"), 0) or not _int(s.get("openingBalance"), 0) or not _int(s.get("chapter"), 1, 6): return "저장 형식이 맞지 않아요. 원본을 보존했습니다."
	for field in ["ledger", "claimedLevels", "memories"]:
		if not s.get(field) is Array: return "저장 형식이 맞지 않아요. 원본을 보존했습니다."
	for field in ["owned", "attempts", "settings", "decorOwned", "surfaces", "orderBook", "visits", "companionRecords"]:
		if not s.get(field) is Dictionary: return "꾸미기/주문 저장 오류"
	if not s.has("project") or (s.project != null and not _facilities.has(s.project)): return "프로젝트 저장 오류"
	if not s.settings.get("reduceMotion") is bool: return "동작 설정 오류"
	if not s.settings.get("sound") is bool or not s.settings.get("effects") in ["full", "low", "off"]: return "소리/효과 설정 오류"
	if not s.settings.get("lighting") in ["day", "sunset", "night"]: return "조명 저장 오류"
	if not s.has("order"): return "주문 저장 오류"
	if s.order != null:
		if not s.order is Dictionary or not s.owned.has(s.order.get("facility")) or not _int(s.order.get("completed"), 0, 2) or not s.order.get("served") is bool: return "주문 저장 오류"
	var cleared = {}
	for level in s.claimedLevels:
		if not _int(level, 1, 8) or cleared.has(level): return "클리어 기록 저장 오류"
		cleared[level] = true
	var total = s.openingBalance
	var tx_ids = {}
	for tx in s.ledger:
		if not tx is Dictionary or not tx.get("id") is String or tx_ids.has(tx.id) or not _int(tx.get("amount")) or not tx.get("kind") in ["reward", "purchase", "upgrade", "decoration"]: return "거래 기록 저장 오류"
		tx_ids[tx.id] = true
		total += tx.amount
		if not _int(total): return "거래 기록 범위 오류"
	if total != s.balance: return "잔액과 거래 기록이 맞지 않아요. 원본을 보존했습니다."
	var positions = []
	for id in s.owned:
		var item = s.owned[id]
		if not _facilities.has(id) or not item is Dictionary or not _int(item.get("level"), 1, 3): return "시설 저장 오류"
		if item.has("actionStage") and not _int(item.actionStage, 1, item.level): return "행동 선택 오류"
		if not item.has("position"): return "배치 저장 오류"
		if item.position != null:
			if not valid_position(item.position): return "배치 저장 오류"
			for position in positions:
				if collides(position, item.position): return "시설이 겹쳐 있어요. 저장을 보존했습니다."
			positions.append(item.position)
	if not _owned_cat(s, s.get("companion")): return "동행 고양이 저장 오류"
	for id in s.decorOwned:
		var item = s.decorOwned[id]
		var decoration = decor_by_id(id)
		if decoration.is_empty() or not item is Dictionary or not item.has("position"): return "꾸미기 위치 오류"
		if decoration.kind in ["floor", "path"] and item.position != null: return "꾸미기 위치 오류"
		if item.position != null and not valid_position(item.position): return "꾸미기 위치 오류"
	for kind in ["floor", "path"]:
		if not s.surfaces.has(kind): return "바닥/길 선택 오류"
		var id = s.surfaces[kind]
		if id != null and (not s.decorOwned.has(id) or decor_by_id(id).get("kind") != kind): return "바닥/길 선택 오류"
	for id in s.orderBook:
		var order = s.orderBook[id]
		if not s.owned.has(id) or not order is Dictionary or not _int(order.get("completed"), 0, 2) or not order.get("served") is bool: return "주문 진행 오류"
	for id in s.companionRecords:
		var record = s.companionRecords[id]
		if not _owned_cat(s, id) or not record is Dictionary or not _int(record.get("runs"), 0) or not _int(record.get("wins"), 0) or record.runs < record.wins or not _int(record.get("lastLevel"), 1, 8): return "동행 기록 오류"
	for id in s.visits:
		if not s.owned.has(id) or not _int(s.visits[id], 0): return "방문 기록 오류"
	for id in s.attempts:
		var attempt = s.attempts[id]
		if not id is String or id.is_empty() or not attempt is Dictionary or not _int(attempt.get("level"), 1, 8) or not attempt.get("status") in ["active", "won", "lost", "abandoned"]: return "퍼즐 기록 저장 오류"
		if attempt.has("companion") and not _owned_cat(s, attempt.companion): return "퍼즐 동행 저장 오류"
	for memory in s.memories:
		if not memory is Dictionary or not memory.get("id") is String or _memory_id_pattern.search(memory.id) == null or not memory.get("kind") in ["arrival", "growth", "story", "visit", "photo", "companion"]: return "추억 저장 오류"
		if memory.kind != "photo":
			if not s.owned.has(memory.get("facility")): return "추억 시설 오류"
			continue
		if not memory.get("layout") is Dictionary or not memory.get("decor", {}) is Dictionary or not memory.get("lighting") in ["day", "sunset", "night"]: return "정원 기억 오류"
		for id in memory.layout:
			var item = memory.layout[id]
			if not _facilities.has(id) or not item is Dictionary or not _int(item.get("level"), 1, 3) or not item.has("position"): return "정원 기억 배치 오류"
			if item.has("actionStage") and not _int(item.actionStage, 1, item.level): return "정원 기억 배치 오류"
			if item.position != null and not valid_position(item.position): return "정원 기억 배치 오류"
		for id in memory.get("decor", {}):
			var item = memory.decor[id]
			if not _decorations.has(id) or not item is Dictionary or not item.has("position") or (item.position != null and not valid_position(item.position)): return "소품 기억 오류"
		if not memory.get("surfaces", {}) is Dictionary: return "기억 바닥/길 오류"
		for kind in ["floor", "path"]:
			var id = memory.get("surfaces", {}).get(kind)
			if id != null and (not memory.get("decor", {}).has(id) or decor_by_id(id).get("kind") != kind): return "기억 바닥/길 오류"
	var decoration_positions = []
	for item in s.decorOwned.values():
		if item.position == null: continue
		for position in positions:
			if dec_collides(position, item.position, 8): return "소품과 시설 위치가 겹쳐요"
		for position in decoration_positions:
			if dec_collides(position, item.position, 4): return "소품 위치가 겹쳐요"
		decoration_positions.append(item.position)
	return ""

func validate(state: Variant) -> Dictionary:
	last_error = _validation_error(state)
	return state if last_error.is_empty() else {}

func _parse(raw: String) -> Variant:
	if raw.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		last_error = "저장 파일이 너무 커요. 원본을 보존했습니다."
		return null
	var parser = JSON.new()
	if parser.parse(raw) != OK:
		last_error = "저장 파일을 읽을 수 없어요. 원본을 보존했습니다."
		return null
	return parser.data

func _migrate_v1(old: Variant) -> Dictionary:
	if not old is Dictionary or old.get("version") != 1 or not _int(old.get("balance"), 0) or not old.get("owned") is Array or not old.get("claimed") is Array or not old.get("slots") is Array:
		last_error = "이전 저장을 읽을 수 없어요. 원본을 보존했습니다."
		return {}
	var state = fresh()
	var mapping = {"drip":"f05", "moka":"f06", "latte":"f07"}
	for id in old.owned:
		if not mapping.has(id):
			last_error = "이전 시설 저장 오류"
			return {}
		var new_id = mapping[id]
		var index = old.slots.find(id)
		state.owned[new_id] = {"level":1,"position":null if index < 0 else {"x":20 + (index % 3) * 29,"y":48 + int(index / 3) * 25}}
		state.chapter = maxi(int(state.chapter), int(by_id(new_id).chapter))
	state.balance = old.balance
	state.openingBalance = old.balance
	state.claimedLevels = old.claimed.duplicate()
	state.migration = "v1"
	return validate(state)

func read() -> Dictionary:
	last_error = ""
	var raw = storage.get_item(KEY)
	if not storage.last_error.is_empty():
		last_error = storage.last_error
		return {}
	if raw != null:
		var parsed = _parse(raw)
		if parsed == null: return {}
		return validate(normalize(parsed))
	var old_raw = storage.get_item(OLD)
	if not storage.last_error.is_empty():
		last_error = storage.last_error
		return {}
	if old_raw != null:
		var old = _parse(old_raw)
		if old == null: return {}
		return _migrate_v1(old)
	return fresh()

func _commit(state: Dictionary, previous: Variant, before_restore: Variant = null) -> bool:
	if not storage.commit(JSON.stringify(state, "", true, true), previous, before_restore):
		last_error = storage.last_error
		if last_error.is_empty(): last_error = "저장 실패. 이전 저장을 보존했습니다."
		return false
	return true

func _transact(change: Callable) -> Dictionary:
	var original = read()
	if original.is_empty(): return _fail("invalid_save", last_error)
	var state = original.duplicate(true)
	var result: Dictionary = change.call(state)
	if result.get("ok", false) and result.get("changed", false):
		state.revision += 1
		if validate(state).is_empty(): return _fail("invalid_save", last_error)
		var previous = storage.get_item(KEY)
		if not storage.last_error.is_empty(): return _fail("storage", storage.last_error)
		if not _commit(state, previous):
			var error = _fail("storage", last_error)
			error.state = original
			return error
	result.state = state if result.get("ok", false) else original
	return result

func _add_tx(state: Dictionary, transaction: Dictionary) -> void:
	state.balance += transaction.amount
	state.ledger.append(transaction)

func _unlock(state: Dictionary) -> void:
	while state.chapter < 6 and state.owned.has(catalog.chapters[int(state.chapter) - 1].representative):
		state.chapter += 1

func begin_attempt(level: Variant, id: Variant) -> Dictionary:
	if not _int(level, 1, 8) or not id is String or id.length() < 8: return _fail("attempt", "퍼즐 기록을 시작할 수 없어요.")
	return _transact(func(s):
		if s.attempts.has(id): return _fail("duplicate", "이미 시작한 퍼즐이에요.")
		s.attempts[id] = {"level":level,"status":"active","companion":s.companion}
		return {"ok":true,"changed":true,"id":id})

func finish_attempt(id: String, won: bool) -> Dictionary:
	return _transact(func(s):
		if not s.attempts.has(id): return _fail("attempt", "퍼즐 기록이 없어요.")
		var attempt = s.attempts[id]
		if attempt.status != "active": return {"ok":true,"changed":false,"reason":"already_finished","amount":0}
		attempt.status = "won" if won else "lost"
		var companion = attempt.get("companion", s.companion)
		var record = s.companionRecords.get(companion, {"runs":0,"wins":0,"lastLevel":attempt.level})
		record.runs += 1
		record.lastLevel = attempt.level
		if won: record.wins += 1
		s.companionRecords[companion] = record
		if won and not _has_memory(s, "companion:" + companion): s.memories.append({"id":"companion:" + companion,"kind":"companion","facility":_facility_for_cat(s, companion)})
		var amount = 0
		if won:
			amount = catalog.rewardRepeat if attempt.level in s.claimedLevels else catalog.rewardFirst
			if not attempt.level in s.claimedLevels: s.claimedLevels.append(attempt.level)
			_add_tx(s, {"id":"reward:" + id,"kind":"reward","amount":amount,"level":attempt.level})
			if s.order != null and s.order.completed < 2:
				s.order.completed += 1
				s.orderBook[s.order.facility] = {"completed":s.order.completed,"served":false}
				if s.order.completed == 2: s.memories.append({"id":"story:" + s.order.facility,"kind":"story","facility":s.order.facility})
		return {"ok":true,"changed":true,"amount":amount})

func abandon(id: String) -> Dictionary:
	return _transact(func(s):
		if not s.attempts.has(id) or s.attempts[id].status != "active": return {"ok":true,"changed":false}
		s.attempts[id].status = "abandoned"
		return {"ok":true,"changed":true})

func purchase(id: String) -> Dictionary:
	return _transact(func(s):
		var facility = by_id(id)
		if facility.is_empty(): return _fail("facility", "시설을 찾을 수 없어요.")
		if s.owned.has(id): return {"ok":true,"changed":false,"reason":"owned"}
		if facility.chapter > s.chapter: return _fail("locked", "앞 장의 대표 프로젝트를 먼저 완성해 주세요.")
		if s.balance < facility.price: return _fail("insufficient", "커피 방울이 부족해요. 익숙한 퍼즐도 다시 플레이할 수 있어요.")
		_add_tx(s, {"id":"buy:" + id,"kind":"purchase","amount":-facility.price,"facility":id})
		s.owned[id] = {"level":1,"position":null}
		s.memories.append({"id":"arrival:" + id,"kind":"arrival","facility":id})
		_unlock(s)
		var gift = GIFTS.get(id)
		var gift_added = null
		if gift != null and not s.decorOwned.has(gift):
			s.decorOwned[gift] = {"position":null}
			gift_added = gift
		return {"ok":true,"changed":true,"gift":gift_added})

func upgrade(id: String) -> Dictionary:
	return _transact(func(s):
		var facility = by_id(id)
		if facility.is_empty() or not s.owned.has(id): return _fail("owned", "먼저 시설을 열어주세요.")
		var owned = s.owned[id]
		if owned.level == 3: return {"ok":true,"changed":false,"reason":"max"}
		var cost = facility.upgrades[int(owned.level) - 1]
		if s.balance < cost: return _fail("insufficient", "커피 방울이 부족해요.")
		_add_tx(s, {"id":"upgrade:" + id + ":" + str(int(owned.level) + 1),"kind":"upgrade","amount":-cost,"facility":id})
		owned.level += 1
		s.memories.append({"id":"growth:" + id + ":" + str(int(owned.level)),"kind":"growth","facility":id})
		return {"ok":true,"changed":true})

func set_project(id: Variant) -> Dictionary:
	return _transact(func(s):
		if id != null and not _facilities.has(id): return _fail("facility", "알 수 없는 목표예요.")
		s.project = id
		return {"ok":true,"changed":true})

func set_companion(id: String) -> Dictionary:
	return _transact(func(s):
		if not _owned_cat(s, id): return _fail("owned", "입주한 고양이를 골라주세요.")
		s.companion = id
		return {"ok":true,"changed":true})

func save_layout(layout: Variant, expected_revision: int, decor_layout: Variant = null) -> Dictionary:
	return _transact(func(s):
		if s.revision != expected_revision: return _fail("conflict", "다른 저장이 변경됐어요. 편집을 다시 열어주세요.")
		if not layout is Dictionary or layout.size() != s.owned.size(): return _fail("layout", "배치 목록이 맞지 않아요.")
		var placed = []
		for id in layout:
			if not s.owned.has(id): return _fail("layout", "배치 목록이 맞지 않아요.")
			var position = layout[id]
			if position == null: continue
			if not valid_position(position): return _fail("bounds", "시설을 정원 안쪽에 놓아주세요.")
			for other in placed:
				if collides(other, position): return _fail("overlap", "시설 사이에 조금 더 여백을 주세요.")
			placed.append(position)
		var decorations = decor_layout
		if decorations == null:
			decorations = {}
			for id in s.decorOwned: decorations[id] = s.decorOwned[id].position
		if not decorations is Dictionary or decorations.size() != s.decorOwned.size(): return _fail("layout", "소품 목록이 변경되었어요.")
		var decor_placed = []
		for id in decorations:
			if not s.decorOwned.has(id): return _fail("layout", "소품 목록이 변경되었어요.")
			var position = decorations[id]
			if position == null: continue
			if decor_by_id(id).kind in ["floor", "path"]: return _fail("surface", "바닥과 길은 선택 버튼으로 적용해주세요.")
			if not valid_position(position): return _fail("bounds", "소품을 정원 안에 놓아주세요.")
			for other in placed:
				if dec_collides(other, position, 8): return _fail("overlap", "소품 사이에 공간을 남겨주세요.")
			for other in decor_placed:
				if dec_collides(other, position, 4): return _fail("overlap", "소품 사이에 공간을 남겨주세요.")
			decor_placed.append(position)
		for id in layout: s.owned[id].position = null if layout[id] == null else layout[id].duplicate(true)
		for id in decorations: s.decorOwned[id].position = null if decorations[id] == null else decorations[id].duplicate(true)
		return {"ok":true,"changed":true})

func setting(value: bool) -> Dictionary:
	return _transact(func(s):
		s.settings.reduceMotion = value
		return {"ok":true,"changed":true})

func sound(value: bool) -> Dictionary:
	return _transact(func(s):
		s.settings.sound = value
		return {"ok":true,"changed":true})

func effects(value: String) -> Dictionary:
	return _transact(func(s):
		if not value in ["full", "low", "off"]: return _fail("effects", "알 수 없는 효과 설정이에요.")
		s.settings.effects = value
		return {"ok":true,"changed":true})

func lighting(value: String) -> Dictionary:
	return _transact(func(s):
		if not value in ["day", "sunset", "night"]: return _fail("lighting", "알 수 없는 조명이에요.")
		s.settings.lighting = value
		return {"ok":true,"changed":true})

func begin_order(id: String) -> Dictionary:
	return _transact(func(s):
		if not s.owned.has(id): return _fail("owned", "소유한 시설을 선택해주세요.")
		if s.order != null and s.order.facility == id: return {"ok":true,"changed":false,"reason":"complete" if s.order.completed == 2 else "active"}
		var progress = s.orderBook.get(id, {"completed":2 if _has_memory(s, "story:" + id) else 0,"served":false})
		s.order = {"facility":id,"completed":progress.completed,"served":progress.served}
		s.orderBook[id] = progress.duplicate(true)
		return {"ok":true,"changed":true,"reason":"complete" if progress.completed == 2 else "active"})

func serve_order() -> Dictionary:
	return _transact(func(s):
		var order = s.order
		if order == null or order.completed < 2: return _fail("not_ready", "퍼즐 두 판을 마쳐 주문을 준비해주세요.")
		if order.served: return {"ok":true,"changed":false,"reason":"served"}
		if s.owned[order.facility].position == null: return _fail("stored", "시설을 정원에 배치하면 손님을 맞이할 수 있어요.")
		order.served = true
		s.orderBook[order.facility] = {"completed":2,"served":true}
		s.visits[order.facility] = s.visits.get(order.facility, 0) + 1
		s.memories.append({"id":"visit:" + order.facility + ":" + str(int(s.visits[order.facility])),"kind":"visit","facility":order.facility})
		return {"ok":true,"changed":true})

func purchase_decoration(id: String) -> Dictionary:
	return _transact(func(s):
		var decoration = decor_by_id(id)
		if decoration.is_empty(): return _fail("decoration", "알 수 없는 소품이에요.")
		if s.decorOwned.has(id): return {"ok":true,"changed":false,"reason":"owned"}
		if s.balance < decoration.price: return _fail("insufficient", "커피 방울이 부족해요.")
		_add_tx(s, {"id":"decor:" + id,"kind":"decoration","amount":-decoration.price,"decoration":id})
		s.decorOwned[id] = {"position":null}
		return {"ok":true,"changed":true})

func equip_surface(id: String) -> Dictionary:
	return _transact(func(s):
		var decoration = decor_by_id(id)
		if decoration.is_empty() or not s.decorOwned.has(id) or not decoration.kind in ["floor", "path"]: return _fail("decoration", "구매한 바닥 또는 길을 선택해주세요.")
		s.surfaces[decoration.kind] = id
		return {"ok":true,"changed":true})

func behavior(id: String, stage: Variant) -> Dictionary:
	return _transact(func(s):
		if not s.owned.has(id) or not _int(stage, 1, s.owned[id].level): return _fail("stage", "해금된 행동을 선택해주세요.")
		s.owned[id].actionStage = stage
		return {"ok":true,"changed":true})

func restore_save(raw: String) -> Dictionary:
	last_error = ""
	var parsed = _parse(raw)
	if parsed == null: return _fail("invalid_save", "복원할 저장을 확인할 수 없어요. 현재 자료를 보존했습니다.")
	var restored = _migrate_v1(parsed) if parsed is Dictionary and parsed.get("version") == 1 else validate(normalize(parsed))
	if restored.is_empty(): return _fail("invalid_save", "복원할 저장을 확인할 수 없어요. 현재 자료를 보존했습니다.")
	var current = storage.get_item(KEY)
	if not storage.last_error.is_empty(): return _fail("storage", storage.last_error)
	# A corrupt current file is preserved separately but never replaces a valid
	# recovery backup. An import is validated completely before any writes.
	var backup = null
	if current != null:
		var old = _parse(current)
		if old != null and _validation_error(normalize(old)).is_empty(): backup = current
	last_error = ""
	if not _commit(restored, backup, current): return _fail("storage", last_error)
	return {"ok":true,"changed":true,"state":restored}

func restore_backup() -> Dictionary:
	var raw = storage.get_item(KEY + ":backup")
	if not storage.last_error.is_empty(): return _fail("storage", storage.last_error)
	return _fail("no_backup", "복원할 이전 저장이 없어요.") if raw == null else restore_save(raw)

func export_save() -> String:
	var state = read()
	return "" if state.is_empty() else JSON.stringify(state, "\t", true, true)

func remember(id: Variant) -> Dictionary:
	if not id is String or id.length() < 8 or _memory_id_pattern.search(id) == null: return _fail("id", "장면 기록 이름이 필요해요.")
	return _transact(func(s):
		if _has_memory(s, id): return {"ok":true,"changed":false}
		s.memories.append({"id":id,"kind":"photo","decor":s.decorOwned.duplicate(true),"surfaces":s.surfaces.duplicate(true),"layout":s.owned.duplicate(true),"lighting":s.settings.lighting})
		return {"ok":true,"changed":true})
