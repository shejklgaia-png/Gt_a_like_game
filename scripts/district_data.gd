extends RefCounted
## City zoning and commerce are deterministic by lot. 36 addressable lots remain
## compatible with old saves and resident slot indices.
const LABELS := {
	"office": "オフィス街", "market": "マーケット", "shopping": "繁華街",
	"nightlife": "風俗街", "residential": "住宅街", "central": "中心街"
}
const BUSINESS_NAMES := {
	"gun": "GUN SHOP", "supermarket": "SUPERMARKET", "convenience": "CONVENIENCE",
	"clothing": "FASHION", "furniture": "FURNITURE", "market": "MARKET",
	"office": "OFFICE", "lounge": "NIGHT LOUNGE", "club": "CLUB",
	"restaurant": "DINER", "apartment": "FOR SALE", "general": "ENTER"
}
const DISTRICT_COLORS := {
	"office": Color("#99b2cb"), "market": Color("#d9ae7f"),
	"shopping": Color("#ef9fbc"), "nightlife": Color("#a58de6"),
	"residential": Color("#a9cea3"), "central": Color("#8acfd0")
}
const STORE_TYPES := ["gun", "supermarket", "convenience", "clothing", "furniture", "market", "office", "lounge", "club", "restaurant", "apartment", "general"]

static func district_for(ix: int, iz: int) -> String:
	if ix <= -1 and iz <= -1:
		return "market"
	if ix <= -1 and iz >= 1:
		return "office"
	if ix >= 1 and iz <= -1:
		return "shopping"
	if ix >= 1 and iz >= 1:
		return "nightlife"
	if (ix + iz) % 3 == 0:
		return "residential"
	return "central"


static func business_for(ix: int, iz: int, district: String) -> String:
	if ix == 0 and iz == -1:
		return "gun"
	if ix == -2 and iz == -2:
		return "supermarket"
	if ix == 1 and iz == -2:
		return "convenience"
	if ix == 2 and iz == -2:
		return "clothing"
	if ix == -1 and iz == -2:
		return "furniture"
	if ix == -2 and iz == -1:
		return "market"
	if ix == -2 and iz == 1:
		return "office"
	if ix == 1 and iz == 1:
		return "lounge"
	if ix == 2 and iz == 1:
		return "club"
	if ix == 1 and iz == -1:
		return "restaurant"
	if (ix + iz * 5 + 20) % 4 == 0 or (ix == 0 and iz == 2):
		return "apartment"
	match district:
		"office":
			return "office"
		"market":
			return "market"
		"shopping":
			return "clothing" if (ix + iz) % 2 == 0 else "restaurant"
		"nightlife":
			return "club" if ix % 2 == 0 else "lounge"
		"residential":
			return "apartment"
		_:
			return "convenience" if (ix + iz) % 3 == 0 else "general"


static func home_price(ix: int, iz: int, district: String) -> int:
	var base := 1100 + posmod(ix * 131 + iz * 87, 5) * 270
	if district == "shopping" or district == "nightlife":
		base += 500
	return base


static func alley_for(ix: int, iz: int) -> bool:
	# Buildings are offset to one side of these lots to leave a true traversable
	# service alley. Both ends connect to the existing street network.
	return posmod(ix * 7 + iz * 11, 5) == 0
