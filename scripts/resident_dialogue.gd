extends RefCounted
class_name PocketResidentDialogue

# 200 hand-authored conversation subjects x 10 contextual approaches = 2,000 scenarios.
# A conversation is a directed acyclic graph. Every response refers to its own
# subject and all choices resolve to an existing node in the same graph.
const TopicA = preload("res://scripts/dialogue_topics_a.gd")
const TopicB = preload("res://scripts/dialogue_topics_b.gd")
const TopicC = preload("res://scripts/dialogue_topics_c.gd")
const TopicD = preload("res://scripts/dialogue_topics_d.gd")
const TopicE = preload("res://scripts/dialogue_topics_e.gd")

const SUBJECT_COUNT := 200
const APPROACH_COUNT := 10
const CONVERSATION_COUNT := SUBJECT_COUNT * APPROACH_COUNT

const GIVEN_NAMES := [
	"アオイ", "ユウ", "サクラ", "ハル", "ミオ", "ソラ", "レン", "ナギ",
	"ヒナ", "リク", "カナ", "トワ", "ユキ", "カイ", "マコ", "イツキ",
	"ノア", "ユズ", "アキ", "メイ", "レイ", "シオン", "フウカ", "コウ"
]
const FAMILY_NAMES := [
	"青木", "遠藤", "岸", "宮本", "川島", "小野", "藤原", "新井",
	"大西", "高田", "河野", "森", "石田", "成瀬", "三浦", "片桐"
]
const GREETINGS := [
	"こんにちは。", "あ、どうも。", "いいところで会いましたね。", "お話ししませんか？"
]

# Each approach changes the framing, reaction and eventual ending, rather than
# changing only punctuation or shuffling an otherwise identical opening line.
const APPROACHES := [
	{
		"id": "最近の関心",
		"opening": "このところ、%sのことをよく考えるんです。",
		"agree": "気持ちが伝わってうれしいです。",
		"detail": "話すと少し考えが整理できますね。",
		"doubt": "違う見方を聞けるのも楽しいです。",
		"personal": "私はこういう発見を大切にしたいです。",
		"ending": "また気になることがあったら話しましょう。"
	},
	{
		"id": "ふと思い出した話",
		"opening": "今日、ふと%sのことを思い出したんです。",
		"agree": "共感してもらえるとは思いませんでした。",
		"detail": "思い出してみると、細かい部分が印象に残っています。",
		"doubt": "思い出は人によって違って当然ですね。",
		"personal": "こういう話は、思い出すたびに少し変わります。",
		"ending": "また別の思い出も聞いてくださいね。"
	},
	{
		"id": "聞いてほしい発見",
		"opening": "%sについて、ちょっと聞いてほしいことがあるんです。",
		"agree": "話してみてよかったです。",
		"detail": "ここからが私の好きなところなんです。",
		"doubt": "なるほど、そういう意見もありますね。",
		"personal": "誰かと話すと発見が増える気がします。",
		"ending": "聞いてくれてありがとうございました。"
	},
	{
		"id": "街角の雑談",
		"opening": "最近、%sの話を誰かとしてみたかったんです。",
		"agree": "こうして立ち話できるのがうれしいです。",
		"detail": "少し長くなりますが、聞いてください。",
		"doubt": "意見が違っても気楽に話せるのはいいですね。",
		"personal": "街にはまだまだ話題が転がっていそうです。",
		"ending": "また通りかかったら声をかけてください。"
	},
	{
		"id": "意外な一面",
		"opening": "%sには、意外な面がありそうだと思いませんか？",
		"agree": "小さな違いに気づくと面白いですよね。",
		"detail": "特にここを知って驚いたんです。",
		"doubt": "そうですね。意外と思うかどうかも人それぞれです。",
		"personal": "見慣れたことも別の角度から見たいです。",
		"ending": "次に会うまでに、また面白い面を探します。"
	},
	{
		"id": "歩きながら考えた",
		"opening": "この街を歩いていたら、%sが頭に浮かびました。",
		"agree": "散歩中に思いついたことも、話すと広がりますね。",
		"detail": "歩きながら、こんなことを考えていたんです。",
		"doubt": "歩いているときの考えは、気分にも左右されますね。",
		"personal": "急がず考える時間が私は好きです。",
		"ending": "それでは、散歩の続きを楽しみましょう。"
	},
	{
		"id": "休日の空想",
		"opening": "休みの日、%sを題材にした話を考えていたんです。",
		"agree": "こんな想像を話せる相手がいてうれしいです。",
		"detail": "考えているうちに、細かなところが気になってきました。",
		"doubt": "想像の仕方に正解はありませんね。",
		"personal": "想像から本当の興味が生まれることもあります。",
		"ending": "今度はどんな話になるか楽しみです。"
	},
	{
		"id": "じっくり語りたい",
		"opening": "もし時間がたっぷりあったら、%sについて語り合いたいです。",
		"agree": "じっくり話せるのはうれしいことです。",
		"detail": "まずは、私が気づいたことを伝えますね。",
		"doubt": "時間をかければ、違う意見も理解できるかもしれません。",
		"personal": "急がず話すと新しい考えが浮かびます。",
		"ending": "続きはまた、時間のあるときに。"
	},
	{
		"id": "人それぞれの好み",
		"opening": "人によって%sの感じ方は違いそうですよね。",
		"agree": "似た感じ方の人がいると安心します。",
		"detail": "私が気になるのは、こういうところです。",
		"doubt": "異なる好みを知るのも面白いです。",
		"personal": "好き嫌いが違っても話せる関係がいいですね。",
		"ending": "あなたの考えを聞けてよかったです。"
	},
	{
		"id": "小さな発見",
		"opening": "%sのことで、最近小さな発見があったんです。",
		"agree": "気づいてもらえるとうれしいものですね。",
		"detail": "その発見は、実はこんなことなんです。",
		"doubt": "大きな発見でなくても、人によって意味は違いますね。",
		"personal": "明日もひとつ発見できたらいいなと思います。",
		"ending": "また新しい発見を探してみますね。"
	}
]

