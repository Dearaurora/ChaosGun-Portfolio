# Game Demo Production Workflow

This is the reusable, cost-aware workflow for turning a game concept into a stable playable demo. It is designed for a solo developer or a very small team using Godot/Unity/Unreal with local tools and optional AI assistance.

The goal is not to maximize content. The goal is to produce one convincing, repeatable player experience with a known scope, measurable gates, and a hard stopping point.

## 0. The operating contract

Every project must define these before implementation:

- **Player promise:** one sentence describing what the player does and why it is fun.
- **Core verb:** the action that must feel good within the first 30 seconds.
- **Win/fail condition:** how a round starts, progresses, ends, and restarts.
- **Demo boundary:** one mode, one camera, one platform target, and the minimum content needed to prove the promise.
- **Evidence:** the screenshot, short recording, or playtest result that will prove each gate.

Use this rule throughout the project:

> One mechanic, one representative space, one complete loop, then polish.

Do not add a second map, online multiplayer, progression, or live-service systems before the first complete loop is fun and restartable.

## 1. Phase map

| Phase | Question answered | Required output | Exit gate |
|---|---|---|---|
| 0. Concept | Is the promise understandable? | One-page concept brief | A stranger can repeat the game loop |
| 1. Risk prototype | Is the central risk fun? | Ugly playable prototype | 5-minute session produces the intended decisions |
| 2. Core loop | Can a player finish and restart a round? | Start → play → win/fail → restart | Three consecutive clean loops |
| 3. Graybox | Does the space support the loop? | One readable graybox arena/level | Routes, camera, danger, and spawns pass checks |
| 4. Vertical slice | Does it look and feel like the intended game? | One representative polished slice | Blind playtest identifies the intended action |
| 5. Demo hardening | Does it work reliably on the target machine? | Validation scripts, fallback assets, packaged build | 3 clean runs, no blocker defects |
| 6. Demo release | Can another person play without help? | Build, README, controls, screenshots/video | Fresh-machine smoke test passes |
| 7. Post-demo | What is worth building next? | Evidence-based backlog | New scope is approved separately |

## 2. Phase 0 — Concept brief (2–4 hours)

Write `docs/concept-brief.md` or an equivalent one-page note containing:

1. Player promise: “The player [verb] to [goal] while [distinctive pressure].”
2. Reference points: no more than three games or visual references.
3. Non-goals: features explicitly excluded from the Demo.
4. Target session length and audience.
5. Technical constraints: engine, input, resolution, platform, and offline/online status.
6. Success evidence: what a reviewer must see in a 60-second clip.

**Cost rule:** use existing engine primitives and temporary assets. Do not commission final art, buy plugins, or build backend infrastructure at this phase.

## 3. Phase 1 — Risk prototype (1–3 days)

Prototype only the highest-risk interaction. Use primitive shapes, placeholder audio, and one test room.

For ChaosGun, the risk prototype is: “Does shooting an opponent off a platform feel better than reducing HP?”

Required checks:

- The player can perform the core verb within 30 seconds.
- The risk/reward decision is visible without explanation.
- The interaction has a clear success and failure signal.
- Restart takes less than 10 seconds.
- A developer can tune the decisive numbers from one data/config location.

**Stop condition:** if the core interaction is not fun with primitive visuals, stop and redesign it. Art cannot repair a weak interaction.

## 4. Phase 2 — Core loop (2–5 days)

Implement the smallest complete loop:

```text
boot → setup → play → feedback → win/fail → result → restart
```

The loop must include:

- input and movement
- the core interaction
- at least one opponent or obstacle
- readable feedback
- a deterministic end condition
- restart without relaunching the editor

Create a small test matrix:

| Test | Pass condition |
|---|---|
| Fresh boot | Main menu or start state appears |
| Start | Playable state loads in target time |
| Core action | Action changes the game state |
| Failure | Player can understand why they failed |
| Victory | Result state names the outcome |
| Restart | A second round starts without stale state |

**Cost rule:** no new content until this matrix passes twice in a row.

## 5. Phase 3 — Graybox and system boundaries (3–7 days)

Build one representative space using plain geometry. Separate responsibilities before adding detail:

- shared combat/player authority
- map-owned layout and hazards
- UI/match state
- data/configuration
- validation and capture scripts

For each map or level, create three files:

- task card: scope and non-goals
- map spec: layout, pacing, forbidden patterns
- validation checklist: structure, spawns, camera, resources, readability

Graybox gate:

- routes and danger zones are readable in a still frame
- every spawn has at least two plausible exits
- resources land on valid playable surfaces
- camera keeps the important action in frame
- a new player can complete a round without developer intervention

