# Pocket District — autonomous development plan (2026-11-18)

Owner: Pocket District autonomous-development task. Target: `shejklgaia-png/Gt_a_like_game` only. **Never modify the SERA repository.**

## A. Source baseline (2026-11-18)

Reviewed `main` at `c34433dbdec8b006ce4cb7bc88b51de20321fc6c` and key scene/gameplay/AI/tests.
- Procedural urban prototype: 36 lots, 46 pedestrians, 18 NPC vehicles; 6 district themes, buildings/shops, interior housing, deliveries, shooting and wanted responses, 2,000 authored conversation openings.
- New perimeter drive loop and high expressway exceed the legacy saved-player-position bounds (`abs(x,z) < 120`), making position persistence inconsistent.
- HUD waypoint chevron was derived from absolute world X/Z, so it could mislead during camera orbit.
- Residents walked at one universal 2.1 m/s, with little idle variation.
- Existing pedestrians intentionally ignore crowd collision layers, to prevent previous crosswalk deadlocks. Avoid re-enabling those collisions without a robust avoidance solution.
- Existing CI already executes headless Godot 4.4.1 and 4.7.2 smoke/simulation/district/Android/stability scripts; no editor or Android device was available in this one-off working environment.

## B. External research: verified discussions and engine guidance (2026-11-18)

