# Coverage that stops rewarding filler tests (Track 2 of the test-suite work)

## Problem

`codecov.yml` sets an 80% target for the lines a PR adds and a 70% target for
the whole project. Neither is a required check (only `CI Success` gates a
merge), but a red `codecov/patch` result prompts the author, usually a coding
session, to add tests until it turns green.

The cheapest lines to cover are boilerplate: `copyWith`, Equatable `props`,
`operator ==`, `hashCode` and `toString`. Tests that exist only to execute
them assert that a field copies or two equal objects are equal, and would
almost never catch a real bug. In a random sample of 120 test files, 7.5% were
low value, mostly of these shapes, and a quarter of the low and moderate files
trace to commits that say they raise patch coverage.

The pressure is modest today (3 of the last 60 merged PRs have a commit chasing
coverage, and none merged with a failing patch status), but every new entity
adds more boilerplate that counts toward the target.

## Decisions

| Topic | Decision |
|---|---|
| Role of coverage | Keep the targets: 80% patch, 70% project, unchanged |
| What changes | Trivial members stop counting toward either number |
| Mechanism | Filter each shard's coverage report in CI before upload. No source changes |
| `copyWith` | Exempt only when its body is pure field copying; one with logic stays counted |
| Serialization | `toJson` and `fromJson` stay counted: they map and default fields |
| Existing filler tests | Untouched here; removing them is Track 3 |

## What is exempt

A member's lines are removed from the report when it is one of:

| Member | Recognised by | Condition |
|---|---|---|
| `copyWith` | A method named `copyWith` | Every line of its body is plain copying (see below) |
| Equatable `props` | A getter `List<Object?> get props` | Always |
| `operator ==` | `bool operator ==(` | Always |
| `hashCode` | `int get hashCode` | Always |
| `toString` | `String toString(` | Always |

A `copyWith` body is plain copying when every line, ignoring comments, blank
lines and brackets, is one of:

- the constructor call: `return Type(`, `return const Type(`, `=> Type(`, or a
  named constructor such as `Type._(`;
- a named argument copied from a parameter: `name: name ?? this.name`,
  `name: this.name` or `name: name`, with an optional trailing comma;
- the whole call on one line, made only of such arguments:
  `return Type(a: a ?? this.a);`.

Anything else (a computed value, a clear flag, a conditional, a helper call,
a local variable) makes the `copyWith` count as ordinary code.

Measured on main: 134 of 226 `copyWith` methods are pure. Most of the rest use
a clear flag or a sentinel value, which counts as logic. With the other four
kinds the exemption covers about 6,200 lines in 334 files, just under 1% of
the hand-written code.

## Components

### `scripts/filter_trivial_coverage.py`

Standard library only, compatible with Python 3.9, tested by
`scripts/filter_trivial_coverage_test.py` with `unittest`, like the other
scripts.

```bash
python3 scripts/filter_trivial_coverage.py coverage/lcov.info
```

For each `SF:` record whose source file exists under `lib/`:

1. Read the source and mask comments and the contents of string literals,
   keeping offsets and line breaks, so a string holding `copyWith(` is not
   read as code.
2. Find each exempt member: its signature line through the end of its body
   (the matching `}` of a block body, or the `;` that ends an arrow body).
3. Drop the record's `DA:` lines whose line number falls inside an exempt
   member, then rewrite `LF` and `LH` from the lines that remain.

Records for files that do not exist, or that are not under `lib/`, pass
through unchanged. A missing or empty report is left as it is and the script
exits 0, so a shard whose tests failed before writing coverage still reports
the test failure, not a filter error. The script prints how many lines it
removed and from how many files.

Removing lines moves a percentage either way. It falls when covered
boilerplate was propping it up, which is the intent: a PR whose new code is
mostly untested apart from its `copyWith` sees its patch status fall. It rises
when uncovered boilerplate was holding it down.

### CI

In `.github/workflows/ci.yaml`, the `test` job gains a step between `Run tests`
and `Upload coverage`:

```yaml
      - name: Drop trivial members from coverage
        # copyWith, props, ==, hashCode and toString count toward no coverage
        # target, so no one writes a test only to execute them (see
        # scripts/filter_trivial_coverage.py and docs/developer/testing.md).
        if: always()
        run: python3 scripts/filter_trivial_coverage.py coverage/lcov.info
```

`if: always()` matches the upload step, which already runs on failure.

The Script Tests job adds the script to its coverage set and runs its tests.

### Guidance

`docs/developer/testing.md` replaces the stale Overview and Coverage Goals
tables (which claim "165+" unit tests and "All goals met") with the policy:

- the two targets and that neither blocks a merge;
- what is exempt, and that a test should assert behaviour, not execute lines;
- how to see patch coverage locally: `flutter test --coverage`, then the filter,
  then the comparison.

The coding session's own notes that coach reaching the patch target get the
same guidance, outside the repository.

## Verification

| Check | How |
|---|---|
| Recognition | Unit tests for each of the five kinds, in block and arrow form |
| `copyWith` rule | A pure one is exempt; ones with a computed value, a clear flag, a conditional or a local variable are not; a one-line pure body is exempt |
| Masking | A string or comment containing `copyWith(` or `operator ==` is not matched |
| Report rewrite | Only the right `DA:` lines go; `LF` and `LH` match what remains; other records are untouched |
| Robustness | Missing report, empty report, a source file that no longer exists, CRLF sources |
| End to end | One CI run: the shards' filter output, and Codecov project coverage before and after |

## Risks

| Risk | Mitigation |
|---|---|
| The filter hides real logic | Only five exact kinds; `copyWith` only when pure; everything else counts |
| A signature shape the filter misses | That member simply stays counted, which is today's behaviour |
| Coverage numbers jump once | Expected: about 6,000 mostly covered lines leave the totals. Noted in the PR |
| Local and CI numbers differ | The docs show the filter as part of measuring patch coverage locally |
