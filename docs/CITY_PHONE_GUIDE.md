# CITY PHONE: getting to jobs and systems

## Why

The procedural city has multiple systems (timed courier contracts, neighborhood inspections, 36 shops/buildings, the garage, houses and furniture, residents and cash caches). Previously some only appeared when the player accidentally approached the correct lot. CITY PHONE gives all these systems one predictable discovery path without teleportation or remote interaction.

## On mobile

1. Tap **CITY** beside the pause button at the top right. On keyboard, press **B**.
2. Pick one of five tabs: **仕事 (Jobs)**, **店舗 (Stores)**, **住居 (Homes)**, **車両 (Vehicles)**, **情報 (Info / Exploration)**.
3. Tap any relevant destination. The phone closes, time resumes, and **GPS: target + arrow + distance** appears below the courier banner.
4. On the compact minimap, follow the **teal destination marker/line**. If the target is farther than the minimap's extent, its marker appears at the edge in the correct direction. The courier package remains visibly golden.
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
- The map gives bearing and distance, **not** full turn-by-turn road routing. Walking across intersections and driving still use normal gameplay controls.

## Implementation and QA

- `scripts/city_phone.gd` dynamically reads the live city services and exposes a modal, scrollable five-tab menu. Menus pause simulation and prevent accidental joystick/camera actions.
- `scripts/main.gd` owns persistent GPS state, dynamic destination resolution, input routing and the HUD banner.
- `scripts/minimap.gd` renders the offscreen-aware route marker and directional ray.
- `scripts/city_phone_test.gd` covers tab availability, touch button, modal state, nonteleport navigation, changing job waypoints, moving owned car targets, facility/caches, clearing/reloading route state; runs in the Godot 4.4.1 and 4.7.2 CI matrix.
- Android real-device tap targets, screen-reader use, UI scaling below 360px, driving readability and route usability remain to be playtested.

No SERA changes.
