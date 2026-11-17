extends RefCounted
class_name PocketResidentDialogue

# No stock speech, prefix, suffix, generic agreement, scripted segue or AI text.
# NPC lines come verbatim from the author's topic-specific database.
# UI navigation choices are labels, not speech or a simulated NPC response.
const TopicA = preload("res://scripts/dialogue_topics_a.gd")
const TopicB = preload("res://scripts/dialogue_topics_b.gd")
const TopicC = preload("res://scripts/dialogue_topics_c.gd")
const TopicD = preload("res://scripts/dialogue_topics_d.gd")
const TopicE = preload("res://scripts/dialogue_topics_e.gd")
const DepthA = preload("res://scripts/dialogue_depth_a.gd")
const DepthB = preload("res://scripts/dialogue_depth_b.gd")
const DepthC = preload("res://scripts/dialogue_depth_c.gd")
const DepthD = preload("res://scripts/dialogue_depth_d.gd")
const DepthE = preload("res://scripts/dialogue_depth_e.gd")

const SUBJECT_COUNT := 200
const OPENING_VARIANTS := 10
const CONVERSATION_COUNT := SUBJECT_COUNT * OPENING_VARIANTS

const GIVEN_NAMES := [
	"アオイ", "ユウ", "サクラ", "ハル", "ミオ", "ソラ", "レン", "ナギ",
	"ヒナ", "リク", "カナ", "トワ", "ユキ", "カイ", "マコ", "イツキ",
	"ノア", "ユズ", "アキ", "メイ", "レイ", "シオン", "フウカ", "コウ"
]
const FAMILY_NAMES := [
	"青木", "遠藤", "岸", "宮本", "川島", "小野", "藤原", "新井",
	"大西", "高田", "河野", "森", "石田", "成瀬", "三浦", "片桐"
]

# These names appear in the player-operated navigation menu. They are never
# spoken by an NPC. No dialogue sentence is constructed from them.
const DETAIL_ROUTES := [
	{"next": "mechanism", "text": "仕組み・原理"},
	{"next": "surprise", "text": "意外な事実"},
	{"next": "field_story", "text": "現場ならではの話"},
	{"next": "example", "text": "身近な観察・体験"}
]

static var _catalog: Array[Dictionary] = []


static func catalog() -> Array[Dictionary]:
	if not _catalog.is_empty():
		return _catalog
	var subject_chunks: Array = [TopicA.RAW, TopicB.RAW, TopicC.RAW, TopicD.RAW, TopicE.RAW]
	var depth_chunks: Array = [DepthA.RAW, DepthB.RAW, DepthC.RAW, DepthD.RAW, DepthE.RAW]
	for part in range(subject_chunks.size()):
		var lines: PackedStringArray = String(subject_chunks[part]).strip_edges().split("\n", false)
		var deep_lines: PackedStringArray = String(depth_chunks[part]).strip_edges().split("\n", false)
		if lines.size() != deep_lines.size():
			push_error("Resident dialogue content count mismatch: " + str(part))
			return []
		for row in range(lines.size()):
			var columns: PackedStringArray = lines[row].strip_edges().split("|", false)
			var knowledge: PackedStringArray = deep_lines[row].strip_edges().split("|", false)
			if columns.size() != 6 or knowledge.size() != 5:
				push_error("Resident dialogue malformed at %d:%d" % [part, row])
				return []
			if String(columns[1]) != String(knowledge[0]):
				push_error("Resident dialogue content mixed across topics at %d:%d" % [part, row])
				return []
			_catalog.append({
				"genre": String(columns[0]),
				"title": String(columns[1]),
				"hook": String(columns[2]),
				"detail": String(columns[3]),
				"counter": String(columns[4]),
				"question": String(columns[5]),
				"mechanism": String(knowledge[1]),
				"surprise": String(knowledge[2]),
				"field_story": String(knowledge[3]),
				"example": String(knowledge[4])
			})
	return _catalog


static func is_valid_catalog() -> bool:
	var subjects := catalog()
	if subjects.size() != SUBJECT_COUNT:
		return false
	var titles: Dictionary = {}
	var genres: Dictionary = {}
	for topic in subjects:
		for field in ["genre", "title", "hook", "detail", "counter", "question", "mechanism", "surprise", "field_story", "example"]:
			if String(topic.get(field, "")).strip_edges().is_empty():
				return false
		var title: String = String(topic["title"])
		if titles.has(title):
			return false
		titles[title] = true
		var genre: String = String(topic["genre"])
		genres[genre] = int(genres.get(genre, 0)) + 1
	if genres.size() != 25:
		return false
	for genre in genres:
		if int(genres[genre]) != 8:
			return false
	return true


