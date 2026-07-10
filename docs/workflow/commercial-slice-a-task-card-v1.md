# Level Task Card

**Task Name**
- `Commercial Slice A - Whitebox Rebuild V1`

**Stage**
- Whitebox

**What This Iteration Must Solve**
- Isolate the map-specific whitebox generation from the shared runtime used by other arenas.
- Rebuild the map into a larger multi-island arena with medium connectivity.
- Ensure every primary lane reconnects without creating dead-end routes.
- Preserve clear ring-out spaces between islands so knockback finishes remain central.

**What This Iteration Explicitly Will Not Do**
- Final art dressing or dense prop placement.
- Final lighting or polish-only camera tuning.
- Asymmetrical layout experiments or advanced height layering.

**Success Criteria**
- The map has one central island, four side islands, four main bridges, and four riskier secondary links.
- Spawn areas provide two exits and do not dump players directly into a single choke.
- The arena plays larger than the current version while keeping movement readable.

**Verification**
- Manual checks: walk route loops, inspect bridge risk, inspect spawn exits.
- Checklist file: `docs/workflow/commercial-slice-a-validation-v1.md`
- Notes: This iteration is approved only if the whitebox is fun while still looking plain.