If a graybox fails, return to layout. Do not solve topology with props or lighting.

## 6. Phase 4 — Vertical slice (3–10 days)

Only now replace placeholders with a limited visual language:

1. lock palette and camera
2. author one hero environment module
3. author one readable player/character treatment
4. author the core weapon/ability feedback
5. add only props that improve route reading or mood
6. capture the same scene at the target resolutions

Use a visual contract:

- what is gameplay authority
- what is presentation-only
- what must never be copied from concept annotations
- minimum silhouette, contrast, and material requirements

**Content budget:** one polished map, one player-facing mode, one enemy family, and the minimum weapon/ability set needed to demonstrate the promise. Additional content is backlog, not Demo scope.

## 7. Phase 5 — Demo hardening (2–5 days)

Turn a pretty slice into a reliable build:

- run a clean boot/start/restart batch
- run AI or obstacle smoke tests where applicable
- validate all referenced scenes, assets, and input actions
- test the lowest supported resolution
- test missing optional assets with a safe fallback
- capture a deterministic showcase scene
- record known limitations in the README

Recommended evidence files:

```text
reports/demo_boot.png
reports/demo_gameplay.png
reports/demo_result.png
reports/demo_validation.txt
```

If the engine CLI is unavailable, record that limitation explicitly and perform static resource/path checks instead of claiming runtime verification.

## 8. Phase 6 — Demo release package (half day–2 days)

The public package contains only:

- playable build or exact run instructions
- concise README
- controls and objective
- 3–5 final screenshots or a short video
- architecture diagram or module map
- credits and third-party asset licenses
- known limitations and future plan

The public package must not contain:

- API keys, `.env` files, credentials, private endpoints
- customer/user data
- internal planning, pricing, or commercial documents
- unfinished branches or large debug dumps
- personal screenshots or local machine paths

## 9. Cost-control system

Track cost in three buckets rather than only money:

| Bucket | Default cap for a solo Demo | Control |
|---|---:|---|
| Calendar time | 2–4 weeks | Weekly scope freeze and milestone review |
| Paid services/assets | 0–10% of total project budget | Buy only after the prototype gate passes |
| Complexity | One mode, one polished space | Every new system requires deleting or deferring another |

Use this priority order:

1. Fix a blocker that prevents starting, playing, winning, or restarting.
2. Fix a readability issue that makes the core action unclear.
3. Fix a stability or performance issue on the target machine.
4. Improve feedback and feel.
5. Improve visual polish.
6. Add content only if the Demo promise is already proven.

AI and automation are cost-effective for:

- code scaffolding and small refactors
- test generation and log analysis
- placeholder variations and documentation
- deterministic capture scripts

They are not a substitute for:

- deciding the core player promise
- playtesting the feel
- checking visual coherence
- approving final scope

## 10. Stable iteration protocol

Every meaningful change follows this loop:

```text
write scope → make one bounded change → run the smallest relevant gate
→ capture evidence → record result → commit → decide next step
```

Commit rules:

- one reason per commit
- name the gate or milestone in the commit message
- never mix an art rebuild with unrelated gameplay changes
- keep generated outputs separate from source changes where practical
- preserve a known-good Demo tag or branch before risky work

Suggested labels:

```text
demo/0-risk-prototype
demo/1-core-loop
demo/2-graybox
demo/3-vertical-slice
demo/4-release-candidate
```

## 11. Definition of Done for a Demo

A Demo is done when all statements are true:

- A new player understands the goal from the first screen.
- The core verb is available within 30 seconds.
- One complete round can be finished and restarted.
- The intended risk/reward decision happens without developer explanation.
- The camera, UI, feedback, and audio agree about important events.
- A fresh checkout or packaged build starts on the target machine.
- The smallest supported resolution remains playable.
- A validation record exists for boot, play, result, and restart.
- The README states what is implemented and what is intentionally out of scope.
- No secrets or private data are present in current files or reachable Git history.
- Future features are written as a backlog, not silently included in the Demo.

## 12. ChaosGun mapping

The existing ChaosGun work maps cleanly to this process:

- **Risk prototype:** knockback and ring-out instead of HP damage.
- **Core loop:** local setup → arena fight → lives/elimination → victory/restart.
- **Graybox:** Open Ring-Out route, bridge, gap, spawn, and camera validation.
- **Vertical slice:** sunset toy-island art direction, toy-sunset UI, authored character/weapon readability.
- **Hardening:** AI smoke, map verifiers, performance gates, and multi-resolution captures.
- **Demo anchor:** Open Ring-Out RC commit `0f75645`.

The next project should reuse the process and gates, not automatically reuse ChaosGun's full asset or tool scope.
