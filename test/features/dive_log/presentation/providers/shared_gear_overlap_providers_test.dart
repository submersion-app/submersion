import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/shared_gear_overlap_providers.dart';

void main() {
  test('one profile gives no notes without a query', () async {
    final t = DateTime(2026);
    final container = ProviderContainer(
      overrides: [
        allDiversProvider.overrideWith(
          (ref) async => [
            Diver(id: 'bill', name: 'Bill', createdAt: t, updatedAt: t),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(allDiversProvider.future);
    final notes = await container.read(
      sharedGearOverlapProvider((
        diveId: null,
        diverId: 'bill',
        entry: DateTime.utc(2026, 5, 1, 10),
        exit: DateTime.utc(2026, 5, 1, 10, 40),
      )).future,
    );
    expect(notes, isEmpty);
  });
}
