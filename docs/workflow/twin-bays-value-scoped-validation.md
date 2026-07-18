# Twin Bays value-scoped validation policy

This policy prevents development work from defaulting to the most expensive
release runner.

The machine-readable authority is
`resources/validation/twin_bays_verification_policy_v1.json`. The release
runner reads that file and enforces these restrictions:

- A complete run requires both `-ReleaseCandidate` and a non-empty
  `-ReleaseReason`.
- The same release fingerprint may fail at most twice consecutively. A third
  attempt is blocked unless the implementation or validation inputs change.
- An override is explicit and requires `-OverrideRetryLimit` together with
  `-OverrideReason`; it is written to the attempt ledger.
- Golden updates remain available only to a complete, explicitly declared
  release-candidate run.
- Every complete attempt is appended to
  `reports/twin_bays_release_attempts.json`, including failures.

## Required scope before release

| Changed area | Default verification |
| --- | --- |
| Reference or documentation | Reference manifest, SHA and contract only |
| Materials, lighting or background | Rendered captures and human review |
| Layout or collision | Structure, collision, portals and captures |
| Gameplay or map routing | Runtime flow, route and shared-profile tests |
| AI behavior | Runtime flow and AI batch |
| Rendering code or production assets | Captures and paired performance |
| Frozen release candidate | One complete release run |

Fix and rerun the smallest failing gate first. The complete runner is not a
debug loop. Environment-only performance failures must be diagnosed before a
retry and do not authorize changes to game content.
