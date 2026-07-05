import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _RecordingSplitService extends DiveSplitService {
  _RecordingSplitService() : super(DiveRepository());

  final calls = <(String, String)>[];

  @override
  Future<String> split({
    required String diveId,
    required String sourceId,
  }) async {
    calls.add((diveId, sourceId));
    return 'new-dive-id';
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

  setUp(() {
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
  });

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
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(dive.id).overrideWith((ref) async => sources),
          sourceProfilesProvider(dive.id).overrideWith((ref) async => profiles),
          gasSwitchesProvider(
            dive.id,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          tankPressuresProvider(
            dive.id,
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
          diveSplitServiceProvider.overrideWithValue(splitService),
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveDetailPage(diveId: dive.id, embedded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = originalOnError;
  }

  Finder inSourceBar(Finder matching) =>
      find.descendant(of: find.byType(SourceBar), matching: matching);

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

      // Bronze active: its 3300s duration renders as 55 min.
      expect(statValue('Bottom Time'), '55 min');
      final chartAfter = tester.widget<DiveProfileChart>(
        find.byType(DiveProfileChart),
      );
      expect(chartAfter.profile.length, 4);
      expect(chartAfter.activeComputerId, 'dc-b');
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

  testWidgets(
    'split menu action shows a confirmation; confirming calls the service '
    'and shows a snackbar; cancel does not',
    (tester) async {
      await pumpPage(tester);

      // Open the secondary chip's menu (menus render in SourceBar order).
      await tester.ensureVisible(
        inSourceBar(find.byIcon(Icons.more_vert)).last,
      );
      await tester.pump();
      await tester.tap(inSourceBar(find.byIcon(Icons.more_vert)).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Split into separate dive'));
      await tester.pumpAndSettle();

      expect(find.text('Split into separate dive?'), findsOneWidget);

      // Cancel first: no call.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(splitService.calls, isEmpty);

      // Again, confirming this time.
      await tester.ensureVisible(
        inSourceBar(find.byIcon(Icons.more_vert)).last,
      );
      await tester.pump();
      await tester.tap(inSourceBar(find.byIcon(Icons.more_vert)).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Split into separate dive'));
      await tester.pumpAndSettle();
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
