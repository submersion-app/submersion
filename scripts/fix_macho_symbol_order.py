#!/usr/bin/env python3
"""Sort the external symbol table of gen_snapshot's App.framework binary.

Flutter 3.44 changed how the AOT snapshot library is produced on Apple
platforms: instead of gen_snapshot emitting assembly that clang links into a
dylib, gen_snapshot now writes the Mach-O itself
(``--snapshot_kind=app-aot-macho-dylib``). That hand-written image has no
exports trie, and its ``LC_DYSYMTAB`` external defined symbols are laid out in
address order rather than sorted by name:

    _kDartVmSnapshotInstructions
    _kDartIsolateSnapshotInstructions
    _kDartVmSnapshotData
    _kDartIsolateSnapshotData

Sorted-by-name is an invariant every ld64-produced dylib upholds, and dyld
before the dyld4 rewrite (macOS 12 and earlier) relies on it: with no exports
trie it falls back to the classic loader, whose ``dlsym`` *binary searches*
that range. Against the order above the search finds ``_kDartVmSnapshotData``
but not ``_kDartIsolateSnapshotData``, so the engine reports

    [ERROR:flutter/runtime/dart_vm_data.cc(31)] Isolate snapshot invalid and
    could not be inferred from settings.

and then segfaults dereferencing the VM it failed to create. That is issue
#996: Submersion v1.5.9 through v1.7.2 crash on launch on macOS 11 Big Sur,
while v1.5.6 (Flutter 3.41.4, clang-linked and therefore sorted) runs fine.
Upstream: https://github.com/flutter/flutter/issues/189183

This script permutes those nlist entries into sorted order. The rewrite is
safe because nothing else in the file refers to a symbol by index -- the image
has no locals, no undefined symbols, and no table of contents, module table,
external reference table, indirect symbol table or relocations. Every one of
those is asserted before a byte is written; an image of any other shape is
rejected rather than modified. Only the 16-byte nlist entries move, so file
size, segment offsets, the string table and ``LC_UUID`` are all untouched and
dSYM symbolication still matches.

Modifying the image invalidates any existing code signature, so this must run
before the framework is signed (or the framework must be re-signed after).

Once Dart's Mach-O writer sorts the table itself, this becomes a no-op and can
be deleted.

Usage:
    fix_macho_symbol_order.py <App.framework/Versions/A/App> [more ...]
    fix_macho_symbol_order.py --check <path> [more ...]   # verify only
"""

import struct
import sys

FAT_MAGIC = 0xCAFEBABE
FAT_MAGIC_64 = 0xCAFEBABF
MH_MAGIC_64 = 0xFEEDFACF

LC_SYMTAB = 0x2
LC_DYSYMTAB = 0xB
LC_DYLD_INFO = 0x22
LC_DYLD_INFO_ONLY = 0x80000022
LC_DYLD_EXPORTS_TRIE = 0x80000033

NLIST_SIZE = 16  # struct nlist_64
N_STAB = 0xE0  # debug-symbol mask within n_type

MACH_HEADER_64_SIZE = 32
FAT_ARCH_SIZE = 20
FAT_ARCH_64_SIZE = 32

# LC_DYSYMTAB fields that must be empty for a permutation to be safe: each one
# would otherwise hold an index into the symbol table we are about to reorder.
INDEX_BEARING_FIELDS = (
    "nlocalsym",
    "nundefsym",
    "ntoc",
    "nmodtab",
    "nextrefsyms",
    "nindirectsyms",
    "nextrel",
    "nlocrel",
)

DYSYMTAB_FIELDS = (
    "ilocalsym", "nlocalsym",
    "iextdefsym", "nextdefsym",
    "iundefsym", "nundefsym",
    "tocoff", "ntoc",
    "modtaboff", "nmodtab",
    "extrefsymoff", "nextrefsyms",
    "indirectsymoff", "nindirectsyms",
    "extreloff", "nextrel",
    "locreloff", "nlocrel",
)


class MachOError(Exception):
    """Raised when a file is not the Mach-O shape this script may rewrite."""


def dyld_classic_dlsym(names, key):
    """Replica of dyld's pre-dyld4 ``dlsym`` over the external defined range.

    Binary searches ``names`` as dyld does, assuming they are sorted. Returns
    the index of ``key`` or ``None``. Present so the tests can demonstrate the
    failure this script prevents rather than merely asserting an ordering.
    """
    low, high = 0, len(names) - 1
    while low <= high:
        mid = (low + high) // 2
        if names[mid] == key:
            return mid
        if key > names[mid]:
            low = mid + 1
        else:
            high = mid - 1
    return None