# Data are built once and reused for all 46+ residents. No network or LLM calls.
static var _catalog: Array[Dictionary] = []


static func catalog() -> Array[Dictionary]:
	if not _catalog.is_empty():
		return _catalog
	for chunk in [TopicA.RAW, TopicB.RAW, TopicC.RAW, TopicD.RAW, TopicE.RAW]:
		for raw_line in String(chunk).strip_edges().split("\n", false):
			var columns: PackedStringArray = raw_line.strip_edges().split("|", false)
			if columns.size() != 6:
				push_error("Malformed resident conversation subject: " + raw_line)
				continue
			_catalog.append({
				"genre": String(columns[0]),
				"title": String(columns[1]),
				"hook": String(columns[2]),
				"detail": String(columns[3]),
				"counter": String(columns[4]),
				"question": String(columns[5])
			})
	return _catalog


static func is_valid_catalog() -> bool:
	var subjects := catalog()
	if subjects.size() != SUBJECT_COUNT or APPROACHES.size() != APPROACH_COUNT:
		return false
	var names: Dictionary = {}
	var genres: Dictionary = {}
	for subject in subjects:
		for field in ["genre", "title", "hook", "detail", "counter", "question"]:
			if String(subject.get(field, "")).strip_edges().is_empty():
				return false
		var name := String(subject["title"])
		if names.has(name):
			return false
		names[name] = true
		var genre := String(subject["genre"])
		genres[genre] = int(genres.get(genre, 0)) + 1
	if genres.size() != 25:
		return false
	for genre in genres:
		if int(genres[genre]) != 8:
			return false
	return true


static func make_profile(resident_id: int) -> Dictionary:
	# The same civilian slot keeps its identity after a reload or respawn.
	var rng := RandomNumberGenerator.new()
	rng.seed = 39017 + resident_id * 7919
	var given: String = GIVEN_NAMES[posmod(resident_id * 7 + 3, GIVEN_NAMES.size())]
	var family: String = FAMILY_NAMES[posmod(resident_id * 11 + 5, FAMILY_NAMES.size())]
	return {
		"id": resident_id,
		"name": "%s %s" % [family, given],
		"seed": int(rng.randi()),
		"favorite": rng.randi_range(0, 24),
		"greeting": rng.randi_range(0, GREETINGS.size() - 1)
	}


static func scenario_id(profile: Dictionary, talks: int = 0) -> int:
	# Resident-specific modular permutations: each resident visits every one of
	# the 2,000 entries exactly once before the conversation cycle repeats.
	var seed := int(profile.get("seed", 1))
	var step := 37 + posmod(seed, 191) * 2
	if step % 5 == 0:
		step += 2
	# step is odd and not divisible by five: coprime to 2,000 (=2^4 * 5^3).
	var offset := posmod(seed + int(profile.get("favorite", 0)) * 80, CONVERSATION_COUNT)
	return posmod(offset + posmod(maxi(talks, 0), CONVERSATION_COUNT) * step, CONVERSATION_COUNT)


