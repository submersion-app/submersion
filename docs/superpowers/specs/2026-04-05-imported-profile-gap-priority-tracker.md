# Imported Profile Gap Priority Tracker

**Date:** 2026-04-05
**Status:** Draft

## Purpose

Track the current gap between:

- backend/profile-model support
- UDDF import support
- SSRF/Subsurface XML import support

This document is intended to guide implementation sequencing, with a bias toward high-priority, low-blast-radius fixes that map directly from existing import fields into already-supported backend columns.

## Definitions

### Support Values

| Value | Meaning |
|---|---|
| `Yes` | Supported end-to-end in the current import path |
| `No` | Representable in our app model, but not fully supported end-to-end in the current import path |
| `N/A` | No direct field/concept support here, so importing it would require inference or a different model |

### Priority Values

| Value | Meaning |
|---|---|
| `High` | Clear dive-computer fidelity gap with user-visible impact, especially for deco, CCR, or gas analysis |
| `Medium` | Valuable metadata/provenance improvement, but less immediately impactful to core dive-profile behavior |
| `Low` | Already mostly covered, or lower-value than the deco/CCR/sample-state gaps |

### Fixed Column

Use the `Fixed` column as a working checkbox:

- `[ ]` not fixed
- `[x]` fixed
- blank = no action currently needed (already covered or not actionable in the current model)

## Combined Table

| Gap / Field Area | Fixed | Priority | Backend Support | UDDF Support | SSRF Support |
|---|---|---|---|---|---|
| Sample `ndl` | [x] | High | Yes | Yes | Yes |
| Sample `tts` | [x] | High | Yes | N/A | Yes |
| Sample `rbt` | [x] | High | Yes | Yes | Yes |
| Sample `cns` | [x] | High | Yes | Yes | Yes |
| Sample ceiling |  | High | Yes | N/A | N/A |
| Sample next stop | [ ] | Medium | N/A | Yes | Yes |
| Sample deco state (`decoType`) | [x] | High | Yes | Yes | Yes |
| Sample heart rate | [x] | High | Yes | Yes | Yes |
| Dive mode (`oc` / `ccr` / `scr`) | [x] | High | Yes | Yes | Yes |
| Rebreather dive fields (`setpointLow/High/Deco`, `SCR` config, diluent gas, loop O2, scrubber, loop volume) | [ ] | High | Yes | Yes | No |
| Tank role / material metadata | [ ] | High | Yes | No | No |
| Dive-level `cns` / `otu` | [x] | Medium | Yes | Yes | Yes |
| Dive-level deco metadata (`decoAlgorithm`, `GF low/high`, conservatism) | [ ] | Medium | Yes | No | No |
| Profile events / markers | [ ] | Medium | Yes | No | No |
| Source provenance snapshot (`DiveDataSources`) | [ ] | Medium | Yes | No | No |
| Surface pressure / altitude / surface interval | [ ] | Medium | Yes | No | No |
| Sample `setpoint` | [ ] | Medium | Yes | Yes | No |
| Sample `ppO2` | [x] | Medium | Yes | Yes | Yes |
| Multi-tank definitions | [ ] | Medium | Yes | Yes | No |
| Per-tank pressure time series |  | Low | Yes | Yes | Yes |
| Gas switches |  | Low | Yes | Yes | Yes |
| Sample ascent rate |  | Low | Yes | N/A | N/A |

## Most Valuable UDDF Fixes

| Gap / Field Area | Fixed | Priority | Why It Matters |
|---|---|---|---|
| Sample `ndl` | [x] | High | Direct deco-fidelity gap; backend already stores it |
| Sample `tts` |  | N/A | UDDF does not currently provide a direct mapped TTS field here, and exports may only include the next required deco stop rather than a full stop schedule |
| Sample `rbt` | [x] | High | Useful for imported computer playback and analysis; currently uses `remainingbottomtime`, falling back to `remainingo2time` when needed |
| Sample `cns` | [x] | High | Important imported O2-toxicity fidelity gap |
| Sample ceiling |  | N/A | UDDF waypoint data does not currently provide a direct ceiling field in our mapped vocabulary |
| Sample next stop | [ ] | Medium | UDDF exposes stop/deco-stop style data, but our backend does not currently have a dedicated sample next-stop field |
| Sample deco state (`decoType`) | [x] | High | UDDF `decostop@kind` now maps `safetystop` directly and treats any other decostop kind as the app's `deco` bucket |
| Sample heart rate | [x] | High | Already parsed in the UDDF path, but currently dropped during persistence |
| Tank role / material metadata | [ ] | High | Backend supports richer tank semantics and UDDF already carries some of it |
| Dive-level `cns` / `otu` | [x] | Medium | Useful summary metadata for imported technical dives |
| Dive-level deco metadata (`decoAlgorithm`, `GF low/high`, conservatism) | [ ] | Medium | Important provenance/context, but less critical than sample deco fields |
| Profile events / markers | [ ] | Medium | Parser can produce them, but importer does not persist them |
| Source provenance snapshot (`DiveDataSources`) | [ ] | Medium | Current UDDF provenance row is under-filled |
| Surface pressure / altitude / surface interval | [ ] | Medium | Helps reproduce altitude/weather/computer context |
| Sample ascent rate |  | Low | Nice to have, but lower value than the core deco fields |

