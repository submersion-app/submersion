# Brand assets

Code that draws the Submersion logo and brand images. The generated images
are committed under `assets/brand/`; after changing a preset, the layout or
the design, rerun the generator and commit the updated PNGs with the change.

## Setup

```bash
python3 -m venv scripts/.venv
scripts/.venv/bin/pip install -r scripts/requirements.txt
```

Python 3.10 or newer. Text rendering needs Pillow's RAQM layout, which loads
the system fribidi library: `brew install fribidi` on macOS, `sudo apt-get
install libfribidi0` on Debian/Ubuntu. Without it the generator stops with
that message rather than drawing un-kerned text.

## App icon

`generate_icon.py` draws the app icon and writes it into `assets/icon/`,
which `flutter_launcher_icons.yaml` then fans out to every platform.

```bash
scripts/.venv/bin/python scripts/brand/generate_icon.py
```

## Banners, lockups and marks

```bash
scripts/.venv/bin/python scripts/brand/generate_brand_assets.py          # all presets
scripts/.venv/bin/python scripts/brand/generate_brand_assets.py --list   # what exists
scripts/.venv/bin/python scripts/brand/generate_brand_assets.py --only github-social
```

Output goes to `assets/brand/`; `--out` picks another folder. That folder is
deliberately not listed in `pubspec.yaml`, so the images are not bundled into
the app (a test enforces this).

| Preset | Size | Use |
| --- | --- | --- |
| `github-social` | 1280x640 | Repository Settings > General > Social preview |
| `og-image` | 1200x630 | Website and docs link previews (Open Graph, Twitter card) |
| `readme-banner` | 2000x500 | README banner |
| `social-header` | 1500x500 | X/Twitter and Mastodon profile header |
| `linkedin-banner` | 1584x396 | LinkedIn banner |
| `play-feature` | 1024x500 | Google Play feature graphic |
| `website-hero`, `website-hero@2x` | 1920x640, 3840x1280 | Website home page hero |
| `square` | 1080x1080 | Square social posts |
| `reddit-banner` | 2144x256 | Subreddit banner, desktop slot (Reddit shows it at 1072x128) |
| `reddit-mobile-banner` | 2160x256 | Subreddit banner, mobile app slot (1080x128) |
| `mark-256`, `mark-512`, `mark-1024` | square | Logo glyph only, transparent; for dark or colored backgrounds |
| `lockup-dark`, `lockup-light` | ~2400 wide | Icon, name, rule and slogan on transparency; navy or white text |
| `wordmark-dark`, `wordmark-light` | ~2400 wide | Icon and name on transparency; navy or white text |

"dark" and "light" name the text color: dark text for light backgrounds,
light text for dark backgrounds.

The mark keeps the icon's white outline and the dive flag's white stripe, so
on a white page those parts disappear. On light backgrounds use a
`lockup-dark` or `wordmark-dark`, or the app icon itself.

## Adding a preset

Add one entry to `PRESETS` in `presets.py`. Banners take a size and an
optional `left_inset` for platforms whose avatar covers the left of the
image. Then add the size to `test_expected_presets_exist_with_exact_sizes` in
`layout_test.py` and run both test files:

```bash
scripts/.venv/bin/python scripts/brand/layout_test.py
scripts/.venv/bin/python scripts/brand/generate_brand_assets_test.py
```

## Fonts

`fonts/` holds Inter Display (ExtraBold for the name, Medium for the slogan)
from https://github.com/rsms/inter, under the SIL Open Font License in
`fonts/OFL.txt`.
