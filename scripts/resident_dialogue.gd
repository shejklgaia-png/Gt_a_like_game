extends RefCounted
class_name PocketResidentDialogue

# All branches are constructed from one topic at a time. Replies never jump into
# unrelated topics; every option names an explicit existing successor node.
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
const TOPICS := [
	{
		"id": "streets",
		"opening": "この街、区画ごとに建物の色が違うんですよ。",
		"agree": "ですよね。歩くだけで少し気分が変わります。",
		"detail": "私は角を曲がったときに景色が変わるのが好きです。",
		"doubt": "確かに、派手すぎると感じる場所もありますね。",
		"question": "目的を決めずに散歩することはありますか？",
		"yes": "では、お気に入りの道もありそうですね。",
		"no": "目的地までまっすぐ歩くのもいいですよね。",
		"personal": "私は静かな歩道を見つけると、つい遠回りします。",
		"bye": "また街で会いましょう。"
	},
	{
		"id": "music",
		"opening": "街を歩くとき、頭の中で曲が流れることがあるんです。",
		"agree": "わかってくれますか。歩く速さまで変わりますよね。",
		"detail": "落ち着いた曲だと、景色をよく眺められる気がします。",
		"doubt": "静かなほうが好きな人もいますよね。",
		"question": "散歩中に音楽を聴くのは好きですか？",
		"yes": "音楽があると、いつもの道も違って感じますね。",
		"no": "街の音に耳を澄ますのもいいものです。",
		"personal": "私は帰り道には、ゆっくりした曲を選びます。",
		"bye": "またおすすめの曲の話をしましょう。"
	},
	{
		"id": "work",
		"opening": "最近、忙しい日ほど休み方が大切だと思うんです。",
		"agree": "同じ考えでうれしいです。無理は続きませんからね。",
		"detail": "短い休憩でも、気分を切り替える時間になります。",
		"doubt": "忙しいと、なかなか休めないこともありますよね。",
		"question": "ひと息つく時間は意識して作っていますか？",
		"yes": "それなら安心です。自分のペースを大事にしたいですね。",
		"no": "ほんの少し座るだけでも違うかもしれませんね。",
		"personal": "私は用事をひとつ終えるたびに、少し空を見ます。",
		"bye": "お互い、無理のない一日を。"
	},
	{
		"id": "neighbors",
		"opening": "この近所には、まだ知らない人がたくさんいますね。",
		"agree": "知り合いが増えると、街の印象も変わりそうです。",
		"detail": "同じ道ですれ違う人でも、話すと意外な一面が見えます。",
		"doubt": "最初から親しく話すのは、ちょっと緊張しますよね。",
		"question": "近所の人とは、よく立ち話をしますか？",
		"yes": "いいですね。挨拶から始まる関係って素敵です。",
		"no": "無理に話さなくても、挨拶だけで十分な日もあります。",
		"personal": "私は顔を覚えてもらえると、それだけでうれしいです。",
		"bye": "次に会ったときも、声をかけてくださいね。"
	},
	{
		"id": "hobbies",
		"opening": "最近、何か新しい趣味を始めようか考えています。",
		"agree": "新しいことって、ちょっとわくわくしますよね。",
		"detail": "上手にできなくても、楽しめたら十分だと思っています。",
		"doubt": "続けられるか不安になるのも、よくわかります。",
		"question": "知らないことに挑戦するのは好きですか？",
		"yes": "その好奇心、いいですね。私も見習いたいです。",
		"no": "慣れたことをじっくり楽しむのも素敵ですよ。",
		"personal": "私はまず、気軽に試せることから始めたいです。",
		"bye": "何か始めたら、また話しますね。"
	},
	{
		"id": "quiet",
		"opening": "にぎやかな街にも、静かな時間があるのが好きです。",
		"agree": "あの落ち着いた感じ、いいですよね。",
		"detail": "人通りが少なくなると、普段は気づかない音が聞こえます。",
		"doubt": "にぎやかな雰囲気のほうが落ち着く人もいますね。",
		"question": "ひとりで静かに過ごす時間は好きですか？",
		"yes": "私もです。気持ちを整える時間になりますよね。",
		"no": "誰かと過ごす時間も大切ですよね。",
		"personal": "私は静かな場所で少し考え事をするのが好きです。",
		"bye": "またゆっくりお話ししましょう。"
	}
]


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
		"favorite": rng.randi_range(0, TOPICS.size() - 1),
		"greeting": rng.randi_range(0, GREETINGS.size() - 1)
	}


