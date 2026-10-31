import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_uncombine_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/data_sources_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _RecordingDiveRepository extends Fake implements DiveRepository {
  final setPrimaryCalls = <(String, String)>[];

  /// Holds the write open until completed.
  Completer<void>? gate;

  /// Thrown from the write when set.
  Object? failure;

  @override
  Future<void> setPrimaryDataSource({
    required String diveId,
    required String computerReadingId,
  }) async {
    setPrimaryCalls.add((diveId, computerReadingId));
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
  }
}

class _RecordingSplitService extends DiveSplitService {
  _RecordingSplitService() : super(DiveRepository());

  final calls = <(String, String)>[];

  /// Holds the split open until completed.
  Completer<void>? gate;

  /// Thrown from the split when set.
  Object? failure;

  @override
  Future<String> split({
    required String diveId,
    required String sourceId,
  }) async {
    calls.add((diveId, sourceId));
    await gate?.future;
    final failure = this.failure;
    if (failure != null) throw failure;
    return 'new-dive-id';
  }
}

class _GatedUncombineService extends DiveUncombineService {
  _GatedUncombineService() : super(DiveRepository());

  /// Holds the separate open until completed.
  Completer<void>? gate;

  final calls = <String>[];

  @override
  Future<List<String>> separate({required String diveId}) async {
    calls.add(diveId);
    await gate?.future;
    return ['restored-dive-id'];
  }
}

List<DiveProfilePoint> _points(int count, {double depthScale = 3.0}) {
  return List.generate(
    count,
    (i) => DiveProfilePoint(
      timestamp: i * 60,
      depth: (i < count / 2 ? i : (count - 1 - i)) * depthScale,
    ),
  );
}

