import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

void main() {
  const full = ComputerTissueSnapshot(
    start: ComputerTissueState(
      n2Bar: [0.79, 0.8, 0.81],
      heBar: [0.0, 0.0, 0.0],
      n2LoadPercent: 12.0,
      surfaceGfPercent: 5.0,
    ),
    end: ComputerTissueState(
      n2Bar: [1.5, 1.4, 1.3],
      heBar: [0.1, 0.2, 0.3],
      loadPercent: [80.0, 75.0, 70.0],
      n2LoadPercent: 78.0,
      gf99Percent: 42.0,
      surfaceGfPercent: 61.0,
      rgbmNitrogen: 0.97,
      rgbmHelium: 1.0,
    ),
  );

  group('ComputerTissueState', () {
    test('compartment count comes from n2Bar first, then loadPercent', () {
      const tensions = ComputerTissueState(n2Bar: [1.0, 1.1]);
      const loads = ComputerTissueState(loadPercent: [10.0, 20.0, 30.0]);
      const scalars = ComputerTissueState(gf99Percent: 40.0);
      expect(tensions.compartmentCount, 2);
      expect(loads.compartmentCount, 3);
      expect(scalars.compartmentCount, isNull);
      expect(tensions.hasCompartments, isTrue);
      expect(loads.hasCompartments, isTrue);
      expect(scalars.hasCompartments, isFalse);
      expect(const ComputerTissueState(n2Bar: []).hasCompartments, isFalse);
    });

    test('toJson uses snake_case keys and omits null fields', () {
      final json = full.end!.toJson();
      expect(json.keys, {
        'n2_bar',
        'he_bar',
        'load_percent',
        'n2_load_percent',
        'gf99_percent',
        'surface_gf_percent',
        'rgbm_nitrogen',
        'rgbm_helium',
      });
      expect(full.start!.toJson().keys, {
        'n2_bar',
        'he_bar',
        'n2_load_percent',
        'surface_gf_percent',
      });
    });

    test('value equality is deep over the compartment lists', () {
      const a = ComputerTissueState(n2Bar: [1.0, 2.0], gf99Percent: 10.0);
      final b = ComputerTissueState(
        n2Bar: [1.0, 2.0].toList(),
        gf99Percent: 10.0,
      );
      const c = ComputerTissueState(n2Bar: [1.0, 2.5], gf99Percent: 10.0);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('copyWith replaces only what is given', () {
      final changed = full.end!.copyWith(gf99Percent: 50.0);
      expect(changed.gf99Percent, 50.0);
      expect(changed.n2Bar, full.end!.n2Bar);
      expect(changed.rgbmNitrogen, full.end!.rgbmNitrogen);
    });

    test('copyWith with no arguments keeps every field', () {
      expect(full.end!.copyWith(), full.end);
    });
  });

  group('ComputerTissueSnapshot', () {
    test('round-trips through toJson and fromJson', () {
      expect(ComputerTissueSnapshot.fromJson(full.toJson()), full);
    });

    test('round-trips through encode and decode', () {
      final text = full.encode();
      expect(ComputerTissueSnapshot.decode(text), full);
    });

    test('top-level JSON keys are start and end', () {
      expect(full.toJson().keys, {'start', 'end'});
      expect(const ComputerTissueSnapshot().toJson(), isEmpty);
    });

    test('hasCompartmentData prefers the end state, then the start', () {
      expect(full.hasCompartmentData, isTrue);
      const startOnly = ComputerTissueSnapshot(
        start: ComputerTissueState(loadPercent: [1.0]),
      );
      const endWithoutCompartments = ComputerTissueSnapshot(
        start: ComputerTissueState(loadPercent: [1.0]),
        end: ComputerTissueState(gf99Percent: 30.0),
      );
      const scalarsOnly = ComputerTissueSnapshot(
        end: ComputerTissueState(gf99Percent: 30.0),
      );
      expect(startOnly.hasCompartmentData, isTrue);
      // The end state is what the dive ends on; an end without compartments
      // does not fall back to the start's.
      expect(endWithoutCompartments.hasCompartmentData, isFalse);
      expect(scalarsOnly.hasCompartmentData, isFalse);
      expect(const ComputerTissueSnapshot().hasCompartmentData, isFalse);
    });

    test('decode returns null on null and blank text', () {
      expect(ComputerTissueSnapshot.decode(null), isNull);
      expect(ComputerTissueSnapshot.decode(''), isNull);
      expect(ComputerTissueSnapshot.decode('   '), isNull);
    });

    test('decode throws only on non-object JSON', () {
      expect(
        () => ComputerTissueSnapshot.decode('[1, 2]'),
        throwsFormatException,
      );
      expect(() => ComputerTissueSnapshot.decode('42'), throwsFormatException);
      expect(
        () => ComputerTissueSnapshot.decode('not json'),
        throwsFormatException,
      );
    });

    test('tryDecode swallows what decode would throw on', () {
      expect(ComputerTissueSnapshot.tryDecode('[1, 2]'), isNull);
      expect(ComputerTissueSnapshot.tryDecode('not json'), isNull);
      expect(ComputerTissueSnapshot.tryDecode(null), isNull);
      expect(ComputerTissueSnapshot.tryDecode(full.encode()), full);
    });

    test('fromJson tolerates missing keys', () {
      expect(
        ComputerTissueSnapshot.fromJson(const {}),
        const ComputerTissueSnapshot(),
      );
    });

    test('fromJson reads past the dive-level values older snapshots held', () {
      // Snapshots stored before #2555 carried the algorithm, CNS and OTU,
      // which have their own dive columns; v316 moved them there.
      final parsed = ComputerTissueSnapshot.fromJson(const {
        'algorithm': 'zhl_16c',
        'start': {'cns_percent': 3.0, 'otu': 1.0, 'n2_load_percent': 10},
        'end': {'cns_percent': 14.0, 'otu': 22.0, 'gf99_percent': 42},
      });
      final onlyLegacy = ComputerTissueSnapshot.fromJson(const {
        'end': {'cns_percent': 14.0, 'otu': 22.0},
      });
      expect(
        parsed,
        const ComputerTissueSnapshot(
          start: ComputerTissueState(n2LoadPercent: 10.0),
          end: ComputerTissueState(gf99Percent: 42.0),
        ),
      );
      expect(parsed.toJson(), {
        'start': {'n2_load_percent': 10.0},
        'end': {'gf99_percent': 42.0},
      });
      // A state holding nothing the snapshot knows reads as no state.
      expect(onlyLegacy.end, isNull);
    });

    test('fromJson nulls malformed values instead of throwing', () {
      final parsed = ComputerTissueSnapshot.fromJson(const {
        'start': 'junk',
        'end': {
          'n2_bar': [1.0, 'x', 3.0],
          'he_bar': 'not a list',
          'load_percent': [50, 60.5],
          'n2_load_percent': 'seventy',
          'gf99_percent': 42,
          'surface_gf_percent': null,
          'rgbm_nitrogen': {'a': 1},
          'rgbm_helium': 1.0,
          'unknown_key': 'ignored',
        },
      });
      expect(parsed.start, isNull);
      final end = parsed.end!;
      // One junk element voids the list: compartment order is positional,
      // so a list with a hole is not a shorter list.
      expect(end.n2Bar, isNull);
      expect(end.heBar, isNull);
      expect(end.loadPercent, [50.0, 60.5]);
      expect(end.n2LoadPercent, isNull);
      expect(end.gf99Percent, 42.0);
      expect(end.surfaceGfPercent, isNull);
      expect(end.rgbmNitrogen, isNull);
      expect(end.rgbmHelium, 1.0);
    });

    test('fromJson accepts integers where doubles are expected', () {
      final parsed = ComputerTissueSnapshot.fromJson(const {
        'end': {
          'n2_bar': [1, 2],
          'gf99_percent': 55,
        },
      });
      expect(parsed.end!.n2Bar, [1.0, 2.0]);
      expect(parsed.end!.gf99Percent, 55.0);
    });

    test('from coerces a snapshot, a JSON map or JSON text', () {
      expect(ComputerTissueSnapshot.from(full), same(full));
      expect(ComputerTissueSnapshot.from(full.toJson()), full);
      expect(ComputerTissueSnapshot.from(full.encode()), full);
      expect(ComputerTissueSnapshot.from(null), isNull);
      expect(ComputerTissueSnapshot.from(42), isNull);
      expect(ComputerTissueSnapshot.from('[1]'), isNull);
    });

    test('copyWith replaces only what is given', () {
      const end = ComputerTissueState(gf99Percent: 12.0);
      final changed = full.copyWith(end: end);
      expect(changed.start, full.start);
      expect(changed.end, end);
    });

    test('copyWith with no arguments keeps start and end', () {
      expect(full.copyWith(), full);
    });
  });
}
