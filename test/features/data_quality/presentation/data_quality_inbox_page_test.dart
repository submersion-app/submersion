import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_state_store.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/pages/data_quality_inbox_page.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_inbox_providers.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_card.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/widgets/combine_dives_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/test_database.dart';
import '../../../helpers/test_app.dart';

/// Findings repository stub whose `watchFindings` emits a single, timer-free
/// value. The inbox's stream provider is autoDispose over a Drift query stream
/// in production; using a plain [Stream.value] keeps the widget test out of
/// fake-async timer trouble while still exercising every rendering branch.
class _FakeFindingsRepository implements QualityFindingsRepository {
  _FakeFindingsRepository(this.findings);
  List<QualityFinding> findings;
  final dismissed = <String>[];

  @override
  Stream<List<QualityFinding>> watchFindings() => Stream.value(findings);

  @override
  Future<void> setStatus(String id, QualityStatus status) async {
    dismissed.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A scan service whose [scanLibrary] is fully driven by the test: it can
/// report a fixed progress step, block on an optional [gate], then resolve with
/// a fixed [summary].
class _FakeScanService extends QualityScanService {
  _FakeScanService({required this.summary, this.gate, this.progress});
  final QualityScanSummary summary;
  final Completer<void>? gate;
  final ({int done, int total})? progress;

  @override
  Future<QualityScanSummary> scanLibrary({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
    Set<String>? enabledDetectorIds,
    DateTime? now,
  }) async {
    if (progress != null) onProgress?.call(progress!.done, progress!.total);
    isCancelled?.call();
    if (gate != null) await gate!.future;
    return summary;
  }
}

/// A scan-state store with test-controlled bookkeeping so the "new checks"
/// banner and the last-scan line can be driven directly.
class _FakeScanStateStore extends QualityScanStateStore {
  _FakeScanStateStore(super.prefs, {this.last, this.newVersions = false});
  final DateTime? last;
  final bool newVersions;
  final recorded = <DateTime>[];

  @override
  DateTime? get lastFullScanAt => last;

  @override
  bool get hasNewDetectorVersions => newVersions;

  @override
  Future<void> recordFullScan(DateTime at, Map<String, int> versions) async {
    recorded.add(at);
  }
}

QualityFinding finding({String detectorId = 'sample_gap'}) => QualityFinding(
  id: 'f-$detectorId',
  diveId: 'd1',
  detectorId: detectorId,
  detectorVersion: 1,
  category: QualityCategory.profile,
  severity: QualitySeverity.info,
  status: QualityStatus.open,
  params: const {'gapCount': 2, 'longestGapSeconds': 90},
  createdAt: DateTime.utc(2026, 7, 17),
  updatedAt: DateTime.utc(2026, 7, 17),
);

QualityFinding _f({
  required String id,
  String diveId = 'd1',
  String? relatedDiveId,
  String? computerId,
  required String detectorId,
  required QualityCategory category,
  Map<String, Object?> params = const {},
  QualitySeverity severity = QualitySeverity.warning,
}) => QualityFinding(
  id: id,
  diveId: diveId,
  relatedDiveId: relatedDiveId,
  computerId: computerId,
  detectorId: detectorId,
  detectorVersion: 1,
  category: category,
  severity: severity,
  status: QualityStatus.open,
  params: params,
  createdAt: DateTime.utc(2026, 7, 17),
  updatedAt: DateTime.utc(2026, 7, 17),
);

Future<Widget> _wrap(_FakeFindingsRepository repo) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      qualityFindingsRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: const MaterialApp(
      // Every assertion in this file is an English literal, and an unpinned
      // MaterialApp resolves against the HOST machine's locale list (not a
      // fixed en_US), so the app's own translations would win on a
      // non-English dev machine and the finders would match nothing.
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DataQualityInboxPage(),
    ),
  );
}

