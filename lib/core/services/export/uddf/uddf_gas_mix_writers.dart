import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// UDDF writer for gas mixes, shared by the full backup and the dives-only
/// export so the two name a mix the same way. A mix's id is its identity in
/// the file: `<gasdefinitions>` holds one `<mix>` per id, and each cylinder
/// and starting `<switchmix>` links to one by it. [parseGasMix] reads a mix
/// back, from these writers or from another program.
class UddfGasMixWriters {
  const UddfGasMixWriters._();

  /// The id of [mix], built from its cleaned percentages so two mixes share
  /// an id only when they are the same gas: `mix_32_0`, or `mix_32.1_0` for
  /// an analyzed fraction. Truncating them merged 32.1% and 32.9% into one
  /// definition (issue #3967).
  static String mixId(GasMix mix) =>
      'mix_${_percentId(mix.o2)}_${_percentId(mix.he)}';

  /// [percent] without the binary error of computing it from a fraction:
  /// 0.29 * 100 is 28.999999999999996, and the native bridges store such
  /// values as they download. Ten decimals sit far below any analyzer's
  /// precision and far above that error, so this tells one gas from another
  /// without telling a gas from its own noise.
  static double cleanPercent(double percent) => _rounded(percent, 10);

  /// [value] at [decimals] places. Adding zero turns the -0.0 a tiny negative
  /// value rounds to, such as the n2 of a 99.9/0.1 mix, into 0.0.
  static double _rounded(double value, int decimals) =>
      double.parse(value.toStringAsFixed(decimals)) + 0.0;

  static String _percentId(double percent) {
    final text = cleanPercent(percent).toString();
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  /// `<gasdefinitions>` with one `<mix>` per distinct gas in [dives], plus
  /// air as the default.
  static void writeGasDefinitions(XmlBuilder builder, List<Dive> dives) {
    builder.element(
      'gasdefinitions',
      nest: () {
        final gasMixes = <String, GasMix>{
          for (final dive in dives)
            for (final tank in dive.tanks) mixId(tank.gasMix): tank.gasMix,
          mixId(const GasMix()): const GasMix(),
        };

        for (final entry in gasMixes.entries) {
          builder.element(
            'mix',
            attributes: {'id': entry.key},
            nest: () {
              builder.element('name', nest: entry.value.name);
              builder.element('o2', nest: _fraction(entry.value.o2));
              builder.element('n2', nest: _fraction(entry.value.n2));
              builder.element('he', nest: _fraction(entry.value.he));
            },
          );
        }
      },
    );
  }

  /// [percent] as UDDF's fraction, at [cleanPercent]'s precision: 12 decimals
  /// of a fraction are 10 of a percentage.
  static String _fraction(double percent) =>
      _rounded(percent / 100, 12).toString();

  /// Reads a `<mix>` as percentages.
  ///
  /// UDDF defines the values as fractions (0.32 for EAN32), but some
  /// programs write percentages (32), and scaling those by 100 stored EAN32
  /// as 3200% oxygen (issue #4705). No share of a gas is above 1, so a mix
  /// with either value above 1 is already in percent. The unit is decided
  /// for the mix as a whole: beside 30% oxygen, a helium of 1 is 1%, not a
  /// whole fraction. A fraction a hair over 1 from float noise
  /// (1.0000000000000002) is still pure gas, not 1%. A missing or
  /// unreadable value, or one outside 0-100% once read, falls back to air's
  /// 21% oxygen and no helium, whatever the unit. A value above 100 is no
  /// share of a gas in either unit, so it does not decide the unit either.
  /// A mix whose oxygen and helium come to more than 100% is no gas at all
  /// and is read as air.
  static GasMix parseGasMix(XmlElement mixElement) {
    final o2 = UddfImportParsers.parseUddfDouble(
      UddfImportParsers.getElementText(mixElement, 'o2'),
    );
    final he = UddfImportParsers.parseUddfDouble(
      UddfImportParsers.getElementText(mixElement, 'he'),
    );
    final scale = _isOnlyAPercentage(o2) || _isOnlyAPercentage(he) ? 1 : 100;

    final o2Percent = _gasPercent(o2, scale) ?? 21.0;
    final hePercent = _gasPercent(he, scale) ?? 0.0;
    if (cleanPercent(o2Percent + hePercent) > 100) return const GasMix();
    return GasMix(o2: o2Percent, he: hePercent);
  }

  /// Whether [value] is above 1 by more than float noise, so it cannot be a
  /// fraction, but no more than 100, so it is a percentage.
  static bool _isOnlyAPercentage(double? value) {
    if (value == null) return false;
    final cleaned = cleanPercent(value);
    return cleaned > 1 && cleaned <= 100;
  }

  /// [value] times [scale] as a percentage, or null when there is no value
  /// or the result is not a share of a gas.
  static double? _gasPercent(double? value, int scale) {
    if (value == null) return null;
    final percent = cleanPercent(value * scale);
    return percent < 0 || percent > 100 ? null : percent;
  }
}
