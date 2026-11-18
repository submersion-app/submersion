import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_picker.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_mode_label.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_details_derived_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_visibility_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/suggested_text_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_assignment.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

const _cardId = 'details';

class _Courses extends StateNotifier<AsyncValue<List<Course>>>
    implements CourseListNotifier {
  _Courses(List<Course> courses) : super(AsyncValue.data(courses));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The Details card of the dive page, edited in place (issue #4527).
void main() {
  final l = AppLocalizationsEn();
  final epoch = DateTime(2024);
  final bare = Dive(id: 'dive', dateTime: DateTime.utc(2026, 3, 9, 10));
  final trip = Trip(
    id: 'trip',
    name: 'Red Sea North',
    startDate: DateTime(2026, 3, 7),
    endDate: DateTime(2026, 3, 14),
    createdAt: epoch,
    updatedAt: epoch,
  );
  final center = DiveCenter(
    id: 'center',
    name: 'Blue Hole Divers',
    createdAt: epoch,
    updatedAt: epoch,
  );
  final course = Course(
    id: 'c1',
    diverId: 'me',
    name: 'Wreck Diver',
    agency: 'padi',
    startDate: epoch,
    createdAt: epoch,
    updatedAt: epoch,
  );
  const saltSite = DiveSite(
    id: 'site',
    name: 'Blue Hole',
    waterType: WaterType.salt,
  );
  final full = bare.copyWith(
    diveTypeIds: const ['wreck', 'night'],
    trip: trip,
    tripId: trip.id,
    diveCenter: center,
    diveOperator: 'Emperor Divers',
    boatName: 'Emperor Elite',
    boatCaptain: 'Sam',
    courseIds: const ['c1'],
    visibilityMeters: 12.4,
    avgDepth: 18.2,
    waterType: WaterType.salt,
    gradientFactorLow: 30,
    gradientFactorHigh: 70,
    excludedFromGasStats: true,
  );
  const imperial = AppSettings(depthUnit: DepthUnit.feet);

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<RecordEditController<Dive>> pumpEditor(
    WidgetTester tester,
    Dive dive, {
    AppSettings settings = const AppSettings(),
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(dive)
      ..openCard(_cardId);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(
            settingsNotifier: MockSettingsNotifier(settings),
          ),
          courseListNotifierProvider.overrideWith((ref) => _Courses([course])),
          coursesForDiveProvider(dive.id).overrideWith((ref) async => const []),
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
                    DiveDetailsCardEditor(session: controller.session!),
                    const TextField(key: ValueKey('elsewhere')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return controller;
  }

  Dive working(RecordEditController<Dive> controller) =>
      controller.session!.working;

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder.first).dy;

  Finder switchOf(String key) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.byType(Switch));

  Switch toggle(WidgetTester tester, String key) =>
      tester.widget<Switch>(switchOf(key));

  /// The field of the free-text row at [index]: operator, boat, captain.
  /// These rows keep their field mounted, for their suggestions.
  Finder wordsField(int index) => find.descendant(
    of: find.byType(SuggestedTextRow).at(index),
    matching: find.byType(TextFormField),
  );

  group('the rows', () {
    testWidgets('show in the order of the read card', (tester) async {
      await pumpEditor(tester, full);

      final order = [
        top(tester, find.byType(DiveTypeMultiSelectField)),
        top(tester, find.text(l.diveLog_diveMode_title)),
        top(tester, find.byType(DiveTripRow)),
        top(tester, find.byType(DiveCenterRow)),
        top(tester, find.text(l.diveLog_edit_row_diveOperator)),
        top(tester, find.text(l.diveLog_edit_row_boatName)),
        top(tester, find.text(l.diveLog_edit_row_boatCaptain)),
        top(tester, find.byType(CourseMultiSelectField)),
        top(tester, find.byType(DiveVisibilityRow)),
        top(tester, find.text(l.diveLog_detail_label_avgDepth)),
        top(tester, find.text(l.diveLog_edit_label_waterType)),
        top(tester, find.byType(DiveDetailsDerivedRows)),
        top(tester, find.byType(FormOverline)),
        top(tester, find.byKey(const Key('dive-edit-exclude-from-stats'))),
        top(tester, find.byKey(const Key('dive-edit-exclude-from-gas-stats'))),
      ];
      expect(order, orderedEquals([...order]..sort()));
      expect(order.toSet(), hasLength(order.length));
    });

    for (final (name, settings) in [
      ('metric', const AppSettings()),
      ('imperial', imperial),
    ]) {
      testWidgets('opening a full dive and touching nothing is no change, '
          '$name', (tester) async {
        final controller = await pumpEditor(tester, full, settings: settings);

        // Into each text row and out again.
        for (final field in [
          wordsField(0),
          wordsField(1),
          wordsField(2),
          find.text(l.diveLog_edit_label_visibility),
        ]) {
          await tester.tap(field);
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('elsewhere')));
          await tester.pump();
        }

        expect(controller.isDirty, isFalse);
      });
    }

    testWidgets('opening a dive with nothing set is no change', (tester) async {
      final controller = await pumpEditor(
        tester,
        bare.copyWith(site: saltSite),
      );

      expect(controller.isDirty, isFalse);
      expect(working(controller).waterType, isNull);
    });
  });

  group('rows that cannot be typed in', () {
    testWidgets('dive mode is shown and not edited', (tester) async {
      await pumpEditor(tester, full.copyWith(diveMode: DiveMode.ccr));
      final mode = diveModeLabel(l, DiveMode.ccr);
      expect(find.text(mode), findsOneWidget);

      final fields = tester.widgetList(find.byType(TextFormField)).length;

      await tester.tap(find.text(mode));
      await tester.pump();

      // No field opened for it.
      expect(find.byType(TextFormField), findsNWidgets(fields));
    });

    testWidgets('average depth is shown in the diver\'s unit and not edited', (
      tester,
    ) async {
      await pumpEditor(tester, full, settings: imperial);
      const units = UnitFormatter(imperial);
      final depth = units.formatDepth(18.2);
      expect(find.text(depth), findsOneWidget);

      final fields = tester.widgetList(find.byType(TextFormField)).length;

      await tester.tap(find.text(depth));
      await tester.pump();

      // No field opened for it.
      expect(find.byType(TextFormField), findsNWidgets(fields));
    });

    testWidgets('a dive with no average depth has no such row', (tester) async {
      await pumpEditor(tester, bare);

      expect(find.text(l.diveLog_detail_label_avgDepth), findsNothing);
    });

    testWidgets('the rows nothing edits share one label column', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        full.copyWith(
          diveComputerModel: 'Perdix 2',
          surfaceInterval: const Duration(hours: 1),
        ),
      );

      double left(String text) => tester.getTopLeft(find.text(text)).dx;
      expect(left('Perdix 2'), left('GF 30/70'));
      expect(
        find.ancestor(
          of: find.byType(DiveDetailsDerivedRows),
          matching: find.byType(DetailRowGroup),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the rows nothing edits follow the sitting', (tester) async {
      await pumpEditor(tester, full);

      final derived = tester.widget<DiveDetailsDerivedRows>(
        find.byType(DiveDetailsDerivedRows),
      );
      expect(derived.dive.gradientFactorLow, 30);
      expect(find.text('GF 30/70'), findsOneWidget);
    });
  });

  group('dive types', () {
    testWidgets('the picker is offered the stored types', (tester) async {
      await pumpEditor(tester, full);

      final field = tester.widget<DiveTypeMultiSelectField>(
        find.byType(DiveTypeMultiSelectField),
      );
      expect(field.selectedTypeIds, ['wreck', 'night']);
      expect(field.keepTypeIds, ['wreck', 'night']);
    });

    // A type the site added and the diver unticked is theirs from then on,
    // even ticked again: the next site does not take it back (plan 4).
    testWidgets('a type the site added, unticked and ticked again, is the '
        'diver\'s', (tester) async {
      final controller = await pumpEditor(tester, full);
      final session = controller.session!;
      final resolver = AltitudeResolver(
        elevationService: ElevationService(
          client: MockClient((_) async => http.Response('', 500)),
        ),
      );
      void assign(DiveSite? site) => assignDiveSite(
        session,
        site,
        siteDiveTypeIds: (_) async => ['drift'],
        resolver: resolver,
        writeSiteAltitude: (_, _) async {},
      );
      DiveTypeMultiSelectField field() =>
          tester.widget<DiveTypeMultiSelectField>(
            find.byType(DiveTypeMultiSelectField),
          );

      assign(const DiveSite(id: 'drifty', name: 'Current point'));
      await tester.pump();
      expect(working(controller).diveTypeIds, ['wreck', 'night', 'drift']);

      field().onChanged(['wreck', 'night']);
      await tester.pump();
      field().onChanged(['wreck', 'night', 'drift']);
      await tester.pump();
      assign(null);
      await tester.pump();

      expect(working(controller).diveTypeIds, ['wreck', 'night', 'drift']);
    });

    testWidgets('changing them sets them in order', (tester) async {
      final controller = await pumpEditor(tester, full);

      tester
          .widget<DiveTypeMultiSelectField>(
            find.byType(DiveTypeMultiSelectField),
          )
          .onChanged(['night', 'drift']);
      await tester.pump();

      expect(working(controller).diveTypeIds, ['night', 'drift']);
      final field = tester.widget<DiveTypeMultiSelectField>(
        find.byType(DiveTypeMultiSelectField),
      );
      expect(field.selectedTypeIds, ['night', 'drift']);
      // Still the types the dive is stored with, so one can be put back.
      expect(field.keepTypeIds, ['wreck', 'night']);
    });
  });

  group('operator, boat and captain', () {
    final rows = <String, (int, String? Function(Dive))>{
      'operator': (0, (d) => d.diveOperator),
      'boat': (1, (d) => d.boatName),
      'captain': (2, (d) => d.boatCaptain),
    };

    testWidgets('the three rows are labelled, in that order', (tester) async {
      await pumpEditor(tester, bare);

      final labels = tester
          .widgetList<SuggestedTextRow>(find.byType(SuggestedTextRow))
          .map((row) => row.label)
          .toList();
      expect(labels, [
        l.diveLog_edit_row_diveOperator,
        l.diveLog_edit_row_boatName,
        l.diveLog_edit_row_boatCaptain,
      ]);
    });

    // Each row suggests what the diver typed there on earlier dives (the
    // old form's "Boat offers a boat from an earlier dive", #3229).
    testWidgets('each row suggests from its own field on earlier dives', (
      tester,
    ) async {
      await pumpEditor(tester, bare);

      final fields = tester
          .widgetList<SuggestedTextRow>(find.byType(SuggestedTextRow))
          .map((row) => row.field)
          .toList();
      expect(fields, [
        DiveTextSuggestionField.diveOperator,
        DiveTextSuggestionField.boatName,
        DiveTextSuggestionField.boatCaptain,
      ]);
    });

    for (final MapEntry(key: name, value: (index, read)) in rows.entries) {
      testWidgets('typing the $name sets it trimmed', (tester) async {
        final controller = await pumpEditor(tester, bare);

        await tester.enterText(wordsField(index), '  Aggressor ');
        await tester.pump();

        expect(read(working(controller)), 'Aggressor');
      });

      testWidgets('emptying the $name clears it', (tester) async {
        final controller = await pumpEditor(tester, full);

        await tester.enterText(wordsField(index), '');
        await tester.pump();

        expect(read(working(controller)), isNull);
        expect(controller.isDirty, isTrue);
      });
    }

    testWidgets('a value arriving underneath is followed, and the caret '
        'stays put', (tester) async {
      final controller = await pumpEditor(tester, full);
      await tester.tap(wordsField(0));
      await tester.pump();
      final field = tester.widget<EditableText>(
        find.descendant(of: wordsField(0), matching: find.byType(EditableText)),
      );
      field.controller.selection = const TextSelection.collapsed(offset: 2);

      controller.storedChanged(full.copyWith(diveOperator: 'Aggressor Fleet'));
      await tester.pump();

      expect(field.controller.text, 'Aggressor Fleet');
      expect(field.controller.selection.baseOffset, 2);
      expect(controller.isDirty, isFalse);
    });
  });

  group('courses', () {
    testWidgets('the picker shows the sitting\'s courses', (tester) async {
      await pumpEditor(tester, full);

      final field = tester.widget<CourseMultiSelectField>(
        find.byType(CourseMultiSelectField),
      );
      expect(field.selectedCourseIds, ['c1']);
    });

    testWidgets('choosing courses sets them', (tester) async {
      final controller = await pumpEditor(tester, bare);

      tester
          .widget<CourseMultiSelectField>(find.byType(CourseMultiSelectField))
          .onChanged(['c1']);
      await tester.pump();

      expect(working(controller).courseIds, ['c1']);
      expect(controller.isDirty, isTrue);
    });

    testWidgets('choosing none clears them', (tester) async {
      final controller = await pumpEditor(tester, full);

      tester
          .widget<CourseMultiSelectField>(find.byType(CourseMultiSelectField))
          .onChanged([]);
      await tester.pump();

      expect(working(controller).courseIds, isEmpty);
    });
  });

  group('water type', () {
    testWidgets('shows the dive\'s own value', (tester) async {
      await pumpEditor(tester, full.copyWith(waterType: WaterType.brackish));

      expect(find.text(WaterType.brackish.localizedName(l)), findsOneWidget);
    });

    testWidgets('with none of its own, the row hints the site\'s and the '
        'sitting has none', (tester) async {
      final controller = await pumpEditor(
        tester,
        bare.copyWith(site: saltSite),
      );

      expect(find.text(WaterType.salt.localizedName(l)), findsOneWidget);
      expect(controller.session!.valueOf(diveWaterTypeField), isNull);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('picking one sets it', (tester) async {
      final controller = await pumpEditor(
        tester,
        bare.copyWith(site: saltSite),
      );
      await tester.tap(find.text(l.diveLog_edit_label_waterType));
      await tester.pumpAndSettle();

      await tester.tap(find.text(WaterType.fresh.localizedName(l)));
      await tester.pumpAndSettle();

      expect(working(controller).waterType, WaterType.fresh);
    });

    testWidgets('clearing it goes back to the site\'s as a hint', (
      tester,
    ) async {
      final controller = await pumpEditor(
        tester,
        bare.copyWith(site: saltSite, waterType: WaterType.fresh),
      );
      await tester.tap(find.text(l.diveLog_edit_label_waterType));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l.diveLog_edit_notSpecified));
      await tester.pumpAndSettle();

      expect(working(controller).waterType, isNull);
      expect(find.text(WaterType.salt.localizedName(l)), findsOneWidget);
    });
  });

  group('the statistics switches', () {
    const master = 'dive-edit-exclude-from-stats';
    const gas = 'dive-edit-exclude-from-gas-stats';

    testWidgets('show what the dive has', (tester) async {
      await pumpEditor(tester, full);

      expect(toggle(tester, master).value, isFalse);
      expect(toggle(tester, gas).value, isTrue);
    });

    testWidgets('turning the master switch on sets it', (tester) async {
      final controller = await pumpEditor(tester, bare);

      await tester.tap(switchOf(master));
      await tester.pump();

      expect(working(controller).excludedFromStats, isTrue);
      expect(working(controller).excludedFromGasStats, isFalse);
    });

    testWidgets('with the master switch on, the gas switch shows on and '
        'cannot be changed', (tester) async {
      final controller = await pumpEditor(
        tester,
        bare.copyWith(excludedFromStats: true),
      );

      expect(toggle(tester, gas).value, isTrue);
      expect(toggle(tester, gas).onChanged, isNull);
      await tester.tap(switchOf(gas));
      await tester.pump();

      expect(controller.isDirty, isFalse);
    });

    testWidgets('turning the master switch off brings back a gas-only '
        'choice', (tester) async {
      final controller = await pumpEditor(tester, full);
      await tester.tap(switchOf(master));
      await tester.pump();
      expect(toggle(tester, gas).onChanged, isNull);

      await tester.tap(switchOf(master));
      await tester.pump();

      expect(toggle(tester, gas).value, isTrue);
      expect(toggle(tester, gas).onChanged, isNotNull);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('the gas switch sets its own flag', (tester) async {
      final controller = await pumpEditor(tester, bare);

      await tester.tap(switchOf(gas));
      await tester.pump();

      expect(working(controller).excludedFromGasStats, isTrue);
      expect(working(controller).excludedFromStats, isFalse);
    });
  });
}