/// Seeds a dive so the inbox can name it. The group header reads through the
/// real repository, so a test that asserts on a header needs a real row.
Future<void> _seedDive(
  String id, {
  String? name,
  DateTime? entryTime,
  double? maxDepth,
  Duration? runtime,
}) {
  final entry = entryTime ?? DateTime.utc(2026, 6, 14, 9, 12);
  return DiveRepository().createDive(
    domain.Dive(
      id: id,
      name: name,
      dateTime: entry,
      entryTime: entry,
      maxDepth: maxDepth,
      runtime: runtime,
    ),
  );
}

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

/// Builds the inbox page over a fake findings stream (the given [findings]),
/// with optional scan-service / scan-state-store fakes. Repairs still dispatch
/// to the real [QualityRepairExecutor] against the test database.
List<dynamic> _overrides(
  SharedPreferences prefs, {
  List<QualityFinding> findings = const [],
  QualityScanService? scanService,
  QualityScanStateStore? store,
  Map<String, String>? computerNames,
  VoidCallback? onComputerNamesRead,
  DiveRepository? diveRepository,
}) => [
  qualityFindingsRepositoryProvider.overrideWithValue(
    _FakeFindingsRepository(List.of(findings)),
  ),
  sharedPreferencesProvider.overrideWithValue(prefs),
  settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
  if (scanService != null)
    qualityScanServiceProvider.overrideWithValue(scanService),
  if (store != null) qualityScanStateStoreProvider.overrideWithValue(store),
  if (diveRepository != null)
    diveRepositoryProvider.overrideWithValue(diveRepository),
  // The name map is built from the saved-computers list, which needs a
  // diver and a computers table this page test has no reason to stand up.
  // Overriding it keeps the assertion on what the page does with the names.
  if (computerNames != null || onComputerNamesRead != null)
    qualityComputerNamesProvider.overrideWith((ref) async {
      onComputerNamesRead?.call();
      return computerNames ?? const {};
    }),
];

Widget _scope(
  SharedPreferences prefs, {
  List<QualityFinding> findings = const [],
  QualityScanService? scanService,
  QualityScanStateStore? store,
  String? filterDiveId,
  Map<String, String>? computerNames,
  VoidCallback? onComputerNamesRead,
  DiveRepository? diveRepository,
}) => ProviderScope(
  overrides: _overrides(
    prefs,
    findings: findings,
    scanService: scanService,
    store: store,
    computerNames: computerNames,
    onComputerNamesRead: onComputerNamesRead,
    diveRepository: diveRepository,
  ).cast(),
  child: localizedMaterialApp(
    // See the note in _wrap: pinned so the English finders below survive a
    // non-English host locale.
    locale: const Locale('en'),
    home: DataQualityInboxPage(filterDiveId: filterDiveId),
  ),
);

