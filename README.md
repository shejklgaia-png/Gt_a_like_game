# Pocket District — 3D mobile open-world sandbox

A **Godot 4** project: a portrait, single-thumb-friendly, procedural 3D city sandbox inspired by open-world crime games. All models are generated with native Godot primitives; there are no third-party art assets.

## Play

1. Install **Godot 4.3 or later** (Godot 4.4/4.5 recommended).
2. Import `project.godot` with the Godot project manager.
3. Run the project (F6/F5). On Android, configure Android export in the Godot editor and export the game.
4. Start next to a gun shop. Find the glowing package marker at the downtown intersection to begin deliveries.

### Mobile (portrait)

- **Drag the circular pad** at the bottom right to walk. Drag up to move forward.
- **SPRINT** toggles running / faster driving. You can keep running after removing your finger.
- **ACTION** interacts with nearby cars, doors, the gun shop, and delivery markers.
- **FIRE** fires the equipped weapon. Holding it provides automatic fire at the selected weapon's cadence.
- **WEAPON** cycles through purchased firearms.
- The aiming helper prefers nearby characters near the player's facing direction. It will not hit actors through solid buildings.

### Desktop testing

- WASD or arrow keys: move / drive / steer.
- Shift: sprint / speed boost.
- Space: fire.
- E/F: interact.
- Q/Tab: next weapon.
- R: toggle sprint.

## Gameplay systems

| System | Current prototype |
| --- | --- |
| Outdoor city | Grid of roads, sidewalks, neon entrances, building facades, streetlamps |
| Traffic | AI cars cruising along roads; takeover and arcade driving |
| Pedestrians | Wandering NPCs with health and hit reactions |
| Weapons | Handgun starter; rifle, shotgun, sniper, and machine gun for sale |
| Gun shop | One downtown shop with a buy / restock menu |
| Delivery | Repeating pickup and delivery route, earning $360 per completed job |
| Wanted | Five-star wanted meter, crimes attract chasing police, wanted level decays |
| Interiors | Deterministic random room plans per building; serialized to user storage |
| Separate rendering | Hides/disables outdoor scene while inside, with dark-gray clear color |
| Save data | Cash, weapons, ammunition, deliveries and generated layouts |

## Scope and limitations

This is a **playable prototype**, not a content-complete GTA clone. Cars use simplified arcade physics rather than suspension/vehicle-wheel simulation. Police and pedestrians use direct steering rather than baked navmeshes. Buildings have simple generated room layouts, not multi-story procedural architecture. Guns use line-of-sight assisted hitscan, not animated gun meshes. There are no bespoke 3D assets or sound effects yet.

## Structure

- `scenes/main.tscn` — starting scene.
- `scripts/main.gd` — world state, missions, gun shop, wanted, controls, HUD, save/load.
- `scripts/city.gd` — roads, buildings, traffic and civilian placement.
- `scripts/vehicle.gd` — traffic and drivable cars.
- `scripts/actor.gd` — pedestrian and police actors.
- `scripts/hero.gd` — playable character.
- `scripts/interior.gd` — room generator and building-specific layout.
- `scripts/shape_factory.gd` — procedural geometry helpers.
- `scripts/smoke_test.gd` — headless Godot smoke tests.

Saved data is stored by Godot under `user://pocket_district_save.json`. This file is not in the Git repository. Reinstalling or clearing app data can delete the save.


## Neighborhood conversations — 2,000 authored variations (25 genres)

- The game now contains **200 individually written subjects** with their own concrete opening observation, detail, counterpoint and yes/no question, grouped into **25 genres of 8 subjects each**.
- Every subject has **10 distinct dialogue approaches** (recent interest, memory, discovery, street conversation, unexpected angle, walk reflection, imagination, long discussion, differing tastes, and small discovery), giving **exactly 2,000 authored-context scenarios** before the additional player-choice branching.
- Each resident traverses all 2,000 scenarios in a resident-specific deterministic permutation with **no repeats until that resident has seen all 2,000**. Resident identity, conversation count and friendship remain persistent across saves.
- Four-level dialogue branches have topic-appropriate agreement, detail, respectful disagreement, yes/no follow-up, personal answer and endings. Each generated graph is acyclic, has only valid options, and reaches an ending. Variation does not rely on external generative AI.
- The smoke test enumerates the entire 2,000-scenario permutation, validates each dialogue graph, verifies 25 genre categories, and exercises resident selection and saved relationship changes.

