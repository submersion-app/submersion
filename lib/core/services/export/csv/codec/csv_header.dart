/// One CSV header split into its base name and optional parenthesised
/// suffix: `Max Depth (ft)` is base `Max Depth`, suffix `ft`. The suffix
/// names a unit (`ft`, `°F`, `psi`) or a date/time format (`DD/MM/YYYY`,
/// `12-hour`). Submersion's CSV exports always write this shape, so the
/// importer can tell a feet column from a metres one by its header.
class CsvHeader {
  const CsvHeader(this.base, [this.suffix]);

  final String base;
  final String? suffix;

  static final _withSuffix = RegExp(r'^(.*\S)\s*\(([^()]+)\)$');

  factory CsvHeader.parse(String raw) {
    final text = raw.trim();
    final match = _withSuffix.firstMatch(text);
    if (match == null) return CsvHeader(text);
    return CsvHeader(match.group(1)!.trim(), match.group(2)!.trim());
  }

  /// Case-folded base, used to look a column up by name.
  String get key => base.toLowerCase();

  @override
  String toString() => suffix == null ? base : '$base ($suffix)';
}