def slice_ranges(data):
    """Return ``[(offset, size), ...]`` for each architecture in ``data``."""
    if len(data) < 8:
        raise MachOError("file too short to be Mach-O")

    (magic,) = struct.unpack_from(">I", data, 0)
    if magic in (FAT_MAGIC, FAT_MAGIC_64):
        (count,) = struct.unpack_from(">I", data, 4)
        wide = magic == FAT_MAGIC_64
        entry = FAT_ARCH_64_SIZE if wide else FAT_ARCH_SIZE
        ranges = []
        for i in range(count):
            base = 8 + i * entry
            if base + entry > len(data):
                raise MachOError("truncated fat header")
            if wide:
                offset, size = struct.unpack_from(">QQ", data, base + 8)
            else:
                offset, size = struct.unpack_from(">II", data, base + 8)
            if offset + size > len(data):
                raise MachOError("fat slice extends past end of file")
            ranges.append((offset, size))
        return ranges

    (thin,) = struct.unpack_from("<I", data, 0)
    if thin != MH_MAGIC_64:
        raise MachOError("not a 64-bit little-endian Mach-O or fat image")
    return [(0, len(data))]


def _load_commands(data, base, end):
    """Yield ``(cmd, cmd_offset, cmdsize)`` for each load command in a slice."""
    if base + MACH_HEADER_64_SIZE > end:
        raise MachOError("truncated Mach-O header")
    (magic,) = struct.unpack_from("<I", data, base)
    if magic != MH_MAGIC_64:
        raise MachOError("not a 64-bit little-endian Mach-O slice")
    (ncmds,) = struct.unpack_from("<I", data, base + 16)

    offset = base + MACH_HEADER_64_SIZE
    for _ in range(ncmds):
        if offset + 8 > end:
            raise MachOError("truncated load command")
        cmd, cmdsize = struct.unpack_from("<II", data, offset)
        if cmdsize < 8 or offset + cmdsize > end:
            raise MachOError("malformed load command size")
        yield cmd, offset, cmdsize
        offset += cmdsize


def symtab_fields(data, base, end=None):
    """Return ``(symoff, nsyms, stroff, strsize)`` with file-absolute offsets."""
    end = len(data) if end is None else end
    for cmd, offset, _ in _load_commands(data, base, end):
        if cmd == LC_SYMTAB:
            symoff, nsyms, stroff, strsize = struct.unpack_from("<IIII", data, offset + 8)
            return base + symoff, nsyms, base + stroff, strsize
    raise MachOError("no LC_SYMTAB")


def _dysymtab_fields(data, base, end):
    for cmd, offset, _ in _load_commands(data, base, end):
        if cmd == LC_DYSYMTAB:
            values = struct.unpack_from("<18I", data, offset + 8)
            return dict(zip(DYSYMTAB_FIELDS, values))
    raise MachOError("no LC_DYSYMTAB")


def _has_exports_trie(data, base, end):
    return any(
        cmd in (LC_DYLD_INFO, LC_DYLD_INFO_ONLY, LC_DYLD_EXPORTS_TRIE)
        for cmd, _, _ in _load_commands(data, base, end)
    )


def _symbol_name_bytes(data, stroff, strsize, n_strx):
    """Return the raw NUL-terminated name of a symbol table entry.

    Names stay bytes end to end. dyld compares them with ``strcmp``, a byte-wise
    comparison, and a Mach-O string table carries no encoding guarantee -- so
    decoding to text would both risk raising on non-UTF-8 names and (via
    surrogate escapes) sort them into an order the loader disagrees with.
    """
    if n_strx >= strsize:
        raise MachOError("symbol name offset past end of string table")
    start = stroff + n_strx
    terminator = data.find(b"\x00", start, stroff + strsize)
    if terminator < 0:
        raise MachOError("unterminated symbol name")
    return bytes(data[start:terminator])