static func make_tree(profile: Dictionary, talks: int = 0, affinity: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(profile.get("seed", 1)) + maxi(talks, 0) * 7717
	# The first topic and later topics differ by person, not by every frame.
	var topic_id := (int(profile.get("favorite", 0)) + rng.randi_range(0, TOPICS.size() - 1)) % TOPICS.size()
	var topic: Dictionary = TOPICS[topic_id]
	var greeting: String = GREETINGS[int(profile.get("greeting", 0)) % GREETINGS.size()]
	if talks == 0:
		greeting = "はじめまして。%sです。" % String(profile.get("name", "住民"))
	elif affinity >= 6:
		greeting = "また会えてうれしいです。"
	elif talks > 0:
		greeting = "また会いましたね。"
	var question := String(topic["question"])
	var yes_or_no := [
		{"text": "はい、好きです", "next": "yes", "affinity": 1},
		{"text": "あまりしません", "next": "no", "affinity": 0},
		{"text": "あなたはどうですか？", "next": "personal", "affinity": 1},
		{"text": "また今度", "next": "bye", "affinity": 0}
	]
	var nodes := {
		"start": {
			"text": "%s\n%s" % [greeting, String(topic["opening"])],
			"choices": [
				{"text": "私もそう思います", "next": "agree", "affinity": 2},
				{"text": "詳しく聞きたいです", "next": "detail", "affinity": 1},
				{"text": "そうは思いません", "next": "doubt", "affinity": 0},
				{"text": "また今度話しましょう", "next": "bye", "affinity": 0}
			]
		},
		"agree": {"text": "%s\n%s" % [topic["agree"], question], "choices": yes_or_no.duplicate(true)},
		"detail": {"text": "%s\n%s" % [topic["detail"], question], "choices": yes_or_no.duplicate(true)},
		"doubt": {"text": "%s\n%s" % [topic["doubt"], question], "choices": yes_or_no.duplicate(true)},
		"yes": {
			"text": topic["yes"],
			"choices": [
				{"text": "あなたはどうですか？", "next": "personal", "affinity": 1},
				{"text": "また話しましょう", "next": "bye", "affinity": 0}
			]
		},
		"no": {
			"text": topic["no"],
			"choices": [
				{"text": "あなたはどうですか？", "next": "personal", "affinity": 1},
				{"text": "また話しましょう", "next": "bye", "affinity": 0}
			]
		},
		"personal": {
			"text": topic["personal"],
			"choices": [
				{"text": "いいお話ですね", "next": "friendly_bye", "affinity": 2},
				{"text": "話してくれてありがとう", "next": "bye", "affinity": 1}
			]
		},
		"friendly_bye": {"text": "こちらこそ、話せてよかったです。また会いましょう！", "choices": []},
		"bye": {"text": topic["bye"], "choices": []}
	}
	return {"start": "start", "topic": topic["id"], "nodes": nodes}


static func is_valid_tree(tree: Dictionary) -> bool:
	var nodes: Dictionary = tree.get("nodes", {})
	if not nodes.has(String(tree.get("start", ""))):
		return false
	var pending: Array[String] = [String(tree["start"])]
	var reached: Dictionary = {}
	var terminals := 0
	while not pending.is_empty():
		var current := pending.pop_front()
		if reached.has(current):
			continue
		if not nodes.has(current):
			return false
		reached[current] = true
		var node: Dictionary = nodes[current]
		if String(node.get("text", "")).strip_edges() == "":
			return false
		var choices: Array = node.get("choices", [])
		if choices.is_empty():
			terminals += 1
		for choice in choices:
			if not (choice is Dictionary):
				return false
			var dest := String(choice.get("next", ""))
			if not nodes.has(dest) or String(choice.get("text", "")).strip_edges() == "":
				return false
			pending.append(dest)
	return terminals > 0 and reached.size() == nodes.size()
