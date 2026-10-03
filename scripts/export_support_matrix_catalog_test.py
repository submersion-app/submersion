#!/usr/bin/env python3
"""Unit tests for export_support_matrix_catalog.py."""

import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
from unittest import mock

_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "export_support_matrix_catalog",
    os.path.join(_HERE, "export_support_matrix_catalog.py"),
)
gen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gen)

RULES = {
    "ios": ["ble"],
    "android": ["ble", "serial"],
    "macos": ["ble", "serial", "usbhid"],
    "windows": ["ble", "serial", "usbhid"],
    "linux": ["ble", "serial", "usbhid"],
    "idOverrides": {"Subgear|XP Air": "subgear-xp-air-irda"},
}

# Entries copied from descriptor.c, formatting quirks included.
TERIC = '{"Shearwater", "Teric",     DC_FAMILY_SHEARWATER_PETREL, 8, DC_TRANSPORT_BLE, dc_filter_shearwater},'
PETREL = '{"Shearwater", "Petrel",    DC_FAMILY_SHEARWATER_PETREL, 3, DC_TRANSPORT_SERIAL | DC_TRANSPORT_BLUETOOTH, dc_filter_shearwater},'
MCLEAN = '{ "McLean", "Extreme", DC_FAMILY_MCLEAN_EXTREME, 0, DC_TRANSPORT_SERIAL | DC_TRANSPORT_BLUETOOTH | DC_TRANSPORT_BLE, dc_filter_mclean},'
VYTEC = '{"Suunto", "Vytec",    DC_FAMILY_SUUNTO_VYPER, 0X0B, DC_TRANSPORT_SERIAL, NULL},'
G2 = '{"Scubapro", "G2",                  DC_FAMILY_UWATEC_SMART, 0x32, DC_TRANSPORT_USBHID | DC_TRANSPORT_BLE, dc_filter_uwatec},'
ALADIN_SQUARE = '{"Scubapro", "Aladin Square",       DC_FAMILY_UWATEC_SMART, 0x22, DC_TRANSPORT_USBHID, dc_filter_uwatec},'
ALADIN_2G_A = '{"Uwatec",   "Aladin 2G",           DC_FAMILY_UWATEC_SMART, 0x13, DC_TRANSPORT_IRDA, dc_filter_uwatec},'
ALADIN_2G_B = '{"Uwatec",   "Aladin 2G",           DC_FAMILY_UWATEC_SMART, 0x15, DC_TRANSPORT_IRDA, dc_filter_uwatec},'
COBALT = '{"Atomic Aquatics", "Cobalt",   DC_FAMILY_ATOMICS_COBALT, 0, DC_TRANSPORT_USB, dc_filter_atomic},'
OC1_A = '{"Oceanic",  "OC1",                 DC_FAMILY_OCEANIC_ATOM2, 0x434E, DC_TRANSPORT_SERIAL, NULL},'
OC1_B = '{"Oceanic",  "OC1",                 DC_FAMILY_OCEANIC_ATOM2, 0x4449, DC_TRANSPORT_SERIAL, NULL},'
OC1_C = '{"Oceanic",  "OC1",                 DC_FAMILY_OCEANIC_ATOM2, 0x4451, DC_TRANSPORT_SERIAL, NULL},'
PUCK_PRO = '{"Mares", "Puck Pro",          DC_FAMILY_MARES_ICONHD , 0x18, DC_TRANSPORT_SERIAL | DC_TRANSPORT_BLE, dc_filter_mares},'
PUCK_PRO_PLUS = '{"Mares", "Puck Pro +",        DC_FAMILY_MARES_ICONHD , 0x18, DC_TRANSPORT_SERIAL | DC_TRANSPORT_BLE, dc_filter_mares},'
XP_AIR_IRDA = '{"Subgear",  "XP Air",              DC_FAMILY_UWATEC_SMART, 0x1C, DC_TRANSPORT_IRDA, dc_filter_uwatec},'
XP_AIR_SERIAL = '{"Subgear",  "XP-Air",              DC_FAMILY_OCEANIC_ATOM2, 0x4555, DC_TRANSPORT_SERIAL, NULL},'
# Synthetic: one product listed twice with different transports.
DUAL_A = '{"Example", "Dual", DC_FAMILY_EXAMPLE, 1, DC_TRANSPORT_SERIAL, NULL},'
DUAL_B = '{"Example", "Dual", DC_FAMILY_EXAMPLE, 2, DC_TRANSPORT_BLE, NULL},'


