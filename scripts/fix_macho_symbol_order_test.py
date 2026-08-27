#!/usr/bin/env python3
"""Unit tests for fix_macho_symbol_order.py.

Run: python3 scripts/fix_macho_symbol_order_test.py

These build synthetic Mach-O objects in memory rather than shelling out to a
linker, so the suite runs identically on Linux CI and macOS without Xcode. The
central case is the issue #996 regression: the four ``kDart*`` snapshot symbols
emitted by gen_snapshot in address order, which macOS 11's dyld cannot find by
binary search.
"""

import importlib.util
import io
import os
import struct
import sys
import contextlib
import unittest

# Load the sibling script by path so the test runs from any working directory.
_HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "fix_macho_symbol_order",
    os.path.join(_HERE, "fix_macho_symbol_order.py"),
)
tool = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tool)

# The order gen_snapshot emits (by address): instructions first, then data.
GEN_SNAPSHOT_ORDER = [
    "_kDartVmSnapshotInstructions",
    "_kDartIsolateSnapshotInstructions",
    "_kDartVmSnapshotData",
    "_kDartIsolateSnapshotData",
]

# The order ld64 emits, and the order dyld's binary search requires.
SORTED_ORDER = sorted(GEN_SNAPSHOT_ORDER)


def _string_table(names):
    """Return ``(blob, {name: n_strx})``. Offset 0 is the customary empty name.

    Accepts ``str`` or raw ``bytes`` names, so tests can build string tables
    that are not valid UTF-8.
    """
    blob = bytearray(b"\x00")
    offsets = {}
    for name in names:
        offsets[name] = len(blob)
        blob += (name.encode() if isinstance(name, str) else name) + b"\x00"
    return bytes(blob), offsets


def _thin(names=None, dysymtab=None, extra_commands=b"", n_values=None):
    """Build a minimal 64-bit Mach-O dylib exporting ``names``.

    ``dysymtab`` overrides fields of the LC_DYSYMTAB command; by default it
    describes the shape gen_snapshot produces (all external defined symbols,
    no locals, no undefined, no auxiliary tables).
    """
    names = list(GEN_SNAPSHOT_ORDER if names is None else names)
    strtab, offsets = _string_table(names)

    # Distinct n_value/n_sect/n_desc per symbol so tests can prove that every
    # field of an nlist entry travels with its name when entries are permuted.
    values = n_values if n_values is not None else [0x1000 * (i + 1) for i in range(len(names))]
    symtab = b"".join(
        struct.pack("<IBBHQ", offsets[name], 0x0F, i + 1, i + 100, values[i])
        for i, name in enumerate(names)
    )

    ncmds_extra = 0
    if extra_commands:
        # Caller-supplied commands are pre-packed; count them by walking cmdsize.
        pos = 0
        while pos < len(extra_commands):
            (_, cmdsize) = struct.unpack_from("<II", extra_commands, pos)
            pos += cmdsize
            ncmds_extra += 1

    header_size = 32
    symtab_cmd_size = 24
    dysymtab_cmd_size = 80
    cmds_size = symtab_cmd_size + dysymtab_cmd_size + len(extra_commands)

    symoff = header_size + cmds_size
    stroff = symoff + len(symtab)

    fields = {
        "ilocalsym": 0, "nlocalsym": 0,
        "iextdefsym": 0, "nextdefsym": len(names),
        "iundefsym": len(names), "nundefsym": 0,
        "tocoff": 0, "ntoc": 0,
        "modtaboff": 0, "nmodtab": 0,
        "extrefsymoff": 0, "nextrefsyms": 0,
        "indirectsymoff": 0, "nindirectsyms": 0,
        "extreloff": 0, "nextrel": 0,
        "locreloff": 0, "nlocrel": 0,
    }
    fields.update(dysymtab or {})

    out = bytearray()
    out += struct.pack(
        "<IiiIIIII",
        tool.MH_MAGIC_64,
        0x01000007,  # CPU_TYPE_X86_64
        0x00000003,  # CPU_SUBTYPE_X86_64_ALL
        0x6,  # MH_DYLIB
        2 + ncmds_extra,
        cmds_size,
        0x100085,
        0,
    )
    out += struct.pack(
        "<IIIIII", tool.LC_SYMTAB, symtab_cmd_size,
        symoff, len(names), stroff, len(strtab),
    )
    out += struct.pack("<II", tool.LC_DYSYMTAB, dysymtab_cmd_size)
    out += struct.pack(
        "<18I",
        fields["ilocalsym"], fields["nlocalsym"],
        fields["iextdefsym"], fields["nextdefsym"],
        fields["iundefsym"], fields["nundefsym"],
        fields["tocoff"], fields["ntoc"],
        fields["modtaboff"], fields["nmodtab"],
        fields["extrefsymoff"], fields["nextrefsyms"],
        fields["indirectsymoff"], fields["nindirectsyms"],
        fields["extreloff"], fields["nextrel"],
        fields["locreloff"], fields["nlocrel"],
    )
    out += extra_commands
    out += symtab
    out += strtab
    return bytes(out)


