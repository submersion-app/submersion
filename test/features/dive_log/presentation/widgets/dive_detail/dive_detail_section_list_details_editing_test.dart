import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_details_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_environment_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_tide_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_signatures_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';
import 'dive_detail_section_list_harness.dart';

AppSettings _settings(
  List<DiveDetailSectionId> visible, {
  DiveDetailLayout layout = DiveDetailLayout.detailed,
  bool expanded = false,
}) => AppSettings(
  diveDetailSections: [
    // In the order given, so a test can put a card above Details.
    for (final id in visible)
      DiveDetailSectionConfig(id: id, visible: true, expanded: expanded),
    for (final id in DiveDetailSectionId.values)
      if (!visible.contains(id))
        DiveDetailSectionConfig(id: id, visible: false),
  ],
  diveDetailLayout: layout,
);

/// The Details card in the dive page's section list, and what holds still
/// around it while it is open (issue #4527).
///
/// The page hands the list the dive as the sitting holds it, and rebuilds
/// when the controller says a card changed. `repump` stands in for that.
void main() {
  final l = AppLocalizationsEn();
  late MockCurrentDiverIdNotifier diverIdNotifier;
  late SharedPreferences prefs;
  final plain = Dive(id: 'dive-1', dateTime: DateTime.utc(2026, 3, 15, 12));
  final atSea = plain.copyWith(
    site: const DiveSite(
      id: 'site-reykjavik',
      name: 'Reykjavik',
      location: GeoPoint(64.15, -21.95),
    ),
  );
  final tide = TideRecord(
    id: 'tide-1',
    diveId: 'dive-1',
    heightMeters: 1.6,
    tideState: TideState.rising,
    rateOfChange: 0.4,
    highTideHeight: 2.4,
    highTideTime: DateTime.utc(2026, 3, 15, 14),
    lowTideHeight: 0.4,
    lowTideTime: DateTime.utc(2026, 3, 15, 8),
    createdAt: DateTime.utc(2026, 3, 15, 12),
  );

  setUp(() async {
    await setUpTestDatabase();
    await DatabaseService.instance.database.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
    );
    // The visibility row opens in the input the device last used.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
  });
  tearDown(() async => tearDownTestDatabase());

  RecordEditController<Dive> controllerOver(Dive stored) {
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(stored);
    addTearDown(controller.dispose);
    return controller;
  }

  Widget harness({
    required Dive dive,
    required AppSettings settings,
    RecordEditController<Dive>? controller,
    Dive? tideFor,
    ReefHealth? satellite,
  }) {
    final list = sectionListFor(dive);
    return ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
        if (tideFor != null)
          healedTideRecordProvider((
            diveId: tideFor.id,
            location: tideFor.site!.location!,
            entryTime: tideFor.effectiveEntryTime,
          )).overrideWith((ref) async => tide),
        if (satellite != null) ...[
          reefHealthForDiveProvider.overrideWith(
            (ref, request) async => ReefPart.ok(satellite),
          ),
          reefHabitatProvider.overrideWith(
            (ref, location) async =>
                const ReefPart.ok(ReefHabitat(onReef: true)),
          ),
        ],
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: controller == null
                ? list
                : RecordEditScope<Dive>(controller: controller, child: list),
          ),
        ),
      ),
    );
  }

  void sizeTo(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 3200);
    addTearDown(tester.view.reset);
  }

  final editor = find.byType(DiveDetailsCardEditor);
  final detailsFrame = find.byWidgetPredicate(
    (w) => w is RecordCardFrame<Dive> && w.card.id == 'details',
  );

  bool tideShows(WidgetTester tester) =>
      tester.getSize(find.byType(DiveTideSection)).height > 0;

  group('the Details card', () {
    const visible = [DiveDetailSectionId.details];

    testWidgets('locked, it has no pencil', (tester) async {
      sizeTo(tester, 600);
      await tester.pumpWidget(
        harness(dive: plain, settings: _settings(visible)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveDetailsSection), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('unlocked, it has a pencil and opens where it sits', (
      tester,
    ) async {
      sizeTo(tester, 600);
      final controller = controllerOver(plain);
      await tester.pumpWidget(
        harness(
          dive: plain,
          settings: _settings(visible),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(detailsFrame);

      await tester.tap(find.byTooltip(l.recordEdit_editCardTooltip('Details')));
      await tester.pumpAndSettle();

      expect(editor, findsOneWidget);
      expect(tester.getTopLeft(detailsFrame), before);
    });

    testWidgets('hidden by the diver, it can be added and opens', (
      tester,
    ) async {
      sizeTo(tester, 600);
      final controller = controllerOver(plain);
      await tester.pumpWidget(
        harness(
          dive: plain,
          settings: _settings(const [DiveDetailSectionId.notes]),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      expect(detailsFrame, findsNothing);

      controller.addCard('details');
      await tester.pumpAndSettle();

      expect(editor, findsOneWidget);
    });

    testWidgets('in the folding layout its pencil opens it', (tester) async {
      sizeTo(tester, 600);
      final controller = controllerOver(plain);
      await tester.pumpWidget(
        harness(
          dive: plain,
          settings: _settings(visible, layout: DiveDetailLayout.list),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(l.recordEdit_editCardTooltip('Details')));
      await tester.pumpAndSettle();

      expect(editor, findsOneWidget);
    });

    testWidgets('at 1200 px it opens in its slot beside Environment', (
      tester,
    ) async {
      sizeTo(tester, 1200);
      final logged = plain.copyWith(airTemp: 21);
      final controller = controllerOver(logged);
      await tester.pumpWidget(
        harness(
          dive: logged,
          settings: _settings(const [
            DiveDetailSectionId.details,
            DiveDetailSectionId.environment,
          ]),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      final environment = find.byWidgetPredicate(
        (w) => w is RecordCardFrame<Dive> && w.card.id == 'environment',
      );
      final before = tester.getRect(detailsFrame);
      expect(tester.getRect(environment).top, before.top);

      controller.openCard('details');
      await tester.pumpAndSettle();

      expect(editor, findsOneWidget);
      final after = tester.getRect(detailsFrame);
      expect(after.topLeft, before.topLeft);
      expect(after.width, before.width);
      expect(tester.getRect(environment).top, after.top);
      expect(tester.getRect(environment).left, greaterThan(after.right - 1));
    });

    // Issue #4583: Notes, straight after the pair, moves up under its
    // shorter half. Opening its editor makes it taller than the space there;
    // it must not jump out from under the diver.
    testWidgets('a card that moved up beside the pair stays while edited', (
      tester,
    ) async {
      sizeTo(tester, 1200);
      // Enough conditions logged that Notes fits under Details closed, and
      // its open editor does not.
      final logged = plain.copyWith(
        airTemp: 21,
        windSpeed: 4,
        humidity: 70,
        surfacePressure: 1.013,
        notes: 'Calm.',
      );
      final controller = controllerOver(logged);
      await tester.pumpWidget(
        harness(
          dive: logged,
          settings: _settings(const [
            DiveDetailSectionId.details,
            DiveDetailSectionId.environment,
            DiveDetailSectionId.notes,
          ]),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      final notes = find.byWidgetPredicate(
        (w) => w is RecordCardFrame<Dive> && w.card.id == 'notes',
      );
      final before = tester.getRect(notes);
      // Half width: it sits in a column of the pair, not below it.
      expect(
        before.width,
        lessThan(tester.getSize(find.byType(Scaffold)).width / 2),
      );

      controller.openCard('notes');
      await tester.pumpAndSettle();

      final after = tester.getRect(notes);
      expect(after.left, before.left);
      expect(after.top, before.top);
      expect(after.width, before.width);
    });

    testWidgets('picking a type, a trip and a water type does not rebuild '
        'the editor', (tester) async {
      sizeTo(tester, 600);
      final controller = controllerOver(plain);
      final settings = _settings(visible);
      await tester.pumpWidget(
        harness(dive: plain, settings: settings, controller: controller),
      );
      controller.openCard('details');
      await tester.pumpAndSettle();
      final before = tester.state(editor);
      final session = controller.session!;

      session.set(diveTypeIdsField, <String>['wreck']);
      session.set(diveWaterTypeField, WaterType.fresh);
      session.set(diveCourseIdsField, <String>['c1']);
      await tester.pumpWidget(
        harness(
          dive: session.working,
          settings: settings,
          controller: controller,
        ),
      );
      await tester.pump();

      expect(identical(tester.state(editor), before), isTrue);
    });
  });

  group('while Details is open', () {
    testWidgets('switching to fresh water keeps the Tide card until Save', (
      tester,
    ) async {
      sizeTo(tester, 600);
      final controller = controllerOver(atSea);
      final settings = _settings(const [
        DiveDetailSectionId.tide,
        DiveDetailSectionId.details,
      ]);
      Future<void> repump() async {
        await tester.pumpWidget(
          harness(
            dive: controller.session!.working,
            settings: settings,
            controller: controller,
            tideFor: atSea,
          ),
        );
        await tester.pumpAndSettle();
      }

      await repump();
      expect(tideShows(tester), isTrue);
      controller.openCard('details');
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(editor).dy;

      controller.session!.set(diveWaterTypeField, WaterType.fresh);
      await repump();

      expect(tideShows(tester), isTrue);
      expect(tester.getTopLeft(editor).dy, top);

      // The Tide card has no editor: it shows the dive as stored until
      // the sitting is saved (plan 4).
      controller.closeCard('details');
      await repump();

      expect(tideShows(tester), isTrue);
    });

    testWidgets('the Surface GPS and Tide pair does not split until Save', (
      tester,
    ) async {
      sizeTo(tester, 1200);
      final controller = controllerOver(atSea);
      final settings = _settings(const [
        DiveDetailSectionId.surfaceGps,
        DiveDetailSectionId.tide,
        DiveDetailSectionId.details,
      ]);
      Future<void> repump() async {
        await tester.pumpWidget(
          harness(
            dive: controller.session!.working,
            settings: settings,
            controller: controller,
            tideFor: atSea,
          ),
        );
        await tester.pumpAndSettle();
      }

      final pair = find.byKey(const ValueKey('diveSectionPair_surfaceGps'));
      await repump();
      expect(pair, findsOneWidget);
      controller.openCard('details');
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(editor).dy;

      controller.session!.set(diveWaterTypeField, WaterType.fresh);
      await repump();

      expect(pair, findsOneWidget);
      expect(tester.getTopLeft(editor).dy, top);

      controller.closeCard('details');
      await repump();

      expect(pair, findsOneWidget);
    });

    // The Environment card carries satellite water conditions, which a
    // freshwater dive has none of. Nothing is logged on these dives, so the
    // satellite lines are all the card holds.
    group('fresh water and the satellite conditions', () {
      final atReef = plain.copyWith(
        site: const DiveSite(
          id: 'site',
          name: 'Coral Garden',
          location: GeoPoint(-16.5, 145.8),
          waterType: WaterType.salt,
        ),
      );
      final health = ReefHealth(
        sst: 30.1,
        sstAnomaly: 0.8,
        degreeHeatingWeeks: 4.2,
        alertLevel: BleachingAlertLevel.watch,
        observedAt: DateTime.utc(2023, 9, 1, 12),
      );
      final environment = find.byType(DiveEnvironmentSection);

      testWidgets('beside Details, the card keeps its lines until Save', (
        tester,
      ) async {
        sizeTo(tester, 1200);
        final controller = controllerOver(atReef);
        final settings = _settings(const [
          DiveDetailSectionId.details,
          DiveDetailSectionId.environment,
        ]);
        Future<void> repump() async {
          await tester.pumpWidget(
            harness(
              dive: controller.session!.working,
              settings: settings,
              controller: controller,
              satellite: health,
            ),
          );
          await tester.pumpAndSettle();
        }

        // Its lines, not its height: beside Details it grows to the open
        // editor's height (issue #4583).
        List<String?> lines() => [
          for (final text in tester.widgetList<Text>(
            find.descendant(of: environment, matching: find.byType(Text)),
          ))
            text.data,
        ];

        await repump();
        final before = lines();
        expect(before, isNotEmpty);
        controller.openCard('details');
        await tester.pumpAndSettle();

        controller.session!.set(diveWaterTypeField, WaterType.fresh);
        await repump();

        expect(lines(), before);

        controller.closeCard('details');
        await repump();

        // The satellite lines are worked out from the dive as stored until
        // the sitting is saved (plan 4), so the card stays.
        expect(environment, findsOneWidget);
      });

      testWidgets('above Details in the folding layout, the editor does not '
          'move', (tester) async {
        sizeTo(tester, 600);
        final controller = controllerOver(atReef);
        final settings = _settings(
          const [DiveDetailSectionId.environment, DiveDetailSectionId.details],
          layout: DiveDetailLayout.list,
          expanded: true,
        );
        Future<void> repump() async {
          await tester.pumpWidget(
            harness(
              dive: controller.session!.working,
              settings: settings,
              controller: controller,
              satellite: health,
            ),
          );
          await tester.pumpAndSettle();
        }

        await repump();
        final height = tester.getSize(environment).height;
        controller.openCard('details');
        await tester.pumpAndSettle();
        final top = tester.getTopLeft(editor).dy;

        controller.session!.set(diveWaterTypeField, WaterType.fresh);
        await repump();

        expect(tester.getSize(environment).height, height);
        expect(tester.getTopLeft(editor).dy, top);
      });
    });

    testWidgets('adding a first course keeps Signatures as it was until '
        'the editors close', (tester) async {
      sizeTo(tester, 600);
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO courses (id, diver_id, name, agency, start_date, "
        "created_at, updated_at) VALUES ('c1', 'diver-1', 'Wreck Diver', "
        "'padi', 0, 0, 0)",
      );
      final controller = controllerOver(plain);
      // What the page reads as a sitting starts (plan 6).
      await tester.runAsync(() async {
        await diveBuddiesList.load(controller.session!);
        await diveSignaturesList.load(controller.session!);
      });
      final settings = _settings(const [
        DiveDetailSectionId.signatures,
        DiveDetailSectionId.details,
      ]);
      Future<void> repump() async {
        await tester.pumpWidget(
          harness(
            dive: controller.session!.working,
            settings: settings,
            controller: controller,
          ),
        );
        await tester.pumpAndSettle();
      }

      final training = find.text(l.diveLog_detail_section_trainingSignature);
      await repump();
      expect(training, findsNothing);
      controller.openCard('details');
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(editor).dy;

      controller.session!.set(diveCourseIdsField, <String>['c1']);
      await repump();

      expect(training, findsNothing);
      expect(tester.getTopLeft(editor).dy, top);

      controller.closeCard('details');
      await repump();

      // Signatures has an editor since plan 6: once the editors close it
      // shows the sitting's course, as any card that gained a value does.
      expect(training, findsOneWidget);
    });

    testWidgets('the Buddies and Signatures pair does not form until Save', (
      tester,
    ) async {
      sizeTo(tester, 1200);
      final controller = controllerOver(plain);
      final settings = _settings(const [
        DiveDetailSectionId.buddies,
        DiveDetailSectionId.signatures,
        DiveDetailSectionId.details,
      ]);
      Future<void> repump() async {
        await tester.pumpWidget(
          harness(
            dive: controller.session!.working,
            settings: settings,
            controller: controller,
          ),
        );
        await tester.pumpAndSettle();
      }

      final pair = find.byKey(const ValueKey('diveSectionPair_buddies'));
      await repump();
      expect(pair, findsNothing);
      controller.openCard('details');
      await tester.pumpAndSettle();

      controller.session!.set(diveCourseIdsField, <String>['c1']);
      await repump();

      expect(pair, findsNothing);

      controller.closeCard('details');
      await repump();

      expect(pair, findsNothing);
    });
  });

  // A card with no editor draws the dive as stored for the whole sitting
  // (issue #4527, plan 4): the site, the date and the depths can now be
  // changed in the header, and such a card must not rework them before
  // Save, nor come and go.
  group('cards with no editor', () {
    testWidgets('a site changed in the sitting leaves Tide on the stored '
        'site', (tester) async {
      sizeTo(tester, 600);
      final controller = controllerOver(atSea);
      final settings = _settings(const [DiveDetailSectionId.tide]);
      Future<void> repump() async {
        await tester.pumpWidget(
          harness(
            dive: controller.session!.working,
            settings: settings,
            controller: controller,
            tideFor: atSea,
          ),
        );
        await tester.pumpAndSettle();
      }

      await repump();
      expect(tideShows(tester), isTrue);

      controller.session!.set(
        diveSiteField,
        const DiveSite(id: 'lake', name: 'Lake'),
      );
      await repump();

      expect(tideShows(tester), isTrue);
    });

    testWidgets('after the sitting the cards follow the dive', (tester) async {
      sizeTo(tester, 600);
      final controller = controllerOver(atSea);
      final settings = _settings(const [DiveDetailSectionId.tide]);
      final lake = plain.copyWith(
        site: const DiveSite(id: 'lake', name: 'Lake'),
      );
      await tester.pumpWidget(
        harness(
          dive: atSea,
          settings: settings,
          controller: controller,
          tideFor: atSea,
        ),
      );
      await tester.pumpAndSettle();
      expect(tideShows(tester), isTrue);

      controller.lock();
      await tester.pumpWidget(
        harness(
          dive: lake,
          settings: settings,
          controller: controller,
          tideFor: atSea,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveTideSection), findsOneWidget);
      expect(tideShows(tester), isFalse);
    });
  });
}
