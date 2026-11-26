# Edit bar actions in the pencil's amber

## Intent

While a record page is unlocked, the way out of the edit (Cancel and Save)
should be as easy to find as the way in (the amber pencil discs). Today Cancel
and Save are plain text in the page's foreground colour on a bar tinted with
the page's accent, so they do not stand out.

## Goals

- Save and Cancel on the unlocked record bar wear the pencil's amber
  (`RecordPencilColors`), so the pencil, the unsaved-changes dot and the bar's
  actions read as one editing colour on every theme preset, light and dark.
- Save is the more prominent of the two.

## Non-goals

- The small Done inside an open card's header stays as it is.
- No change to app bar actions outside the record editing bars.
- No change to the bar's tint, underline, layout or height.

## Anti-goals

- Cancel must not look as inviting as Save: a diver aiming for Save should not
  land on Cancel.
- Amber must not spread to unrelated app bar actions, which would dilute what
  the colour means.

## Approaches

1. **New editing button beside the pencil (chosen).** A `RecordEditAction`
   widget in `lib/shared/widgets/record_editing/` with a filled and a ring
   style, both read from `RecordPencilColors`. The record bars use it in place
   of `AppBarTextAction`. Keeps the editing colour in one folder; built on
   `FilledButton` and `OutlinedButton`, which bring their own foreground, so
   the app bar adoption guard (which flags bare `TextButton`s) stays satisfied
   and the Tropical / Console invisible-label defect cannot return.
2. **An amber option on `AppBarTextAction`.** Fewer files, but puts the
   editing colour inside a general widget eleven unrelated pages use.
3. **Theme-level button colours.** Would recolour every filled button in the
   app. Ruled out.

## Design (as decided)

- **Style B:** the primary action is filled: `fill` background, `onFill`
  label, `outline` ring. Cancel is a ring: transparent background, `outline`
  ring, label in `outline` (deep gold in light; in dark `outline` is the bright
  amber fill, as the pencil disc's ring is).
- **Where:**
  - `RecordEditBar` (full page): Cancel ring, Save filled.
  - `RecordEditPaneHeader` (desktop list pane): Cancel ring, Save filled.
  - `RecordSatelliteBar` (passport, cylinder board): Done filled, since it is
    that bar's only exit.
- **States:** a disabled action fades to Material's 0.38 opacity of its own
  colours. While saving, the filled action shows the progress spinner in
  `onFill`, keeping the label for assistive technology. Cancel disables while
  saving or busy, as today.
- The library reader's Send (the `saveLabel` override) takes Save's look.

## Left to the builder

- Button density and padding, provided the bar's height does not change and a
  long translation of Cancel or Save still fits (the title ellipsizes first).
- Hover, press and focus ink, provided they read on both fills.
