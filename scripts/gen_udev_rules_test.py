#!/usr/bin/env python3
"""Unit tests for gen_udev_rules.py.

Run: python3 scripts/gen_udev_rules_test.py

The regression this guards: libdivecomputer's descriptor tables are C source,
not a data file, so a submodule bump that reshapes them would make a naive
parser emit an empty rules file. An empty file installs cleanly and silently
leaves every USB dive computer unreachable, which is exactly the class of
failure check_bundled_native_assets.py exists to prevent for native libraries.
"""

import importlib.util
import os
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_udev_rules.py")
spec = importlib.util.spec_from_file_location("gen_udev_rules", SCRIPT)
gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen)

SAMPLE = """
dc_filter_uwatec (const dc_descriptor_t *descriptor)
{
\tstatic const dc_usbhid_desc_t usbhid[] = {
\t\t{0x2e6c, 0x3201}, // G2, G2 TEK
\t\t{0xc251, 0x2006}, // Aladin Square
\t};
}

dc_filter_atomic (const dc_descriptor_t *descriptor)
{
\tstatic const dc_usb_desc_t usb[] = {
\t\t{0x0471, 0x0888}, // Atomic Aquatics Cobalt
\t};
}
"""


class ParseDevicesTest(unittest.TestCase):
    def test_extracts_usbhid_devices_with_comments(self):
        devices = gen.parse_devices(SAMPLE)
        self.assertIn(gen.Device("2e6c", "3201", "G2, G2 TEK", True), devices)
        self.assertIn(gen.Device("c251", "2006", "Aladin Square", True), devices)

    def test_extracts_plain_usb_devices(self):
        devices = gen.parse_devices(SAMPLE)
        self.assertIn(
            gen.Device("0471", "0888", "Atomic Aquatics Cobalt", False), devices
        )

    def test_finds_every_device_in_the_sample(self):
        self.assertEqual(len(gen.parse_devices(SAMPLE)), 3)

    def test_empty_source_raises_rather_than_emitting_nothing(self):
        with self.assertRaises(SystemExit):
            gen.parse_devices("int main(void) { return 0; }")


class RenderTest(unittest.TestCase):
    def test_hidraw_device_gets_hidraw_and_usb_rules(self):
        text = gen.render([gen.Device("2e6c", "3201", "G2, G2 TEK", True)])
        self.assertIn(
            'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="2e6c", '
            'ATTRS{idProduct}=="3201", TAG+="uaccess"',
            text,
        )
        self.assertIn(
            'SUBSYSTEM=="usb", ATTR{idVendor}=="2e6c", '
            'ATTR{idProduct}=="3201", TAG+="uaccess"',
            text,
        )

    def test_plain_usb_device_gets_no_hidraw_rule(self):
        text = gen.render([gen.Device("0471", "0888", "Cobalt", False)])
        self.assertNotIn("hidraw", text)

    def test_never_uses_group_based_access(self):
        text = gen.render([gen.Device("2e6c", "3201", "G2", True)])
        self.assertNotIn("plugdev", text)
        self.assertNotIn("dialout", text)

    def test_includes_serial_bridge_rules(self):
        text = gen.render([gen.Device("2e6c", "3201", "G2", True)])
        # FTDI, Prolific, and Silicon Labs bridges are how the serial dive
        # computers reach /dev/ttyUSB*.
        for vid in ("0403", "067b", "10c4"):
            self.assertIn(
                'SUBSYSTEM=="tty", ATTRS{idVendor}=="%s", TAG+="uaccess"' % vid,
                text,
            )

    def test_device_comment_is_preserved(self):
        text = gen.render([gen.Device("2e6c", "3201", "G2, G2 TEK", True)])
        self.assertIn("# G2, G2 TEK", text)


if __name__ == "__main__":
    unittest.main()
