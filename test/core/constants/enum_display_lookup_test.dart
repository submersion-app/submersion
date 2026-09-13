import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enum_display_lookup.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  test('every export enum round trips through its display name', () {
    void check<T extends Enum>(List<T> values, String Function(T) name) {
      for (final v in values) {
        expect(enumByDisplayName(values, name, name(v)), v, reason: '$v');
      }
    }

    check(WaterType.values, (v) => v.displayName);
    check(EntryMethod.values, (v) => v.displayName);
    check(EquipmentType.values, (v) => v.displayName);
    check(Visibility.values, (v) => v.displayName);
    check(CurrentDirection.values, (v) => v.displayName);
    check(CloudCover.values, (v) => v.displayName);
    check(Precipitation.values, (v) => v.displayName);
  });

  test('matching ignores case and surrounding spaces', () {
    expect(
      enumByDisplayName(
        EntryMethod.values,
        (v) => v.displayName,
        ' boat entry ',
      ),
      EntryMethod.boat,
    );
  });

  test('the enum name is accepted as a fallback', () {
    expect(
      enumByDisplayName(
        EquipmentType.values,
        (v) => v.displayName,
        'firstStage',
      ),
      EquipmentType.firstStage,
    );
  });

  test('blank or unknown text is null', () {
    expect(
      enumByDisplayName(WaterType.values, (v) => v.displayName, ''),
      isNull,
    );
    expect(
      enumByDisplayName(WaterType.values, (v) => v.displayName, null),
      isNull,
    );
    expect(
      enumByDisplayName(WaterType.values, (v) => v.displayName, 'Lava'),
      isNull,
    );
  });
}
