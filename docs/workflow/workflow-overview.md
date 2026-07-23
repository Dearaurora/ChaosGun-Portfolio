# Workflow Overview

This project uses a lightweight production workflow designed for a small team building a combat-focused game prototype that is gradually turning into a polished vertical slice.

The goal is not to add heavy process. The goal is to stop mixing design, whitebox, art dressing, and polish into one messy pass.

For the complete concept-to-Demo workflow, including cost controls, release gates, and a reusable Definition of Done, see [`game-demo-production-workflow.md`](game-demo-production-workflow.md).

## Core Principle

Each iteration should solve one class of problems at a time.

- Goal Definition decides what this pass is for.
- Whitebox proves layout, combat flow, and danger space.
- Graybox proves readability, cover logic, and camera framing.
- Dressing adds atmosphere and presentation without harming gameplay.
- Polish tightens feel and presentation after the structure is already correct.

If a later stage reveals a structural failure, the work should move backward to the earlier stage instead of hiding the problem with surface changes.

## Required Files Per Meaningful Map Iteration

Every map iteration should create or update these three files:

1. A task card
   - Scope for the current pass
   - What this pass must solve
   - What this pass must not do

2. A map spec
   - Target experience
   - Layout rules
   - Size rules
   - Forbidden patterns
   - Pass criteria

3. A validation checklist
   - Connectivity
   - Fall risk
   - Spawn safety and tempo
   - Readability
   - Combat value
   - Resource spawn validity

When a pass is about pacing, feel, or showcase readiness, add a fourth file:

4. A live-play checklist
   - Opening tempo
   - Route value
   - Ring-out feel
   - Pickup pressure
   - Spawn safety in real hands-on play
   - Notes for the next pass

## Normal Iteration Order

1. Write or update the task card.
2. Write or update the map spec.
3. Build the stage target for the current pass.
4. Run the validation checklist.
5. If the pass depends on gameplay feel, run or prepare the live-play checklist.
6. Record what worked, what failed, and what the next pass should target.

## Anti-Patterns

Do not do these:

- Add final props during whitebox.
- Tune lighting before layout is stable.
- Treat readability issues as art problems when the actual issue is route structure.
- Keep polishing a map that fails connectivity or spawn tests.
- Expand scope in the middle of a pass without updating the task card.

## Recommended Directory Usage

- Templates live in `docs/workflow/`
- Active iteration cards and specs can live beside the templates while the project is small
- If the project grows, split into:
  - `docs/workflow/templates/`
  - `docs/workflow/maps/<map-name>/`

## Working Rule

The map should be fun before it is pretty.
The map should be readable before it is atmospheric.
The map should be stable before it is content-rich.