### Talking with residents

- Walk near a civilian to see **ACTION: 話す**. Press **ACTION** (mobile) or **E/F** (desktop) to talk. Building entrances take priority when you are right at the door.
- Pick one of the displayed replies using the touch buttons or desktop keys **1–4**. Tap **会話を終える** (or press **E/F/Esc**) to leave.
- Each of the 46 civilian slots gets a persistent Japanese name, deterministic personality seed, preferred genre, conversation visit count and friendship/affinity score.
- The first interaction introduces the resident; later chats vary the scenario, branch order and number of initial branches. Responses are tied to the current topic and only point to valid successor nodes; there is no free-form text generation or unpredictable LLM dependency.
- Civilians pause walking and turn toward the player during a conversation. Attacks, panic, wanted status, moving out of range and player injury/death end the interaction safely.
- Relationships are saved as the optional \`residents\` object in \`user://pocket_district_save.json\`; older saves continue to load.
- The headless smoke test validates every civilian's conversation graph and checks an actual dialogue path plus relationship persistence.

## Roadmap

Streaming city chunks, navigation and traffic signals; shoot animations, gun recoil and muzzle effects; shop economy; interior object interactions; missions with waypoint arrows; touch sensitivity calibration; Android device profiling.

## Android APK (automated)

Push to `main` to start the **Build Android APK** GitHub Actions workflow. It runs an engine smoke test, creates an ARM64 debug-signed `PocketDistrict-debug.apk`, and attaches it to the run as an artifact. Successful builds from `main` also publish the APK in the [Pocket District Preview release](https://github.com/shejklgaia-png/Gt_a_like_game/releases/tag/pocket-district-preview).

The build uses Godot 4.4.1 and includes the existing web export preset unchanged. Android packages are preview/debug signed and intended for manual installation, not Google Play distribution.

## Movement, camera and combat update

- **Closer overhead camera**: default 64° pitch, 9.1 m camera arm; dynamically shortens when a building blocks the view.
- **Orbit on a phone**: swipe over the **upper scene area** to rotate yaw and adjust pitch (42°–78°); drag the bottom-right pad to walk. Use one thumb sequentially. On desktop, hold right mouse button while dragging.
- **Weapon-specific firing**: pistol, automatic rifle, pump shotgun (8 pellets), sniper rifle and machine gun now use distinct procedural models, muzzle flashes, appropriate shot spread, hitscan collisions, impact particles and floating damage numbers.
- **Characters**: visible gait via joint animation, hurt reactions, a collapsing death animation, and delayed respawn for the player. Police swing batons with a timed contact frame.
- **Car theft**: pedestrians and AI vehicles stop for people in the lane; taking a vehicle opens its door and plays a reach/entry animation before driving.
- **Pedestrians**: movement stays aligned with sidewalks, while occasional inter-block crossings remain on painted zebra-crossing corridors.

**Status:** experimental preview; smoke tests check scene initialization and key component states, but do not replace Android device testing. Vehicle braking uses forward raycasts and is not yet a full traffic simulation; walking/death/carjacking are procedural rig motions rather than motion-captured animations.

## v0.2.1 — sidewalk and pedestrian navigation fix

- Raised sidewalks are visual only; the street and pavements now share one flat physical ground surface, eliminating the step that blocked the player.
- Nonblocking pedestrian collision masks prevent same-route crowd and vehicle gridlocks while retaining hitscan target detection and vehicle braking.
- Opposing pedestrians use separate passing lanes within the sidewalk and marked zebra-crossing width.
- After 1.8 seconds without route progress, pedestrians automatically pick another legal sidewalk waypoint.
- Automated smoke tests check real player movement across the curb, sidewalk geometry, character collision layers and stuck-route recovery.

## v0.3.0 — city-systems expansion (partial 112-item implementation)

Features now included in the prototype:
- Synced 28-second traffic signals shared by cars, pedestrian crossing checks and generated traffic-light models.
- Police A* route grid around buildings, sight-line memory, crosswalk route segments, temporary civilian panic and population replenishment.
- Synthesized, royalty-free background loop, street sounds, gunshot, engine, police tone, footstep, impact, UI, death and reward effects.
- Improved firearm hit scanning with occlusion, head/limb multipliers, range falloff, distinct magazines, reserve ammo, automatic reload and scope.
- Generated trees, benches, refuse bins, hydrants, window and lane-strip GPU instancing and cached meshes/materials.
- Updated HUD with crosshair, minimap, reload/scope controls, pause/settings, FPS monitor and more reachable portrait controls.
- Timed delivery goals and rewards, saved mission progress, collectible once-only interior caches and backup-safe save data.
- Camera obstruction checks, cinematic vehicle camera following and car-exit safety checks.
- Two CI test suites: boot interaction smoke and autonomous simulation, required before APK export.

**Important:** This is a considerable expansion but is **not a complete 112/112 implementation**. The exact item-by-item status is [ROADMAP_112.md](ROADMAP_112.md). Larger remaining features include intersecting turn traffic, pedestrian avoidance instead of passing through, district streaming, richer motion rigs, nontrivial content, and full Android device tests.

The assets listed above are all constructed procedurally and use no third-party license-dependent binaries.

## v0.3.1 — streetscape clearance and overhead-camera update

- Benches, bins, trees and hydrants now sit beside **mid-block side facades**, not
  intersection corners. The entire physical footprint must clear both pedestrian
  walking lanes. Benches face their adjacent building, and retain walkable space
  in front of the seat.
- Street lamps moved away from crossing entrances and pedestrian stop lines.
- Buildings now use distinct, lively color palettes across city blocks; each lot
  also receives a colorful pastel sidewalk. Roads retain a darker asphalt tone.
- On-foot camera keeps the player centered from a stable **69-degree overhead
  angle**, increases its distance from **9.1m to 16.5m**, and smoothly returns to
  the fixed view after a manual swipe. The camera still avoids obstructing walls;
  driving retains its heading-follow camera.
- Street-prop clearance, bench orientation, district color variety and camera
  recentering are covered by an automated autonomous-scene regression test.

This remains a prototype. Physical Android device testing is needed in addition
to CI headless tests.


## Android editor: game subprocess stops without a script error

If the Android Godot editor prints `--- Debugging process stopped ---` after a few
seconds but remains open, the game subprocess may have been closed by Android;
that message **does not, by itself, identify a script error**. Godot's Android
editor has a documented crash related to embedded game windows:

1. In Godot, open the **Game** workspace at the top, set **Game Embed Mode**
   to **Disabled**, and run the game again.
2. In Android Developer Options, ensure **Don't keep activities** is OFF.
3. Compare with the **standalone Android APK** from the preview release. If the
   APK works while editor Play closes, investigate the editor / Android window
   lifecycle rather than treating it as a game script crash.
4. On Android, the game writes a lightweight 5-second diagnostic snapshot to
   `user://pocket_district_last_session.json` with runtime, memory monitor,
   node count, and renderer draw calls. If the previous run did not close
   normally, the next launch displays its last known seconds / memory / nodes
   for 12 seconds and prints the snapshot to Output.
5. Note: GitHub's automated headless stress tests validate the game logic but
   **cannot prove that an Android phone's native renderer won't crash**.

Reported upstream: https://github.com/godotengine/godot/issues/109485
Godot Android-editor caveats:
https://docs.godotengine.org/en/stable/tutorials/editor/using_the_android_editor.html

