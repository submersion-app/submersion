# UI conventions doc, spacing scale and named radii

Issue: #4971

## Why

Colours are centralised (`ColorScheme` plus the `StatusColors`,
`RecordPencilColors` and `FeatureAccentColors` extensions), but spacing and
corner radii are hand-written wherever they are used. Only the form system
shares constants (`FormStyle`). Nothing written down tells a contributor, or an
agent building a component, which API serves which role, so every new widget
adds more literals. `lib/` holds about 2,900 `EdgeInsets` literals and 576
`BorderRadius.circular(...)` literals.

## Goals

1. A conventions doc, `docs/developer/ui-conventions.md`, linked from
   `CLAUDE.md` and from `docs/developer/README.md`, that maps each styling
   role to the API that serves it and records the standing UI rules.
2. A shared spacing scale and a set of named radii, in the style of
   `FormStyle`.
3. Every spacing and radius literal in `lib/shared/widgets/` migrated to the
   scale or to a named constant, with no visual change.
4. An architecture test that fails when a new literal appears in
   `lib/shared/widgets/`.

## Non-goals

- Migrating feature folders. They move later, feature by feature, in small
  PRs, so the work does not collide with open feature branches. Each such PR
  adds its folder to the guard's list.
- Font sizes and colour literals. The doc points at `textTheme` roles and the
  colour APIs, but no guard covers `fontSize:` or `Color(0x...)` here.
- Retuning any value. The scale is descriptive: it names what the app already
  uses.

## Anti-goals

- Any pixel moving. Every migrated site keeps its exact value; a value that is
  not on the scale gets a name, never a nearby scale step.
- A guard that cries wolf. It must not flag comments, non-literal expressions,
  `0`, or the declaration of a named constant.
- A doc that drifts. It names APIs and files, never hex values or pixel
  numbers that live in code.

## Approaches considered

| Approach | Trade-off | Outcome |
| --- | --- | --- |
| AST scanner (`package:analyzer` visitor plus its own scanner test, like `list_tile_trailing_scanner.dart`) | About 250 lines; exact across formatting and comments | **Chosen** |
| Regex scanner over comment-stripped source (like `map_style_switcher_adoption_test.dart`) | About 60 lines; misreads multi-line and nested arguments, and `//` inside strings | Rejected: false positives on a guard every shared widget meets |
| `custom_lint` rule | Shows in the IDE; new dependency and a second guard mechanism | Rejected: the repo guards with architecture tests |

Also decided with the maintainer:

- **Scope:** both steps in one PR, with `lib/shared/widgets/` migrated so the
  guard starts at zero literals (no per-file count baseline).
- **Naming:** numeric names that carry the value (`Spacing.s16`, `Radii.r12`),
  so a migration reads as visibly one-to-one.
- **Gap boxes count:** a `SizedBox` with only `width` or only `height` set to a
  number is spacing and uses the scale. A box with both is a size and is out
  of scope.

## Design

### Constants

New file `lib/core/theme/spacing.dart` (beside the colour tokens), holding two
`abstract final class`es of `static const double`:

- `Spacing`: `s2, s4, s6, s8, s12, s16, s20, s24, s32, s40, s48`. These are the
  values `lib/` already uses most for padding and gaps (counts at the time of
  writing: 16, 8, 12, 4 and 24 dominate, then 6, 2, 32, 20, 40, 48).
- `Radii`: `r2, r4, r6, r8, r12, r16, r20, r24`, plus `pill = 999` for the
  fully rounded ends `lib/` already writes as `BorderRadius.circular(999)`.

Each class carries a doc comment pointing at the conventions doc and saying
that a value off the scale gets its own named constant rather than a nearby
step.

### In-between values

A value that is deliberately off the scale (the form rows' 11/14 padding, the
13 form-group radius, a 10 or 14 inset in a shared widget, the 88 FAB
clearance) is declared as a named constant with a doc comment saying why,
next to the code that uses it, the way `FormStyle` and `kFabListPadding`
already do. Constants used by one widget stay private to its file; constants
a family of widgets shares go in that family's style class (`FormStyle`).

### The guard

`test/architecture/spacing_literal_scanner.dart` parses each file with
`parseString` and visits instance creations and method invocations. It flags a
numeric literal (integer or double, optionally negated) other than zero when
it is passed directly as an argument to:

- `EdgeInsets.all / symmetric / only / fromLTRB` and the same constructors of
  `EdgeInsetsDirectional` (`all`, `symmetric`, `only`, `fromSTEB`);
