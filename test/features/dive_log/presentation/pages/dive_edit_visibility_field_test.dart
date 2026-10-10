import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/edit_form_scaffold.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Pumps a bounded run of frames, for pages that never settle.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Dive buildDive({
    double? visibilityMeters,
    enums.Visibility? visibility,
    double? min,
    double? max,
  }) => Dive(
    id: 'dive-vis',
    diveNumber: 1,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    entryTime: DateTime(2026, 3, 28, 10, 5),
    bottomTime: const Duration(minutes: 40),
    maxDepth: 20.0,
    visibilityMeters: visibilityMeters,
    visibilityMinMeters: min,
    visibilityMaxMeters: max,
    visibility: visibility,
    tanks: const [],
    profile: const [],
    gear: looseGear(const []),
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  Future<void> pumpEditPage(
    WidgetTester tester,
    String? diveId, {
    String? rememberedMode,
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    if (rememberedMode != null) {
      // getBaseOverrides resets the mock prefs; seed after it, on the same
      // instance the provider reads.
      await (await SharedPreferences.getInstance()).setString(
        'dive_edit_visibility_input_mode',
        rememberedMode,
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
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
    if (diveId == null) {
      // A new-dive page hosts a continuous animation, so pumpAndSettle never
      // settles; bounded pumps drain the async work instead.
      await pumpFrames(tester);
    } else {
      await tester.pumpAndSettle();
    }
  }

  Future<void> expandConditions(WidgetTester tester) async {
    final header = find.text('Conditions');
    await tester.ensureVisible(header.first);
    await tester.pumpAndSettle();
    await tester.tap(header.first);
    await tester.pumpAndSettle();
  }

  /// Opens the collapsed visibility row and types [text] into it.
  Future<void> typeVisibility(WidgetTester tester, String text) async {
    final row = find
        .ancestor(of: find.text('Visibility'), matching: find.byType(FormRow))
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

  testWidgets('a measured dive shows the distance and its adjective', (
    tester,
  ) async {
    final created = await repository.createDive(
      buildDive(visibilityMeters: 6.0),
    );
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    // Collapsed FormRow.text renders "<value> <unit symbol>".
    expect(find.text('6 m'), findsOneWidget);
    // Default calibration is tropical, under which 6 m is Moderate. That is
    // exactly the complaint this feature exists to let divers fix.
    expect(find.text('Moderate'), findsOneWidget);
  });

  testWidgets('a 20 m dive reads Good under the default calibration', (
    tester,
  ) async {
    final created = await repository.createDive(
      buildDive(visibilityMeters: 20.0),
    );
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    expect(find.text('20 m'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget);
  });

  testWidgets('a legacy dive shows its band, not an adjective', (tester) async {
    final created = await repository.createDive(
      buildDive(visibility: enums.Visibility.moderate),
    );
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    // The bucket only says the dive fell somewhere in 5-15 m, so the caption
    // states the range rather than asserting a calibrated adjective.
    expect(find.text('5-15 m'), findsOneWidget);
  });

  testWidgets('a dive with no visibility shows no caption', (tester) async {
    final created = await repository.createDive(buildDive());
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);

    expect(find.text('Moderate'), findsNothing);
    expect(find.text('Good'), findsNothing);
    expect(find.text('Excellent'), findsNothing);
  });

  // The field has no input formatter, so stray characters reach the save
  // path. Unparseable text means visibility is unknown; storing 0 m would
  // record a measurement nobody took and bin the dive as Poor (#2076).
  testWidgets('unparseable visibility text saves as unknown, not 0 m', (
    tester,
  ) async {
    final created = await repository.createDive(buildDive());
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);
    await typeVisibility(tester, 'abc');
    await tapSave(tester);

    final reloaded = (await repository.getDiveById(created.id))!;
    expect(reloaded.visibilityMeters, isNull);
  });

  testWidgets('negative visibility text saves as unknown', (tester) async {
    final created = await repository.createDive(buildDive());
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);
    await typeVisibility(tester, '-5');
    await tapSave(tester);

    final reloaded = (await repository.getDiveById(created.id))!;
    expect(reloaded.visibilityMeters, isNull);
  });

  testWidgets('a valid visibility entry is stored in meters', (tester) async {
    final created = await repository.createDive(buildDive());
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);
    await typeVisibility(tester, '12');
    await tapSave(tester);

    final reloaded = (await repository.getDiveById(created.id))!;
    expect(reloaded.visibilityMeters, closeTo(12.0, 0.0001));
  });

  group('range input (issue #3226)', () {
    testWidgets('picking a band saves its range on the diver scale', (
      tester,
    ) async {
      final created = await repository.createDive(buildDive());
      await pumpEditPage(tester, created.id);
      await expandConditions(tester);
      await tester.tap(find.text('Range'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
      await tester.pumpAndSettle();
      // Default scale is tropical: Good is 15-30 m.
      expect(find.text('15-30 m'), findsOneWidget);
      await tapSave(tester);

      final saved = (await repository.getDiveById(created.id))!;
      expect(saved.visibilityMeters, isNull);
      expect(saved.visibilityRange, const VisibilityRange(minM: 15, maxM: 30));
    });

    testWidgets('a range dive opens in Range with its chip selected', (
      tester,
    ) async {
      final created = await repository.createDive(buildDive(min: 15, max: 30));
      await pumpEditPage(tester, created.id);
      await expandConditions(tester);
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Good'),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets(
      'an off-scale range shows itself and survives an untouched save',
      (tester) async {
        // Cold water Good, viewed under the default tropical scale.
        final created = await repository.createDive(buildDive(min: 6, max: 12));
        await pumpEditPage(tester, created.id);
        await expandConditions(tester);
        for (final chip in tester.widgetList<ChoiceChip>(
          find.byType(ChoiceChip),
        )) {
          expect(chip.selected, isFalse);
        }
        expect(find.text('6-12 m'), findsWidgets);
        await tapSave(tester);

        final saved = (await repository.getDiveById(created.id))!;
        expect(saved.visibilityRange, const VisibilityRange(minM: 6, maxM: 12));
      },
    );

    testWidgets('an untouched measured dive keeps its unrounded value', (
      tester,
    ) async {
      final created = await repository.createDive(
        buildDive(visibilityMeters: 6.44),
      );
      await pumpEditPage(tester, created.id);
      await tapSave(tester);
      expect(
        (await repository.getDiveById(created.id))!.visibilityMeters,
        6.44,
      );
    });

    testWidgets('an untouched legacy dive keeps its bucket', (tester) async {
      final created = await repository.createDive(
        buildDive(visibility: enums.Visibility.moderate),
      );
      await pumpEditPage(tester, created.id);
      await tapSave(tester);
      final saved = (await repository.getDiveById(created.id))!;
      expect(saved.visibility, enums.Visibility.moderate);
      expect(saved.visibilityRange, isNull);
    });

    testWidgets('a range survives a detour through Precise (review #1)', (
      tester,
    ) async {
      final created = await repository.createDive(buildDive(min: 15, max: 30));
      await pumpEditPage(tester, created.id);
      await expandConditions(tester);
      await tester.tap(find.text('Precise'));
      await tester.pumpAndSettle();
      await typeVisibility(tester, '8');
      await tester.tap(find.text('Range'));
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Good'),
      );
      expect(chip.selected, isTrue);
      await tapSave(tester);

      final saved = (await repository.getDiveById(created.id))!;
      expect(saved.visibilityRange, const VisibilityRange(minM: 15, maxM: 30));
      expect(saved.visibilityMeters, isNull);
    });

    testWidgets('picking a band arms the unsaved-changes guard (review #3)', (
      tester,
    ) async {
      final created = await repository.createDive(buildDive());
      await pumpEditPage(tester, created.id, rememberedMode: 'range');
      await expandConditions(tester);
      bool guarded() => tester
          .widget<EditFormScaffold>(find.byType(EditFormScaffold))
          .hasUnsavedChanges;
      expect(guarded(), isFalse);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
      await tester.pumpAndSettle();

      expect(guarded(), isTrue);
    });

    testWidgets('a new dive opens in the last-used mode', (tester) async {
      await pumpEditPage(tester, null, rememberedMode: 'range');
      final header = find.text('Conditions');
      await tester.ensureVisible(header.first);
      await pumpFrames(tester);
      await tester.tap(header.first);
      await pumpFrames(tester);
      expect(find.byType(ChoiceChip), findsNWidgets(4));
    });
  });
}
