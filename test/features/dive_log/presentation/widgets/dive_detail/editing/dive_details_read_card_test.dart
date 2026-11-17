import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_course_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_details_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_details_derived_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/sac_volume_hint.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

class _Courses extends StateNotifier<AsyncValue<List<Course>>>
    implements CourseListNotifier {
  _Courses(List<Course> courses) : super(AsyncValue.data(courses));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Course _course(String id, String name) => Course(
  id: id,
  diverId: 'me',
  name: name,
  agency: 'padi',
  startDate: DateTime(2024),
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

/// A card that stands in for the Details card until it is registered.
final _detailsCard = EditCard<Dive>(
  id: 'details',
  title: (context) => 'Details',
  isEmpty: (_) => false,
  editorBuilder: (context, session) => const SizedBox.shrink(),
);

/// The Details card as the dive page shows it while reading (issue #4527).
void main() {
  final l = AppLocalizationsEn();
  final bare = Dive(id: 'dive', dateTime: DateTime(2024, 6, 1, 10));
  final wreck = _course('c1', 'Wreck Diver');
  final deep = _course('c2', 'Deep Diver');

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<void> pumpCard(
    WidgetTester tester,
    Dive dive, {
    RecordEditController<Dive>? controller,
    List<Course> stored = const [],
    List<Course> known = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final card = DiveDetailsSection(dive: dive);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          coursesForDiveProvider(dive.id).overrideWith((ref) async => stored),
          courseListNotifierProvider.overrideWith((ref) => _Courses(known)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: controller == null
                  ? card
                  : RecordEditScope<Dive>(
                      controller: controller,
                      child: RecordCardFrame<Dive>(
                        card: _detailsCard,
                        child: card,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// The value beside [label], or null when the card has no such row.
  String? rowValue(WidgetTester tester, String label) {
    final rows = tester
        .widgetList<DiveDetailRow>(find.byType(DiveDetailRow))
        .where((row) => row.label == label);
    return rows.isEmpty ? null : rows.single.value;
  }

  group('the header', () {
    testWidgets('is the shared header, with its info button and no pencil', (
      tester,
    ) async {
      await pumpCard(tester, bare);

      final header = find.byType(RecordCardHeader);
      expect(header, findsOneWidget);
      expect(
        find.descendant(of: header, matching: find.text('Details')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.byType(HeaderInfoButton)),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('the trip link is a button of its own', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpCard(
        tester,
        bare.copyWith(
          tripId: 't1',
          trip: Trip(
            id: 't1',
            name: 'Red Sea',
            startDate: DateTime(2024, 6),
            endDate: DateTime(2024, 6, 8),
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ),
      );

      // Its own node, named first by its action; the row's own text
      // follows, and nothing else of the card's.
      final link = find.bySemanticsLabel(
        RegExp(
          '^${RegExp.escape(l.diveLog_detail_semantics_viewTrip('Red Sea'))}',
        ),
      );
      expect(link, findsOneWidget);
      expect(tester.getSemantics(link).flagsCollection.isButton, isTrue);
      semantics.dispose();
    });

    testWidgets('inside an unlocked frame it gains its pencil', (tester) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(bare);
      addTearDown(controller.dispose);

      await pumpCard(tester, bare, controller: controller);

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byTooltip(l.recordEdit_editCardTooltip('Details')), findsOne);
    });
  });

  group('the statistics row', () {
    testWidgets('a counted dive has none', (tester) async {
      await pumpCard(tester, bare);

      expect(rowValue(tester, l.diveLog_edit_group_statistics), isNull);
    });

    testWidgets('an excluded dive says so', (tester) async {
      await pumpCard(tester, bare.copyWith(excludedFromStats: true));

      expect(
        rowValue(tester, l.diveLog_edit_group_statistics),
        l.diveLog_edit_summary_excluded,
      );
    });

    testWidgets('a gas-only exclusion says that', (tester) async {
      await pumpCard(tester, bare.copyWith(excludedFromGasStats: true));

      expect(
        rowValue(tester, l.diveLog_edit_group_statistics),
        l.diveLog_edit_summary_gasExcluded,
      );
    });

    testWidgets('with both on, the master one is named', (tester) async {
      await pumpCard(
        tester,
        bare.copyWith(excludedFromStats: true, excludedFromGasStats: true),
      );

      expect(
        rowValue(tester, l.diveLog_edit_group_statistics),
        l.diveLog_edit_summary_excluded,
      );
    });

    testWidgets('it is the last row of the card', (tester) async {
      await pumpCard(
        tester,
        bare.copyWith(
          excludedFromStats: true,
          gradientFactorLow: 30,
          gradientFactorHigh: 70,
          surfaceInterval: const Duration(hours: 1),
        ),
      );

      final statistics = tester.getTopLeft(
        find.text(l.diveLog_edit_group_statistics),
      );
      final interval = tester.getTopLeft(
        find.text(l.diveLog_detail_label_surfaceInterval),
      );
      expect(statistics.dy, greaterThan(interval.dy));
    });
  });

  group('courses', () {
    testWidgets('are drawn from the dive, in its order', (tester) async {
      // The stored dive is in one course; the dive as the page holds it,
      // mid-sitting, is in two.
      await pumpCard(
        tester,
        bare.copyWith(courseIds: const ['c2', 'c1']),
        stored: [wreck],
        known: [wreck, deep],
      );

      expect(find.text('Deep Diver'), findsOneWidget);
      expect(find.text('Wreck Diver'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Deep Diver')).dy,
        lessThan(tester.getTopLeft(find.text('Wreck Diver')).dy),
      );
    });

    testWidgets('a course the dive has left is not drawn', (tester) async {
      await pumpCard(
        tester,
        bare.copyWith(courseIds: const ['c2']),
        stored: [wreck, deep],
        known: [wreck, deep],
      );

      expect(find.text('Deep Diver'), findsOneWidget);
      expect(find.text('Wreck Diver'), findsNothing);
    });

    testWidgets('a dive with no courses draws none, whatever is stored', (
      tester,
    ) async {
      await pumpCard(tester, bare, stored: [wreck], known: [wreck]);

      expect(find.byType(DiveCourseRows), findsNothing);
      expect(find.text('Wreck Diver'), findsNothing);
    });

    testWidgets('while the dive\'s own courses load, the course list is not '
        'read', (tester) async {
      // Every id looks missing until the dive's courses arrive. Reading the
      // diver's whole course list then would be a wasted load on every dive
      // page, and a wrong one: the rows draw nothing until the load ends.
      final pending = Completer<List<Course>>();
      addTearDown(() => pending.complete(const []));
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var listReads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            coursesForDiveProvider(
              'dive',
            ).overrideWith((ref) => pending.future),
            courseListNotifierProvider.overrideWith((ref) {
              listReads++;
              return _Courses([wreck]);
            }),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DiveDetailsSection(
                  dive: bare.copyWith(courseIds: const ['c1']),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(listReads, 0);
      expect(find.text('Wreck Diver'), findsNothing);
    });

    testWidgets('an id nobody knows is left out', (tester) async {
      await pumpCard(
        tester,
        bare.copyWith(courseIds: const ['c1', 'gone']),
        stored: [wreck],
        known: [wreck],
      );

      expect(find.text('Wreck Diver'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the rows nothing edits', () {
    testWidgets('are one widget, in the order the card has always had', (
      tester,
    ) async {
      await pumpCard(
        tester,
        bare.copyWith(
          gradientFactorLow: 30,
          gradientFactorHigh: 70,
          diveComputerModel: 'Perdix 2',
          surfaceInterval: const Duration(hours: 1),
        ),
      );

      expect(find.byType(DiveDetailsDerivedRows), findsOneWidget);
      double top(String label) => tester.getTopLeft(find.text(label)).dy;
      final order = [
        top(l.diveLog_detail_label_gradientFactors),
        top(l.diveLog_detail_label_diveComputer),
        top(l.diveLog_detail_label_surfaceInterval),
      ];
      expect(order, orderedEquals([...order]..sort()));
      // Below the rows the card edits.
      expect(order.first, greaterThan(top(l.diveLog_diveMode_title)));
    });
  });

  // Wanted in volume per minute, with a pressure reading and no cylinder
  // volume: the card explains the fallback, and the note leads to the place
  // the volume is entered (issue #386).
  group('the cylinder volume hint', () {
    final noVolume = bare.copyWith(
      runtime: const Duration(minutes: 44),
      avgDepth: 13.2,
      tanks: const [
        DiveTank(
          id: 'tank-1',
          startPressure: 200,
          endPressure: 50,
          gasMix: GasMix(o2: 21, he: 0),
          role: TankRole.backGas,
        ),
      ],
    );
    const rmv = AppSettings(gasConsumptionDisplay: GasConsumptionDisplay.rmv);

    Future<void> pumpRows(
      WidgetTester tester, {
      RecordEditController<Dive>? controller,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await getBaseOverrides(
            settingsNotifier: MockSettingsNotifier(rmv),
          ),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: controller == null
                  ? DiveDetailsDerivedRows(dive: noVolume)
                  : RecordEditScope<Dive>(
                      controller: controller,
                      child: DiveDetailsDerivedRows(dive: noVolume),
                    ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    SacVolumeHint hint(WidgetTester tester) =>
        tester.widget<SacVolumeHint>(find.byType(SacVolumeHint));

    // A locked page reads only: the hint no longer leads to the old edit
    // form (issue #4527, plan 11).
    testWidgets('on a page with no editing it reads only', (tester) async {
      await pumpRows(tester);

      expect(hint(tester).onTap, isNull);
    });

    testWidgets('on a locked page it reads only', (tester) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {});
      addTearDown(controller.dispose);

      await pumpRows(tester, controller: controller);

      expect(hint(tester).onTap, isNull);
    });

    // Plan 5 gave the Cylinders card an editor: during a sitting the hint
    // opens it, never the old edit form over the sitting (issue #4527).
    testWidgets('during a sitting it opens the Cylinders card', (tester) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(noVolume);
      addTearDown(controller.dispose);

      await pumpRows(tester, controller: controller);
      hint(tester).onTap!();

      expect(controller.openCardIds, contains('tanks'));
    });

    testWidgets('once the sitting ends it reads only again', (tester) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(noVolume);
      addTearDown(controller.dispose);
      await pumpRows(tester, controller: controller);

      controller.lock();
      await tester.pump();

      expect(hint(tester).onTap, isNull);
    });
  });

  // Rows the card shows and nothing on it edits, as they were before they
  // moved into DiveDetailsDerivedRows.
  group('the rows nothing edits, one by one', () {
    Future<void> pumpDerived(
      WidgetTester tester,
      Dive dive, {
      List<BuddyWithRole> buddies = const [],
      List<DiveComputer> computers = const [],
      Duration? interval,
      bool inCard = false,
    }) async {
      final rows = DiveDetailsDerivedRows(dive: dive);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            buddiesForDiveProvider(
              dive.id,
            ).overrideWith((ref) async => buddies),
            computersForDiveProvider(
              dive.id,
            ).overrideWith((ref) async => computers),
            surfaceIntervalProvider(
              dive.id,
            ).overrideWith((ref) async => interval),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: inCard ? Card(child: rows) : rows),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a dive with no buddies shows its imported buddy and dive '
        'master text', (tester) async {
      await pumpDerived(
        tester,
        bare.copyWith(buddy: ' Sam ', diveMaster: 'Ali'),
      );

      expect(rowValue(tester, l.diveLog_detail_label_buddy), 'Sam');
      expect(rowValue(tester, l.diveLog_detail_label_diveMaster), 'Ali');
    });

    testWidgets('a computer named on the dive shows its serial and firmware', (
      tester,
    ) async {
      await pumpDerived(
        tester,
        bare.copyWith(
          diveComputerModel: 'Perdix 2',
          diveComputerSerial: 'A1B2',
          diveComputerFirmware: '93',
        ),
      );

      expect(rowValue(tester, l.diveLog_detail_label_diveComputer), 'Perdix 2');
      expect(rowValue(tester, l.diveLog_detail_label_serialNumber), 'A1B2');
      expect(rowValue(tester, l.diveLog_detail_label_firmwareVersion), '93');
    });

    testWidgets('a linked computer is a row that leads to it, with its '
        'serial under its name', (tester) async {
      await pumpDerived(
        tester,
        bare,
        computers: [
          DiveComputer(
            id: 'pc',
            name: 'Perdix 2',
            serialNumber: 'A1B2',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ],
      );

      expect(find.byType(DiveDetailLinkRow), findsOneWidget);
      expect(find.text(l.diveLog_detail_serialNumber('A1B2')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              w.properties.label ==
                  l.diveLog_detail_semantics_viewDiveComputer('Perdix 2'),
        ),
        findsOneWidget,
      );
    });

    // A link row is a node of its own: in the Card it would otherwise merge
    // into the card's, one button named for everything the card says.
    testWidgets('in a card, the dive computer link is a button of its own', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpDerived(
        tester,
        bare,
        inCard: true,
        computers: [
          DiveComputer(
            id: 'pc',
            name: 'Perdix 2',
            serialNumber: 'A1B2',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ],
      );

      // Its own node, named first by its action; the row's own text
      // follows, and nothing else of the card's.
      final link = find.bySemanticsLabel(
        RegExp(
          '^${RegExp.escape(l.diveLog_detail_semantics_viewDiveComputer('Perdix 2'))}',
        ),
      );
      expect(link, findsOneWidget);
      expect(tester.getSemantics(link).flagsCollection.isButton, isTrue);
      semantics.dispose();
    });

    testWidgets('with none imported, the surface interval is worked out', (
      tester,
    ) async {
      await pumpDerived(tester, bare, interval: const Duration(hours: 2));

      expect(
        rowValue(tester, l.diveLog_detail_label_surfaceInterval),
        isNotNull,
      );
    });

    testWidgets('with neither, there is no surface interval row', (
      tester,
    ) async {
      await pumpDerived(tester, bare);

      expect(rowValue(tester, l.diveLog_detail_label_surfaceInterval), isNull);
    });
  });

  group('diveStatisticsExclusion', () {
    test('is null for a counted dive', () {
      expect(diveStatisticsExclusion(l, bare), isNull);
    });

    test('names the exclusion', () {
      expect(
        diveStatisticsExclusion(l, bare.copyWith(excludedFromStats: true)),
        l.diveLog_edit_summary_excluded,
      );
      expect(
        diveStatisticsExclusion(l, bare.copyWith(excludedFromGasStats: true)),
        l.diveLog_edit_summary_gasExcluded,
      );
    });
  });
}
