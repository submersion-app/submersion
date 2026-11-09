import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

/// How far apart, in bar, a metadata tank's start pressure and a parsed
/// tank's may be and still describe one cylinder. Shearwater Cloud stores
/// whole psi and the raw log 2 psi steps, so one reading never differs by
/// more than a fraction of a bar.
const double _pressureToleranceBar = 1.0;

/// [metaTanks] with the transmitter serial of the parsed tank each one pairs
/// with (issue #4347): Shearwater Cloud's metadata names a dive's tanks but
/// carries no serial, while libdivecomputer reads the serial off the raw log.
///
/// Both lists run in slot order, and libdivecomputer leaves out a slot that
/// never read a pressure. So when every metadata tank with a pressure lines
/// up with the parsed tank at the same position, they pair in order, which
/// settles two cylinders filled to the same pressure. Otherwise a tank pairs
/// with the one parsed tank whose start pressure is within tolerance, and
/// only when no other tank claims it. Anything less certain leaves the
/// serial unset: a wrong serial would give the tank another cylinder's
/// role and size.
List<Map<String, dynamic>> withTransmitterSerials(
  List<Map<String, dynamic>> metaTanks,
  List<pigeon.TankInfo> parsedTanks,
) {
  final candidates = [
    for (final t in parsedTanks)
      if ((t.transmitterSerial ?? 0) > 0 && t.startPressureBar != null) t,
  ];
  if (candidates.isEmpty) {
    return [
      for (final t in metaTanks) {...t},
    ];
  }

  double? startOf(Map<String, dynamic> t) =>
      (t['startPressure'] as num?)?.toDouble();
  bool close(double a, double b) => (a - b).abs() <= _pressureToleranceBar;

  // Index into candidates per metadata tank; null leaves it unpaired.
  final pairing = List<int?>.filled(metaTanks.length, null);
  final withPressure = [
    for (var i = 0; i < metaTanks.length; i++)
      if (startOf(metaTanks[i]) != null) i,
  ];
  final inSlotOrder =
      withPressure.length == candidates.length &&
      [
        for (var k = 0; k < withPressure.length; k++)
          close(
            startOf(metaTanks[withPressure[k]])!,
            candidates[k].startPressureBar!,
          ),
      ].every((ok) => ok);

  if (inSlotOrder) {
    for (var k = 0; k < withPressure.length; k++) {
      pairing[withPressure[k]] = k;
    }
  } else {
    final claims = List<int>.filled(candidates.length, 0);
    for (final i in withPressure) {
      final near = [
        for (var c = 0; c < candidates.length; c++)
          if (close(startOf(metaTanks[i])!, candidates[c].startPressureBar!)) c,
      ];
      if (near.length != 1) continue;
      pairing[i] = near.single;
      claims[near.single]++;
    }
    for (var i = 0; i < pairing.length; i++) {
      final c = pairing[i];
      if (c != null && claims[c] > 1) pairing[i] = null;
    }
  }

  return [
    for (var i = 0; i < metaTanks.length; i++)
      {
        ...metaTanks[i],
        if (pairing[i] case final c?)
          'transmitterSerial': '${candidates[c].transmitterSerial}',
      },
  ];
}
