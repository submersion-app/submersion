import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

import '../../../../helpers/test_database.dart';

/// The Set-time dialog's dive-wide shift reaches the dive through this
/// provider's wiring (issue #4539). Wired to nothing, the switch would save
/// and move no media, with nothing to say so.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  test("the pinner's dive shift is written to the dive", () async {
    final start = DateTime.utc(2026, 5, 6, 9, 4).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(start),
            createdAt: Value(start),
            updatedAt: Value(start),
          ),
        );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(mediaTimePinnerProvider).setDiveShift('d1', -47);

    expect(
      (await DiveRepository().getDiveById('d1'))!.mediaTimeOffsetSeconds,
      -47,
    );
  });
}
