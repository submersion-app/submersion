import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/twin_set_review_note.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../recording_insights_repository.dart';

/// Issue #3374: the Gas page offers to re-role the cylinders the old twin
/// set guess counted, and remembers a dismissal per diver on this device.
class _FakeDiveRepository extends Fake implements DiveRepository {
  List<String>? tankIds;
  TankRole? role;

  TankRole? onlyFrom;

  @override
  Future<int> setTankRoles(
    List<String> tankIds,
    TankRole role, {
    TankRole? onlyFrom,
  }) async {
    this.tankIds = tankIds;
    this.role = role;
    this.onlyFrom = onlyFrom;
    return tankIds.length;
  }
}

TwinSetCandidates _candidates({int dives = 14, int tanks = 15}) => (
  tankIds: [for (var i = 0; i < tanks; i++) 't$i'],
  diveIds: [for (var i = 0; i < dives; i++) 'd$i'],
);

const _none = (tankIds: <String>[], diveIds: <String>[]);
const _diverId = 'diver-1';
const _dismissedKey = 'twin_set_review_dismissed.$_diverId';

void main() {
  late _FakeDiveRepository diveRepository;
  late SharedPreferences prefs;

  setUp(() {
    diveRepository = _FakeDiveRepository();
  });

  /// [withCandidates] false leaves the candidates provider for the test to
  /// override itself.
  Future<List<Override>> overrides(
    TwinSetCandidates candidates, {
    Map<String, Object> storedPrefs = const {},
    bool withCandidates = true,
  }) async {
    SharedPreferences.setMockInitialValues(storedPrefs);
    prefs = await SharedPreferences.getInstance();
    return [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier()..setCurrentDiver(_diverId),
      ),
      diveRepositoryProvider.overrideWithValue(diveRepository),
      insightsRepositoryProvider.overrideWithValue(
        RecordingInsightsRepository(ids: candidates.diveIds),
      ),
      if (withCandidates)
        twinSetCandidatesProvider.overrideWith((ref) async => candidates),
      tankConfigurationStatsProvider.overrideWith(
        (ref) async => TankConfigurationStats.empty,
      ),
    ];
  }

  Future<void> pumpNote(
    WidgetTester tester,
    TwinSetCandidates candidates, {
    Map<String, Object> storedPrefs = const {},
  }) async {
    await tester.pumpWidget(
      testApp(
        overrides: await overrides(candidates, storedPrefs: storedPrefs),
        child: const SingleChildScrollView(child: TwinSetReviewNote()),
      ),
    );
    await tester.pumpAndSettle();
  }

  final title = find.textContaining('look like a twin set');

  testWidgets('hidden with no candidates', (tester) async {
    await pumpNote(tester, _none);

    expect(title, findsNothing);
    expect(find.text('Mark as twin sets'), findsNothing);
  });

  testWidgets('names the dive count with the plural', (tester) async {
    await pumpNote(tester, _candidates());

    expect(
      find.text('14 dives have cylinders that look like a twin set.'),
      findsOneWidget,
    );
    expect(find.textContaining('20 L and up'), findsOneWidget);
  });

  testWidgets('one dive uses the singular', (tester) async {
    await pumpNote(tester, _candidates(dives: 1, tanks: 1));

    expect(
      find.text('1 dive has a cylinder that looks like a twin set.'),
      findsOneWidget,
    );
  });

  testWidgets('hidden once dismissed', (tester) async {
    await pumpNote(
      tester,
      _candidates(),
      storedPrefs: const {_dismissedKey: true},
    );

    expect(title, findsNothing);
  });

  testWidgets('dismiss stores the flag under the diver id', (tester) async {
    await pumpNote(tester, _candidates());

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(prefs.getBool(_dismissedKey), isTrue);
    expect(title, findsNothing);
  });

  testWidgets(
    'mark asks first, names both counts, then re-roles the candidate tanks',
    (tester) async {
      final candidates = _candidates();
      await pumpNote(tester, candidates);

      await tester.tap(find.text('Mark as twin sets'));
      await tester.pumpAndSettle();

      expect(find.text('Set role to Twin Set?'), findsOneWidget);
      expect(
        find.textContaining('15 cylinders on 14 dives to Twin Set'),
        findsOneWidget,
      );
      expect(diveRepository.tankIds, isNull);

      await tester.tap(find.text('Set role'));
      await tester.pumpAndSettle();

      expect(diveRepository.tankIds, candidates.tankIds);
      expect(diveRepository.role, TankRole.twinSet);
      expect(diveRepository.onlyFrom, TankRole.backGas);
      expect(find.text('15 cylinders set to Twin Set'), findsOneWidget);
    },
  );

  testWidgets('cancelling the dialog changes nothing', (tester) async {
    await pumpNote(tester, _candidates());

    await tester.tap(find.text('Mark as twin sets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(diveRepository.tankIds, isNull);
    expect(find.text('Set role to Twin Set?'), findsNothing);
    expect(title, findsOneWidget);
  });

  testWidgets('hides while the candidates reload for another diver', (
    tester,
  ) async {
    final candidates = _candidates();
    final neverForOther = Completer<TwinSetCandidates>();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await overrides(candidates, withCandidates: false),
          twinSetCandidatesProvider.overrideWith((ref) {
            final diverId = ref.watch(currentDiverIdProvider);
            return diverId == _diverId
                ? Future.value(candidates)
                : neverForOther.future;
          }),
        ],
        child: const SingleChildScrollView(child: TwinSetReviewNote()),
      ),
    );
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(TwinSetReviewNote)),
    );
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver('diver-2');
    await tester.pump();

    expect(title, findsNothing);
    expect(find.text('Mark as twin sets'), findsNothing);
  });

  testWidgets('review opens the dive list with the candidate dive ids', (
    tester,
  ) async {
    final candidates = _candidates(dives: 3, tanks: 4);
    final router = GoRouter(
      initialLocation: '/insights',
      routes: [
        GoRoute(
          path: '/insights',
          builder: (_, _) => const Scaffold(
            body: SingleChildScrollView(child: TwinSetReviewNote()),
          ),
        ),
        GoRoute(path: '/dives', builder: (_, _) => const Text('dive list')),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(router: router, overrides: await overrides(candidates)),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TwinSetReviewNote)),
    );

    await tester.tap(find.text('Review dives'));
    await tester.pumpAndSettle();

    expect(find.text('dive list'), findsOneWidget);
    final filter = container.read(diveFilterProvider);
    expect(filter.diveIds, candidates.diveIds);
    expect(filter.diveIdsLabel, 'Tank configuration: Looks like a twin set');
  });
}
