# Dive Computer Support Matrix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish `https://submersion.app/computers`, a per-model matrix of Bluetooth and USB support per platform with verification status, sourced from every place divers report results and refreshed by a monthly sweep.

**Architecture:** A Python generator in the app repo turns libdivecomputer's descriptor table and a five-row platform-rules file into `catalog.json` (what is possible). A curated `reports.json` in the website repo holds evidence (what divers saw). A static page joins the two in the browser through pure ES modules that `node --test` covers; a validator gates the data; a monthly cloud routine sweeps sources and opens a PR.

**Tech Stack:** Python 3.9+ standard library and unittest (app repo); plain HTML, CSS and ES modules, Node 22 `node:test` (website repo, GitHub Pages); `gh`, `curl`, `git`; a scheduled cloud agent.

**Spec:** `docs/superpowers/specs/2026-10-02-dive-computer-support-matrix-design.md` (app repo). Read it before any task.

## Global Constraints

- No em dash (U+2014) and no en dash used as punctuation in any file, commit message, PR title or body, or data `note`.
- No mention of Claude, Claude Code or Anthropic in any commit, PR, issue, comment or file in either repo. No `Co-Authored-By` trailers, no session links.
- No usernames or display names anywhere in the data or on the page; a `note` is our own paraphrase, at most 120 characters, never quoted text.
- Platforms, in this order everywhere: `ios`, `android`, `macos`, `windows`, `linux`.
- Transport families shown: `bluetooth` (libdc `ble`) and `usb` (libdc `serial`, `usb`, `usbhid`). Bluetooth Classic and IrDA are never a family.
- Platform rules: iOS `ble`; Android `ble`, `serial`; macOS, Windows, Linux `ble`, `serial`, `usbhid`. libdc raw `usb` is reachable nowhere.
- Model id: lowercase vendor and product, `+` spelled `plus`, other non-alphanumeric runs collapsed to `-`, trimmed; identical vendor and product pairs merge; distinct pairs colliding need an `idOverrides` entry (`"Subgear|XP Air": "subgear-xp-air-irda"` exists).
- Outcomes: `works`, `caveats`, `fails`. Sources: `scubaboard`, `github-issue`, `github-pr`, `github-discussion`, `reddit`, `app-store`, `play-store`. Release notes only corroborate `fixedIn`.
- Generator runs on Python 3.9 (no `match`, no `X | None` annotations). Locally use `python3.14`; the system `python3` is 3.9.6, which the code must also support.
- App repo PRs carry `Refs #2616` (PR 1) or `Closes #2616` (PR 5) in the description body.
- Website copy rules (its `docs/superpowers/specs/2026-08-23-content-rewrite-design.md`): second person, present tense, one idea per sentence, no metaphor or slogan; every homepage claim maps to a row in that spec's verified-claims table.
- Run `dart format .` only if a task touches Dart (none here). Never `git add -A`; stage explicit paths.
- Pushing a branch or opening a PR is a stop-and-ask point: get the maintainer's yes in chat first.
- The Write and Edit tools decode a backslash-u escape in their arguments into the real character. `validate.mjs` and `tests/support-matrix-validate.test.mjs` must contain the six-character escape (backslash, `u2014`), never a literal em dash: write those two files with a script, or fix them up after, then check each with `python3 -c "import sys;print(open(sys.argv[1],encoding='utf-8').read().count(chr(0x2014)))" <file>` (expect `0`).

## Review Focus

1. A failure reported on the `fixedIn` version or later must show **Not working**; only a failure from before the fix shows "fixed in vX, awaiting confirmation" (Task 3 test `fixedIn does not excuse a failure on the fixed version`).
2. Two reports for one cell with the same version and date and different outcomes must resolve to the weaker outcome (Task 3 test `same version and date resolves to the weaker outcome`).
3. A diver typing `perdix3`, `Perdix 3` or `puck pro+` must find the model regardless of spacing and punctuation (Task 4 test `search ignores spacing and punctuation`).
4. Clearing every filter must remove the query string from the address bar, not leave the old one (an empty `replaceState` URL keeps it). Task 4 test `urlFor drops an empty query`.
5. A deep link to a model the current filters hide (shared filtered URL plus `#model`) must still land on the model by clearing the filters. Task 4 test `revealTarget clears filters that hide the target`.

---

## Execution order

Tasks run 1, 2, 3, 4, 5, 6, 7, 11, 12, 8, 9, 10. Tasks 11 and 12 (per-model reports through a pre-filled GitHub issue form) were added after Task 7; the numbers are kept so the briefs and ledger lines already written stay valid. Task 11 joins PR 1 and Task 12 joins PR 2.

## File Structure

App repo (`submersion`, this worktree):

| File | Responsibility |
|---|---|
| `scripts/export_support_matrix_catalog.py` | Parse `descriptor.c`, apply platform rules, write `catalog.json` |
| `scripts/export_support_matrix_catalog_test.py` | unittest coverage of the generator |
| `scripts/data/support_matrix_platform_rules.json` | Which libdc transports each platform implements, plus id overrides |
| `.github/workflows/ci.yaml` | Register the new test in the script-tests job |
| `docs/guide/dive-computer.md`, `README.md` | Task 10: point at the matrix |

Website repo (`submersion-website`, a new worktree):

| File | Responsibility |
|---|---|
| `computers/status.js` | Cell status rules (single implementation) |
| `computers/rows.js` | Rows from catalog and reports; sort, search, filters, URL state, deep-link target |
| `computers/render.js` | HTML strings for rows, details, provenance, unsupported list |
| `computers/page.js` | Browser glue: fetch, events, history, hash |
| `computers/index.html`, `computers/page.css` | The page and its styles |
| `computers/data/catalog.json`, `computers/data/reports.json` | Data |
| `tools/support-matrix/validate.mjs` | Data validator (library and CLI) |
| `tools/support-matrix/merge.mjs` | Fold a sweep's candidates into `reports.json` |
| `tools/support-matrix/fixed-in.mjs` | First release tag containing a merge commit |
| `tools/support-matrix/SWEEP.md` | The sweep procedure, initial and monthly |
| `tests/fixtures/support-matrix-catalog.json` | Shared small catalog for JS tests |
| `tests/support-matrix-*.test.mjs` | Tests, picked up by the existing `node --test tests/*.test.mjs` |
| `index.html`, `docs/superpowers/specs/2026-08-23-content-rewrite-design.md` | Homepage link and its claims row |

---

### Task 1: Descriptor parser and catalog builder

**Files:**
- Create: `scripts/export_support_matrix_catalog.py`
- Test: `scripts/export_support_matrix_catalog_test.py`

**Interfaces:**
- Produces: `parse_descriptors(source: str) -> list[tuple[str, str, set[str]]]`; `slugify(vendor: str, product: str) -> str`; `load_rules(text: str) -> dict`; `build_catalog(descriptors, rules: dict, previous_ids=()) -> dict` with keys `models`, `unsupported`, `removed`; `CatalogError(Exception)`; constants `PLATFORMS`, `FAMILIES`, `FLAG_NAMES`.

- [ ] **Step 1: Write the failing tests**

Create `scripts/export_support_matrix_catalog_test.py`:

```python
#!/usr/bin/env python3
"""Unit tests for export_support_matrix_catalog.py."""

import importlib.util
import json
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "export_support_matrix_catalog",
    os.path.join(_HERE, "export_support_matrix_catalog.py"),
)
gen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gen)

RULES = {
    "ios": ["ble"],
    "android": ["ble", "serial"],
    "macos": ["ble", "serial", "usbhid"],
    "windows": ["ble", "serial", "usbhid"],
    "linux": ["ble", "serial", "usbhid"],
    "idOverrides": {"Subgear|XP Air": "subgear-xp-air-irda"},
}

# Entries copied from descriptor.c, formatting quirks included.
TERIC = '{"Shearwater", "Teric",     DC_FAMILY_SHEARWATER_PETREL, 8, DC_TRANSPORT_BLE, dc_filter_shearwater},'
PETREL = '{"Shearwater", "Petrel",    DC_FAMILY_SHEARWATER_PETREL, 3, DC_TRANSPORT_SERIAL | DC_TRANSPORT_BLUETOOTH, dc_filter_shearwater},'
MCLEAN = '{ "McLean", "Extreme", DC_FAMILY_MCLEAN_EXTREME, 0, DC_TRANSPORT_SERIAL | DC_TRANSPORT_BLUETOOTH | DC_TRANSPORT_BLE, dc_filter_mclean},'
VYTEC = '{"Suunto", "Vytec",    DC_FAMILY_SUUNTO_VYPER, 0X0B, DC_TRANSPORT_SERIAL, NULL},'
G2 = '{"Scubapro", "G2",                  DC_FAMILY_UWATEC_SMART, 0x32, DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE, dc_filter_uwatec},'
ALADIN_SQUARE = '{"Scubapro", "Aladin Square",       DC_FAMILY_UWATEC_SMART, 0x22, DC_TRANSPORT_USBHID, dc_filter_uwatec},'
ALADIN_2G_A = '{"Uwatec",   "Aladin 2G",           DC_FAMILY_UWATEC_SMART, 0x13, DC_TRANSPORT_IRDA, dc_filter_uwatec},'
ALADIN_2G_B = '{"Uwatec",   "Aladin 2G",           DC_FAMILY_UWATEC_SMART, 0x15, DC_TRANSPORT_IRDA, dc_filter_uwatec},'
COBALT = '{"Atomic Aquatics", "Cobalt",   DC_FAMILY_ATOMICS_COBALT, 0, DC_TRANSPORT_USB, dc_filter_atomic},'
OC1_A = '{"Oceanic",  "OC1",                 DC_FAMILY_OCEANIC_ATOM2, 0x434E, DC_TRANSPORT_SERIAL, NULL},'
OC1_B = '{"Oceanic",  "OC1",                 DC_FAMILY_OCEANIC_ATOM2, 0x4449, DC_TRANSPORT_SERIAL, NULL},'
OC1_C = '{"Oceanic",  "OC1",                 DC_FAMILY_OCEANIC_ATOM2, 0x4451, DC_TRANSPORT_SERIAL, NULL},'
PUCK_PRO = '{"Mares", "Puck Pro",          DC_FAMILY_MARES_ICONHD , 0x18, DC_TRANSPORT_SERIAL | DC_TRANSPORT_BLE, dc_filter_mares},'
PUCK_PRO_PLUS = '{"Mares", "Puck Pro +",        DC_FAMILY_MARES_ICONHD , 0x18, DC_TRANSPORT_SERIAL | DC_TRANSPORT_BLE, dc_filter_mares},'
XP_AIR_IRDA = '{"Subgear",  "XP Air",              DC_FAMILY_UWATEC_SMART, 0x1C, DC_TRANSPORT_IRDA, dc_filter_uwatec},'
XP_AIR_SERIAL = '{"Subgear",  "XP-Air",              DC_FAMILY_OCEANIC_ATOM2, 0x4555, DC_TRANSPORT_SERIAL, NULL},'
# Synthetic: one product listed twice with different transports.
DUAL_A = '{"Example", "Dual", DC_FAMILY_EXAMPLE, 1, DC_TRANSPORT_SERIAL, NULL},'
DUAL_B = '{"Example", "Dual", DC_FAMILY_EXAMPLE, 2, DC_TRANSPORT_BLE, NULL},'


def table(*lines):
    return (
        "static const dc_descriptor_t g_descriptors[] = {\n"
        + "\n".join("\t" + line for line in lines)
        + "\n};\n"
    )


def build(*lines, rules=RULES, previous_ids=()):
    return gen.build_catalog(gen.parse_descriptors(table(*lines)), rules, previous_ids)


def model(catalog, model_id):
    return next(m for m in catalog["models"] if m["id"] == model_id)


class ParseTest(unittest.TestCase):
    def test_reads_vendor_product_and_transports(self):
        self.assertEqual(
            gen.parse_descriptors(table(TERIC, PETREL)),
            [
                ("Shearwater", "Teric", {"ble"}),
                ("Shearwater", "Petrel", {"serial", "bluetooth"}),
            ],
        )

    def test_tolerates_the_tables_formatting(self):
        parsed = gen.parse_descriptors(table(MCLEAN, VYTEC))
        self.assertEqual(
            [(v, p) for v, p, _ in parsed], [("McLean", "Extreme"), ("Suunto", "Vytec")]
        )

    def test_skips_commented_out_entries(self):
        parsed = gen.parse_descriptors(table("/* " + TERIC + " */", "// " + G2, VYTEC))
        self.assertEqual([p for _, p, _ in parsed], ["Vytec"])

    def test_unknown_flag_is_an_error(self):
        line = TERIC.replace("DC_TRANSPORT_BLE", "DC_TRANSPORT_WIFI")
        with self.assertRaises(gen.CatalogError):
            gen.parse_descriptors(table(line))

    def test_missing_table_is_an_error(self):
        with self.assertRaises(gen.CatalogError):
            gen.parse_descriptors("int main(void) { return 0; }")


class SlugTest(unittest.TestCase):
    def test_slugs(self):
        self.assertEqual(gen.slugify("Mares", "Puck Pro +"), "mares-puck-pro-plus")
        self.assertEqual(gen.slugify("Heinrichs Weikamp", "OSTC 2N"), "heinrichs-weikamp-ostc-2n")
        self.assertEqual(gen.slugify("Subgear", "XP-Air"), "subgear-xp-air")


class BuildTest(unittest.TestCase):
    def test_ble_only_model_is_bluetooth_everywhere(self):
        teric = model(build(TERIC), "shearwater-teric")
        self.assertEqual(teric["platforms"], {p: ["bluetooth"] for p in gen.PLATFORMS})

    def test_hid_and_ble_is_bluetooth_on_mobile_and_both_on_desktop(self):
        g2 = model(build(G2), "scubapro-g2")
        self.assertEqual(g2["platforms"]["ios"], ["bluetooth"])
        self.assertEqual(g2["platforms"]["android"], ["bluetooth"])
        for platform in ("macos", "windows", "linux"):
            self.assertEqual(g2["platforms"][platform], ["bluetooth", "usb"])

    def test_hid_only_is_na_on_mobile(self):
        square = model(build(ALADIN_SQUARE), "scubapro-aladin-square")
        self.assertEqual(square["platforms"]["ios"], [])
        self.assertEqual(square["platforms"]["android"], [])
        self.assertEqual(square["platforms"]["macos"], ["usb"])

    def test_classic_and_serial_gets_no_bluetooth(self):
        petrel = model(build(PETREL), "shearwater-petrel")
        self.assertEqual(petrel["platforms"]["ios"], [])
        self.assertEqual(petrel["platforms"]["android"], ["usb"])
        self.assertEqual(petrel["platforms"]["macos"], ["usb"])

    def test_irda_only_is_unsupported(self):
        catalog = build(ALADIN_2G_A, TERIC)
        self.assertEqual([m["id"] for m in catalog["models"]], ["shearwater-teric"])
        self.assertEqual(
            catalog["unsupported"],
            [{"id": "uwatec-aladin-2g", "vendor": "Uwatec", "product": "Aladin 2G", "reason": "irda-only"}],
        )

    def test_raw_usb_only_is_unsupported(self):
        catalog = build(COBALT)
        self.assertEqual(catalog["models"], [])
        self.assertEqual(catalog["unsupported"][0]["reason"], "raw-usb-only")

    def test_identical_pairs_merge(self):
        catalog = build(OC1_A, OC1_B, OC1_C, ALADIN_2G_A, ALADIN_2G_B)
        self.assertEqual([m["id"] for m in catalog["models"]], ["oceanic-oc1"])
        self.assertEqual(len(catalog["unsupported"]), 1)

    def test_merged_pairs_take_the_union_of_transports(self):
        dual = model(build(DUAL_A, DUAL_B), "example-dual")
        self.assertEqual(dual["libdc"], ["ble", "serial"])
        self.assertEqual(dual["platforms"]["android"], ["bluetooth", "usb"])

    def test_punctuation_variants_get_distinct_ids(self):
        ids = [m["id"] for m in build(PUCK_PRO, PUCK_PRO_PLUS)["models"]]
        self.assertEqual(ids, ["mares-puck-pro", "mares-puck-pro-plus"])

    def test_id_override_resolves_a_collision(self):
        catalog = build(XP_AIR_IRDA, XP_AIR_SERIAL)
        self.assertEqual([m["id"] for m in catalog["models"]], ["subgear-xp-air"])
        self.assertEqual(catalog["unsupported"][0]["id"], "subgear-xp-air-irda")

    def test_unresolved_collision_is_an_error_naming_both(self):
        rules = dict(RULES, idOverrides={})
        with self.assertRaises(gen.CatalogError) as raised:
            build(XP_AIR_IRDA, XP_AIR_SERIAL, rules=rules)
        self.assertIn("Subgear XP Air", str(raised.exception))
        self.assertIn("Subgear XP-Air", str(raised.exception))

    def test_removed_lists_ids_no_longer_present(self):
        catalog = build(TERIC, ALADIN_2G_A, previous_ids=["shearwater-teric", "uwatec-aladin-2g", "gone-model"])
        self.assertEqual(catalog["removed"], ["gone-model"])

    def test_models_sorted_by_vendor_then_product(self):
        ids = [m["id"] for m in build(TERIC, G2, PETREL)["models"]]
        self.assertEqual(ids, ["scubapro-g2", "shearwater-petrel", "shearwater-teric"])

    def test_libdc_lists_raw_transports_in_fixed_order(self):
        self.assertEqual(model(build(MCLEAN), "mclean-extreme")["libdc"], ["ble", "bluetooth", "serial"])


class RulesTest(unittest.TestCase):
    def test_rejects_a_missing_platform(self):
        rules = {k: v for k, v in RULES.items() if k != "linux"}
        with self.assertRaises(gen.CatalogError):
            gen.load_rules(json.dumps(rules))

    def test_rejects_an_unknown_transport(self):
        rules = dict(RULES, ios=["ble", "wifi"])
        with self.assertRaises(gen.CatalogError):
            gen.load_rules(json.dumps(rules))

    def test_the_committed_rules_file_is_the_spec(self):
        with open(gen.DEFAULT_RULES, encoding="utf-8") as handle:
            self.assertEqual(gen.load_rules(handle.read()), RULES)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3.14 scripts/export_support_matrix_catalog_test.py`
