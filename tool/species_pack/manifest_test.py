#!/usr/bin/env python3
"""Unit tests for manifest.py and the pure parts of candidates.py."""

import hashlib
import importlib.util
import json
import os
import tempfile
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


manifest = _load("manifest")
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


class BuildManifestTests(unittest.TestCase):
    def build(self):
        return manifest.build_manifest(
            pack_version="2026.11.17",
            detector_id="cfd-rfdetr-nano-640-20260706",
            classifier_id="bioclip-2-vitl14-2957b32",
            embedding_size=768,
            files=[{"name": "a", "engine": "all", "size": 1, "sha256": "0" * 64}],
            credits=[{"name": "X", "licence": "MIT", "text": ""}],
        )

    def test_format_and_provisional_bars(self):
        m = self.build()
        self.assertEqual(m["formatVersion"], 1)
        self.assertEqual(m["packVersion"], "2026.11.17")
        naming = m["naming"]
        self.assertIs(naming["provisional"], True)
        self.assertEqual(naming["minCropSide"], 64)
        self.assertEqual(naming["minOpenScore"], 0.15)
        self.assertEqual(naming["suggestScore"], 0.50)
        self.assertEqual(naming["confidentScore"], 0.70)
        self.assertEqual(naming["suggestScoreNoLocation"], 0.70)
        self.assertEqual(naming["minAllowedCandidates"], 200)
        self.assertEqual(naming["topK"], 5)
        self.assertEqual(m["region"], {"cellDegrees": 5, "neighbourCells": 1})
        self.assertEqual(m["cropThumbnailSize"], 320)

    def test_model_settings_are_the_spikes(self):
        m = self.build()
        det = m["detector"]
        self.assertEqual(det["inputSize"], 640)
        self.assertEqual(det["mean"], [0.485, 0.456, 0.406])
        self.assertEqual(det["std"], [0.229, 0.224, 0.225])
        self.assertEqual(det["scoreThreshold"], 0.3)
        self.assertEqual(det["maxBoxes"], 8)
        self.assertEqual(det["cropPadding"], 0.10)
        clf = m["classifier"]
        self.assertEqual(clf["inputSize"], 224)
        self.assertEqual(clf["embeddingSize"], 768)
        self.assertEqual(clf["logitScale"], 100.0)
        self.assertEqual(clf["cropFit"], "padSquare")

    def test_round_trips_through_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "manifest.json")
            manifest.write_manifest(path, self.build())
            with open(path, encoding="utf-8") as fh:
                self.assertEqual(json.load(fh), self.build())


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



class PackVersionTests(unittest.TestCase):
    def test_two_builds_on_one_day_get_different_versions(self):
        import datetime

        morning = datetime.datetime(2026, 11, 17, 9, 5, tzinfo=datetime.timezone.utc)
        evening = datetime.datetime(2026, 11, 17, 18, 40, tzinfo=datetime.timezone.utc)
        self.assertEqual(build_pack.default_version(morning), "2026.11.17.0905")
        self.assertNotEqual(build_pack.default_version(morning), build_pack.default_version(evening))


if __name__ == "__main__":
    unittest.main()