def read_external_symbols(data, base, end=None):
    """Return ``[(name, (n_type, n_sect, n_desc, n_value)), ...]`` in file order.

    ``name`` is raw bytes; decode only for display.
    """
    end = len(data) if end is None else end
    symoff, nsyms, stroff, strsize = symtab_fields(data, base, end)
    dysymtab = _dysymtab_fields(data, base, end)

    first = dysymtab["iextdefsym"]
    count = dysymtab["nextdefsym"]
    if first + count > nsyms:
        raise MachOError("external symbol range exceeds symbol table")
    if symoff + nsyms * NLIST_SIZE > len(data):
        raise MachOError("symbol table extends past end of file")
    if stroff + strsize > len(data):
        raise MachOError("string table extends past end of file")

    symbols = []
    for i in range(first, first + count):
        entry = symoff + i * NLIST_SIZE
        n_strx, n_type, n_sect, n_desc, n_value = struct.unpack_from("<IBBHQ", data, entry)
        symbols.append(
            (
                _symbol_name_bytes(data, stroff, strsize, n_strx),
                (n_type, n_sect, n_desc, n_value),
            )
        )
    return symbols


def sort_slice(data, base, end=None):
    """Sort one slice's external defined symbols by name. Return True if changed.

    Returns False without touching ``data`` when the image is linker-produced
    (it has an exports trie, so dyld never uses the binary search) or is
    already sorted. Raises :class:`MachOError` for any other shape.
    """
    end = len(data) if end is None else end

    if _has_exports_trie(data, base, end):
        return False

    symoff, nsyms, stroff, strsize = symtab_fields(data, base, end)
    dysymtab = _dysymtab_fields(data, base, end)

    populated = [field for field in INDEX_BEARING_FIELDS if dysymtab[field]]
    if populated:
        raise MachOError(
            "refusing to reorder: symbol indices are referenced by "
            + ", ".join(populated)
        )

    first = dysymtab["iextdefsym"]
    count = dysymtab["nextdefsym"]
    if count == 0:
        return False
    if first + count > nsyms:
        raise MachOError("external symbol range exceeds symbol table")
    if symoff + nsyms * NLIST_SIZE > len(data):
        raise MachOError("symbol table extends past end of file")
    if stroff + strsize > len(data):
        raise MachOError("string table extends past end of file")

    start = symoff + first * NLIST_SIZE
    entries = []
    for i in range(count):
        offset = start + i * NLIST_SIZE
        raw = bytes(data[offset:offset + NLIST_SIZE])
        (n_strx,) = struct.unpack_from("<I", raw, 0)
        n_type = raw[4]
        if n_type & N_STAB:
            raise MachOError("debug symbol inside the external defined range")
        entries.append((_symbol_name_bytes(data, stroff, strsize, n_strx), raw))

    ordered = sorted(entries, key=lambda item: item[0])
    if ordered == entries:
        return False

    for i, (_, raw) in enumerate(ordered):
        offset = start + i * NLIST_SIZE
        data[offset:offset + NLIST_SIZE] = raw
    return True


def sort_image(data):
    """Sort every slice of a thin or fat image. Return the number changed."""
    changed = 0
    for base, size in slice_ranges(data):
        if sort_slice(data, base, base + size):
            changed += 1
    return changed


def _describe(path, data):
    """Return report lines naming each slice's external symbols, in file order."""
    lines = []
    for base, size in slice_ranges(data):
        names = [
            name.decode("utf-8", "surrogateescape")
            for name, _ in read_external_symbols(data, base, base + size)
        ]
        lines.append(f"    slice @{base}: {', '.join(names)}")
    return lines


def main(argv):
    args = argv[1:]
    check_only = "--check" in args
    paths = [arg for arg in args if arg != "--check"]
    if not paths:
        print(__doc__)
        return 2

    all_ok = True
    for path in paths:
        print(f"{'Checking' if check_only else 'Sorting'} Mach-O symbol table: {path}")
        try:
            with open(path, "rb") as fh:
                data = bytearray(fh.read())
            changed = sort_image(data)
        except (OSError, MachOError, struct.error) as exc:
            # Fail closed: an image we cannot parse is one we cannot prove is
            # loadable on macOS 11, so never let the build believe it passed.
            print(f"  ERROR {path}: {exc}")
            all_ok = False
            continue

        if check_only:
            if changed:
                print(f"  FAIL  {changed} slice(s) have unsorted external symbols")
                print("  -> this build will crash on launch on macOS 11 (issue #996)")
                all_ok = False
            else:
                print("  ok    external symbols are sorted in every slice")
            continue

        if changed:
            with open(path, "wb") as fh:
                fh.write(data)
            print(f"  sorted {changed} slice(s); re-sign the framework before shipping")
        else:
            print("  ok    already sorted (or linker-produced); left unchanged")
        for line in _describe(path, data):
            print(line)

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