## Most Valuable SSRF Fixes

| Gap / Field Area | Fixed | Priority | Why It Matters |
|---|---|---|---|
| Dive mode (`oc` / `ccr` / `scr`) | [x] | High | Real `.ssrf` files contain `dctype='CCR'` dives that are currently flattened |
| Rebreather dive fields (`setpointLow/High/Deco`, `SCR` config, diluent gas, loop O2, scrubber, loop volume) | [ ] | High | Biggest fidelity gap for CCR imports |
| Sample `ndl` | [x] | High | Real `.ssrf` samples contain it frequently and now map directly into profile samples |
| Sample `tts` | [x] | High | Present in the corpus and now preserved directly in imported profile data |
| Sample `rbt` | [x] | High | Present in the corpus and now preserved directly in imported profile data |
| Sample `cns` | [x] | High | Present in the corpus and now preserved directly in imported profile data |
| Sample ceiling |  | N/A | SSRF exposes stop-depth-style data, but not a direct ceiling field, so importing `ceiling` would require interpretation |
| Sample next stop | [ ] | Medium | SSRF exposes stop-depth-style data, but our backend does not currently have a dedicated sample next-stop field |
| Sample deco state (`decoType`) | [x] | High | `in_deco=1` now maps directly to the app's `deco` bucket, while non-deco samples remain `null` |
| Sample heart rate | [x] | High | Real `.ssrf` uses `heartbeat`; parser now preserves it directly into profile samples |
| Tank role / material metadata | [x] | High | Real `.ssrf` has `use='diluent'`; direct role mapping is now preserved, while richer material metadata remains open |
| Dive-level `cns` / `otu` | [x] | Medium | Real dive attributes exist and now persist through the shared import snapshot path |
| Dive-level deco metadata (`decoAlgorithm`, `GF low/high`, conservatism) | [ ] | Medium | Often available via `extradata`, but not mapped |
| Sample `setpoint` | [ ] | Medium | Real SSRF exports can imply it indirectly, but the parser does not currently map sample setpoint directly |
| Sample `ppO2` | [x] | Medium | Real SSRF `po2` now maps directly into sample `ppO2` |
| Profile events / markers | [ ] | Medium | Gas changes are imported, but bookmarks and other events are dropped |
| Source provenance snapshot (`DiveDataSources`) | [ ] | Medium | SSRF provenance is much thinner than backend support |
| Surface pressure / altitude / surface interval | [ ] | Medium | Real surface pressure exists in the corpus, but parser does not import it |
| Multi-tank definitions | [ ] | Medium | Multi-cylinder and `pressureN` are present, but richer semantics are incomplete |
| Sample ascent rate |  | Low | Lower value than the deco/CCR gaps |
| Per-tank pressure time series |  | Low | Already supported well enough |
| Gas switches |  | Low | Already supported well enough |

## High-Priority Low-Hanging Fruit

These are the high-priority items that appear straightforward, already exist in the source format, map cleanly to existing backend columns, and should have relatively low blast radius.

