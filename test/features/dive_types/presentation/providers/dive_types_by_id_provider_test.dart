import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';

void main() {
  DiveTypeEntity type(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('keys the diver\'s dive types by id once they load', () async {
    final night = type('night', 'Night');
    final custom = type('search_recovery', 'Search & Recovery');
    final container = ProviderContainer(
      overrides: [
        diveTypesProvider.overrideWith((ref) async => [night, custom]),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(diveTypesByIdProvider.future), {
      'night': night,
      'search_recovery': custom,
    });
  });

  group('diveTypesByIdOrEmpty', () {
    test('passes the loaded types through', () async {
      final night = type('night', 'Night');

      expect(await diveTypesByIdOrEmpty(Future.value({'night': night})), {
        'night': night,
      });
    });

    test('is empty when the lookup fails', () async {
      expect(
        await diveTypesByIdOrEmpty(Future.error(StateError('no database'))),
        isEmpty,
      );
    });
  });
}
