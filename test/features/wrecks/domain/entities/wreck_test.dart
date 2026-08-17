import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';

void main() {
  const base = Wreck(id: 'w-1', name: 'Hilma Hooker');

  test('known enum names decode; unknown ones survive as null', () {
    final typed = base.copyWith(
      vesselTypeName: 'ship',
      conditionName: 'broken',
      protectionName: 'warGrave',
      causeName: 'scuttled',
    );
    expect(typed.vesselType, WreckVesselType.ship);
    expect(typed.condition, WreckCondition.broken);
    expect(typed.protection, WreckProtection.warGrave);
    expect(typed.cause, WreckCause.scuttled);

    final future = base.copyWith(vesselTypeName: 'submersible');
    expect(future.vesselType, isNull);
    expect(future.vesselTypeName, 'submersible');
    // An unrelated edit preserves the unknown name.
    expect(future.copyWith(name: 'x').vesselTypeName, 'submersible');
  });

  test('hasCoordinates needs both halves', () {
    expect(base.hasCoordinates, isFalse);
    expect(base.copyWith(latitude: 12.15).hasCoordinates, isFalse);
    expect(
      base.copyWith(latitude: 12.15, longitude: -68.3).hasCoordinates,
      isTrue,
    );
  });

  test('copyWith clears nullables only via flags', () {
    final w = base.copyWith(
      siteId: 'site-1',
      latitude: 12.15,
      longitude: -68.3,
      depthToDeckMeters: 18,
      depthToSeabedMeters: 30,
      lengthMeters: 72,
    );
    expect(w.copyWith().siteId, 'site-1');
    expect(w.copyWith(clearSite: true).siteId, isNull);

    // Half a position is not a position: both halves clear together.
    expect(w.copyWith(clearCoordinates: true).latitude, isNull);
    expect(w.copyWith(clearCoordinates: true).longitude, isNull);

    // clearDepths touches the depths only; length is not a depth.
    final cleared = w.copyWith(clearDepths: true);
    expect(cleared.depthToDeckMeters, isNull);
    expect(cleared.depthToSeabedMeters, isNull);
    expect(cleared.lengthMeters, 72);
  });
}