Expected: error, `FileNotFoundError` for `export_support_matrix_catalog.py`.

- [ ] **Step 3: Write the implementation and the rules file**

Create `scripts/data/support_matrix_platform_rules.json`:

```json
{
  "ios": ["ble"],
  "android": ["ble", "serial"],
  "macos": ["ble", "serial", "usbhid"],
  "windows": ["ble", "serial", "usbhid"],
  "linux": ["ble", "serial", "usbhid"],
  "idOverrides": {
    "Subgear|XP Air": "subgear-xp-air-irda"
  }
}
```

Create `scripts/export_support_matrix_catalog.py`:

```python
#!/usr/bin/env python3
"""Export the dive computer support matrix catalog for submersion.app/computers.

Reads libdivecomputer's descriptor table and the per-platform transport rules
in scripts/data/support_matrix_platform_rules.json, and writes catalog.json:
every model, and the transport families each platform can reach for it.

Usage:
  python3 scripts/export_support_matrix_catalog.py --out catalog.json \
      [--previous old-catalog.json]
"""

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone

_HERE = os.path.dirname(os.path.abspath(__file__))
_ROOT = os.path.dirname(_HERE)
LIBDC_DIR = os.path.join(
    _ROOT, "packages", "libdivecomputer_plugin", "third_party", "libdivecomputer"
)
DEFAULT_DESCRIPTOR = os.path.join(LIBDC_DIR, "src", "descriptor.c")
DEFAULT_RULES = os.path.join(_HERE, "data", "support_matrix_platform_rules.json")

PLATFORMS = ("ios", "android", "macos", "windows", "linux")
FAMILIES = ("bluetooth", "usb")

# libdc's DC_TRANSPORT_* flags (include/libdivecomputer/common.h).
FLAG_NAMES = {
    "DC_TRANSPORT_SERIAL": "serial",
    "DC_TRANSPORT_USB": "usb",
    "DC_TRANSPORT_USBHID": "usbhid",
    "DC_TRANSPORT_IRDA": "irda",
    "DC_TRANSPORT_BLUETOOTH": "bluetooth",
    "DC_TRANSPORT_BLE": "ble",
}
TRANSPORT_ORDER = ("ble", "bluetooth", "serial", "usb", "usbhid", "irda")

# The family a libdc transport is shown under. Bluetooth Classic and IrDA have
# no entry because no platform implements them.
FAMILY_OF = {"ble": "bluetooth", "serial": "usb", "usb": "usb", "usbhid": "usb"}

_TABLE = re.compile(r"g_descriptors\[\]\s*=\s*\{(.*?)\n\};", re.S)
_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
_LINE_COMMENT = re.compile(r"//[^\n]*")
_ENTRY = re.compile(
    r'\{\s*"([^"]*)"\s*,\s*"([^"]*)"\s*,\s*\w+\s*,\s*\w+\s*,'
    r"\s*([A-Z_|\s]+?)\s*,\s*\w+\s*\}"
)


class CatalogError(Exception):
    """The inputs cannot produce a trustworthy catalog."""


def parse_descriptors(source):
    """Returns (vendor, product, transport names) for each table entry."""
    table = _TABLE.search(source)
    if table is None:
        raise CatalogError("g_descriptors[] table not found")
    body = _LINE_COMMENT.sub("", _BLOCK_COMMENT.sub("", table.group(1)))
    entries = []
    for vendor, product, flags in _ENTRY.findall(body):
        transports = set()
        for flag in flags.split("|"):
            name = FLAG_NAMES.get(flag.strip())
            if name is None:
                raise CatalogError(
                    "unknown transport flag %s on %s %s" % (flag.strip(), vendor, product)
                )
            transports.add(name)
        entries.append((vendor, product, transports))
    return entries


def slugify(vendor, product):
    text = ("%s %s" % (vendor, product)).lower().replace("+", " plus ")
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")


def load_rules(text):
    rules = json.loads(text)
    known = set(FLAG_NAMES.values())
    for platform in PLATFORMS:
        transports = rules.get(platform)
        if not isinstance(transports, list):
            raise CatalogError("rules: %s is missing" % platform)
        unknown = sorted(set(transports) - known)
        if unknown:
            raise CatalogError("rules: %s lists unknown transports %s" % (platform, unknown))
    if not isinstance(rules.get("idOverrides", {}), dict):
        raise CatalogError("rules: idOverrides must be an object")
    return rules


def _families(transports, allowed):
    found = {FAMILY_OF[t] for t in transports if t in allowed and t in FAMILY_OF}
    return [family for family in FAMILIES if family in found]


def _unsupported_reason(transports):
    if transports == {"irda"}:
        return "irda-only"
    if transports == {"usb"}:
        return "raw-usb-only"
    return "no-implemented-transport"


def build_catalog(descriptors, rules, previous_ids=()):
    merged = {}
    for vendor, product, transports in descriptors:
        merged.setdefault((vendor, product), set()).update(transports)

    overrides = rules.get("idOverrides", {})
    owners = {}
    models = []
    unsupported = []
    for (vendor, product), transports in sorted(
        merged.items(), key=lambda item: (item[0][0].lower(), item[0][1].lower())
    ):
        name = "%s %s" % (vendor, product)
        model_id = overrides.get("%s|%s" % (vendor, product)) or slugify(vendor, product)
        if model_id in owners:
            raise CatalogError(
                '"%s" and "%s" both have the id %s; add an idOverrides entry'
                % (owners[model_id], name, model_id)
            )
        owners[model_id] = name
        platforms = {p: _families(transports, rules[p]) for p in PLATFORMS}
        if any(platforms.values()):
            models.append(
                {
                    "id": model_id,
                    "vendor": vendor,
                    "product": product,
                    "libdc": [t for t in TRANSPORT_ORDER if t in transports],
                    "platforms": platforms,
                }
            )
        else:
            unsupported.append(
                {
                    "id": model_id,
                    "vendor": vendor,
                    "product": product,
                    "reason": _unsupported_reason(transports),
                }
            )
    removed = sorted(set(previous_ids) - set(owners))
    return {"models": models, "unsupported": unsupported, "removed": removed}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3.14 scripts/export_support_matrix_catalog_test.py && python3 scripts/export_support_matrix_catalog_test.py`
Expected: `OK` from both (3.14 and the 3.9 system interpreter).

- [ ] **Step 5: Commit**

```bash
git add scripts/export_support_matrix_catalog.py scripts/export_support_matrix_catalog_test.py scripts/data/support_matrix_platform_rules.json
git commit -m "feat(support-matrix): build the computer catalog from libdivecomputer's descriptor table

Refs #2616"
```

---

### Task 2: Generator CLI, provenance and CI registration

**Files:**
- Modify: `scripts/export_support_matrix_catalog.py` (append CLI)
- Modify: `scripts/export_support_matrix_catalog_test.py` (append `MainTest`)
- Modify: `.github/workflows/ci.yaml` (script-tests job, "Run Python guard tests with coverage" step, around line 556)

**Interfaces:**
- Consumes: everything Task 1 produces.
- Produces: `git_head(path: str) -> str`; `main(argv=None) -> int`; CLI `--descriptor`, `--rules`, `--previous`, `--out` (required), `--min-descriptors` (default 300). Output JSON key order: `generatedFrom` (`appCommit`, `libdcCommit`, `generatedAt`), `models`, `unsupported`, `removed`.

- [ ] **Step 1: Write the failing tests**

Add these imports to the top of the test file, beside the existing ones:

```python
import contextlib
import io
import tempfile
from unittest import mock
```

Append before the `if __name__` block:

```python
class MainTest(unittest.TestCase):
    def run_main(self, *lines, extra=()):
        with tempfile.TemporaryDirectory() as tmp:
            descriptor = os.path.join(tmp, "descriptor.c")
            with open(descriptor, "w", encoding="utf-8") as handle:
                handle.write(table(*lines))
            out = os.path.join(tmp, "catalog.json")
            argv = ["--descriptor", descriptor, "--out", out, "--min-descriptors", "1"]
            argv += list(extra)
            stderr = io.StringIO()
            with mock.patch.object(gen, "git_head", return_value="a" * 40), contextlib.redirect_stderr(
                stderr
            ), contextlib.redirect_stdout(io.StringIO()):
                code = gen.main(argv)
            written = None
            if os.path.exists(out):
                with open(out, encoding="utf-8") as handle:
                    written = json.load(handle)
            return code, written, stderr.getvalue(), tmp

    def test_writes_a_catalog_with_provenance(self):
        code, catalog, _, _ = self.run_main(TERIC, ALADIN_2G_A)
        self.assertEqual(code, 0)
        self.assertEqual(list(catalog), ["generatedFrom", "models", "unsupported", "removed"])
        self.assertEqual(catalog["generatedFrom"]["appCommit"], "a" * 40)
        self.assertEqual(catalog["generatedFrom"]["libdcCommit"], "a" * 40)
        self.assertRegex(catalog["generatedFrom"]["generatedAt"], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    def test_refuses_a_table_below_the_minimum(self):
        code, catalog, stderr, _ = self.run_main(TERIC, extra=["--min-descriptors", "5"])
        self.assertEqual(code, 1)
        self.assertIsNone(catalog)
        self.assertIn("only 1 descriptors", stderr)

    def test_previous_catalog_feeds_removed(self):
        with tempfile.TemporaryDirectory() as tmp:
            previous = os.path.join(tmp, "previous.json")
            with open(previous, "w", encoding="utf-8") as handle:
                json.dump({"models": [{"id": "gone-model"}], "unsupported": []}, handle)
            code, catalog, _, _ = self.run_main(TERIC, extra=["--previous", previous])
        self.assertEqual(code, 0)
        self.assertEqual(catalog["removed"], ["gone-model"])

    def test_a_collision_exits_non_zero_without_writing(self):
        with tempfile.TemporaryDirectory() as tmp:
            rules = os.path.join(tmp, "rules.json")
            with open(rules, "w", encoding="utf-8") as handle:
                json.dump(dict(RULES, idOverrides={}), handle)
            code, catalog, stderr, _ = self.run_main(XP_AIR_IRDA, XP_AIR_SERIAL, extra=["--rules", rules])
        self.assertEqual(code, 1)
        self.assertIsNone(catalog)
        self.assertIn("idOverrides", stderr)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3.14 scripts/export_support_matrix_catalog_test.py`
Expected: FAIL, `AttributeError: ... has no attribute 'git_head'` (or `main`).

- [ ] **Step 3: Append the CLI to the generator**

```python
def git_head(path):
    try:
        result = subprocess.run(
            ["git", "-C", path, "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        )
    except (OSError, subprocess.CalledProcessError) as error:
        raise CatalogError("cannot read the git commit of %s: %s" % (path, error))
    return result.stdout.strip()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--descriptor", default=DEFAULT_DESCRIPTOR)
    parser.add_argument("--rules", default=DEFAULT_RULES)
    parser.add_argument("--previous", help="the catalog.json this one replaces")
    parser.add_argument("--out", required=True)
    parser.add_argument("--min-descriptors", type=int, default=300)
    args = parser.parse_args(argv)
    try:
        with open(args.descriptor, encoding="utf-8") as handle:
            descriptors = parse_descriptors(handle.read())
        if len(descriptors) < args.min_descriptors:
            raise CatalogError(
                "only %d descriptors parsed (expected at least %d); "
                "the table format may have changed" % (len(descriptors), args.min_descriptors)
            )
        with open(args.rules, encoding="utf-8") as handle:
            rules = load_rules(handle.read())
        previous_ids = ()
        if args.previous:
            with open(args.previous, encoding="utf-8") as handle:
                previous = json.load(handle)
            previous_ids = [m["id"] for m in previous["models"] + previous.get("unsupported", [])]
        catalog = build_catalog(descriptors, rules, previous_ids)
        libdc_dir = os.path.dirname(os.path.dirname(os.path.abspath(args.descriptor)))
        generated_from = {
            "appCommit": git_head(_ROOT),
            "libdcCommit": git_head(libdc_dir),
            "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        }
    except (OSError, ValueError, KeyError, CatalogError) as error:
        print("error: %s" % error, file=sys.stderr)
        return 1
    output = {"generatedFrom": generated_from}
    output.update(catalog)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(output, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    print(
        "%d models, %d unsupported, %d removed -> %s"
        % (len(catalog["models"]), len(catalog["unsupported"]), len(catalog["removed"]), args.out)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3.14 scripts/export_support_matrix_catalog_test.py && python3 scripts/export_support_matrix_catalog_test.py`
Expected: `OK` from both.

- [ ] **Step 5: Register the test in CI**

In `.github/workflows/ci.yaml`, in the "Run Python guard tests with coverage" step:
1. Append `,scripts/export_support_matrix_catalog.py` inside the `guards='...'` string, before the closing quote.
2. After the `scripts/filter_trivial_coverage_test.py` run (the last `coverage run --append` before `coverage report`), add:

```yaml
          python3 -m coverage run --append --include="$guards" \
            scripts/export_support_matrix_catalog_test.py
```

Run: `grep -n "export_support_matrix_catalog" .github/workflows/ci.yaml`
Expected: two hits (the guards list and the run line).

- [ ] **Step 6: Run the generator against the real table**

The libdc submodule must be initialized (`git submodule update --init --recursive` if `packages/libdivecomputer_plugin/third_party/libdivecomputer/src/descriptor.c` is missing).

