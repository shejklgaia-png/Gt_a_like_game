# Pocket District: 100-case QA execution ledger

**Scope**: one Godot project development session plus 100 independent parameterized QA scenarios in `scripts/hundred_cycle_test.gd`. This ledger does **not** assert that 100 separate features or 100 separately scheduled automation runs were completed.

**Target base**: `cbd780d9bd449f3d8f14190ddda13db185de5b70` (`main` before this work).

## Implementation delivered in this session

- Repair elevated-road car interaction heights: entering uses vehicle-relative deck level; exiting raycasts for a safe nearby surface and retains its vertical level.
- Add 12 one-time street finds by stable building ID (no collision meshes); cash rewards in the $70–$145 range.
- Store claimed finds in the existing save payload; unclaimed sites appear on minimap; HUD includes completion count.
- Add user-facing proximity interaction prompt; claims are triggered by ACTION, not automatic.
- Extend the existing two-version Godot CI with 100 deterministic, parameterized scenarios.

## Execution matrix

| QA cycle | System | Case input | Acceptance condition |
|---:|---|---|---|
| 001 | Exploration cache placement | Cache slot 1/12 | Unique discoverable ID, visible & nearest only when close |
| 002 | Exploration cache placement | Cache slot 2/12 | Unique discoverable ID, visible & nearest only when close |
| 003 | Exploration cache placement | Cache slot 3/12 | Unique discoverable ID, visible & nearest only when close |
| 004 | Exploration cache placement | Cache slot 4/12 | Unique discoverable ID, visible & nearest only when close |
| 005 | Exploration cache placement | Cache slot 5/12 | Unique discoverable ID, visible & nearest only when close |
| 006 | Exploration cache placement | Cache slot 6/12 | Unique discoverable ID, visible & nearest only when close |
| 007 | Exploration cache placement | Cache slot 7/12 | Unique discoverable ID, visible & nearest only when close |
| 008 | Exploration cache placement | Cache slot 8/12 | Unique discoverable ID, visible & nearest only when close |
| 009 | Exploration cache placement | Cache slot 9/12 | Unique discoverable ID, visible & nearest only when close |
| 010 | Exploration cache placement | Cache slot 10/12 | Unique discoverable ID, visible & nearest only when close |
| 011 | Courier contracts | Completed deliveries 0 | Positive reward and available time across differing distance |
| 012 | Courier contracts | Completed deliveries 1 | Positive reward and available time across differing distance |
| 013 | Courier contracts | Completed deliveries 2 | Positive reward and available time across differing distance |
| 014 | Courier contracts | Completed deliveries 3 | Positive reward and available time across differing distance |
| 015 | Courier contracts | Completed deliveries 4 | Positive reward and available time across differing distance |
| 016 | Courier contracts | Completed deliveries 5 | Positive reward and available time across differing distance |
| 017 | Courier contracts | Completed deliveries 6 | Positive reward and available time across differing distance |
| 018 | Courier contracts | Completed deliveries 7 | Positive reward and available time across differing distance |
| 019 | Courier contracts | Completed deliveries 8 | Positive reward and available time across differing distance |
| 020 | Courier contracts | Completed deliveries 9 | Positive reward and available time across differing distance |
| 021 | Accessible storefront entrances | Building index 0 | Facade-side reachable entry and recognized business |
| 022 | Accessible storefront entrances | Building index 3 | Facade-side reachable entry and recognized business |
| 023 | Accessible storefront entrances | Building index 6 | Facade-side reachable entry and recognized business |
| 024 | Accessible storefront entrances | Building index 9 | Facade-side reachable entry and recognized business |
| 025 | Accessible storefront entrances | Building index 12 | Facade-side reachable entry and recognized business |
| 026 | Accessible storefront entrances | Building index 15 | Facade-side reachable entry and recognized business |
| 027 | Accessible storefront entrances | Building index 18 | Facade-side reachable entry and recognized business |
| 028 | Accessible storefront entrances | Building index 21 | Facade-side reachable entry and recognized business |
| 029 | Accessible storefront entrances | Building index 24 | Facade-side reachable entry and recognized business |
| 030 | Accessible storefront entrances | Building index 27 | Facade-side reachable entry and recognized business |
| 031 | Camera-relative arrows | Camera rotation increment 0.08 rad | Projected screen-right and screen-up navigation match camera |
| 032 | Camera-relative arrows | Camera rotation increment 0.16 rad | Projected screen-right and screen-up navigation match camera |
| 033 | Camera-relative arrows | Camera rotation increment 0.24 rad | Projected screen-right and screen-up navigation match camera |
| 034 | Camera-relative arrows | Camera rotation increment 0.32 rad | Projected screen-right and screen-up navigation match camera |
| 035 | Camera-relative arrows | Camera rotation increment 0.4 rad | Projected screen-right and screen-up navigation match camera |
| 036 | Camera-relative arrows | Camera rotation increment 0.48 rad | Projected screen-right and screen-up navigation match camera |
| 037 | Camera-relative arrows | Camera rotation increment 0.56 rad | Projected screen-right and screen-up navigation match camera |
| 038 | Camera-relative arrows | Camera rotation increment 0.64 rad | Projected screen-right and screen-up navigation match camera |
| 039 | Camera-relative arrows | Camera rotation increment 0.72 rad | Projected screen-right and screen-up navigation match camera |
| 040 | Camera-relative arrows | Camera rotation increment 0.8 rad | Projected screen-right and screen-up navigation match camera |
| 041 | Navigation grid | Route target x=-90, z=93 | A* route exists and avoids marked building solids |
| 042 | Navigation grid | Route target x=-72, z=93 | A* route exists and avoids marked building solids |
| 043 | Navigation grid | Route target x=-54, z=93 | A* route exists and avoids marked building solids |
| 044 | Navigation grid | Route target x=-36, z=93 | A* route exists and avoids marked building solids |
| 045 | Navigation grid | Route target x=-18, z=93 | A* route exists and avoids marked building solids |
| 046 | Navigation grid | Route target x=0, z=93 | A* route exists and avoids marked building solids |
| 047 | Navigation grid | Route target x=18, z=93 | A* route exists and avoids marked building solids |
| 048 | Navigation grid | Route target x=36, z=93 | A* route exists and avoids marked building solids |
| 049 | Navigation grid | Route target x=54, z=93 | A* route exists and avoids marked building solids |
| 050 | Navigation grid | Route target x=72, z=93 | A* route exists and avoids marked building solids |
| 051 | Vehicle speed and sensors | Traffic vehicle index 0 | Speed within safe band and occupied-car sensor bypass |
| 052 | Vehicle speed and sensors | Traffic vehicle index 1 | Speed within safe band and occupied-car sensor bypass |
| 053 | Vehicle speed and sensors | Traffic vehicle index 2 | Speed within safe band and occupied-car sensor bypass |
| 054 | Vehicle speed and sensors | Traffic vehicle index 3 | Speed within safe band and occupied-car sensor bypass |
| 055 | Vehicle speed and sensors | Traffic vehicle index 4 | Speed within safe band and occupied-car sensor bypass |
| 056 | Vehicle speed and sensors | Traffic vehicle index 5 | Speed within safe band and occupied-car sensor bypass |
| 057 | Vehicle speed and sensors | Traffic vehicle index 6 | Speed within safe band and occupied-car sensor bypass |
| 058 | Vehicle speed and sensors | Traffic vehicle index 7 | Speed within safe band and occupied-car sensor bypass |
| 059 | Vehicle speed and sensors | Traffic vehicle index 8 | Speed within safe band and occupied-car sensor bypass |
| 060 | Vehicle speed and sensors | Traffic vehicle index 9 | Speed within safe band and occupied-car sensor bypass |
| 061 | Pedestrian safety | Resident index 0 | Unique resident identity, valid walking pace and nonblocking mask |
| 062 | Pedestrian safety | Resident index 1 | Unique resident identity, valid walking pace and nonblocking mask |
| 063 | Pedestrian safety | Resident index 2 | Unique resident identity, valid walking pace and nonblocking mask |
| 064 | Pedestrian safety | Resident index 3 | Unique resident identity, valid walking pace and nonblocking mask |
| 065 | Pedestrian safety | Resident index 4 | Unique resident identity, valid walking pace and nonblocking mask |
| 066 | Pedestrian safety | Resident index 5 | Unique resident identity, valid walking pace and nonblocking mask |
| 067 | Pedestrian safety | Resident index 6 | Unique resident identity, valid walking pace and nonblocking mask |
| 068 | Pedestrian safety | Resident index 7 | Unique resident identity, valid walking pace and nonblocking mask |
| 069 | Pedestrian safety | Resident index 8 | Unique resident identity, valid walking pace and nonblocking mask |
| 070 | Pedestrian safety | Resident index 9 | Unique resident identity, valid walking pace and nonblocking mask |
| 071 | HUD and mission legibility | Courier contract index 0 | HUD shows current correct contract and claim counter |
| 072 | HUD and mission legibility | Courier contract index 1 | HUD shows current correct contract and claim counter |
| 073 | HUD and mission legibility | Courier contract index 2 | HUD shows current correct contract and claim counter |
| 074 | HUD and mission legibility | Courier contract index 3 | HUD shows current correct contract and claim counter |
| 075 | HUD and mission legibility | Courier contract index 4 | HUD shows current correct contract and claim counter |
| 076 | HUD and mission legibility | Courier contract index 5 | HUD shows current correct contract and claim counter |
| 077 | HUD and mission legibility | Courier contract index 6 | HUD shows current correct contract and claim counter |
| 078 | HUD and mission legibility | Courier contract index 7 | HUD shows current correct contract and claim counter |
| 079 | HUD and mission legibility | Courier contract index 8 | HUD shows current correct contract and claim counter |
| 080 | HUD and mission legibility | Courier contract index 9 | HUD shows current correct contract and claim counter |
| 081 | Unique one-time reward | Cache collect slot 1 | One-time collection, bounded cash reward, marker disappears |
| 082 | Unique one-time reward | Cache collect slot 2 | One-time collection, bounded cash reward, marker disappears |
| 083 | Unique one-time reward | Cache collect slot 3 | One-time collection, bounded cash reward, marker disappears |
| 084 | Unique one-time reward | Cache collect slot 4 | One-time collection, bounded cash reward, marker disappears |
| 085 | Unique one-time reward | Cache collect slot 5 | One-time collection, bounded cash reward, marker disappears |
| 086 | Unique one-time reward | Cache collect slot 6 | One-time collection, bounded cash reward, marker disappears |
| 087 | Unique one-time reward | Cache collect slot 7 | One-time collection, bounded cash reward, marker disappears |
| 088 | Unique one-time reward | Cache collect slot 8 | One-time collection, bounded cash reward, marker disappears |
| 089 | Unique one-time reward | Cache collect slot 9 | One-time collection, bounded cash reward, marker disappears |
| 090 | Unique one-time reward | Cache collect slot 10 | One-time collection, bounded cash reward, marker disappears |
| 091 | Save/load fidelity | Saved find id index 0 | Claimed cache remains hidden and counted after save reload |
| 092 | Save/load fidelity | Saved find id index 1 | Claimed cache remains hidden and counted after save reload |
| 093 | Save/load fidelity | Saved find id index 2 | Claimed cache remains hidden and counted after save reload |
| 094 | Save/load fidelity | Saved find id index 3 | Claimed cache remains hidden and counted after save reload |
| 095 | Save/load fidelity | Saved find id index 4 | Claimed cache remains hidden and counted after save reload |
| 096 | Save/load fidelity | Saved find id index 5 | Claimed cache remains hidden and counted after save reload |
| 097 | Save/load fidelity | Saved find id index 6 | Claimed cache remains hidden and counted after save reload |
| 098 | Save/load fidelity | Saved find id index 7 | Claimed cache remains hidden and counted after save reload |
| 099 | Save/load fidelity | Saved find id index 8 | Claimed cache remains hidden and counted after save reload |
| 100 | Save/load fidelity | Saved find id index 9 | Claim remains after save reload; elevated freeway car exit preserves elevation |

