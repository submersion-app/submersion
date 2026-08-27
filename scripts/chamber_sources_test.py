#!/usr/bin/env python3
"""Unit tests for chamber_sources.py.

Run: python3 scripts/chamber_sources_test.py

Parsers run against committed fixtures rather than the live pages, so the suite
is hermetic and a registry going offline does not turn the build red. The
asserted facilities were read out of those fixtures by hand.
"""

import importlib.util
import os
import unittest

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "chamber_sources",
    os.path.join(_HERE, "chamber_sources.py"),
)
chamber_sources = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(chamber_sources)

FIXTURES = os.path.join(_HERE, "fixtures", "chambers")
RETRIEVED = "2026-08-26"


def _fixture(name):
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as handle:
        return handle.read()


class NormalizePhoneTest(unittest.TestCase):
    def test_an_international_number_is_kept(self):
        self.assertEqual(
            chamber_sources.normalize_phone("+390817474102", "39"), "+390817474102"
        )

    def test_a_national_number_gains_its_country_code(self):
        self.assertEqual(
            chamber_sources.normalize_phone("01752 209999", "44"), "+441752209999"
        )

    def test_a_double_zero_prefix_becomes_a_plus(self):
        self.assertEqual(
            chamber_sources.normalize_phone("0039 081 7474102", "39"), "+390817474102"
        )

    def test_a_parenthesised_trunk_zero_is_dropped(self):
        self.assertEqual(
            chamber_sources.normalize_phone("+64-(0)9-487 2214", "64"), "+6494872214"
        )

    def test_only_the_first_number_on_a_line_is_taken(self):
        self.assertEqual(
            chamber_sources.normalize_phone(
                "Recapito telefonico: +390817474102 +390817474098", "39"
            ),
            "+390817474102",
        )


class ParseSimsiTest(unittest.TestCase):
    def setUp(self):
        self.rows = chamber_sources.parse_simsi(
            _fixture("simsi.html"),
            retrieved=RETRIEVED,
            source_url="https://simsi.it/centri-iperbarici-italiani/",
        )

    def test_extracts_a_substantial_number_of_italian_centres(self):
        self.assertGreaterEqual(len(self.rows), 40)
        self.assertTrue(all(r["country"] == "IT" for r in self.rows))

    def test_extracts_a_known_centre_with_its_phone(self):
        cardarelli = [r for r in self.rows if "Cardarelli" in r["name"]]
        self.assertEqual(len(cardarelli), 1)
        self.assertEqual(cardarelli[0]["phone"], "+390817474102")
        self.assertEqual(cardarelli[0]["city"], "Napoli")

    def test_an_explicit_urgenza_si_becomes_a_diving_emergency_chamber(self):
        cardarelli = [r for r in self.rows if "Cardarelli" in r["name"]][0]
        self.assertEqual(cardarelli["capability"], "diving_emergency")
        self.assertEqual(cardarelli["availability"], "h24")

    def test_an_explicit_urgenze_h24_no_is_not_read_as_an_emergency_chamber(self):
        # "Urgenze h24 no" appears on the same page as "Urgenza h24: SI".
        # Matching the bare string "h24" would invert this row's meaning. The
        # record in question is the Lecce unit, reachable on +39 0832 335499.
        lecce = [r for r in self.rows if r["phone"] == "+390832335499"]
        self.assertEqual(len(lecce), 1, "the Lecce record should be parsed")
        self.assertNotEqual(lecce[0]["capability"], "diving_emergency")
        self.assertEqual(lecce[0]["availability"], "business_hours")

    def test_italian_numbers_keep_their_trunk_zero(self):
        # +39 832 335499 does not connect; Italy keeps the leading zero.
        national = [r for r in self.rows if not r["phone"].startswith("+390")]
        self.assertEqual(
            [r["phone"] for r in national],
            [],
            "every Italian row should carry a dialable +39 0... number",
        )

    def test_no_row_carries_two_numbers_run_together(self):
        for row in self.rows:
            self.assertLessEqual(
                len(row["phone"].lstrip("+")),
                15,
                f"{row['name']} looks like two numbers concatenated",
            )

    def test_a_blank_flag_stays_unknown_rather_than_assumed(self):
        blanks = [r for r in self.rows if r["capability"] == "unknown"]
        self.assertTrue(blanks, "most SIMSI rows leave the h24 field empty")

    def test_every_row_is_marked_as_a_registry_lead(self):
        self.assertTrue(all(r["verified"]["via"] == "registry" for r in self.rows))


class ParseBhaTest(unittest.TestCase):
    def setUp(self):
        self.rows = chamber_sources.parse_bha(
            _fixture("bha.html"),
            retrieved=RETRIEVED,
            source_url="https://ukhyperbaric.com/members/",
        )

    def test_extracts_the_member_facilities(self):
        self.assertGreaterEqual(len(self.rows), 5)
        self.assertTrue(all(r["country"] == "GB" for r in self.rows))

    def test_extracts_ddrc_with_its_switchboard_and_emergency_line(self):
        ddrc = [r for r in self.rows if "DDRC" in r["name"]]
        self.assertEqual(len(ddrc), 1)
        self.assertEqual(ddrc[0]["city"], "Plymouth")
        self.assertEqual(ddrc[0]["phone"], "+441752209999")
        self.assertEqual(ddrc[0]["emergencyPhone"], "+447831151523")


class SpumsIsNotParsedTest(unittest.TestCase):
    def test_there_is_no_spums_parser(self):
        # SPUMS prose has no record delimiter, and a trial parser bound the
        # national Diver Emergency Service hotline to a named hospital unit.
        # Those twelve units are hand-curated in the overlay instead.
        self.assertFalse(hasattr(chamber_sources, "parse_spums"))


try:
    import pypdf

    HAVE_PYPDF = True
except ImportError:  # pragma: no cover - depends on the local environment
    HAVE_PYPDF = False


@unittest.skipUnless(HAVE_PYPDF, "pypdf is not installed")
class ParseFfessmTest(unittest.TestCase):
    def setUp(self):
        reader = pypdf.PdfReader(os.path.join(FIXTURES, "ffessm.pdf"))
        text = "\n".join(page.extract_text() or "" for page in reader.pages)
        self.rows = chamber_sources.parse_ffessm(
            text,
            retrieved=RETRIEVED,
            source_url="https://ffessm74.com/wp-content/uploads/2014/03/Liste_Caissons2.pdf",
        )

    def test_extracts_french_chambers(self):
        self.assertGreaterEqual(len(self.rows), 15)
        self.assertTrue(all(r["country"] == "FR" for r in self.rows))

    def test_extracts_le_havre_with_its_phone(self):
        havre = [r for r in self.rows if r["city"] == "Le Havre"]
        self.assertEqual(len(havre), 1)
        self.assertEqual(havre[0]["phone"], "+33235552530")

    def test_a_military_chamber_is_marked_on_call(self):
        military = [r for r in self.rows if r["availability"] == "on_call"]
        self.assertTrue(military, "the list tags several chambers militaires")


if __name__ == "__main__":
    unittest.main()