Run: `python3.14 scripts/export_support_matrix_catalog.py --out "$SCRATCH/catalog.json"`, where `$SCRATCH` is the session scratchpad directory (never a literal `/tmp`).
Expected: `329 models, 20 unsupported, 0 removed -> .../catalog.json`. Then spot-check:

Run: `python3.14 -c "import json,sys;c=json.load(open(sys.argv[1]));print([m for m in c['models'] if m['id'] in ('scubapro-g2','shearwater-perdix-3')]);print(sorted(u['reason'] for u in c['unsupported']).count('raw-usb-only'))" "$SCRATCH/catalog.json"`
Expected: G2 with `ios: ["bluetooth"]` and `macos: ["bluetooth", "usb"]`; Perdix 3 `bluetooth` on all five; `2`.

- [ ] **Step 7: Commit**

```bash
git add scripts/export_support_matrix_catalog.py scripts/export_support_matrix_catalog_test.py .github/workflows/ci.yaml
git commit -m "feat(support-matrix): add the catalog generator CLI and run its tests in CI

Refs #2616"
```

- [ ] **Step 8: Stop and ask before opening PR 1**

Ask the maintainer to approve pushing `ericgriffin/bluetooth-usb-support-matrix-2012fc` and opening PR 1 (spec, plan, generator). Body: a Summary of the generator and rules, "Refs #2616", Screenshots section deleted (no UI paths touched). No attribution lines.

---

### Task 3: Website worktree and cell status rules

**Files:**
- Create: `computers/status.js`
- Test: `tests/support-matrix-status.test.mjs`

**Interfaces:**
- Produces: `STATUS` (`verified`, `issues`, `not-working`, `untested`, `na`); `compareVersions(a: string|null, b: string|null) -> -1|0|1`; `newestFirst(a, b) -> number` (sort comparator); `cellStatus(reports: Report[], reachable: boolean) -> { status, reports?, latest?, label? }`. `reports` in the result is sorted newest first; absent for `na` and `untested`.

- [ ] **Step 1: Create the website worktree**

The website clone at `/Users/ericgriffin/repos/submersion-app/submersion-website` is behind `origin/main`. This session's file tools may only write inside granted directories: call `mcp__ccd_directory__request_directory` for `/Users/ericgriffin/repos/submersion-app/submersion-website-support-matrix` first if writes there are refused.

```bash
git -C /Users/ericgriffin/repos/submersion-app/submersion-website fetch origin
git -C /Users/ericgriffin/repos/submersion-app/submersion-website worktree add -b ericgriffin/support-matrix-page /Users/ericgriffin/repos/submersion-app/submersion-website-support-matrix origin/main
```

All website paths below are relative to that worktree (`$WEB`). Confirm: `node --version` reports 22 or later, and `node --test tests/*.test.mjs` passes before any change.

- [ ] **Step 2: Write the failing tests**

Create `tests/support-matrix-status.test.mjs`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";

import { STATUS, cellStatus, compareVersions } from "../computers/status.js";

const report = (over = {}) => ({
  model: "shearwater-perdix-3",
  platform: "android",
  transport: "bluetooth",
  outcome: "works",
  appVersion: "1.8.0",
  date: "2026-09-01",
  source: "github-issue",
  url: "https://github.com/submersion-app/submersion/issues/723",
  sourceRef: null,
  fixedIn: null,
  note: "Downloaded 40 dives",
  ...over,
});

test("an unreachable cell is n/a even with reports", () => {
  assert.equal(cellStatus([report()], false).status, STATUS.NA);
});

test("a reachable cell with no reports is untested", () => {
  assert.equal(cellStatus([], true).status, STATUS.UNTESTED);
});

test("a linkable works report verifies", () => {
  assert.equal(cellStatus([report()], true).status, STATUS.VERIFIED);
});

test("works reported only in store reviews is not verified", () => {
  const cell = cellStatus(
    [report({ source: "app-store", url: "https://apps.apple.com/us/app/submersion-dive-log/id6757456915", sourceRef: "appstore:us:1" })],
    true,
  );
  assert.equal(cell.status, STATUS.ISSUES);
  assert.equal(cell.label, "Reported working only in app store reviews");
});

test("a newer store review over an older linkable works still verifies", () => {
  const store = report({ appVersion: "1.8.1", source: "play-store", url: "https://play.google.com/store/apps/details?id=app.submersion", sourceRef: "play:1" });
  assert.equal(cellStatus([report(), store], true).status, STATUS.VERIFIED);
});

test("caveats is issues", () => {
  assert.equal(cellStatus([report({ outcome: "caveats" })], true).status, STATUS.ISSUES);
});

test("an unfixed failure is not working", () => {
  assert.equal(cellStatus([report({ outcome: "fails" })], true).status, STATUS.NOT_WORKING);
});

test("a failure from before its fix awaits confirmation", () => {
  const cell = cellStatus([report({ outcome: "fails", appVersion: "1.8.0", fixedIn: "1.8.1" })], true);
  assert.equal(cell.status, STATUS.ISSUES);
  assert.equal(cell.label, "Fixed in v1.8.1, awaiting confirmation");
});

test("a failure with no version and a fix awaits confirmation", () => {
  const cell = cellStatus([report({ outcome: "fails", appVersion: null, fixedIn: "1.8.1" })], true);
  assert.equal(cell.status, STATUS.ISSUES);
});

test("fixedIn does not excuse a failure on the fixed version", () => {
  const onFixed = cellStatus([report({ outcome: "fails", appVersion: "1.8.1", fixedIn: "1.8.1" })], true);
  const after = cellStatus([report({ outcome: "fails", appVersion: "1.8.2", fixedIn: "1.8.1" })], true);
  assert.equal(onFixed.status, STATUS.NOT_WORKING);
  assert.equal(after.status, STATUS.NOT_WORKING);
});

test("a merged but unreleased fix is still not working", () => {
  const cell = cellStatus([report({ outcome: "fails", fixedIn: "unreleased" })], true);
  assert.equal(cell.status, STATUS.NOT_WORKING);
  assert.equal(cell.label, "Fix pending release");
});

test("app version outranks date", () => {
  const oldBuildLater = report({ outcome: "fails", appVersion: "1.6.0", date: "2026-09-20" });
  const newBuildEarlier = report({ outcome: "works", appVersion: "1.8.0", date: "2026-09-01", url: "https://github.com/submersion-app/submersion/issues/1" });
  const cell = cellStatus([oldBuildLater, newBuildEarlier], true);
  assert.equal(cell.status, STATUS.VERIFIED);
  assert.equal(cell.latest, newBuildEarlier);
});

test("a missing version sorts oldest", () => {
  const unknown = report({ outcome: "fails", appVersion: null, date: "2026-09-30" });
  assert.equal(cellStatus([unknown, report()], true).status, STATUS.VERIFIED);
});

test("same version and date resolves to the weaker outcome", () => {
  const works = report();
  const fails = report({ outcome: "fails", url: "https://github.com/submersion-app/submersion/issues/2" });
  assert.equal(cellStatus([works, fails], true).status, STATUS.NOT_WORKING);
  assert.equal(cellStatus([fails, works], true).status, STATUS.NOT_WORKING);
});

test("reports come back newest first", () => {
  const a = report({ appVersion: "1.7.0" });
  const b = report({ appVersion: "1.8.0", url: "https://github.com/submersion-app/submersion/issues/3" });
  assert.deepEqual(cellStatus([a, b], true).reports, [b, a]);
});

