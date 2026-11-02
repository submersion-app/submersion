import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/database/database.dart' show DiveProfileEvent;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/experience_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Annotating a notes passage on the dive edit page (#4109): the pin wraps
/// the selection as a link at once, and the annotation row is written when
/// the dive is saved; a link removed from the notes takes its row with it.
void main() {
  late DiveRepository repository;
  late String? previousLocale;

  const profile = [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 600, depth: 30),
    DiveProfilePoint(timestamp: 1200, depth: 30),
    DiveProfilePoint(timestamp: 1800, depth: 0),
  ];

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    Intl.defaultLocale = previousLocale;
    await tearDownTestDatabase();
  });

  Future<Dive> seedDive({
    String notes = 'I felt sick today',
    bool withLength = true,
  }) => repository.createDive(
    Dive(
      id: 'dive-ann',
      dateTime: DateTime.utc(2026, 5, 3, 10),
      runtime: withLength ? const Duration(seconds: 1800) : null,
      profile: withLength ? profile : const [],
      notes: notes,
    ),
  );

  Future<void> pumpEditor(
    WidgetTester tester,
    String diveId, {
    void Function(String)? onSaved,
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(const AppSettings()),
    );
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
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Opens the Experience section and puts the Notes row into edit mode.
  Future<TextEditingController> openNotes(WidgetTester tester) async {
    await tester.tap(find.text('Experience').first, warnIfMissed: false);
    await tester.pumpAndSettle();
    final notesRow = find.descendant(
      of: find.byType(ExperienceSection),
      matching: find.text('Notes'),
    );
    await tester.tap(notesRow.first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownNotesField), findsOneWidget);
    return tester
        .widget<MarkdownNotesField>(find.byType(MarkdownNotesField))
        .controller;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  Future<List<DiveProfileEvent>> rows() async {
    final db = DatabaseService.instance.database;
    return (db.select(
      db.diveProfileEvents,
    )..where((t) => t.diveId.equals('dive-ann'))).get();
  }

  testWidgets(
    'annotating a selection records a pending annotation and the save '
    'reconciles it',
    (tester) async {
      final dive = await seedDive();
      String? savedId;
      await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);
      final controller = await openNotes(tester);
      controller.selection = const TextSelection(
        baseOffset: 7,
        extentOffset: 11,
      );
      await tester.tap(find.byTooltip('Annotate'));
      await tester.pumpAndSettle();
      expect(find.text('Annotate "sick"'), findsOneWidget);

      final time = find.descendant(
        of: find.byType(MinutesSecondsField),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(time, '10:30');
      await tester.tap(find.widgetWithText(FilledButton, 'Annotate'));
      await tester.pumpAndSettle();
      expect(controller.text, contains('[sick](annotation:'));
      expect(await rows(), isEmpty, reason: 'nothing is written before save');

      await save(tester);
      expect(savedId, isNotNull);
      final row = (await rows()).single;
      expect(
        (row.eventType, row.source, row.timestamp, row.description, row.depth),
        ('annotation', 'user', 630, 'sick', 30.0),
      );
      expect(controller.text, contains('[sick](annotation:${row.id})'));
    },
  );

  testWidgets('removing the link from the notes deletes the row on save', (
    tester,
  ) async {
    final db = DatabaseService.instance.database;
    final dive = await seedDive(notes: 'I [felt sick](annotation:a1) today');
    await db.customStatement(
      'INSERT INTO dive_profile_events '
      '(id, dive_id, timestamp, event_type, source, description, created_at) '
      "VALUES ('a1', 'dive-ann', 600, 'annotation', 'user', 'felt sick', 1)",
    );
    await pumpEditor(tester, dive.id);
    final controller = await openNotes(tester);
    controller.text = 'I felt sick today';
    await tester.pump();

    await save(tester);
    expect(await rows(), isEmpty);
  });

  testWidgets('a dive with no profile and no runtime still opens the sheet', (
    tester,
  ) async {
    final dive = await seedDive(withLength: false);
    await pumpEditor(tester, dive.id);
    final controller = await openNotes(tester);
    controller.selection = const TextSelection(baseOffset: 7, extentOffset: 11);
    await tester.tap(find.byTooltip('Annotate'));
    await tester.pumpAndSettle();
    expect(find.text('Annotate "sick"'), findsOneWidget);
    expect(
      find.text('This dive has no profile to point at. Type the time instead.'),
      findsOneWidget,
    );
  });
}
