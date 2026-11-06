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

  static final _number = RegExp(
    r'^([+-]?)(\d*)(?:\.(\d*))?(?:[eE]([+-]?\d+))?$',
  );

  /// [bar] in Pascal as plain decimal text (`1.01` gives `101000`), or null
  /// for a value that is no reading: zero, negative, NaN or infinite.
  static String? pascalText(double bar) {
    if (!bar.isFinite || bar <= 0) return null;
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
    final exponent = int.parse(match.group(4) ?? '0') - _barExponent;
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
    var result = text.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (result.contains('.')) {
      result = result.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return result;
  }
}
