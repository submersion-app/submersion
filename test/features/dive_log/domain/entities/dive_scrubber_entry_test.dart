import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/gas_colors.dart';

void main() {
  group('gas class', () {
    test('no tanks is unclassified, not air', () {
      expect(DiveScrubberGas.of(), isNull);
    });

    test('up to 22% O2 is air, like the chart', () {
      expect(DiveScrubberGas.of(maxO2: 21, maxHe: 0), DiveScrubberGas.air);
      expect(DiveScrubberGas.of(maxO2: 22.0, maxHe: 0), DiveScrubberGas.air);
      expect(DiveScrubberGas.of(maxO2: 22), DiveScrubberGas.air);
    });

    test('any O2 above 22% without helium is nitrox', () {
      expect(DiveScrubberGas.of(maxO2: 22.5, maxHe: 0), DiveScrubberGas.nitrox);
      expect(DiveScrubberGas.of(maxO2: 32), DiveScrubberGas.nitrox);
      expect(DiveScrubberGas.of(maxO2: 100, maxHe: 0), DiveScrubberGas.nitrox);
    });

    test('any helium is trimix, whatever the O2', () {
      expect(DiveScrubberGas.of(maxO2: 18, maxHe: 45), DiveScrubberGas.trimix);
      expect(DiveScrubberGas.of(maxO2: 50, maxHe: 0.5), DiveScrubberGas.trimix);
      expect(DiveScrubberGas.of(maxHe: 10), DiveScrubberGas.trimix);
    });

    test('agrees with the chart, oxygen counting as nitrox', () {
      const o2s = <double>[0, 18, 21, 22, 22.5, 32, 50, 98.9, 99, 100];
      const hes = <double>[0, 0.5, 10, 45];
      for (final o2 in o2s) {
        for (final he in hes) {
          final chart = GasColors.forMixPercent(o2, he);
          final expected = chart == GasColors.trimix
              ? DiveScrubberGas.trimix
              : chart == GasColors.air
              ? DiveScrubberGas.air
              : DiveScrubberGas.nitrox;
          expect(
            DiveScrubberGas.of(maxO2: o2, maxHe: he),
            expected,
            reason: 'O2 $o2, He $he',
          );
        }
      }
    });

    test('classes rank air, nitrox, trimix', () {
      expect(DiveScrubberGas.values, [
        DiveScrubberGas.air,
        DiveScrubberGas.nitrox,
        DiveScrubberGas.trimix,
      ]);
    });
  });

  test('an entry defaults to no gas and its gas takes part in equality', () {
    const plain = DiveScrubberEntry(id: 'a', sortTimestamp: 0);
    expect(plain.gas, isNull);
    expect(
      plain,
      isNot(
        const DiveScrubberEntry(
          id: 'a',
          sortTimestamp: 0,
          gas: DiveScrubberGas.nitrox,
        ),
      ),
    );
  });

  group('copyWith', () {
    const full = DiveScrubberEntry(
      id: 'a',
      sortTimestamp: 1,
      tripId: 't',
      tripName: 'Trip',
      diveNumber: 7,
      siteName: 'Reef',
      maxDepth: 18.5,
      bottomTime: Duration(minutes: 40),
      rating: 3,
      isFavorite: true,
      gas: DiveScrubberGas.nitrox,
    );

    test('with no arguments is an equal copy', () {
      expect(full.copyWith(), full);
    });

    test('replaces every field', () {
      const other = DiveScrubberEntry(
        id: 'b',
        sortTimestamp: 2,
        tripId: 'u',
        tripName: 'Other',
        diveNumber: 8,
        siteName: 'Wall',
        maxDepth: 30,
        bottomTime: Duration(minutes: 50),
        rating: 5,
        gas: DiveScrubberGas.trimix,
      );
      expect(
        full.copyWith(
          id: 'b',
          sortTimestamp: 2,
          tripId: 'u',
          tripName: 'Other',
          diveNumber: 8,
          siteName: 'Wall',
          maxDepth: 30,
          bottomTime: const Duration(minutes: 50),
          rating: 5,
          isFavorite: false,
          gas: DiveScrubberGas.trimix,
        ),
        other,
      );
    });
  });
}