- `BorderRadius.circular`, `Radius.circular`, `Radius.elliptical`;
- `SizedBox(...)` with no `child` when exactly one of `width` / `height` is
  given (the literal in that argument). A one-axis `SizedBox` with a `child`
  sizes its child (a column width, a dialog height) and is not spacing (call
  made while writing the spec);
- the layout spacing arguments, by name on any call: `spacing:`,
  `runSpacing:` (`Row`, `Column`, `Flex`, `Wrap`), `mainAxisSpacing:`,
  `crossAxisSpacing:` (grid delegates) and `indent:`, `endIndent:` (`Divider`,
  `VerticalDivider`). Decided with the maintainer: they are gaps by another
  name.

A literal counts when it is the argument itself, or a branch of a conditional
(`compact ? 8 : 16`) or the right side of `??` that is the argument,
recursively through parentheses. An operand of arithmetic is not flagged
(`Spacing.s8 * 2`, `depth * 12`): it is a multiplier or a computed offset
(call made while writing the spec).

It does not flag:

- anything inside the initializer of a top-level variable, a `static`
  field declaration or an enum constant's arguments (a named constant, such as `FormStyle.rowPadding` or
  `kFabListPadding`), except inside a closure there. An instance field is
  widget state and is checked (narrowed after the final review);
- expressions built from names (`FormStyle.groupRadius`);
- `SizedBox.square`, `SizedBox.fromSize` and two-axis boxes, which are sizes;
- comments and strings, which the AST never presents as arguments.

`test/architecture/spacing_literal_scanner_test.dart` unit-tests the scanner
on inline source snippets (each flagged form, each exempt form, multi-line
arguments, const and non-const creation).
`test/architecture/spacing_literals_test.dart` runs it over a list of guarded
roots, today `['lib/shared/widgets']`, and fails with `file:line  call  value`
for each finding plus a message pointing at the conventions doc. A later
feature migration adds its folder to that list.

### Migration of `lib/shared/widgets/`

Every flagged site is rewritten: an on-scale value becomes the `Spacing` /
`Radii` constant of the same value, and an off-scale value becomes a named
constant as above. About 190 sites.

Proving no pixel moves (call made while writing the spec): the repo has one
golden test and none over shared widgets, so tests alone cannot catch a 16
turned into 12. The on-scale rewrites are therefore mechanical, driven by the
scanner's own findings (literal N becomes `Spacing.sN` or `Radii.rN`, equal by
construction). Only off-scale sites are edited by hand, and a one-off diff
check confirms every removed literal maps to a constant of the same value.
Existing widget tests still run as the behaviour check.

### The conventions doc

`docs/developer/ui-conventions.md`, sections:

1. **Colour roles:** `ColorScheme` roles for surfaces, accents and containers;
   `StatusColors.of(context)` for overdue / due soon / OK;
   `RecordPencilColors.of(context)` for the editing colour;
   `FeatureAccentColors.resolve(theme)` for per-area accents; `AppColors` for
   the fixed data hues (gas mixes, chart series, favourite); `foregroundOn`
   and `blackOrWhiteOn` for text on a fill; `backdropColorOf` for marks that
   punch out of what lies beneath them; new colour roles go in a
   `ThemeExtension` with light and dark values.
2. **Contrast:** 4.5:1 for text and 3:1 for icons and edges, on every theme
   preset, with the tests that hold it.
3. **Type:** `textTheme` roles first; `FormStyle` text styles inside forms; a
   `fontSize:` override only with a reason.
4. **Spacing and radii:** the `Spacing` and `Radii` scales, the in-between
   rule, and the guard (what it flags, how to exempt a value properly).
5. **Standing rules:** status always carries an icon and a word, never colour
   alone; selection is a fill and editing is a full frame (no coloured left
   borders); app bar titles are left-aligned; every unit follows the active
   diver's unit settings; build for the whole range of divers (few and many
   items, short and long values, phone and desktop width).
6. **Where styling lives:** `lib/core/theme/` for tokens and extensions,
   `FormStyle` for the form system, a widget family's own style class for
   values only that family shares.

`CLAUDE.md` gains one line under Code Conventions linking the doc;
`docs/developer/README.md` gains it in Quick Links.

## Left to the builder

- Exact doc wording, and which existing tests to cite for contrast.
- Names of the in-between constants created during the migration.
- Whether a named constant is private or belongs in a family's style class,
  per the rule above.
