import 'dart:async';

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

  test('keys the loaded dive types by id', () async {
    final night = type('night', 'Night');
    final custom = type('search_recovery', 'Search & Recovery');
    final container = ProviderContainer(
      overrides: [
        diveTypesProvider.overrideWith((ref) async => [night, custom]),
      ],
    );
    addTearDown(container.dispose);

    await container.read(diveTypesProvider.future);

    expect(container.read(diveTypesByIdProvider), {
      'night': night,
      'search_recovery': custom,
    });
  });

  test('is empty while the dive types load', () {
    final container = ProviderContainer(
      overrides: [
        diveTypesProvider.overrideWith(
          (ref) => Completer<List<DiveTypeEntity>>().future,
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(diveTypesByIdProvider), isEmpty);
  });
}
