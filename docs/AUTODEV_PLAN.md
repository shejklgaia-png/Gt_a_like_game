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

## B. External research: player opinions vs verified platform advice

The following Reddit discussions represent *individual opinions, not representative player statistics*. Reviewed 2026-11-18:
- [Cities feel hollow when buildings are static decoration and NPCs are anonymous crowds](https://www.reddit.com/r/gamedev/comments/1j3vz9n/): prefer meaningful locations and interaction affordances.
- [Free-roam exploration is itself an activity](https://www.reddit.com/r/gamingsuggestions/comments/1w7ti3t/): preserve choice to explore without mandatory quest UI.
- [Players like worlds that keep changing without their direct action](https://www.reddit.com/r/gamedesign/comments/1xtgspb/): consider routines/reaction chains, but prioritize deterministic cheap simulations on mobile.
- [Opportunities for progress from independent exploration](https://www.reddit.com/r/gaming/comments/1u54dx4/): short jobs, hidden finds and freedom to ignore them.
- [Official Godot 4 performance guidance](https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html): measure mobile bottlenecks; use effective batching, visibility/distance and LOD techniques instead of unbounded actor count.

These findings suggest *density of interactive outcomes and low-friction discovery*, rather than adding empty square kilometers.

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
- Verification: added explicit regression assertions to existing headless smoke and simulation scripts. **These test assertions are committed but NOT locally executed** because this environment has no Godot executable and no direct network clone. The PR CI must pass before merging.

### Safety and release rules
1. Keep this change on a development branch pending CI; do not imply it is merged.
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
