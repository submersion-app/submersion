#!/usr/bin/env python3
"""Unit tests for manifest.py and candidates.py (GBIF replaced by a stub)."""

import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
import urllib.parse

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


manifest = _load("manifest")
models = _load("models")
candidates = _load("candidates")
build_pack = _load("build_pack")


class FileEntryTests(unittest.TestCase):
    def test_size_and_hash_match_the_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "candidates.json")
            with open(path, "wb") as fh:
                fh.write(b"[1, 2, 3]")
            entry = manifest.file_entry(path, "all")
            self.assertEqual(entry["name"], "candidates.json")
            self.assertEqual(entry["engine"], "all")
            self.assertEqual(entry["size"], 9)
            self.assertEqual(entry["sha256"], hashlib.sha256(b"[1, 2, 3]").hexdigest())


CFD = "cfd-rfdetr-nano-640-20260706"
MEGALODON = "megalodon-yolo11x-403704d"
BIOCLIP = "bioclip-2-vitl14-2957b32"
CONTENTS = {"candidates.json": "a" * 64, "text_embeddings.f16": "b" * 64, "regions.bin": "c" * 64}


def entries(contents):
    """Manifest file entries carrying `contents`' hashes, plus a model."""
    files = [{"name": "detector.coreml.zip", "engine": "coreml", "size": 1, "sha256": "d" * 64}]
    return files + [{"name": n, "engine": "all", "size": 1, "sha256": h} for n, h in contents.items()]


class ContentsTests(unittest.TestCase):
    def test_contents_are_the_shared_naming_files(self):
        self.assertEqual(manifest.contents_of(entries(CONTENTS)), CONTENTS)

    def test_a_missing_file_is_absent(self):
        partial = {"candidates.json": "a" * 64}
        self.assertEqual(manifest.contents_of(entries(partial)), partial)


class NamingForTests(unittest.TestCase):
    MEASURED = [
        {
            "naming": {"provisional": False, "minOpenScore": 0.3},
            "detectorIds": [CFD],
            "classifierId": BIOCLIP,
            "cropFit": "centreCrop",
            "contents": CONTENTS,
            "findings": "docs/design/findings/x.md",
        },
        {
            "naming": {"provisional": False, "minOpenScore": 0.44},
            "detectorIds": [CFD, MEGALODON],
            "classifierId": BIOCLIP,
            "cropFit": "centreCrop",
            "contents": CONTENTS,
            "findings": "docs/design/findings/x.md",
        },
    ]

    def naming(self, detectors=(CFD,), classifier=BIOCLIP, fit="centreCrop", contents=CONTENTS, measured=MEASURED):
        return manifest.naming_for(list(detectors), classifier, fit, contents, measured)

    def test_measured_bars_for_the_exact_measured_pack(self):
        self.assertEqual(self.naming(), self.MEASURED[0]["naming"])

    def test_each_detector_set_gets_its_own_bars(self):
        self.assertEqual(self.naming(detectors=(CFD, MEGALODON)), self.MEASURED[1]["naming"])

    def test_a_pair_in_the_other_order_is_not_the_measured_pair(self):
        # Boxes are pooled in the pack's order, so the order is part of
        # what was measured.
        self.assertIs(self.naming(detectors=(MEGALODON, CFD))["provisional"], True)

    def test_provisional_bars_when_any_naming_file_differs(self):
        for name in CONTENTS:
            changed = dict(CONTENTS, **{name: "e" * 64})
            naming = self.naming(contents=changed)
            self.assertEqual(naming, manifest.NAMING_PROVISIONAL, name)
            self.assertIs(naming["provisional"], True)

    def test_provisional_bars_when_a_naming_file_is_missing(self):
        partial = {k: v for k, v in CONTENTS.items() if k != "regions.bin"}
        self.assertIs(self.naming(contents=partial)["provisional"], True)

    def test_provisional_bars_for_another_classifier(self):
        self.assertIs(self.naming(classifier="another-classifier")["provisional"], True)

    def test_provisional_bars_for_another_detector(self):
        self.assertIs(self.naming(detectors=(MEGALODON,))["provisional"], True)

    def test_provisional_bars_for_another_crop_fitting(self):
        self.assertIs(self.naming(fit="padSquare")["provisional"], True)

    def test_provisional_bars_when_nothing_is_measured(self):
        self.assertIs(self.naming(measured=None)["provisional"], True)

    def test_returned_bars_are_a_copy(self):
        naming = self.naming(measured=None)
        naming["minOpenScore"] = 9
        self.assertNotEqual(manifest.NAMING_PROVISIONAL["minOpenScore"], 9)


