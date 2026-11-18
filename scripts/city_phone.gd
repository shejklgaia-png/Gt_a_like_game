extends Panel
class_name PocketCityPhone
## A single mobile-friendly entry point into city services. Choosing an entry
## only sets pedestrian/vehicle GPS; purchases and conversations stay on-site.

const Districts = preload("res://scripts/district_data.gd")
const Dialogue = preload("res://scripts/resident_dialogue.gd")
const GameData = preload("res://scripts/gameplay_data.gd")

var game: Node3D
var page: String = "仕事"
var headline: Label
var summary: Label
var entries: VBoxContainer
var tabs: Array[Button] = []


func _ready() -> void:
	name = "CityPhone"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", panel_style(Color("#152634")))
	var padding := MarginContainer.new()
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + edge, 12)
	add_child(padding)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	padding.add_child(body)
	headline = add_text(body, 22, Color("#e9f8f0"))
	headline.text = "CITY PHONE  /  街の案内"
	summary = add_text(body, 15, Color("#b2d4d8"))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	body.add_child(tab_bar)
	for section in ["仕事", "店舗", "住居", "車両", "情報", "依頼"]:
		var tab := make_button(section, Color("#365364"), 15)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = 45
		tab.pressed.connect(open_page.bind(section))
		tab_bar.add_child(tab)
		tabs.append(tab)
	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroller)
	entries = VBoxContainer.new()
	entries.add_theme_constant_override("separation", 7)
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(entries)
	var tip := add_text(body, 14, Color("#a9c2c6"))
	tip.text = "案内を設定 → 地図を見ながら移動 → 現地でACTION"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	body.add_child(footer)
	var reset := make_button("案内解除", Color("#5a5362"), 16)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.custom_minimum_size.y = 46
	reset.pressed.connect(clear_waypoint)
	footer.add_child(reset)
	var close := make_button("街へ戻る", Color("#257568"), 16)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.custom_minimum_size.y = 46
	close.pressed.connect(close_phone)
	footer.add_child(close)
	visible = false


