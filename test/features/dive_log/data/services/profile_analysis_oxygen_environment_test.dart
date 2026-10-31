import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/gas_density.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Issue #3958: a logged dive's oxygen numbers and gas overlays are read from
/// the same water and surface pressure the decompression replay runs in.
void main() {
  final altitudeFresh = DiveEnvironment.forConditions(
    altitudeMeters: 3000,
    waterType: WaterType.fresh,
  );
  final salt = DiveEnvironment.forConditions(waterType: WaterType.salt);

  const depths = [35.0, 35.0, 35.0];
  const timestamps = [0, 300, 600];
  const ean36 = [ProfileGasSegment(startTimestamp: 0, fN2: 0.64)];

  ProfileAnalysis analyzeOc(
    DiveEnvironment environment, {
    List<ProfileGasSegment>? gasSegments = ean36,
  }) => ProfileAnalysisService(environment: environment).analyze(
    diveId: 'oc',
    depths: depths,
    timestamps: timestamps,
    o2Fraction: 0.36,
    gasSegments: gasSegments,
  );

  group('open circuit oxygen exposure', () {
    test('the issue reproduction reads its own selected site', () {
      final analysis = analyzeOc(altitudeFresh);

      expect(analysis.ppO2Curve, everyElement(closeTo(1.488029, 1e-6)));
      expect(analysis.o2Exposure.maxPpO2, closeTo(1.488029, 1e-6));
      expect(analysis.o2Exposure.cnsEnd, closeTo(8.091176, 1e-6));
      expect(analysis.o2Exposure.otu, closeTo(17.640041, 1e-6));
      expect(analysis.cnsCurve!.last, closeTo(8.091176, 1e-6));
      expect(analysis.otuCurve!.last, closeTo(17.640041, 1e-6));
    });

    test('the standard environment keeps the 1 bar, 10 m per bar model', () {
      final analysis = analyzeOc(DiveEnvironment.standard);

      expect(analysis.ppO2Curve, everyElement(closeTo(1.62, 1e-6)));
      expect(analysis.o2Exposure.cnsEnd, closeTo(22.222222, 1e-6));
      expect(analysis.o2Exposure.otu, closeTo(19.582735, 1e-6));
    });

    test('a dive with no gas schedule reads the same pressure', () {
      final analysis = analyzeOc(altitudeFresh, gasSegments: null);

      expect(analysis.ppO2Curve, everyElement(closeTo(1.488029, 1e-6)));
      expect(analysis.o2Exposure.maxPpO2, closeTo(1.488029, 1e-6));
      expect(analysis.o2Exposure.cnsEnd, closeTo(8.091176, 1e-6));
      expect(analysis.o2Exposure.otu, closeTo(17.640041, 1e-6));
      expect(analysis.cnsCurve!.last, closeTo(8.091176, 1e-6));
      expect(analysis.otuCurve!.last, closeTo(17.640041, 1e-6));
    });

    test('salt water reads deeper than the flat model', () {
      final ppO2 = salt.pressureAtDepth(35) * 0.36;

      expect(analyzeOc(salt).ppO2Curve, everyElement(closeTo(ppO2, 1e-9)));
      expect(ppO2, greaterThan(1.62));
    });

    test('a gas switch inside a sample interval is exposed in that water', () {
      const segments = [
        ProfileGasSegment(startTimestamp: 0, fN2: 0.64),
        ProfileGasSegment(startTimestamp: 300, fN2: 0.5),
      ];
      final analysis = ProfileAnalysisService(environment: altitudeFresh)
          .analyze(
            diveId: 'switch',
            depths: const [30.0, 30.0],
            timestamps: const [0, 600],
            o2Fraction: 0.36,
            gasSegments: segments,
          );

      expect(
        analysis.o2Exposure.maxPpO2,
        closeTo(altitudeFresh.pressureAtDepth(30) * 0.5, 1e-9),
      );
    });

    test('ppO2 events follow the selected site, not the flat model', () {
      final altitude = analyzeOc(altitudeFresh);
      final standard = analyzeOc(DiveEnvironment.standard);

      expect(standard.hadPpO2Critical, isTrue);
      expect(altitude.hadPpO2Critical, isFalse);
      expect(altitude.hadPpO2Warning, isTrue);
      bool flagsCritical(ProfileAnalysis analysis) => analysis.events.any(
        (e) =>
            e.eventType == ProfileEventType.ppO2High &&
            e.severity == EventSeverity.alert,
      );
      expect(flagsCritical(standard), isTrue);
      expect(flagsCritical(altitude), isFalse);
    });
  });

  group('rebreathers', () {
    final timestamps = [for (var t = 0; t <= 2400; t += 60) t];
    final depths = [for (final _ in timestamps) 21.0];
    const bailoutAt = 1200;
    final bailoutIndex = timestamps.indexOf(bailoutAt);
    const loop = ProfileGasSegment(startTimestamp: 0, fN2: 0.79, setpoint: 1.3);
    const bailout = ProfileGasSegment(startTimestamp: bailoutAt, fN2: 0.5);

    ProfileAnalysis analyzeCcr(List<ProfileGasSegment> segments) =>
        ProfileAnalysisService(environment: altitudeFresh).analyze(
          diveId: 'ccr',
          depths: depths,
          timestamps: timestamps,
          o2Fraction: 0.21,
          diveMode: DiveMode.ccr,
          setpointHigh: 1.3,
          gasSegments: segments,
          rebreatherPpO2Curve: List<double>.filled(timestamps.length, 1.3),
        );

    test('a bailout sample breathes its cylinder at the site pressure', () {
      final analysis = analyzeCcr(const [loop, bailout]);

      expect(analysis.ppO2Curve[bailoutIndex - 1], closeTo(1.3, 1e-9));
      expect(
        analysis.ppO2Curve[bailoutIndex],
        closeTo(altitudeFresh.pressureAtDepth(21) * 0.5, 1e-9),
      );
    });

    test('the loop ppN2 is the site ambient less the loop ppO2', () {
      final ambient = altitudeFresh.pressureAtDepth(21);
      final analysis = analyzeCcr(const [loop]);

      expect(analysis.ppN2Curve!.last, closeTo(ambient - 1.3, 1e-9));
    });

    test('the loop clamps its ppO2 to the site ambient near the surface', () {
      // 5 m is 1.5 bar on the flat model, which would leave 0.2 bar of inert
      // gas under a 1.3 setpoint. At this site it is under 1.3 bar.
      expect(altitudeFresh.pressureAtDepth(5), lessThan(1.3));
      final shallow = ProfileAnalysisService(environment: altitudeFresh)
          .analyze(
            diveId: 'ccr-shallow',
            depths: const [5.0, 5.0],
            timestamps: const [0, 60],
            o2Fraction: 0.21,
            diveMode: DiveMode.ccr,
            setpointHigh: 1.3,
            gasSegments: const [loop],
            rebreatherPpO2Curve: const [1.3, 1.3],
          );

      expect(shallow.ppN2Curve!.last, closeTo(0, 1e-9));
    });

    test('an SCR curve scales the loop FO2 by the site pressure', () {
      final fromFlat = ProfileAnalysisService().analyze(
        diveId: 'scr',
        depths: const [20.0, 20.0],
        timestamps: const [0, 60],
        diveMode: DiveMode.scr,
        scrInjectionRate: 10,
        scrSupplyO2Percent: 40,
      );
      final atSite = ProfileAnalysisService(environment: altitudeFresh).analyze(
        diveId: 'scr',
        depths: const [20.0, 20.0],
        timestamps: const [0, 60],
        diveMode: DiveMode.scr,
        scrInjectionRate: 10,
        scrSupplyO2Percent: 40,
      );

      final loopFo2 = fromFlat.ppO2Curve.first / 3.0;
      expect(
        atSite.ppO2Curve.first,
        closeTo(altitudeFresh.pressureAtDepth(20) * loopFo2, 1e-6),
      );
    });
  });

  group('gas overlays', () {
    const trimix = [ProfileGasSegment(startTimestamp: 0, fN2: 0.4, fHe: 0.3)];

    ProfileAnalysis analyzeTrimix(DiveEnvironment environment) =>
        ProfileAnalysisService(environment: environment).analyze(
          diveId: 'trimix',
          depths: depths,
          timestamps: timestamps,
          o2Fraction: 0.3,
          heFraction: 0.3,
          gasSegments: trimix,
        );

    test('ppN2 and ppHe read the site pressure', () {
      final ambient = altitudeFresh.pressureAtDepth(35);
      final analysis = analyzeTrimix(altitudeFresh);

      expect(analysis.ppN2Curve, everyElement(closeTo(ambient * 0.4, 1e-9)));
      expect(analysis.ppHeCurve, everyElement(closeTo(ambient * 0.3, 1e-9)));
    });

    test('gas density reads the site pressure', () {
      final density = gasDensityGPerL(
        fO2: 0.3,
        fHe: 0.3,
        ambientPressureBar: altitudeFresh.pressureAtDepth(35),
      );

      expect(
        analyzeTrimix(altitudeFresh).densityCurve,
        everyElement(closeTo(density, 1e-9)),
      );
    });

    test('the MOD line is the depth the gas reaches 1.4 bar at the site', () {
      final mod = maxOperatingDepthMeters(
        0.3,
        maxPpO2: 1.4,
        environment: altitudeFresh,
      );

      expect(
        analyzeTrimix(altitudeFresh).modCurve,
        everyElement(closeTo(mod, 1e-9)),
      );
      expect(mod, greaterThan(36.67));
    });
  });

  test('an analysis says which environment produced it', () {
    expect(analyzeOc(altitudeFresh).environment, altitudeFresh);
    expect(
      analyzeOc(DiveEnvironment.standard).environment.surfacePressureBar,
      1,
    );
    expect(
      ProfileAnalysisService(environment: altitudeFresh)
          .analyze(
            diveId: 'gauge',
            depths: depths,
            timestamps: timestamps,
            diveMode: DiveMode.gauge,
          )
          .environment,
      altitudeFresh,
    );
  });
}