def _fat(slices):
    """Wrap thin Mach-O images in a fat container, 4 KB-aligned like ld64."""
    header = struct.pack(">II", tool.FAT_MAGIC, len(slices))
    arch_size = 20
    offset = len(header) + arch_size * len(slices)
    archs = b""
    body = b""
    for i, image in enumerate(slices):
        offset = (offset + 0xFFF) & ~0xFFF
        pad = offset - (len(header) + arch_size * len(slices) + len(body))
        body += b"\x00" * pad + image
        archs += struct.pack(">iiIII", 0x01000007 + i, 3, offset, len(image), 12)
        offset += len(image)
    return header + archs + body


def _names_in_order(data, base=0):
    """Read back the symbol-table names of ``data`` in file order, as text."""
    return [
        name.decode("utf-8", "surrogateescape")
        for name, _ in tool.read_external_symbols(bytearray(data), base)
    ]


def _raw_names_in_order(data, base=0):
    """Read back the symbol-table names of ``data`` in file order, as bytes."""
    return [name for name, _ in tool.read_external_symbols(bytearray(data), base)]


class SortTests(unittest.TestCase):
    def test_sorts_gen_snapshot_order(self):
        data = bytearray(_thin())
        self.assertEqual(_names_in_order(data), GEN_SNAPSHOT_ORDER)
        self.assertTrue(tool.sort_slice(data, 0))
        self.assertEqual(_names_in_order(data), SORTED_ORDER)

    def test_preserves_length_and_string_table(self):
        original = _thin()
        data = bytearray(original)
        tool.sort_slice(data, 0)
        self.assertEqual(len(data), len(original))
        # Everything after the symbol table (the string blob) is untouched.
        symoff, nsyms, _, _ = tool.symtab_fields(bytearray(original), 0)
        tail = symoff + nsyms * tool.NLIST_SIZE
        self.assertEqual(bytes(data[tail:]), original[tail:])

    def test_nlist_fields_travel_with_their_name(self):
        data = bytearray(_thin())
        before = dict(tool.read_external_symbols(data, 0))
        tool.sort_slice(data, 0)
        after = dict(tool.read_external_symbols(data, 0))
        self.assertEqual(before, after)

    def test_sorts_names_that_are_not_valid_utf8(self):
        """Names are compared as bytes, the way dyld's strcmp compares them.

        A Mach-O string table carries no encoding guarantee. Decoding to text
        would raise on these names, and surrogate escapes would sort them above
        every real character -- producing an order the loader disagrees with.
        """
        names = [b"_\xff_last", b"_\x80_first", b"_ascii"]
        data = bytearray(_thin(names=names))
        self.assertTrue(tool.sort_slice(data, 0))
        self.assertEqual(_raw_names_in_order(data), sorted(names))

    def test_is_idempotent(self):
        data = bytearray(_thin())
        self.assertTrue(tool.sort_slice(data, 0))
        self.assertFalse(tool.sort_slice(data, 0))
        self.assertEqual(_names_in_order(data), SORTED_ORDER)

    def test_already_sorted_is_untouched(self):
        original = _thin(names=SORTED_ORDER)
        data = bytearray(original)
        self.assertFalse(tool.sort_slice(data, 0))
        self.assertEqual(bytes(data), original)

    def test_fat_binary_sorts_every_slice(self):
        data = bytearray(_fat([_thin(), _thin()]))
        self.assertEqual(tool.sort_image(data), 2)
        for base, _ in tool.slice_ranges(data):
            self.assertEqual(_names_in_order(data, base), SORTED_ORDER)

    def test_sort_image_counts_only_modified_slices(self):
        data = bytearray(_fat([_thin(), _thin(names=SORTED_ORDER)]))
        self.assertEqual(tool.sort_image(data), 1)


class GuardTests(unittest.TestCase):
    """Anything outside the shape gen_snapshot emits must fail closed.

    Reordering nlist entries is only safe because nothing else in the file
    refers to a symbol by index. Each table below would carry such a reference.
    """

    def _assert_rejects(self, **dysymtab):
        data = bytearray(_thin(dysymtab=dysymtab))
        with self.assertRaises(tool.MachOError):
            tool.sort_slice(data, 0)

    def test_rejects_local_symbols(self):
        self._assert_rejects(nlocalsym=1, iextdefsym=1, iundefsym=5)

    def test_rejects_undefined_symbols(self):
        self._assert_rejects(nundefsym=1)

    def test_rejects_indirect_symbol_table(self):
        self._assert_rejects(indirectsymoff=64, nindirectsyms=2)

    def test_rejects_table_of_contents(self):
        self._assert_rejects(tocoff=64, ntoc=2)

    def test_rejects_module_table(self):
        self._assert_rejects(modtaboff=64, nmodtab=1)

    def test_rejects_external_reference_table(self):
        self._assert_rejects(extrefsymoff=64, nextrefsyms=1)

    def test_rejects_external_relocations(self):
        self._assert_rejects(extreloff=64, nextrel=1)

    def test_rejects_local_relocations(self):
        self._assert_rejects(locreloff=64, nlocrel=1)

    def test_rejects_non_macho(self):
        with self.assertRaises(tool.MachOError):
            tool.sort_image(bytearray(b"\x7fELF" + b"\x00" * 60))

    def test_rejects_truncated_symbol_table(self):
        data = bytearray(_thin())
        with self.assertRaises(tool.MachOError):
            tool.sort_slice(data[: len(data) - 8], 0)


