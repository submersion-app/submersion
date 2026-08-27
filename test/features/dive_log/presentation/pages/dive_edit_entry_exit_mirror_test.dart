import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// New-dive pages host a continuous animation, so pumpAndSettle never
/// settles; a bounded pump loop drains async work and animations instead.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The Conditions section is collapsed by default and its children are not
/// mounted while collapsed. The whole header row (including the label text)
/// is the toggle tap target.
Future<void> expandConditions(WidgetTester tester) async {
  final header = find.text('Conditions');
  await tester.scrollUntilVisible(
    header,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(header);
  await pumpFrames(tester);
}

/// Opens the EnumPickerRow labeled [rowLabel] and taps the sheet option
/// [optionText]. Sheet options are ListTiles; page rows are not, so
/// widgetWithText(ListTile, ...) cannot hit the row behind the sheet.
Future<void> pickMethod(
  WidgetTester tester,
  String rowLabel,
  String optionText,
) async {
  final row = find.text(rowLabel);
  await tester.scrollUntilVisible(
    row,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(row);
  await pumpFrames(tester);
  await tester.tap(find.widgetWithText(ListTile, optionText));
  await pumpFrames(tester);
}

void main() {
  group('DiveEditPage entry/exit mirroring (new dive)', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    List<dynamic> buildOverrides(List<dynamic> base) {
      return [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveListNotifierProvider.overrideWith((ref) {
          return DiveListNotifier(repository, ref);
        }),
        customTankPresetsProvider.overrideWith((ref) async => []),
      ];
    }

    Future<void> pumpNewDivePage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          overrides: buildOverrides(overrides),
          locale: const Locale('en'),
          child: const DiveEditPage(embedded: true),
        ),
      );
      await pumpFrames(tester);
    }

    testWidgets('selecting entry method fills exit method', (tester) async {
      await pumpNewDivePage(tester);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Shore Entry');

      // Entry row value + mirrored exit row value.
      expect(find.text('Shore Entry'), findsNWidgets(2));
    });

    testWidgets('exit follows subsequent entry changes while linked', (
      tester,
    ) async {
      await pumpNewDivePage(tester);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Shore Entry');
      await pickMethod(tester, 'Entry Method', 'Boat Entry');

      expect(find.text('Boat Entry'), findsNWidgets(2));
      expect(find.text('Shore Entry'), findsNothing);
    });

    testWidgets('touching exit breaks the link for the session', (
      tester,
    ) async {
      await pumpNewDivePage(tester);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Shore Entry');
      await pickMethod(tester, 'Exit Method', 'Ladder');
      await pickMethod(tester, 'Entry Method', 'Boat Entry');

      // Entry changed alone; exit kept its explicit value.
      expect(find.text('Boat Entry'), findsOneWidget);
      expect(find.text('Ladder'), findsOneWidget);
    });

    testWidgets('clearing entry while linked clears exit', (tester) async {
      await pumpNewDivePage(tester);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Shore Entry');
      await pickMethod(tester, 'Entry Method', 'Not specified');

      expect(find.text('Shore Entry'), findsNothing);
    });
  });

  group('DiveEditPage entry/exit mirroring (existing dive)', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    List<dynamic> buildOverrides(List<dynamic> base) {
      return [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveListNotifierProvider.overrideWith((ref) {
          return DiveListNotifier(repository, ref);
        }),
        customTankPresetsProvider.overrideWith((ref) async => []),
      ];
    }

    Dive buildDive({EntryMethod? entry, EntryMethod? exit}) => Dive(
      id: 'dive-entry-exit',
      diveNumber: 1,
      dateTime: DateTime(2026, 3, 28, 10, 0),
      entryTime: DateTime(2026, 3, 28, 10, 5),
      bottomTime: const Duration(minutes: 40),
      maxDepth: 20.0,
      entryMethod: entry,
      exitMethod: exit,
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );

    Future<void> pumpExistingDivePage(
      WidgetTester tester,
      String diveId,
    ) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          overrides: buildOverrides(overrides),
          locale: const Locale('en'),
          child: DiveEditPage(diveId: diveId, embedded: true),
        ),
      );
      // Existing-dive pages settle normally (no perpetual animation).
      await tester.pumpAndSettle();
    }

    testWidgets('equal saved values open linked: entry change updates both', (
      tester,
    ) async {
      final created = await repository.createDive(
        buildDive(entry: EntryMethod.shore, exit: EntryMethod.shore),
      );
      await pumpExistingDivePage(tester, created.id);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Boat Entry');

      expect(find.text('Boat Entry'), findsNWidgets(2));
      expect(find.text('Shore Entry'), findsNothing);
    });

    testWidgets('differing saved values open unlinked: exit stays put', (
      tester,
    ) async {
      final created = await repository.createDive(
        buildDive(entry: EntryMethod.giantStride, exit: EntryMethod.ladder),
      );
      await pumpExistingDivePage(tester, created.id);
      await expandConditions(tester);

      await pickMethod(tester, 'Entry Method', 'Boat Entry');

      expect(find.text('Boat Entry'), findsOneWidget);
      expect(find.text('Ladder'), findsOneWidget);
      expect(find.text('Giant Stride'), findsNothing);
    });

    testWidgets('untouched open-and-save never backfills an empty exit', (
      tester,
    ) async {
      final created = await repository.createDive(
        buildDive(entry: EntryMethod.shore, exit: null),
      );
      await pumpExistingDivePage(tester, created.id);
      await expandConditions(tester);

      // Exit row shows no value on load — only the entry row has one.
      expect(find.text('Shore Entry'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await repository.getDiveById(created.id);
      expect(saved!.entryMethod, EntryMethod.shore);
      expect(saved.exitMethod, isNull);
    });
  });
}