class MeasuredBarsTests(unittest.TestCase):
    # Pack 2026.11.18.0030: 9,151 candidates, with the surveyed species and
    # the whole of each GBIF facet.
    MEASURED_PACK = {
        "candidates.json": "4f0dc61c95ab06de3a0b2ecb1401260e23907c3d2ff09d2da165bd9c8c34d50c",
        "text_embeddings.f16": "9aa97fc27a4b91039bd8eb9b6ad7be2da0cc97e4818a1ad81bb7f61b111cde33",
        "regions.bin": "f07736bd1c38fb5321b1900ebf0ab51555a9cf0715af4f364292202d953e4bcd",
    }
    # Pack 2026.11.17.1617: 7,646 candidates, photographed species only. Its
    # bars do not carry over to a pack with a longer list.
    EARLIER_PACK = {
        "candidates.json": "7e36bbf837c705f2679baf29e120462b35707421c96955403e031d61d3e7accb",
        "text_embeddings.f16": "957f0e7ee016dc7ef99a1b96c81b81130439b5dbb9b9170e0d190839b0e1b20e",
        "regions.bin": "ec2f86088a9bd113b7faa96550168e8672ed7e63f6cb2b6d0d64f43e15ac426f",
    }

    def test_the_measured_pack_gets_the_measured_bars(self):
        naming = manifest.naming_for([CFD], BIOCLIP, "centreCrop", self.MEASURED_PACK)
        self.assertIs(naming["provisional"], False)
        self.assertEqual(naming["minOpenScore"], 0.39)
        self.assertEqual(naming["suggestScore"], 0.64)
        self.assertEqual(naming["suggestScoreNoLocation"], 0.79)
        self.assertEqual(naming["confidentScore"], 1.01)
        self.assertEqual(naming["confidentScoreNoLocation"], 1.01)
        self.assertEqual(naming["minCropSide"], 64)
        self.assertEqual(naming["minAllowedCandidates"], 200)
        self.assertEqual(naming["topK"], 5)

    def test_the_pair_pack_gets_its_own_measured_bars(self):
        naming = manifest.naming_for([CFD, MEGALODON], BIOCLIP, "centreCrop", self.MEASURED_PACK)
        self.assertIs(naming["provisional"], False)
        self.assertEqual(
            [naming[k] for k in ("minOpenScore", "suggestScore", "suggestScoreNoLocation", "confidentScore", "confidentScoreNoLocation")],
            [0.44, 0.74, 0.81, 1.01, 1.01],
        )

    def test_a_megalodon_pack_gets_its_own_measured_bars(self):
        naming = manifest.naming_for([MEGALODON], BIOCLIP, "padSquare", self.MEASURED_PACK)
        self.assertIs(naming["provisional"], False)
        self.assertEqual(
            [naming[k] for k in ("minOpenScore", "suggestScore", "suggestScoreNoLocation", "confidentScore", "confidentScoreNoLocation")],
            [0.21, 0.75, 0.70, 1.01, 1.01],
        )

    def test_build_manifest_writes_the_pairs_bars_for_a_pair_pack(self):
        built = manifest.build_manifest(
            pack_version="2026.11.18.0356",
            detector_set="both",
            classifier_id=BIOCLIP,
            embedding_size=768,
            files=entries(self.MEASURED_PACK),
            credits=[],
        )
        self.assertIs(built["naming"]["provisional"], False)
        self.assertEqual(built["naming"]["suggestScore"], 0.74)

    def test_build_manifest_writes_measured_bars_only_for_that_pack(self):
        def build(contents):
            return manifest.build_manifest(
                pack_version="2026.11.17",
                detector_set="cfd",
                classifier_id=BIOCLIP,
                embedding_size=768,
                files=entries(contents),
                credits=[],
            )

        self.assertIs(build(self.MEASURED_PACK)["naming"]["provisional"], False)
        self.assertIs(build(CONTENTS)["naming"]["provisional"], True)

    def test_the_earlier_pack_now_gets_provisional_bars(self):
        naming = manifest.naming_for([CFD], BIOCLIP, "centreCrop", self.EARLIER_PACK)
        self.assertIs(naming["provisional"], True)

    def test_the_measured_bars_name_their_findings(self):
        for entry in manifest.NAMING_MEASURED:
            path = os.path.join(_HERE, "..", "..", entry["findings"])
            self.assertTrue(os.path.exists(path), path)

    def test_each_measured_entry_has_sound_levels(self):
        # build_manifest refuses them only at the end of a whole pack build.
        for entry in manifest.NAMING_MEASURED:
            self.assertEqual(manifest.level_problems(entry["naming"]), [], entry["detectorIds"])

    def test_each_measured_entry_is_a_known_detector_set_at_its_fitting(self):
        sets = {tuple(manifest.DETECTORS[k]["id"] for k in keys): name for name, keys in manifest.DETECTOR_SETS.items()}
        for entry in manifest.NAMING_MEASURED:
            name = sets.get(tuple(entry["detectorIds"]))
            self.assertIsNotNone(name, entry["detectorIds"])
            self.assertEqual(entry["cropFit"], manifest.CROP_FIT[name])