test("compareVersions is numeric, part by part", () => {
  assert.equal(compareVersions("1.7.10", "1.7.9"), 1);
  assert.equal(compareVersions("1.8", "1.8.0"), 0);
  assert.equal(compareVersions(null, "0.0.1"), -1);
  assert.equal(compareVersions(null, null), 0);
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `node --test tests/support-matrix-status.test.mjs`
Expected: FAIL, `Cannot find module '.../computers/status.js'`.

- [ ] **Step 4: Write the implementation**

Create `computers/status.js`:

```js
// Cell status for the support matrix: the one place that decides what a cell
// shows. The rules are in the app repo's spec,
// docs/superpowers/specs/2026-10-02-dive-computer-support-matrix-design.md.

export const STATUS = Object.freeze({
  VERIFIED: "verified",
  ISSUES: "issues",
  NOT_WORKING: "not-working",
  UNTESTED: "untested",
  NA: "na",
});

// Store reviews have no public permalink, so they cannot verify a cell alone.
const UNLINKABLE = new Set(["app-store", "play-store"]);

// Lower is weaker; the weaker outcome wins a tie.
const STRENGTH = { fails: 0, caveats: 1, works: 2 };

// Dotted numeric versions, compared part by part; null sorts oldest.
export function compareVersions(a, b) {
  if (a == null || b == null) return a == null && b == null ? 0 : a == null ? -1 : 1;
  const left = a.split(".").map(Number);
  const right = b.split(".").map(Number);
  for (let i = 0; i < Math.max(left.length, right.length); i++) {
    const diff = (left[i] ?? 0) - (right[i] ?? 0);
    if (diff !== 0) return Math.sign(diff);
  }
  return 0;
}

// Sort comparator: newest app version, then newest date, then weakest outcome.
export function newestFirst(a, b) {
  return (
    compareVersions(b.appVersion, a.appVersion) ||
    (a.date === b.date ? 0 : a.date > b.date ? -1 : 1) ||
    STRENGTH[a.outcome] - STRENGTH[b.outcome]
  );
}

export function cellStatus(reports, reachable) {
  if (!reachable) return { status: STATUS.NA };
  if (reports.length === 0) return { status: STATUS.UNTESTED };
  const sorted = [...reports].sort(newestFirst);
  const latest = sorted[0];
  const result = (status, label) => ({ status, reports: sorted, latest, ...(label ? { label } : {}) });
  switch (latest.outcome) {
    case "works":
      return reports.some((r) => r.outcome === "works" && !UNLINKABLE.has(r.source))
        ? result(STATUS.VERIFIED)
        : result(STATUS.ISSUES, "Reported working only in app store reviews");
    case "caveats":
      return result(STATUS.ISSUES);
    case "fails":
      if (latest.fixedIn === "unreleased") return result(STATUS.NOT_WORKING, "Fix pending release");
      if (latest.fixedIn && compareVersions(latest.appVersion, latest.fixedIn) < 0) {
        return result(STATUS.ISSUES, `Fixed in v${latest.fixedIn}, awaiting confirmation`);
      }
      return result(STATUS.NOT_WORKING);
    default:
      throw new Error(`unknown outcome ${latest.outcome}`);
  }
}
```

Note `compareVersions(null, "1.8.1")` is `-1`, so a failure with no version and a fix awaits confirmation, as the test requires.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `node --test tests/support-matrix-status.test.mjs`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add computers/status.js tests/support-matrix-status.test.mjs
git commit -m "feat(computers): add the support matrix cell status rules"
```

---

### Task 4: Rows, search, filters and URL state

**Files:**
- Create: `computers/rows.js`
- Create: `tests/fixtures/support-matrix-catalog.json`
- Test: `tests/support-matrix-rows.test.mjs`

**Interfaces:**
- Consumes: `cellStatus` from `computers/status.js`.
- Produces: `PLATFORMS`, `FAMILIES`, `STATUSES` (arrays); `buildRows(catalog, reports) -> Row[]` where `Row = { id, vendor, product, family, cells: { [platform]: CellStatus }, hasEvidence }` (`hasEvidence` is per model: true on every row of a model with any report); `filterRows(rows, state) -> Row[]`; `vendorsOf(rows) -> string[]`; `parseState(search: string) -> State`; `stateToSearch(state) -> string` (`""` or `"?..."`); `urlFor(pathname, state, hash) -> string`; `revealTarget(rows, state, id) -> State|null` (null when `id` is not a model; `state` unchanged when a row of `id` passes the filters; otherwise an empty state). `State = { q, brand, platform, status, transport }`, all strings, `""` when unset.

- [ ] **Step 1: Write the shared fixture**

Create `tests/fixtures/support-matrix-catalog.json`:

```json
{
  "generatedFrom": {
    "appCommit": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    "libdcCommit": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
    "generatedAt": "2026-10-02T00:00:00Z"
  },
  "models": [
    {
      "id": "scubapro-aladin-square",
      "vendor": "Scubapro",
      "product": "Aladin Square",
      "libdc": ["usbhid"],
      "platforms": { "ios": [], "android": [], "macos": ["usb"], "windows": ["usb"], "linux": ["usb"] }
    },
    {
      "id": "scubapro-g2",
      "vendor": "Scubapro",
      "product": "G2",
      "libdc": ["ble", "usbhid"],
      "platforms": {
        "ios": ["bluetooth"],
        "android": ["bluetooth"],
        "macos": ["bluetooth", "usb"],
        "windows": ["bluetooth", "usb"],
        "linux": ["bluetooth", "usb"]
      }
    },
    {
      "id": "shearwater-perdix-3",
      "vendor": "Shearwater",
      "product": "Perdix 3",
      "libdc": ["ble"],
      "platforms": {
        "ios": ["bluetooth"],
        "android": ["bluetooth"],
        "macos": ["bluetooth"],
        "windows": ["bluetooth"],
        "linux": ["bluetooth"]
      }
    },
    {
      "id": "mares-puck-pro-plus",
      "vendor": "Mares",
      "product": "Puck Pro +",
      "libdc": ["ble", "serial"],
      "platforms": {
        "ios": ["bluetooth"],
        "android": ["bluetooth", "usb"],
        "macos": ["bluetooth", "usb"],
        "windows": ["bluetooth", "usb"],
        "linux": ["bluetooth", "usb"]
      }
    }
  ],
  "unsupported": [
    { "id": "uwatec-aladin-2g", "vendor": "Uwatec", "product": "Aladin 2G", "reason": "irda-only" }
  ],
  "removed": []
}
```

- [ ] **Step 2: Write the failing tests**

Create `tests/support-matrix-rows.test.mjs`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  buildRows,
  filterRows,
  parseState,
  revealTarget,
  stateToSearch,
  urlFor,
  vendorsOf,
} from "../computers/rows.js";

const catalog = JSON.parse(
  readFileSync(new URL("./fixtures/support-matrix-catalog.json", import.meta.url), "utf8"),
);

const report = (over = {}) => ({
  model: "shearwater-perdix-3",
  platform: "android",
  transport: "bluetooth",
  outcome: "works",
  appVersion: "1.8.0",
  date: "2026-09-01",
  source: "github-issue",
  url: "https://github.com/submersion-app/submersion/issues/723",
  sourceRef: null,
  fixedIn: null,
  note: "Downloaded 40 dives",
  ...over,
});

const EMPTY = { q: "", brand: "", platform: "", status: "", transport: "" };
const keys = (rows) => rows.map((r) => `${r.id}/${r.family}`);

test("one row per reachable family, n/a where a platform cannot reach it", () => {
  const rows = buildRows(catalog, []);
  assert.deepEqual(keys(rows), [
    "mares-puck-pro-plus/bluetooth",
    "mares-puck-pro-plus/usb",
    "scubapro-aladin-square/usb",
    "scubapro-g2/bluetooth",
    "scubapro-g2/usb",
    "shearwater-perdix-3/bluetooth",
  ]);
  const square = rows.find((r) => r.id === "scubapro-aladin-square");
  assert.equal(square.cells.ios.status, "na");
  assert.equal(square.cells.macos.status, "untested");
});

test("reports land in their cell", () => {
  const rows = buildRows(catalog, [report()]);
  const perdix = rows.find((r) => r.id === "shearwater-perdix-3");
  assert.equal(perdix.cells.android.status, "verified");
  assert.equal(perdix.cells.ios.status, "untested");
});

test("a model with evidence sorts first within its vendor, rows kept together", () => {
  const rows = buildRows(catalog, [report({ model: "scubapro-g2", platform: "macos", transport: "usb" })]);
  assert.deepEqual(keys(rows).slice(2, 5), [
    "scubapro-g2/bluetooth",
    "scubapro-g2/usb",
    "scubapro-aladin-square/usb",
  ]);
  assert.equal(rows.find((r) => r.id === "scubapro-g2" && r.family === "bluetooth").hasEvidence, true);
});

test("search ignores spacing and punctuation", () => {
  const rows = buildRows(catalog, []);
  const find = (q) => keys(filterRows(rows, { ...EMPTY, q }));
  assert.deepEqual(find("perdix3"), ["shearwater-perdix-3/bluetooth"]);
  assert.deepEqual(find("Perdix 3"), ["shearwater-perdix-3/bluetooth"]);
  assert.deepEqual(find("shear 3"), ["shearwater-perdix-3/bluetooth"]);
  assert.equal(find("puck pro+").length, 2);
});

test("brand and transport filters", () => {
  const rows = buildRows(catalog, []);
  assert.deepEqual(keys(filterRows(rows, { ...EMPTY, brand: "Shearwater" })), ["shearwater-perdix-3/bluetooth"]);
  assert.deepEqual(keys(filterRows(rows, { ...EMPTY, brand: "Scubapro", transport: "usb" })), [
    "scubapro-aladin-square/usb",
    "scubapro-g2/usb",
  ]);
});

test("a platform filter hides rows that are n/a there", () => {
  const rows = buildRows(catalog, []);
  const ios = keys(filterRows(rows, { ...EMPTY, platform: "ios" }));
  assert.ok(!ios.includes("scubapro-aladin-square/usb"));
  assert.ok(!ios.includes("scubapro-g2/usb"));
});

test("status filters a platform's cell, or any cell when no platform is set", () => {
  const rows = buildRows(catalog, [report()]);
  assert.deepEqual(keys(filterRows(rows, { ...EMPTY, platform: "android", status: "verified" })), [
    "shearwater-perdix-3/bluetooth",
  ]);
  assert.deepEqual(keys(filterRows(rows, { ...EMPTY, platform: "ios", status: "verified" })), []);
  assert.deepEqual(keys(filterRows(rows, { ...EMPTY, status: "verified" })), ["shearwater-perdix-3/bluetooth"]);
  assert.equal(filterRows(rows, { ...EMPTY, status: "na" }).length, 3);
});

test("vendorsOf lists each vendor once, sorted", () => {
  assert.deepEqual(vendorsOf(buildRows(catalog, [])), ["Mares", "Scubapro", "Shearwater"]);
});

test("parseState keeps known values and drops unknown ones", () => {
  assert.deepEqual(parseState("?q=perdix&platform=ios&status=bogus&transport=usb&brand=Mares"), {
    q: "perdix",
    brand: "Mares",
    platform: "ios",
    status: "",
    transport: "usb",
  });
});

test("stateToSearch round-trips and omits empty values", () => {
  const state = { ...EMPTY, q: "puck pro +", platform: "android" };
  assert.deepEqual(parseState(stateToSearch(state)), state);
  assert.equal(stateToSearch(EMPTY), "");
});

test("urlFor drops an empty query", () => {
  assert.equal(urlFor("/computers/", EMPTY, "#scubapro-g2"), "/computers/#scubapro-g2");
  assert.equal(urlFor("/computers/", { ...EMPTY, q: "g2" }, ""), "/computers/?q=g2");
});

test("revealTarget keeps filters that already show the target", () => {
  const rows = buildRows(catalog, []);
  const state = { ...EMPTY, brand: "Scubapro" };
  assert.deepEqual(revealTarget(rows, state, "scubapro-g2"), state);
});

test("revealTarget clears filters that hide the target", () => {
  const rows = buildRows(catalog, []);
  assert.deepEqual(revealTarget(rows, { ...EMPTY, brand: "Mares" }, "scubapro-g2"), EMPTY);
});

test("revealTarget ignores a hash that is not a model", () => {
  assert.equal(revealTarget(buildRows(catalog, []), EMPTY, "content"), null);
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `node --test tests/support-matrix-rows.test.mjs`
Expected: FAIL, `Cannot find module '.../computers/rows.js'`.

- [ ] **Step 4: Write the implementation**

Create `computers/rows.js`:

```js
// Rows, search, filters and URL state for the support matrix. Pure, so the
// tests drive it without a browser; page.js wires it to the page.
import { cellStatus } from "./status.js";

export const PLATFORMS = ["ios", "android", "macos", "windows", "linux"];
export const FAMILIES = ["bluetooth", "usb"];
export const STATUSES = ["verified", "issues", "not-working", "untested", "na"];
const STATE_KEYS = ["q", "brand", "platform", "status", "transport"];
const ENUMS = { platform: PLATFORMS, status: STATUSES, transport: FAMILIES };

const byText = (a, b) => a.localeCompare(b, "en", { sensitivity: "base", numeric: true });
const squash = (text) => text.toLowerCase().replace(/[^a-z0-9]+/g, "");

export function buildRows(catalog, reports) {
  const byCell = new Map();
  for (const r of reports) {
    const key = `${r.model}|${r.transport}|${r.platform}`;
    if (!byCell.has(key)) byCell.set(key, []);
    byCell.get(key).push(r);
  }
  const rows = [];
  for (const model of catalog.models) {
    for (const family of FAMILIES) {
      if (!PLATFORMS.some((p) => model.platforms[p].includes(family))) continue;
      const cells = {};
      for (const p of PLATFORMS) {
        cells[p] = cellStatus(byCell.get(`${model.id}|${family}|${p}`) ?? [], model.platforms[p].includes(family));
      }
      rows.push({ id: model.id, vendor: model.vendor, product: model.product, family, cells, hasEvidence: false });
    }
  }
  const withEvidence = new Set(
    rows.filter((row) => PLATFORMS.some((p) => row.cells[p].reports)).map((row) => row.id),
  );
  return rows
    .map((row) => ({ ...row, hasEvidence: withEvidence.has(row.id) }))
    .sort(
      (a, b) =>
        byText(a.vendor, b.vendor) ||
        Number(b.hasEvidence) - Number(a.hasEvidence) ||
        byText(a.product, b.product) ||
        FAMILIES.indexOf(a.family) - FAMILIES.indexOf(b.family),
    );
}

export function filterRows(rows, state) {
  const tokens = (state.q ?? "").split(/\s+/).map(squash).filter(Boolean);
  return rows.filter((row) => {
    const text = squash(`${row.vendor} ${row.product}`);
    if (!tokens.every((token) => text.includes(token))) return false;
    if (state.brand && row.vendor !== state.brand) return false;
    if (state.transport && row.family !== state.transport) return false;
    if (state.platform && !state.status && row.cells[state.platform].status === "na") return false;
    const platforms = state.platform ? [state.platform] : PLATFORMS;
    if (state.status && !platforms.some((p) => row.cells[p].status === state.status)) return false;
    return true;
  });
}

export function vendorsOf(rows) {
  return [...new Set(rows.map((row) => row.vendor))].sort(byText);
}

export function parseState(search) {
  const params = new URLSearchParams(search);
  const state = {};
  for (const key of STATE_KEYS) {
    const value = params.get(key) ?? "";
    state[key] = ENUMS[key] && !ENUMS[key].includes(value) ? "" : value;
  }
  return state;
}

export function stateToSearch(state) {
  const params = new URLSearchParams();
  for (const key of STATE_KEYS) if (state[key]) params.set(key, state[key]);
  const text = params.toString();
  return text ? `?${text}` : "";
}

// The address to replaceState to. An empty string there would keep the old
// query, so the path is always spelled out.
export function urlFor(pathname, state, hash) {
  return `${pathname}${stateToSearch(state)}${hash}`;
}

// Filters to apply so the model in the hash is on screen: the current ones
// when they show it, none when they hide it, null when the hash is no model.
export function revealTarget(rows, state, id) {
  if (!rows.some((row) => row.id === id)) return null;
  if (filterRows(rows, state).some((row) => row.id === id)) return state;
  return Object.fromEntries(STATE_KEYS.map((key) => [key, ""]));
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `node --test tests/support-matrix-rows.test.mjs tests/support-matrix-status.test.mjs`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add computers/rows.js tests/support-matrix-rows.test.mjs tests/fixtures/support-matrix-catalog.json
git commit -m "feat(computers): build, search and filter support matrix rows"
```

---

### Task 5: Markup rendering

**Files:**
- Create: `computers/render.js`
- Test: `tests/support-matrix-render.test.mjs`

**Interfaces:**
- Consumes: `PLATFORMS` from `rows.js`; `Row` objects from `buildRows`.
- Produces: `escapeHtml(value) -> string`; `sourceText(report) -> string`; `renderRows(rows) -> string` (`<tr>` elements for a `<tbody>`); `renderDetail(row, platform) -> string` (one `<tr class="detail">`); `renderBrandOptions(vendors) -> string`; `renderUnsupported(unsupported) -> string`; `renderProvenance(generatedFrom) -> string`; `STATUS_TEXT`, `PLATFORM_TEXT`, `FAMILY_TEXT`. Cell buttons carry `data-cell="<id>|<family>|<platform>"`; the first row of each model carries `id="<model id>"`; every row carries `data-model="<model id>"`.

- [ ] **Step 1: Write the failing tests**

Create `tests/support-matrix-render.test.mjs`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import { buildRows } from "../computers/rows.js";
import {
  escapeHtml,
  renderBrandOptions,
  renderDetail,
  renderProvenance,
  renderRows,
  renderUnsupported,
  sourceText,
} from "../computers/render.js";

const catalog = JSON.parse(
  readFileSync(new URL("./fixtures/support-matrix-catalog.json", import.meta.url), "utf8"),
);

const report = (over = {}) => ({
  model: "shearwater-perdix-3",
  platform: "android",
  transport: "bluetooth",
  outcome: "works",
  appVersion: "1.8.0",
  date: "2026-09-01",
  source: "github-issue",
  url: "https://github.com/submersion-app/submersion/issues/723",
  sourceRef: null,
  fixedIn: null,
  note: "Downloaded 40 dives",
  ...over,
});

test("escapeHtml escapes the five characters", () => {
  assert.equal(escapeHtml(`<a href="x">'&'</a>`), "&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;");
});

test("rows are grouped under vendor headings", () => {
  const html = renderRows(buildRows(catalog, []));
  const vendors = [...html.matchAll(/<tr class="vendor"><th colspan="7" scope="colgroup">([^<]+)</g)].map((m) => m[1]);
  assert.deepEqual(vendors, ["Mares", "Scubapro", "Shearwater"]);
});

test("only a model's first row carries its id", () => {
  const html = renderRows(buildRows(catalog, []));
  assert.equal(html.match(/id="scubapro-g2"/g).length, 1);
  assert.equal(html.match(/data-model="scubapro-g2"/g).length, 2);
});

test("cells without reports are text, cells with reports are buttons", () => {
  const html = renderRows(buildRows(catalog, [report()]));
  assert.match(html, /<span class="cell cell--na">n\/a<\/span>/);
  assert.match(html, /<span class="cell cell--untested">Untested<\/span>/);
  assert.match(
    html,
    /<button type="button" class="cell cell--verified" data-cell="shearwater-perdix-3\|bluetooth\|android" aria-expanded="false" aria-label="Shearwater Perdix 3, Bluetooth, Android: Verified\. Show reports">Verified<\/button>/,
  );
});

test("data values are escaped", () => {
  const evil = { ...catalog, models: [{ ...catalog.models[2], product: "<img src=x onerror=alert(1)>" }] };
  const html = renderRows(buildRows(evil, []));
  assert.ok(!html.includes("<img"));
  assert.match(html, /&lt;img src=x onerror=alert\(1\)&gt;/);
});

test("detail lists reports newest first with sources and fix state", () => {
  const rows = buildRows(catalog, [
    report({ appVersion: "1.7.2", outcome: "fails", fixedIn: "1.7.3", note: "Name not <recognized>" }),
    report({ appVersion: "1.8.0", url: "https://scubaboard.com/community/threads/x.667061/post-1", source: "scubaboard" }),
  ]);
  const html = renderDetail(rows.find((r) => r.id === "shearwater-perdix-3"), "android");
  assert.match(html, /^<tr class="detail" data-cell="shearwater-perdix-3\|bluetooth\|android"><td colspan="7">/);
  assert.match(html, /<h3>Shearwater Perdix 3 · Bluetooth · Android<\/h3>/);
  const scuba = html.indexOf("ScubaBoard post");
  const github = html.indexOf("GitHub #723");
  assert.ok(scuba > 0 && github > scuba, "newest report first");
  assert.match(html, /Name not &lt;recognized&gt;/);
  assert.match(html, /Fixed in v1\.7\.3\./);
  assert.match(html, /rel="noreferrer"/);
});

test("sourceText names each source", () => {
  assert.equal(sourceText(report()), "GitHub #723");
  assert.equal(sourceText(report({ source: "github-pr", url: "https://github.com/submersion-app/submersion/pull/1465" })), "GitHub #1465");
  assert.equal(sourceText(report({ source: "github-discussion" })), "GitHub discussion");
  assert.equal(sourceText(report({ source: "reddit" })), "Reddit");
  assert.equal(sourceText(report({ source: "app-store" })), "App Store review");
  assert.equal(sourceText(report({ source: "play-store" })), "Google Play review");
});

test("brand options, unsupported list and provenance", () => {
  assert.equal(renderBrandOptions(["Mares", "A&B"]), '<option value="Mares">Mares</option><option value="A&amp;B">A&amp;B</option>');
  assert.equal(renderUnsupported(catalog.unsupported), "<li>Uwatec Aladin 2G</li>");
  const html = renderProvenance(catalog.generatedFrom);
  assert.match(html, /href="https:\/\/github\.com\/submersion-app\/libdivecomputer\/commit\/b{40}"/);
  assert.match(html, /href="https:\/\/github\.com\/submersion-app\/submersion\/commit\/a{40}"/);
  assert.match(html, /2026-10-02/);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test tests/support-matrix-render.test.mjs`
Expected: FAIL, `Cannot find module '.../computers/render.js'`.

- [ ] **Step 3: Write the implementation**

Create `computers/render.js`:

```js
// Markup for the support matrix, as HTML strings so node --test can check it
// without a browser. Every value that comes from the data passes through
// escapeHtml.
import { PLATFORMS } from "./rows.js";

const ESCAPES = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
export const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (c) => ESCAPES[c]);

export const STATUS_TEXT = {
  verified: "Verified",
  issues: "Issues",
  "not-working": "Not working",
  untested: "Untested",
  na: "n/a",
};
export const PLATFORM_TEXT = { ios: "iOS", android: "Android", macos: "macOS", windows: "Windows", linux: "Linux" };
export const FAMILY_TEXT = { bluetooth: "Bluetooth", usb: "USB" };
const OUTCOME_TEXT = { works: "Works", caveats: "Works with caveats", fails: "Fails" };

export function sourceText(report) {
  switch (report.source) {
    case "github-issue":
    case "github-pr": {
      const number = /\/(?:issues|pull)\/(\d+)/.exec(report.url);
      return number ? `GitHub #${number[1]}` : "GitHub";
    }
    case "github-discussion":
      return "GitHub discussion";
    case "scubaboard":
      return "ScubaBoard post";
    case "reddit":
      return "Reddit";
    case "app-store":
      return "App Store review";
    case "play-store":
      return "Google Play review";
    default:
      return "Source";
  }
}

function cellHtml(row, platform) {
  const cell = row.cells[platform];
  const text = STATUS_TEXT[cell.status];
  const cls = `cell cell--${cell.status}`;
  if (!cell.reports) return `<span class="${cls}">${text}</span>`;
  const key = escapeHtml(`${row.id}|${row.family}|${platform}`);
  const label = escapeHtml(
    `${row.vendor} ${row.product}, ${FAMILY_TEXT[row.family]}, ${PLATFORM_TEXT[platform]}: ${text}. Show reports`,
  );
  return `<button type="button" class="${cls}" data-cell="${key}" aria-expanded="false" aria-label="${label}">${text}</button>`;
}

