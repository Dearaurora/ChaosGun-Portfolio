# Commercial Slice A Visual Translation Spec V1

**Map Name**
- `Commercial Slice A`

**Version Goal**
- Keep the current multi-island ring-out gameplay intact while translating the visual language toward the provided soft, toy-like reference image.

**Keep Intact**
- Multi-island layout, bridge connectivity, and lethal gaps
- Fixed camera framing
- Current spawn plan and pickup cadence

**Target Visual Experience**
- The arena should read as bright, soft, playful, and clean at first glance.
- Surfaces should feel like a stylized toy board rather than a dark ritual arena or a grayboxed prototype.
- Decorative detail should support framing and atmosphere without competing with route readability.

**Visual Language**
- Ground surfaces: light yellow-green grass
- Cover and low walls: pastel lavender-blue
- Bridge surfaces: warm muted yellow
- Perimeter dressing: rounded rocks, soft trees, and small foliage clusters only
- Cover silhouettes: rounded toy-like low walls rather than hard rectangular blocks
- Ground detail: sparse soft patches that break up the grass field without adding gameplay noise
- Bridge mouths and island rims: grouped decorative shell segments that suggest a hand-authored toy maze without changing traversal

**Reference Translation Rules**
- Add a unified grass backdrop beneath the islands so the map no longer floats in a mostly empty void.
- Use color and dressing to approximate the reference image rather than copying its planar maze layout.
- Favor large soft color fields and low-noise silhouettes over prop variety.

**Forbidden Visual Patterns**
- No gates, banners, altars, grave props, lamp posts, or other ritual/dojang props
- No heavy fog wash or bright gray overexposure
- No dense decorative clutter near bridge mouths
- No visual dressing that can be mistaken for new hard cover

**Pass Criteria**
- `CommercialSliceBackdrop/GrassField` exists
- Center island reads as light grass, bridges read as warm connectors, and low cover reads as pastel lavender
- Dressing uses only trees, rocks, and foliage families
- Main low-cover shells use softened rounded geometry
- The grass backdrop includes soft ground patches
- Bridge mouths and island rims have grouped decorative shell segments
- The visual pass meets `docs/workflow/commercial-slice-a-art-quality-gate-v1.md`: total score at least 32/40, no category below 3, and Reference Fidelity, Composition, and Geometry Language each at least 4
- A screenshot review note records per-category scores, the largest visual gaps, and a pass/fail decision
- Fixed camera behavior remains unchanged
- Whitebox verifier and short smoke regression both pass after the visual translation