def table(*lines):
    return (
        "static const dc_descriptor_t g_descriptors[] = {\n"
        + "\n".join("\t" + line for line in lines)
        + "\n};\n"
    )


def build(*lines, rules=RULES, previous_ids=()):
    return gen.build_catalog(gen.parse_descriptors(table(*lines)), rules, previous_ids)


def model(catalog, model_id):
    return next(m for m in catalog["models"] if m["id"] == model_id)


class ParseTest(unittest.TestCase):
    def test_reads_vendor_product_and_transports(self):
        self.assertEqual(
            gen.parse_descriptors(table(TERIC, PETREL)),
            [
                ("Shearwater", "Teric", {"ble"}),
                ("Shearwater", "Petrel", {"serial", "bluetooth"}),
            ],
        )

    def test_tolerates_the_tables_formatting(self):
        parsed = gen.parse_descriptors(table(MCLEAN, VYTEC))
        self.assertEqual(
            [(v, p) for v, p, _ in parsed], [("McLean", "Extreme"), ("Suunto", "Vytec")]
        )

    def test_skips_commented_out_entries(self):
        parsed = gen.parse_descriptors(table("/* " + TERIC + " */", "// " + G2, VYTEC))
        self.assertEqual([p for _, p, _ in parsed], ["Vytec"])

    def test_unknown_flag_is_an_error(self):
        line = TERIC.replace("DC_TRANSPORT_BLE", "DC_TRANSPORT_WIFI")
        with self.assertRaises(gen.CatalogError):
            gen.parse_descriptors(table(line))

    def test_missing_table_is_an_error(self):
        with self.assertRaises(gen.CatalogError):
            gen.parse_descriptors("int main(void) { return 0; }")

    def test_an_entry_the_parser_cannot_read_is_an_error(self):
        # An expression in the model field: findall would skip this entry and
        # silently drop the model from the matrix.
        odd = '{"Shearwater", "Tern 2", DC_FAMILY_SHEARWATER_PETREL, 0x10 | 0x01, DC_TRANSPORT_BLE, dc_filter_shearwater},'
        with self.assertRaises(gen.CatalogError) as raised:
            gen.parse_descriptors(table(TERIC, odd))
        self.assertIn("Tern 2", str(raised.exception))

    def test_a_brace_inside_a_product_name_parses(self):
        quad = '{"Mares", "Quad {Air}", DC_FAMILY_MARES_ICONHD, 0x23, DC_TRANSPORT_BLE, dc_filter_mares},'
        parsed = gen.parse_descriptors(table(TERIC, quad))
        self.assertEqual([p for _, p, _ in parsed], ["Teric", "Quad {Air}"])

    def test_the_error_quotes_an_unreadable_last_row_whole(self):
        odd = '{"Shearwater", "Tern 2", DC_FAMILY_SHEARWATER_PETREL, 0x10 | 0x01, DC_TRANSPORT_BLE, dc_filter_shearwater},'
        with self.assertRaises(gen.CatalogError) as raised:
            gen.parse_descriptors(table(TERIC, odd))
        self.assertTrue(str(raised.exception).endswith("dc_filter_shearwater},"), str(raised.exception))

    def test_a_row_not_led_by_a_string_literal_is_an_error(self):
        for odd in (
            '{VENDOR_SHEARWATER, "Tern 2", DC_FAMILY_SHEARWATER_PETREL, 15, DC_TRANSPORT_BLE, dc_filter_shearwater},',
            '{.vendor = "Shearwater", .product = "Tern 2"},',
        ):
            with self.assertRaises(gen.CatalogError) as raised:
                gen.parse_descriptors(table(TERIC, odd))
            self.assertIn("Tern 2", str(raised.exception))


