import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1609 — a new dive can seed its weighting from a past dive instead of
/// re-entering every belt weight by hand.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(WidgetTester tester, String diveId) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: diveId, embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gasGear = find.text('1 tank · Air').first;
    await tester.ensureVisible(gasGear);
    await tester.pumpAndSettle();
    await tester.tap(gasGear);
    await tester.pumpAndSettle();
  }

  testWidgets('copies the weight entries from a chosen dive, editable', (
    tester,
  ) async {
    await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 3, 1, 10),
        weights: const [
          DiveWeight(
            id: 'w1',
            diveId: '',
            weightType: WeightType.belt,
            amountKg: 3.0,
          ),
          DiveWeight(
            id: 'w2',
            diveId: '',
            weightType: WeightType.integrated,
            amountKg: 1.5,
          ),
        ],
      ),
    );
    final target = await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 3, 8, 10)),
    );

    await pumpEditor(tester, target.id);

    final copyRow = find.text('Copy weighting from a dive');
    await tester.ensureVisible(copyRow);
    await tester.pumpAndSettle();
    await tester.tap(copyRow);
    await tester.pumpAndSettle();

    // The source dive is listed with its two-entry summary; pick it.
    expect(find.text('2 weights · 4.5 kg'), findsOneWidget);
    await tester.tap(find.text('2 weights · 4.5 kg'));
    await tester.pumpAndSettle();

    // Both rows landed as ordinary editable weight fields (seeded in the
    // display unit at the page's usual precision).
    expect(find.widgetWithText(TextFormField, '3.0'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '1.5'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final reloaded = (await repository.getDiveById(target.id))!;
    expect(reloaded.weights, hasLength(2));
    expect(
      reloaded.weights.map((w) => w.amountKg).toList()..sort(),
      [1.5, 3.0],
    );
    // The copies are independent rows, not the originals.
    expect(reloaded.weights.map((w) => w.id), isNot(contains('w1')));
  });

  testWidgets('the copy row disappears once the dive has a weight entry', (
    tester,
  ) async {
    final target = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 3, 8, 10),
        weights: const [
          DiveWeight(
            id: 'w9',
            diveId: '',
            weightType: WeightType.belt,
            amountKg: 2.0,
          ),
        ],
      ),
    );

    await pumpEditor(tester, target.id);

    expect(find.text('Copy weighting from a dive'), findsNothing);
  });
}
