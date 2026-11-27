# Twin set candidates: D codes in custom presets

Issue: #5065

## Problem

The Gas page note that offers to re-role cylinders that look like a twin set
(#3374) is meant to find Back Gas cylinders whose name or preset carries a D
code such as `D12`. A custom tank preset stores a slug, built in
`TankPresetEntity` by dropping every character outside `[a-z0-9\s-]` and
turning whitespace into `_`:

| Display name | Stored slug |
|---|---|
| `D12` | `d12` |
| `D 12` | `d_12` |
| `D 8.5` | `d_85` |

`_namesTwin` turns `_` back into a space, so the D code rule sees `d 12` or
`d 85`. `_twinDCode` required the digit straight after the `d`, so neither
matched. A `D 12` preset (24 L) was still found by the 20 L volume rule; a
`D 8.5` preset (17 L) was not found at all.

## Change

One rule, in `lib/features/insights/domain/tank_configuration/twin_set_candidates.dart`:

```
(?<![a-z0-9])d\s*\d{1,2}(?:[.,]\d)?(?![a-z0-9]|[.,]\d)
```

- `\s*` lets whitespace separate the `d` and the size, which covers both a
  typed name (`D 12`) and a slug (`d_12` after the underscore swap).
- `(?:[.,]\d)?` accepts one decimal digit with a point or a comma (`D8.5`,
  `D 8,5`). The slug has already lost the point, so `d_85` matches as the
  two-digit size `85`.
- The look-behind still rejects a D inside a word (`ED12`, `ED 12`), and the
  look-ahead still rejects a third digit (`D123`, `D 123`) and a second
  decimal digit (`D12.55`).

The SQL function `twin_set_candidate` calls the same Dart rule, so the
repository query needs no change.

## Edge cases considered

- **A Diluent named `D1`:** it already matched the old rule; the role filter
  (`backGas` only) keeps it out, as before.
- **Words that start with d** (`Dive 12`, `Doppelventil`): a letter follows
  the `d`, so the rule does not match. The valve phrase is still stripped
  before the check.
- **Built-in presets** (`al80`, `steel12`, `steel15`, ...): none starts with a
  free-standing `d` followed by a number.
- **A size with a unit** (`D12L`): it did not match before and still does
  not; it is out of scope for this issue.
- **Reading the preset display name instead of the slug:** not needed. The
  slug already carries the D code, and joining `tank_presets` would add a
  per-diver lookup to a query that today reads `dive_tanks` alone.

## Tests

- `twin_set_candidates_test.dart`: names `D 12`, `D8.5`, `D 8.5`, `D 8,5`;
  presets `d_12`, `d_85`, `d85`; rejected `D 123`, `ED 12`, `D12.55`; a 17 L
  `d_85` Back Gas is a candidate and a `d_85` Diluent is not.
- `twin_set_candidates_sql_test.dart`: a 17 L Back Gas with preset `d_85` is
  returned by `getTwinSetCandidates`.
