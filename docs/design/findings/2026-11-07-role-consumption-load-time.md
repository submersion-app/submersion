# Consumption by cylinder role: load time

Issue: #771. Spec: `docs/design/specs/2026-11-07-sac-trend-by-cylinder-role-design.md`.

## Setup

A test database seeded with 2000 open-circuit dives, each with a 12 L back gas
cylinder. Every fourth dive (500) also has a 7 L deco cylinder, a gas switch
onto it at 50 minutes, and a profile with one sample every 4 seconds (901
samples). Timed on the development Mac (Apple silicon) in `flutter test`,
three runs each, median shown. The live logbook was not used: a debug build
pointed at it migrates it.

## Result

| Read | Median |
| --- | --- |
| `getRoleConsumptionPerDive` (new) | 916 ms |
| `getSacVolumeByTankRole` (old by-role SQL) | 3 ms |
| `getSacVolumePerDive` (main SAC trend) | 3 ms |
| `getCcrGasUsePerDive` (no CCR dives seeded) | 0 ms |

## Reading it

The new read runs the dive detail's per-cylinder calculation in Dart on every
dive, with lean dive reads, gas switches, pressure series and 120-point
profile summaries loaded per chunk of 500. That is roughly 0.5 ms a dive here,
against a single SQL aggregate before. It is under the plan's 2 second stop
line, so the work went on.

It is paid once per filter change on the Gas page (the provider keeps both
lanes, so the lane toggle is free) and once for the planner's logged default
SAC, which is invalidated on every logbook change. A phone will be slower than
this Mac. If either shows up as a visible wait, the follow-up named in the
spec is a per-dive cache on the `deco_classification_cache` pattern, keyed by
an inputs hash, so only changed dives are recomputed.

## After the review: worst case and the per-dive memo

The whole-branch review pointed out that the first run had no pressure
series and profiles on only a quarter of the dives. Measured again with every
one of 2000 dives carrying a 4-second profile and a 4-second transmitter
series, read a chunk at a time:

| Phase | Total |
| --- | --- |
| Lean dive reads | 121 ms |
| Gas switches | 2 ms |
| Displayed pressure series (decoded on the calling isolate) | 726 ms |
| 120-point profile summaries (decoded on a worker isolate) | 1707 ms |
| Per-cylinder calculation and fold | 65 ms |
| **First read** | **1614 ms** |
| **Second and third read** | **9 ms** |

The live logbook (36 dives, every one with a profile and a series) is too
small to show this. The repository now keeps each dive's figures in memory
with the version they were worked out from: the dive source stamp
(`diveSourceStampSql`: the dive, its profile and pressure series and its
tanks), its gas switches, and which recording is primary. A later read,
whether a filter change on the Gas page, a logbook change ticking the
planner's logged default, or opening the Dive Lab, works out only the dives
whose version moved. Nothing is stored, so the first read after launch still
pays the full cost.

