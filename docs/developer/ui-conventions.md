# UI Conventions

Which API serves which styling role, and the rules every screen follows. Read
this before building or changing a widget. It names APIs and files rather than
colour codes or pixel values, so it stays true as those values are tuned; the
code is the source of truth for the numbers.

## Colour roles

Never write a colour literal (`Color(0x...)`, `Colors.red`) in a widget. Pick
the role the colour plays:

| Role | API | File |
| --- | --- | --- |
| Surfaces, accents, containers, outlines, text on them | `Theme.of(context).colorScheme` roles (`surface`, `surfaceContainerLow`, `primary`, `onPrimaryContainer`, `outlineVariant`, ...) | Material `ColorScheme`, built per preset in `lib/core/theme/full_themes/` |
| Severity: overdue, due soon, OK | `StatusColors.of(context).alert` / `.warn` / `.ok`, each a `StatusSwatch` with `container`, `onContainer`, `outline`, `accent`, `onAccent` | `lib/core/theme/status_colors.dart` |
| Editing: the record pencil, unsaved-change dot, Cancel and Save on an unlocked record | `RecordPencilColors.of(context)` (`fill`, `onFill`, `outline`) | `lib/core/theme/record_pencil_colors.dart` |
| A feature area's accent (navigation, settings sections, Connections) | `FeatureAccentColors.resolve(theme).of(featureId)`; `null` means no accent | `lib/core/theme/feature_accent_colors.dart` |
| Fixed data hues: gas mixes, chart series, favourite | `AppColors` | `lib/core/theme/app_colors.dart` |
| Text or an icon on a solid fill | `foregroundOn(scheme, fill)` for a fill taken from the scheme; `blackOrWhiteOn(fill)` for a data colour | `lib/core/theme/foreground_on.dart` |
| A mark that punches out of what lies beneath it (the ring around a chart dot) | `backdropColorOf(context)`: the enclosing card's fill, or the page | `lib/core/theme/backdrop_color.dart` |
| Container roles of a hand-built preset | `withTintedContainers(scheme)` | `lib/core/theme/tinted_containers.dart` |

A new colour role goes in a `ThemeExtension` with a light and a dark value, as
`StatusColors` and `RecordPencilColors` do, and is registered on every preset.
It does not go in `AppColors`, which cannot follow the theme's brightness.

## Contrast

On every theme preset, in light and dark:

- text reaches 4.5:1 against what it sits on;
- icons, edges and other graphics reach 3:1.

The presets are held to this by tests under `test/core/theme/`:
`theme_container_contrast_test.dart` (container roles and their foregrounds),
`theme_neutral_roles_test.dart` (outlines and neutral text),
`status_colors_test.dart` and `record_pencil_colors_test.dart`. A new colour
role comes with the same kind of test.

## Type

Use the `Theme.of(context).textTheme` roles (`titleMedium`, `bodySmall`,
`labelSmall`, ...), adjusted with `copyWith` for weight or colour. Inside the
form system, use the text styles on `FormStyle`
(`lib/shared/widgets/forms/form_style.dart`). Override `fontSize:` only with a
reason the role cannot meet, and say what it is in a comment. The app name next
to the logo uses `BrandTypography.wordmark`
(`lib/core/theme/brand_typography.dart`) and nothing else does.

## Spacing and radii

Padding, margins, gaps and corner radii come from the scales in
`lib/core/theme/spacing.dart`:

- `Spacing.s2` to `Spacing.s48` for padding, margins and gaps;
- `Radii.r2` to `Radii.r24` for corners, and `Radii.pill` for fully rounded
  ends.

Each name carries its value (`Spacing.s16` is 16), so the scale names the
values in use rather than imposing a grid.

A value that is deliberately off the scale is declared once as a named
constant, with a doc comment saying why, beside the code that uses it. Never
move it to a nearby step. One widget's value is a private constant in its
file; a value a family of widgets shares goes in that family's style class,
as the form system's shared values do in `FormStyle` (`rowInset`,
`rowPadding`, `groupRadius`). A constant built from the scales needs no comment
(`EdgeInsets.fromLTRB(Spacing.s16, FormStyle.rowInset, Spacing.s16,
Spacing.s6)`).

`test/architecture/spacing_literals_test.dart` fails when a guarded folder
writes a spacing or radius value as a bare number. It checks:

- the `EdgeInsets` and `EdgeInsetsDirectional` constructors;
- `BorderRadius.circular`, `Radius.circular` and `Radius.elliptical`;
- a `SizedBox` with only `width` or only `height` and no `child`, or
  `child: null` (a gap);
- the `spacing:`, `runSpacing:`, `mainAxisSpacing:`, `crossAxisSpacing:`,
  `indent:` and `endIndent:` arguments of any call.

It looks through parentheses, both branches of a conditional, each arm of a
switch expression and the fallback of `??`. It does not look at zero, at any
arithmetic (`Spacing.s8 * 2`, `16 + inset`), at a `SizedBox` that sizes a
child, or inside a top-level, `static` or enum constant declaration, which is
how a named constant is exempt. An instance field and a closure's body are checked like
any other code.

A childless one-axis `SizedBox` that holds a place of a fixed size rather than
a gap (a 300-tall chart placeholder) is still flagged: declare its size as a
named constant, as for any off-scale value.

`lib/shared/widgets/` is guarded today. Feature folders migrate one at a time,
each in its own small PR, so the work does not collide with open feature
branches: a migration PR replaces the folder's literals, with no visual change,
and adds the folder to `guardedRoots` in the test. New and changed widgets in
any folder use the scales from now on.

## Standing rules

- **Status is never colour alone.** A status always carries an icon and a word,
  so it reads in greyscale and to a screen reader.
- **Selection is a fill; editing is a full frame.** A selected row or card gets
  a container fill, and an open editor gets a frame around the whole card. No
  coloured left borders.
- **App bar titles are left-aligned.** The presets set `centerTitle: false`;
  do not override it.
- **Every unit follows the active diver's unit settings.** Format depth,
  pressure, temperature, volume and weight through `unitFormatterProvider`
  (`lib/core/utils/unit_formatter.dart`), never with a hard-coded unit.
- **Build for the whole range of divers.** Check a screen with few and many
  items, short and long values, and at phone and desktop width: a new diver
  with 5 dives and an experienced one with 15,000, a 6 m reef dive and a deep
  trimix dive with stops from 40 m.

## Where styling lives

- `lib/core/theme/`: tokens and theme extensions shared by the whole app
  (colours, spacing and radii, typography, the presets).
- `lib/shared/widgets/forms/form_style.dart`: the form system's own values.
- A widget family's style class: values only that family shares.
- The widget's own file: a named constant only that widget uses.
