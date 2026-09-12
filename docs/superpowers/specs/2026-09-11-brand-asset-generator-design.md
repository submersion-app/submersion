# Brand Asset Generator Design

Date: 2026-09-11
Branch: `ericgriffin/social-preview-image-aeb565`

## Goal

Generate the approved Submersion social card, and every other brand image the
project needs, from code, the same way `scripts/generate_icon.py` generates the
app icon. One command renders a named set of banners (teal background) and
transparent PNGs (logo, lockups, wordmarks) at the sizes each destination
expects.

The approved reference design is a 1280x640 card: the app icon tile on the
left over the icon's own cyan-to-teal gradient with faint decorative white wave
bands, and on the right "Submersion" in heavy deep navy (#06303C), a short red
rule in the dive-flag red (#C80000), and the one-line slogan "Dive safe. Log
everything." in medium navy (#0B4452), scaled so its width equals the
wordmark's width.

## Decisions

| Topic | Decision |
| --- | --- |
| Renderer | Pillow, reusing the existing icon code (approach A). No browser, no SVG rasterizer. |
| Font | Inter Display (SIL Open Font License), bundled: ExtraBold for the name, Medium for the slogan. Apple's SF Pro used in the prototype cannot be committed. |
| Committed outputs | The generated PNGs are committed under `assets/brand/`, the script's default output (revised after implementation; originally script only). Not listed in `pubspec.yaml`, so not bundled into the app. No CI staleness check. |
| Location | New folder `scripts/brand/`. `scripts/generate_icon.py` moves there too. |
| `generate_icon.py` | Moved with `git mv`; the only edit is the one-line project-root path fix the move requires. No other code changes. |
| README | Unchanged. The README banner asset is generated, but the README header is not modified. |

## Outputs

Running `python3 scripts/brand/generate_brand_assets.py` writes every preset to
`assets/brand/<name>.png`. `--only <name>[,<name>...]` renders a subset;
`--list` prints every preset with its size and purpose; `--out <dir>`
overrides the output directory.

### Banners (teal background, opaque)

Horizontal layout: icon left; name, rule and slogan right.

| Preset | Size | Use |
| --- | --- | --- |
| `github-social` | 1280x640 | GitHub repository social preview |
| `og-image` | 1200x630 | Website and docs link previews (Open Graph, Twitter card) |
| `readme-banner` | 2000x500 | README banner, 4:1, sharp on high-density screens |
| `social-header` | 1500x500 | X/Twitter and Mastodon profile header |
| `linkedin-banner` | 1584x396 | LinkedIn banner |
| `play-feature` | 1024x500 | Google Play feature graphic |
| `website-hero` | 1920x640 | Website home page hero |
| `website-hero@2x` | 3840x1280 | Website home page hero, 2x |
| `square` | 1080x1080 | Square posts; stacked layout (icon above centered text) |

`social-header` and `linkedin-banner` carry a larger left safe inset because
the profile avatar covers the lower-left of the header on those platforms.

### Transparent PNGs

No background gradient and no decorative waves.

| Preset | Contents |
| --- | --- |
| `mark-256`, `mark-512`, `mark-1024` | The dive-flag waves and arrow with the white outline and edge lighting; no teal tile, no drop shadow |
| `lockup-dark` | Icon tile, name, red rule, slogan; navy text, for light backgrounds |
| `lockup-light` | Same, with white text, for dark backgrounds |
| `wordmark-dark` | Icon tile and name only (no rule, no slogan); navy text |
| `wordmark-light` | Same, with white text |

Lockups and wordmarks are rendered 2400px wide and cropped to their content
plus a small uniform margin. The mark omits the icon's drop shadow because a
translucent black shadow reads as a smudge on dark backgrounds; the white
outline keeps it legible on any background. The wordmark drops the rule
because the rule exists only to separate the name from the slogan.

## Architecture

```
scripts/brand/
  generate_icon.py              moved from scripts/ (path fix only)
  generate_brand_assets.py      CLI and Pillow rendering
  presets.py                    preset table (data only)
  layout.py                     geometry (no Pillow import)
  mark.py                       transparent mark built from icon primitives
  fonts/InterDisplay-ExtraBold.ttf
  fonts/InterDisplay-Medium.ttf
  fonts/OFL.txt
  README.md                     what each preset is for, how to add one
  layout_test.py
  generate_brand_assets_test.py
```

Modules import each other as siblings (the script's own directory is on
`sys.path` when run directly), matching how the flat `scripts/` files work.
No package or `__init__.py` is introduced.

### presets.py

A list of immutable preset records: name, width, height, kind (`banner`,
`transparent`), layout (`horizontal`, `stacked`, `mark`), text theme (`dark`,
`light`), whether the slogan and rule are shown, and safe insets (left, top,
right, bottom) in pixels. Adding a destination is one new record.

Default safe inset is 12.5% of the canvas height on every side (80px on the
640px-high card, matching GitHub's recommended 40pt border). Overrides:
`social-header` uses a 300px left inset and `linkedin-banner` a 400px left
inset for the avatar overlap.

### layout.py

Pure geometry. Input: canvas size, safe insets, layout kind, whether the
slogan is shown, and a `measure(text, role, font_px) -> (width, height)`
callable. Output: boxes for the icon, name, rule and slogan.

All dimensions derive from the icon size using the approved card's
proportions: icon height 0.53 of canvas height, name font 0.34 of the icon
size, rule 96x8 at the reference scale, and the reference gaps measured
between ink edges on the approved render (64px icon-to-text, 40px
name-to-rule, 46px rule-to-slogan at a 340px icon). Text boxes are ink
bounding boxes, not line boxes, so alignment is exact. The
slogan font size is solved so the slogan's measured width equals the name's
measured width. One scale factor is reduced until the whole block fits inside
the safe area, and the block is then centered in it. `stacked` places the
icon above the text block, both horizontally centered.

### mark.py

`create_mark(size)` renders the glyph on a transparent canvas at 4x and
downsamples with LANCZOS, like the icon. It imports `build_flag` and
`build_wave_arrow_mask` from `generate_icon.py` and applies its own copy of
the white outline (mask dilation) and edge lighting steps, without the drop
shadow and without a tile clip. It duplicates roughly 40 lines of
`apply_depth_effects`; the drift test below guards against the copy diverging
from the icon.

### generate_brand_assets.py

For each selected preset: build the canvas (banner: the approved card's
160-degree gradient `#4FE9FD` 0%, `#40D3E0` 45%, `#2FB4AA` 100% plus the three
decorative wave shapes and the icon's soft teal drop shadow; transparent:
empty RGBA, no shadow), render the icon tile with `create_icon()` at the
laid-out size, draw the name, rule and slogan with the bundled fonts, crop
transparent lockups to content plus margin, and save PNG.

Text requires Pillow's RAQM layout. Inter carries its kerning only in the
OpenType GPOS table (it has no legacy `kern` table), and Pillow's BASIC layout
reads only `kern`, so without RAQM the text would silently lose all kerning
and output would differ between machines. Pillow's wheels bundle libraqm but
load the system `libfribidi` at runtime (Homebrew `fribidi` on macOS,
`libfribidi0` on Debian/Ubuntu). There is no fallback.

Error handling: an unknown `--only` name exits non-zero listing valid names; a
missing font file exits non-zero naming the expected path; RAQM unavailable
exits non-zero with the fribidi install commands; Pillow import failure exits
non-zero pointing at `scripts/requirements.txt`.

### generate_icon.py move

`git mv scripts/generate_icon.py scripts/brand/generate_icon.py`. Its `main()`
derives the project root as the parent of the script directory; after the
move it must go up two levels. That line is the only edit. Verification: run
it and confirm the regenerated `assets/icon/*.png` match the committed files
pixel for pixel (then restore the committed files if the bytes differ only in
PNG encoding).

### Other edits

- `scripts/requirements.txt`: add `Pillow>=10.1` (the first release that
  accepts the float font sizes the renderer passes), noting it serves the brand
  scripts (the icon script already depended on it without listing it).

## Testing

Tests are written before the code they cover (repo TDD rule), in the
`unittest` style of the existing `scripts/*_test.py` files.

`layout_test.py` (no Pillow, fake measurer):

- slogan width equals name width
- every box lies inside the safe area for every preset, including the avatar
  insets
- the block is centered within the safe area
- 4:1 canvases scale down rather than overflow
- `stacked` puts the icon above the text, both centered
- wordmark layouts return no rule or slogan box

`generate_brand_assets_test.py` (Pillow, real fonts):

- every preset renders at its exact size
- banners have no transparent pixels
- transparent presets have fully transparent corners and non-empty content
- the mark contains no tile-teal pixels
- mark drift guard: inside the eroded glyph mask, the mark's flag pixels match
  the committed `assets/icon/icon.png` within a small mean-difference
  tolerance
- `lockup-dark` and `lockup-light` differ only in text pixels (navy vs white)
- CLI: `--list` output, `--only` subset, unknown name exits non-zero, missing
  font exits non-zero, RAQM unavailable exits non-zero

Tests fail, never skip, when Pillow or the fonts are missing.

### CI

In `.github/workflows/ci.yaml`, the `script-tests` job gains a Pillow install
step using the job's existing three-attempt pip retry pattern, installs
`libfribidi0` if Pillow reports RAQM unavailable, and runs `scripts/brand/layout_test.py` and
`scripts/brand/generate_brand_assets_test.py`. The step runs before the dive
site harvester step: that step's unretried `pip install -r
scripts/requirements.txt` also lists Pillow, so running it first would make it
the one downloading Pillow and bypass the retry.

### Manual verification

Run the generator locally, inspect every output, time the full run (the
3840x1280 hero renders its icon at roughly 2700px supersampled through the
existing per-pixel loops), and compare the Inter `github-social` render side
by side with the approved SF Pro prototype.

## Out of scope

- Changing the README header.
- A CI staleness check for the committed PNGs (Pillow, FreeType and fribidi
  versions differ between machines, so a pixel-exact check would fail
  spuriously).
- Any change to `generate_icon.py` beyond the path fix, including performance
  work on its per-pixel loops (revisit only if the measured run time is a
  problem).
- Dark-background banner variants.
