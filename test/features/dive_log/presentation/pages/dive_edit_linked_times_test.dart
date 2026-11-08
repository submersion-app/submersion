import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #241: on the edit form the exit follows the entry, the runtime moves
/// the exit, and moving the exit shows its runtime. Drives the real form
/// against a real database so the assertions are on the stored row.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              onSaved: onSaved ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(FormRow)).first;

  Future<void> tapRow(WidgetTester tester, String label) async {
    await tester.ensureVisible(row(label));
    await tester.pumpAndSettle();
    await tester.tap(row(label));
    await tester.pumpAndSettle();
  }

  /// Picks [day] in the open date picker and keeps the time as it was.
  Future<void> pickDayKeepTime(WidgetTester tester, String day) async {
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text(day),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // date
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel')); // time
    await tester.pumpAndSettle();
  }

  /// The runtime the form shows; the row builds its text field only while
  /// it is being edited.
  String runtimeText(WidgetTester tester) =>
      tester.widget<FormRow>(row('Runtime')).controller!.text;

  Future<Dive> saveAndReload(WidgetTester tester, String id) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    return (await repository.getDiveById(id))!;
  }

  // A dive computer's times, seconds and all.
  final entry = DateTime.utc(2026, 1, 1, 10, 0, 50);
  final exit = DateTime.utc(2026, 1, 1, 10, 50, 10);
  const runtime = Duration(seconds: 2960);
  const bottomTime = Duration(seconds: 2409);

  testWidgets('moving the entry date moves the exit with it', (tester) async {
    await repository.createDive(
      Dive(
        id: 'dive-241-entry',
        dateTime: entry,
        entryTime: entry,
        exitTime: exit,
        bottomTime: bottomTime,
        runtime: runtime,
      ),
    );

    await pumpEditor(tester, 'dive-241-entry');
    await tapRow(tester, 'Entry');
    await pickDayKeepTime(tester, '3');

    expect(
      find.descendant(of: row('Exit'), matching: find.textContaining('3')),
      findsWidgets,
    );
    expect(runtimeText(tester), '49');

    final saved = await saveAndReload(tester, 'dive-241-entry');
    const shift = Duration(days: 2);
    expect(saved.entryTime, entry.add(shift));
    expect(saved.exitTime, exit.add(shift));
    expect(saved.runtime, runtime);
    expect(saved.bottomTime, bottomTime);
  });

  testWidgets('typing a runtime moves the exit to entry plus runtime', (
    tester,
  ) async {
    await repository.createDive(
      Dive(
        id: 'dive-241-runtime',
        dateTime: entry,
        entryTime: entry,
        exitTime: exit,
        bottomTime: bottomTime,
        runtime: runtime,
      ),
    );

    await pumpEditor(tester, 'dive-241-runtime');
    await tapRow(tester, 'Runtime');
    await tester.enterText(
      find.descendant(of: row('Runtime'), matching: find.byType(TextField)),
      '60',
    );
    await tester.pumpAndSettle();

    final saved = await saveAndReload(tester, 'dive-241-runtime');
    expect(saved.entryTime, entry);
    expect(saved.exitTime, entry.add(const Duration(minutes: 60)));
    expect(saved.runtime, const Duration(minutes: 60));
    expect(saved.bottomTime, bottomTime);
  });

  testWidgets('clearing the runtime puts the exit back where it was', (
    tester,
  ) async {
    // Backspacing "52" passes through "5"; the exit must not stay at entry
    // plus five minutes once the field is blank.
    await repository.createDive(
      Dive(
        id: 'dive-241-clear',
        dateTime: entry,
        entryTime: entry,
        exitTime: exit,
        bottomTime: bottomTime,
        runtime: runtime,
      ),
    );

    await pumpEditor(tester, 'dive-241-clear');
    await tapRow(tester, 'Runtime');
    final field = find.descendant(
      of: row('Runtime'),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '5');
    await tester.pumpAndSettle();
    await tester.enterText(field, '');
    await tester.pumpAndSettle();

    final saved = await saveAndReload(tester, 'dive-241-clear');
    expect(saved.entryTime, entry);
    expect(saved.exitTime, exit);
    expect(saved.runtime, runtime);
  });

  testWidgets('a runtime typed on a dive with no exit saves no exit', (
    tester,
  ) async {
    await repository.createDive(
      Dive(
        id: 'dive-241-estimate',
        dateTime: entry,
        entryTime: entry,
        runtime: runtime,
      ),
    );

    await pumpEditor(tester, 'dive-241-estimate');
    await tapRow(tester, 'Runtime');
    await tester.enterText(
      find.descendant(of: row('Runtime'), matching: find.byType(TextField)),
      '55',
    );
    await tester.pumpAndSettle();
    await tapRow(tester, 'Entry');
    await pickDayKeepTime(tester, '2');

    final saved = await saveAndReload(tester, 'dive-241-estimate');
    expect(saved.entryTime, entry.add(const Duration(days: 1)));
    expect(saved.exitTime, isNull);
    expect(saved.runtime, const Duration(minutes: 55));
  });

  testWidgets('moving the exit shows its runtime', (tester) async {
    final wholeEntry = DateTime.utc(2026, 1, 1, 10, 0);
    await repository.createDive(
      Dive(
        id: 'dive-241-exit',
        dateTime: wholeEntry,
        entryTime: wholeEntry,
        exitTime: DateTime.utc(2026, 1, 1, 10, 50),
        runtime: const Duration(minutes: 50),
      ),
    );

    await pumpEditor(tester, 'dive-241-exit');
    await tapRow(tester, 'Exit');
    await pickDayKeepTime(tester, '2');

    // A day and fifty minutes.
    expect(runtimeText(tester), '1490');

    final saved = await saveAndReload(tester, 'dive-241-exit');
    expect(saved.exitTime, DateTime.utc(2026, 1, 2, 10, 50));
    expect(saved.runtime, const Duration(minutes: 1490));
  });

  testWidgets('confirming an estimated exit shows its runtime', (tester) async {
    final wholeEntry = DateTime.utc(2026, 1, 1, 10, 0);
    await repository.createDive(
      Dive(
        id: 'dive-241-confirm',
        dateTime: wholeEntry,
        entryTime: wholeEntry,
        bottomTime: const Duration(minutes: 40),
      ),
    );

    await pumpEditor(tester, 'dive-241-confirm');
    expect(runtimeText(tester), isEmpty);

    await tapRow(tester, 'Exit');
    await tester.tap(find.text('OK')); // date
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // time
    await tester.pumpAndSettle();

    expect(runtimeText(tester), '40');
  });

  testWidgets('reopening the exit picker leaves a stored runtime alone', (
    tester,
  ) async {
    // The computer's runtime differs from exit minus entry; a picker
    // confirmed at the same minute must not overwrite it (issue #3901).
    await repository.createDive(
      Dive(
        id: 'dive-241-reopen',
        dateTime: entry,
        entryTime: entry,
        exitTime: exit,
        runtime: const Duration(minutes: 47),
      ),
    );

    await pumpEditor(tester, 'dive-241-reopen');
    await tapRow(tester, 'Exit');
    await tester.tap(find.text('OK')); // date
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // time
    await tester.pumpAndSettle();

    expect(runtimeText(tester), '47');
    final saved = await saveAndReload(tester, 'dive-241-reopen');
    expect(saved.runtime, const Duration(minutes: 47));
    expect(saved.exitTime, exit);
  });
}
