extends SceneTree
## Regression for the 200 story quests. Uses a private save file so real
## players' progress is never altered; tests genuine game event entrances.

func _initialize() -> void:
	call_deferred("check")


func fail(reason: String, code: int) -> void:
	push_error(reason)
	quit(code)


func clear_active(director: PocketQuestDirector) -> void:
	director.active.clear()
	director.started_at.clear()
	director.elapsed += 30.0


func check() -> void:
	var path := "user://pocket_200_quests_regression.json"
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		fail("Quest game scene did not load", 501)
		return
	var game = scene.instantiate()
	game.save_path_override = path
	root.add_child(game)
	await process_frame
	await physics_frame
	var director: PocketQuestDirector = game.quest_director
	if not is_instance_valid(director) or director.catalog.size() != 200 or director.event_index.size() != 25:
		fail("Exactly 200 catalog quests and 25 triggers must load", 502)
		return
	var titles: Dictionary = {}
	var hooks: Dictionary = {}
	var trigger_counts: Dictionary = {}
	for id in director.catalog:
		var quest: Dictionary = director.catalog[id]
		if titles.has(String(quest["title"])) or hooks.has(String(quest["hook"])):
			fail("Quest title or narrative premise repeats: " + str(id), 503)
			return
		titles[String(quest["title"])] = true
		hooks[String(quest["hook"])] = true
		var trigger: String = String(quest["trigger"])
		trigger_counts[trigger] = int(trigger_counts.get(trigger, 0)) + 1
		if int(quest["reward"]) < 100 or not quest["stages"] is Array or quest["stages"].size() != 2:
			fail("Malformed authored quest stages or rewards: " + str(id), 504)
			return
	for kind in trigger_counts:
		if int(trigger_counts[kind]) != 8:
			fail("Trigger family does not contain exactly eight authored plots: " + kind, 505)
			return

	# An NPC calling out is enough to start a story without TALK.
	game.quest_event("npc_call", {"role": "買い物", "resident_id": 0})
	if director.active.size() != 1 or String(director.active[0]["id"]) != "Q001":
		fail("A nearby shopping resident did not trigger first spontaneous quest", 506)
		return
	if game.navigation_kind != "quest" or game.navigation_id != "Q001":
		fail("Newly discovered quest is not automatically reachable via GPS", 507)
		return
	game.city_phone.open_phone()
	game.city_phone.open_page("依頼")
	var active_found := false
	for entry in game.city_phone.entries.get_children():
		if entry is Button and String(entry.text).contains("迷子の昼食券"):
			active_found = true
	if not active_found or game.city_phone.tabs.size() != 6:
		fail("CITY journal tab cannot browse a new quest", 508)
		return
	game.city_phone.close_phone()
	var initial_cash: int = game.cash
	game.quest_event("lot_action", {"business": "restaurant"})
	if int(director.active[0]["step"]) != 1 or game.cash != initial_cash:
		fail("First quest action should advance but not pay", 509)
		return
	if not game.navigation_kind == "quest" or not game.city_waypoint_point().is_finite():
		fail("Stage transition did not retain reachable next destination", 510)
		return
	game.quest_event("lot_action", {"business": "market"})
	if director.active.size() != 0 or not director.completed.has("Q001"):
		fail("Second quest step did not complete its story", 511)
		return
	if game.cash != initial_cash + int(director.catalog["Q001"]["reward"]) or game.navigation_kind == "quest":
		fail("Quest rewards are wrong or stale GPS remained after completion", 512)
		return
	game.quest_event("lot_action", {"business": "market"})
	if game.cash != initial_cash + int(director.catalog["Q001"]["reward"]):
		fail("A completed quest can pay repeatedly", 513)
		return
	game.save_game()
	director.completed.clear()
	game.load_game()
	if not director.completed.has("Q001") or director.completed_count() != 1:
		fail("Quest completion history did not survive legacy-safe save/load", 514)
		return

	# Each trigger is backed by a gameplay event rather than a journal button.
	clear_active(director)
	var before: int = director.active.size()
	game.hero.global_position = game.quest_incidents.patrol.global_position + Vector3(0.3, 0, 0.3)
	game.interaction()
	if director.active.size() <= before or String(director.active[0]["id"]) != "Q025":
		fail("Real ACTION at nonhostile patrol did not start police quest", 515)
		return
	clear_active(director)
	var retail: Dictionary = {}
	for lot in game.city.buildings:
		if String(lot["business"]) == "supermarket":
			retail = lot
			break
	if retail.is_empty():
		fail("Supermarket lot missing from the world", 516)
		return
	game.enter_interior(retail)
	if not game.indoors or director.active.is_empty() or String(director.active[0]["id"]) != "Q033":
		fail("Entering an actual supermarket did not trigger shop-specific story", 517)
		return
	game.leave_interior()
	clear_active(director)
	var apartment: Dictionary = {}
	for lot in game.city.buildings:
		if String(lot["business"]) == "apartment":
			apartment = lot
			break
	game.enter_interior(apartment)
	if director.active.is_empty() or String(director.active[0]["id"]) != "Q041":
		fail("Walking into a real residence did not start a housing quest", 518)
		return
	game.leave_interior()
	clear_active(director)

	# Test the real purchasing methods and emitted events.
	game.cash = 10000
	game.purchase_gun("Rifle")
	if director.active.is_empty() or String(director.active[0]["id"]) != "Q066":
		fail("Purchasing the Rifle did not unlock its dedicated weapon quest", 519)
		return
	clear_active(director)
	game.open_commerce_for(apartment)
	game.select_commerce_option(0)
	if not game.purchased_homes.has(String(apartment["id"])):
		fail("The base-game housing purchase path regressed", 520)
		return
	if director.active.is_empty() or String(director.active[0]["id"]) != "Q073":
		fail("Real property purchase did not create a home quest", 521)
		return
	game.close_commerce()
	clear_active(director)
	var furniture_shop: Dictionary = {}
	for lot in game.city.buildings:
		if String(lot["business"]) == "furniture":
			furniture_shop = lot
			break
	game.open_commerce_for(furniture_shop)
	var chair_index := -1
	for index in range(game.commerce_options.size()):
		var opt: Dictionary = game.commerce_options[index]
		if String(opt.get("type", "")) == "buy_stock" and String(opt.get("merchandise", {}).get("id", "")) == "chair":
			chair_index = index
			break
	if chair_index < 0:
		fail("Furniture catalog no longer sells chairs", 522)
		return
	game.select_commerce_option(chair_index)
	if director.active.is_empty() or String(director.active[0]["id"]) != "Q084":
		fail("Buying a specific chair did not start its furniture quest", 523)
		return
	game.close_commerce()
	clear_active(director)

	# Collision must carry a real damaged-player event, not a proximity-only
	# guess. A synthetic signal probes the exact hooked physics signal path.
	var before_hp: float = game.hero.hp
	game.city.cars[0].ran_into_hero.emit(game.city.cars[0], 11.0)
	if game.hero.hp >= before_hp:
		fail("Vehicle impact event did not physically damage the player", 524)
		return
	var accident_started := false
	for record in director.active:
		if String(record["id"]).begins_with("Q05"):
			accident_started = true
	if not accident_started:
		fail("A speed-qualified car collision did not initiate an accident quest", 525)
		return
	clear_active(director)
	game.hero.reset_health()
	
	# The scene really contains fighting actors *before* the player arrives.
	var incident: PocketQuestIncidents = game.quest_incidents
	incident.spawn_clash(Vector3(42.35, 0.25, 18.0))
	if incident.fighters.size() != 2 or incident.fighters[0].dead or incident.fighters[1].dead:
		fail("Ambient combat scene did not instantiate two live opponents", 526)
		return
	game.hero.global_position = Vector3(42.35, 0.25, 15.0)
	incident._process(1.4)
	var saw_combat := false
	for item in director.active:
		if String(item["id"]) == "Q097":
			saw_combat = true
	if not saw_combat or not incident.witnessed:
		fail("Walking into an already-active skirmish did not start a witness quest", 527)
		return
	incident.clear_clash()
	clear_active(director)

	# Driving quests are offered only after actual travel, never just sitting
	# in a vehicle. The queued distance stage must retain partial progress.
	game.quest_event("car_entered", {"ownership": "owned"})
	if director.active.is_empty() or String(director.active[0]["id"]) != "Q113":
		fail("Entering an owned car did not start an owned-car story", 528)
		return
	game.quest_event("driving", {"amount": 30.0, "ready": false})
	if float(director.active[0]["progress"]) < 29.0 or int(director.active[0]["step"]) != 0:
		fail("First 30 driven meters were not counted toward the quest", 529)
		return
	game.save_game()
	director.restore({})
	game.load_game()
	if director.active.is_empty() or float(director.active[0]["progress"]) < 29.0:
		fail("Partial driving distance was lost after save/load", 530)
		return
	game.quest_event("driving", {"amount": 27.0, "ready": false})
	if int(director.active[0]["step"]) != 1:
		fail("Reaching driving distance did not unlock the next task", 531)
		return
	clear_active(director)
	game.quest_event("driving", {"amount": 1.0, "ready": false})
	if not director.active.is_empty():
		fail("Driving story started before the 45 meter discovery milestone", 532)
		return
	game.quest_event("driving", {"amount": 45.0, "ready": true})
	if director.active.is_empty() or String(director.active[0]["id"]) != "Q121":
		fail("Travel milestone did not launch a driving-discovery quest", 533)
		return
	clear_active(director)
	var before_count := director.completed_count()
	game.quest_event("furniture_placed", {"item": "wardrobe"})
	if director.active.is_empty() or String(director.active[0]["id"]) != "Q096":
		fail("Specific wardrobe placement does not unlock its quest", 534)
		return
	clear_active(director)
	game.quest_event("district_visit", {"district": "nightlife"})
	if director.active.is_empty() or String(director.active[0]["id"]) != "Q156":
		fail("Entering nightlife district does not offer its local stories", 535)
		return
	clear_active(director)
	game.quest_event("wanted_raised", {"level": 1})
	if director.active.is_empty() or String(director.active[0]["id"]) != "Q161":
		fail("Police chase warning cannot start a consequence quest", 536)
		return
	if director.completed_count() != before_count:
		fail("Simply discovering stories granted rewards or completed stories", 537)
		return
	print("PASS: 200 authored quests, 25 trigger families and 200 unique narratives")
	print("PASS: NPC callout, actual police ACTION, shop/home entry, gun/home/chair purchase")
	print("PASS: vehicle impact, pre-existing NPC street fight and furniture/district/wanted triggers")
	print("PASS: 3-slot quest journal, two-step progress, once-only reward, GPS and save/load")
	print("PASS: distance-gated vehicle stories with partial distance persistence")
	quit(0)