## Validation gate

- Godot 4.4.1 and 4.7.2 headless import, existing smoke/simulation/district/Android/stability scripts, and the 100-case QA script must pass before merging.
- APK export is separate from actual Android device input, rendering and thermal profiling; latter remains unverified.
- GitHub Pages deployment still needs repository administrator enablement; preview Web export can still be downloaded from Actions artifacts.

## Independent external evidence considered

- Individual Reddit commenters described wanting NPCs with believable routines and local reactivity; this motivated *useful density* rather than empty map expansion: https://www.reddit.com/r/videogames/comments/1whgo5z/what_makes_an_open_world_actually_feel_alive/
- Others described filler-heavy large open worlds as tiring; optional discoveries should stay short and skippable: https://www.reddit.com/r/gaming/comments/1jy0f9s/are_we_hitting_open_world_fatigue_or_do_players/
- Official Godot mobile 3D advice recommends deliberate visibility/LOD and target-device profiling: https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html

## Next feature-development priorities (not counted as completed)

1. NPC origin/destination routines between stores, jobs and housing that are visually testable and cannot block pedestrian crossings.
2. Multiple classes of optional neighborhood jobs, with consequences and persistence beyond money.
3. Vehicle ownership or rental (clean courier path without carjacking), parking and repaired road-grade entry/exit.
4. Player-led map discovery: district landmarks and fast local recommendations.
5. Street events with lightweight ambient NPC reactions and no copy-paste dialogue.
6. Android gesture conflict and safe-area testing on real devices, including portrait screens.
7. Long-term traffic deadlock monitoring across ring/freeway routes; reduction in CPU overhead.