/// A repository whose identity lookup fails, for the branch where the header
/// cannot name a dive because the read itself broke (as opposed to the dive
/// simply being absent from an otherwise successful read).
class _FailingDiveRepository implements DiveRepository {
  @override
  Future<List<DiveSummary>> getSummariesByIds(List<String> ids) async {
    throw StateError('identity lookup unavailable');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
    // Repair dispatch queues a targeted rescan; keep the Drift work out of the
    // widget-test zone.
    QualityScanScheduler.enabled = false;
  });
  tearDown(() {
    QualityScanScheduler.enabled = true;
    return tearDownTestDatabase();
  });

  // --- Existing fake-repository coverage -----------------------------------

  testWidgets('empty inbox shows the all-clear state', (tester) async {
    await tester.pumpWidget(await _wrap(_FakeFindingsRepository([])));
    await tester.pumpAndSettle();
    expect(find.text('All clear'), findsOneWidget);
    // Never scanned: the empty state shows the CTA copy, not a last-scan line.
    expect(find.textContaining('has not been scanned'), findsOneWidget);
  });

  testWidgets('a finding renders its detector title', (tester) async {
    await tester.pumpWidget(await _wrap(_FakeFindingsRepository([finding()])));
    await tester.pumpAndSettle();
    expect(find.text('Sample gaps'), findsOneWidget);
  });

  testWidgets('dismiss marks the finding dismissed', (tester) async {
    final repo = _FakeFindingsRepository([finding()]);
    await tester.pumpWidget(await _wrap(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first); // expand
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(repo.dismissed, ['f-sample_gap']);
  });

  testWidgets('expanded card shows exactly one Go to dive link', (
    tester,
  ) async {
    // sample_gap's repair options include a GoToDiveRepair; the card also
    // renders its own footer "Go to dive" -- there must be no duplicate.
    await tester.pumpWidget(await _wrap(_FakeFindingsRepository([finding()])));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first); // expand
    await tester.pumpAndSettle();
    expect(find.text('Go to dive'), findsOneWidget);
  });

  // --- Rendering / formatter coverage --------------------------------------

  testWidgets('renders unit-formatted messages for every formatter', (
    tester,
  ) async {
    // One finding per formatter closure (depth, pressure, temperature, sac),
    // all on the same dive so they collapse into one group (append branch).
    await _seedDive('d1', name: 'Reef wall');
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'm-depth',
            detectorId: 'depth_spike',
            category: QualityCategory.profile,
            params: const {'depth': 30.0, 'atSeconds': 125},
          ),
          _f(
            id: 'm-pressure',
            detectorId: 'pressure_anomaly',
            category: QualityCategory.pressure,
            params: const {'startBar': 50.0, 'endBar': 200.0},
          ),
          _f(
            id: 'm-temp',
            detectorId: 'temp_anomaly',
            category: QualityCategory.temperature,
            params: const {'deltaC': 6.0, 'spikeShaped': true},
          ),
          _f(
            id: 'm-sac',
            detectorId: 'pressure_anomaly',
            category: QualityCategory.pressure,
            params: const {'surfaceLpm': 40.0},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QualityFindingCard), findsNWidgets(4));
    expect(find.text('Depth spike'), findsOneWidget);
    expect(find.text('Temperature anomaly'), findsOneWidget);
    expect(find.text('Pressure anomaly'), findsNWidgets(2));
    // Single dive group header, naming the dive rather than its uuid.
    expect(find.textContaining('Reef wall'), findsOneWidget);
    expect(find.text('d1'), findsNothing);
  });

  // --- Chip row / filtering ------------------------------------------------

  testWidgets('chip selection filters findings by category', (tester) async {
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'c-gap',
            detectorId: 'sample_gap',
            category: QualityCategory.profile,
            params: const {'gapCount': 1, 'longestGapSeconds': 30},
          ),
          _f(
            id: 'c-clock',
            detectorId: 'clock_offset',
            category: QualityCategory.time,
            params: const {'offsetHours': 3},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // All chip: both categories visible; per-chip counts are rendered.
    expect(find.text('Sample gaps'), findsOneWidget);
    expect(find.text('Clock & timezone'), findsOneWidget);
    expect(find.text('Time (1)'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Time (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Sample gaps'), findsNothing);
    expect(find.text('Clock & timezone'), findsOneWidget);
  });

  testWidgets('filterDiveId deep-link shows only touching findings', (
    tester,
  ) async {
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        filterDiveId: 'd2',
        findings: [
          _f(
            id: 'dl-gap',
            detectorId: 'sample_gap',
            category: QualityCategory.profile,
            params: const {'gapCount': 1, 'longestGapSeconds': 30},
          ),
          _f(
            id: 'dl-clock',
            diveId: 'd2',
            detectorId: 'clock_offset',
            category: QualityCategory.time,
            params: const {'offsetHours': 2},
          ),
          _f(
            id: 'dl-dup',
            diveId: 'd1',
            relatedDiveId: 'd2',
            detectorId: 'duplicate',
            category: QualityCategory.duplicate,
            params: const {'score': 0.9, 'timeDiffMinutes': 5},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // d1-only sample_gap is filtered out; d2 and the d2-related pair remain.
    expect(find.text('Sample gaps'), findsNothing);
    expect(find.text('Clock & timezone'), findsOneWidget);
    expect(find.text('Likely duplicate'), findsOneWidget);
  });

  testWidgets(
    'comma-separated filterDiveId shows findings for every id in the set',
    (tester) async {
      final prefs = await _prefs();
      await tester.pumpWidget(
        _scope(
          prefs,
          // Whole imported set (as the import summary deep-links); no dive in
          // scope may be hidden even though the count spans all of them.
          filterDiveId: 'd1,d2',
          findings: [
            _f(
              id: 'gap-d1',
              detectorId: 'sample_gap',
              category: QualityCategory.profile,
              params: const {'gapCount': 1, 'longestGapSeconds': 30},
            ),
            _f(
              id: 'clock-d2',
              diveId: 'd2',
              detectorId: 'clock_offset',
              category: QualityCategory.time,
              params: const {'offsetHours': 2},
            ),
            _f(
              id: 'spike-d3',
              diveId: 'd3',
              detectorId: 'depth_spike',
              category: QualityCategory.profile,
              params: const {'depth': 55.0, 'atSeconds': 120},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // d1 and d2 findings both show; d3 (outside the set) is hidden.
      expect(find.text('Sample gaps'), findsOneWidget);
      expect(find.text('Clock & timezone'), findsOneWidget);
      expect(find.text('Depth spike'), findsNothing);
    },
  );

  testWidgets('one dive gets one header even when findings interleave', (
    tester,
  ) async {
    await _seedDive('d1', name: 'Reef wall');
    await _seedDive('d2', name: 'Night dive');
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        // watchFindings emits in updatedAt order (not by dive), so d1's two
        // findings straddle d2's. Grouping must still yield a single d1 header.
        findings: [
          _f(
            id: 'd1-gap',
            detectorId: 'sample_gap',
            category: QualityCategory.profile,
            params: const {'gapCount': 1, 'longestGapSeconds': 30},
          ),
          _f(
            id: 'd2-clock',
            diveId: 'd2',
            detectorId: 'clock_offset',
            category: QualityCategory.time,
            params: const {'offsetHours': 2},
          ),
          _f(
            id: 'd1-spike',
            detectorId: 'depth_spike',
            category: QualityCategory.profile,
            params: const {'depth': 55.0, 'atSeconds': 120},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Exactly one header per dive despite the interleaving, each naming its
    // own dive.
    expect(find.textContaining('Reef wall'), findsOneWidget);
    expect(find.textContaining('Night dive'), findsOneWidget);
  });

  // --- Dive identity -------------------------------------------------------

  testWidgets('header names an unnamed, siteless dive by when it happened', (
    tester,
  ) async {
    // The reported bug: a downloaded dive carries neither a custom name nor a
    // site, so the old fallback chain ran all the way to the raw uuid and the
    // page named no dive the diver could recognize.
    await _seedDive('d1', entryTime: DateTime.utc(2026, 6, 14, 9, 12));
    final prefs = await _prefs();
    await tester.pumpWidget(_scope(prefs, findings: [finding()]));
    await tester.pumpAndSettle();

    expect(find.text('d1'), findsNothing);
    expect(find.textContaining('2026'), findsOneWidget);
  });

  testWidgets('header carries the dive max depth and duration', (tester) async {
    await _seedDive(
      'd1',
      name: 'Reef wall',
      maxDepth: 28.4,
      runtime: const Duration(minutes: 47),
    );
    final prefs = await _prefs();
    await tester.pumpWidget(_scope(prefs, findings: [finding()]));
    await tester.pumpAndSettle();

    expect(find.textContaining('28.4'), findsOneWidget);
    expect(find.textContaining('47 min'), findsOneWidget);
  });

  testWidgets('a finding whose dive is gone says so instead of showing an id', (
    tester,
  ) async {
    final prefs = await _prefs();
    await tester.pumpWidget(_scope(prefs, findings: [finding()]));
    await tester.pumpAndSettle();

    expect(find.text('Dive details unavailable'), findsOneWidget);
    expect(find.text('d1'), findsNothing);
  });

  testWidgets('a cross-dive finding names the dive it is paired with', (
    tester,
  ) async {
    await _seedDive('d1', name: 'Reef wall');
    await _seedDive('d2', name: 'Night dive');
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'dupe',
            detectorId: 'duplicate',
            category: QualityCategory.duplicate,
            relatedDiveId: 'd2',
            params: const {'score': 0.5, 'timeDiffMinutes': 1},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Paired with'), findsOneWidget);
    expect(find.textContaining('Night dive'), findsOneWidget);
  });

  testWidgets('a finding names the computer that recorded it', (tester) async {
    await _seedDive('d1', name: 'Reef wall');
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'gap',
            detectorId: 'sample_gap',
            category: QualityCategory.profile,
            computerId: 'c1',
            params: const {'gapCount': 2, 'longestGapSeconds': 90},
          ),
        ],
        computerNames: const {'c1': 'Perdix AI'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recorded by Perdix AI'), findsOneWidget);
  });

  testWidgets('a deep link still names a paired dive outside its filter', (
    tester,
  ) async {
    // The identity lookup is scoped to the dive filter so a deep link does not
    // load the whole library. The pair's other dive is outside that filter, and
    // must still be named: scoping away the dive the row points at would make
    // the row useless exactly where the deep link sends you.
    await _seedDive('d1', name: 'Reef wall');
    await _seedDive('d2', name: 'Night dive');
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        filterDiveId: 'd1',
        findings: [
          _f(
            id: 'dupe',
            detectorId: 'duplicate',
            category: QualityCategory.duplicate,
            relatedDiveId: 'd2',
            params: const {'score': 0.5, 'timeDiffMinutes': 1},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Night dive'), findsOneWidget);
  });

  testWidgets('computer names are not read when no finding names one', (
    tester,
  ) async {
    // Resolving names costs a diver lookup plus a computers-table read. No
    // finding here carries a computerId, so nothing should ask for them.
    await _seedDive('d1', name: 'Reef wall');
    var read = false;
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [finding()],
        onComputerNamesRead: () => read = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(read, isFalse);
  });

  testWidgets('computer names are read when a finding names one', (
    tester,
  ) async {
    await _seedDive('d1', name: 'Reef wall');
    var read = false;
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'gap',
            detectorId: 'sample_gap',
            category: QualityCategory.profile,
            computerId: 'c1',
            params: const {'gapCount': 2, 'longestGapSeconds': 90},
          ),
        ],
        onComputerNamesRead: () => read = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(read, isTrue);
  });

  testWidgets('tapping a dive header opens that dive', (tester) async {
    await _seedDive('d1', name: 'Reef wall');
    final prefs = await _prefs();
    final router = GoRouter(
      initialLocation: '/quality',
      routes: [
        GoRoute(
          path: '/quality',
          builder: (_, _) => const DataQualityInboxPage(),
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (_, state) =>
              Scaffold(body: Text('opened ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: _overrides(prefs, findings: [finding()]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Reef wall'));
    await tester.pumpAndSettle();

    expect(find.text('opened d1'), findsOneWidget);
  });

  testWidgets('a failed identity lookup says so rather than showing an id', (
    tester,
  ) async {
    // Distinct from the dive simply being absent: here the read itself broke,
    // so there is no map at all. The header must still name the state instead
    // of leaving a blank line above the findings.
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [finding()],
        diveRepository: _FailingDiveRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dive details unavailable'), findsOneWidget);
    expect(find.text('d1'), findsNothing);
    // The finding itself still renders; only its identity is unknown.
    expect(find.text('Sample gaps'), findsOneWidget);
  });

  // --- Empty state variants + library scan flow ----------------------------

  testWidgets('empty state shows last-scan line and scans on tap', (
    tester,
  ) async {
    final prefs = await _prefs();
    final store = _FakeScanStateStore(prefs, last: DateTime.utc(2026, 7, 10));
    final service = _FakeScanService(
      summary: const QualityScanSummary(
        divesScanned: 0,
        findingsProduced: 0,
        detectorErrors: 0,
      ),
    );
    await tester.pumpWidget(_scope(prefs, scanService: service, store: store));
    await tester.pumpAndSettle();

    expect(find.text('All clear'), findsOneWidget);
    expect(find.textContaining('Last scan'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Scan library'));
    await tester.pumpAndSettle();

    expect(store.recorded, isNotEmpty);
    expect(find.textContaining('Scan complete'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('scan shows an indeterminate progress bar and can be cancelled', (
    tester,
  ) async {
    final prefs = await _prefs();
    final gate = Completer<void>();
    final store = _FakeScanStateStore(prefs);
    final service = _FakeScanService(
      summary: const QualityScanSummary(
        divesScanned: 3,
        findingsProduced: 2,
        detectorErrors: 0,
      ),
      gate: gate,
    );
    await tester.pumpWidget(
      _scope(
        prefs,
        scanService: service,
        store: store,
        findings: [
          _f(
            id: 's-gap',
            detectorId: 'sample_gap',
            category: QualityCategory.profile,
            params: const {'gapCount': 1, 'longestGapSeconds': 30},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.radar));
    await tester.pump();

    // (0, 0) => indeterminate, and the app-bar scan action is hidden.
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, isNull);
    expect(find.byIcon(Icons.radar), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();

    expect(store.recorded, isNotEmpty);
    expect(find.textContaining('Scan complete'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('scan shows determinate progress and reports detector errors', (
    tester,
  ) async {
    final prefs = await _prefs();
    final gate = Completer<void>();
    final store = _FakeScanStateStore(prefs);
    final service = _FakeScanService(
      summary: const QualityScanSummary(
        divesScanned: 4,
        findingsProduced: 0,
        detectorErrors: 2,
      ),
      gate: gate,
      progress: (done: 2, total: 4),
    );
    await tester.pumpWidget(
      _scope(
        prefs,
        scanService: service,
        store: store,
        findings: [
          _f(
            id: 'e-gap',
            detectorId: 'sample_gap',
            category: QualityCategory.profile,
            params: const {'gapCount': 1, 'longestGapSeconds': 30},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.radar));
    await tester.pump();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.5, 0.001));

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.textContaining('could not be fully checked'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('new-checks banner offers a rescan', (tester) async {
    final prefs = await _prefs();
    final store = _FakeScanStateStore(
      prefs,
      last: DateTime.utc(2026, 7, 10),
      newVersions: true,
    );
    final service = _FakeScanService(
      summary: const QualityScanSummary(
        divesScanned: 1,
        findingsProduced: 0,
        detectorErrors: 0,
      ),
    );
    await tester.pumpWidget(_scope(prefs, scanService: service, store: store));
    await tester.pumpAndSettle();

    expect(find.text('New quality checks are available'), findsOneWidget);

    await tester.tap(find.text('Rescan'));
    await tester.pumpAndSettle();

    expect(store.recorded, isNotEmpty);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  // --- Repair dispatch (_runAction) ----------------------------------------

  final repairCases = <String, QualityFinding>{
    'fill gaps': _f(
      id: 'r-gap',
      detectorId: 'sample_gap',
      category: QualityCategory.profile,
      params: const {'gapCount': 2, 'longestGapSeconds': 90},
    ),
    'despike': _f(
      id: 'r-spike',
      detectorId: 'depth_spike',
      category: QualityCategory.profile,
      params: const {'depth': 30.0, 'atSeconds': 125},
    ),
    'recompute metrics': _f(
      id: 'r-recompute',
      detectorId: 'depth_spike',
      category: QualityCategory.profile,
      params: const {'storedMaxDepth': 30.0, 'profileMaxDepth': 28.0},
    ),
    'smooth temperature': _f(
      id: 'r-smooth',
      detectorId: 'temp_anomaly',
      category: QualityCategory.temperature,
      params: const {'deltaC': 6.0, 'spikeShaped': true},
    ),
    'convert temperature': _f(
      id: 'r-convert',
      detectorId: 'temp_anomaly',
      category: QualityCategory.temperature,
      params: const {
        'minTempC': 285.0,
        'maxTempC': 290.0,
        'fahrenheitAsKelvinSuspected': true,
      },
    ),
    'smooth impossible rates': _f(
      id: 'r-rates',
      detectorId: 'impossible_rate',
      category: QualityCategory.profile,
      params: const {'startSeconds': 120, 'interpolatable': true},
    ),
    'clamp negative depths': _f(
      id: 'r-clamp',
      detectorId: 'depth_spike',
      category: QualityCategory.profile,
      params: const {'sampleCount': 3, 'minDepth': -2.0},
    ),
    'swap tank pressures': _f(
      id: 'r-swapp',
      detectorId: 'pressure_anomaly',
      category: QualityCategory.pressure,
      params: const {'tankId': 't1', 'startBar': 50.0, 'endBar': 200.0},
    ),
    'set tank record from series': _f(
      id: 'r-series',
      detectorId: 'pressure_anomaly',
      category: QualityCategory.pressure,
      params: const {'tankId': 't1', 'recordBar': 200.0, 'seriesBar': 50.0},
    ),
    'swap pressure series': _f(
      id: 'r-swapseries',
      detectorId: 'tank_assignment',
      category: QualityCategory.tank,
      params: const {'tankIdA': 'a', 'tankIdB': 'b'},
    ),
    'set primary source': _f(
      id: 'r-primary',
      detectorId: 'source_conflict',
      category: QualityCategory.source,
      params: const {
        'sourceId': 's1',
        'primaryMaxDepth': 30.0,
        'sourceMaxDepth': 28.0,
      },
    ),
  };

  repairCases.forEach((name, f) {
    testWidgets('repair "$name" dispatches through _runAction', (tester) async {
      final prefs = await _prefs();
      await tester.pumpWidget(_scope(prefs, findings: [f]));
      await tester.pumpAndSettle();

      // The trailing primary action of the card.
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();

      // Each of these repairs reports the outcome (applied or failed) as a
      // SnackBar via the shared withUndo helper.
      expect(find.byType(SnackBar), findsWidgets);
      await tester.pumpAndSettle(const Duration(seconds: 6));
    });
  });

  testWidgets('time-shift repair opens the offset sheet and applies', (
    tester,
  ) async {
    // A real dive so shiftTimes + divesInSameImport have a row to operate on.
    final entry = DateTime.utc(2026, 7, 1, 10);
    await DiveRepository().createDive(
      domain.Dive(id: 'd1', dateTime: entry, entryTime: entry),
    );
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'r-clock',
            detectorId: 'clock_offset',
            category: QualityCategory.time,
            params: const {'offsetHours': 3},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    // The offset sheet: number field + import-wide toggle + OK.
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Repair applied'), findsOneWidget);
    // Exercise the undo action wired onto the SnackBar.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('scalar water-temp repair converts the dive and can undo', (
    tester,
  ) async {
    // 78 recorded as Celsius is 25.6 C read as Fahrenheit.
    await DiveRepository().createDive(
      domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1), waterTemp: 78),
    );
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'r-temp-scalar',
            detectorId: 'temp_anomaly',
            category: QualityCategory.temperature,
            params: const {'waterTempC': 78.0, 'fahrenheitSuspected': true},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    expect(find.text('Repair applied'), findsOneWidget);
    expect(
      (await DiveRepository().getDiveById('d1'))!.waterTemp,
      closeTo(25.5556, 1e-3),
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle(const Duration(seconds: 6));
    expect((await DiveRepository().getDiveById('d1'))!.waterTemp, 78);
  });

  testWidgets('consolidate-duplicate repair reports through a SnackBar', (
    tester,
  ) async {
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'r-dup',
            diveId: 'd1',
            relatedDiveId: 'd2',
            detectorId: 'duplicate',
            category: QualityCategory.duplicate,
            params: const {'score': 0.9, 'timeDiffMinutes': 5},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsWidgets);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('a same-computer duplicate offers no Consolidate button', (
    tester,
  ) async {
    // The real-world duplicate is the same dive downloaded twice from one
    // computer, and DiveConsolidationBuilder refuses to merge those. The
    // inbox used to offer Consolidate anyway, so the tap could only ever
    // fail; the card now explains that no automatic fix exists instead.
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'r-dup-same',
            diveId: 'd1',
            relatedDiveId: 'd2',
            detectorId: 'duplicate',
            category: QualityCategory.duplicate,
            params: const {
              'score': 0.9,
              'timeDiffMinutes': 1,
              'sameComputer': true,
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Consolidate'), findsNothing);
    expect(
      find.text('No automatic fix. Open the dive to correct this.'),
      findsOneWidget,
    );
  });

  testWidgets('split-source repair reports a failure through a SnackBar', (
    tester,
  ) async {
    // DiveSplitService.split() throws for a source that does not belong to
    // the dive, and it also refuses a dive whose stored series this build
    // cannot decode. Either way the diver must be told: the repair used to
    // run outside any try/catch, so the tap silently did nothing and the
    // finding stayed open forever.
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'r-splitsource',
            detectorId: 'source_conflict',
            category: QualityCategory.source,
            params: const {
              'sourceId': 's1',
              'primaryMaxDepth': 30.0,
              'sourceMaxDepth': 28.0,
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // Split is not the card's primary action; expand the card to reach it.
    // Tap the title rather than the tile's center: the trailing primary
    // button is wide enough to sit under it.
    await tester.tap(find.text('Conflicting sources'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Split into separate dives'));
    await tester.pumpAndSettle();

    expect(find.text('Split failed'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('combine-split repair opens the combine dialog', (tester) async {
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'r-split',
            diveId: 'd1',
            relatedDiveId: 'd2',
            detectorId: 'split_pair',
            category: QualityCategory.time,
            params: const {'gapSeconds': 120},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    expect(find.byType(CombineDivesDialog), findsOneWidget);
    // Dismiss the barrier so the dialog route closes cleanly.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
  });

  testWidgets('reassign-series repair no-ops when the dive is missing', (
    tester,
  ) async {
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'r-reassign',
            detectorId: 'tank_assignment',
            category: QualityCategory.tank,
            params: const {'tankId': 't1'},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    // No dive row => the tank picker returns null and the action returns
    // without a SnackBar; the page stays intact.
    expect(find.text('Wrong cylinder'), findsOneWidget);
  });

  testWidgets('reassign-series repair opens the tank picker', (tester) async {
    final t = DateTime.utc(2026, 7, 1, 10);
    await DiveRepository().createDive(
      domain.Dive(
        id: 'd1',
        dateTime: t,
        entryTime: t,
        tanks: const [
          domain.DiveTank(id: 't1', order: 0),
          domain.DiveTank(id: 't2', order: 1),
        ],
      ),
    );
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        findings: [
          _f(
            id: 'r-reassign2',
            detectorId: 'tank_assignment',
            category: QualityCategory.tank,
            params: const {'tankId': 't1'},
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton).first);
    await tester.pumpAndSettle();

    // The picker lists the dive's other tank; choosing it dispatches the
    // reassignment (reported via a SnackBar).
    await tester.tap(find.text('Tank 2'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsWidgets);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });
}
