import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';

void main() {
  test('catalog keys are the stored, synced names', () {
    expect(
      {for (final c in BuiltInCatalog.values) c.name: c.key},
      {
        'diveTypes': 'diveTypes',
        'diveRoles': 'diveRoles',
        'siteTypes': 'siteTypes',
        'serviceKinds': 'serviceKinds',
        'preDiveTemplates': 'preDiveTemplates',
      },
    );
  });

  group('withBuiltInHidden', () {
    test('adds an id to an empty map', () {
      expect(
        withBuiltInHidden(const {}, BuiltInCatalog.diveRoles, 'solo', true),
        {
          'diveRoles': {'solo'},
        },
      );
    });

    test('removing the last id drops the catalog key', () {
      expect(
        withBuiltInHidden(
          const {
            'diveRoles': {'solo'},
          },
          BuiltInCatalog.diveRoles,
          'solo',
          false,
        ),
        isEmpty,
      );
    });

    test('leaves other catalogs, including unknown keys, untouched', () {
      final next = withBuiltInHidden(
        const {
          'siteTypes': {'lake'},
          'futureKind': {'x'},
        },
        BuiltInCatalog.diveTypes,
        'night',
        true,
      );
      expect(next, {
        'siteTypes': {'lake'},
        'futureKind': {'x'},
        'diveTypes': {'night'},
      });
    });

    test('returns the same map when nothing changes', () {
      const current = {
        'diveTypes': {'night'},
      };
      expect(
        identical(
          withBuiltInHidden(current, BuiltInCatalog.diveTypes, 'night', true),
          current,
        ),
        isTrue,
      );
    });

    test('does not mutate its input', () {
      final current = {
        'diveTypes': {'night'},
      };
      withBuiltInHidden(current, BuiltInCatalog.diveTypes, 'wreck', true);
      expect(current, {
        'diveTypes': {'night'},
      });
    });
  });
}
