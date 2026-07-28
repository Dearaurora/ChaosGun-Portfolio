# Momentum Circuit v8 approved environment references

These four images are the approved production references for the low-cost
environment enrichment pass. They do not redefine gameplay geometry.

| Reference | Production use | SHA-256 |
| --- | --- | --- |
| `momentum_circuit_v8_far_mothership_approved.png` | Static far backdrop and mothership skyline | `B43CFD745F14072A64CAF6506C0084B9387818439E6AE719E4FA3BCC9F4D2875` |
| `momentum_circuit_v8_mid_energy_array_approved.png` | Mid-distance ring and tower composition | `503369B7AEEFD6DC562C6D0E77386911424001069176A84D6253E968ECD0F542` |
| `momentum_circuit_v8_ambient_transit_approved.png` | Ambient traffic, probes, and beacons | `B26DB95C8EA96BD5DE118219C6924FA3ACF582ADFEDB8EBAB1B403803D5A6C3C` |
| `momentum_circuit_v8_lowpoly_roster_approved.png` | Exact ten-family low-poly roster | `6B67E669A423A6CEF8186F2546D2BAF58C2142C49F1AFBBDA2073118FE4F1F84` |

Production split:

- Far detail remains a static background texture.
- Exactly ten reusable low-poly families provide mid-distance silhouettes.
- Runtime motion is limited to slow rings, three traffic loops, and a
  low-alpha sensor scan.
- Everything in this pass remains outside the playable boundary, visual-only,
  shadow-free, and collision-free.