class RelevelTests(unittest.TestCase):
    """Naming levels (issue #4721) added to a published manifest, keeping
    its pack version and files."""

    BASE = {
        "provisional": False,
        "minCropSide": 64,
        "minOpenScore": 0.44,
        "suggestScore": 0.74,
        "confidentScore": 1.01,
        "suggestScoreNoLocation": 0.81,
        "confidentScoreNoLocation": 1.01,
        "minAllowedCandidates": 200,
        "topK": 5,
    }
    LEVELS = [{"id": "balanced", "target": 0.75, "suggestScore": 0.6, "suggestScoreNoLocation": 0.7, "precision": 0.81}]

    def published(self):
        return manifest.build_manifest(
            pack_version="2026.11.18.0356",
            detector_set="both",
            classifier_id=BIOCLIP,
            embedding_size=768,
            files=entries(CONTENTS),
            credits=[],
            naming=dict(self.BASE),
        )

    def measured(self, **naming):
        return [
            {
                "naming": {**self.BASE, "precision": 0.897, "levels": copy.deepcopy(self.LEVELS), **naming},
                "detectorIds": manifest.detector_ids("both"),
                "classifierId": BIOCLIP,
                "cropFit": "centreCrop",
                "contents": CONTENTS,
                "findings": "docs/design/findings/x.md",
            }
        ]

    def test_relevel_adds_levels_and_keeps_the_pack(self):
        published = self.published()
        out = manifest.relevel(published, self.measured())
        self.assertEqual([level["id"] for level in out["naming"]["levels"]], ["balanced"])
        self.assertEqual(out["naming"]["precision"], 0.897)
        self.assertEqual(out["packVersion"], published["packVersion"])
        self.assertEqual(out["files"], published["files"])
        self.assertNotIn("levels", published["naming"])

    def test_relevel_refuses_a_changed_bar(self):
        with self.assertRaises(ValueError):
            manifest.relevel(self.published(), self.measured(suggestScore=0.70))

    def test_relevel_refuses_an_unmeasured_pack(self):
        published = self.published()
        published["files"] = entries({**CONTENTS, "regions.bin": "e" * 64})
        with self.assertRaises(ValueError):
            manifest.relevel(published, self.measured())

    def test_relevel_refuses_bad_levels(self):
        bad = [{**self.LEVELS[0], "suggestScore": 0.9}]
        with self.assertRaises(ValueError):
            manifest.relevel(self.published(), self.measured(levels=bad))

    def test_relevel_reads_a_format_one_pack(self):
        published = self.published()
        published["formatVersion"] = 1
        del published["detectors"], published["boxes"]
        published["detector"] = copy.deepcopy(PackDetectorsTests.FORMAT_ONE["detector"])
        measured = self.measured()
        measured[0]["detectorIds"] = [CFD]
        out = manifest.relevel(published, measured)
        self.assertEqual([level["id"] for level in out["naming"]["levels"]], ["balanced"])
        self.assertEqual(out["detector"], published["detector"])

    def test_build_manifest_refuses_bad_levels(self):
        bad = {**self.BASE, "levels": [{**self.LEVELS[0], "suggestScore": 0.9}]}
        with self.assertRaises(ValueError):
            manifest.build_manifest(
                pack_version="v",
                detector_set="both",
                classifier_id=BIOCLIP,
                embedding_size=768,
                files=[],
                credits=[],
                naming=bad,
            )

    def test_build_manifest_refuses_bad_levels_with_no_provisional_flag(self):
        # The app reads levels unless the bars are marked provisional.
        bad = {k: v for k, v in self.BASE.items() if k != "provisional"}
        bad["levels"] = [{**self.LEVELS[0], "suggestScore": 0.9}]
        with self.assertRaises(ValueError):
            manifest.build_manifest(
                pack_version="v",
                detector_set="both",
                classifier_id=BIOCLIP,
                embedding_size=768,
                files=[],
                credits=[],
                naming=bad,
            )

    def test_build_manifest_copies_levels(self):
        naming = {**self.BASE, "precision": 0.897, "levels": copy.deepcopy(self.LEVELS)}
        built = manifest.build_manifest(
            pack_version="v",
            detector_set="both",
            classifier_id=BIOCLIP,
            embedding_size=768,
            files=[],
            credits=[],
            naming=naming,
        )
        built["naming"]["levels"].append({})
        self.assertEqual(len(naming["levels"]), 1)

    def test_naming_for_copies_levels(self):
        measured = self.measured()
        naming = manifest.naming_for(manifest.detector_ids("both"), BIOCLIP, "centreCrop", CONTENTS, measured)
        naming["levels"].append({})
        self.assertEqual(len(measured[0]["naming"]["levels"]), 1)


class LevelProblemsTests(unittest.TestCase):
    NAMING = RelevelTests.BASE
    BALANCED = RelevelTests.LEVELS[0]
    EAGER = {"id": "eager", "target": 0.65, "suggestScore": 0.5, "suggestScoreNoLocation": 0.6, "precision": 0.7}

    def problems(self, levels, **naming):
        return manifest.level_problems({**self.NAMING, "levels": levels, **naming})

    def test_good_levels_have_no_problems(self):
        self.assertEqual(self.problems([self.BALANCED, self.EAGER], precision=0.897), [])
        self.assertEqual(manifest.level_problems(dict(self.NAMING)), [])

    def test_a_bar_above_the_pack_bar(self):
        self.assertTrue(self.problems([{**self.BALANCED, "suggestScoreNoLocation": 0.85}]))

    def test_eager_above_balanced(self):
        self.assertTrue(self.problems([self.BALANCED, {**self.EAGER, "suggestScore": 0.65}]))

    def test_out_of_order_or_unknown_ids(self):
        self.assertTrue(self.problems([self.EAGER, self.BALANCED]))
        self.assertTrue(self.problems([{**self.BALANCED, "id": "surer"}]))

    def test_a_level_no_lower_than_the_one_above(self):
        same = {**self.BALANCED, "suggestScore": 0.74, "suggestScoreNoLocation": 0.81}
        self.assertTrue(self.problems([same]))
        self.assertTrue(self.problems([self.BALANCED, {**self.EAGER, "suggestScore": 0.6, "suggestScoreNoLocation": 0.7}]))

    def test_accuracy_rising_with_more_names(self):
        self.assertTrue(self.problems([self.BALANCED, {**self.EAGER, "precision": 0.85}], precision=0.897))
        self.assertTrue(self.problems([{**self.BALANCED, "precision": 0.9}], precision=0.897))

    def test_precision_out_of_range(self):
        self.assertTrue(self.problems([{**self.BALANCED, "precision": 0}]))
        self.assertTrue(self.problems([self.BALANCED], precision=1.2))

    def test_a_missing_or_bad_target(self):
        without = {k: v for k, v in self.BALANCED.items() if k != "target"}
        self.assertTrue(self.problems([without]))
        self.assertTrue(self.problems([{**self.BALANCED, "target": "0.75"}]))
        self.assertTrue(self.problems([{**self.BALANCED, "target": True}]))

    def test_malformed_values_are_problems_not_errors(self):
        broken = {**self.BALANCED, "suggestScore": None, "precision": None}
        problems = self.problems([broken, self.EAGER], precision="x")
        self.assertEqual(len(problems), 3)

    def test_measured_entries_have_no_problems(self):
        for entry in manifest.NAMING_MEASURED:
            self.assertEqual(manifest.level_problems(entry["naming"]), [], entry["detectorIds"])


