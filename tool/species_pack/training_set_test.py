#!/usr/bin/env python3
"""Unit tests for training_set.py, the rules that choose the naming layer's
training and validation photos (issue #4724)."""

import csv
import importlib.util
import os
import sys
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
_spec = importlib.util.spec_from_file_location("training_set", os.path.join(_HERE, "training_set.py"))
training_set = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(training_set)

BEFORE = "2024-06-30T23:00:00Z"
AFTER = "2024-07-01T00:00:00Z"


def observation(licence="cc-by", url="https://x/photos/1/square.jpg", obscured=False):
    return {
        "id": 7,
        "uri": "https://www.inaturalist.org/observations/7",
        "created_at": AFTER,
        "location": "12.5,-68.25",
        "obscured": obscured,
        "user": {"login": "diver"},
        "taxon": {"id": 1, "name": "Scarus vetula", "rank": "species"},
        "photos": [{"id": 9, "url": url, "license_code": licence, "attribution": "(c) Diver, some rights reserved"}]
        if licence is not None
        else [],
    }


def record(i, *, observer="a", created=AFTER, key=1, candidate=0):
    return {
        "id": str(i),
        "uri": f"https://www.inaturalist.org/observations/{i}",
        "created": created,
        "observer": observer,
        "candidate": candidate,
        "gbif_key": key,
        "lat": None,
        "lon": None,
        "photo_url": f"https://x/{i}/large.jpg",
        "licence": "cc-by",
        "attribution": f"(c) {observer}",
    }


class ObservationRecordTest(unittest.TestCase):
    def test_record_keeps_open_and_nc_licences(self):
        for licence in ("cc0", "cc-by", "cc-by-nc"):
            self.assertIsNotNone(training_set.observation_record(observation(licence), 3, 11), licence)
        for licence in ("cc-by-sa", "cc-by-nc-sa", "cc-by-nd", "cc-by-nc-nd", None):
            self.assertIsNone(training_set.observation_record(observation(licence), 3, 11), licence)

    def test_record_uses_large_photo_and_hidden_place(self):
        r = training_set.observation_record(observation(), 3, 11)
        self.assertEqual(r["photo_url"], "https://x/photos/1/large.jpg")
        self.assertEqual((r["lat"], r["lon"]), (12.5, -68.25))
        self.assertEqual((r["id"], r["observer"], r["candidate"], r["gbif_key"]), ("7", "diver", 3, 11))
        hidden = training_set.observation_record(observation(obscured=True), 3, 11)
        self.assertIsNone(hidden["lat"])
        self.assertIsNone(hidden["lon"])

    def test_a_photo_without_a_url_is_skipped(self):
        self.assertIsNone(training_set.observation_record(observation(url=None), 3, 11))
        missing = observation()
        del missing["photos"][0]["url"]
        self.assertIsNone(training_set.observation_record(missing, 3, 11))


class GuardTest(unittest.TestCase):
    def test_guard_drops_test_ids_and_post_cutoff_test_observers(self):
        records = [
            record(1, observer="other"),
            record(2, observer="tester", created=BEFORE),
            record(3, observer="tester", created=AFTER),
            record(4, observer="other", created=AFTER),
        ]
        kept = training_set.guard(records, test_ids={"1"}, test_observers={"tester"})
        self.assertEqual([r["id"] for r in kept], ["2", "4"])


class SplitTest(unittest.TestCase):
    def test_validation_observers_are_post_cutoff_only_and_stable(self):
        records = [record(i, observer=f"o{i}", created=AFTER) for i in range(1000)]
        records.append(record(5000, observer="early", created=BEFORE))
        chosen = training_set.validation_observers(records)
        self.assertEqual(chosen, training_set.validation_observers(list(reversed(records))))
        self.assertNotIn("early", chosen)
        self.assertTrue(70 <= len(chosen) <= 130, len(chosen))

    def test_split_keeps_validation_observers_out_of_training(self):
        records = [
            record(1, observer="v", created=BEFORE),
            record(2, observer="v", created=AFTER),
            record(3, observer="t", created=BEFORE),
            record(4, observer="t", created=AFTER),
        ]
        train, validation = training_set.split(records, {"v"})
        self.assertEqual([r["id"] for r in train], ["3", "4"])
        self.assertEqual([r["id"] for r in validation], ["2"])


class CapTest(unittest.TestCase):
    def test_cap_prefers_post_cutoff_then_newest(self):
        records = [record(i, observer=f"o{i}", created=BEFORE) for i in range(40)]
        records += [record(100 + i, observer=f"p{i}", created=f"2025-01-{i + 1:02d}T00:00:00Z") for i in range(20)]
        kept = training_set.cap(records)
        self.assertEqual(len(kept), training_set.PER_SPECIES)
        after = [r for r in kept if r["created"] >= training_set.CUTOFF]
        self.assertEqual(len(after), 20)
        self.assertEqual(kept[0]["id"], "119")

    def test_cap_limits_each_observer_per_species(self):
        records = [record(i, observer="busy", key=1) for i in range(8)]
        records += [record(10 + i, observer="busy", key=2, candidate=1) for i in range(8)]
        kept = training_set.cap(records)
        self.assertEqual(sum(1 for r in kept if r["gbif_key"] == 1), training_set.PER_OBSERVER)
        self.assertEqual(sum(1 for r in kept if r["gbif_key"] == 2), training_set.PER_OBSERVER)


class HeldBackTest(unittest.TestCase):
    def test_held_back_species_is_seeded_and_from_underwater_inat_rows(self):
        rows = [{"source": "inaturalist", "underwater": "yes", "gbif_key": str(k)} for k in range(1, 400)]
        rows += [{"source": "inaturalist", "underwater": "no", "gbif_key": "9001"}]
        rows += [{"source": "commons", "underwater": "", "gbif_key": ""}]
        keys = training_set.held_back_species(rows)
        self.assertEqual(len(keys), training_set.HELD_BACK)
        self.assertEqual(keys, training_set.held_back_species(list(reversed(rows))))
        self.assertNotIn(9001, keys)
        self.assertTrue(all(isinstance(k, int) for k in keys))

    def test_without_species_drops_every_record_of_a_key(self):
        records = [record(1, key=5), record(2, key=6), record(3, key=5)]
        self.assertEqual([r["id"] for r in training_set.without_species(records, {5})], ["2"])


class RowsHashTest(unittest.TestCase):
    def test_rows_hash_is_the_manifest_s_text_embeddings_hash(self):
        manifest = {
            "files": [
                {"name": "candidates.json", "sha256": "a" * 64},
                {"name": "text_embeddings.f16", "sha256": "b" * 64},
            ]
        }
        self.assertEqual(training_set.rows_sha256(manifest), "b" * 64)
        self.assertIsNone(training_set.rows_sha256({"files": []}))


class CreditsTest(unittest.TestCase):
    def test_write_credits_sorted_one_row_per_record(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "training_photos.csv")
            training_set.write_credits(path, [record(20), record(3)])
            with open(path, encoding="utf-8", newline="") as fh:
                rows = list(csv.DictReader(fh))
        self.assertEqual([r["id"] for r in rows], ["3", "20"])
        self.assertEqual(set(rows[0]), {"id", "uri", "licence", "attribution"})


if __name__ == "__main__":
    unittest.main()
