# Suggest an equipment category (design)

Suggestion 3 of discussion #4118: "Easier suggestions for equipment categories".

## Intent

Dive gear keeps changing, and some items fit none of Submersion's equipment
types or the style choices inside them. Today a diver who notices that has to
leave the app, find the repository and write a free-form feature request. The
goal is a short, structured proposal raised from the gear editor, so the
maintainer receives consistent requests (what, where it belongs, why) and can
judge each one quickly, without the list filling up with arbitrary categories.

## How equipment is categorised today

- **Category** = an `EquipmentType` value (a flat list of about 60 types,
  `lib/core/constants/app_enums.dart`). Adding one means a new enum value and
  a slot in every type order (`equipment_type_order.dart`).
- **Subcategory** = a choice on a type's style attribute, such as `bcd_style`,
  `bag_style` or `instrument_type` (`equipment_attribute_catalog.dart`).
  Adding one means a new choice key and its labels.

So a suggestion is one of those two, and its parent is an existing type.

## Goals

- From the gear editor, a diver can propose a new category or subcategory in
  under a minute.
- The resulting GitHub issue always carries the `equipment-suggestion` label
  and the same headings, whoever files it.
- Nothing leaves the device without the diver seeing it: the app opens a
  prefilled page in the browser and the diver posts it from their own account.
- Species suggestions get the same fix, so their `species-suggestion` label
  lands too.

## Non-goals

- No in-app GitHub account, token or API call.
- No local custom categories; the diver still files the item under the
  closest type (often Other) until the suggestion ships.
- No new named equipment families.

## Anti-goals

- Anything that sends gear details without the diver choosing to.
- A form so long that divers give up, or so loose that every request needs a
  follow-up question.

## Approaches considered

1. **Prefilled issue body, as species did.** No repository file, but GitHub
   applies a `labels=` URL parameter only for people who can triage the
   repository, so every diver's suggestion arrives unlabelled. This is what
   happened to species suggestions #4330 and #4334.
2. **GitHub issue form, with the app filling its fields (chosen).** A YAML
   form under `.github/ISSUE_TEMPLATE/` declares the labels and fields; the
   app opens `issues/new?template=<form>.yml&<field id>=<value>`. The form's
   labels are applied for everyone, the headings are consistent, and
   `computer-report.yml` already works this way from the support matrix. It
   also appears in GitHub's New issue chooser, so web visitors can suggest
   too. Cost: one more file whose field ids the app must match.
3. **Prefilled body plus a labelling workflow** keyed on the title prefix.
   Works, but adds an Action to fix what the form does for free. Dropped.

The user chose approach 2 and asked for species to move to it as well.

## Design

### Entry point

A text link under the type dropdown in the gear editor's header card
(`gear_item_header_editor.dart`): "Can't find a fit? Suggest a category". It
is shown for new and existing items, including dive-computer items whose type
is locked.

### Dialog

| Field | Behaviour |
| --- | --- |
| What are you suggesting? | Segmented choice: *New type of gear* (category) or *New kind of a type* (subcategory). Defaults to category when the item's type is Other, otherwise subcategory. |
| Name | Required free text. |
| Parent type | Dropdown of every `EquipmentType`, sorted by localized label, prefilled with the item's type. Labelled "A kind of" and required for a subcategory; labelled "Closest existing type" with a "None" option for a category. |
| Why is it needed? | Required, multi-line. |
| Include this item as an example | Checkbox, off by default. Shows the item's brand and model, and is hidden when the item has neither. |
| Open in GitHub | Primary action. Disabled until the required fields are filled. |

The dialog notes that it opens a prefilled request on GitHub that the diver
reviews and posts from their browser.

### Issue form: `.github/ISSUE_TEMPLATE/equipment-suggestion.yml`

- `title: "Equipment suggestion: "`, `labels: ["equipment-suggestion", "enhancement"]`.
- Fields (ids are the URL contract): `kind` (input, "Category or
  subcategory"), `name` (input, required), `parent` (input, the type's
  English label with its enum name in brackets, such as
  `Instrument / Gauge (instrument)`), `reason` (textarea, required),
  `example` (input, optional), `app_version` and `locale` (inputs).
- Text inputs and textareas only, since those are what URL prefill reliably
  fills.

The app sends English labels and stable enum names, whatever the diver's
language, so the maintainer can map a request straight to code; `locale`
records the language the diver wrote in.

### URL builder

`lib/features/equipment/domain/services/equipment_suggestion_url.dart`, a pure
function shaped like `buildSpeciesSuggestionUrl`: it takes the suggestion,
locale and app version and returns the `Uri`. The title is
`Equipment suggestion: <name>`. Free text gives way, so the URL stays at or
under 8000 characters: the reason first, then the example, then the name, down
to one character.

### Species migration

- New `.github/ISSUE_TEMPLATE/species-suggestion.yml` with `labels:
  ["species-suggestion"]` and input or textarea fields for common name,
  scientific name, category, taxonomy class, description, locale and app
  version.
- `buildSpeciesSuggestionUrl` fills those fields through `template=` instead of
  a `body` with a JSON block, keeping its title and its trimming order.
- `docs/developer/species-catalog.md` drops the "find them by title" caveat.

### Shared launcher

`launchSpeciesSuggestion` and `speciesSuggestionLaunchProvider` move to a
shared helper used by both features: external browser, no `canLaunchUrl`
guard, and a "Copy link" snackbar when the launch fails. Its strings become
shared ones.

### Labels

Create the `equipment-suggestion` label on the repository, described like
`species-suggestion`. An issue form whose label does not exist files the issue
without it.

## Testing

- URL builder unit tests: path, template, title, every field id and value,
  trimming order and the 8000-character cap.
- A contract test reads both YAML forms and checks that every field id the
  builders send exists in the form, and that the form's labels are as
  designed.
- Widget tests: the link shows under the type field (also when the type is
  locked); the dialog's defaults, required-field gating and the example
  checkbox; Open in GitHub launches the built URL through the provider; a
  failed launch shows the copy-link snackbar.
- The species detail page's existing suggest test, updated to the new URL.

## Left to the builder

- Exact copy and l10n keys, following the equipment and marine-life naming.
- Whether the dialog is a dialog or a bottom sheet on phone widths, following
  what the gear editor already uses for similar pickers.
