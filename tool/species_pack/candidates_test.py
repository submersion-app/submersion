#!/usr/bin/env python3
"""Unit tests for candidates.py (GBIF replaced by a stub)."""

import contextlib
import hashlib
import importlib.util
import io
import os
import unittest
import urllib.parse

_HERE = os.path.dirname(os.path.abspath(__file__))


def _load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(_HERE, f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


candidates = _load("candidates")


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


if __name__ == "__main__":
    unittest.main()
