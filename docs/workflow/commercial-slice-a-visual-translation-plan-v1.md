# Commercial Slice A Visual Translation Plan V1

**Goal**
- Move `Commercial Slice A` noticeably closer to the supplied soft pastel reference image without changing the current gameplay topology.

**Work Items**
1. Add verifier checks for the target reference-style palette, backdrop, and allowed dressing language.
2. Rebuild the map dressing so it uses only trees, rocks, and foliage.
3. Add a unified visual grass backdrop under the current island layout.
4. Translate the island, bridge, and cover materials into the target pastel palette.
5. Tune map-local lighting and environment so the scene is bright and soft without washing out.
6. Replace the most visible hard-edged wall blocks with softer rounded wall shells.
7. Add soft ground patches to the grass backdrop.
8. Add grouped decorative shell segments around bridge mouths and island rims.
9. Extend grouped decorative shell segments to side-link entries and center-to-side turns.
10. Re-run whitebox verification and a short smoke batch.

**Files**
- Modify: `scripts/maps/commercial_slice_a.gd`
- Modify: `scripts/maps/battle_arena.gd`
- Modify: `scripts/tests/commercial_slice_whitebox_verifier.gd`
- Modify: `docs/workflow/commercial-slice-a-validation-v1.md`
- Modify: `docs/workflow/commercial-slice-a-live-play-v1.md`

**Validation**
- `powershell -File scripts/tests/run_commercial_slice_whitebox_verifier.ps1 -GodotPath <path-to-Godot.exe>`
- `powershell -File scripts/tests/run_commercial_slice_ai_smoke_batch.ps1 -GodotPath <path-to-Godot.exe> -Runs 2`
