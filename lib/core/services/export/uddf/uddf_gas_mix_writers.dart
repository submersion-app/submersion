import 'package:xml/xml.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// UDDF writer for gas mixes, shared by the full backup and the dives-only
/// export so the two name a mix the same way. A mix's id is its identity in
/// the file: `<gasdefinitions>` holds one `<mix>` per id, and each cylinder
/// and starting `<switchmix>` links to one by it.
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
  static double cleanPercent(double percent) =>
      double.parse(percent.toStringAsFixed(10));

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
      double.parse((percent / 100).toStringAsFixed(12)).toString();
}
