"""Every image generate_brand_assets.py can render.

Adding a destination is one new Preset entry. Sizes are pixels. Banners are
drawn on the teal background; transparent presets are lockups cropped to
their content; marks are the bare logo glyph.
"""

from dataclasses import dataclass

from layout import Insets

DEFAULT_INSET_RATIO = 0.125  # 80px on the 640px-high card (GitHub's 40pt border)
LOCKUP_MARGIN = 48

RULE_COLOR = (200, 0, 0)  # #C80000, dive-flag red
THEMES = {
    # Navy text, for light backgrounds (and the teal banners).
    "dark": ((6, 48, 60), (11, 68, 82)),
    # White text, for dark backgrounds.
    "light": ((255, 255, 255), (230, 248, 250)),
}


@dataclass(frozen=True)
class Preset:
    name: str
    width: int
    height: int
    kind: str  # "banner" | "transparent" | "mark"
    layout: str  # "horizontal" | "stacked" | "none"
    purpose: str
    theme: str = "dark"
    show_slogan: bool = True
    icon_ratio: float = 0.53
    left_inset: float | None = None


def _banner(name, width, height, purpose, **kw):
    return Preset(name, width, height, "banner", "horizontal", purpose, **kw)


def _lockup(name, purpose, **kw):
    # A square working canvas with icon_ratio 1.0 forces the layout to be
    # width-bound, so the lockup comes out close to 2400px wide before cropping.
    return Preset(name, 2400, 2400, "transparent", "horizontal", purpose, icon_ratio=1.0, **kw)


def _mark(size):
    # The dive flag's white stripe and outline vanish on white, so the mark is
    # for dark or colored backgrounds; light pages use a lockup or the icon.
    return Preset(
        f"mark-{size}",
        size,
        size,
        "mark",
        "none",
        "Transparent logo mark, no tile; for dark or colored backgrounds",
    )


PRESETS = (
    _banner("github-social", 1280, 640, "GitHub repository social preview"),
    _banner("og-image", 1200, 630, "Website and docs link previews (Open Graph, Twitter card)"),
    _banner("readme-banner", 2000, 500, "README banner, 4:1 for high-density screens"),
    _banner("social-header", 1500, 500, "X/Twitter and Mastodon profile header", left_inset=300),
    _banner("linkedin-banner", 1584, 396, "LinkedIn banner", left_inset=400),
    _banner("play-feature", 1024, 500, "Google Play feature graphic"),
    _banner("website-hero", 1920, 640, "Website home page hero"),
    _banner("website-hero@2x", 3840, 1280, "Website home page hero, 2x"),
    Preset("square", 1080, 1080, "banner", "stacked", "Square social posts", icon_ratio=0.36),
    # Reddit shows its banners only 128px tall (1072x128 desktop, 1080x128
    # app; these are 2x). The icon fills the whole safe height so the name
    # and slogan are as large as the strip allows.
    _banner(
        "reddit-banner",
        2144,
        256,
        "Reddit community banner, desktop slot",
        icon_ratio=1 - 2 * DEFAULT_INSET_RATIO,
    ),
    _banner(
        "reddit-mobile-banner",
        2160,
        256,
        "Reddit community banner, mobile app slot",
        icon_ratio=1 - 2 * DEFAULT_INSET_RATIO,
    ),
    _mark(256),
    _mark(512),
    _mark(1024),
    _lockup("lockup-dark", "Transparent lockup, navy text for light backgrounds"),
    _lockup("lockup-light", "Transparent lockup, white text for dark backgrounds", theme="light"),
    _lockup("wordmark-dark", "Transparent icon and name, navy text", show_slogan=False),
    _lockup(
        "wordmark-light",
        "Transparent icon and name, white text",
        theme="light",
        show_slogan=False,
    ),
)

_BY_NAME = {p.name: p for p in PRESETS}


def find(name):
    """Return the preset called name; raises KeyError if there is none."""
    return _BY_NAME[name]


def safe_insets(preset):
    if preset.kind == "transparent":
        m = LOCKUP_MARGIN
        return Insets(m, m, m, m)
    d = preset.height * DEFAULT_INSET_RATIO
    left = preset.left_inset if preset.left_inset is not None else d
    return Insets(left, d, d, d)


def size_label(preset):
    if preset.kind == "transparent":
        return f"~{preset.width} wide"
    return f"{preset.width}x{preset.height}"
