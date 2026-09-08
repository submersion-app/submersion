#!/usr/bin/env python3
"""Unit tests for dive_site_harvester.py.

Run: python3 scripts/dive_site_harvester_test.py

These cover the metadata build stamp. The harvester writes `generated_at`
into two shipped assets, and the conventional-looking `isoformat() + "Z"`
produces a string no ISO-8601 parser accepts, so the stamp is worthless to
anyone who later wants to know how stale the bundled data is.
"""

import importlib.util
import ast
import os
import unittest
from datetime import datetime, timezone

_HERE = os.path.dirname(os.path.abspath(__file__))
_SOURCE = os.path.join(_HERE, "dive_site_harvester.py")

try:
    import overpy  # noqa: F401
    import requests  # noqa: F401
    import tenacity  # noqa: F401
    import tqdm  # noqa: F401

    _HAS_DEPS = True
except ImportError:  # pragma: no cover - exercised only on bare runners
    _HAS_DEPS = False

if _HAS_DEPS:
    _spec = importlib.util.spec_from_file_location(
        "dive_site_harvester",
        _SOURCE,
    )
    dive_site_harvester = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(dive_site_harvester)


@unittest.skipUnless(_HAS_DEPS, "the harvester's dependencies are not installed")
class UtcTimestampTest(unittest.TestCase):
    def test_stamps_a_timestamp_that_actually_parses(self):
        # isoformat() already writes "+00:00", so appending "Z" would give
        # "...+00:00Z" and every ISO-8601 parser would reject it.
        stamp = dive_site_harvester.utc_timestamp()

        self.assertTrue(stamp.endswith("Z"), stamp)
        self.assertNotIn("+00:00", stamp)
        parsed = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        self.assertEqual(parsed.tzinfo, timezone.utc)

    def test_stamps_the_current_instant(self):
        before = datetime.now(timezone.utc).replace(microsecond=0)
        stamp = dive_site_harvester.utc_timestamp()
        after = datetime.now(timezone.utc)

        parsed = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        self.assertGreaterEqual(parsed, before)
        self.assertLessEqual(parsed, after)


class GeneratedAtCallSiteTest(unittest.TestCase):
    """The helper is only worth having if every call site reaches for it.

    A source scan rather than a call because the three stamps are written
    deep inside methods that only run after a full Overpass harvest. The
    scan walks the parsed tree rather than the raw text so prose about the
    bug -- this docstring included -- cannot trip it.
    """

    def setUp(self):
        with open(_SOURCE, encoding="utf-8") as f:
            self.tree = ast.parse(f.read())

    def test_no_call_site_appends_z_to_an_isoformat(self):
        offenders = [
            node.lineno
            for node in ast.walk(self.tree)
            if isinstance(node, ast.BinOp)
            and isinstance(node.op, ast.Add)
            and isinstance(node.left, ast.Call)
            and isinstance(node.left.func, ast.Attribute)
            and node.left.func.attr == "isoformat"
        ]

        self.assertEqual(offenders, [], "isoformat() already carries +00:00")

    def test_every_generated_at_goes_through_the_helper(self):
        stamps = [
            ast.unparse(value)
            for node in ast.walk(self.tree)
            if isinstance(node, ast.Dict)
            for key, value in zip(node.keys, node.values)
            if isinstance(key, ast.Constant) and key.value == "generated_at"
        ]

        self.assertEqual(stamps, ["utc_timestamp()"] * 3)


if __name__ == "__main__":
    unittest.main()
