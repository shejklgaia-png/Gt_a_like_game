# CITY PHONE: getting to jobs and systems

## Why

The procedural city has multiple systems (timed courier contracts, neighborhood inspections, 36 shops/buildings, the garage, houses and furniture, residents and cash caches). Previously some only appeared when the player accidentally approached the correct lot. CITY PHONE gives all these systems one predictable discovery path without teleportation or remote interaction.

## On mobile

1. Tap **CITY** beside the pause button at the top right. On keyboard, press **B**.
2. Pick one of five tabs: **仕事 (Jobs)**, **店舗 (Stores)**, **住居 (Homes)**, **車両 (Vehicles)**, **情報 (Info / Exploration)**.
3. Tap any relevant destination. The phone closes, time resumes, and **GPS: destination + next-route direction + estimated route distance** appears below the courier banner.
4. On the compact minimap, follow the **teal route through open A* map cells and destination marker**. If the target is farther than the minimap's extent, its marker appears at the edge in the correct direction. The courier package remains visibly golden.
5. At the store, car, job board, resident or collectible, press **ACTION** to perform the real interaction. The phone does **not** teleport the player or allow distant item purchases.
6. Reopen CITY to change the target or tap **案内解除** to clear the GPS. Escape, E or B closes the phone on a keyboard.

## Job/feature entry points

| CITY tab | Destination | Required on-site action |
| --- | --- | --- |
| 仕事 | Courier pickup/dropoff, with current contract name and timing | ACTION at gold parcel/delivery point |
| 仕事 | Neighborhood jobs board if idle, current inspection site if active | ACTION to accept/check the next site |
| 店舗 | Weapons, supermarket, convenience, clothing, furniture, market, restaurant, lounge and club | ACTION at the door; buy/enter where supported |
| 住居 | Every previously purchased home plus nearest available listing | ACTION at entrance; purchase/home furnishings in the relevant menu |
| 車両 | CITY GARAGE and the player's owned car, when available | ACTION at garage to purchase/recall or at car to drive |
| 情報 | Nearest uncollected cache and nearest valid resident | ACTION to collect/talk |
| 情報 | View current number of discoveries, equipment types, total earnings | Status only; no remote interaction |
| 情報 | Camera, sound and display settings | Opens the existing pause/settings panel |

## Navigation behavior

- Delivery GPS tracks the next pickup/destination as the contract progresses.
- Neighborhood GPS points first to the job board, then to the active checkpoint and automatically advances to checkpoint two. Once completed, it points back to the board.
- Vehicle and resident GPS tracks their moving world coordinates; facility and discovered-cache GPS point to stable addresses.
- GPS selection is optional; courier and side jobs can continue concurrently without overwriting each other's underlying mission state.
- GPS kind, address and label are stored as optional save fields, preserving compatibility with older saves.
- On foot within the central street grid, GPS now follows a reusable graph of **196 sidewalk nodes** connected along the existing curb-side pavements and across roads **only at mapped intersection crosswalks**. An approaching crossing warns **青で進む** or **赤信号で待機** according to the same shared signal phase used by cars and wandering pedestrians. Red-signal crosswalk spans turn amber on the minimap. The GPS remains advisory and does not prevent the player from stepping into the street.
- In cars, outside the central street grid and on elevated roads, GPS retains the earlier building-blocked two-meter A* grid, so existing car and freeway navigation remains available.
- The HUD points to the next waypoint along the chosen path and shows estimated route distance. Within 3.3m horizontally of the objective the HUD shows **arrival / ACTION**. Paths are recalculated at most once per 1.5 seconds for 12m deviations, or when moving objectives shift more than 3m.
- The central pedestrian map aligns with curb-side corridors and designated intersection crossings, but the route is **not** an automated pedestrian controller. Roads outside the grid, narrow alleys, moving hazards, traffic violations, step-free/ramp accessibility, and spoken street-name navigation are not comprehensively mapped; actual crossing safety requires player judgement. If routing is unavailable, the map retains the older building-aware A* or a direct bearing.

## Implementation and QA

- `scripts/city_phone.gd` dynamically reads the live city services and exposes a modal, scrollable five-tab menu. Menus pause simulation and prevent accidental joystick/camera actions.
- `scripts/main.gd` owns persistent GPS state, dynamic destination resolution, input routing and the HUD banner.
- `scripts/minimap.gd` renders the clipped A* route polyline, offscreen destination marker, and fallback direction.
- `scripts/city_route.gd` retains the general cached A* route using `PocketNavGrid`.
- `scripts/sidewalk_route.gd` builds a fixed, reusable curb-and-crosswalk graph for **ground-level on-foot** navigation. The nearby crossing hint references the same `traffic_rules.gd` phase as simulated cars and pedestrians. No physical collision mesh or NPC behavior is changed.
- **Garage ACTION fix:** touching the real `CITY GARAGE` door now opens its purchase/recall/visit commerce menu; previous direct-call tests did not exercise this entry point.
- `scripts/city_phone_test.gd` covers tab availability, touch button, modal state, nonteleport navigation, changing job waypoints, moving owned car targets, facility/caches, clearing/reloading route state; runs in the Godot 4.4.1 and 4.7.2 CI matrix.
- `scripts/city_route_test.gd` validates 12 building-avoiding routes, real detours, nearby turn guidance, refresh throttling, moving goal re-pathing, route arrival and GPS save/load.
- `scripts/sidewalk_route_test.gd` verifies 12 storefront routes, legitimate pedestrian crosswalk segments, red/green live warnings, 60 stationary-route updates without recomputation, freeway fallback, plus the real ACTION→buy/recall garage interaction.
- Android real-device tap targets, screen-reader use, UI scaling below 360px, driving readability and route usability remain to be playtested.

No SERA changes.