static func make_tree(profile: Dictionary, talks: int = 0, affinity: int = 0) -> Dictionary:
	var subjects := catalog()
	if subjects.size() != SUBJECT_COUNT:
		return {}
	var scenario := scenario_id(profile, talks)
	var topic_index := floori(float(scenario) / float(APPROACH_COUNT))
	var approach_index := posmod(scenario, APPROACH_COUNT)
	var topic: Dictionary = subjects[topic_index]
	var approach: Dictionary = APPROACHES[approach_index]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(profile.get("seed", 1)) + maxi(talks, 0) * 7717 + scenario
	var greeting: String = GREETINGS[posmod(int(profile.get("greeting", 0)), GREETINGS.size())]
	if talks == 0:
		greeting = "はじめまして。%sです。" % String(profile.get("name", "住民"))
	elif affinity >= 6:
		greeting = "また会えてうれしいです。"
	else:
		greeting = "また会いましたね。"
	var opening: String = String(approach["opening"]) % String(topic["title"])
	var question: String = String(topic["question"])
	# Each topic has subject-specific fact, detail, counterpoint and question.
	# Responding negatively never implies agreement with the positive statement.
	var yes_or_no: Array = [
		{"text": "はい、そう思います", "next": "yes", "affinity": 1},
		{"text": "どちらかというと違います", "next": "no", "affinity": 0},
		{"text": "あなた自身はどうですか？", "next": "personal", "affinity": 1},
		{"text": "そろそろ行きます", "next": "bye", "affinity": 0}
	]
	var nodes: Dictionary = {
		"start": {
			"text": "%s\n%s\n%s" % [greeting, opening, String(topic["hook"])],
			"choices": []
		},
		"agree": {
			"text": "%s\n%s\n%s" % [String(approach["agree"]), String(topic["detail"]), question],
			"choices": yes_or_no.duplicate(true)
		},
		"detail": {
			"text": "%s\n%s\n%s" % [String(approach["detail"]), String(topic["detail"]), question],
			"choices": yes_or_no.duplicate(true)
		},
		"doubt": {
			"text": "%s\n%s\n%s" % [String(approach["doubt"]), String(topic["counter"]), question],
			"choices": yes_or_no.duplicate(true)
		},
		"yes": {
			"text": "そうなんですね。共通の話題があってうれしいです。",
			"choices": [
				{"text": "あなたはどうですか？", "next": "personal", "affinity": 1},
				{"text": "また話しましょう", "next": "bye", "affinity": 0}
			]
		},
		"no": {
			"text": "そういう感じ方もありますよね。違いを知れてよかったです。",
			"choices": [
				{"text": "あなたはどうですか？", "next": "personal", "affinity": 1},
				{"text": "また話しましょう", "next": "bye", "affinity": 0}
			]
		},
		"personal": {
			"text": "%s\n%sについては、これからも自分のペースで楽しみたいです。" % [String(approach["personal"]), String(topic["title"])],
			"choices": [
				{"text": "いいお話ですね", "next": "friendly_bye", "affinity": 2},
				{"text": "話してくれてありがとう", "next": "bye", "affinity": 1}
			]
		},
		"friendly_bye": {"text": "こちらこそ、話せてよかったです。%s" % String(approach["ending"]), "choices": []},
		"bye": {"text": "お話しできてよかったです。%s" % String(approach["ending"]), "choices": []}
	}
	var openings: Array = [
		{"text": "私もそう思います", "next": "agree", "affinity": 2},
		{"text": "もう少し詳しく聞きたい", "next": "detail", "affinity": 1},
		{"text": "別の見方もあると思います", "next": "doubt", "affinity": 0}
	]
	# Shuffle which perspectives are offered, and offer two or three.
	for index in range(openings.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var swap_value = openings[index]
		openings[index] = openings[swap_index]
		openings[swap_index] = swap_value
	var count := 2 + rng.randi_range(0, 1)
	var chosen: Array = []
	for index in range(count):
		chosen.append(openings[index])
	chosen.append({"text": "また今度話しましょう", "next": "bye", "affinity": 0})
	var start_node: Dictionary = nodes["start"]
	start_node["choices"] = chosen
	nodes["start"] = start_node
	for branch in ["agree", "detail", "doubt"]:
		var present := false
		for selection in chosen:
			if String(selection["next"]) == branch:
				present = true
				break
		if not present:
			nodes.erase(branch)
	return {
		"start": "start",
		"scenario_id": scenario,
		"topic": String(topic["title"]),
		"genre": String(topic["genre"]),
		"approach": String(approach["id"]),
		"nodes": nodes
	}


static func is_valid_tree(tree: Dictionary) -> bool:
	var nodes: Dictionary = tree.get("nodes", {})
	if not nodes.has(String(tree.get("start", ""))):
		return false
	var levels := {"start": 0, "agree": 1, "detail": 1, "doubt": 1, "yes": 2, "no": 2, "personal": 3, "friendly_bye": 4, "bye": 4}
	var pending: Array[String] = [String(tree["start"])]
	var reached: Dictionary = {}
	var terminals := 0
	while not pending.is_empty():
		var current := pending.pop_front()
		if reached.has(current):
			continue
		if not nodes.has(current) or not levels.has(current):
			return false
		reached[current] = true
		var node: Dictionary = nodes[current]
		if String(node.get("text", "")).strip_edges().is_empty():
			return false
		var choices: Array = node.get("choices", [])
		if choices.size() > 4:
			return false
		if choices.is_empty():
			terminals += 1
		for choice in choices:
			if not (choice is Dictionary):
				return false
			var dest := String(choice.get("next", ""))
			if not nodes.has(dest) or not levels.has(dest) or int(levels[dest]) <= int(levels[current]):
				return false
			if String(choice.get("text", "")).strip_edges().is_empty():
				return false
			pending.append(dest)
	return terminals >= 2 and reached.size() == nodes.size()