export function renderRows(rows) {
  const out = [];
  const seen = new Set();
  let vendor = null;
  for (const row of rows) {
    if (row.vendor !== vendor) {
      vendor = row.vendor;
      out.push(`<tr class="vendor"><th colspan="7" scope="colgroup">${escapeHtml(vendor)}</th></tr>`);
    }
    const anchor = seen.has(row.id) ? "" : ` id="${escapeHtml(row.id)}"`;
    seen.add(row.id);
    const cells = PLATFORMS.map(
      (p) => `<td class="platform" data-label="${PLATFORM_TEXT[p]}">${cellHtml(row, p)}</td>`,
    ).join("");
    out.push(
      `<tr data-model="${escapeHtml(row.id)}"${anchor}><th scope="row">${escapeHtml(row.product)}</th>` +
        `<td class="transport">${FAMILY_TEXT[row.family]}</td>${cells}</tr>`,
    );
  }
  return out.join("\n");
}

function fixText(report) {
  if (report.fixedIn === "unreleased") return " Fix merged, not released yet.";
  if (report.fixedIn) return ` Fixed in v${report.fixedIn}.`;
  return "";
}

export function renderDetail(row, platform) {
  const cell = row.cells[platform];
  const items = cell.reports
    .map((r) => {
      const version = r.appVersion ? `v${r.appVersion}` : "version not stated";
      return (
        `<li><strong>${OUTCOME_TEXT[r.outcome]}</strong> · ${escapeHtml(version)} · ${escapeHtml(r.date)}<br>` +
        `${escapeHtml(r.note)}${escapeHtml(fixText(r))} ` +
        `<a href="${escapeHtml(r.url)}" target="_blank" rel="noreferrer">${escapeHtml(sourceText(r))}</a></li>`
      );
    })
    .join("");
  const label = cell.label ? `<p>${escapeHtml(cell.label)}</p>` : "";
  const key = escapeHtml(`${row.id}|${row.family}|${platform}`);
  const title = `${escapeHtml(`${row.vendor} ${row.product}`)} · ${FAMILY_TEXT[row.family]} · ${PLATFORM_TEXT[platform]}`;
  return `<tr class="detail" data-cell="${key}"><td colspan="7"><h3>${title}</h3>${label}<ul>${items}</ul></td></tr>`;
}

export function renderBrandOptions(vendors) {
  return vendors.map((v) => `<option value="${escapeHtml(v)}">${escapeHtml(v)}</option>`).join("");
}

export function renderUnsupported(unsupported) {
  return unsupported.map((m) => `<li>${escapeHtml(m.vendor)} ${escapeHtml(m.product)}</li>`).join("");
}