Player comments below are *individual experiences*, not a statistically representative audience sample; avoid copying other games' copyrighted content.
- [What makes an open world actually feel alive?](https://www.reddit.com/r/videogames/comments/1whgo5z/what_makes_an_open_world_actually_feel_alive/): contributors prioritize believable NPC routines, local detail and environmental storytelling, not area size.
- [Open world games where NPCs do their own thing](https://www.reddit.com/r/gamingsuggestions/comments/15y66ze/open_world_games_where_npcs_kinda_just_do_their/): desire for enterable spaces and visible independent routine.
- [Games where every NPC has a life and schedule](https://www.reddit.com/r/gamingsuggestions/comments/cu4edd): a concrete player request for NPC identities and continuity.
- [How to get a player hooked in an open world](https://www.reddit.com/r/gamedesign/comments/1e0mv2l): early-session clarity and social interactions matter to the design question.
- [Official Godot 4 3D performance optimization](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html): render batching, visibility ranges and material costs require measurement; Compatibility renderer has feature limitations.
- [Official Godot GPU optimization](https://docs.godotengine.org/en/4.3/tutorials/performance/gpu_optimization.html): profile on target mobile GPU; minimize transparency/fill-rate cost.

Inference for this project: improve *interactive density, direction, local encounters and legible feedback* before multiplying static buildings. These are hypotheses to validate through playtests, not proven causal effects.

## C. Roadmap, impact / effort / regression risk

| Priority | Feature | Value | Cost | Risk | Next verification |
|---|---|---|---|---|---|
| P0 | Preserve world position on perimeter and highway | High | Low | Low | Save/load round-trip for x=128 and elevated z=137 |
| P0 | Avoid pedestrian/vehicle crosswalk stalls | High | High | High | Long multi-agent test with waiting/replanning counters |
| P1 | Camera-relative marker arrows | High | Low | Low | Compass tests from camera basis |
| P1 | Resident walking rhythm variety and small idle pauses | Medium | Low | Low-Medium | Seeded-speed diversity and sidewalk bounds |
| P1 | First-session onboarding: landmark, first job, shop/home affordances | High | Medium | Medium | User journey smoke flow |
| P1 | Better driving/parking feedback and traffic collision recovery | High | High | Medium | Highway traversal plus collision test |
| P2 | Short optional events: courier, local encounter, business errand | High | Medium | Medium | Mission start/reward/retry/save integration |
| P2 | NPC destination routines (work/shop/home), no generic filler dialogue | High | High | High | Deterministic schedules and crowd density |
| P2 | Individual buildings with intentional interior micro-events | High | Medium | Medium | Entry/exit, citizen spawn, no softlock |
| P3 | Streaming and inexpensive distant crowd impostors | High | High | High | Android profiling: frame time/VRAM/thermal |
| P3 | Visual continuity and audio feedback across districts | Medium | Medium | Medium | Screenshot comparisons and mobile legibility |

## D. Cycle 1 implementation (one-off 01:00 → 03:00 → 05:00 rehearsal)

- Analysis: identified source-rooted save/load and camera waypoint defects; prioritized low-regression fixes with tests.
- Implementation: expanded coordinate bounds to match city ground/perimeter/freeway (without accepting points beyond the map), projected the 8-way destination arrow onto camera right/up, assigned deterministic varied resident walking speeds and occasional non-crosswalk pauses.
- Verification: added explicit regression assertions to existing headless smoke and simulation scripts. The prior 3-pass improvement reached main in commit `fbc3cdfa736db43e05d3de32fed14736418ecda7` after headless Godot 4.4.1/4.7.2 and Android build CI passed. A real Android playtest remains outstanding.

### Safety and release rules
1. Keep new and unverified changes on a development branch pending CI; do not imply untested changes are merged.
2. Preserve `main` and existing saves. No third-party GTA assets or licensed content.
3. Never re-enable person-person physical blocking without proving that sidewalks/crosswalks remain traversable.
4. Run Godot import, smoke, simulation, Android startup, stability, district tests in CI.
5. Follow up with a focused Android run: enter a perimeter car, drive onto elevated road, save/load, inspect UI compass while orbiting, watch people at crossings.
6. If CI fails, fix the failing code first; otherwise open merge review.

## E. Next cycle
1. Verify actual GitHub Actions results, repair any type or import regressions.
2. Build short, optional neighborhood errand micro-missions that re-use the existing commerce and delivery state without forcing the player into a single career loop.
3. Instrument pedestrians: mean stuck time, crosswalk crossing time, near-collision count and citizen-movement latency (actual phone profiling required).
4. Add high-contrast contextual interaction hints and a lightweight nearby-activity cue.

## F. Ten-pass development rehearsal (2026-11-18)

Target base: `fbc3cdfa736db43e05d3de32fed14736418ecda7`.
Work branch: `autodev/2026-11-18-ten-pass-expansion`. Each pass is one *local project-development iteration*, not a separate scheduled automation invocation.

| Pass | Concrete result |
|---:|---|
| 01 | Retain downloadable Web export ZIP in CI even when GitHub Pages is not enabled. |
| 02 | Add four data-driven courier contracts indexed by completed deliveries. |
| 03 | Different contract clocks and base payouts; no migration needed for prior saves. |
| 04 | 20% clean-run cash bonus when a parcel is delivered with zero wanted stars. |
| 05 | HUD contract title, ground-distance arrow, deadline warning color. |
| 06 | Non-modal first-job instructional hints, without disabling free roaming. |
| 07 | Give an immediately adjacent parcel interaction precedence over a storefront/NPC. |
| 08 | Different per-car cruise speeds for the grid and scenic highway. |
| 09 | Vehicle headway control: 3 forward rays measure closest obstacle and smoothly adjust target cruise speed. |
| 10 | Expand Godot headless regression tests (courier progression, clean bonus, arrows, parcel/door priority, traffic sensor and pace). |

### Known publishing blocker

On the previous main commit, Web export was successful but `actions/configure-pages@v5` failed with "Get Pages site failed: Not Found". Repository Settings > Pages must be enabled and set to **GitHub Actions** by an administrator. The new `actions/upload-artifact@v4` step makes the generated website downloadable from CI even if Pages remains unavailable. Do not claim a published URL until deployment itself passes.

### Release checklist

- Run GitHub Actions Godot 4.4.1 / 4.7.2 import, smoke, simulation, district, Android startup and sustained-play tests.
- Check Android APK export; Web export artifact should be uploaded before Pages setup.
- On real Android phone: verify the first parcel remains visible and collectible, driving input, alley/curb safety, police pursuit, indoor merchant dialogue, and performance at rush-hour.
- Watch long-term vehicle following for headway stability and unintended stops. If stalls are detected, increase temporal smoothing or cap waiting/replanning time.
- No use of third-party commercial IP assets. Do not modify SERA.

## G. City-life expansion milestone — 2026-11-18

See [CITY_LIFE_MILESTONE.md](CITY_LIFE_MILESTONE.md). The following have been developed on PR #10 and require green CI before being regarded as released:

- 46 outdoor citizens keep their stable identities but now seek business-linked shopping/work/home/dining stops; crosswalk signals and nonblocking lane behavior remain.
- A separate 2-stop neighborhood task board cycles between local surveys, food checks and nightlife inspections, each with distinct reward and persistent progress.
- A new legal CITY GARAGE allows the purchase/recall of an owned car (no automatic carjacking wanted stars), with persistent last position and direction.
- Map and contextual HUD distinguish legitimate work, private transport and original courier gameplay.
- Fixed a pre-existing aliasing corruption: `show_commerce` now deep-copies incoming lot data so `close_commerce().clear()` cannot erase records inside `city.buildings`. This error was reproducible in the Godot CI log but previously allowed the run to pass; the new test script is now guarded against silent GDScript `SCRIPT ERROR` output.

Next after CI acceptance:
1. Real-device walkthrough of garage parking, owned car recall and both concurrent quest types. Verify input zones and HUD text never obscure the vehicle/mission controls.
2. NPC *time-scheduled* enter/leave buildings rather than stop-only routines, respecting collision clearances, memory caps and signal phases.
3. Dynamic ambient incidents that generate consequences and new optional short tasks.
4. Repeatable diverse economy and job progression that does not reward automatic wanted escalation.
