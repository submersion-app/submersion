import 'dart:async';

import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_time_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_row.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_area_anchor_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/models/site_area_anchor.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// The header block's editor: its rows, the number rows' rule that the
/// number on show stands for the stored value, the linked times, the
/// profile suggestions and the planned switch (issue #4527, plan 4).
void main() {
  const imperial = AppSettings(
    depthUnit: DepthUnit.feet,
    temperatureUnit: TemperatureUnit.fahrenheit,
  );
  final entry = DateTime.utc(2026, 3, 9, 9, 42, 27);
  final exit = DateTime.utc(2026, 3, 9, 10, 34, 51);
  const reef = DiveSite(id: 'reef', name: 'Blue Corner', country: 'Palau');
  final full = Dive(
    id: 'dive',
    dateTime: entry,
    entryTime: entry,
    exitTime: exit,
    runtime: const Duration(minutes: 52, seconds: 24),
    bottomTime: const Duration(minutes: 41, seconds: 10),
    diveNumber: 214,
    name: 'Morning drift',
    site: reef,
    maxDepth: 12.41,
    avgDepth: 8.37,
    waterTemp: 27.4,
    rating: 4,
  );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<RecordEditController<Dive>> pumpEditor(
    WidgetTester tester,
    Dive dive, {
    AppSettings settings = const AppSettings(),
    Future<List<DiveDataSource>> Function()? sources,
    SiteAreaAnchorRepository? anchors,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(dive)
      ..openCard(diveHeaderCardId);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(
            settingsNotifier: MockSettingsNotifier(settings),
          ),
          if (sources != null)
            diveDataSourcesProvider(dive.id).overrideWith((ref) => sources()),
          if (anchors != null)
            siteAreaAnchorRepositoryProvider.overrideWithValue(anchors),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordEditScope<Dive>(
                controller: controller,
                child: Column(
                  children: [
                    DiveHeaderCardEditor(session: controller.session!),
                    const TextField(key: ValueKey('elsewhere')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold)));

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder.first).dy;

  /// Opens the resting row showing [resting] and types [steps], one
  /// growing prefix at a time.
  Future<void> type(
    WidgetTester tester,
    String resting,
    List<String> steps,
  ) async {
    await tester.tap(find.text(resting));
    await tester.pump();
    for (final text in steps) {
      await tester.enterText(find.byType(TextFormField).first, text);
      await tester.pump();
    }
  }

  Future<void> tapAway(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('elsewhere')));
    await tester.pump();
  }

  Dive working(RecordEditController<Dive> c) => c.session!.working;

  testWidgets('rows show in the order of the hero', (tester) async {
    await pumpEditor(tester, full);
    final l = l10nOf(tester);

    final order = [
      top(tester, find.text(l.diveLog_edit_label_diveNumber)),
      top(tester, find.text(l.diveLog_edit_label_diveName)),
      top(tester, find.byType(DiveSiteRow)),
      top(tester, find.text(l.diveLog_edit_row_entry)),
      top(tester, find.text(l.diveLog_edit_row_exit)),
      top(tester, find.text(l.diveLog_edit_section_rating)),
      top(tester, find.text(l.diveLog_diveMode_title)),
      top(tester, find.text(l.diveLog_edit_label_maxDepth)),
      top(tester, find.text(l.diveLog_edit_label_avgDepth)),
      top(tester, find.text(l.diveLog_edit_label_runtime)),
      top(tester, find.text(l.diveLog_edit_label_bottomTime)),
      top(tester, find.text(l.diveLog_edit_label_waterTemp)),
      top(tester, find.text(l.diveLog_bulkEdit_fieldFavorite)),
      top(tester, find.text(l.diveLog_edit_planned_switch)),
    ];
    expect(order, orderedEquals([...order]..sort()));
    expect(order.toSet(), hasLength(order.length));
  });

  for (final (name, settings) in [
    ('metric', const AppSettings()),
    ('imperial', imperial),
  ]) {
    testWidgets('$name: opening it and touching nothing leaves the sitting '
        'clean', (tester) async {
      final controller = await pumpEditor(tester, full, settings: settings);
      final l = l10nOf(tester);

      for (final label in [
        l.diveLog_edit_label_diveName,
        l.diveLog_edit_label_maxDepth,
        l.diveLog_edit_label_avgDepth,
        l.diveLog_edit_label_runtime,
        l.diveLog_edit_label_bottomTime,
        l.diveLog_edit_label_waterTemp,
      ]) {
        await tester.tap(find.text(label));
        await tester.pump();
        await tapAway(tester);
      }

      expect(controller.isDirty, isFalse);
    });
  }

  testWidgets('imperial: depths that show alike are told apart', (
    tester,
  ) async {
    final controller = await pumpEditor(tester, full, settings: imperial);

    await type(tester, '40.7 ft', ['4', '40', '40.', '40.8']);
    expect(working(controller).maxDepth, closeTo(12.436, 1e-3));

    for (final text in ['40.', '40.7']) {
      await tester.enterText(find.byType(TextFormField).first, text);
      await tester.pump();
    }
    expect(working(controller).maxDepth, 12.41);
    expect(controller.isDirty, isFalse);
  });

  testWidgets('a runtime typed digit by digit moves the exit; typed back, '
      'the exit is back', (tester) async {
    final controller = await pumpEditor(tester, full);

    await type(tester, '52 min', ['6', '60']);
    expect(working(controller).exitTime, entry.add(const Duration(hours: 1)));

    for (final text in ['5', '52']) {
      await tester.enterText(find.byType(TextFormField).first, text);
      await tester.pump();
    }
    expect(working(controller).exitTime, exit);
    expect(controller.isDirty, isFalse);
  });

  // Code review: the open card reads whole minutes as the hero and the
  // form do, so 43 min 40 s is 43 there too, and typing 43 changes nothing.
  testWidgets('times read in whole minutes, as the hero shows them', (
    tester,
  ) async {
    const runtime = Duration(minutes: 43, seconds: 40);
    final controller = await pumpEditor(
      tester,
      full.copyWith(
        runtime: runtime,
        exitTime: entry.add(runtime),
        bottomTime: const Duration(minutes: 41, seconds: 50),
      ),
    );

    expect(find.text('43 min'), findsOneWidget);
    expect(find.text('41 min'), findsOneWidget);

    await type(tester, '43 min', ['4', '43']);
    expect(controller.isDirty, isFalse);
  });

  // Final review, Important 2.
  testWidgets('a runtime emptied with backspace leaves the exit where it was', (
    tester,
  ) async {
    final controller = await pumpEditor(tester, full);

    await type(tester, '52 min', ['5', '']);

    expect(working(controller).runtime, isNull);
    expect(working(controller).exitTime, exit);
  });

  // Final review, Important 3: a plan is usually in the future.
  testWidgets('the entry of a dive dated next month can keep its date', (
    tester,
  ) async {
    final later = DateTime.now().toUtc().add(const Duration(days: 40));
    await pumpEditor(
      tester,
      full.copyWith(
        dateTime: later,
        entryTime: later,
        clearExitTime: true,
        isPlanned: true,
      ),
    );

    final row = tester.widget<DiveTimeRow>(find.byType(DiveTimeRow).first);
    expect(
      row.lastDate.isBefore(DateTime(later.year, later.month, later.day)),
      isFalse,
    );
  });

  group('profile suggestions', () {
    final profiled = full.copyWith(
      clearBottomTime: true,
      profile: [
        for (var s = 0; s <= 3600; s += 60)
          DiveProfilePoint(timestamp: s, depth: s == 0 || s == 3600 ? 0 : 15),
      ],
    );

    testWidgets('bottom time from the profile is offered, not stored', (
      tester,
    ) async {
      final controller = await pumpEditor(tester, profiled);
      final l = l10nOf(tester);

      expect(
        find.byTooltip(l.diveLog_edit_tooltip_calculateFromProfile),
        findsWidgets,
      );
      expect(controller.isDirty, isFalse);
      expect(working(controller).bottomTime, isNull);
    });

    testWidgets('the runtime suggestion moves the exit', (tester) async {
      final controller = await pumpEditor(tester, profiled);
      final l = l10nOf(tester);
      final runtimeRow = find.ancestor(
        of: find.text(l.diveLog_edit_label_runtime),
        matching: find.byType(Row),
      );

      await tester.tap(
        find.descendant(
          of: runtimeRow.first,
          matching: find.byTooltip(l.diveLog_edit_tooltip_calculateFromProfile),
        ),
      );
      await tester.pump();

      expect(working(controller).runtime, const Duration(hours: 1));
      expect(working(controller).exitTime, entry.add(const Duration(hours: 1)));
    });

    testWidgets('a dive with no profile is offered none', (tester) async {
      await pumpEditor(tester, full);
      final l = l10nOf(tester);
      expect(
        find.byTooltip(l.diveLog_edit_tooltip_calculateFromProfile),
        findsNothing,
      );
    });
  });

  group('planned', () {
    testWidgets('the number is hidden while planned, and the switch gives '
        'the stored number back', (tester) async {
      final controller = await pumpEditor(tester, full);
      final l = l10nOf(tester);
      final switchRow = find.byKey(const Key('dive_edit_planned_switch'));

      await tester.tap(
        find.descendant(of: switchRow, matching: find.byType(Switch)),
      );
      await tester.pump();
      expect(find.text(l.diveLog_edit_label_diveNumber), findsNothing);
      expect(working(controller).diveNumber, isNull);

      await tester.tap(
        find.descendant(of: switchRow, matching: find.byType(Switch)),
      );
      await tester.pump();
      expect(working(controller).diveNumber, 214);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('a stored plan shows a row that cannot be changed', (
      tester,
    ) async {
      await pumpEditor(tester, full.copyWith(isPlanned: true));
      expect(find.byKey(const Key('dive_edit_planned_switch')), findsNothing);
      expect(find.byType(Switch), findsOneWidget); // the favourite only
    });

    // PR review: the sources load after the card opens, and a dive whose
    // primary source is not yet known must not offer the switch meanwhile.
    testWidgets('while the dive\'s sources load there is no switch', (
      tester,
    ) async {
      final loading = Completer<List<DiveDataSource>>();
      await pumpEditor(tester, full, sources: () => loading.future);
      expect(find.byKey(const Key('dive_edit_planned_switch')), findsNothing);

      loading.complete(const []);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dive_edit_planned_switch')), findsOneWidget);
    });

    testWidgets('a dive with a primary source has no switch', (tester) async {
      final at = DateTime.utc(2026, 3, 9);
      await pumpEditor(
        tester,
        full,
        sources: () async => [
          DiveDataSource(
            id: 'src',
            diveId: full.id,
            isPrimary: true,
            importedAt: at,
            createdAt: at,
          ),
        ],
      );
      expect(find.byKey(const Key('dive_edit_planned_switch')), findsNothing);
    });

    testWidgets('a draft has no switch', (tester) async {
      await pumpEditor(tester, full.copyWith(isDraft: true));
      expect(find.byKey(const Key('dive_edit_planned_switch')), findsNothing);
    });
  });

  testWidgets('rating: tapping the current star clears it', (tester) async {
    final controller = await pumpEditor(tester, full);

    await tester.tap(find.byIcon(Icons.star).at(3));
    await tester.pump();

    expect(working(controller).rating, isNull);
  });

  testWidgets('favourite toggles', (tester) async {
    final controller = await pumpEditor(tester, full);
    final l = l10nOf(tester);
    final row = find.ancestor(
      of: find.text(l.diveLog_bulkEdit_fieldFavorite),
      matching: find.byType(Row),
    );

    await tester.tap(
      find.descendant(of: row.first, matching: find.byType(Switch)),
    );
    await tester.pump();

    expect(working(controller).isFavorite, isTrue);
  });

  testWidgets('clearing the site takes back what it set', (tester) async {
    final controller = await pumpEditor(tester, full.copyWith(clearSite: true));
    final session = controller.session!;
    readDiveSiteAssigner(tester.element(find.byType(DiveSiteRow)))(
      session,
      const DiveSite(id: 'salt', name: 'Reef', waterType: WaterType.salt),
    );
    await tester.pumpAndSettle();
    expect(session.valueOf(diveWaterTypeField), WaterType.salt);

    await tester.tap(
      find.descendant(
        of: find.byType(DiveSiteRow),
        matching: find.byTooltip(l10nOf(tester).common_action_remove),
      ),
    );
    await tester.pumpAndSettle();

    expect(working(controller).site, isNull);
    expect(session.valueOf(diveWaterTypeField), isNull);
  });

  // PR review: the area lookup runs before the picker opens, so a sitting
  // ended while it answers must open no picker.
  testWidgets('a sitting ended while the area loads opens no picker', (
    tester,
  ) async {
    final area = Completer<SiteAreaAnchor?>();
    final controller = await pumpEditor(
      tester,
      full.copyWith(clearSite: true, diverId: 'diver'),
      anchors: _HeldAnchors(area),
    );

    await tester.tap(find.text(l10nOf(tester).diveLog_edit_row_addSite));
    await tester.pump();
    controller.session!.freeze();
    area.complete(null);
    await tester.pumpAndSettle();

    expect(find.byType(SitePickerSheet), findsNothing);
  });

  testWidgets('the exit row shows the estimate for a dive with no exit', (
    tester,
  ) async {
    final controller = await pumpEditor(
      tester,
      full.copyWith(clearExitTime: true),
    );
    final row = tester.widget<DiveTimeRow>(find.byType(DiveTimeRow).last);
    expect(row.value, isNull);
    expect(row.hint, entry.add(const Duration(minutes: 52, seconds: 24)));
    expect(controller.isDirty, isFalse);
  });

  testWidgets('unreadable text marks the card', (tester) async {
    final controller = await pumpEditor(tester, full);

    await type(tester, '12.4 m', ['1.2.3']);

    expect(controller.invalidCardIds, {diveHeaderCardId});
    expect(controller.isDirty, isFalse);
  });

  testWidgets('a name arriving underneath is followed, and the caret stays '
      'put', (tester) async {
    final controller = await pumpEditor(tester, full);

    await tester.tap(find.text('Morning drift'));
    await tester.pump();
    final field = find.byType(TextFormField).first;
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    editable.controller.selection = const TextSelection.collapsed(offset: 2);
    controller.storedChanged(full.copyWith(name: 'Evening drift'));
    await tester.pump();

    expect(editable.controller.text, 'Evening drift');
    expect(editable.controller.selection.baseOffset, 2);
  });
}

/// An area lookup that answers when the test says.
class _HeldAnchors extends SiteAreaAnchorRepository {
  _HeldAnchors(this.answer);

  final Completer<SiteAreaAnchor?> answer;

  @override
  Future<SiteAreaAnchor?> forDive({
    required DateTime at,
    String? tripId,
    String? diverId,
    List<String> excludeDiveIds = const [],
  }) => answer.future;
}
