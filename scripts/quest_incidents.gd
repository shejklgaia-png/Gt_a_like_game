extends Node3D
class_name PocketQuestIncidents
## Real-world quest sources. A neutral street patrol can be contacted by
## ACTION; short NPC-on-NPC clashes start before the player reaches the site.
## Neither incident actor is treated as a crime caused by the player.

const ActorScript = preload("res://scripts/actor.gd")
const Shapes = preload("res://scripts/shape_factory.gd")
const SITES := [
	Vector3(-29.65, 0.25, -54.0),
	Vector3(42.35, 0.25, 18.0),
	Vector3(78.35, 0.25, 54.0)
]

var game: Node3D
var patrol: PocketActor
var fighters: Array[PocketActor] = []
var signpost: Node3D
var incident_time: float = 0.0
var spawn_cooldown: float = 12.0
var beat_clock: float = 0.0
var site_index: int = 0
var witnessed: bool = false


func setup(owner: Node3D) -> void:
	game = owner
	name = "QuestIncidentSources"
	patrol = ActorScript.new()
	patrol.name = "NeighborhoodPatrol"
	patrol.position = Vector3(6.35, 0.24, 18.0)
	patrol.setup(true, patrol.position, 78613)
	patrol.set_meta("quest_patrol", true)
	add_child(patrol)


func nearest_officer(at: Vector3, within: float = 3.3) -> PocketActor:
	if is_instance_valid(patrol) and not patrol.dead and patrol.global_position.distance_to(at) <= within:
		return patrol
	for officer in fighters:
		if is_instance_valid(officer) and officer.officer and not officer.dead and officer.global_position.distance_to(at) <= within:
			return officer
	return null


func _process(delta: float) -> void:
	if game == null or not is_instance_valid(game.hero) or game.indoors:
		return
	if fighters.is_empty():
		spawn_cooldown -= delta
		if spawn_cooldown > 0.0:
			return
		var best := INF
		var selected := -1
		for step in range(SITES.size()):
			var index := posmod(site_index + step, SITES.size())
			var distance: float = game.hero.global_position.distance_to(SITES[index])
			if distance < best:
				best = distance
				selected = index
		if selected >= 0 and best < 68.0:
			site_index = posmod(selected + 1, SITES.size())
			spawn_clash(SITES[selected])
		return
	incident_time += delta
	var officer: PocketActor = fighters[0]
	var adversary: PocketActor = fighters[1]
	if not is_instance_valid(officer) or not is_instance_valid(adversary) or officer.dead or adversary.dead or incident_time >= 42.0:
		clear_clash()
		return
	if not witnessed and incident_time > 1.1 and game.hero.global_position.distance_to(adversary.global_position) <= 15.0:
		witnessed = true
		game.quest_event("fight_witness", {"position": [adversary.global_position.x, adversary.global_position.y, adversary.global_position.z]})
	beat_clock += delta
	if beat_clock > 1.65:
		beat_clock = 0.0
		if officer.global_position.distance_to(adversary.global_position) <= 3.1:
			# Built-in baton animation targets heroes, so actors receive a
			# small explicit symmetric hit to make the conflict genuine.
			officer.try_baton_attack(adversary, 0.9)
			adversary.try_baton_attack(officer, 0.9)
			officer.hit(0.6)
			adversary.hit(0.6)


func spawn_clash(where: Vector3) -> void:
	incident_time = 0.0
	beat_clock = 0.0
	witnessed = false
	var officer := ActorScript.new()
	officer.name = "IncidentOfficer"
	officer.position = where + Vector3(-1.2, 0.0, 0.0)
	officer.setup(true, officer.position, 60031 + site_index)
	officer.set_meta("ambient_incident", true)
	add_child(officer)
	var suspect := ActorScript.new()
	suspect.name = "IncidentSuspect"
	suspect.position = where + Vector3(0.95, 0, 0)
	suspect.setup(false, suspect.position, 78015 + site_index)
	suspect.mafia = true
	suspect.chatting = true # stays around the scene instead of wandering away
	suspect.set_meta("ambient_incident", true)
	add_child(suspect)
	officer.engage = true
	officer.chase_target = suspect
	fighters = [officer, suspect]
	signpost = Node3D.new()
	signpost.position = where + Vector3(0, 0.0, -2.4)
	add_child(signpost)
	Shapes.sign3d(signpost, "CITY INCIDENT", Vector3(0, 2.8, 0), Color("#ffb17d"))


func clear_clash() -> void:
	for actor in fighters:
		if is_instance_valid(actor):
			actor.queue_free()
	fighters.clear()
	if is_instance_valid(signpost):
		signpost.queue_free()
	signpost = null
	spawn_cooldown = 45.0
	incident_time = 0.0