class BuildManifestTests(unittest.TestCase):
    def build(self, detector_set="cfd"):
        return manifest.build_manifest(
            pack_version="2026.11.17",
            detector_set=detector_set,
            classifier_id="bioclip-2-vitl14-2957b32",
            embedding_size=768,
            files=[{"name": "a", "engine": "all", "size": 1, "sha256": "0" * 64}],
            credits=[{"name": "X", "licence": "MIT", "text": ""}],
        )

    def test_format_and_provisional_bars(self):
        m = self.build()
        self.assertEqual(m["formatVersion"], 2)
        self.assertEqual(m["packVersion"], "2026.11.17")
        naming = m["naming"]
        self.assertIs(naming["provisional"], True)
        self.assertEqual(naming["minCropSide"], 64)
        self.assertEqual(naming["minOpenScore"], 0.15)
        self.assertEqual(naming["suggestScore"], 0.50)
        self.assertEqual(naming["confidentScore"], 0.70)
        self.assertEqual(naming["suggestScoreNoLocation"], 0.70)
        self.assertEqual(naming["confidentScoreNoLocation"], 0.70)
        self.assertEqual(naming["minAllowedCandidates"], 200)
        self.assertEqual(naming["topK"], 5)
        self.assertEqual(m["region"], {"cellDegrees": 5, "neighbourCells": 1})
        self.assertEqual(m["cropThumbnailSize"], 320)
        self.assertNotIn("detector", m)

    def test_model_settings_are_the_spikes(self):
        m = self.build()
        (det,) = m["detectors"]
        self.assertEqual(det["id"], CFD)
        self.assertEqual(det["format"], "rfdetr")
        self.assertEqual(det["file"], "detector")
        self.assertEqual(det["inputSize"], 640)
        self.assertEqual(det["mean"], [0.485, 0.456, 0.406])
        self.assertEqual(det["std"], [0.229, 0.224, 0.225])
        self.assertEqual(det["scoreThreshold"], 0.3)
        self.assertEqual(det["maxBoxes"], 8)
        self.assertEqual(m["boxes"], {"mergeIoU": 0.5, "maxBoxes": 8, "cropPadding": 0.10})
        clf = m["classifier"]
        self.assertEqual(clf["inputSize"], 224)
        self.assertEqual(clf["embeddingSize"], 768)
        self.assertEqual(clf["logitScale"], 100.0)
        self.assertEqual(clf["cropFit"], "centreCrop")

    def test_megalodon_alone_is_padded_to_square(self):
        m = self.build("megalodon")
        (det,) = m["detectors"]
        self.assertEqual(det["id"], MEGALODON)
        self.assertEqual(det["format"], "yolo")
        self.assertEqual(det["file"], "detector-megalodon")
        self.assertEqual(det["mean"], [0.0, 0.0, 0.0])
        self.assertEqual(det["std"], [1.0, 1.0, 1.0])
        self.assertEqual(det["scoreThreshold"], 0.25)
        self.assertEqual(det["maxBoxes"], 8)
        self.assertEqual(m["classifier"]["cropFit"], "padSquare")

    def test_both_detectors_in_order_with_centre_crop(self):
        m = self.build("both")
        self.assertEqual([d["id"] for d in m["detectors"]], [CFD, MEGALODON])
        self.assertEqual([d["file"] for d in m["detectors"]], ["detector", "detector-megalodon"])
        self.assertEqual(m["classifier"]["cropFit"], "centreCrop")

    def test_detector_files_are_named_by_their_stem(self):
        self.assertEqual(manifest.model_zip("detector-megalodon", "coreml"), "detector-megalodon.coreml.zip")
        self.assertEqual(manifest.detector_ids("both"), [CFD, MEGALODON])

    def test_a_built_manifest_shares_nothing_with_the_settings(self):
        m = self.build("both")
        m["detectors"][1]["std"][0] = 9.0
        m["boxes"]["maxBoxes"] = 1
        m["classifier"]["mean"][0] = 9.0
        detectors, boxes = manifest.pack_detectors(self.build("both"))
        detectors[0]["mean"][0] = 9.0
        manifest.with_detectors(self.build("both"), detectors, boxes)["detectors"][0]["std"][0] = 9.0
        self.assertEqual(manifest.DETECTORS["megalodon"]["std"], [1.0, 1.0, 1.0])
        self.assertEqual(manifest.DETECTORS["cfd"]["mean"], [0.485, 0.456, 0.406])
        self.assertEqual(manifest.DETECTORS["cfd"]["std"], [0.229, 0.224, 0.225])
        self.assertEqual(manifest.BOXES["maxBoxes"], 8)
        self.assertEqual(manifest.CLASSIFIER_SETTINGS["mean"][0], 0.48145466)

    def test_round_trips_through_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "manifest.json")
            manifest.write_manifest(path, self.build("both"))
            with open(path, encoding="utf-8") as fh:
                self.assertEqual(json.load(fh), self.build("both"))


