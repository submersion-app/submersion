# Deco golden vectors

`generate_vectors.py` is an independent Python implementation of the
ZH-L16C + gradient-factor model, sharing pinned semantics with the Dart
engine (see docs/superpowers/plans/2026-07-05-dive-planner-phase1-engine.md,
Task 9). It generates `test/core/deco/golden/vectors.json`, which
`golden_vector_test.dart` replays against the Dart engine.

Regenerate after any intentional engine-semantics change:

    python3 scripts/deco_golden/generate_vectors.py > test/core/deco/golden/vectors.json

Never edit vectors.json by hand. Never derive expected values from an
LLM's recall — only from this script or a published external source.

Release gate: before each planner release, additionally compare a standard
plan set against MultiDeco by hand (see the design spec, Testing section).
