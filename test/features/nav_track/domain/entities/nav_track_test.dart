import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

NavTrack _track({
  double? anchorLatitude,
  double? anchorLongitude,
  double? endLatitude,
  double? endLongitude,
  NavTrackEndMode endMode = NavTrackEndMode.none,
  double trustFraction = 0,
  double headingOffsetDeg = 0,
}) {
  return NavTrack(
    id: 'track-1',
    source: NavTrackSource.seacraftEnc,
    startTime: 1700000000,
    endTime: 1700003600,
    pointCount: 2,
    anchorLatitude: anchorLatitude,
    anchorLongitude: anchorLongitude,
    endMode: endMode,
    endLatitude: endLatitude,
    endLongitude: endLongitude,
    trustFraction: trustFraction,
    headingOffsetDeg: headingOffsetDeg,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('NavTrackSource', () {
    test('wireValue/fromWireValue round trip', () {
      for (final source in NavTrackSource.values) {
        expect(NavTrackSource.fromWireValue(source.wireValue), source);
      }
    });

    test('fromWireValue throws on an unrecognized value', () {
      expect(
        () => NavTrackSource.fromWireValue('garmin_route'),
        throwsArgumentError,
      );
    });

    test('label is human-readable per source', () {
      expect(NavTrackSource.seacraftEnc.label, 'Seacraft ENC');
      expect(NavTrackSource.suuntoRoute.label, 'Suunto route');
    });
  });

  group('NavTrackLinkMode', () {
    test('wireValue/fromWireValue round trip', () {
      for (final mode in NavTrackLinkMode.values) {
        expect(NavTrackLinkMode.fromWireValue(mode.wireValue), mode);
      }
    });

    test('fromWireValue(null) returns null', () {
      expect(NavTrackLinkMode.fromWireValue(null), isNull);
    });

    test('fromWireValue throws on an unrecognized value', () {
      expect(
        () => NavTrackLinkMode.fromWireValue('automatic'),
        throwsArgumentError,
      );
    });
  });

  group('NavTrackEndModeWire', () {
    test('wireValue/fromWireValue round trip', () {
      for (final mode in NavTrackEndMode.values) {
        expect(NavTrackEndModeWire.fromWireValue(mode.wireValue), mode);
      }
    });

    test('fromWireValue throws on an unrecognized value', () {
      expect(
        () => NavTrackEndModeWire.fromWireValue('unknown'),
        throwsArgumentError,
      );
    });
  });

  group('NavTrack.anchor', () {
    test('is null when either coordinate is missing', () {
      expect(_track().anchor, isNull);
      expect(_track(anchorLatitude: 47).anchor, isNull);
      expect(_track(anchorLongitude: 8).anchor, isNull);
    });

    test('is the GeoPoint when both coordinates are set', () {
      final anchor = _track(anchorLatitude: 47.1, anchorLongitude: 8.2).anchor;
      expect(anchor, const GeoPoint(47.1, 8.2));
    });
  });

  group('NavTrack.endPoint', () {
    test('is null when either coordinate is missing', () {
      expect(_track().endPoint, isNull);
      expect(_track(endLatitude: 47).endPoint, isNull);
      expect(_track(endLongitude: 8).endPoint, isNull);
    });

    test('is the GeoPoint when both coordinates are set', () {
      final endPoint = _track(endLatitude: 46.5, endLongitude: 7.5).endPoint;
      expect(endPoint, const GeoPoint(46.5, 7.5));
    });
  });

  group('NavTrack.correction', () {
    test('assembles anchor, end mode/point, trust and rotation', () {
      final track = _track(
        anchorLatitude: 47.1,
        anchorLongitude: 8.2,
        endMode: NavTrackEndMode.point,
        endLatitude: 46.5,
        endLongitude: 7.5,
        trustFraction: 0.4,
        headingOffsetDeg: 12.5,
      );
      final correction = track.correction;
      expect(correction.anchor, const GeoPoint(47.1, 8.2));
      expect(correction.endMode, NavTrackEndMode.point);
      expect(correction.endPoint, const GeoPoint(46.5, 7.5));
      expect(correction.trustFraction, 0.4);
      expect(correction.headingOffsetDeg, 12.5);
    });

    test('has null anchor/endPoint when coordinates are unset', () {
      final correction = _track().correction;
      expect(correction.anchor, isNull);
      expect(correction.endPoint, isNull);
      expect(correction.endMode, NavTrackEndMode.none);
      expect(correction.trustFraction, 0);
      expect(correction.headingOffsetDeg, 0);
    });
  });

  group('NavTrack.copyWith', () {
    test('overrides every field when a new value is given', () {
      final original = _track();
      final updated = original.copyWith(
        id: 'track-2',
        diveId: 'dive-1',
        linkMode: NavTrackLinkMode.manual,
        isPrimary: false,
        siteId: 'site-1',
        source: NavTrackSource.suuntoRoute,
        sourceRef: 'file.csv',
        deviceName: 'Seacraft ENC3',
        name: 'Morning dive',
        equipmentId: 'equip-1',
        startTime: 1,
        endTime: 2,
        tzOffsetMinutes: 60,
        timeOffsetSeconds: 30,
        pointCount: 5,
        totalDistance: 100,
        maxDepth: 20,
        maxSpeed: 1.5,
        avgSpeed: 0.5,
        anchorLatitude: 47.1,
        anchorLongitude: 8.2,
        endMode: NavTrackEndMode.sameAsStart,
        endLatitude: 46.5,
        endLongitude: 7.5,
        trustFraction: 0.5,
        headingOffsetDeg: 10,
        points: const [],
        createdAt: DateTime.utc(2026, 2, 2),
        updatedAt: DateTime.utc(2026, 2, 3),
      );

      expect(updated.id, 'track-2');
      expect(updated.diveId, 'dive-1');
      expect(updated.linkMode, NavTrackLinkMode.manual);
      expect(updated.isPrimary, false);
      expect(updated.siteId, 'site-1');
      expect(updated.source, NavTrackSource.suuntoRoute);
      expect(updated.sourceRef, 'file.csv');
      expect(updated.deviceName, 'Seacraft ENC3');
      expect(updated.name, 'Morning dive');
      expect(updated.equipmentId, 'equip-1');
      expect(updated.startTime, 1);
      expect(updated.endTime, 2);
      expect(updated.tzOffsetMinutes, 60);
      expect(updated.timeOffsetSeconds, 30);
      expect(updated.pointCount, 5);
      expect(updated.totalDistance, 100);
      expect(updated.maxDepth, 20);
      expect(updated.maxSpeed, 1.5);
      expect(updated.avgSpeed, 0.5);
      expect(updated.anchorLatitude, 47.1);
      expect(updated.anchorLongitude, 8.2);
      expect(updated.endMode, NavTrackEndMode.sameAsStart);
      expect(updated.endLatitude, 46.5);
      expect(updated.endLongitude, 7.5);
      expect(updated.trustFraction, 0.5);
      expect(updated.headingOffsetDeg, 10);
      expect(updated.createdAt, DateTime.utc(2026, 2, 2));
      expect(updated.updatedAt, DateTime.utc(2026, 2, 3));
    });

    test('keeps every field unchanged when called with no arguments', () {
      final original = _track(
        anchorLatitude: 47.1,
        anchorLongitude: 8.2,
        endMode: NavTrackEndMode.point,
        endLatitude: 46.5,
        endLongitude: 7.5,
        trustFraction: 0.4,
        headingOffsetDeg: 12.5,
      );
      expect(original.copyWith(), original);
    });

    test(
      'cannot null out a nullable field: passing null keeps the old value',
      () {
        final withDive = _track().copyWith(diveId: 'dive-1');
        // The `??` idiom used by copyWith cannot distinguish "leave
        // unchanged" from "clear this field" -- passing null is a no-op,
        // not a way to unlink. Callers that need to clear diveId must
        // construct a new NavTrack directly.
        final attemptedClear = withDive.copyWith(diveId: null);
        expect(attemptedClear.diveId, 'dive-1');

        // Demonstrate the actual limitation directly: copyWith(diveId: null)
        // is indistinguishable from copyWith() at the call site because
        // `diveId ?? this.diveId` falls back whenever the argument is null.
        final NavTrack attemptToClear = NavTrack(
          id: withDive.id,
          diveId: null,
          source: withDive.source,
          startTime: withDive.startTime,
          endTime: withDive.endTime,
          pointCount: withDive.pointCount,
          createdAt: withDive.createdAt,
          updatedAt: withDive.updatedAt,
        );
        expect(attemptToClear.diveId, isNull);
      },
    );
  });

  group('Equatable', () {
    test('two NavTracks with the same fields are equal', () {
      final a = _track(anchorLatitude: 47.1, anchorLongitude: 8.2);
      final b = _track(anchorLatitude: 47.1, anchorLongitude: 8.2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('NavTracks differing in one field are not equal', () {
      final a = _track(anchorLatitude: 47.1, anchorLongitude: 8.2);
      final b = _track(anchorLatitude: 47.2, anchorLongitude: 8.2);
      expect(a, isNot(b));
    });
  });
}