class SlugTest(unittest.TestCase):
    def test_slugs(self):
        self.assertEqual(gen.slugify("Mares", "Puck Pro +"), "mares-puck-pro-plus")
        self.assertEqual(gen.slugify("Heinrichs Weikamp", "OSTC 2N"), "heinrichs-weikamp-ostc-2n")
        self.assertEqual(gen.slugify("Subgear", "XP-Air"), "subgear-xp-air")


class BuildTest(unittest.TestCase):
    def test_ble_only_model_is_bluetooth_everywhere(self):
        teric = model(build(TERIC), "shearwater-teric")
        self.assertEqual(teric["platforms"], {p: ["bluetooth"] for p in gen.PLATFORMS})

    def test_hid_and_ble_is_bluetooth_on_mobile_and_both_on_desktop(self):
        g2 = model(build(G2), "scubapro-g2")
        self.assertEqual(g2["platforms"]["ios"], ["bluetooth"])
        self.assertEqual(g2["platforms"]["android"], ["bluetooth"])
        for platform in ("macos", "windows", "linux"):
            self.assertEqual(g2["platforms"][platform], ["bluetooth", "usb"])

    def test_hid_only_is_na_on_mobile(self):
        square = model(build(ALADIN_SQUARE), "scubapro-aladin-square")
        self.assertEqual(square["platforms"]["ios"], [])
        self.assertEqual(square["platforms"]["android"], [])
        self.assertEqual(square["platforms"]["macos"], ["usb"])

    def test_classic_and_serial_gets_no_bluetooth(self):
        petrel = model(build(PETREL), "shearwater-petrel")
        self.assertEqual(petrel["platforms"]["ios"], [])
        self.assertEqual(petrel["platforms"]["android"], ["usb"])
        self.assertEqual(petrel["platforms"]["macos"], ["usb"])

    def test_irda_only_is_unsupported(self):
        catalog = build(ALADIN_2G_A, TERIC)
        self.assertEqual([m["id"] for m in catalog["models"]], ["shearwater-teric"])
        self.assertEqual(
            catalog["unsupported"],
            [{"id": "uwatec-aladin-2g", "vendor": "Uwatec", "product": "Aladin 2G", "reason": "irda-only"}],
        )

    def test_raw_usb_only_is_unsupported(self):
        catalog = build(COBALT)
        self.assertEqual(catalog["models"], [])
        self.assertEqual(catalog["unsupported"][0]["reason"], "raw-usb-only")

    def test_identical_pairs_merge(self):
        catalog = build(OC1_A, OC1_B, OC1_C, ALADIN_2G_A, ALADIN_2G_B)
        self.assertEqual([m["id"] for m in catalog["models"]], ["oceanic-oc1"])
        self.assertEqual(len(catalog["unsupported"]), 1)

    def test_merged_pairs_take_the_union_of_transports(self):
        dual = model(build(DUAL_A, DUAL_B), "example-dual")
        self.assertEqual(dual["libdc"], ["ble", "serial"])
        self.assertEqual(dual["platforms"]["android"], ["bluetooth", "usb"])

    def test_punctuation_variants_get_distinct_ids(self):
        ids = [m["id"] for m in build(PUCK_PRO, PUCK_PRO_PLUS)["models"]]
        self.assertEqual(ids, ["mares-puck-pro", "mares-puck-pro-plus"])

    def test_id_override_resolves_a_collision(self):
        catalog = build(XP_AIR_IRDA, XP_AIR_SERIAL)
        self.assertEqual([m["id"] for m in catalog["models"]], ["subgear-xp-air"])
        self.assertEqual(catalog["unsupported"][0]["id"], "subgear-xp-air-irda")

    def test_unresolved_collision_is_an_error_naming_both(self):
        rules = dict(RULES, idOverrides={})
        with self.assertRaises(gen.CatalogError) as raised:
            build(XP_AIR_IRDA, XP_AIR_SERIAL, rules=rules)
        self.assertIn("Subgear XP Air", str(raised.exception))
        self.assertIn("Subgear XP-Air", str(raised.exception))

    def test_removed_lists_ids_no_longer_present(self):
        catalog = build(TERIC, ALADIN_2G_A, previous_ids=["shearwater-teric", "uwatec-aladin-2g", "gone-model"])
        self.assertEqual(catalog["removed"], ["gone-model"])

    def test_models_sorted_by_vendor_then_product(self):
        ids = [m["id"] for m in build(TERIC, G2, PETREL)["models"]]
        self.assertEqual(ids, ["scubapro-g2", "shearwater-petrel", "shearwater-teric"])

    def test_libdc_lists_raw_transports_in_fixed_order(self):
        self.assertEqual(model(build(MCLEAN), "mclean-extreme")["libdc"], ["ble", "bluetooth", "serial"])