class PackDetectorsTests(unittest.TestCase):
    FORMAT_ONE = {
        "formatVersion": 1,
        "detector": {
            "id": CFD, "inputSize": 640, "mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225],
            "scoreThreshold": 0.3, "maxBoxes": 8, "cropPadding": 0.1,
        },
        "classifier": {"id": BIOCLIP},
    }

    def test_a_format_one_pack_is_the_fish_detector(self):
        detectors, boxes = manifest.pack_detectors(self.FORMAT_ONE)
        self.assertEqual(detectors, [manifest.DETECTORS["cfd"]])
        self.assertEqual(boxes, manifest.BOXES)

    def test_a_format_two_pack_lists_its_own(self):
        built = manifest.build_manifest(
            pack_version="v", detector_set="both", classifier_id=BIOCLIP, embedding_size=768, files=[], credits=[]
        )
        detectors, boxes = manifest.pack_detectors(built)
        self.assertEqual([d["id"] for d in detectors], [CFD, MEGALODON])
        self.assertEqual(boxes, manifest.BOXES)

    def test_a_format_one_detector_format_is_ignored_as_the_app_does(self):
        old = dict(self.FORMAT_ONE, detector=dict(self.FORMAT_ONE["detector"], detectorFormat="yolo"))
        (detector,), _ = manifest.pack_detectors(old)
        self.assertEqual(detector["format"], "rfdetr")

    def test_with_detectors_writes_format_two_and_keeps_the_rest(self):
        one = manifest.with_detectors(self.FORMAT_ONE, [manifest.DETECTORS["megalodon"]], manifest.BOXES)
        self.assertEqual(one["formatVersion"], 2)
        self.assertNotIn("detector", one)
        self.assertEqual(one["detectors"], [manifest.DETECTORS["megalodon"]])
        self.assertEqual(one["boxes"], manifest.BOXES)
        self.assertEqual(one["classifier"], {"id": BIOCLIP})
        self.assertIn("detector", self.FORMAT_ONE)


class DetectorIdentityTests(unittest.TestCase):
    """The app detects a stored photo again only when the pack's detector
    ids change (SpeciesPackManifest.detectorSetId), so how each detector
    runs is pinned to its id here. Changing any value below needs a new id
    for the detectors it affects; then update this test."""

    PINNED_DETECTORS = {
        "cfd": {
            "id": "cfd-rfdetr-nano-640-20260706",
            "format": "rfdetr",
            "file": "detector",
            "inputSize": 640,
            "mean": [0.485, 0.456, 0.406],
            "std": [0.229, 0.224, 0.225],
            "scoreThreshold": 0.3,
            "maxBoxes": 8,
        },
        "megalodon": {
            "id": "megalodon-yolo11x-403704d",
            "format": "yolo",
            "file": "detector-megalodon",
            "inputSize": 640,
            "mean": [0.0, 0.0, 0.0],
            "std": [1.0, 1.0, 1.0],
            "scoreThreshold": 0.25,
            "maxBoxes": 8,
        },
    }
    PINNED_BOXES = {"mergeIoU": 0.5, "maxBoxes": 8, "cropPadding": 0.10}

    def test_detector_settings_change_only_with_their_id(self):
        self.assertEqual(manifest.DETECTORS, self.PINNED_DETECTORS, "a detector setting changed: give it a new id")

    def test_no_id_has_a_plus_sign(self):
        # The app stores a pair as both ids joined with "+" and refuses an id
        # holding one.
        for detector in manifest.DETECTORS.values():
            self.assertNotIn("+", detector["id"])

    def test_box_settings_change_only_with_new_ids(self):
        self.assertEqual(manifest.BOXES, self.PINNED_BOXES, "a box setting changed: give the detectors new ids")


