# Commercial Slice A Live Play

**Map**
- `Commercial Slice A`

**Build / Commit / Date**
- 2026-04-24

**Session Type**
- Pending live play

**Session Goal**
- Validate whether the current whitebox plus two-route pickup pressure feels good in actual hands-on play, not just smoke tests.

## Launch
**Recommended launcher**
- `powershell -File scripts/playtest/launch_commercial_slice_playtest.ps1 -GodotPath <path-to-Godot.exe>`

**What the launcher does**
- Sets the match preset to `1 Human + 3 AI`
- Selects `Commercial Slice A`
- Boots directly into the map without going through menu setup

## Opening Tempo
- [ ] First contact happens fast enough for the target arcade pace.
- [ ] Opening movement gives a clear first decision instead of immediate confusion.
- [ ] Players can intentionally choose center pressure or side rotation.

## Route Value
- [ ] Center route feels valuable without invalidating side routes.
- [ ] Side routes create real resets, flanks, or re-entry options.
- [ ] Bridge mouths create tension without becoming miserable hard stops.

## Ring-Out Pressure
- [ ] Lethal edges feel readable during movement and combat.
- [ ] Ring-out finishes happen often enough to define the map identity.
- [ ] Ring-out pressure feels earned rather than random or cheap.

## Pickup Pressure
- [ ] Weapon pickups are easy to notice during real play.
- [ ] Pickup positions pull players into interesting route decisions.
- [ ] Pickup contests create movement rather than idle camping.

## Spawn Safety
- [ ] Respawns feel recoverable.
- [ ] Spawn exits offer at least two believable choices.
- [ ] Spawned players are pressured, but not instantly trapped.

## Readability
- [ ] Players can quickly tell where the dangerous edges are.
- [ ] Players can read the difference between main routes and riskier routes.
- [ ] Curated props frame the arena without being mistaken for real cover or blockers.
- [ ] The camera stays fixed instead of chasing character movement or falls.
- [ ] The combat camera supports route reading during actual play.

## Visual Direction
- [ ] The map reads as soft, playful, and toy-like rather than grim or whitebox-heavy.
- [ ] Light grass, lavender walls, and warm bridge accents feel coherent in motion.
- [ ] Tree, rock, and foliage dressing improves atmosphere without making the map noisy.
- [ ] Rounded wall shells feel intentional rather than like stretched primitives.
- [ ] Soft ground patches add charm without being mistaken for gameplay zones.
- [ ] Grouped shell segments around bridge mouths and island rims feel like authored scenery rather than pasted-on clutter.

## Overall Feel
- [ ] The map feels larger than a single-room arena.
- [ ] The map produces memorable fights.
- [ ] Players would willingly queue this map again.

## Current Automated Context
**Smoke baseline**
- Two simultaneous live pickups are stable.
- Two pickup route clusters are stable.
- Recent six-run batch smoke summary: `Armed AI avg 1.67`, `Deaths avg 3.17`, `Ring-outs avg 3.17`, `First death avg 6.83s`.

**What live play must answer next**
- Are bridge-mouth pickups actually readable and attractive to a human player?
- Do side-route pickups create useful rotations or feel too far from the real fight?
- Does the map feel skillful, or just hazardous?

## Notes
**What felt strong**
- 

**What felt weak**
- 

**What needs a next pass**
- 
