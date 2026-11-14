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

## Roadmap

Streaming city chunks, navigation and traffic signals; shoot animations, gun recoil and muzzle effects; shop economy; interior object interactions; missions with waypoint arrows; touch sensitivity calibration; Android device profiling.
