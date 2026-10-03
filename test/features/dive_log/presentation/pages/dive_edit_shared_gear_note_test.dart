import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/shared_gear_overlap_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The dive editor notes gear that is also on another profile's
/// overlapping dive (issue #2853).
void main() {
  late DiveRepository repository;
  const mask = EquipmentItem(
    id: 'mask',
    name: 'Mask',
    type: EquipmentType.mask,
  );

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  testWidgets('a gear row on another profile overlapping dive says so', (
    tester,
  ) async {
    await EquipmentRepository().createEquipment(mask);
    final dive = await repository.createDive(
      Dive(
        id: 'dive-1',
        diveNumber: 1,
        dateTime: DateTime.utc(2026, 3, 28, 10, 0),
        notes: '',
        gear: looseGear(const [mask]),
      ),
    );
    final queries = <SharedGearOverlapQuery>[];
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          sharedGearOverlapProvider.overrideWith((ref, query) async {
            queries.add(query);
            return {
              'mask': (
                diverName: 'Anna',
                entry: DateTime.utc(2026, 3, 28, 10, 2),
              ),
            };
          }),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: dive.id, embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final summary = find.textContaining('1 item');
    await tester.ensureVisible(summary.first);
    await tester.pumpAndSettle();
    await tester.tap(summary.first);
    await tester.pumpAndSettle();

    expect(find.textContaining("Also on Anna's dive"), findsOneWidget);
    expect(queries, isNotEmpty);
    expect(queries.last.diveId, 'dive-1');
    expect(queries.last.entry, DateTime.utc(2026, 3, 28, 10));
  });
}