class UnpackModelTests(unittest.TestCase):
    def pack_with(self, tmp, stem, inner):
        import zipfile

        pack = os.path.join(tmp, "pack")
        os.makedirs(pack, exist_ok=True)
        with zipfile.ZipFile(os.path.join(pack, manifest.model_zip(stem, "coreml")), "w") as zf:
            zf.writestr(f"{inner}/Manifest.json", "{}")
        return pack

    def test_a_pack_model_is_unpacked_into_its_folder(self):
        with tempfile.TemporaryDirectory() as tmp:
            pack = self.pack_with(tmp, "detector-megalodon", "detector.mlpackage")
            folder = os.path.join(tmp, "models", "detector-megalodon")
            path = manifest.unpack_model(pack, "detector-megalodon", folder)
            self.assertEqual(path, os.path.join(folder, "detector.mlpackage"))
            self.assertTrue(os.path.isdir(path))

    def test_a_compiled_model_already_there_is_used(self):
        with tempfile.TemporaryDirectory() as tmp:
            pack = self.pack_with(tmp, "detector", "detector.mlpackage")
            folder = os.path.join(tmp, "models", "detector")
            os.makedirs(os.path.join(folder, "detector.mlmodelc"))
            self.assertEqual(manifest.unpack_model(pack, "detector", folder), os.path.join(folder, "detector.mlmodelc"))
            self.assertEqual(manifest.model_in(folder), os.path.join(folder, "detector.mlmodelc"))

    def test_a_zip_holding_no_model_names_itself(self):
        with tempfile.TemporaryDirectory() as tmp:
            pack = self.pack_with(tmp, "classifier", "weights")
            with self.assertRaises(SystemExit) as stop:
                manifest.unpack_model(pack, "classifier", os.path.join(tmp, "models", "classifier"))
            self.assertIn("classifier.coreml.zip", str(stop.exception))

    def test_an_empty_or_missing_folder_holds_no_model(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(manifest.model_in(os.path.join(tmp, "nothing")))


class FittingTests(unittest.TestCase):
    def test_a_fitting_the_packs_use_is_no_mismatch(self):
        self.assertEqual(manifest.fitting_mismatches(dict(manifest.CROP_FIT)), {})

    def test_a_scorer_choice_unlike_the_packs_is_reported(self):
        chosen = dict(manifest.CROP_FIT, megalodon="centreCrop")
        self.assertEqual(
            manifest.fitting_mismatches(chosen),
            {"megalodon": {"chosen": "centreCrop", "packs use": "padSquare"}},
        )


class ModelIdsTests(unittest.TestCase):
    def test_the_converted_models_are_the_ones_the_manifest_names(self):
        # A new checkpoint in models.py must change the pack's detector id,
        # or measured bars would carry over to a different model.
        self.assertEqual(models.DETECTOR_ID, manifest.DETECTORS["cfd"]["id"])
        for entry in manifest.NAMING_MEASURED:
            self.assertEqual(entry["classifierId"], models.CLASSIFIER_ID)


class CreditsTests(unittest.TestCase):
    def names(self, detector_set):
        return [c["name"] for c in build_pack.credits_for(detector_set)]

    def test_the_fish_detector_pack_credits_it(self):
        names = self.names("cfd")
        self.assertIn("Community Fish Detector", names)
        self.assertIn("RF-DETR", names)
        self.assertNotIn("FathomNet Megalodon", names)

    def test_a_megalodon_pack_credits_mbari_under_cc_by(self):
        credits = {c["name"]: c for c in build_pack.credits_for("megalodon")}
        self.assertNotIn("Community Fish Detector", credits)
        self.assertNotIn("RF-DETR", credits)
        megalodon = credits["FathomNet Megalodon"]
        self.assertEqual(megalodon["licence"], "CC BY 4.0")
        self.assertIn("MBARI", megalodon["text"])

    def test_every_pack_credits_the_classifier_and_gbif(self):
        for detector_set in manifest.DETECTOR_SETS:
            names = self.names(detector_set)
            self.assertIn("BioCLIP 2", names)
            self.assertIn("GBIF occurrence and taxonomy data", names)

    def test_the_pair_credits_both(self):
        names = self.names("both")
        self.assertIn("Community Fish Detector", names)
        self.assertIn("FathomNet Megalodon", names)

    def test_the_fish_detector_credit_says_no_licence_is_stated(self):
        credits = {c["name"]: c for c in build_pack.credits_for("cfd")}
        cfd = credits["Community Fish Detector"]
        self.assertEqual(cfd["licence"], "No licence stated; its authors leave the terms to the user")
        self.assertIn("https://github.com/filippovarini/community-fish-detector/issues/8", cfd["text"])
        self.assertNotIn("awaiting", cfd["licence"])

    def test_the_gbif_credit_names_what_the_pack_uses(self):
        gbif = {c["name"]: c for c in build_pack.credits_for("both")}["GBIF occurrence and taxonomy data"]
        self.assertIn("Species names", gbif["text"])
        self.assertIn("counts of where each species has been recorded", gbif["text"])


class CategoryTests(unittest.TestCase):
    def cat(self, kingdom="Animalia", phylum="Chordata", klass=None, order=None):
        return candidates.category_for(
            {"kingdom": kingdom, "phylum": phylum, "class": klass, "order": order}
        )

    def test_ray_finned_fish_have_no_class_in_the_gbif_backbone(self):
        self.assertEqual(self.cat(order="Perciformes"), "fish")
        self.assertEqual(self.cat(klass="Petromyzonti", order="Petromyzontiformes"), "fish")

    def test_sharks_and_rays(self):
        self.assertEqual(self.cat(klass="Elasmobranchii", order="Orectolobiformes"), "shark")
        self.assertEqual(self.cat(klass="Elasmobranchii", order="Myliobatiformes"), "ray")

    def test_turtles_mammals_and_reptiles(self):
        self.assertEqual(self.cat(klass="Testudines"), "turtle")
        self.assertEqual(self.cat(klass="Mammalia", order="Cetacea"), "mammal")
        self.assertEqual(self.cat(klass="Squamata"), "other")

    def test_corals_and_anemones(self):
        self.assertEqual(self.cat(phylum="Cnidaria", klass="Anthozoa", order="Scleractinia"), "coral")
        self.assertEqual(self.cat(phylum="Cnidaria", klass="Anthozoa", order="Actiniaria"), "invertebrate")

    def test_algae_tunicates_and_other_animals(self):
        self.assertEqual(self.cat(kingdom="Chromista", phylum="Ochrophyta"), "plant")
        self.assertEqual(self.cat(klass="Ascidiacea"), "invertebrate")
        self.assertEqual(self.cat(phylum="Mollusca", klass="Cephalopoda"), "invertebrate")
        self.assertEqual(self.cat(kingdom="Fungi", phylum="Ascomycota"), "other")


class CatalogueKeyTests(unittest.TestCase):
    def test_one_candidate_per_key_in_catalogue_order(self):
        catalogue = [
            {"id": "sp_b", "commonName": "B", "scientificName": "B b", "category": "fish"},
            {"id": "sp_manta_ray", "commonName": "Manta", "scientificName": "Mobula alfredi", "category": "ray"},
            {"id": "sp_reef_manta_ray", "commonName": "Reef Manta", "scientificName": "Mobula alfredi", "category": "ray"},
        ]
        # The key generator gives each key one catalogue species.
        species_keys = {"9241141": "sp_reef_manta_ray", "7": "sp_b"}
        rows = candidates.catalogue_candidates(catalogue, species_keys)
        self.assertEqual([r["catalogId"] for r in rows], ["sp_b", "sp_reef_manta_ray"])
        self.assertEqual(rows[1]["gbifKey"], 9241141)
        self.assertEqual(rows[1]["category"], "ray")
        self.assertEqual(rows[1]["commonName"], "Reef Manta")


class ExpansionTests(unittest.TestCase):
    def test_orders_of_aquatic_categories_only(self):
        records = [
            ("fish", {"orderKey": 587, "order": "Perciformes"}),
            ("shark", {"orderKey": 765, "order": "Orectolobiformes"}),
            ("invertebrate", {"orderKey": 980, "order": "Nudibranchia"}),
            ("coral", {"orderKey": 1, "order": "Scleractinia"}),
            ("mammal", {"orderKey": 731, "order": "Artiodactyla"}),
            ("plant", {"orderKey": 1369, "order": "Poales"}),
            ("turtle", {"orderKey": 3, "order": "Testudines"}),
            ("other", {"orderKey": 4, "order": "Anura"}),
            ("fish", {"orderKey": None, "order": None}),
        ]
        self.assertEqual(candidates.expansion_order_keys(records), {587, 765, 980, 1})

    def test_orders_with_many_land_species_are_left_out(self):
        records = [("invertebrate", {"orderKey": 9, "order": "Stylommatophora"})]
        self.assertEqual(candidates.expansion_order_keys(records), set())


class SurveyQueryTests(unittest.TestCase):
    def test_survey_counts_only_present_shallow_human_observations(self):
        f = dict(candidates.SURVEY_FILTERS)
        self.assertEqual(f["basis_of_record"], "HUMAN_OBSERVATION")
        self.assertEqual(f["occurrence_status"], "PRESENT")
        self.assertEqual(f["depth"], "0,40")
        self.assertNotIn("media_type", f)

    def test_photo_query_is_unchanged(self):
        self.assertEqual(
            candidates.PHOTO_FILTERS,
            [("media_type", "StillImage"), ("basis_of_record", "HUMAN_OBSERVATION")],
        )

    def test_photo_cache_is_not_an_earlier_paged_page(self):
        # Earlier builds paged the photo facet 1,000 at a time and cached
        # page 0 here; that page must not answer the whole query.
        path = candidates.facet_cache_path("w", "photographed", [3, 1], candidates.PHOTO_FILTERS, 50, 20000)
        digest = hashlib.sha256(b"1,3").hexdigest()[:12]
        self.assertNotEqual(path, os.path.join("w", "facets", f"species_{digest}_50_0.json"))

    def test_survey_cache_differs_from_the_photo_cache(self):
        photo = candidates.facet_cache_path("w", "photographed", [1], candidates.PHOTO_FILTERS, 50, 20000)
        survey = candidates.facet_cache_path("w", "surveyed", [1], candidates.SURVEY_FILTERS, 50, 20000)
        self.assertNotEqual(photo, survey)

    def test_cache_changes_with_filters_taxa_floor_and_limit(self):
        base = candidates.facet_cache_path("w", "surveyed", [1], candidates.SURVEY_FILTERS, 50, 20000)
        for other in (
            candidates.facet_cache_path("w", "surveyed", [1], [("depth", "0,30")], 50, 20000),
            candidates.facet_cache_path("w", "surveyed", [1, 2], candidates.SURVEY_FILTERS, 50, 20000),
            candidates.facet_cache_path("w", "surveyed", [1], candidates.SURVEY_FILTERS, 25, 20000),
            candidates.facet_cache_path("w", "surveyed", [1], candidates.SURVEY_FILTERS, 50, 1000),
        ):
            self.assertNotEqual(base, other)


class SpeciesFacetTests(unittest.TestCase):
    """The facet queries, with GBIF replaced by a stub that records each
    request and answers with `counts`."""

    def fetch(self, fn, counts, **kwargs):
        calls = []

        def fake_get_json(url, cache_path):
            calls.append((url, cache_path))
            return {"facets": [{"field": "SPECIES_KEY", "counts": counts}]}

        real = candidates._get_json
        candidates._get_json = fake_get_json
        self.addCleanup(setattr, candidates, "_get_json", real)
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            found = fn([7, 3], "w", **kwargs)
        return found, calls, stderr.getvalue()

    @staticmethod
    def params(url):
        return urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)

    def test_photographed_species_come_from_one_request(self):
        # GBIF's facet paging repeats and skips species at page boundaries,
        # so the whole facet is asked for at once.
        counts = [{"name": "11", "count": 90}, {"name": "12", "count": 60}]
        found, calls, _ = self.fetch(candidates.fetch_photographed_species, counts, min_images=50)
        self.assertEqual(found, [(11, 90), (12, 60)])
        self.assertEqual(len(calls), 1)
        q = self.params(calls[0][0])
        self.assertEqual(q["media_type"], ["StillImage"])
        self.assertEqual(q["basis_of_record"], ["HUMAN_OBSERVATION"])
        self.assertEqual(q["facetMincount"], ["50"])
        self.assertEqual(q["facetLimit"], ["20000"])
        self.assertNotIn("facetOffset", q)
        self.assertEqual(sorted(q["taxon_key"]), ["3", "7"])
        self.assertIn(os.path.join("w", "facets", "photographed_"), calls[0][1])

    def test_surveyed_species_ask_for_present_shallow_records(self):
        counts = [{"name": "21", "count": 900}]
        found, calls, _ = self.fetch(candidates.fetch_surveyed_species, counts, min_records=50)
        self.assertEqual(found, [(21, 900)])
        self.assertEqual(len(calls), 1)
        q = self.params(calls[0][0])
        self.assertEqual(q["occurrence_status"], ["PRESENT"])
        self.assertEqual(q["depth"], ["0,40"])
        self.assertEqual(q["basis_of_record"], ["HUMAN_OBSERVATION"])
        self.assertNotIn("media_type", q)
        self.assertNotIn("facetOffset", q)
        self.assertIn(os.path.join("w", "facets", "surveyed_"), calls[0][1])

    def test_a_full_answer_warns_that_species_may_be_missing(self):
        counts = [{"name": "1", "count": 9}, {"name": "2", "count": 8}]
        _, _, err = self.fetch(candidates.fetch_surveyed_species, counts, min_records=5, limit=2)
        self.assertIn("GBIF returned 2 surveyed species, the limit", err)

    def test_a_short_answer_does_not_warn(self):
        _, _, err = self.fetch(candidates.fetch_surveyed_species, [{"name": "1", "count": 9}], min_records=5, limit=2)
        self.assertEqual(err, "")


