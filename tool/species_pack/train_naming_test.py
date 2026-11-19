#!/usr/bin/env python3
"""Unit tests for train_naming.py (issue #4724). Needs numpy; the training
tests also need torch and are skipped without it.

    .venv-species-pack/bin/python -I tool/species_pack/train_naming_test.py
"""

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from unittest import mock

import numpy as np

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)
_spec = importlib.util.spec_from_file_location("train_naming", os.path.join(_HERE, "train_naming.py"))
train_naming = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(train_naming)

try:
    import torch  # noqa: F401

    HAVE_TORCH = True
except ImportError:
    HAVE_TORCH = False


def toy():
    """Two species whose name rows point the wrong way, and a third with no
    photos."""
    rng = np.random.default_rng(1)
    name_rows = np.array([[0, 1, 0, 0], [1, 0, 0, 0], [0, 0, 1, 0]], dtype=np.float32)
    a = np.array([1, 0, 0, 0], dtype=np.float32) + rng.normal(0, 0.05, (40, 4)).astype(np.float32)
    b = np.array([0, 1, 0, 0], dtype=np.float32) + rng.normal(0, 0.05, (40, 4)).astype(np.float32)
    x = np.concatenate([a, b])
    y = np.array([0] * 40 + [1] * 40)
    return name_rows, x, y


class F16Test(unittest.TestCase):
    def test_f16_refuses_nan_and_overflow(self):
        with self.assertRaises(ValueError):
            train_naming.f16_bytes(np.array([[1.0, np.nan]], dtype=np.float32))
        with self.assertRaises(ValueError):
            train_naming.f16_bytes(np.array([[70000.0, 0.0]], dtype=np.float32))
        data = train_naming.f16_bytes(np.array([[1.0, -2.5]], dtype=np.float32))
        self.assertEqual(np.frombuffer(data, dtype="<f2").tolist(), [1.0, -2.5])


class FinishTest(unittest.TestCase):
    def test_finish_blends_and_scales(self):
        trained = np.array([[2.0, 0.0]], dtype=np.float32)
        names = np.array([[0.0, 2.0]], dtype=np.float32)
        out = train_naming.finish(trained, names, blend=0.25, sharpness=2.0)
        np.testing.assert_allclose(out, [[1.0, 3.0]])


@unittest.skipUnless(HAVE_TORCH, "needs torch")
class TrainTest(unittest.TestCase):
    def test_untrained_rows_are_unchanged(self):
        name_rows, x, y = toy()
        rows = train_naming.train(name_rows, x, y, anchor=1e-3, epochs=5, lr=0.05, seed=0, device="cpu")
        np.testing.assert_array_equal(rows[2], name_rows[2])

    def test_training_separates_two_toy_species(self):
        name_rows, x, y = toy()
        before = train_naming.top1(name_rows, x, y)
        rows = train_naming.train(name_rows, x, y, anchor=1e-4, epochs=40, lr=0.05, seed=0, device="cpu")
        self.assertEqual(before, 0.0)
        self.assertEqual(train_naming.top1(rows, x, y), 1.0)
        self.assertLess(train_naming.validation_loss(rows, x, y), train_naming.validation_loss(name_rows, x, y))


class LoadTest(unittest.TestCase):
    def test_load_excludes_held_back_species(self):
        with tempfile.TemporaryDirectory() as work:
            os.makedirs(os.path.join(work, "embeddings"))
            records = [
                {"id": "1", "candidate": 0, "gbif_key": 11},
                {"id": "2", "candidate": 1, "gbif_key": 22},
                {"id": "3", "candidate": 0, "gbif_key": 11},
            ]
            with open(os.path.join(work, "selected.json"), "w", encoding="utf-8") as fh:
                json.dump({"train": records[:2], "validation": records[2:]}, fh)
            np.save(os.path.join(work, "embeddings", "0000.npy"), np.array([[3, 4], [1, 0], [0, 2]], dtype=np.float32))
            with open(os.path.join(work, "embeddings", "0000.jsonl"), "w", encoding="utf-8") as fh:
                for r in records:
                    fh.write(json.dumps(r) + "\n")
            x, y, kept = train_naming.load(work, part="train", exclude={22})
            self.assertEqual([r["id"] for r in kept], ["1"])
            self.assertEqual(y.tolist(), [0])
            np.testing.assert_allclose(x, [[0.6, 0.8]])
            xv, yv, _ = train_naming.load(work, part="validation")
            self.assertEqual(yv.tolist(), [0])

    def test_load_with_no_photos_says_so(self):
        with tempfile.TemporaryDirectory() as work:
            os.makedirs(os.path.join(work, "embeddings"))
            with open(os.path.join(work, "selected.json"), "w", encoding="utf-8") as fh:
                json.dump({"train": [{"id": "1"}], "validation": []}, fh)
            np.save(os.path.join(work, "embeddings", "0000.npy"), np.zeros((0, 0), dtype=np.float32))
            open(os.path.join(work, "embeddings", "0000.jsonl"), "w", encoding="utf-8").close()
            with self.assertRaisesRegex(SystemExit, "no validation photos"):
                train_naming.load(work, part="validation")


class SearchTest(unittest.TestCase):
    def test_search_stops_when_no_setting_has_a_finite_loss(self):
        name_rows, x, y = toy()
        diverged = np.full_like(name_rows, np.nan)
        with mock.patch.object(train_naming, "train", return_value=diverged):
            with self.assertRaisesRegex(SystemExit, "finite validation loss"):
                train_naming.search(name_rows, (x, y), (x, y), log=lambda _: None)


class NameRowsTest(unittest.TestCase):
    def pack(self, folder, scale):
        with open(os.path.join(folder, "manifest.json"), "w", encoding="utf-8") as fh:
            json.dump({"classifier": {"embeddingSize": 2, "logitScale": scale}}, fh)
        with open(os.path.join(folder, "candidates.json"), "w", encoding="utf-8") as fh:
            json.dump([{}, {}, {}], fh)
        np.arange(6, dtype="<f2").tofile(os.path.join(folder, "text_embeddings.f16"))

    def test_name_rows_read_the_pack(self):
        with tempfile.TemporaryDirectory() as folder:
            self.pack(folder, train_naming.SCALE)
            self.assertEqual(train_naming.name_rows_of(folder).shape, (3, 2))

    def test_a_pack_scored_at_another_scale_is_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            self.pack(folder, 10.0)
            with self.assertRaisesRegex(SystemExit, "logitScale"):
                train_naming.name_rows_of(folder)


if __name__ == "__main__":
    unittest.main()
