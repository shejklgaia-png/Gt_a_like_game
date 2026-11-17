extends RefCounted
const Furniture = preload("res://scripts/furniture_catalog.gd")

static func items(business: String) -> Array[Dictionary]:
	match business:
		"supermarket":
			return [
				{"id": "groceries", "name": "食料品セット（HP +35）", "price": 55, "heal": 35},
				{"id": "fresh", "name": "生鮮食品（HP +50）", "price": 90, "heal": 50}
			]
		"convenience":
			return [
				{"id": "snack", "name": "軽食（HP +15）", "price": 25, "heal": 15},
				{"id": "drink", "name": "飲み物（HP +10）", "price": 15, "heal": 10}
			]
		"market":
			return [
				{"id": "fruit", "name": "青果（HP +25）", "price": 35, "heal": 25},
				{"id": "meal", "name": "屋台料理（HP +40）", "price": 65, "heal": 40}
			]
		"restaurant":
			return [{"id": "dinner", "name": "料理（HP +65）", "price": 120, "heal": 65}]
		"clothing":
			return [
				{"id": "blue", "name": "ブルーのジャケット", "price": 160, "outfit": "#4965ae"},
				{"id": "red", "name": "レッドのジャケット", "price": 160, "outfit": "#b65756"},
				{"id": "olive", "name": "オリーブのジャケット", "price": 160, "outfit": "#729079"}
			]
		"furniture":
			var result: Array[Dictionary] = []
			for item in Furniture.STOCK:
				result.append({"id": String(item["id"]), "name": String(item["name"]), "price": int(item["price"]), "furniture": true})
			return result
		_:
			return []


static func is_retail(business: String) -> bool:
	return business in ["supermarket", "convenience", "market", "restaurant", "clothing", "furniture"]