export function renderProvenance(generatedFrom) {
  const link = (repo, sha) =>
    `<a href="https://github.com/submersion-app/${repo}/commit/${escapeHtml(sha)}">${escapeHtml(sha.slice(0, 7))}</a>`;
  return (
    `Built from libdivecomputer ${link("libdivecomputer", generatedFrom.libdcCommit)} and Submersion ` +
    `${link("submersion", generatedFrom.appCommit)}, last updated ${escapeHtml(generatedFrom.generatedAt.slice(0, 10))}.`
  );
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `node --test tests/support-matrix-render.test.mjs`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add computers/render.js tests/support-matrix-render.test.mjs
git commit -m "feat(computers): render support matrix rows and report details"
```

---

### Task 6: Data validator, merge and fixedIn tools

**Files:**
- Create: `tools/support-matrix/validate.mjs`, `tools/support-matrix/merge.mjs`, `tools/support-matrix/fixed-in.mjs`
- Test: `tests/support-matrix-validate.test.mjs`, `tests/support-matrix-tools.test.mjs`

**Interfaces:**
- Consumes: `PLATFORMS`, `FAMILIES` from `computers/rows.js`.
- Produces: `validate(catalog, data) -> string[]` (empty when valid); `cellKey(report) -> string`; `OUTCOMES`; `SOURCES` (source to allowed hosts); `mergeReports(existing, sweep) -> { data, added, duplicates }`; `sortReports(reports) -> Report[]`; `firstRelease(tags: string[]) -> string` (`"X.Y.Z"` or `"unreleased"`). CLIs: `node tools/support-matrix/validate.mjs` (exit 1 on problems), `node tools/support-matrix/merge.mjs <sweep.json>`, `node tools/support-matrix/fixed-in.mjs <app-repo> <sha>...`.

- [ ] **Step 1: Write the failing validator tests**

Create `tests/support-matrix-validate.test.mjs`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import { validate } from "../tools/support-matrix/validate.mjs";

const catalog = JSON.parse(
  readFileSync(new URL("./fixtures/support-matrix-catalog.json", import.meta.url), "utf8"),
);

const report = (over = {}) => ({
  model: "shearwater-perdix-3",
  platform: "android",
  transport: "bluetooth",
  outcome: "works",
  appVersion: "1.8.0",
  date: "2026-09-01",
  source: "github-issue",
  url: "https://github.com/submersion-app/submersion/issues/723",
  sourceRef: null,
  fixedIn: null,
  note: "Downloaded 40 dives",
  ...over,
});
const data = (...reports) => ({ watermarks: {}, reports });
const problems = (...reports) => validate(catalog, data(...reports));
const one = (over, pattern) => {
  const errors = problems(report(over));
  assert.equal(errors.length, 1, errors.join("\n"));
  assert.match(errors[0], pattern);
};

test("valid data has no problems", () => {
  assert.deepEqual(problems(report(), report({ platform: "ios", url: "https://github.com/submersion-app/submersion/issues/1" })), []);
});

test("missing watermarks", () => {
  assert.match(validate(catalog, { reports: [] })[0], /watermarks missing/);
});

test("unknown model", () => one({ model: "nope" }, /unknown model/));
test("unsupported model", () => one({ model: "uwatec-aladin-2g" }, /unsupported on every platform/));
test("unknown platform", () => one({ platform: "symbian" }, /unknown platform/));
test("unknown transport", () => one({ transport: "irda" }, /unknown transport/));
test("unreachable family", () => one({ model: "scubapro-aladin-square", platform: "ios", transport: "usb" }, /usb is not reachable on ios/));
test("unknown outcome", () => one({ outcome: "great" }, /unknown outcome/));
test("unknown source", () => one({ source: "forum" }, /unknown source/));
test("non-https url", () => one({ url: "javascript:alert(1)" }, /not an https URL/));
test("http url", () => one({ url: "http://github.com/x" }, /not an https URL/));
test("host must match source", () => one({ source: "reddit" }, /does not match source reddit/));
test("reddit subdomains are fine", () => assert.deepEqual(problems(report({ source: "reddit", url: "https://www.reddit.com/r/submersion/comments/abc/x/def/" })), []));
test("store review needs a sourceRef", () =>
  one({ source: "app-store", url: "https://apps.apple.com/us/app/submersion-dive-log/id6757456915" }, /needs a sourceRef/));
test("only store reviews carry a sourceRef", () => one({ sourceRef: "x" }, /only store reviews/));
test("appVersion must be a version", () => one({ appVersion: "1.8-beta" }, /appVersion/));
test("appVersion must be present", () => {
  const r = report();
  delete r.appVersion;
  assert.match(problems(r)[0], /appVersion/);
});
test("fixedIn must be a version or unreleased", () => one({ fixedIn: "soon" }, /fixedIn/));
test("date must be YYYY-MM-DD", () => one({ date: "Sept 1" }, /date/));
test("note length", () => one({ note: "x".repeat(121) }, /note must be 1 to 120/));
test("note without an em dash", () => one({ note: "works \u2014 mostly" }, /em dash/));
test("duplicates", () => {
  const errors = problems(report(), report());
  assert.equal(errors.length, 1);
  assert.match(errors[0], /duplicate/);
});
test("store duplicates key on sourceRef, not the shared listing url", () => {
  const store = (ref) => report({ source: "app-store", url: "https://apps.apple.com/us/app/submersion-dive-log/id6757456915", sourceRef: ref });
  assert.deepEqual(problems(store("appstore:us:1"), store("appstore:us:2")), []);
});
```

- [ ] **Step 2: Write the failing tools tests**

Create `tests/support-matrix-tools.test.mjs`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";

import { mergeReports } from "../tools/support-matrix/merge.mjs";
import { firstRelease } from "../tools/support-matrix/fixed-in.mjs";

const report = (over = {}) => ({
  model: "shearwater-perdix-3",
  platform: "android",
  transport: "bluetooth",
  outcome: "works",
  appVersion: "1.8.0",
  date: "2026-09-01",
  source: "github-issue",
  url: "https://github.com/submersion-app/submersion/issues/723",
  sourceRef: null,
  fixedIn: null,
  note: "Downloaded 40 dives",
  ...over,
});

test("merge adds new reports and skips ones already recorded", () => {
  const existing = { watermarks: { github: { since: "2026-09-01T00:00:00Z" } }, reports: [report()] };
  const fresh = report({ platform: "ios", url: "https://github.com/submersion-app/submersion/issues/9" });
  const result = mergeReports(existing, { reports: [report(), fresh], watermarks: {} });
  assert.equal(result.added, 1);
  assert.equal(result.duplicates, 1);
  assert.equal(result.data.reports.length, 2);
});

test("merge keeps only report fields and fills nullable ones", () => {
  const candidate = { ...report({ platform: "ios" }), modelText: "Perdix 3", fixedBy: 1465 };
  delete candidate.sourceRef;
  delete candidate.fixedIn;
  const [merged] = mergeReports({ watermarks: {}, reports: [] }, { reports: [candidate] }).data.reports;
  assert.deepEqual(Object.keys(merged), [
    "model", "platform", "transport", "outcome", "appVersion", "date", "source", "url", "sourceRef", "fixedIn", "note",
  ]);
  assert.equal(merged.sourceRef, null);
  assert.equal(merged.fixedIn, null);
});

test("merge replaces only the watermarks the sweep reports", () => {
  const existing = { watermarks: { scubaboard: { lastPostId: 1 }, reddit: { lastCreatedUtc: 5 } }, reports: [] };
  const { data } = mergeReports(existing, { reports: [], watermarks: { reddit: { lastCreatedUtc: 9 } } });
  assert.deepEqual(data.watermarks, { scubaboard: { lastPostId: 1 }, reddit: { lastCreatedUtc: 9 } });
});

test("merge output order is stable", () => {
  const a = report({ model: "b-model" });
  const b = report({ model: "a-model", url: "https://github.com/submersion-app/submersion/issues/2" });
  const { data } = mergeReports({ watermarks: {}, reports: [a] }, { reports: [b] });
  assert.deepEqual(data.reports.map((r) => r.model), ["a-model", "b-model"]);
});

test("firstRelease picks the lowest version tag and drops the build", () => {
  assert.equal(firstRelease(["v1.8.0.8404", "v1.7.10.8264", "pre-rebase-228", "v1.7.9.8162", ""]), "1.7.9");
  assert.equal(firstRelease(["v1.7.10", "v1.7.9.1"]), "1.7.9");
});

test("firstRelease with no release tag is unreleased", () => {
  assert.equal(firstRelease(["pre-rebase-228", ""]), "unreleased");
  assert.equal(firstRelease([]), "unreleased");
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `node --test tests/support-matrix-validate.test.mjs tests/support-matrix-tools.test.mjs`
Expected: FAIL, modules not found.

- [ ] **Step 4: Write the validator**

Create `tools/support-matrix/validate.mjs`:

```js
// Checks the support matrix data before it can merge: every report points at
// a real, reachable cell, uses known values, links where its source says it
// does, and appears once. Run: node tools/support-matrix/validate.mjs
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { FAMILIES, PLATFORMS } from "../../computers/rows.js";

export const OUTCOMES = ["works", "caveats", "fails"];
export const SOURCES = {
  scubaboard: ["scubaboard.com"],
  "github-issue": ["github.com"],
  "github-pr": ["github.com"],
  "github-discussion": ["github.com"],
  reddit: ["reddit.com"],
  "app-store": ["apps.apple.com"],
  "play-store": ["play.google.com"],
};
const STORE_SOURCES = new Set(["app-store", "play-store"]);
const VERSION = /^\d+(\.\d+){0,3}$/;
const DATE = /^\d{4}-\d{2}-\d{2}$/;
const EM_DASH = "\u2014";

const hostMatches = (host, allowed) => allowed.some((a) => host === a || host.endsWith(`.${a}`));

// Two reports are the same evidence when they share a source item and a cell.
// Store reviews share the listing url, so their review id identifies them.
export const cellKey = (r) => [r.sourceRef ?? r.url, r.model, r.platform, r.transport].join("|");

function httpsHost(url) {
  try {
    const parsed = new URL(url);
    return parsed.protocol === "https:" ? parsed.hostname : null;
  } catch {
    return null;
  }
}

export function validate(catalog, data) {
  const errors = [];
  const models = new Map();
  for (const m of [...catalog.models, ...(catalog.unsupported ?? [])]) {
    if (models.has(m.id)) errors.push(`catalog: duplicate id ${m.id}`);
    models.set(m.id, m);
  }
  if (typeof data.watermarks !== "object" || data.watermarks === null) errors.push("reports: watermarks missing");
  if (!Array.isArray(data.reports)) return [...errors, "reports: reports is not a list"];

  const seen = new Set();
  data.reports.forEach((r, i) => {
    const at = `reports[${i}] (${r.model} ${r.platform} ${r.transport})`;
    const model = models.get(r.model);
    if (!model) errors.push(`${at}: unknown model`);
    else if (!model.platforms) errors.push(`${at}: model is unsupported on every platform`);
    if (!PLATFORMS.includes(r.platform)) errors.push(`${at}: unknown platform`);
    if (!FAMILIES.includes(r.transport)) errors.push(`${at}: unknown transport`);
    if (model?.platforms && PLATFORMS.includes(r.platform) && FAMILIES.includes(r.transport)) {
      if (!model.platforms[r.platform].includes(r.transport)) {
        errors.push(`${at}: ${r.transport} is not reachable on ${r.platform}`);
      }
    }
    if (!OUTCOMES.includes(r.outcome)) errors.push(`${at}: unknown outcome ${r.outcome}`);
    if (!(r.source in SOURCES)) {
      errors.push(`${at}: unknown source ${r.source}`);
    } else {
      const host = httpsHost(r.url);
      if (!host) errors.push(`${at}: url is not an https URL`);
      else if (!hostMatches(host, SOURCES[r.source])) errors.push(`${at}: url host ${host} does not match source ${r.source}`);
      const store = STORE_SOURCES.has(r.source);
      if (store && !r.sourceRef) errors.push(`${at}: a store review needs a sourceRef`);
      if (!store && r.sourceRef != null) errors.push(`${at}: only store reviews carry a sourceRef`);
    }
    if (r.appVersion !== null && !VERSION.test(String(r.appVersion))) {
      errors.push(`${at}: appVersion ${r.appVersion} is not a version or null`);
    }
    if (r.fixedIn != null && r.fixedIn !== "unreleased" && !VERSION.test(String(r.fixedIn))) {
      errors.push(`${at}: fixedIn ${r.fixedIn} is not a version or "unreleased"`);
    }
    if (!DATE.test(String(r.date))) errors.push(`${at}: date ${r.date} is not YYYY-MM-DD`);
    if (typeof r.note !== "string" || r.note.length === 0 || r.note.length > 120) {
      errors.push(`${at}: note must be 1 to 120 characters`);
    } else if (r.note.includes(EM_DASH)) {
      errors.push(`${at}: note contains an em dash`);
    }
    const key = cellKey(r);
    if (seen.has(key)) errors.push(`${at}: duplicate of an earlier report`);
    seen.add(key);
  });
  return errors;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const read = (path) => JSON.parse(readFileSync(new URL(`../../${path}`, import.meta.url), "utf8"));
  const errors = validate(read("computers/data/catalog.json"), read("computers/data/reports.json"));
  for (const error of errors) console.error(error);
  console.log(errors.length ? `${errors.length} problem(s)` : "support matrix data is valid");
  process.exit(errors.length ? 1 : 0);
}
```

- [ ] **Step 5: Write the merge and fixed-in tools**

Create `tools/support-matrix/merge.mjs`:

```js
// Folds a sweep's candidate reports into computers/data/reports.json: drops
// ones already recorded, keeps only report fields, keeps a stable order so
// monthly diffs stay small, and advances only the watermarks the sweep sets.
//   node tools/support-matrix/merge.mjs <sweep.json>
// sweep.json is { "reports": [...], "watermarks": { "<source>": {...} } }.
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { cellKey } from "./validate.mjs";

const FIELDS = ["model", "platform", "transport", "outcome", "appVersion", "date", "source", "url", "sourceRef", "fixedIn", "note"];
const NULLABLE = new Set(["appVersion", "sourceRef", "fixedIn"]);
const ORDER = ["model", "transport", "platform", "date", "url", "sourceRef"];

const pick = (r) => Object.fromEntries(FIELDS.map((f) => [f, r[f] ?? (NULLABLE.has(f) ? null : r[f])]));

export function sortReports(reports) {
  return [...reports].sort((a, b) => {
    for (const key of ORDER) {
      const x = String(a[key] ?? "");
      const y = String(b[key] ?? "");
      if (x !== y) return x < y ? -1 : 1;
    }
    return 0;
  });
}

export function mergeReports(existing, sweep) {
  const seen = new Set(existing.reports.map(cellKey));
  const added = [];
  let duplicates = 0;
  for (const candidate of sweep.reports ?? []) {
    const report = pick(candidate);
    const key = cellKey(report);
    if (seen.has(key)) {
      duplicates++;
      continue;
    }
    seen.add(key);
    added.push(report);
  }
  return {
    data: {
      watermarks: { ...existing.watermarks, ...(sweep.watermarks ?? {}) },
      reports: sortReports([...existing.reports, ...added]),
    },
    added: added.length,
    duplicates,
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const target = new URL("../../computers/data/reports.json", import.meta.url);
  const existing = JSON.parse(readFileSync(target, "utf8"));
  const sweep = JSON.parse(readFileSync(process.argv[2], "utf8"));
  const { data, added, duplicates } = mergeReports(existing, sweep);
  writeFileSync(target, `${JSON.stringify(data, null, 2)}\n`);
  console.log(`added ${added}, skipped ${duplicates} already recorded`);
}
```

Create `tools/support-matrix/fixed-in.mjs`:

```js
// The first release containing a fix, for a report's fixedIn.
//   node tools/support-matrix/fixed-in.mjs <app-repo-checkout> <merge-sha>...
// Prints "<sha> <X.Y.Z|unreleased>" per sha. The checkout needs its tags
// (git fetch --tags).
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const RELEASE = /^v(\d+)\.(\d+)\.(\d+)(?:\.\d+)?$/;

export function firstRelease(tags) {
  const versions = tags
    .map((tag) => RELEASE.exec(tag.trim()))
    .filter(Boolean)
    .map((m) => [Number(m[1]), Number(m[2]), Number(m[3])])
    .sort((a, b) => a[0] - b[0] || a[1] - b[1] || a[2] - b[2]);
  return versions.length ? versions[0].join(".") : "unreleased";
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [repo, ...shas] = process.argv.slice(2);
  for (const sha of shas) {
    const tags = execFileSync("git", ["-C", repo, "tag", "--contains", sha], { encoding: "utf8" }).split("\n");
    console.log(`${sha} ${firstRelease(tags)}`);
  }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `node --test tests/support-matrix-validate.test.mjs tests/support-matrix-tools.test.mjs`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add tools/support-matrix/validate.mjs tools/support-matrix/merge.mjs tools/support-matrix/fixed-in.mjs tests/support-matrix-validate.test.mjs tests/support-matrix-tools.test.mjs
git commit -m "feat(computers): validate, merge and date-stamp support matrix reports"
```

---

### Task 7: The page, its data, and the homepage link

**Files:**
- Create: `computers/index.html`, `computers/page.css`, `computers/page.js`
- Create: `computers/data/catalog.json` (generated), `computers/data/reports.json`
- Create: `tests/support-matrix-data.test.mjs`
- Modify: `index.html` (the `#computer` zone's "350+ models" feature, around line 131)
- Modify: `docs/superpowers/specs/2026-08-23-content-rewrite-design.md` (verified-claims "Tested computers" row, around line 47)

**Interfaces:**
- Consumes: `buildRows`, `filterRows`, `parseState`, `urlFor`, `revealTarget`, `vendorsOf` (rows.js); `renderRows`, `renderDetail`, `renderBrandOptions`, `renderUnsupported`, `renderProvenance` (render.js); `validate` (validate.mjs).
- Produces: the published page. Element ids page.js relies on: `q`, `brand`, `platform`, `status`, `transport`, `count`, `error`, `rows`, `updated`, `provenance`, `unsupported`.

- [ ] **Step 1: Write the failing data test**

Create `tests/support-matrix-data.test.mjs`:

```js
// The committed support matrix data must pass the validator, so a sweep PR
// with a broken reference fails here instead of on the live page.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import { validate } from "../tools/support-matrix/validate.mjs";

const read = (path) => JSON.parse(readFileSync(new URL(`../${path}`, import.meta.url), "utf8"));

test("the committed support matrix data is valid", () => {
  assert.deepEqual(validate(read("computers/data/catalog.json"), read("computers/data/reports.json")), []);
});

test("the catalog is a full generator run", () => {
  const catalog = read("computers/data/catalog.json");
  assert.ok(catalog.models.length > 300, `only ${catalog.models.length} models`);
  assert.match(catalog.generatedFrom.appCommit, /^[0-9a-f]{40}$/);
  assert.match(catalog.generatedFrom.libdcCommit, /^[0-9a-f]{40}$/);
});
```

Run: `node --test tests/support-matrix-data.test.mjs`
Expected: FAIL, `ENOENT` for `computers/data/catalog.json`.

- [ ] **Step 2: Generate the catalog and an empty reports file**

From the app worktree (the generator must be committed there, Task 2):

```bash
mkdir -p /Users/ericgriffin/repos/submersion-app/submersion-website-support-matrix/computers/data
python3.14 /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/quizzical-taussig-4088e1/scripts/export_support_matrix_catalog.py --out /Users/ericgriffin/repos/submersion-app/submersion-website-support-matrix/computers/data/catalog.json
```

Expected: `329 models, 20 unsupported, 0 removed -> ...`.

Create `computers/data/reports.json`:

```json
{
  "watermarks": {},
  "reports": []
}
```

Run: `node --test tests/support-matrix-data.test.mjs`
Expected: PASS.

- [ ] **Step 3: Write `computers/page.js`**

```js
// Browser glue for the support matrix: loads the data, keeps the address bar
// in step with the controls, opens a cell's reports, and follows #model deep
// links. The rules live in status.js, rows.js and render.js.
import { buildRows, filterRows, parseState, revealTarget, urlFor, vendorsOf } from "./rows.js";
import { renderBrandOptions, renderDetail, renderProvenance, renderRows, renderUnsupported } from "./render.js";

const CONTROLS = ["q", "brand", "platform", "status", "transport"];
const $ = (id) => document.getElementById(id);

async function fetchJson(path) {
  const response = await fetch(path, { cache: "no-cache" });
  if (!response.ok) throw new Error(`${path}: HTTP ${response.status}`);
  return response.json();
}

const readControls = () => Object.fromEntries(CONTROLS.map((id) => [id, $(id).value.trim()]));

function writeControls(state) {
  for (const id of CONTROLS) $(id).value = state[id] ?? "";
}

function start(catalog, reports) {
  const allRows = buildRows(catalog, reports.reports);
  const byKey = new Map(allRows.map((row) => [`${row.id}|${row.family}`, row]));

  $("brand").insertAdjacentHTML("beforeend", renderBrandOptions(vendorsOf(allRows)));
  $("updated").textContent = `Last updated ${catalog.generatedFrom.generatedAt.slice(0, 10)}.`;
  $("provenance").innerHTML = renderProvenance(catalog.generatedFrom);
  $("unsupported").innerHTML = renderUnsupported(catalog.unsupported);

  function show() {
    const rows = filterRows(allRows, readControls());
    $("rows").innerHTML = renderRows(rows);
    $("count").textContent = `Showing ${rows.length} of ${allRows.length} rows.`;
  }

  function followHash() {
    const id = decodeURIComponent(location.hash.slice(1));
    const state = id ? revealTarget(allRows, readControls(), id) : null;
    if (!state) return;
    writeControls(state);
    history.replaceState(null, "", urlFor(location.pathname, state, location.hash));
    show();
    const targets = document.querySelectorAll(`tr[data-model="${CSS.escape(id)}"]`);
    targets.forEach((tr) => tr.classList.add("is-target"));
    targets[0]?.scrollIntoView({ block: "center" });
  }

  for (const id of CONTROLS) {
    $(id).addEventListener("input", () => {
      history.replaceState(null, "", urlFor(location.pathname, readControls(), location.hash));
      show();
    });
  }

  $("rows").addEventListener("click", (event) => {
    const button = event.target.closest("button[data-cell]");
    if (!button) return;
    const row = button.closest("tr");
    const open = row.nextElementSibling?.classList.contains("detail") ? row.nextElementSibling : null;
    const reopening = open?.dataset.cell === button.dataset.cell;
    if (open) {
      open.remove();
      row.querySelectorAll('button[aria-expanded="true"]').forEach((b) => b.setAttribute("aria-expanded", "false"));
    }
    if (reopening) return;
    const [id, family, platform] = button.dataset.cell.split("|");
    row.insertAdjacentHTML("afterend", renderDetail(byKey.get(`${id}|${family}`), platform));
    button.setAttribute("aria-expanded", "true");
  });

  window.addEventListener("hashchange", followHash);
  writeControls(parseState(location.search));
  show();
  followHash();
}

Promise.all([fetchJson("/computers/data/catalog.json"), fetchJson("/computers/data/reports.json")])
  .then(([catalog, reports]) => start(catalog, reports))
  .catch((error) => {
    console.error(error);
    $("error").hidden = false;
  });
```

- [ ] **Step 4: Write `computers/page.css`**

```css
/* The support matrix page. Colour and type tokens come from /styles.css. */
.matrix { max-width: var(--max); margin: 0 auto; padding: 32px 16px 64px; color: var(--ink); }
.matrix h1 { margin: 0 0 12px; }
.matrix .lead { color: var(--ink-muted); max-width: 70ch; }
.sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }

.matrix__legend { display: grid; gap: 6px; list-style: none; padding: 0; margin: 20px 0; color: var(--ink-muted); }
.matrix__legend .cell { margin-right: 8px; }
.matrix__updated, .matrix__count { color: var(--ink-muted); font-size: 0.9rem; }

.matrix__controls { display: grid; grid-template-columns: 2fr repeat(4, minmax(0, 1fr)); gap: 8px; margin: 24px 0 8px; }
.matrix__controls input, .matrix__controls select {
  width: 100%; font: inherit; color: var(--ink); background: var(--panel);
  border: 1px solid var(--line); border-radius: 8px; padding: 8px 10px;
}
.matrix__controls input:focus-visible, .matrix__controls select:focus-visible { outline: 2px solid var(--cyan); outline-offset: 1px; }
.matrix__error { color: #ff9a9a; }

.matrix__table { width: 100%; border-collapse: collapse; background: var(--panel); border-radius: 12px; overflow: hidden; }
.matrix__table th, .matrix__table td { padding: 8px 10px; border-bottom: 1px solid var(--line); text-align: left; vertical-align: middle; }
.matrix__table thead th { font-size: 0.85rem; color: var(--ink-muted); font-weight: 600; }
.matrix__table tr.vendor th { background: rgba(143, 220, 236, 0.08); color: var(--cyan-text); font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.06em; }
.matrix__table tr.is-target { outline: 2px solid var(--cyan); outline-offset: -2px; }
.matrix__table tr.detail td { background: rgba(143, 220, 236, 0.05); }
.detail h3 { margin: 0 0 4px; font-size: 1rem; }
.detail ul { margin: 8px 0 0; padding-left: 18px; display: grid; gap: 8px; }
.detail a { color: var(--cyan); }

.cell {
  display: inline-flex; align-items: center; gap: 6px; padding: 2px 8px; border-radius: 999px;
  border: 1px solid currentColor; background: transparent; color: inherit; font: inherit; font-size: 0.85rem; white-space: nowrap;
}
button.cell { cursor: pointer; }
button.cell:focus-visible { outline: 2px solid var(--cyan); outline-offset: 2px; }
.cell::before { font-weight: 700; }
.cell--verified { color: #7be3a0; }
.cell--verified::before { content: "\2713"; }
.cell--issues { color: #ffd27a; }
.cell--issues::before { content: "!"; }
.cell--not-working { color: #ff9a9a; }
.cell--not-working::before { content: "\2715"; }
.cell--untested { color: var(--ink-muted); border-style: dashed; }
.cell--untested::before { content: "?"; }
.cell--na { color: var(--ink-faint); border-color: transparent; }

.matrix__help, .matrix__provenance { margin-top: 40px; color: var(--ink-muted); }
.matrix__help a, .matrix__provenance a { color: var(--cyan); }
.matrix__provenance ul { columns: 2; padding-left: 18px; }

@media (max-width: 720px) {
  .matrix__controls { grid-template-columns: 1fr 1fr; }
  .matrix__controls .matrix__search { grid-column: 1 / -1; }
  .matrix__table thead { display: none; }
  .matrix__table, .matrix__table tbody { display: block; }
  .matrix__table tr { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 6px; padding: 10px; border-bottom: 1px solid var(--line); }
  .matrix__table tr.vendor, .matrix__table tr.detail { display: block; padding: 0; }
  .matrix__table tr > th[scope="row"] { grid-column: 1 / 4; border: 0; padding: 0; }
  .matrix__table tr > td.transport { grid-column: 4 / 6; border: 0; padding: 0; text-align: right; color: var(--ink-muted); }
  .matrix__table td.platform { border: 0; padding: 0; display: flex; flex-direction: column; gap: 2px; font-size: 0.75rem; min-width: 0; }
  .matrix__table td.platform::before { content: attr(data-label); color: var(--ink-muted); }
  .cell { font-size: 0.75rem; padding: 2px 6px; white-space: normal; }
  .matrix__provenance ul { columns: 1; }
}
```

- [ ] **Step 5: Write `computers/index.html`**

Start from the current `privacy/index.html` (on `origin/main`). Keep, unchanged except for paths: the `<head>` font and stylesheet links, the skip link, the `.ocean` block, the `<header class="surface">` navigation, the footer, the `data-year` script and `ocean.js`. Change these `<head>` values:
- `<title>Dive computer support · Submersion Dive Log</title>`
- description: `Which dive computers Submersion downloads from over Bluetooth and USB on iOS, Android, macOS, Windows and Linux, and what divers have reported for each.`
- `<link rel="canonical" href="https://submersion.app/computers/" />`, and the matching `og:title` and `og:description`.
- Add after `../styles.css`: `<link rel="stylesheet" href="/computers/page.css" />`.
- Footer text: `© <span data-year></span> Submersion · GPL-3.0` (the copy rules retire "See you down there").

Replace the legal body (everything between the header and the footer) with:

```html
<main id="content" class="matrix">
  <h1>Dive computer support</h1>
  <p class="lead">
    Find your dive computer to see whether Submersion downloads from it on your phone or computer. Each cell shows
    what divers have reported for one model, one connection and one platform.
  </p>
  <ul class="matrix__legend" aria-label="Legend">
    <li><span class="cell cell--verified">Verified</span>A diver downloaded dives this way.</li>
    <li><span class="cell cell--issues">Issues</span>It works with a caveat, or a fix is waiting for a diver to confirm it.</li>
    <li><span class="cell cell--not-working">Not working</span>A diver reported a failure that is not fixed yet.</li>
    <li><span class="cell cell--untested">Untested</span>Submersion supports this connection, and nobody has reported on it yet.</li>
    <li><span class="cell cell--na">n/a</span>This platform cannot use this connection.</li>
  </ul>
  <p class="matrix__updated" id="updated"></p>

  <form class="matrix__controls" role="search" onsubmit="return false">
    <label class="matrix__search"><span class="sr-only">Search models</span>
      <input id="q" type="search" placeholder="Search, for example Perdix 3" autocomplete="off" /></label>
    <label><span class="sr-only">Brand</span>
      <select id="brand"><option value="">All brands</option></select></label>
    <label><span class="sr-only">Platform</span>
      <select id="platform">
        <option value="">All platforms</option><option value="ios">iOS</option><option value="android">Android</option>
        <option value="macos">macOS</option><option value="windows">Windows</option><option value="linux">Linux</option>
      </select></label>
    <label><span class="sr-only">Status</span>
      <select id="status">
        <option value="">Any status</option><option value="verified">Verified</option><option value="issues">Issues</option>
        <option value="not-working">Not working</option><option value="untested">Untested</option>
      </select></label>
    <label><span class="sr-only">Connection</span>
      <select id="transport">
        <option value="">Any connection</option><option value="bluetooth">Bluetooth</option><option value="usb">USB</option>
      </select></label>
  </form>
  <p class="matrix__count" id="count" aria-live="polite"></p>
  <p class="matrix__error" id="error" hidden>The support matrix did not load. Reload the page to try again.</p>

  <table class="matrix__table">
    <thead>
      <tr>
        <th scope="col">Model</th><th scope="col">Connection</th><th scope="col">iOS</th><th scope="col">Android</th>
        <th scope="col">macOS</th><th scope="col">Windows</th><th scope="col">Linux</th>
      </tr>
    </thead>
    <tbody id="rows"></tbody>
  </table>

  <section class="matrix__help">
    <h2>Help fill the gaps</h2>
    <p>
      Tried Submersion with your computer? Post what happened in the
      <a href="https://scubaboard.com/community/threads/submersion-free-open-source-dive-log-app-all-platforms-looking-for-dive-computer-testers.667061/">ScubaBoard thread</a>,
      on <a href="https://www.reddit.com/r/submersion/">r/submersion</a> or as a
      <a href="https://github.com/submersion-app/submersion/issues">GitHub issue</a>. Include the model, your phone or
      computer and its operating system, Bluetooth or USB, and your Submersion version. Reports are added to this page
      each month.
    </p>
  </section>

  <section class="matrix__provenance">
    <h2>Where this comes from</h2>
    <p id="provenance"></p>
    <p>
      Bluetooth Classic and infrared are not supported on any platform. These models use only infrared, or a raw USB
      connection Submersion does not implement:
    </p>
    <ul id="unsupported"></ul>
  </section>
</main>
<script type="module" src="/computers/page.js"></script>
```

The `onsubmit` attribute is inline: if the site ever adds a CSP, move it to page.js. Check `privacy/index.html`'s nav: its links point at `../#...` anchors that the README says still resolve, so keep them as they are.

- [ ] **Step 6: Link the page from the homepage and record the claim**

In `index.html`, in the `#computer` zone's "350+ models" feature paragraph, replace:

```
The project has confirmed the Shearwater Teric and the Aqualung i300C and i330R and is looking for testers for the rest.
```

with:

```
<a href="/computers/">See which models divers have verified on your platform</a>, and which still need a tester.
```

In `docs/superpowers/specs/2026-08-23-content-rewrite-design.md`, replace the "Tested computers" row of the verified-claims table with:

```
| Tested computers | "See which models divers have verified on your platform, and which still need a tester." | `/computers/` page, data in `computers/data/` |
```

- [ ] **Step 7: Run every website test**

Run: `node --test tests/*.test.mjs && node tools/support-matrix/validate.mjs`
Expected: all pass; `support matrix data is valid`.

- [ ] **Step 8: Check the page in a browser**

Add a local-only entry (not committed) to `.claude/launch.json` in the app worktree:

```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "website-matrix",
      "runtimeExecutable": "python3.14",
      "runtimeArgs": ["-m", "http.server", "5173", "--directory", "/Users/ericgriffin/repos/submersion-app/submersion-website-support-matrix"],
      "port": 5173
    }
  ]
}
```

Start it with `preview_start {name: "website-matrix"}`, then navigate to `http://localhost:5173/computers/` and check:
1. `read_console_messages` with `onlyErrors: true`: none.
2. `get_page_text`: "Showing 405 of 405 rows."; legend and help text present; 20 items in the unsupported list.
3. Type `perdix3` into the search: one row; the address bar shows `?q=perdix3`. Clear it: the address bar has no `?`.
4. Navigate to `http://localhost:5173/computers/?brand=Mares#scubapro-g2`: the brand filter clears and both G2 rows are outlined.
5. `resize_window` preset `mobile`: cards, five chips per row, no horizontal scroll (`document.documentElement.scrollWidth <= innerWidth` via `javascript_tool`). Then preset `desktop`.
6. Screenshots at desktop and mobile widths for the PR.

The empty `reports.json` means every reachable cell reads Untested; to exercise a detail panel, temporarily add one valid report locally, click its cell, confirm the panel, then revert the file (`git diff --stat computers/data/reports.json` shows nothing before committing).

- [ ] **Step 9: Commit and stop to ask before PR 2**

```bash
git add computers/index.html computers/page.css computers/page.js computers/data/catalog.json computers/data/reports.json tests/support-matrix-data.test.mjs index.html docs/superpowers/specs/2026-08-23-content-rewrite-design.md
git commit -m "feat(computers): publish the dive computer support matrix page"
```

Ask the maintainer to approve pushing `ericgriffin/support-matrix-page` and opening PR 2 on `submersion-app/submersion-website`. Body: what the page shows, how status is computed, the screenshot files to drag in, and that evidence arrives in the next PR. Mention submersion-app/submersion#2616 as context.

---

### Task 8: The sweep procedure and the initial sweep

Starts after PR 2 merges. Branch from fresh `origin/main` in the website repo:

```bash
git -C /Users/ericgriffin/repos/submersion-app/submersion-website fetch origin
git -C /Users/ericgriffin/repos/submersion-app/submersion-website worktree add -b ericgriffin/support-matrix-initial-sweep /Users/ericgriffin/repos/submersion-app/submersion-website-sweep origin/main
```

**Files:**
- Create: `tools/support-matrix/SWEEP.md`
- Modify: `computers/data/reports.json` (via `merge.mjs`), `computers/data/catalog.json` (regenerated)

**Interfaces:**
- Consumes: `merge.mjs`, `fixed-in.mjs`, `validate.mjs` CLIs; the generator CLI (app repo).
- Produces: `SWEEP.md`, the procedure the monthly routine follows; a candidate file format (below) every source agent returns.

- [ ] **Step 1: Write `tools/support-matrix/SWEEP.md`**

````markdown
# Support matrix sweep

How `computers/data/reports.json` gets new evidence. The same procedure runs
the first time (every watermark empty, so every source is read in full) and
monthly (each source read from its own watermark). The page, the validator
and the status rules are described in the app repo's spec,
`docs/superpowers/specs/2026-10-02-dive-computer-support-matrix-design.md`.

## Rules for every report

- One report is one diver's own result for one model, one platform and one
  connection. Release notes, changelogs and "should work" replies are not
  reports. A maintainer's own hardware test is.
- `outcome`: `works` (dives downloaded), `caveats` (downloaded with a
  workaround or a partial problem), `fails`. When unsure, use the weaker one.
- `platform`: `ios`, `android`, `macos`, `windows`, `linux`. Leave the report
  out when the platform cannot be told.
- `transport`: `bluetooth` or `usb`. On iOS it is always `bluetooth`. Leave the
  report out when it cannot be told on another platform.
- `appVersion`: the Submersion version the diver ran, `X.Y.Z`, or `null`.
- `date`: the post or comment date, `YYYY-MM-DD`.
- `url`: the permalink to the exact post or comment. Store reviews use the
  listing (App Store
  `https://apps.apple.com/us/app/submersion-dive-log/id6757456915`, Google Play
  `https://play.google.com/store/apps/details?id=app.submersion`) and put the
  review id in `sourceRef` (`appstore:<country>:<id>`, `play:<submit millis>`).
- `note`: at most 120 characters, our own words, no quotes, no usernames, no
  em dash. Say what happened ("Downloaded 40 dives after re-pairing").
- `model`: a catalog id from `computers/data/catalog.json`. A report that names
  a family ("Suunto D-series") or an ambiguous name goes in `unmapped` with the
  text it used. Never guess.
- `fixedBy`: when the thread or issue links a fixing PR, its number. The merge
  step turns it into `fixedIn`.

## Reports from the form

An issue opened from the matrix page's "Report your result" link is a filled
issue form (`.github/ISSUE_TEMPLATE/computer-report.yml` in the app repo). Its
body is Markdown: each field is a `### <label>` heading followed by the answer
(`_No response_` when an optional field is empty). Read it, do not interpret
it:

- `model`: the catalog id at the start of "Dive computer" (the text before the
  first space). If it is not a catalog id, the report goes to `unmapped` with
  the whole answer.
- `platform`: the "Platform" answer, lowercased (`iOS` gives `ios`).
- `transport`: "Connection", `Bluetooth` gives `bluetooth`, `USB` gives `usb`.
- `outcome`: "What happened", `Downloaded dives` gives `works`,
  `Downloaded with problems` gives `caveats`, `Did not work` gives `fails`.
- `appVersion`: "Submersion version" when it is dotted numbers (a leading `v`
  dropped), otherwise `null`.
- `date`: the issue's `createdAt` date.
- `source`: `github-issue`; `url`: the issue's `url`; `sourceRef`: `null`.
- `note`: a paraphrase of "Details" in our own words, at most 120 characters,
  or `Reported through the form` when it is empty.
- A maintainer comment on the issue that links a fixing PR gives `fixedBy`.

## Candidate file

Each source produces `sweep-<source>.json` in a scratch directory (never in
the repo):

```json
{
  "reports": [ { "model": "...", "platform": "...", "transport": "...",
                 "outcome": "...", "appVersion": null, "date": "...",
                 "source": "...", "url": "...", "sourceRef": null,
                 "note": "...", "fixedBy": null } ],
  "unmapped": [ { "text": "Suunto D-series", "url": "...", "why": "family name" } ],
  "watermarks": { "<source>": { } },
  "failed": null
}
```

`failed` is a one-line reason when the source could not be read; then
`reports` is empty and `watermarks` leaves that source out, so its watermark
stays where it was.

## Sources

Read each from its watermark in `reports.json`. Split a source across
parallel agents when it has more than about 10 pages or 100 items to read.

| Source key | Read | Watermark written |
|---|---|---|
| `scubaboard` | `https://scubaboard.com/community/threads/submersion-free-open-source-dive-log-app-all-platforms-looking-for-dive-computer-testers.667061/` and `.../page-N`, fetched with `curl -sL -A "Mozilla/5.0"`. Posts are `<article ... data-content="post-<id>">`; permalink `https://scubaboard.com/community/threads/submersion-free-open-source-dive-log-app-all-platforms-looking-for-dive-computer-testers.667061/post-<id>`. Skip posts with id at or below `lastPostId`. | `{ "lastPostId": <highest id read>, "sweptAt": "<today>" }` |
| `github` (report form) | Issues labelled `computer-report`: `gh issue list --repo submersion-app/submersion --label computer-report --state all --limit 1000 --json number,title,body,url,createdAt,updatedAt`, keeping those updated after `github.since`. Parsed field by field, see "Reports from the form". | shares the `github` watermark |
| `github` (issues, PRs, discussions) | `gh api --paginate "repos/submersion-app/submersion/issues?state=all&per_page=100&since=<since>"` (issues and PRs), `gh api --paginate "repos/submersion-app/submersion/issues/comments?per_page=100&since=<since>"`, and discussions with comments over GraphQL. Dump to files and grep locally for catalog vendor and product names; never use the search API in a loop (it rate-limits). Issue and comment permalinks are their `html_url`. Skip issues labelled `computer-report`; the form row reads them. | `{ "since": "<sweep start, ISO 8601 UTC>" }` |
| `reddit` | `curl -s -A "submersion-support-matrix/1.0" "https://www.reddit.com/r/submersion/new.json?limit=100"` (follow `after`), then `https://www.reddit.com<permalink>.json` per post for comments. Skip items with `created_utc` at or below `lastCreatedUtc`. Permalinks are `https://www.reddit.com<permalink>`. | `{ "lastCreatedUtc": <highest read> }` |
| `appStore` | `https://itunes.apple.com/<cc>/rss/customerreviews/page=<1..10>/id=6757456915/sortby=mostrecent/json` for `cc` in us gb ca au nz ie de at ch fr be nl es it pt se no dk fi pl cz jp mx br sg za; stop a country at the first empty page or the first review at or below `lastReviewId`. | `{ "lastReviewId": <highest numeric id read>, "sweptAt": "<today>" }` |
| `playStore` | Play Console review exports: `gcloud storage ls gs://$PLAY_REVIEWS_BUCKET/reviews/` then `gcloud storage cp` each `reviews_app.submersion_<YYYYMM>.csv` after `lastExportMonth` (UTF-16; read with `iconv -f UTF-16 -t UTF-8`). Use the `Device`, `App Version Name`, `Review Submit Date and Time`, `Review Submit Millis Since Epoch` and `Review Text` columns. Needs `PLAY_REVIEWS_BUCKET` and a service account key in `GOOGLE_APPLICATION_CREDENTIALS`; without them, set `failed`. | `{ "lastExportMonth": "<YYYYMM of the newest file read>" }` |

## Steps

1. In an app repo checkout (`git submodule update --init packages/libdivecomputer_plugin/third_party/libdivecomputer`, `git fetch --tags`), regenerate the catalog:
   `python3 scripts/export_support_matrix_catalog.py --previous <website>/computers/data/catalog.json --out <website>/computers/data/catalog.json`.
   Note any `removed` ids.
2. Read every source into its candidate file (in parallel where possible).
3. Resolve `fixedBy`: for each PR number, `gh pr view <n> --repo submersion-app/submersion --json mergeCommit -q .mergeCommit.oid`, then `node tools/support-matrix/fixed-in.mjs <app checkout> <sha>`; set `fixedIn` on that report and drop `fixedBy`.
4. Combine the candidate files into one `sweep.json` (concatenate `reports`, merge `watermarks`), then `node tools/support-matrix/merge.mjs sweep.json`.
5. `node tools/support-matrix/validate.mjs` and `node --test tests/*.test.mjs`. Fix or drop any report the validator rejects; never weaken the validator.
6. If every source has `failed`, open no PR; report the reasons instead. Otherwise open one PR titled `data(computers): support matrix sweep <YYYY-MM-DD>` whose body lists: reports added per source; every `unmapped` item with its link; reports whose model appears in `removed`; every source with `failed` and its reason. No attribution lines.
````

- [ ] **Step 2: Commit the procedure**

```bash
git add tools/support-matrix/SWEEP.md
git commit -m "docs(computers): describe the support matrix sweep"
```

- [ ] **Step 3: Run the initial sweep as a parallel fan-out**

Read `SWEEP.md` and `computers/data/catalog.json` first. Dispatch these agents in one message, each told to follow `SWEEP.md`'s report rules and candidate-file format exactly, and to write its file under the session scratchpad:

1. ScubaBoard pages 1 to 9, 10 to 18, 19 to 27, 28 to 36, 37 to 45, 46 to 54, 55 to 63, 64 to the last page (eight agents; the last checks the current page count).
2. GitHub issues and PRs: the `device sync` label (`gh issue list --repo submersion-app/submersion --label "device sync" --state all --limit 500 --json number,title,body,comments,url`) plus a full REST dump of issues and issue comments grepped for every catalog vendor and product name. Include merged PRs that fix a device problem as `fixedBy` context on the reports they resolve.
3. GitHub discussions (all 36, with comments) over GraphQL.
4. Reddit r/submersion, all posts and comments.
5. App Store reviews, all listed storefronts.
6. Report-form issues (label `computer-report`), parsed per "Reports from the form"; there may be none yet.

Google Play joins once Task 9's service account exists. If it is unavailable now, record `playStore` as `failed: "service account not set up yet"`.

- [ ] **Step 4: Merge, resolve fixes, validate**

Follow `SWEEP.md` steps 3 to 5. Expected: `node tools/support-matrix/validate.mjs` prints `support matrix data is valid`, and every test passes.

- [ ] **Step 5: Review the result before the PR**

Show the maintainer: reports per source, the `unmapped` list, and the cells that changed from Untested (`node -e` over `buildRows` from `computers/rows.js`, counting statuses). Wait for their go-ahead on the unmapped items; resolve the ones they map by adding reports.

- [ ] **Step 6: Commit and stop to ask before PR 3**

```bash
git add computers/data/reports.json computers/data/catalog.json
git commit -m "data(computers): initial support matrix sweep"
```

Ask before pushing `ericgriffin/support-matrix-initial-sweep` and opening PR 3 with the body `SWEEP.md` step 6 describes.

---

### Task 9: Play access, ScubaBoard reachability and the monthly routine

**Files:** none in either repo unless the ScubaBoard check fails (then `tools/support-matrix/SWEEP.md`).

**Interfaces:**
- Consumes: `SWEEP.md`.
- Produces: a scheduled cloud routine, monthly, prompt: `In submersion-app/submersion-website, follow tools/support-matrix/SWEEP.md. The app repo is submersion-app/submersion.`

- [ ] **Step 1: Hand the maintainer the Play setup steps**

These are theirs to do; never enter credentials yourself:
1. In Google Cloud, create a service account in the project linked to the Play Console.
2. In Play Console, Users and permissions, invite the service account's email with "View app information and download bulk reports" for Submersion.
3. Note the bucket id from Play Console, Download reports, Reviews ("Copy Cloud Storage URI": `gs://pubsite_prod_<id>/reviews/`).
4. Create a JSON key for the service account, and add it and the bucket id as secrets of the routine's environment (`GOOGLE_APPLICATION_CREDENTIALS` content and `PLAY_REVIEWS_BUCKET`).

- [ ] **Step 2: Create the routine (after the maintainer's yes)**

Use the `schedule` skill to create a monthly cloud routine (first of the month) with the prompt above, with access to both repos and permission to push branches and open PRs on `submersion-app/submersion-website` only.

- [ ] **Step 3: Run it once and check the PR it opens**

Trigger one run. Check the PR body: did ScubaBoard read successfully? Did Play read the exports? If ScubaBoard failed at the edge (Cloudflare challenge, 403), add a "Local fallback" section to `SWEEP.md`: run the `scubaboard` source from a maintainer machine with `curl` and commit its candidate file into a follow-up sweep, and open a small PR with that change.

---

### Task 10: Point the app's docs at the matrix

Starts after PR 2 has published the page. Branch from fresh `main` in a new app worktree (`git worktree add -b ericgriffin/support-matrix-docs <path> origin/main`, then `git submodule update --init --recursive`).

**Files:**
- Modify: `docs/guide/dive-computer.md:5-27`
- Modify: `README.md:52-54`

- [ ] **Step 1: Replace the guide's supported-computers sections**

In `docs/guide/dive-computer.md`, replace from `## Supported Computers` through the end of the `### Connection Types` table (the `| **USB** | Wired connection (requires adapter) |` line) with:

```markdown
## Supported Computers

Submersion uses libdivecomputer, which supports 350+ models. Which of them
download over Bluetooth or USB depends on the model and on your platform:

| Platform | Bluetooth LE | USB |
|----------|--------------|-----|
| **iOS** | Yes | No |
| **Android** | Yes | USB serial cables |
| **macOS, Windows, Linux** | Yes | USB serial cables and USB HID |

Bluetooth Classic and infrared are not supported.

The [support matrix](https://submersion.app/computers/) lists every model, the
connections each platform can use for it, and what divers have reported:
verified, issues, not working or untested. Check your model there before buying
a cable, and add your own result to fill a gap.
```

- [ ] **Step 2: Replace the README's confirmed list**

In `README.md`, replace the three-line `> **Confirmed working:** ...` block with:

```markdown
> **Will it work with my computer?** The [support matrix](https://submersion.app/computers/)
> lists every model, the connections each platform can use, and what divers have
> reported. Tried one that is not verified yet? [Tell us how it went](https://github.com/submersion-app/submersion/issues).
```

- [ ] **Step 3: Check and commit**

Run: `grep -n "Bluetooth Classic\|Fully Tested\|Confirmed working" docs/guide/dive-computer.md README.md`
Expected: one hit, the guide's "Bluetooth Classic and infrared are not supported." line.

```bash
git add docs/guide/dive-computer.md README.md
git commit -m "docs: point the dive computer guide and README at the support matrix

Closes #2616"
```

- [ ] **Step 4: Stop and ask before PR 5**

Ask before pushing and opening PR 5. Body: Summary, `Closes #2616`, Screenshots section deleted (only `docs/` and `README.md` changed).

---

### Task 11: The computer report issue form

Added after Task 7 for per-model reports; runs after Task 7, per the execution order. App repo, goes into PR 1.

**Files:**
- Create: `.github/ISSUE_TEMPLATE/computer-report.yml` (app repo)

**Interfaces:**
- Produces: field ids `model`, `platform`, `connection`, `outcome`, `app_version`, `device`, `details`; dropdown option labels `iOS`, `Android`, `macOS`, `Windows`, `Linux`; `Bluetooth`, `USB`; `Downloaded dives`, `Downloaded with problems`, `Did not work`; label `computer-report`. Task 12's `reportUrl` and Task 8's form parser consume exactly these.

An issue form is configuration: it has no unit test in this repo, and GitHub validates it when the branch is pushed. Step 2 parses it locally instead.

- [ ] **Step 1: Write the form**

Create `.github/ISSUE_TEMPLATE/computer-report.yml`:

```yaml
name: Dive computer report
description: Tell us how Submersion worked with your dive computer. Reports feed the support matrix at submersion.app/computers.
title: "Computer report: "
labels: ["computer-report"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for reporting. Your report is public on GitHub and feeds the [support matrix](https://submersion.app/computers/), so please leave out personal details such as your name, email address or dive locations.
  - type: input
    id: model
    attributes:
      label: Dive computer
      description: The model as the support matrix lists it. It is filled in when you start from the matrix.
      placeholder: shearwater-perdix-3 (Shearwater Perdix 3)
    validations:
      required: true
  - type: dropdown
    id: platform
    attributes:
      label: Platform
      description: Where you ran Submersion.
      options:
        - iOS
        - Android
        - macOS
        - Windows
        - Linux
    validations:
      required: true
  - type: dropdown
    id: connection
    attributes:
      label: Connection
      options:
        - Bluetooth
        - USB
    validations:
      required: true
  - type: dropdown
    id: outcome
    attributes:
      label: What happened
      options:
        - Downloaded dives
        - Downloaded with problems
        - Did not work
    validations:
      required: true
  - type: input
    id: app_version
    attributes:
      label: Submersion version
      description: For example 1.8.1.
      placeholder: 1.8.1
    validations:
      required: true
  - type: input
    id: device
    attributes:
      label: Phone or computer
      description: Optional. The device and its operating system version, for example "Pixel 8, Android 15".
  - type: textarea
    id: details
    attributes:
      label: Details
      description: Optional. Anything that helps, such as error messages, workarounds, or how many dives came across.
```

- [ ] **Step 2: Parse it and check the ids**

Run: `ruby -ryaml -e 'f = YAML.load_file(".github/ISSUE_TEMPLATE/computer-report.yml"); puts f["labels"].inspect; f["body"].each { |b| puts [b["type"], b["id"], (b.dig("attributes", "options") || []).join("|")].join(" ") }'`
Expected: `["computer-report"]`, then `markdown`, `input model`, `dropdown platform iOS|Android|macOS|Windows|Linux`, `dropdown connection Bluetooth|USB`, `dropdown outcome Downloaded dives|Downloaded with problems|Did not work`, `input app_version`, `input device`, `textarea details`.

- [ ] **Step 3: Commit**

```bash
git add .github/ISSUE_TEMPLATE/computer-report.yml
git commit -m "feat(support-matrix): add a dive computer report issue form

Refs #2616"
```

The `computer-report` label is created on the repo (`gh label create computer-report --repo submersion-app/submersion --color 0E8A16 --description "A diver's result with a dive computer, for the support matrix"`) only after the maintainer approves pushing PR 1; it is an outward change.

---

### Task 12: Report links on the matrix page

Added after Task 7 for per-model reports; runs after Task 7, before Task 8. Website repo, goes into PR 2.

**Files:**
- Modify: `computers/render.js`, `computers/page.css`, `computers/index.html`
- Test: `tests/support-matrix-render.test.mjs`

**Interfaces:**
- Consumes: Task 11's field ids and option labels; `PLATFORM_TEXT`, `FAMILY_TEXT`, `escapeHtml` (render.js).
- Produces: `reportUrl({ id, vendor, product, family, platform } = {}) -> string`. Every row's model cell and every detail panel carry `<a class="report" ...>`.

- [ ] **Step 1: Write the failing tests**

Add to the imports of `tests/support-matrix-render.test.mjs`: `reportUrl` (from `../computers/render.js`). Append:

```js
const form = (url) => new URL(url);
const perdix = { id: "shearwater-perdix-3", vendor: "Shearwater", product: "Perdix 3", family: "bluetooth" };

test("a row's report link fills in the model and connection", () => {
  const url = form(reportUrl(perdix));
  assert.equal(url.origin + url.pathname, "https://github.com/submersion-app/submersion/issues/new");
  assert.equal(url.searchParams.get("template"), "computer-report.yml");
  assert.equal(url.searchParams.get("labels"), "computer-report");
  assert.equal(url.searchParams.get("title"), "Computer report: Shearwater Perdix 3, Bluetooth");
  assert.equal(url.searchParams.get("model"), "shearwater-perdix-3 (Shearwater Perdix 3)");
  assert.equal(url.searchParams.get("connection"), "Bluetooth");
  assert.equal(url.searchParams.has("platform"), false);
});

test("a cell's report link fills in the platform too", () => {
  const url = form(reportUrl({ ...perdix, platform: "android" }));
  assert.equal(url.searchParams.get("title"), "Computer report: Shearwater Perdix 3, Android, Bluetooth");
  assert.equal(url.searchParams.get("platform"), "Android");
});

test("report links encode spaces as %20, not +", () => {
  const url = reportUrl(perdix);
  assert.match(url, /Shearwater%20Perdix%203/);
  assert.ok(!url.includes("+"));
});

test("the blank report link opens the form with nothing filled in", () => {
  const url = form(reportUrl());
  assert.equal(url.searchParams.get("template"), "computer-report.yml");
  assert.equal(url.searchParams.has("title"), false);
  assert.equal(url.searchParams.has("model"), false);
});

test("every row and every detail panel links to the form", () => {
  const rows = buildRows(catalog, [report()]);
  const html = renderRows(rows);
  assert.equal(html.match(/<a class="report"/g).length, rows.length);
  assert.ok(html.includes(`href="${escapeHtml(reportUrl(rows[0]))}"`));
  assert.match(html, /aria-label="Report your result for Mares Puck Pro \+, Bluetooth"/);
  const perdixRow = rows.find((r) => r.id === "shearwater-perdix-3");
  const detail = renderDetail(perdixRow, "android");
  assert.ok(detail.includes(`href="${escapeHtml(reportUrl({ ...perdixRow, platform: "android" }))}"`));
});
```

Run: `node --test tests/support-matrix-render.test.mjs`
Expected: FAIL, `reportUrl` is not exported (SyntaxError on the import).

- [ ] **Step 2: Implement**

In `computers/render.js`, after `FAMILY_TEXT`, add:

```js
const REPORT_FORM = "https://github.com/submersion-app/submersion/issues/new";

// A pre-filled "computer report" issue form (.github/ISSUE_TEMPLATE in the app
// repo). The field ids and option labels here must match that form. Spaces are
// encoded as %20: encodeURIComponent, not URLSearchParams, which writes "+".
export function reportUrl({ id, vendor, product, family, platform } = {}) {
  const fields = [["template", "computer-report.yml"], ["labels", "computer-report"]];
  if (id) {
    const where = [platform && PLATFORM_TEXT[platform], family && FAMILY_TEXT[family]].filter(Boolean);
    fields.push(["title", ["Computer report: " + `${vendor} ${product}`, ...where].join(", ")]);
    fields.push(["model", `${id} (${vendor} ${product})`]);
    if (family) fields.push(["connection", FAMILY_TEXT[family]]);
    if (platform) fields.push(["platform", PLATFORM_TEXT[platform]]);
  }
  return `${REPORT_FORM}?${fields.map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join("&")}`;
}

function reportLink(row, platform) {
  const where = [platform && PLATFORM_TEXT[platform], FAMILY_TEXT[row.family]].filter(Boolean).join(", ");
  const label = escapeHtml(`Report your result for ${row.vendor} ${row.product}, ${where}`);
  const href = escapeHtml(reportUrl({ ...row, platform }));
  return `<a class="report" href="${href}" target="_blank" rel="noreferrer" aria-label="${label}">Report</a>`;
}
```

In `renderRows`, change the model cell to:

```js
`<tr data-model="${escapeHtml(row.id)}"${anchor}><th scope="row">${escapeHtml(row.product)} ${reportLink(row)}</th>` +
```

In `renderDetail`, change the returned panel's closing to:

```js
return `<tr class="detail" data-cell="${key}"><td colspan="7"><h3>${title}</h3>${label}<ul>${items}</ul>` +
  `<p>${reportLink(row, platform)}</p></td></tr>`;
```

In `computers/page.css`, after `.detail a { color: var(--cyan); }`, add:

```css
.report { margin-left: 8px; font-size: 0.8rem; font-weight: 400; color: var(--cyan); }
.detail .report { margin-left: 0; }
```

In `computers/index.html`, in "Help fill the gaps", replace the sentence beginning "Tried Submersion with your computer? Post what happened in the" up to and including "as a" plus its GitHub issue link with:

```html
Tried Submersion with your computer?
<a href="https://github.com/submersion-app/submersion/issues/new?template=computer-report.yml&amp;labels=computer-report" target="_blank" rel="noreferrer">Report your result</a>
(it takes a free GitHub account), or post what happened in the
<a href="https://scubaboard.com/community/threads/submersion-free-open-source-dive-log-app-all-platforms-looking-for-dive-computer-testers.667061/">ScubaBoard thread</a>
or on <a href="https://www.reddit.com/r/submersion/">r/submersion</a>.
```

keeping the following sentences ("Include the model, ..." and "Reports are added to this page each month.").

- [ ] **Step 3: Run the tests to verify they pass**

Run: `node --test tests/*.test.mjs`
Expected: all pass.

- [ ] **Step 4: Check in the browser**

With the `website-matrix` preview: a row's "Report" link and a detail panel's link open GitHub's form with the fields filled in (check the `href` with `javascript_tool`, and that a tap does not toggle the row); at 375 px the link sits after the model name without overflow.

- [ ] **Step 5: Commit**

```bash
git add computers/render.js computers/page.css computers/index.html tests/support-matrix-render.test.mjs
git commit -m "feat(computers): link every model to a pre-filled report form"
```
