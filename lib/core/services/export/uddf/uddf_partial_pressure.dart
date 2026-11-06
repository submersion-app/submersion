/// UDDF partial pressures, which the spec defines in Pascal (issue #4198).
///
/// Submersion stores them in bar. Multiplying by 100000 adds float noise
/// (`1.01 * 100000` prints as `101000.00000000001` and reads back as
/// `1.0100000000000002`), so the conversion moves the decimal point in the
/// number's text instead, both ways. The written text is the stored value's
/// shortest form shifted five places, and reading it back parses that same
/// decimal with the exponent lowered by five, so the double that comes back
/// is the one that was stored.
abstract final class UddfPartialPressure {
  /// One bar in Pascal, as a power of ten.
  static const _barExponent = 5;

  /// The largest value read as bar: anything above it is Pascal. No
  /// breathable partial pressure reaches 100 bar, and 100 Pa (0.001 bar) is
  /// no plausible reading either.
  static const maxBar = 100.0;

  static final _number = RegExp(
    r'^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$',
  );

  static final _leadingZeros = RegExp(r'^0+(?=\d)');
  static final _trailingZeros = RegExp(r'\.?0+$');

  /// [bar] in Pascal as plain decimal text (`1.01` gives `101000`), or null
  /// for a value that is no reading: null, NaN, infinite, or so small that
  /// its Pascal value ([maxBar] or less) would read back as bar.
  static String? pascalText(double? bar) {
    if (bar == null || !bar.isFinite) return null;
    // Divided, not multiplied: 0.001 * 100000 rounds above 100.
    if (bar <= maxBar / 100000) return null;
    final match = _number.firstMatch(bar.toString())!;
    final whole = match.group(2)!;
    final digits = '$whole${match.group(3) ?? ''}';
    final exponent = int.parse(match.group(4) ?? '0');
    final point = whole.length + exponent + _barExponent;

    final String text;
    if (point <= 0) {
      text = '0.${'0' * -point}$digits';
    } else if (point >= digits.length) {
      text = digits.padRight(point, '0');
    } else {
      text = '${digits.substring(0, point)}.${digits.substring(point)}';
    }
    return _trim(text);
  }

  /// [pascal], the text of a value in Pascal, in bar. Null when it is no
  /// number.
  static double? barFromPascalText(String pascal) {
    final match = _number.firstMatch(pascal.trim());
    if (match == null) return null;
    final whole = match.group(2)!;
    final fraction = match.group(3) ?? '';
    // "." or an exponent alone has no digits, so it is no number.
    if (whole.isEmpty && fraction.isEmpty) return null;
    // int.tryParse, as an exponent too long for an int is no number either.
    final written = int.tryParse(match.group(4) ?? '0');
    if (written == null) return null;
    final exponent = written - _barExponent;
    // Written out in full ("0" either side of the point) so the text is one
    // double.parse accepts whatever form the input took.
    return double.tryParse(
      '${match.group(1)}${whole.isEmpty ? '0' : whole}.${fraction}0'
      'e$exponent',
    );
  }

  /// Drops leading zeros before the point (keeping one) and trailing zeros
  /// after it, with the point itself when nothing follows it.
  static String _trim(String text) {
    var result = text.replaceFirst(_leadingZeros, '');
    if (result.contains('.')) {
      result = result.replaceFirst(_trailingZeros, '');
    }
    return result;
  }
}