class RulesTest(unittest.TestCase):
    def test_rejects_a_missing_platform(self):
        rules = {k: v for k, v in RULES.items() if k != "linux"}
        with self.assertRaises(gen.CatalogError):
            gen.load_rules(json.dumps(rules))

    def test_rejects_an_unknown_transport(self):
        rules = dict(RULES, ios=["ble", "wifi"])
        with self.assertRaises(gen.CatalogError):
            gen.load_rules(json.dumps(rules))

    def test_rejects_a_rules_file_that_is_not_an_object(self):
        for text in ('["ble"]', '"ios"', "3"):
            with self.assertRaises(gen.CatalogError):
                gen.load_rules(text)

    def test_rejects_an_override_that_is_not_an_id(self):
        rules = dict(RULES, idOverrides={"Mares|Puck Pro +": "Mares Puck Pro Plus"})
        with self.assertRaises(gen.CatalogError):
            gen.load_rules(json.dumps(rules))

    def test_the_committed_rules_file_is_the_spec(self):
        with open(gen.DEFAULT_RULES, encoding="utf-8") as handle:
            self.assertEqual(gen.load_rules(handle.read()), RULES)


class MainTest(unittest.TestCase):
    def run_main(self, *lines, extra=(), dirty=False):
        with tempfile.TemporaryDirectory() as tmp:
            descriptor = os.path.join(tmp, "descriptor.c")
            with open(descriptor, "w", encoding="utf-8") as handle:
                handle.write(table(*lines))
            out = os.path.join(tmp, "catalog.json")
            argv = ["--descriptor", descriptor, "--out", out, "--min-descriptors", "1"]
            argv += list(extra)
            stderr = io.StringIO()
            with mock.patch.object(gen, "git_head", return_value="a" * 40), mock.patch.object(
                gen, "git_dirty", return_value=dirty
            ), contextlib.redirect_stderr(stderr), contextlib.redirect_stdout(io.StringIO()):
                code = gen.main(argv)
            written = None
            if os.path.exists(out):
                with open(out, encoding="utf-8") as handle:
                    written = json.load(handle)
            return code, written, stderr.getvalue(), tmp

    def test_writes_a_catalog_with_provenance(self):
        code, catalog, _, _ = self.run_main(TERIC, ALADIN_2G_A)
        self.assertEqual(code, 0)
        self.assertEqual(list(catalog), ["generatedFrom", "models", "unsupported", "removed"])
        self.assertEqual(catalog["generatedFrom"]["appCommit"], "a" * 40)
        self.assertEqual(catalog["generatedFrom"]["libdcCommit"], "a" * 40)
        self.assertRegex(catalog["generatedFrom"]["generatedAt"], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    def test_refuses_a_table_below_the_minimum(self):
        code, catalog, stderr, _ = self.run_main(TERIC, extra=["--min-descriptors", "5"])
        self.assertEqual(code, 1)
        self.assertIsNone(catalog)
        self.assertIn("only 1 descriptors", stderr)

    def test_previous_catalog_feeds_removed(self):
        with tempfile.TemporaryDirectory() as tmp:
            previous = os.path.join(tmp, "previous.json")
            with open(previous, "w", encoding="utf-8") as handle:
                json.dump({"models": [{"id": "gone-model"}], "unsupported": []}, handle)
            code, catalog, _, _ = self.run_main(TERIC, extra=["--previous", previous])
        self.assertEqual(code, 0)
        self.assertEqual(catalog["removed"], ["gone-model"])

    def test_a_collision_exits_non_zero_without_writing(self):
        with tempfile.TemporaryDirectory() as tmp:
            rules = os.path.join(tmp, "rules.json")
            with open(rules, "w", encoding="utf-8") as handle:
                json.dump(dict(RULES, idOverrides={}), handle)
            code, catalog, stderr, _ = self.run_main(XP_AIR_IRDA, XP_AIR_SERIAL, extra=["--rules", rules])
        self.assertEqual(code, 1)
        self.assertIsNone(catalog)
        self.assertIn("idOverrides", stderr)

    def test_a_malformed_previous_catalog_exits_non_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            previous = os.path.join(tmp, "previous.json")
            with open(previous, "w", encoding="utf-8") as handle:
                json.dump(["not", "a", "catalog"], handle)
            code, catalog, stderr, _ = self.run_main(TERIC, extra=["--previous", previous])
        self.assertEqual(code, 1)
        self.assertIsNone(catalog)
        self.assertIn("error:", stderr)

    def test_an_unwritable_out_exits_non_zero(self):
        with tempfile.TemporaryDirectory() as tmp:
            code, _, stderr, _ = self.run_main(TERIC, extra=["--out", tmp])
        self.assertEqual(code, 1)
        self.assertIn("error:", stderr)

    def test_a_failed_write_keeps_the_existing_catalog(self):
        with tempfile.TemporaryDirectory() as tmp:
            descriptor = os.path.join(tmp, "descriptor.c")
            with open(descriptor, "w", encoding="utf-8") as handle:
                handle.write(table(TERIC))
            out = os.path.join(tmp, "catalog.json")
            with open(out, "w", encoding="utf-8") as handle:
                handle.write('{"previous": true}\n')
            argv = ["--descriptor", descriptor, "--out", out, "--min-descriptors", "1"]
            with mock.patch.object(gen, "git_head", return_value="a" * 40), mock.patch.object(
                gen.json, "dump", side_effect=OSError("disk full")
            ), contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
                code = gen.main(argv)
            with open(out, encoding="utf-8") as handle:
                kept = handle.read()
            leftovers = sorted(os.listdir(tmp))
        self.assertEqual(code, 1)
        self.assertEqual(kept, '{"previous": true}\n')
        self.assertEqual(leftovers, ["catalog.json", "descriptor.c"])

    def test_uncommitted_generator_or_rules_changes_warn(self):
        code, catalog, stderr, _ = self.run_main(TERIC, dirty=True)
        self.assertEqual(code, 0)
        self.assertIsNotNone(catalog)
        self.assertIn("warning: the generator or its rules have uncommitted changes", stderr)

    def test_a_clean_checkout_does_not_warn(self):
        _, _, stderr, _ = self.run_main(TERIC)
        self.assertNotIn("uncommitted", stderr)

    def test_an_override_that_matches_nothing_warns(self):
        with tempfile.TemporaryDirectory() as tmp:
            rules = os.path.join(tmp, "rules.json")
            with open(rules, "w", encoding="utf-8") as handle:
                json.dump(dict(RULES, idOverrides={"Nobody|Nothing": "nobody-nothing"}), handle)
            code, _, stderr, _ = self.run_main(TERIC, extra=["--rules", rules])
        self.assertEqual(code, 0)
        self.assertIn("warning: idOverrides key Nobody|Nothing matches no descriptor", stderr)


if __name__ == "__main__":
    unittest.main()
