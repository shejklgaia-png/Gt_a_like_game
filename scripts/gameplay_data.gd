extends RefCounted
## Common data catalog; new weapons can be configured without changing gameplay code.
static func weapons() -> Array[Dictionary]:
	var data: Array[Dictionary] = [
		{"id":"Handgun","price":0,"damage":25.0,"rate":0.29,"range":50.0,"ammo":180,"magazine":15,"reload":1.2,"spread":1.9,"pellets":1,"auto":false},
		{"id":"Rifle","price":650,"damage":32.0,"rate":0.14,"range":75.0,"ammo":150,"magazine":30,"reload":1.9,"spread":1.0,"pellets":1,"auto":true},
		{"id":"Shotgun","price":450,"damage":88.0,"rate":0.78,"range":24.0,"ammo":45,"magazine":6,"reload":2.1,"spread":7.0,"pellets":8,"auto":false},
		{"id":"Sniper","price":1100,"damage":140.0,"rate":1.20,"range":130.0,"ammo":35,"magazine":5,"reload":2.4,"spread":0.18,"pellets":1,"auto":false},
		{"id":"Machine Gun","price":1500,"damage":18.0,"rate":0.075,"range":66.0,"ammo":350,"magazine":70,"reload":3.0,"spread":3.1,"pellets":1,"auto":true}
	]
	return data

static func delivery_sites() -> Array[Vector3]:
	return [
		Vector3(-29.7,0.2,-65.3),
		Vector3(78.3,0.2,-29.3),
		Vector3(-65.7,0.2,78.3),
		Vector3(42.3,0.2,42.4),
		Vector3(-29.7,0.2,78.3),
		Vector3(78.3,0.2,78.3),
		Vector3(-65.7,0.2,-29.3),
		Vector3(6.3,0.2,-65.7)
	]

static func mission_reward(distance: float, difficulty: int) -> int:
	return maxi(125, int(120.0 + distance * 1.45) + difficulty * 95)

static func mission_time(distance: float) -> float:
	return maxf(50.0, distance / 4.0 + 32.0)


## Alternating courier contracts make the existing delivery loop less repetitive.
## Contracts are derived from completed jobs, so older save files remain valid.
static func delivery_contract(completed: int) -> Dictionary:
	var contracts: Array[Dictionary] = [
		{"title": "LOCAL COURIER", "reward_scale": 1.0, "time_scale": 1.0},
		{"title": "EXPRESS RUN", "reward_scale": 1.4, "time_scale": 0.84},
		{"title": "DISTRICT TRANSFER", "reward_scale": 1.25, "time_scale": 1.05},
		{"title": "SPECIAL ORDER", "reward_scale": 1.6, "time_scale": 0.90}
	]
	return contracts[posmod(maxi(0, completed), contracts.size())].duplicate()
