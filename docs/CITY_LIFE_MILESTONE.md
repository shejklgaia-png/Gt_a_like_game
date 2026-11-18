# Pocket District — City Life Milestone (2026-11-18)

## Goals

Turn a purely courier-focused procedural map into a legible place where the player can work for different reasons and travel legally. Preserve all previous player data and keep the older hands-free traffic routes safe.

## Playable additions

1. **Resident daily purposes.** Each of the 46 residents has a deterministic purpose: shopping, employment, going home, or dining. Their sidewalk destinations come from nearby real storefronts, with deliberate short visits rather than random walking alone. The existing single-axis sidewalk corridors and signal-controlled crosswalks remain unchanged. Colored badges distinguish roles at glance; approaching a resident shows their purpose in the interaction hint. This is a *prototype of errands*, not a full clock-based schedule or interior entry.
2. **Three optional neighborhood jobs.** Look for a blue **JOBS** board by the office. Press ACTION to accept a two-stop assignment. The cyan minimap marker leads to the current inspection site. Tasks cycle: STREET SURVEY ($220), MARKET INSPECTION ($270), NIGHT DISTRICT CHECK ($320). They are separate from timed parcel deliveries, and there are no kill objectives. One payment per completed job; intermediate progress and completed count persist in the existing save.
3. **Legally owned garage vehicle.** Visit **CITY GARAGE**, pay $1,350 to buy a teal car, and drive without the automatic carjacking wanted-star penalty. The car is kept in the save along with its last position and heading and can be recalled from the garage menu at no cost. The purchased vehicle stays parked rather than using NPC patrol AI. Public NPC cars remain available to hijack (which still raises wanted level).
4. **Minimap clarity.** Garage entrance, privately owned car, side-job board, and current objective are shown with distinct colored symbols.

## Compatibility / constraints

- No old save migration is needed: added fields default to empty and no car ownership.
- The city keeps 36 lots, 46 standard residents, and 18 original NPC traffic vehicles.
- New side jobs share ACTION with other interactions; a nearby active job site takes precedence over the door. Timed courier work continues independently.
- The garage is a new type for a previously generic lot at district grid (0,1).
- Citizen routines stay on their assigned sidewalk axis. Crosswalks are approached and crossed one block at a time under existing traffic signals. No crowd-to-crowd colliders are re-enabled.
- The newly owned car is spawned outside the 18 NPC traffic slots so traffic budgets and identity indices remain unchanged.
- Real mobile device performance, traffic jams during extended play, garage parking usability and indoor visit realism still require hands-on playtesting.

## Automated checks

`scripts/city_life_test.gd` is integrated with the Godot 4.4.1 and 4.7.2 headless smoke workflow and verifies:
- Four distinct resident roles among the existing 46 identities, nearby purpose destinations, and nonblocking pedestrian collision layers.
- Job board availability, job-start interaction, first and second stops, one-time reward and next-job rotation.
- Partial job saving and full restore after reload.
- Garage purchase option and purchase price, physically spawned owned car, entering without wanted stars, safe exit and persisted vehicle ownership/location.
- All older smoke, traffic, interior, conversation, 100-scenario, Android-startup and sustained-play suites continue to run.

## Follow-up implementation candidates

- Actual commute schedules with enter/leave building transitions, shops with customers and weather-dependent routines.
- Second-hand vehicles, rentals, owned-garage custom color, repair, respawn after vehicle damage, and legal driving law violations.
- Dynamic local events (lost property, crowds, traffic incidents) that branch from existing social/commerce systems.
- Better shared mission tracker for concurrently active parcel and neighborhood tasks; in-game toggle between targets.
- Real Android touch safe-area validation, performance and control verification on target phone.

No copyrighted GTA assets or texts. SERA is outside scope.
