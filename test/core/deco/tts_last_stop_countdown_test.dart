import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

// These tests pin the gradient-factor ascent against Subsurface's model:
//
//  * GF-low is anchored at the dive's DEEPEST ceiling and held fixed for the
//    whole ascent (Subsurface's gf_low_pressure_this_dive), so shallow stops
//    interpolate toward GF-high instead of collapsing to GF-low.
//  * A stop is left when the diver may ascend to the NEXT shallower stop,
//    evaluated at that shallower depth's GF (Subsurface's trial_ascent). At the
//    last stop that depth is the surface (GF-high) -- the same criterion the
//    deco-cleared check uses -- so TTS counts down smoothly instead of sitting
//    pinned at the GF-low value and then collapsing in a single sample.
Future<(List<double>, List<int>, List<ProfileGasSegment>)> _loadOc(
  String fixture,
) async {
  final bytes = Uint8List.fromList(
    utf8.encode(File('test/dives/$fixture').readAsStringSync()),
  );
  final dive = (await SubsurfaceXmlParser().parse(
    bytes,
  )).entitiesOf(ImportEntityType.dives).first;
  final profile = (dive['profile'] as List).cast<Map<String, dynamic>>();
  final mixes = (dive['tanks'] as List)
      .map((t) => (t as Map)['gasMix'] as GasMix)
      .toList();
  final segs = <ProfileGasSegment>[
    ProfileGasSegment(
      startTimestamp: 0,
      fN2: (100 - mixes[0].o2 - mixes[0].he) / 100,
      fHe: mixes[0].he / 100,
    ),
  ];
  for (final s in (dive['gasSwitches'] as List)) {
    final t = (s as Map)['timestamp'] as int;
    final idx = int.parse((s['tankRef'] as String).split(':').first);
    final m = mixes[idx];
    segs.add(
      ProfileGasSegment(
        startTimestamp: t,
        fN2: (100 - m.o2 - m.he) / 100,
        fHe: m.he / 100,
      ),
    );
  }
  return (
    profile.map((p) => p['depth'] as double).toList(),
    profile.map((p) => p['timestamp'] as int).toList(),
    segs,
  );
}

void main() {
  test('fixture 001: calculated TTS at the 3 m stop does not cliff', () async {
    final (depths, ts, segs) = await _loadOc(
      '001_short_deco_single_gas_switch.ssrf.xml',
    );
    final tts = (BuhlmannAlgorithm(gfLow: 0.50, gfHigh: 0.75)..reset())
        .processProfileWithGasSegments(
          depths: depths,
          timestamps: ts,
          gasSegments: segs,
        )
        .map((s) => s.ttsSeconds)
        .toList();

    // Inspect the final shallow (3 m) phase, isolating the last-stop clearance
    // from the separate recorded-gas-switch drop earlier in the dive. A smooth
    // count-down drops at most ~1 stop-minute per sample; the bug collapsed TTS
    // by ~12 min (~720 s) in a single 10 s sample.
    var maxDrop = 0;
    for (var i = 1; i < ts.length; i++) {
      if (depths[i] <= 3.5 && ts[i] > 45 * 60) {
        final drop = tts[i - 1] - tts[i];
        if (drop > maxDrop) maxDrop = drop;
      }
    }
    expect(
      maxDrop,
      lessThanOrEqualTo(120),
      reason: 'TTS collapsed by ${maxDrop}s at the 3 m stop (flat-then-cliff)',
    );
  });

  test(
    'fixture 004 @ 9 m: ceiling matches Subsurface (deep GF-low anchor)',
    () async {
      // Subsurface (GF 50/75) reports a 7.4 m calculated ceiling at min 30 (9 m).
      // Before the fixed deep anchor the app collapsed to GF-low at the 9 m stop
      // and reported ~8.8 m (too conservative).
      final (depths, ts, segs) = await _loadOc(
        '004_short_deco_single_gas_switch.ssrf.xml',
      );
      final statuses = (BuhlmannAlgorithm(gfLow: 0.50, gfHigh: 0.75)..reset())
          .processProfileWithGasSegments(
            depths: depths,
            timestamps: ts,
            gasSegments: segs,
          );
      final DecoStatus atMin30 = statuses[ts.indexWhere((t) => t == 30 * 60)];
      expect(atMin30.ceilingMeters, closeTo(7.4, 0.6));
    },
  );
}