class LinkerProducedTests(unittest.TestCase):
    """A linker-produced image has an exports trie and is left alone.

    dyld resolves through the trie there, and ld64 already sorts the table. If
    Dart's writer starts emitting a trie (or Flutter reverts to clang linking),
    this step must quietly stop acting rather than start failing builds.
    """

    def _with_command(self, cmd):
        return bytearray(_thin(extra_commands=struct.pack("<IIII", cmd, 16, 0, 0)))

    def test_skips_dyld_info_only(self):
        data = self._with_command(tool.LC_DYLD_INFO_ONLY)
        self.assertFalse(tool.sort_slice(data, 0))
        self.assertEqual(_names_in_order(data), GEN_SNAPSHOT_ORDER)

    def test_skips_dyld_exports_trie(self):
        data = self._with_command(tool.LC_DYLD_EXPORTS_TRIE)
        self.assertFalse(tool.sort_slice(data, 0))


class DyldLookupTests(unittest.TestCase):
    """Reproduce the failure this script exists to prevent.

    ``dyld_classic_dlsym`` mirrors dyld's pre-dyld4 binary search over the
    external-defined range. Against gen_snapshot's order it finds the VM data
    symbol but not the isolate one -- exactly the single error line reported in
    issue #996, and the reason the app segfaults on macOS 11.
    """

    def test_gen_snapshot_order_hides_the_isolate_snapshot(self):
        found = {
            name: tool.dyld_classic_dlsym(GEN_SNAPSHOT_ORDER, name) is not None
            for name in GEN_SNAPSHOT_ORDER
        }
        self.assertTrue(found["_kDartVmSnapshotData"])
        self.assertFalse(found["_kDartIsolateSnapshotData"])

    def test_sorted_order_finds_every_symbol(self):
        for name in SORTED_ORDER:
            self.assertIsNotNone(tool.dyld_classic_dlsym(SORTED_ORDER, name))

    def test_sorted_file_is_resolvable(self):
        data = bytearray(_thin())
        tool.sort_slice(data, 0)
        names = _names_in_order(data)
        for name in GEN_SNAPSHOT_ORDER:
            self.assertIsNotNone(tool.dyld_classic_dlsym(names, name))


class MainTests(unittest.TestCase):
    def setUp(self):
        self.tmp = os.path.join(
            os.environ.get("TMPDIR", "/tmp"), f"macho_order_{os.getpid()}.bin"
        )
        self.addCleanup(lambda: os.path.exists(self.tmp) and os.remove(self.tmp))

    def _write(self, data):
        with open(self.tmp, "wb") as fh:
            fh.write(data)

    def _run(self, argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = tool.main(argv)
        return code, out.getvalue()

    def test_rewrites_file_in_place(self):
        self._write(_thin())
        code, output = self._run(["fix_macho_symbol_order.py", self.tmp])
        self.assertEqual(code, 0)
        self.assertIn("sorted", output)
        with open(self.tmp, "rb") as fh:
            self.assertEqual(_names_in_order(fh.read()), SORTED_ORDER)

    def test_check_mode_fails_on_unsorted_and_does_not_write(self):
        original = _thin()
        self._write(original)
        code, output = self._run(["fix_macho_symbol_order.py", "--check", self.tmp])
        self.assertEqual(code, 1)
        self.assertIn("996", output)
        with open(self.tmp, "rb") as fh:
            self.assertEqual(fh.read(), original)

    def test_check_mode_passes_on_sorted(self):
        self._write(_thin(names=SORTED_ORDER))
        code, _ = self._run(["fix_macho_symbol_order.py", "--check", self.tmp])
        self.assertEqual(code, 0)

    def test_unparseable_file_fails_closed(self):
        self._write(b"not a mach-o at all")
        code, output = self._run(["fix_macho_symbol_order.py", self.tmp])
        self.assertEqual(code, 1)
        self.assertIn("ERROR", output)

    def test_no_arguments_prints_usage(self):
        code, _ = self._run(["fix_macho_symbol_order.py"])
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