void main() {
  final now = DateTime(2026, 5, 7);

  DiveDataSource source({
    required String id,
    required String computerId,
    required String computerName,
    required bool isPrimary,
  }) {
    return DiveDataSource(
      id: id,
      diveId: 'test-dive-1',
      computerId: computerId,
      isPrimary: isPrimary,
      computerName: computerName,
      maxDepth: isPrimary ? 21.7 : 18.3,
      duration: isPrimary ? 3360 : 3300,
      waterTemp: isPrimary ? 27.0 : 26.5,
      importedAt: now,
      createdAt: now,
    );
  }

  late Dive dive;
  late List<DiveDataSource> sources;
  late Map<String, SourceProfile> profiles;
  late _RecordingSplitService splitService;
  late _RecordingDiveRepository repository;
  late _GatedUncombineService uncombineService;
  late ValueNotifier<bool> showPage;
  late int diveReads;

  setUp(() {
    uncombineService = _GatedUncombineService();
    showPage = ValueNotifier(true);
    addTearDown(showPage.dispose);
    diveReads = 0;
    dive = createTestDiveWithBottomTime().copyWith(profile: _points(6));
    sources = [
      source(
        id: 'src-a',
        computerId: 'dc-a',
        computerName: 'Kiyans Teric',
        isPrimary: true,
      ),
      source(
        id: 'src-b',
        computerId: 'dc-b',
        computerName: 'Erics Teric',
        isPrimary: false,
      ),
    ];
    profiles = {
      'src-a': SourceProfile(
        sourceId: 'src-a',
        computerId: 'dc-a',
        isEdited: false,
        points: _points(6),
      ),
      'src-b': SourceProfile(
        sourceId: 'src-b',
        computerId: 'dc-b',
        isEdited: false,
        points: _points(4, depthScale: 2.5),
      ),
    };
    splitService = _RecordingSplitService();
    repository = _RecordingDiveRepository();
  });

  Finder inSourceBar(Finder matching) =>
      find.descendant(of: find.byType(SourceBar), matching: matching);

  Finder inSourceBarMenu() => inSourceBar(find.byIcon(Icons.more_vert)).last;

  Future<void> pumpPage(WidgetTester tester) async {
    final base = await getBaseOverrides();
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async {
            diveReads++;
            return dive;
          }),
          diveDataSourcesProvider(dive.id).overrideWith((ref) async => sources),
          sourceProfilesProvider(dive.id).overrideWith((ref) async => profiles),
          gasSwitchesProvider(
            dive.id,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          tankPressuresProvider(
            dive.id,
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
          diveSplitServiceProvider.overrideWithValue(splitService),
          diveUncombineServiceProvider.overrideWithValue(uncombineService),
          diveSegmentCountProvider(dive.id).overrideWith((ref) async => 2),
          diveRepositoryProvider.overrideWithValue(repository),
          computersForDiveProvider(dive.id).overrideWith(
            (ref) async => [
              DiveComputer(
                id: 'dc-a',
                name: 'Black Computer',
                createdAt: now,
                updatedAt: now,
              ),
              DiveComputer(
                id: 'dc-b',
                name: 'Bronze Computer',
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        ],
        child: MaterialApp(
          // flutter_test forwards the host machine's locale list, so an
          // unpinned MaterialApp renders a translated UI on a non-English
          // machine and every English literal below stops matching.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<bool>(
            valueListenable: showPage,
            builder: (context, show, _) => show
                ? Scaffold(
                    body: DiveDetailPage(diveId: dive.id, embedded: true),
                  )
                : const Scaffold(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = originalOnError;
  }

  /// Keeps the dive read alive once the page is gone, as the dive list does,
  /// so a refresh shows up in [diveReads].
  void listenToDive(WidgetTester tester) {
    final subscription = ProviderScope.containerOf(
      tester.element(find.byType(DiveDetailPage)),
    ).listen(diveProvider(dive.id), (_, _) {});
    addTearDown(subscription.close);
  }

  /// Takes the page away while an action started from it is still running.
  Future<int> leavePage(WidgetTester tester) async {
    showPage.value = false;
    await tester.pump();
    expect(find.byType(DiveDetailPage), findsNothing);
    return diveReads;
  }

  Future<void> tapSetPrimary(WidgetTester tester) async {
    await tester.ensureVisible(inSourceBarMenu());
    await tester.pump();
    await tester.tap(inSourceBarMenu());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set as primary'));
    await tester.pump();
  }

  testWidgets(
    'sources bar shows both resolved names and never Unknown Computer',
    (tester) async {
      await pumpPage(tester);

      expect(inSourceBar(find.text('Kiyans Teric')), findsOneWidget);
      expect(inSourceBar(find.text('Erics Teric')), findsOneWidget);
      expect(find.text('Unknown Computer'), findsNothing);
    },
  );

  testWidgets(
    'header stat values and the chart profile follow the active source',
    (tester) async {
      await pumpPage(tester);

      // Value shown in the header stat column labeled [label] (the value
      // Text precedes the label inside the stat Column).
      String statValue(String label) {
        final column = find
            .ancestor(of: find.text(label), matching: find.byType(Column))
            .first;
        return tester
            .widgetList<Text>(
              find.descendant(of: column, matching: find.byType(Text)),
            )
            .first
            .data!;
      }

      // Primary active: dive-level bottom time (45 min fixture default).
      expect(statValue('Bottom Time'), '45 min');

      final chartBefore = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      expect(chartBefore.profile.length, 6);

      await tester.ensureVisible(inSourceBar(find.text('Erics Teric')));
      await tester.pump();
      await tester.tap(inSourceBar(find.text('Erics Teric')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Bronze active: its bottom time is derived from its own profile
      // (final ascent starts at t=120), never read from its 3300 s duration,
      // which is the runtime it measured (issue #2421).
      expect(statValue('Bottom Time'), '2 min');
      final chartAfter = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      expect(chartAfter.profile.length, 4);
      expect(chartAfter.activeComputerId, 'dc-b');
    },
  );

  testWidgets(
    'a viewed source with no profile shows the dive bottom time, never its '
    'runtime',
    (tester) async {
      profiles.remove('src-b');
      await pumpPage(tester);

      await tester.ensureVisible(inSourceBar(find.text('Erics Teric')));
      await tester.pump();
      await tester.tap(inSourceBar(find.text('Erics Teric')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final column = find
          .ancestor(of: find.text('Bottom Time'), matching: find.byType(Column))
          .first;
      final value = tester
          .widgetList<Text>(
            find.descendant(of: column, matching: find.byType(Text)),
          )
          .first
          .data;
      // Not '55 min', the 3300 s runtime the source measured.
      expect(value, '45 min');
    },
  );

  testWidgets('overlay eye draws the other source as a chart overlay', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.ensureVisible(
      inSourceBar(find.byIcon(Icons.visibility_off_outlined)),
    );
    await tester.pump();
    await tester.tap(inSourceBar(find.byIcon(Icons.visibility_off_outlined)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final chart = tester.widget<DiveProfileChart>(
      find.byType(DiveProfileChart),
    );
    expect(chart.overlays, isNotNull);
    expect(chart.overlays!.single.sourceId, 'src-b');
    expect(chart.overlays!.single.name, 'Erics Teric');
  });

  testWidgets('the sources bar chip menu does not offer split', (tester) async {
    await pumpPage(tester);

    await tester.ensureVisible(inSourceBar(find.byIcon(Icons.more_vert)).last);
    await tester.pump();
    await tester.tap(inSourceBar(find.byIcon(Icons.more_vert)).last);
    await tester.pumpAndSettle();

    expect(find.text('Set as primary'), findsOneWidget);
    expect(find.text('Split into separate dive'), findsNothing);
  });

  testWidgets('the sources bar chip menu promotes a source to primary', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.ensureVisible(inSourceBar(find.byIcon(Icons.more_vert)).last);
    await tester.pump();
    await tester.tap(inSourceBar(find.byIcon(Icons.more_vert)).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set as primary'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(repository.setPrimaryCalls, [(dive.id, 'src-b')]);
  });

  testWidgets('leaving during a set primary still refreshes the dive', (
    tester,
  ) async {
    await pumpPage(tester);
    listenToDive(tester);
    final gate = repository.gate = Completer<void>();

    await tapSetPrimary(tester);
    final readsBefore = await leavePage(tester);

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(diveReads, readsBefore + 1);
  });

  testWidgets('a set primary that fails tells the diver', (tester) async {
    await pumpPage(tester);
    repository.failure = StateError('the write failed');

    await tapSetPrimary(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('leaving during a split still refreshes the dive', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);
    listenToDive(tester);
    final gate = splitService.gate = Completer<void>();

    tester.widget<DataSourcesSection>(find.byType(DataSourcesSection)).onSplit!(
      'src-b',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split'));
    await tester.pump();
    final readsBefore = await leavePage(tester);

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(diveReads, readsBefore + 1);
    expect(find.text('Dive split'), findsOneWidget);
  });

  testWidgets('a split that fails after leaving still tells the diver', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);
    final gate = splitService.gate = Completer<void>();
    splitService.failure = StateError('the split failed');

    tester.widget<DataSourcesSection>(find.byType(DataSourcesSection)).onSplit!(
      'src-b',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split'));
    await tester.pump();
    await leavePage(tester);

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.text('Split failed'), findsOneWidget);
  });

  testWidgets('leaving during a separate still refreshes the dive', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester);
    listenToDive(tester);
    final gate = uncombineService.gate = Completer<void>();

    tester
        .widget<DataSourcesSection>(find.byType(DataSourcesSection))
        .onSeparate!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Separate'));
    await tester.pump();
    expect(uncombineService.calls, [dive.id]);
    final readsBefore = await leavePage(tester);

    gate.complete();
    await tester.pump();
    await tester.pump();

    expect(diveReads, readsBefore + 1);
    expect(find.text('2 dives restored'), findsOneWidget);
  });

  testWidgets(
    'the Data Sources card split action shows a confirmation; confirming '
    'calls the service and shows a snackbar; cancel does not',
    (tester) async {
      // The detail page is far taller than the default 600px test surface,
      // and the Data Sources card sits below the profile: at the default
      // size the card's overflow menu stays off screen even at max scroll.
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(tester);

      Finder secondaryCardMenu() => find
          .descendant(
            of: find.byType(DataSourcesSection),
            matching: find.byIcon(Icons.more_vert),
          )
          .last;

      Future<void> openSplitDialog() async {
        await tester.ensureVisible(secondaryCardMenu());
        await tester.pumpAndSettle();
        await tester.tap(secondaryCardMenu());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Split into separate dive'));
        await tester.pumpAndSettle();
      }

      await openSplitDialog();
      expect(find.text('Split into separate dive?'), findsOneWidget);

      // Cancel first: no call.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(splitService.calls, isEmpty);

      // Again, confirming this time.
      await openSplitDialog();
      await tester.tap(find.text('Split'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(splitService.calls, [(dive.id, 'src-b')]);
      expect(find.text('Dive split'), findsOneWidget);
    },
  );

  testWidgets('the Details card Dive Computer row follows the active source', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Black Computer'), findsOneWidget);
    expect(find.text('Bronze Computer'), findsNothing);

    await tester.ensureVisible(inSourceBar(find.text('Erics Teric')));
    await tester.pump();
    await tester.tap(inSourceBar(find.text('Erics Teric')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Bronze Computer'), findsOneWidget);
    expect(find.text('Black Computer'), findsNothing);
  });
}
