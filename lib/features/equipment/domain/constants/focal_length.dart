/// A lens's focal length as the diver writes it (issue #3050): a prime's
/// single figure ("60") or a zoom's range ("15-45", "8 to 16mm").
///
/// Storage contract for `AttributeKind.focalLength`: valueText holds the
/// text as written, valueNum the wide (shorter) end in mm, so a zoom still
/// sorts and queries by a number. Rows saved before #3050 carry valueNum
/// alone, and every reader here falls back to it.
library;

const _figure = r'(\d+(?:[.,]\d+)?)\s*(?:mm)?';

/// One figure, optionally followed by a second joined with a hyphen, an en
/// or em dash (phones substitute them as the diver types), or "to".
final _focalLength = RegExp(
  '^$_figure(?:\\s*(?:-|${String.fromCharCode(0x2013)}|'
  '${String.fromCharCode(0x2014)}|to)\\s*$_figure)?\$',
  caseSensitive: false,
);

final _unit = RegExp(r'\s*mm', caseSensitive: false);

double _readFigure(String figure) => double.parse(figure.replaceAll(',', '.'));

/// A number without a trailing ".0". Non-finite values (only a hand-edited
/// file can carry one) read as nothing rather than throwing in toInt().
String _plain(double n) {
  if (!n.isFinite) return '';
  return n == n.truncateToDouble() ? n.toInt().toString() : n.toString();
}

/// Whether [text] is a focal length the edit form accepts: one figure or a
/// range of two, each optionally suffixed with `mm`. Empty is valid because
/// the field is optional.
bool isValidFocalLength(String text) {
  final t = text.trim();
  return t.isEmpty || _focalLength.hasMatch(t);
}

/// The wide (shorter) end of [text] in mm: the figure itself for a prime,
/// the smaller figure of a zoom's range in whichever order it was written.
/// Null when [text] is not a focal length.
double? parseFocalLengthWideEnd(String text) {
  final match = _focalLength.firstMatch(text.trim());
  if (match == null) return null;
  final first = _readFigure(match.group(1)!);
  final second = match.group(2);
  if (second == null) return first;
  final other = _readFigure(second);
  return first < other ? first : other;
}

/// What the edit field shows for a stored value: the text as written, or a
/// pre-#3050 row's number without a trailing ".0".
String focalLengthEditText({String? valueText, double? valueNum}) {
  final text = valueText?.trim() ?? '';
  if (text.isNotEmpty) return text;
  return valueNum == null ? '' : _plain(valueNum);
}

/// The detail page's display: any `mm` the diver typed is dropped and the
/// unit appended exactly once ("15mm-45mm" reads "15-45 mm"). Text that is
/// not a focal length (a CSV import keeps it as written) is shown as is,
/// never as "wide mm".
String formatFocalLength({String? valueText, double? valueNum}) {
  final raw = valueText?.trim() ?? '';
  final written = raw.replaceAll(_unit, '').trim();
  if (written.isEmpty) {
    final figure = valueNum == null ? '' : _plain(valueNum);
    return figure.isEmpty ? '' : '$figure mm';
  }
  return isValidFocalLength(raw) ? '$written mm' : raw;
}
