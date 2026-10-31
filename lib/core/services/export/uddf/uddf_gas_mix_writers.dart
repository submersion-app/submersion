import 'package:xml/xml.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// UDDF writer for gas mixes, shared by the full backup and the dives-only
/// export so the two name a mix the same way. A mix's id is its identity in
/// the file: `<gasdefinitions>` holds one `<mix>` per id, and each cylinder
/// and starting `<switchmix>` links to one by it.
class UddfGasMixWriters {
  const UddfGasMixWriters._();

  /// The id of [mix], built from its exact percentages so two mixes share an
  /// id only when they are the same gas: `mix_32_0`, or `mix_32.1_0` for an
  /// analyzed fraction. Truncating them merged 32.1% and 32.9% into one
  /// definition (issue #3967).
  static String mixId(GasMix mix) =>
      'mix_${_percentId(mix.o2)}_${_percentId(mix.he)}';

  static String _percentId(double percent) {
    final text = percent.toString();
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
              builder.element('o2', nest: (entry.value.o2 / 100).toString());
              builder.element('n2', nest: (entry.value.n2 / 100).toString());
              builder.element('he', nest: (entry.value.he / 100).toString());
            },
          );
        }
      },
    );
  }
}
