import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #3229: the editor shows and saves the dive's operator, boat,
/// captain and surface conditions, against a real database.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(
    WidgetTester tester,
    String diveId, {
    void Function(String)? onSaved,
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          // Pinned so the English finders below hold on any host locale.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens a collapsed group by tapping its header text.
  Future<void> expand(WidgetTester tester, String header) async {
    final finder = find.text(header).first;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder fieldOf(String label) => find.descendant(
    of: find.widgetWithText(SuggestionFormRow, label),
    matching: find.byType(TextFormField),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  Future<domain.Dive> createDive({String? boatName}) => repository.createDive(
    domain.Dive(
      id: '',
      dateTime: DateTime.utc(2026, 5, 1, 10),
      maxDepth: 20,
      boatName: boatName,
    ),
  );

  testWidgets('typing in the Trip group saves operator, boat and captain', (
    tester,
  ) async {
    final dive = await createDive();
    String? savedId;
    await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);

    await expand(tester, 'Trip');
    await tester.enterText(fieldOf('Operator'), 'Buddy Dive');
    await tester.enterText(fieldOf('Boat'), ' Bonaire Breeze ');
    await tester.enterText(fieldOf('Captain'), 'Rik');
    await tester.pumpAndSettle();
    await save(tester);

    expect(savedId, isNotNull);
    final saved = (await repository.getDiveById(dive.id))!;
    expect(saved.diveOperator, 'Buddy Dive');
    expect(saved.boatName, 'Bonaire Breeze', reason: 'trimmed on save');
    expect(saved.boatCaptain, 'Rik');
  });

  testWidgets('whitespace-only text clears the field to null', (tester) async {
    final dive = await createDive(boatName: 'Old boat');
    await pumpEditor(tester, dive.id);

    await expand(tester, 'Trip');
    expect(find.text('Old boat'), findsOneWidget, reason: 'loaded');
    await tester.enterText(fieldOf('Boat'), '   ');
    await tester.pumpAndSettle();
    await save(tester);

    expect((await repository.getDiveById(dive.id))!.boatName, isNull);
  });

  testWidgets('the Conditions group saves surface conditions', (tester) async {
    final dive = await createDive();
    await pumpEditor(tester, dive.id);

    await expand(tester, 'Conditions');
    await tester.enterText(fieldOf('Surface Conditions'), 'Choppy');
    await tester.pumpAndSettle();
    await save(tester);

    expect(
      (await repository.getDiveById(dive.id))!.surfaceConditions,
      'Choppy',
    );
  });

  testWidgets('an imported boat survives saving an unrelated edit', (
    tester,
  ) async {
    final dive = await createDive();
    await (db.update(db.dives)..where((t) => t.id.equals(dive.id))).write(
      const DivesCompanion(
        diveOperator: Value('Buddy Dive'),
        boatName: Value('Bonaire Breeze'),
        boatCaptain: Value('Rik'),
        surfaceConditions: Value('Choppy'),
      ),
    );
    await pumpEditor(tester, dive.id);

    final nameRow = find
        .ancestor(of: find.text('Name'), matching: find.byType(FormRow))
        .first;
    await tester.ensureVisible(nameRow);
    await tester.tap(nameRow);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: nameRow, matching: find.byType(TextField)),
      'Renamed',
    );
    await tester.pumpAndSettle();
    await save(tester);

    final saved = (await repository.getDiveById(dive.id))!;
    expect(saved.name, 'Renamed');
    expect(saved.diveOperator, 'Buddy Dive');
    expect(saved.boatName, 'Bonaire Breeze');
    expect(saved.boatCaptain, 'Rik');
    expect(saved.surfaceConditions, 'Choppy');
  });

  testWidgets('Boat offers a boat from an earlier dive', (tester) async {
    await createDive(boatName: 'Bonaire Breeze');
    final dive = await createDive();
    await pumpEditor(tester, dive.id);

    await expand(tester, 'Trip');
    await tester.enterText(fieldOf('Boat'), 'Bon');
    await tester.pumpAndSettle();

    expect(find.text('Bonaire Breeze'), findsOneWidget);
  });

  testWidgets('the collapsed Trip summary names the boat', (tester) async {
    final dive = await createDive(boatName: 'Bonaire Breeze');
    await pumpEditor(tester, dive.id);

    expect(find.textContaining('Bonaire Breeze'), findsOneWidget);
  });
}