class WantedKeysTests(unittest.TestCase):
    def test_photographed_first_then_surveyed(self):
        self.assertEqual(
            candidates.wanted_keys([(1, 90), (2, 80)], [(3, 900), (4, 50)], set(), 10), [1, 2, 3, 4]
        )

    def test_a_species_in_both_is_listed_once_at_its_photographed_place(self):
        self.assertEqual(
            candidates.wanted_keys([(1, 90), (2, 80)], [(2, 5000), (3, 60)], set(), 10), [1, 2, 3]
        )

    def test_species_already_on_the_list_are_skipped(self):
        self.assertEqual(candidates.wanted_keys([(1, 90), (2, 80)], [(3, 60)], {1, 3}, 10), [2])

    def test_survey_only_species_are_cut_first(self):
        self.assertEqual(candidates.wanted_keys([(1, 90), (2, 80)], [(3, 900)], set(), 2), [1, 2])

    def test_no_room_adds_nothing(self):
        self.assertEqual(candidates.wanted_keys([(1, 90)], [(3, 900)], set(), 0), [])
        self.assertEqual(candidates.wanted_keys([(1, 90)], [(3, 900)], set(), -5), [])

    def test_a_key_repeated_within_a_ranking_counts_once(self):
        self.assertEqual(candidates.wanted_keys([(1, 90), (1, 90)], [(3, 9), (3, 9)], set(), 10), [1, 3])


