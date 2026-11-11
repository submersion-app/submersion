#!/usr/bin/env python3
"""Unit tests for generate_country_names.py.

Run: python3 scripts/geography/generate_country_names_test.py

The generator turns CLDR territory names into the table the app resolves a
site's free-text country with (issue #4426). A name it maps wrongly puts a
wrong flag beside a site, so the table keeps only assigned ISO codes and
drops any name that means two countries.
"""

import importlib.util
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "generate_country_names", os.path.join(_HERE, "generate_country_names.py")
)
gen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gen)

# Shaped like CLDR's supplemental codeMappings.json: private-use codes (AA,
# numeric 958) and exceptional reservations (AC, no numeric) carry an alpha3
# too, so an alpha3 alone does not make a code a country.
CODE_MAPPINGS = {
    "MX": {"_numeric": "484", "_alpha3": "MEX"},
    "GB": {"_numeric": "826", "_alpha3": "GBR"},
    "MV": {"_numeric": "462", "_alpha3": "MDV"},
    "AA": {"_numeric": "958", "_alpha3": "AAA"},
    "AC": {"_alpha3": "ASC"},
    "EU": {"_numeric": "967"},
    "QO": {},
    "001": {"_numeric": "001"},
}


class FoldTest(unittest.TestCase):
    def test_folds_case_and_accents(self):
        self.assertEqual(gen.fold("  Curaçao "), "curacao")

    def test_folds_hungarian_double_acute(self):
        self.assertEqual(gen.fold("Magyarország"), "magyarorszag")

    def test_drops_periods(self):
        self.assertEqual(gen.fold("U.S.A."), "usa")

    def test_reads_ampersand_as_and(self):
        self.assertEqual(gen.fold("Trinidad & Tobago"), "trinidad and tobago")

    def test_drops_a_leading_the(self):
        self.assertEqual(gen.fold("The Bahamas"), "bahamas")
        self.assertEqual(gen.fold("Theodore"), "theodore")

    def test_collapses_inner_whitespace(self):
        self.assertEqual(gen.fold("Costa   Rica"), "costa rica")

    def test_strips_combining_marks(self):
        self.assertEqual(gen.fold("México"), "mexico")

    def test_folds_wider_latin_letters(self):
        self.assertEqual(gen.fold("Česko"), "cesko")
        self.assertEqual(gen.fold("Türkiye"), "turkiye")
        self.assertEqual(gen.fold("Łódź"), "lodz")

    def test_keeps_non_latin_scripts(self):
        self.assertEqual(gen.fold(" مصر "), "مصر")


class AssignedCodesTest(unittest.TestCase):
    def test_keeps_only_assigned_codes(self):
        self.assertEqual(gen.assigned_codes(CODE_MAPPINGS), {"MX", "GB", "MV"})

    def test_drops_deprecated_codes(self):
        mappings = {**CODE_MAPPINGS, "YU": {"_numeric": "891", "_alpha3": "YUG"}}
        self.assertEqual(
            gen.assigned_codes(mappings, deprecated={"YU"}), {"MX", "GB", "MV"}
        )
        self.assertNotIn("YUG", gen.alpha3_map(mappings, deprecated={"YU"}))

    def test_alpha3_map_covers_assigned_codes_only(self):
        self.assertEqual(
            gen.alpha3_map(CODE_MAPPINGS),
            {"MEX": "MX", "GBR": "GB", "MDV": "MV"},
        )


class NamesFromLocaleTest(unittest.TestCase):
    def test_skips_unassigned_and_numeric_keys(self):
        names = gen.names_from_locale(
            {"MX": "Mexico", "EU": "European Union", "001": "World"},
            {"MX", "GB"},
        )
        self.assertEqual(names, [("Mexico", "MX")])

    def test_includes_alt_short_and_alt_variant(self):
        names = gen.names_from_locale(
            {
                "GB": "United Kingdom",
                "GB-alt-short": "UK",
                "MX-alt-variant": "Mexique",
            },
            {"MX", "GB"},
        )
        self.assertIn(("UK", "GB"), names)
        self.assertIn(("Mexique", "MX"), names)

    def test_only_limits_to_named_codes(self):
        names = gen.names_from_locale(
            {"MX": "Mexico", "GB": "United Kingdom"}, {"MX", "GB"}, only={"GB"}
        )
        self.assertEqual(names, [("United Kingdom", "GB")])


class BuildTableTest(unittest.TestCase):
    def test_drops_names_mapping_to_two_codes(self):
        table = gen.build_table([("x", "AA"), ("X", "BB"), ("Mexico", "MX")])
        self.assertNotIn("x", table)
        self.assertEqual(table["mexico"], "MX")

    def test_same_name_same_code_twice_is_kept(self):
        table = gen.build_table([("Mexico", "MX"), ("MEXICO", "MX")])
        self.assertEqual(table, {"mexico": "MX"})

    def test_drops_denied_names(self):
        table = gen.build_table(
            [("Congo", "CG"), ("Mexico", "MX")], denied={"congo"}
        )
        self.assertEqual(table, {"mexico": "MX"})

    def test_ignores_blank_names(self):
        self.assertEqual(gen.build_table([("  ", "MX")]), {})


class OfficialLanguagesTest(unittest.TestCase):
    def test_adds_official_language_names(self):
        info = {
            "MV": {
                "_population": "1",
                "languagePopulation": {
                    "dv": {"_officialStatus": "official"},
                    "en": {"_populationPercent": "10"},
                },
            },
            "ES": {
                "languagePopulation": {
                    "ca": {"_officialStatus": "official_regional"},
                    "es": {"_officialStatus": "official"},
                    "fr": {"_officialStatus": "de_facto_official"},
                },
            },
        }
        self.assertEqual(
            gen.official_languages(info),
            {"dv": {"MV"}, "ca": {"ES"}, "es": {"ES"}, "fr": {"ES"}},
        )

    def test_official_name_only_for_its_own_territory(self):
        dv_territories = {"MV": "ދިވެހިރާއްޖެ", "MX": "Dhivehi Mexico"}
        names = gen.names_from_locale(dv_territories, {"MV", "MX"}, only={"MV"})
        self.assertEqual(names, [("ދިވެހިރާއްޖެ", "MV")])


class RenderDartTest(unittest.TestCase):
    def test_renders_sorted_maps_and_header(self):
        source = gen.render_dart(
            {"mexico": "MX", "deutschland": "DE"},
            {"MEX": "MX", "DEU": "DE"},
            {"MX", "DE"},
            "48.0.0",
        )
        self.assertIn("Generated by scripts/geography/generate_country_names.py", source)
        self.assertIn("CLDR 48.0.0", source)
        self.assertLess(source.index("'deutschland'"), source.index("'mexico'"))
        self.assertIn("const Map<String, String> cldrCountryNameCodes", source)
        self.assertIn("const Map<String, String> alpha3ToAlpha2", source)
        self.assertIn("const Set<String> assignedAlpha2Codes", source)
        self.assertNotIn("—", source)

    def test_escapes_quotes_and_backslashes(self):
        source = gen.render_dart({"cote d'ivoire": "CI"}, {}, {"CI"}, "1")
        self.assertIn("'cote d\\'ivoire': 'CI'", source)


if __name__ == "__main__":
    unittest.main()
