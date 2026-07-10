# Stage Gates

This file defines when a map iteration is allowed to move forward and when it must move backward.

## 1. Goal Definition Gate

Before any implementation starts, the task card must answer:

- What this pass is trying to improve
- What this pass will not touch
- What success looks like
- How success will be checked

If those answers are vague, implementation should not start.

## 2. Whitebox Gate

Whitebox is allowed to touch:

- Island layout
- Bridges and gaps
- Spawn positions
- Resource spawn positions
- Route structure
- Combat spacing

Whitebox is not allowed to focus on:

- Final art dressing
- Detailed lighting
- Decorative clutter
- Final presentation polish

Whitebox can move to graybox only if:

- Core routes are connected
- Ring-out space is real and readable
- Spawns have at least two usable exits
- Runtime respawn points stay aligned with the map-specific spawn plan
- Resource spawns land on valid playable surfaces
- No critical zone is functioning as a bunker
- The map is already fun to move through and fight on while still plain

Whitebox pacing changes should not be locked in from one smoke sample alone.

- If a tuning decision is variance-sensitive, use a multi-run smoke batch before deciding the direction.
- If the pass is intended to improve real player feel, prepare a live-play checklist before moving on.

Whitebox must be revisited if:

- Graybox reveals dead routes
- Players cannot rotate out of pressure
- Bridge fights do not create meaningful risk
- The center dominates so hard that side routes lose value

## 3. Graybox Gate

Graybox is allowed to touch:

- Light cover placement
- Low-complexity landmarks
- Camera framing
- Readability shaping

Graybox is not allowed to hide whitebox flaws by:

- Blocking bad routes with props instead of fixing layout
- Forcing interest through clutter
- Using dressing to fake gameplay depth

Graybox can move to dressing only if:

- Players can read center, flank, bridge hierarchy, and danger zones quickly
- Cover supports tempo without creating hard bunker play
- Camera framing supports the intended route reading
- Important combat spaces remain visually open enough to track fights

Graybox must return to whitebox if:

- Readability problems come from layout shape rather than visual treatment
- Cover is required just to make movement functional
- Camera only works from one brittle angle

## 4. Dressing Gate

Dressing is allowed to touch:

- Props
- Boundary framing
- Lighting atmosphere
- Material and palette consistency
- Presentation-focused environment detail

Dressing must obey these rules:

- Never reduce route readability
- Never narrow a route unless the spec is updated
- Never make a lethal edge look safe
- Never make a safe floor look lethal by accident

Dressing can move to polish only if:

- The map mood supports the spec without harming readability
- Props reinforce composition instead of hiding combat
- Bridge mouths and spawn exits remain clear
- Players can still immediately identify danger space

Dressing must return to graybox if:

- Props create line-of-sight confusion
- Atmosphere makes the route hierarchy unclear
- Decorative objects become accidental gameplay blockers

## 5. Polish Gate

Polish is allowed to touch:

- Fine camera tuning
- VFX and presentation emphasis
- Material cleanup
- Small readability accents
- Showcase-oriented finishing work

Polish must not be used to:

- Rescue a weak layout
- Fix a spawn flaw
- Compensate for poor route logic

The pass is complete only if:

- The validation checklist is filled out
- Any required live-play checklist exists and is ready for the next hands-on session
- Effective changes are recorded
- Remaining problems are recorded
- The next priority is named clearly

## Move-Back Rule

If a stage exposes a problem owned by an earlier stage, go backward.

- Layout problems go back to whitebox.
- Readability structure problems go back to graybox.
- Presentation-only issues stay in dressing or polish.

Do not protect bad structure with pretty surface work.
