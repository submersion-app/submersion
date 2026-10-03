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