func panel_style(tint: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.set_corner_radius_all(15)
	return box


func add_text(parent: Node, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func make_button(title: String, tint: Color, font_size: int = 17) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("#f1faf9"))
	button.add_theme_stylebox_override("normal", panel_style(tint))
	button.add_theme_stylebox_override("hover", panel_style(tint.lightened(0.16)))
	button.add_theme_stylebox_override("pressed", panel_style(tint.darkened(0.16)))
	return button


func open_phone() -> void:
	if visible:
		return
	visible = true
	game.fire_held = false
	game.stick_value = Vector2.ZERO
	game.stick_pointer = -1
	game.camera_touch = -1
	get_tree().paused = true
	open_page(page)


func close_phone() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	game.fire_held = false
	game.stick_value = Vector2.ZERO


func open_page(section: String) -> void:
	page = section
	for index in range(tabs.size()):
		tabs[index].modulate = Color("#ffe6b1") if index == ["仕事", "店舗", "住居", "車両", "情報", "依頼"].find(page) else Color.WHITE
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	summary.text = ("現在の案内: " + String(game.navigation_label)) if not String(game.navigation_label).is_empty() else "行きたい仕事や施設を選んでください"
	match page:
		"仕事":
			fill_jobs()
		"店舗":
			fill_shops()
		"住居":
			fill_homes()
		"車両":
			fill_cars()
		"情報":
			fill_discoveries()
		"依頼":
			fill_quests()


func note(message: String) -> void:
	var text := add_text(entries, 16, Color("#afcad2"))
	text.text = message
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func current_position() -> Vector3:
	return game.current_travel_position()


func distance_m(at: Vector3) -> int:
	var pos := current_position()
	return roundi(Vector2(pos.x - at.x, pos.z - at.z).length())


func destination(title: String, detail: String, kind: String, key: String, at: Vector3, color: Color = Color("#315768")) -> void:
	var button := make_button("%s  ・  %dm\n%s" % [title, distance_m(at), detail], color, 16)
	button.custom_minimum_size.y = 68
	button.pressed.connect(select_destination.bind(kind, key, title, at))
	entries.add_child(button)


func select_destination(kind: String, key: String, title: String, at: Vector3) -> void:
	game.set_city_waypoint(kind, key, title, at)
	close_phone()


func clear_waypoint() -> void:
	game.clear_city_waypoint()
	close_phone()


func closest_lot(business: String, owned_only: bool = false, unowned_only: bool = false) -> Dictionary:
	var best := INF
	var result: Dictionary = {}
	var at := current_position()
	for lot in game.city.buildings:
		if not lot.has("door") or String(lot.get("business", "")) != business:
			continue
		var is_owned: bool = game.purchased_homes.has(String(lot["id"]))
		if owned_only and not is_owned:
			continue
		if unowned_only and is_owned:
			continue
		var door: Vector3 = lot["door"]
		var distance := Vector2(door.x - at.x, door.z - at.z).length_squared()
		if distance < best:
			best = distance
			result = lot
	return result


func fill_jobs() -> void:
	note("仕事は現地でACTIONを押して開始・進行します。\n配達中も別の地域ジョブを選べます。")
	var social: PocketConversationActivities = game.conversation_activities
	if is_instance_valid(social) and social.active:
		destination("住民の活動：" + String(social.active_offer()["title"]),
			social.objective_description(), "activity", "", social.objective_position(), Color("#6b6451"))
		var abandon_button := make_button("住民の活動を辞退する（報酬なし）", Color("#694e56"), 15)
		abandon_button.custom_minimum_size.y = 47
		abandon_button.pressed.connect(func() -> void:
			game.cancel_conversation_activity()
			open_page("仕事")
		)
		entries.add_child(abandon_button)
	elif is_instance_valid(social):
		note("住民と話すと、街の活動や紹介を受けられます（報酬・親密度あり）。")
	var contract: Dictionary = GameData.delivery_contract(game.deliveries)
	var label := "配達  #%d  %s" % [game.deliveries + 1, String(contract["title"])]
	var status := "荷物の届け先（制限時間あり）" if game.mission_stage == 1 else "荷物を受け取る（初期ジョブ）"
	destination(label, status, "delivery", "", game.mission_point, Color("#645538"))
	var jobs: PocketNeighborhoodJobs = game.neighborhood_jobs
	if is_instance_valid(jobs) and is_instance_valid(jobs.board_marker):
		var active_label := "地域ジョブ：%s" % String(jobs.active_contract()["title"])
		if jobs.active:
			destination(active_label, "調査先 %d/2  → 次の地点へ" % (jobs.step_index + 1), "side_job", "", jobs.objective_position(), Color("#2d6b64"))
			destination("地域ジョブ受付", "進行中の仕事は現地で進めてください", "job_board", "", jobs.board_position)
		else:
			destination("地域ジョブ受付", "調査・市場点検・夜間巡回を順番に受注", "side_job", "", jobs.board_position, Color("#2d6b64"))
	note("配達完了: %d件   地域ジョブ完了: %d件" % [game.deliveries, jobs.completed if is_instance_valid(jobs) else 0])


func fill_shops() -> void:
	note("各店舗の入口でACTIONを押すと、購入や入店ができます。")
	for item in [
		{"id": "gun", "title": "武器・弾薬", "desc": "武器の購入・弾薬補給"},
		{"id": "supermarket", "title": "スーパー", "desc": "食品・日用品"},
		{"id": "convenience", "title": "コンビニ", "desc": "軽食・消耗品"},
		{"id": "clothing", "title": "洋服店", "desc": "衣装・外見"},
		{"id": "furniture", "title": "家具店", "desc": "マイルーム用家具"},
		{"id": "market", "title": "市場", "desc": "マーケットを訪問"},
		{"id": "restaurant", "title": "飲食店", "desc": "街の飲食店へ"},
		{"id": "lounge", "title": "ラウンジ", "desc": "夜の繁華街へ"},
		{"id": "club", "title": "クラブ", "desc": "夜の施設へ"}
	]:
		var lot := closest_lot(String(item["id"]))
		if not lot.is_empty():
			var door: Vector3 = lot["door"]
			destination(String(item["title"]), String(item["desc"]), "lot", String(lot["id"]), door)


func fill_homes() -> void:
	note("住居を購入すると、室内への入室と家具の配置ができます。")
	var owned_count: int = game.purchased_homes.size()
	note("所有物件：%d件   家具の所持種類：%d" % [owned_count, game.furniture_inventory.size()])
	for lot in game.city.buildings:
		if String(lot.get("business", "")) != "apartment":
			continue
		if game.purchased_homes.has(String(lot["id"])):
			var door: Vector3 = lot["door"]
			destination("マイルーム  " + String(lot["id"]), "室内でACTION → 家具配置", "lot", String(lot["id"]), door, Color("#2a6558"))
	var listing := closest_lot("apartment", false, true)
	if not listing.is_empty():
		var entry: Vector3 = listing["door"]
		destination("物件を探す", "近くの売り物件   $%d" % int(listing["home_price"]), "lot", String(listing["id"]), entry)
	elif owned_count == 0:
		note("現在、案内できる販売物件がありません。")


func fill_cars() -> void:
	note("ガレージで自家用車を購入・回送できます。車の乗降は現地ACTIONです。")
	var garage := closest_lot("garage")
	if not garage.is_empty():
		var door: Vector3 = garage["door"]
		destination("CITY GARAGE", "自家用車の購入・回送・見学", "lot", String(garage["id"]), door, Color("#246f6d"))
	if is_instance_valid(game.garage_car):
		destination("マイカー", "所有中の車へ移動", "owned_car", "", game.garage_car.global_position, Color("#246f6d"))
	else:
		note("自家用車：未購入（購入価格 $1350）")


func fill_discoveries() -> void:
	note("探索・交流・所持品・設定への入口です。")
	if is_instance_valid(game.conversation_activities):
		var activities: PocketConversationActivities = game.conversation_activities
		note("住民の活動完了：%d件  /  会話から仕事や交流に派生できます" % activities.total_completed)
	var closest_id := -1
	var best := INF
	for i in range(game.street_finds.total_count()):
		if game.street_finds.collected.has(game.street_finds.site_ids[i]):
			continue
		var site: Vector3 = game.street_finds.site_positions[i]
		var distance := float(distance_m(site))
		if distance < best:
			best = distance
			closest_id = i
	if closest_id >= 0:
		var site: Vector3 = game.street_finds.site_positions[closest_id]
		destination("隠された街のアイテム", "最寄りの未発見品を探す", "cache", game.street_finds.site_ids[closest_id], site, Color("#715c35"))
	else:
		note("街の発見品をすべて回収済みです。")
	var closest_person: PocketActor = null
	var resident_distance := INF
	for resident in game.city.people:
		if not is_instance_valid(resident) or resident.dead or resident.panic_time > 0.0:
			continue
		var gap: float = current_position().distance_squared_to(resident.global_position)
		if gap < resident_distance:
			resident_distance = gap
			closest_person = resident
	if closest_person != null:
		var profile: Dictionary = Dialogue.make_profile(closest_person.resident_id)
		destination("近くの住民：%s" % String(profile["name"]), "近づいてACTION → 会話", "resident", str(closest_person.resident_id), closest_person.global_position)
	note("探索品：%d/%d   装備：%s   収入：$%d" % [
		game.street_finds.count_collected(), game.street_finds.total_count(),
		str(game.owned_weapons.size()) + "種", game.total_earnings
	])
	var settings := make_button("表示・カメラ・サウンド設定を開く", Color("#495368"), 16)
	settings.custom_minimum_size.y = 58
	settings.pressed.connect(open_settings)
	entries.add_child(settings)


func fill_quests() -> void:
	var director: PocketQuestDirector = game.quest_director
	if not is_instance_valid(director):
		note("依頼データは準備中です")
		return
	note("発見と完了の記録：%d/200件完了  |  進行中：%d/3件" % [director.completed_count(), director.active.size()])
	note("街での呼びかけ・会話・警官・事故・買物・室内・戦闘など、25種類の出来事から200件の物語が発生します。")
	if director.active.is_empty():
		note("進行中の依頼はありません。街を歩いたり住民に話しかけてみてください。")
	for item in director.active:
		var quest: Dictionary = director.get_quest(String(item["id"]))
		var caption := "%s  %s\n%s" % [String(quest["id"]), String(quest["title"]), director.describe(item)]
		var button := make_button(caption, Color("#625c7d"), 15)
		button.custom_minimum_size.y = 85
		button.pressed.connect(select_quest.bind(String(quest["id"])))
		entries.add_child(button)
		var explanation := add_text(entries, 14, Color("#bbccd8"))
		explanation.text = String(quest.get("hook", ""))
		explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var abandon_button := make_button("この依頼を中断する（報酬なし）", Color("#644b54"), 14)
		abandon_button.custom_minimum_size.y = 40
		abandon_button.pressed.connect(abandon_quest.bind(String(quest["id"])))
		entries.add_child(abandon_button)
	note("完了済みの記録：")
	var shown := 0
	for id in director.catalog:
		if not director.completed.has(String(id)):
			continue
		var row: Dictionary = director.get_quest(String(id))
		var label := add_text(entries, 14, Color("#8fbeb1"))
		label.text = "✓ %s  %s" % [id, String(row["title"])]
		shown += 1
		if shown >= 20:
			break
	if shown == 0:
		note("まだありません。依頼の完了がここに記録されます。")
	elif director.completed_count() > shown:
		note("ほか %d件はセーブデータに記録されています。" % (director.completed_count() - shown))


func select_quest(id: String) -> void:
	var row: Dictionary = game.quest_director.get_quest(id)
	var target: Dictionary = game.quest_waypoint(id)
	if target.is_empty():
		note("この段階は地図に固定できません。依頼の説明に従って行動してください。")
		return
	game.set_city_waypoint("quest", id, String(row.get("title", "")), target["point"])
	close_phone()


func abandon_quest(id: String) -> void:
	game.cancel_quest(id)
	open_page("依頼")


func open_settings() -> void:
	close_phone()
	game.toggle_settings()