class PackVersionTests(unittest.TestCase):
    def test_two_builds_on_one_day_get_different_versions(self):
        import datetime

        morning = datetime.datetime(2026, 11, 17, 9, 5, tzinfo=datetime.timezone.utc)
        evening = datetime.datetime(2026, 11, 17, 18, 40, tzinfo=datetime.timezone.utc)
        self.assertEqual(build_pack.default_version(morning), "2026.11.17.0905")
        self.assertNotEqual(build_pack.default_version(morning), build_pack.default_version(evening))


class BuildOptionsTests(unittest.TestCase):
    def test_defaults(self):
        args = build_pack.parse_args(["--out", "x"])
        self.assertEqual(args.detectors, "cfd")
        self.assertEqual(args.max_candidates, 10000)
        self.assertEqual(args.min_images, 50)
        self.assertEqual(args.min_survey_records, 50)

    def test_detectors_choose_a_set(self):
        self.assertEqual(build_pack.parse_args(["--out", "x", "--detectors", "both"]).detectors, "both")
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            build_pack.parse_args(["--out", "x", "--detectors", "ssd"])

    def test_survey_floor_is_its_own_option(self):
        args = build_pack.parse_args(["--out", "x", "--min-survey-records", "25"])
        self.assertEqual(args.min_survey_records, 25)
        self.assertEqual(args.min_images, 50)


if __name__ == "__main__":
    unittest.main()
