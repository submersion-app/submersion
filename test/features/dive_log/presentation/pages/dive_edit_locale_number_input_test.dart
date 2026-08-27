import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Locale-aware numeric entry on the dive edit form (issue #1091).
///
/// The form seeds its fields from stored metric values and reads them back on
/// save. Both halves have to agree on what a decimal separator is: a diver in
/// fr must be able to type "12,5", and a diver in de must be able to open a
/// dive and save it untouched without the depth growing by a factor of ten
/// (under de, '.' is the GROUPING separator, so a "12.5" seed read through a
/// locale-aware parser is 125).
void main() {
  late DiveRepository repository;
  late String? previousLocale;

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    Intl.defaultLocale = previousLocale;
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
        // The UI stays English so English finders keep working; the pinned
        // Intl.defaultLocale is what governs number parsing.
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: diveId, embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the collapsed [FormRow.text] labelled [label] and types [text].
  Future<void> typeIntoRow(
    WidgetTester tester,
    String label,
    String text,
  ) async {
    final row = find
        .ancestor(of: find.text(label), matching: find.byType(FormRow))
        .first;
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: row, matching: find.byType(TextField)),
      text,
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('fr: a comma decimal typed into max depth is stored', (
    tester,
  ) async {
    Intl.defaultLocale = 'fr';

    final created = await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 4, 2, 9, 30)),
    );

    await pumpEditor(tester, created.id);
    await typeIntoRow(tester, 'Max Depth', '12,5');
    await tapSave(tester);

    final reloaded = (await repository.getDiveById(created.id))!;
    expect(reloaded.maxDepth, closeTo(12.5, 0.0001));
  });

  testWidgets('fr: a comma decimal typed into a weight entry is stored', (
    tester,
  ) async {
    Intl.defaultLocale = 'fr';

    final created = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 4, 2, 9, 30),
        weights: const [
          DiveWeight(
            id: 'w1',
            diveId: '',
            weightType: enums.WeightType.belt,
            amountKg: 0,
          ),
        ],
      ),
    );

    await pumpEditor(tester, created.id);

    // The weights list lives in the collapsed Gas & Gear group.
    final gasGear = find.text('1 tank · Air').first;
    await tester.ensureVisible(gasGear);
    await tester.pumpAndSettle();
    await tester.tap(gasGear);
    await tester.pumpAndSettle();

    final amountField = find
        .ancestor(of: find.text('kg'), matching: find.byType(TextFormField))
        .first;
    await tester.ensureVisible(amountField);
    await tester.pumpAndSettle();
    await tester.enterText(amountField, '2,5');
    await tester.pumpAndSettle();

    await tapSave(tester);

    final reloaded = (await repository.getDiveById(created.id))!;
    expect(reloaded.weights.single.amountKg, closeTo(2.5, 0.0001));
  });

  testWidgets('de: saving an untouched dive does not multiply its values', (
    tester,
  ) async {
    Intl.defaultLocale = 'de';

    // A tank makes the loaded form dirty, which is the realistic case: the
    // diver opens a dive, changes something elsewhere, and saves.
    final created = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 4, 2, 9, 30),
        maxDepth: 12.5,
        avgDepth: 8.5,
        swellHeight: 1.5,
        windSpeed: 3.5,
        tanks: const [DiveTank(id: 'tank-1', gasMix: GasMix())],
      ),
    );

    await pumpEditor(tester, created.id);
    await tapSave(tester);

    final reloaded = (await repository.getDiveById(created.id))!;
    // Each of these would be ten times larger if the seed wrote a '.' that the
    // locale-aware parser then read as a grouping separator.
    expect(reloaded.maxDepth, closeTo(12.5, 0.0001));
    expect(reloaded.avgDepth, closeTo(8.5, 0.0001));
    expect(reloaded.swellHeight, closeTo(1.5, 0.0001));
    expect(reloaded.windSpeed, closeTo(3.5, 0.0001));
  });

  testWidgets('de: an integer round trip survives an untouched save', (
    tester,
  ) async {
    Intl.defaultLocale = 'de';

    final created = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 4, 2, 9, 30),
        diveNumber: 1250,
        bottomTime: const Duration(minutes: 47),
        tanks: const [DiveTank(id: 'tank-1', gasMix: GasMix())],
      ),
    );

    await pumpEditor(tester, created.id);
    await tapSave(tester);

    final reloaded = (await repository.getDiveById(created.id))!;
    // 1250 must not come back as 1.250 -> 1 or as 1250000: seeding is done
    // without grouping separators and read back with parseUserInt.
    expect(reloaded.diveNumber, 1250);
    expect(reloaded.bottomTime, const Duration(minutes: 47));
  });
}