| Format | Gap / Field Area | Why It Is Low-Hanging |
|---|---|---|
| UDDF | Sample heart rate | Already parsed from waypoints in current UDDF import flow; mainly a persistence-path change |
| UDDF | Sample `cns` | Standard waypoint field with a direct one-to-one mapping into profile samples |
| UDDF | Sample `ndl` | Standard waypoint `nodecotime` field maps directly into profile samples |
| UDDF | Sample `rbt` | Standard waypoint timing fields map directly enough, using `remainingbottomtime` and falling back to `remainingo2time` |
| UDDF | Dive-level `cns` / `otu` | Can be taken directly from the last waypoint values and stored in the dive-data-source snapshot |
| SSRF | Dive mode (`dctype` -> `diveMode`) | Direct attribute-to-enum mapping with existing backend support |
| SSRF | Dive-level `cns` | Direct dive-attribute mapping to existing dive-level support |
| SSRF | Dive-level `otu` | Direct dive-attribute mapping to existing dive-level support |
| SSRF | Sample `ndl` | Real sample attribute exists; backend already stores per-sample NDL |
| SSRF | Sample `tts` | Real sample attribute exists; backend already stores per-sample TTS |
| SSRF | Sample `rbt` | Real sample attribute exists; backend already stores per-sample RBT |
| SSRF | Sample `cns` | Real sample attribute exists; backend already stores per-sample CNS |
| SSRF | Sample heart rate (`heartbeat`) | Real sample attribute exists; backend already stores per-sample heart rate |
| SSRF | Tank role (`use='diluent'` and related roles) | Direct cylinder-attribute mapping to existing tank-role concept |

## High-Priority But Larger Effort

These are still high-priority, but likely require interpretation rules, broader parser changes, or extra validation/testing beyond a simple field-to-column mapping.

| Format | Gap / Field Area | Why It Is Larger |
|---|---|---|
| UDDF | Sample `tts` / ceiling | UDDF does not currently provide a direct mapped TTS or ceiling field here, and exports may only describe the next required stop rather than the full deco schedule, so these still require interpretation or derived app-friendly values |
| UDDF | Sample next stop | The source format can describe it, but we need a backend field if we want to preserve it directly instead of deriving from other data |
| UDDF | Reconstructing deco-stop state from waypoint vocabulary | May require field interpretation rather than direct one-to-one mapping |
| SSRF | Rebreather dive fields beyond basic mode | Needs mapping from `po2`, `sensorN`, and possibly `extradata` into the app's rebreather model |
| SSRF | Sample ceiling | Requires deriving an app-friendly ceiling from `in_deco`, `stoptime`, and `stopdepth` rather than importing a direct field |
| SSRF | Sample next stop | The source format can describe it, but we need a backend field if we want to preserve it directly instead of deriving from other data |
| SSRF | Full rebreather semantics for diluent / CCR tanks | Role mapping is simple, but full CCR interpretation is broader than a single parser tweak |

## Suggested First Implementation Slice

If we start with the safest, most direct wins, the first slice should be:

| Order | Format | Gap / Field Area |
|---|---|---|
| 1 | UDDF | Sample heart rate persistence |
| 2 | SSRF | Dive mode (`dctype`) |
| 3 | SSRF | Dive-level `cns` / `otu` |
| 4 | SSRF | Sample `ndl` / `tts` / `rbt` / `cns` |
| 5 | SSRF | Sample heart rate (`heartbeat`) |
| 6 | SSRF | Tank role from cylinder `use=` |

## Notes

- `large-anon.ssrf` confirms that SSRF contains real-world occurrences of `dctype='CCR'`, `use='diluent'`, sample `ndl`, `tts`, `rbt`, `cns`, `heartbeat`, `bearing`, `po2`, `sensor1`-`sensor4`, and deco-stop fields.
- The biggest theme is not backend limitation. The backend already supports a much richer imported-profile model than the current UDDF and SSRF importers use.
- Current UDDF `rbt` uses a documented heuristic: prefer `remainingbottomtime`, then fall back to `remainingo2time` when that is the only remaining-gas/time field present.
- Current UDDF work does not populate sample `ceiling` because we have not identified a direct ceiling field in the mapped waypoint vocabulary.
- Current UDDF work does not populate sample `tts` because we have not identified a direct mapped TTS field, and stop-related exports may only capture the next required stop instead of the full remaining decompression schedule.
- Current UDDF `decoType` uses a direct `decostop@kind` mapping: `safetystop -> 1`, any other present `decostop` kind -> `2`, and samples with no `decostop` remain `null`. Unsupported kinds are logged as warnings during import.
- Both UDDF and SSRF can expose next-stop-style data, but our backend currently has no dedicated sample-level `next stop` field to store it without overloading `ceiling`.
- Current SSRF `decoType` uses a narrow direct mapping: `in_deco=1 -> 2`, while `in_deco=0` remains `null` instead of forcing an explicit non-deco enum value.
- In the combined table, `Fixed` means the gap is effectively closed across the compared import paths, not merely improved for one format.
- This tracker is intended to evolve as fixes land. Update the `Fixed` column in place rather than duplicating rows elsewhere.