static func make_profile(resident_id: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 39017 + resident_id * 7919
	var given: String = GIVEN_NAMES[posmod(resident_id * 7 + 3, GIVEN_NAMES.size())]
	var family: String = FAMILY_NAMES[posmod(resident_id * 11 + 5, FAMILY_NAMES.size())]
	return {
		"id": resident_id,
		"name": "%s %s" % [family, given],
		"seed": int(rng.randi()),
		"favorite": rng.randi_range(0, 24)
	}


static func scenario_id(profile: Dictionary, talks: int = 0) -> int:
	# Visit every one of the 2,000 topic/opening pairs before repetition.
	var seed: int = int(profile.get("seed", 1))
	var step: int = 37 + posmod(seed, 191) * 2
	if step % 5 == 0:
		step += 2
	var offset: int = posmod(seed + int(profile.get("favorite", 0)) * 80, CONVERSATION_COUNT)
	return posmod(offset + posmod(maxi(talks, 0), CONVERSATION_COUNT) * step, CONVERSATION_COUNT)


static func opening_fields(variant: int) -> Array[String]:
	# Every opening is assembled ONLY from this subject's authored passages.
	# No reused transition phrase is ever attached between paragraphs.
	match posmod(variant, OPENING_VARIANTS):
		0: return ["hook"]
		1: return ["hook", "detail"]
		2: return ["hook", "counter"]
		3: return ["hook", "mechanism"]
		4: return ["hook", "surprise"]
		5: return ["hook", "field_story"]
		6: return ["hook", "example"]
		7: return ["hook", "detail", "counter"]
		8: return ["hook", "surprise", "example"]
		_: return ["hook", "mechanism", "field_story"]


static func make_tree(profile: Dictionary, talks: int = 0, _affinity: int = 0, _continuing: bool = false) -> Dictionary:
	var subjects := catalog()
	if subjects.size() != SUBJECT_COUNT:
		return {}
	var scenario: int = scenario_id(profile, talks)
	var topic_index: int = scenario / OPENING_VARIANTS
	var variant: int = posmod(scenario, OPENING_VARIANTS)
	var topic: Dictionary = subjects[topic_index]
	var opening: Array[String] = opening_fields(variant)
	var paragraphs: PackedStringArray = []
	var already_uttered: Dictionary = {}
	for field in opening:
		paragraphs.append(String(topic[field]))
		if field in ["mechanism", "surprise", "field_story", "example"]:
			already_uttered[field] = true
	var nodes: Dictionary = {
		"start": {"text": "\n".join(paragraphs), "choices": DETAIL_ROUTES.duplicate(true)}
	}
	for route in DETAIL_ROUTES:
		var key: String = String(route["next"])
		nodes[key] = {
			"text": String(topic[key]),
			"choices": DETAIL_ROUTES.duplicate(true)
		}
	return {
		"start": "start",
		"scenario_id": scenario,
		"topic": String(topic["title"]),
		"genre": String(topic["genre"]),
		"opening_fields": opening,
		"already_uttered": already_uttered,
		"nodes": nodes
	}


static func is_valid_tree(tree: Dictionary) -> bool:
	# Content policy enforced in the validator: every spoken character must
	# originate in a topic-specific authored paragraph. No templated fillers.
	var scenario: int = int(tree.get("scenario_id", -1))
	if scenario < 0 or scenario >= CONVERSATION_COUNT:
		return false
	var topic: Dictionary = catalog()[scenario / OPENING_VARIANTS]
	var fields: Array = tree.get("opening_fields", [])
	var expected_opening: PackedStringArray = []
	for field in fields:
		if not topic.has(String(field)):
			return false
		expected_opening.append(String(topic[field]))
	var nodes: Dictionary = tree.get("nodes", {})
	if nodes.size() != 5 or String(tree.get("start", "")) != "start":
		return false
	if not nodes.has("start") or String(nodes["start"].get("text", "")) != "\n".join(expected_opening):
		return false
	for key in ["mechanism", "surprise", "field_story", "example"]:
		if not nodes.has(key) or String(nodes[key].get("text", "")) != String(topic[key]):
			return false
	for node_key in nodes:
		var node: Dictionary = nodes[node_key]
		var choices: Array = node.get("choices", [])
		if choices.size() != DETAIL_ROUTES.size():
			return false
		for choice_index in range(DETAIL_ROUTES.size()):
			var choice: Dictionary = choices[choice_index]
			var route: Dictionary = DETAIL_ROUTES[choice_index]
			if String(choice.get("next", "")) != String(route["next"]):
				return false
			if String(choice.get("text", "")) != String(route["text"]):
				return false
	return true
