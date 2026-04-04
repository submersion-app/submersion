import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

void main() {
  group('BuhlmannAlgorithm', () {
    late BuhlmannAlgorithm algorithm;

    setUp(() {
      algorithm = BuhlmannAlgorithm(
        gfLow: 1.0, // 100% - no conservatism for validation tests
        gfHigh: 1.0,
      );
    });

    group('initialization', () {
      test('should initialize with default gradient factors', () {
        final defaultAlgorithm = BuhlmannAlgorithm();
        expect(defaultAlgorithm, isNotNull);
      });

      test('should initialize with custom gradient factors', () {
        final customAlgorithm = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.70);
        expect(customAlgorithm, isNotNull);
      });

      test('should initialize tissues at surface', () {
        final status = algorithm.getDecoStatus(currentDepth: 0);
        expect(status.ceilingMeters, equals(0.0));
        expect(status.inDeco, isFalse);
      });

      test('should have 16 tissue compartments', () {
        expect(algorithm.compartments.length, equals(16));
      });
    });

    group('NDL calculations', () {
      test(
        'should return a raw Buhlmann NDL near 17 minutes at 30m on air',
        () {
          final ndl = algorithm.calculateNdl(
            depthMeters: 30.0,
            fN2: airN2Fraction,
            fHe: 0.0,
          );

          expect(ndl, greaterThanOrEqualTo(15 * 60));
          expect(ndl, lessThanOrEqualTo(18 * 60));
        },
      );

      test('should return reasonable NDL for shallow dive on air', () {
        // At 10m on air, NDL should be very long (near infinite)
        final ndl = algorithm.calculateNdl(
          depthMeters: 10.0,
          fN2: airN2Fraction,
          fHe: 0.0,
        );
        // NDL at 10m is typically unlimited (>200 min)
        expect(ndl, greaterThan(200 * 60));
      });

      test('should return shorter NDL for deeper dive', () {
        // At 30m on air, NDL is limited
        final ndl = algorithm.calculateNdl(
          depthMeters: 30.0,
          fN2: airN2Fraction,
          fHe: 0.0,
        );
        // NDL at 30m is approximately 20 minutes for ZH-L16C (varies by GF)
        expect(ndl, greaterThan(10 * 60));
        expect(ndl, lessThan(60 * 60));
      });

      test('should return very short NDL for very deep dive', () {
        // At 40m on air, NDL is very short
        final ndl = algorithm.calculateNdl(
          depthMeters: 40.0,
          fN2: airN2Fraction,
          fHe: 0.0,
        );
        // NDL at 40m is approximately 5-10 minutes
        expect(ndl, greaterThan(3 * 60));
        expect(ndl, lessThan(20 * 60));
      });

      test('should return longer NDL with nitrox 32', () {
        // Nitrox 32 (32% O2, 68% N2) should have longer NDL than air
        final ndlAir = algorithm.calculateNdl(
          depthMeters: 30.0,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        algorithm.reset();

        final ndlNitrox = algorithm.calculateNdl(
          depthMeters: 30.0,
          fN2: 0.68, // 32% O2
          fHe: 0.0,
        );

        expect(ndlNitrox, greaterThan(ndlAir));
      });
    });

    group('tissue loading', () {
      test('should reach the half-time midpoint after one half-time', () {
        final initialPN2 = algorithm.compartments.first.currentPN2;
        final inspiredN2At30m = calculateInspiredN2(4.0, airN2Fraction);

        algorithm.calculateSegment(
          depthMeters: 30.0,
          durationSeconds: 4 * 60, // Compartment 1 N2 half-time = 4 min
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final updatedPN2 = algorithm.compartments.first.currentPN2;
        final expectedMidpoint =
            initialPN2 + ((inspiredN2At30m - initialPN2) * 0.5);

        expect(updatedPN2, closeTo(expectedMidpoint, 0.0001));
      });

      test('should load tissues at constant depth', () {
        final initialStatus = algorithm.getDecoStatus(currentDepth: 0);
        final initialLoading = initialStatus.leadingCompartmentLoading;

        // Descend and stay at 30m for 10 minutes
        algorithm.calculateSegment(
          depthMeters: 15, // Average depth during descent
          durationSeconds: 60, // 1 minute descent
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        algorithm.calculateSegment(
          depthMeters: 30,
          durationSeconds: 10 * 60, // 10 minutes
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final finalStatus = algorithm.getDecoStatus(currentDepth: 30);
        expect(
          finalStatus.leadingCompartmentLoading,
          greaterThan(initialLoading),
        );
      });

      test('should offgas tissues at surface', () {
        // Load tissues at depth
        algorithm.calculateSegment(
          depthMeters: 30,
          durationSeconds: 20 * 60, // 20 minutes
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final loadedStatus = algorithm.getDecoStatus(currentDepth: 30);

        // Ascend to surface (using average depth)
        algorithm.calculateSegment(
          depthMeters: 15, // Average during ascent
          durationSeconds: 3 * 60, // 3 minute ascent
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        // Wait at surface for offgassing
        algorithm.calculateSegment(
          depthMeters: 0,
          durationSeconds: 10 * 60, // 10 minutes
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final offgassedStatus = algorithm.getDecoStatus(currentDepth: 0);
        expect(
          offgassedStatus.leadingCompartmentLoading,
          lessThan(loadedStatus.leadingCompartmentLoading),
        );
      });

      test(
        'should approach inspired nitrogen pressure after very long exposure',
        () {
          final inspiredN2At30m = calculateInspiredN2(4.0, airN2Fraction);

          algorithm.calculateSegment(
            depthMeters: 30.0,
            durationSeconds: 8000 * 60,
            fN2: airN2Fraction,
            fHe: 0.0,
          );

          for (int i = 0; i < algorithm.compartments.length; i++) {
            expect(
              algorithm.compartments[i].currentPN2,
              closeTo(inspiredN2At30m, 0.001),
              reason:
                  'Compartment ${i + 1} should converge to inspired nitrogen pressure',
            );
          }
        },
      );
    });

    group('ceiling calculation', () {
      test('should have zero ceiling at surface', () {
        final ceiling = algorithm.calculateCeiling();
        expect(ceiling, equals(0.0));
      });

      test('should calculate ceiling after deep dive', () {
        // Deep dive that should create deco obligation
        algorithm.calculateSegment(
          depthMeters: 22.5, // Average during descent
          durationSeconds: 90,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        algorithm.calculateSegment(
          depthMeters: 45,
          durationSeconds: 25 * 60, // 25 minutes
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final ceiling = algorithm.calculateCeiling(currentDepth: 45);
        final status = algorithm.getDecoStatus(currentDepth: 45);

        // After 25 min at 45m, we should be in deco
        expect(status.inDeco, isTrue);
        expect(ceiling, greaterThan(0));
      });
    });

    group('gradient factors', () {
      test('should calculate more conservative ceiling with lower GF', () {
        final conservativeAlgorithm = BuhlmannAlgorithm(
          gfLow: 0.30,
          gfHigh: 0.70,
        );

        final liberalAlgorithm = BuhlmannAlgorithm(gfLow: 0.70, gfHigh: 0.90);

        // Same dive for both
        void doDive(BuhlmannAlgorithm algo) {
          algo.calculateSegment(
            depthMeters: 40,
            durationSeconds: 15 * 60,
            fN2: airN2Fraction,
            fHe: 0.0,
          );
        }

        doDive(conservativeAlgorithm);
        doDive(liberalAlgorithm);

        // Conservative should have higher ceiling (deeper deco stop)
        final conservativeCeiling = conservativeAlgorithm.calculateCeiling(
          currentDepth: 40,
        );
        final liberalCeiling = liberalAlgorithm.calculateCeiling(
          currentDepth: 40,
        );

        expect(conservativeCeiling, greaterThanOrEqualTo(liberalCeiling));
      });
    });

    group('processProfile', () {
      test('should process a simple dive profile', () {
        final depths = [
          0.0,
          5.0,
          10.0,
          15.0,
          20.0,
          20.0,
          20.0,
          15.0,
          10.0,
          5.0,
          0.0,
        ];
        final timestamps = [0, 30, 60, 90, 120, 300, 600, 660, 720, 780, 840];

        final statuses = algorithm.processProfile(
          depths: depths,
          timestamps: timestamps,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        expect(statuses.length, equals(depths.length));
        expect(statuses.first.ceilingMeters, equals(0.0));
      });

      test('should track NDL decreasing during descent', () {
        // Descend to 30m over 3 minutes, stay for 10 minutes
        final depths = <double>[];
        final timestamps = <int>[];

        // Descent
        for (int t = 0; t <= 180; t += 10) {
          timestamps.add(t);
          depths.add(t / 6.0); // 10m per minute
        }

        // Bottom time
        for (int t = 190; t <= 780; t += 10) {
          timestamps.add(t);
          depths.add(30.0);
        }

        final statuses = algorithm.processProfile(
          depths: depths,
          timestamps: timestamps,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        // NDL should decrease over time at depth
        final bottomStatuses = statuses.skip(19).toList();
        if (bottomStatuses.length >= 2) {
          final firstBottomNdl = bottomStatuses.first.ndlSeconds;
          final lastBottomNdl = bottomStatuses.last.ndlSeconds;
          expect(lastBottomNdl, lessThan(firstBottomNdl));
        }
      });

      test(
        'processProfileWithGasSegments should match processProfile for a single gas',
        () {
          final depths = <double>[0.0, 15.0, 30.0, 30.0, 15.0, 6.0, 0.0];
          final timestamps = <int>[0, 60, 120, 1200, 1320, 1500, 1620];

          final singleGasAlgorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
          final gasAwareAlgorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

          final singleGasStatuses = singleGasAlgorithm.processProfile(
            depths: depths,
            timestamps: timestamps,
            fN2: airN2Fraction,
            fHe: 0.0,
          );

          final gasAwareStatuses = gasAwareAlgorithm
              .processProfileWithGasSegments(
                depths: depths,
                timestamps: timestamps,
                gasSegments: const [
                  ProfileGasSegment(
                    startTimestamp: 0,
                    fN2: airN2Fraction,
                    fHe: 0.0,
                  ),
                ],
              );

          expect(gasAwareStatuses.length, equals(singleGasStatuses.length));
          for (int i = 0; i < singleGasStatuses.length; i++) {
            expect(
              gasAwareStatuses[i].ndlSeconds,
              equals(singleGasStatuses[i].ndlSeconds),
              reason: 'NDL mismatch at index $i',
            );
            expect(
              gasAwareStatuses[i].ceilingMeters,
              closeTo(singleGasStatuses[i].ceilingMeters, 0.0001),
              reason: 'Ceiling mismatch at index $i',
            );
            expect(
              gasAwareStatuses[i].ttsSeconds,
              equals(singleGasStatuses[i].ttsSeconds),
              reason: 'TTS mismatch at index $i',
            );
          }
        },
      );

      test(
        'processProfileWithGasSegments should improve deco metrics after switching to EAN32',
        () {
          final depths = <double>[0.0, 15.0, 30.0, 30.0, 21.0, 12.0, 6.0, 0.0];
          final timestamps = <int>[0, 60, 120, 1200, 1320, 1440, 1560, 1680];

          final allAirAlgorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
          final switchedAlgorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

          final allAirStatuses = allAirAlgorithm.processProfile(
            depths: depths,
            timestamps: timestamps,
            fN2: airN2Fraction,
            fHe: 0.0,
          );

          final switchedStatuses = switchedAlgorithm
              .processProfileWithGasSegments(
                depths: depths,
                timestamps: timestamps,
                gasSegments: const [
                  ProfileGasSegment(
                    startTimestamp: 0,
                    fN2: airN2Fraction,
                    fHe: 0.0,
                  ),
                  ProfileGasSegment(startTimestamp: 1320, fN2: 0.68, fHe: 0.0),
                ],
              );

          expect(
            switchedStatuses.last.leadingCompartmentLoading,
            lessThan(allAirStatuses.last.leadingCompartmentLoading),
          );
          expect(
            switchedStatuses.last.ttsSeconds,
            lessThanOrEqualTo(allAirStatuses.last.ttsSeconds),
          );
          expect(
            switchedStatuses.last.ceilingMeters,
            lessThanOrEqualTo(allAirStatuses.last.ceilingMeters + 0.0001),
          );
        },
      );

      test(
        'processProfileWithGasSegments throws if first gas segment starts after profile start',
        () {
          final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

          expect(
            () => algorithm.processProfileWithGasSegments(
              depths: const [10.0, 10.0],
              timestamps: const [0, 60],
              gasSegments: const [
                ProfileGasSegment(
                  startTimestamp: 30,
                  fN2: airN2Fraction,
                  fHe: 0.0,
                ),
              ],
            ),
            throwsArgumentError,
          );
        },
      );

      test(
        'processProfileWithGasSegments applies in-interval gas switches at their exact timestamp',
        () {
          final sparseAlgorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
          final explicitBoundaryAlgorithm = BuhlmannAlgorithm(
            gfLow: 1.0,
            gfHigh: 1.0,
          );

          final sparseStatuses = sparseAlgorithm.processProfileWithGasSegments(
            depths: const [0.0, 30.0, 30.0],
            timestamps: const [0, 120, 1320],
            gasSegments: const [
              ProfileGasSegment(
                startTimestamp: 0,
                fN2: airN2Fraction,
                fHe: 0.0,
              ),
              ProfileGasSegment(startTimestamp: 720, fN2: 0.68, fHe: 0.0),
            ],
          );

          final explicitBoundaryStatuses = explicitBoundaryAlgorithm
              .processProfileWithGasSegments(
                depths: const [0.0, 30.0, 30.0, 30.0],
                timestamps: const [0, 120, 720, 1320],
                gasSegments: const [
                  ProfileGasSegment(
                    startTimestamp: 0,
                    fN2: airN2Fraction,
                    fHe: 0.0,
                  ),
                  ProfileGasSegment(startTimestamp: 720, fN2: 0.68, fHe: 0.0),
                ],
              );

          final sparseFinal = sparseStatuses.last;
          final explicitFinal = explicitBoundaryStatuses.last;

          expect(
            sparseFinal.leadingCompartmentLoading,
            closeTo(explicitFinal.leadingCompartmentLoading, 0.0001),
          );
          expect(
            sparseFinal.ceilingMeters,
            closeTo(explicitFinal.ceilingMeters, 0.0001),
          );
          expect(sparseFinal.ndlSeconds, equals(explicitFinal.ndlSeconds));
          expect(sparseFinal.ttsSeconds, equals(explicitFinal.ttsSeconds));
        },
      );
    });

    group('decompression schedule', () {
      test('should generate deco stops for saturated dive', () {
        // Do a dive that requires deco
        algorithm.calculateSegment(
          depthMeters: 45,
          durationSeconds: 30 * 60, // 30 minutes
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final stops = algorithm.calculateDecoSchedule(
          currentDepth: 45,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        expect(stops, isNotEmpty);
        // First stop should be deepest, last should be shallowest
        if (stops.length > 1) {
          expect(
            stops.first.depthMeters,
            greaterThanOrEqualTo(stops.last.depthMeters),
          );
        }
        // Last stop should typically be at 3-6m
        expect(stops.last.depthMeters, lessThanOrEqualTo(6.0));
      });

      test('should calculate TTS for deco dive', () {
        algorithm.calculateSegment(
          depthMeters: 45,
          durationSeconds: 30 * 60,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final tts = algorithm.calculateTts(currentDepth: 45);

        // TTS should include ascent time + stop times
        expect(tts, greaterThan(0));
        // TTS should be at least enough for 45m ascent at 9m/min
        expect(tts, greaterThanOrEqualTo((45 / 9 * 60).round()));
      });
    });

    group('reset', () {
      test('should reset tissues to surface saturation', () {
        // Load tissues
        algorithm.calculateSegment(
          depthMeters: 30,
          durationSeconds: 30 * 60,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final loadedStatus = algorithm.getDecoStatus(currentDepth: 30);
        expect(loadedStatus.leadingCompartmentLoading, greaterThan(50));

        // Reset
        algorithm.reset();

        // Should be back to surface saturation
        final resetStatus = algorithm.getDecoStatus(currentDepth: 0);
        expect(resetStatus.ceilingMeters, equals(0.0));
        expect(resetStatus.inDeco, isFalse);
      });
    });

    group('trimix support', () {
      test('should handle trimix gas', () {
        // Trimix 18/45 (18% O2, 45% He, 37% N2)
        const fN2 = 0.37;
        const fHe = 0.45;

        algorithm.calculateSegment(
          depthMeters: 60,
          durationSeconds: 20 * 60,
          fN2: fN2,
          fHe: fHe,
        );

        // Should have valid status with helium
        final status = algorithm.getDecoStatus(
          currentDepth: 60,
          fN2: fN2,
          fHe: fHe,
        );
        expect(status, isNotNull);
        expect(status.inDeco, isTrue);
      });
    });

    group('ZH-L16C coefficients', () {
      test('should have 16 compartments', () {
        expect(zhl16cN2HalfTimes.length, equals(16));
        expect(zhl16cHeHalfTimes.length, equals(16));
        expect(zhl16cN2A.length, equals(16));
        expect(zhl16cN2B.length, equals(16));
        expect(zhl16cHeA.length, equals(16));
        expect(zhl16cHeB.length, equals(16));
      });

      test('should have increasing half-times', () {
        for (int i = 1; i < zhl16cN2HalfTimes.length; i++) {
          expect(
            zhl16cN2HalfTimes[i],
            greaterThan(zhl16cN2HalfTimes[i - 1]),
            reason: 'N2 half-times should be in increasing order',
          );
        }
      });

      test('should have valid coefficient ranges', () {
        for (int i = 0; i < 16; i++) {
          expect(zhl16cN2HalfTimes[i], greaterThan(0));
          expect(zhl16cHeHalfTimes[i], greaterThan(0));
          expect(zhl16cN2A[i], greaterThan(0));
          expect(zhl16cN2B[i], greaterThan(0));
          expect(zhl16cN2B[i], lessThanOrEqualTo(1.0));
          expect(zhl16cHeA[i], greaterThan(0));
          expect(zhl16cHeB[i], greaterThan(0));
          expect(zhl16cHeB[i], lessThanOrEqualTo(1.0));
        }
      });

      test(
        'helium half-times should be approximately 2.65x faster than N2',
        () {
          for (int i = 0; i < 16; i++) {
            final ratio = zhl16cN2HalfTimes[i] / zhl16cHeHalfTimes[i];
            // Ratio should be approximately 2.65 (helium is ~2.65x faster)
            expect(ratio, closeTo(2.65, 0.1));
          }
        },
      );

      test(
        'should match surface M-value benchmarks for representative compartments',
        () {
          final comp1M0 = zhl16cN2A[0] + (1.0 / zhl16cN2B[0]);
          final comp4M0 = zhl16cN2A[3] + (1.0 / zhl16cN2B[3]);
          final comp16M0 = zhl16cN2A[15] + (1.0 / zhl16cN2B[15]);

          expect(comp1M0, closeTo(3.240098, 0.000001));
          expect(comp4M0, closeTo(2.034155, 0.000001));
          expect(comp16M0, closeTo(1.268647, 0.000001));
        },
      );
    });

    group('helper functions', () {
      test('air nitrogen fraction should use the normalized 0.7902 value', () {
        expect(airN2Fraction, closeTo(0.7902, 0.000001));
      });

      test('calculateAmbientPressure should be correct', () {
        expect(calculateAmbientPressure(0), equals(1.0));
        expect(calculateAmbientPressure(10), equals(2.0));
        expect(calculateAmbientPressure(20), equals(3.0));
        expect(calculateAmbientPressure(30), equals(4.0));
      });

      test('calculateDepthFromPressure should be inverse', () {
        expect(calculateDepthFromPressure(1.0), equals(0.0));
        expect(calculateDepthFromPressure(2.0), equals(10.0));
        expect(calculateDepthFromPressure(3.0), equals(20.0));
      });

      test('calculateInspiredN2 should account for water vapor', () {
        final inspiredN2 = calculateInspiredN2(1.0, airN2Fraction);
        // Should be less than straight ambient * fraction due to water vapor
        expect(inspiredN2, lessThan(airN2Fraction));
        expect(inspiredN2, greaterThan(0));
      });

      test(
        'calculateInspiredN2 should match the alveolar gas benchmark at the surface',
        () {
          final inspiredN2 = calculateInspiredN2(1.0, airN2Fraction);
          expect(inspiredN2, closeTo(0.74065446, 0.000001));
        },
      );

      test(
        'calculateInspiredN2 should scale linearly with nitrogen fraction',
        () {
          final inspiredAir = calculateInspiredN2(3.0, airN2Fraction);
          final inspiredEan50 = calculateInspiredN2(3.0, 0.5);

          expect(
            inspiredEan50 / inspiredAir,
            closeTo(0.5 / airN2Fraction, 0.0001),
          );
        },
      );
    });

    group('gas switching sanity', () {
      test(
        'switching to EAN50 at 6m should offgas faster than staying on air',
        () {
          final airAlgorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
          final ean50Algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

          final preloadedAir = airAlgorithm.compartments[4].copyWith(
            currentPN2: 2.5,
          );
          final preloadedEan50 = ean50Algorithm.compartments[4].copyWith(
            currentPN2: 2.5,
          );

          airAlgorithm.setCompartments([
            ...airAlgorithm.compartments.sublist(0, 4),
            preloadedAir,
            ...airAlgorithm.compartments.sublist(5),
          ]);
          ean50Algorithm.setCompartments([
            ...ean50Algorithm.compartments.sublist(0, 4),
            preloadedEan50,
            ...ean50Algorithm.compartments.sublist(5),
          ]);

          airAlgorithm.calculateSegment(
            depthMeters: 6.0,
            durationSeconds: 10 * 60,
            fN2: airN2Fraction,
            fHe: 0.0,
          );
          ean50Algorithm.calculateSegment(
            depthMeters: 6.0,
            durationSeconds: 10 * 60,
            fN2: 0.5,
            fHe: 0.0,
          );

          expect(
            ean50Algorithm.compartments[4].currentPN2,
            lessThan(airAlgorithm.compartments[4].currentPN2),
          );
        },
      );
    });

    group('30m air sanity profile', () {
      test(
        'compartment 5 should reach the expected pressure after 20 minutes at 30m',
        () {
          algorithm.calculateSegment(
            depthMeters: 30.0,
            durationSeconds: 20 * 60,
            fN2: airN2Fraction,
            fHe: 0.0,
          );

          expect(
            algorithm.compartments[4].currentPN2,
            closeTo(1.692612, 0.0001),
          );
        },
      );

      test('30m for 20 minutes on air should be in deco at GF 100/100', () {
        algorithm.calculateSegment(
          depthMeters: 30.0,
          durationSeconds: 20 * 60,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        final status = algorithm.getDecoStatus(
          currentDepth: 30.0,
          fN2: airN2Fraction,
          fHe: 0.0,
        );

        expect(status.inDeco, isTrue);
        expect(status.ceilingMeters, greaterThan(0.0));
      });
    });

    group('shallow recreational dive with conservative GF', () {
      // These tests verify that shallow recreational dives never incorrectly
      // show as deco dives, even with conservative gradient factors.
      // This was a bug where GF Low was being used for NDL checks instead of GF High.

      test(
        '12m dive on air should never show deco obligation with GF 30/70',
        () {
          final algorithm = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.70);

          // Simulate 25 minutes at 12m (longer than typical recreational dive)
          algorithm.calculateSegment(
            depthMeters: 12.0,
            durationSeconds: 25 * 60,
            fN2: airN2Fraction,
          );

          final status = algorithm.getDecoStatus(currentDepth: 12.0);

          // Should NOT be in deco - this is a shallow recreational dive
          expect(
            status.inDeco,
            isFalse,
            reason: '12m/25min dive should not be in deco even with GF 30/70',
          );
          expect(
            status.ndlSeconds,
            greaterThan(0),
            reason: 'NDL should be positive for 12m recreational dive',
          );
        },
      );

      test('processProfile for 12m/23min dive should never show deco', () {
        final algorithm = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.70);

        // Build profile similar to the Mosquito Pier dive that was showing
        // false deco after ~22 minutes
        final depths = <double>[];
        final timestamps = <int>[];

        // 2-second intervals, like the UDDF data
        for (int t = 0; t <= 23 * 60; t += 2) {
          timestamps.add(t);
          // Descent for first minute, then stay around 12m
          if (t < 60) {
            depths.add((t / 60.0) * 12.0); // Descend to 12m in 1 minute
          } else {
            depths.add(12.0);
          }
        }

        final statuses = algorithm.processProfile(
          depths: depths,
          timestamps: timestamps,
          fN2: airN2Fraction,
        );

        // No point should be in deco - verify ALL points
        for (int i = 0; i < statuses.length; i++) {
          expect(
            statuses[i].inDeco,
            isFalse,
            reason:
                'Point $i at ${timestamps[i]}s (${timestamps[i] ~/ 60}min) '
                'should not be in deco',
          );
          expect(
            statuses[i].ndlSeconds,
            greaterThan(0),
            reason:
                'NDL at point $i (${timestamps[i] ~/ 60}min) '
                'should be positive',
          );
        }
      });

      test('NDL at 12m should remain substantial even after 30 minutes', () {
        final algorithm = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.70);

        // After 30 min at 12m on air
        algorithm.calculateSegment(
          depthMeters: 12.0,
          durationSeconds: 30 * 60,
          fN2: airN2Fraction,
        );

        final ndl = algorithm.calculateNdl(
          depthMeters: 12.0,
          fN2: airN2Fraction,
        );

        // Even after 30 min at 12m, NDL should still be >30 min
        // (dive tables show 12m/40ft has NDL well over 100 min)
        expect(
          ndl,
          greaterThan(30 * 60),
          reason: 'NDL at 12m should remain substantial even after 30 min',
        );
      });

      test(
        'GF 30/70 should give shorter NDL than GF 100/100 but still positive',
        () {
          final conservativeAlgo = BuhlmannAlgorithm(gfLow: 0.30, gfHigh: 0.70);
          final liberalAlgo = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

          // Same dive for both: 20 min at 12m
          void doDive(BuhlmannAlgorithm algo) {
            algo.calculateSegment(
              depthMeters: 12.0,
              durationSeconds: 20 * 60,
              fN2: airN2Fraction,
            );
          }

          doDive(conservativeAlgo);
          doDive(liberalAlgo);

          final conservativeNdl = conservativeAlgo.calculateNdl(
            depthMeters: 12.0,
            fN2: airN2Fraction,
          );
          final liberalNdl = liberalAlgo.calculateNdl(
            depthMeters: 12.0,
            fN2: airN2Fraction,
          );

          // Both should be positive (not in deco)
          expect(
            conservativeNdl,
            greaterThan(0),
            reason: 'Conservative GF should still show positive NDL at 12m',
          );
          expect(
            liberalNdl,
            greaterThan(0),
            reason: 'Liberal GF should show positive NDL at 12m',
          );

          // Conservative should be shorter but still substantial
          expect(
            conservativeNdl,
            lessThanOrEqualTo(liberalNdl),
            reason: 'Conservative GF should have shorter or equal NDL',
          );
        },
      );
    });

    group('cumulative tissue loading', () {
      test('processProfile should use pre-loaded compartments', () {
        final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

        // Simulate dive 1: 30m for 20 minutes
        algorithm.calculateSegment(
          depthMeters: 30.0,
          durationSeconds: 20 * 60,
          fN2: airN2Fraction,
        );

        // Simulate 60 min surface interval
        algorithm.calculateSegment(
          depthMeters: 0.0,
          durationSeconds: 60 * 60,
          fN2: airN2Fraction,
        );
        final recoveredCompartments = algorithm.compartments;

        // Now create fresh algorithm and pre-load recovered state
        final dive2Algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
        dive2Algorithm.setCompartments(recoveredCompartments);

        // processProfile for dive 2 at 18m for 30 min
        final depths = <double>[];
        final timestamps = <int>[];
        for (int t = 0; t <= 30 * 60; t += 60) {
          timestamps.add(t);
          depths.add(18.0);
        }

        final statusesCumulative = dive2Algorithm.processProfile(
          depths: depths,
          timestamps: timestamps,
          fN2: airN2Fraction,
        );

        // Compare with fresh algorithm (no residual loading)
        final freshAlgorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);
        final statusesFresh = freshAlgorithm.processProfile(
          depths: depths,
          timestamps: timestamps,
          fN2: airN2Fraction,
        );

        // Cumulative dive should have SHORTER NDL than fresh dive
        final cumulativeNdl = statusesCumulative.last.ndlSeconds;
        final freshNdl = statusesFresh.last.ndlSeconds;

        expect(
          cumulativeNdl,
          lessThan(freshNdl),
          reason:
              'Repetitive dive should have shorter NDL due to residual loading',
        );
      });

      test(
        '48-hour surface interval should produce near-surface-saturated state',
        () {
          final algorithm = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

          // Deep dive: 40m for 20 minutes
          algorithm.calculateSegment(
            depthMeters: 40.0,
            durationSeconds: 20 * 60,
            fN2: airN2Fraction,
          );

          // 48 hours at surface
          algorithm.calculateSegment(
            depthMeters: 0.0,
            durationSeconds: 48 * 60 * 60,
            fN2: airN2Fraction,
          );

          final recovered = algorithm.compartments;

          // Create fresh surface-saturated algorithm
          final fresh = BuhlmannAlgorithm(gfLow: 1.0, gfHigh: 1.0);

          // All compartments should be within 1% of surface values
          for (int i = 0; i < 16; i++) {
            expect(
              recovered[i].currentPN2,
              closeTo(fresh.compartments[i].currentPN2, 0.01),
              reason:
                  'Compartment ${i + 1} should be near surface-saturated after 48h',
            );
          }
        },
      );
    });
  });
}
