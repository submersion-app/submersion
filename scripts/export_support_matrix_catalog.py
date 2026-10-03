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
# Where an entry starts, whether or not _ENTRY can read it: the table body
# holds nothing but entries, so every opening brace outside a string literal
# begins one. String literals are matched (and skipped) so a brace in a
# product name is not taken for a new entry.
_ENTRY_START = re.compile(r'"(?:\\.|[^"\\])*"|\{')
# The shape slugify produces; an idOverrides value must have it too.
_ID = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class CatalogError(Exception):
    """The inputs cannot produce a trustworthy catalog."""


def parse_descriptors(source):
    """Returns (vendor, product, transport names) for each table entry."""
    table = _TABLE.search(source)
    if table is None:
        raise CatalogError("g_descriptors[] table not found")
    body = _LINE_COMMENT.sub("", _BLOCK_COMMENT.sub("", table.group(1)))
    # Every entry must parse: skipping one it cannot read would drop that model
    # from the matrix without a word.
    entries = []
    for start in _ENTRY_START.finditer(body):
        if start.group() != "{":
            continue  # a string literal, possibly holding a brace
        entry = _ENTRY.match(body, start.start())
        if entry is None:
            end = body.find("\n", start.start())
            line = body[start.start() : end if end != -1 else len(body)].strip()
            raise CatalogError("cannot read descriptor entry: %s" % line)
        vendor, product, flags = entry.groups()
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
    if not isinstance(rules, dict):
        raise CatalogError("rules: the file must hold a JSON object")
    known = set(FLAG_NAMES.values())
    for platform in PLATFORMS:
        transports = rules.get(platform)
        if not isinstance(transports, list):
            raise CatalogError("rules: %s is missing" % platform)
        unknown = sorted(set(transports) - known)
        if unknown:
            raise CatalogError("rules: %s lists unknown transports %s" % (platform, unknown))
    overrides = rules.get("idOverrides", {})
    if not isinstance(overrides, dict):
        raise CatalogError("rules: idOverrides must be an object")
    for key, value in overrides.items():
        if not isinstance(value, str) or not _ID.match(value):
            raise CatalogError("rules: idOverrides %s gives %r, not a lowercase-hyphen id" % (key, value))
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


def _git(path, *args):
    """stdout of git run in the repo at path; raises on failure."""
    return subprocess.run(
        ["git", "-C", path] + list(args), capture_output=True, text=True, check=True
    ).stdout


def git_head(path):
    try:
        return _git(path, "rev-parse", "HEAD").strip()
    except (OSError, subprocess.CalledProcessError) as error:
        raise CatalogError("cannot read the git commit of %s: %s" % (path, error))


def git_dirty(path, files):
    """Whether any of files has uncommitted changes in the repo at path."""
    try:
        return bool(_git(path, "status", "--porcelain", "--", *files).strip())
    except (OSError, subprocess.CalledProcessError):
        return False


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
        output = {"generatedFrom": generated_from}
        output.update(catalog)
        # The sweep passes the same file as --previous and --out, so write a
        # sibling and swap it in: a failed write leaves the old catalog whole.
        partial = args.out + ".partial"
        try:
            with open(partial, "w", encoding="utf-8") as handle:
                json.dump(output, handle, indent=2, ensure_ascii=False)
                handle.write("\n")
            os.replace(partial, args.out)
        finally:
            if os.path.exists(partial):
                os.remove(partial)
    except (OSError, ValueError, KeyError, TypeError, CatalogError) as error:
        print("error: %s" % error, file=sys.stderr)
        return 1
    # appCommit names HEAD; say so when the catalog was built from edits HEAD
    # does not contain.
    if git_dirty(_ROOT, [os.path.abspath(__file__), os.path.abspath(args.rules)]):
        print(
            "warning: the generator or its rules have uncommitted changes; "
            "appCommit %s does not contain them" % generated_from["appCommit"],
            file=sys.stderr,
        )
    used = {"%s|%s" % (vendor, product) for vendor, product, _ in descriptors}
    for key in sorted(set(rules.get("idOverrides", {})) - used):
        print("warning: idOverrides key %s matches no descriptor" % key, file=sys.stderr)
    print(
        "%d models, %d unsupported, %d removed -> %s"
        % (len(catalog["models"]), len(catalog["unsupported"]), len(catalog["removed"]), args.out)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
