import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_state_store.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/presentation/pages/data_quality_inbox_page.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_card.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/widgets/combine_dives_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/l10n_test_helpers.dart';
import '../../../helpers/test_database.dart';

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
  required String detectorId,
  required QualityCategory category,
  Map<String, Object?> params = const {},
  QualitySeverity severity = QualitySeverity.warning,
}) => QualityFinding(
  id: id,
  diveId: diveId,
  relatedDiveId: relatedDiveId,
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DataQualityInboxPage(),
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
Widget _scope(
  SharedPreferences prefs, {
  List<QualityFinding> findings = const [],
  QualityScanService? scanService,
  QualityScanStateStore? store,
  String? filterDiveId,
}) => ProviderScope(
  overrides: [
    qualityFindingsRepositoryProvider.overrideWithValue(
      _FakeFindingsRepository(List.of(findings)),
    ),
    sharedPreferencesProvider.overrideWithValue(prefs),
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    if (scanService != null)
      qualityScanServiceProvider.overrideWithValue(scanService),
    if (store != null) qualityScanStateStoreProvider.overrideWithValue(store),
  ],
  child: localizedMaterialApp(
    home: DataQualityInboxPage(filterDiveId: filterDiveId),
  ),
);

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
            params: const {'deltaC': 6.0},
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
    // Single dive group header (falls back to the raw dive id, no dive name).
    expect(find.text('d1'), findsOneWidget);
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
    final prefs = await _prefs();
    await tester.pumpWidget(
      _scope(
        prefs,
        // watchFindings emits in updatedAt order (not by dive), so d1's two
        // findings straddle d2's. Grouping must still yield a single d1 header
        // (no dive seeded -> the header falls back to rendering the dive id).
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

    // Exactly one header per dive despite the interleaving.
    expect(find.text('d1'), findsOneWidget);
    expect(find.text('d2'), findsOneWidget);
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
      params: const {'deltaC': 6.0},
    ),
    'convert temperature': _f(
      id: 'r-convert',
      detectorId: 'temp_anomaly',
      category: QualityCategory.temperature,
      params: const {'minTempC': 250.0, 'maxTempC': 260.0},
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
