import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_reset_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/terrain_data_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A [MapReloadNotifier] whose [start] is fully controlled by the test, so
/// the reload flow's progress UI and outcome messages can be driven without
/// a real bathymetry repository or dive site list.
class _FakeMapReloadNotifier extends MapReloadNotifier {
  _FakeMapReloadNotifier(super.ref, {required this.onStart});

  final Future<void> Function(_FakeMapReloadNotifier self) onStart;
  int cancelCalls = 0;

  @override
  Future<void> start() => onStart(this);

  @override
  void cancel() {
    cancelCalls++;
    super.cancel();
  }

  void setTestState(MapReloadState value) => state = value;
}

void main() {
  Future<void> pumpSection(
    WidgetTester tester, {
    required List<Override> extraOverrides,
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...base, ...extraOverrides],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: TerrainDataSection()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders its header and all four actions', (tester) async {
    await pumpSection(
      tester,
      extraOverrides: [
        bathymetryRepositoryProvider.overrideWithValue(null),
        swissBathyTileCacheRepositoryProvider.overrideWithValue(null),
        knownDiveSiteLocationsProvider.overrideWith((ref) async => const []),
      ],
    );

    expect(find.text('3D terrain'), findsOneWidget);
    expect(find.text('Update Existing Map Data'), findsOneWidget);
    expect(find.text('Delete data'), findsOneWidget);
    expect(find.text('Reset remaining bathymetry data'), findsOneWidget);
    expect(find.text('Reload map data'), findsOneWidget);
  });

  testWidgets(
    'confirming the swissBATHY3D delete action calls the clear provider '
    'and shows a confirmation snackbar',
    (tester) async {
      var cleared = false;
      await pumpSection(
        tester,
        extraOverrides: [
          bathymetryRepositoryProvider.overrideWithValue(null),
          swissBathyTileCacheRepositoryProvider.overrideWithValue(null),
          knownDiveSiteLocationsProvider.overrideWith((ref) async => const []),
          swissBathyClearProvider.overrideWithValue(() async {
            cleared = true;
          }),
        ],
      );

      await tester.tap(find.text('Delete data'));
      await tester.pumpAndSettle();

      // The confirm dialog is up; nothing has run yet.
      expect(cleared, isFalse);
      expect(find.text('Delete swissBATHY3D data?'), findsOneWidget);

      await tester.tap(find.text('Delete data').last);
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
      expect(find.text('swissBATHY3D data deleted'), findsOneWidget);
    },
  );

  testWidgets('cancelling the confirm dialog does not run the clear action', (
    tester,
  ) async {
    var cleared = false;
    await pumpSection(
      tester,
      extraOverrides: [
        bathymetryRepositoryProvider.overrideWithValue(null),
        swissBathyTileCacheRepositoryProvider.overrideWithValue(null),
        knownDiveSiteLocationsProvider.overrideWith((ref) async => const []),
        bathymetryOtherSourcesClearProvider.overrideWithValue(() async {
          cleared = true;
        }),
      ],
    );

    await tester.tap(find.text('Reset remaining bathymetry data').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(cleared, isFalse);
  });

  testWidgets(
    'the refresh tile is disabled while a delete/reset action is running '
    '(regression: a shared busy flag used to leave it tappable, letting it '
    'start concurrently with the delete)',
    (tester) async {
      final clearStarted = Completer<void>();
      final clearGate = Completer<void>();
      var refreshCalls = 0;
      await pumpSection(
        tester,
        extraOverrides: [
          bathymetryRepositoryProvider.overrideWithValue(null),
          swissBathyTileCacheRepositoryProvider.overrideWithValue(null),
          knownDiveSiteLocationsProvider.overrideWith((ref) async => const []),
          swissBathyClearProvider.overrideWithValue(() async {
            clearStarted.complete();
            await clearGate.future;
          }),
          swissBathyManualRefreshProvider.overrideWithValue(() async {
            refreshCalls++;
            return null;
          }),
        ],
      );

      await tester.tap(find.text('Delete data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete data').last);
      await tester.pump();
      await clearStarted.future;
      await tester.pump();

      // The delete is now in flight. Tapping the refresh tile must do
      // nothing: IgnorePointer should be blocking it, not just dimming it --
      // the tap is expected to miss its target entirely, which is exactly
      // what warnIfMissed: false is here to confirm without flagging it as
      // a test-authoring mistake.
      await tester.tap(
        find.text('Update Existing Map Data'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(refreshCalls, 0);

      clearGate.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'confirming the reload dialog shows per-site progress, a busy notice, '
    'and a done message once it finishes, and the cancel button forwards '
    'to the notifier',
    (tester) async {
      final startGate = Completer<void>();
      late _FakeMapReloadNotifier fake;
      await pumpSection(
        tester,
        extraOverrides: [
          bathymetryRepositoryProvider.overrideWithValue(null),
          swissBathyTileCacheRepositoryProvider.overrideWithValue(null),
          knownDiveSiteLocationsProvider.overrideWith((ref) async => const []),
          mapReloadProvider.overrideWith((ref) {
            fake = _FakeMapReloadNotifier(
              ref,
              onStart: (self) async {
                self.setTestState(
                  self.state.copyWith(
                    isRunning: true,
                    total: 2,
                    completed: 1,
                    startedAt: DateTime.now().subtract(
                      const Duration(seconds: 4),
                    ),
                  ),
                );
                await startGate.future;
                self.setTestState(
                  self.state.copyWith(isRunning: false, completed: 2),
                );
              },
            );
            return fake;
          }),
        ],
      );

      await tester.tap(find.text('Reload map data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reload'));
      await tester.pumpAndSettle();

      expect(find.text('1 of 2 dive sites'), findsOneWidget);
      expect(
        find.text(
          'Another 3D terrain action is running. Please wait until it finishes.',
        ),
        findsOneWidget,
      );

      final cancelButton = find.widgetWithText(TextButton, 'Cancel');
      await tester.ensureVisible(cancelButton);
      await tester.tap(cancelButton);
      expect(fake.cancelCalls, 1);

      startGate.complete();
      await tester.pumpAndSettle();

      expect(
        find.text('Map data reloaded for every dive site'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows no remaining-time estimate once every site is done, instead of '
    'rounding an empty queue up to "about 1 second remaining" (regression: '
    'the formatter clamped a genuine zero to one)',
    (tester) async {
      final startGate = Completer<void>();
      await pumpSection(
        tester,
        extraOverrides: [
          bathymetryRepositoryProvider.overrideWithValue(null),
          swissBathyTileCacheRepositoryProvider.overrideWithValue(null),
          knownDiveSiteLocationsProvider.overrideWith((ref) async => const []),
          mapReloadProvider.overrideWith(
            (ref) => _FakeMapReloadNotifier(
              ref,
              onStart: (self) async {
                // The last site has completed but the run has not torn down
                // yet, so the progress card is still on screen with nothing
                // left to wait for.
                self.setTestState(
                  self.state.copyWith(
                    isRunning: true,
                    total: 2,
                    completed: 2,
                    startedAt: DateTime.now().subtract(
                      const Duration(seconds: 4),
                    ),
                  ),
                );
                await startGate.future;
                self.setTestState(self.state.copyWith(isRunning: false));
              },
            ),
          ),
        ],
      );

      await tester.tap(find.text('Reload map data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reload'));
      await tester.pump();

      expect(find.text('2 of 2 dive sites'), findsOneWidget);
      expect(find.text('about 1 second remaining'), findsNothing);
      expect(find.textContaining('second remaining'), findsNothing);
      expect(find.textContaining('seconds remaining'), findsNothing);

      startGate.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'shows the warming-phase text while lakes are being warmed, and a '
    'failure message when the reload throws',
    (tester) async {
      final startGate = Completer<void>();
      await pumpSection(
        tester,
        extraOverrides: [
          bathymetryRepositoryProvider.overrideWithValue(null),
          swissBathyTileCacheRepositoryProvider.overrideWithValue(null),
          knownDiveSiteLocationsProvider.overrideWith((ref) async => const []),
          mapReloadProvider.overrideWith(
            (ref) => _FakeMapReloadNotifier(
              ref,
              onStart: (self) async {
                self.setTestState(
                  self.state.copyWith(
                    isRunning: true,
                    overallStartedAt: DateTime.now().subtract(
                      const Duration(seconds: 2),
                    ),
                    warmStartedAt: DateTime.now(),
                    warmingLakeName: 'Lake Zurich',
                    warmingLakeIndex: 1,
                    warmingLakeTotal: 3,
                  ),
                );
                await startGate.future;
                self.setTestState(
                  self.state.copyWith(isRunning: false, error: 'boom'),
                );
              },
            ),
          ),
        ],
      );

      await tester.tap(find.text('Reload map data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reload'));
      await tester.pump();

      expect(find.text('Preparing: lake 1 of 3 (Lake Zurich)'), findsOneWidget);

      startGate.complete();
      await tester.pumpAndSettle();

      expect(
        find.text('Reload failed; some dive sites may not have been reloaded'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'confirming the "reset remaining bathymetry data" action calls the '
    'clear provider and shows a confirmation snackbar',
    (tester) async {
      var cleared = false;
      await pumpSection(
        tester,
        extraOverrides: [
          bathymetryRepositoryProvider.overrideWithValue(null),
          swissBathyTileCacheRepositoryProvider.overrideWithValue(null),
          knownDiveSiteLocationsProvider.overrideWith((ref) async => const []),
          bathymetryOtherSourcesClearProvider.overrideWithValue(() async {
            cleared = true;
          }),
        ],
      );

      await tester.tap(find.text('Reset remaining bathymetry data').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset remaining bathymetry data').last);
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
      expect(find.text('Remaining bathymetry data reset'), findsOneWidget);
    },
  );

  testWidgets('shows an error snackbar when a delete/reset action throws '
      '(regression: a throwing action used to leave no signal at all)', (
    tester,
  ) async {
    await pumpSection(
      tester,
      extraOverrides: [
        bathymetryRepositoryProvider.overrideWithValue(null),
        swissBathyTileCacheRepositoryProvider.overrideWithValue(null),
        knownDiveSiteLocationsProvider.overrideWith((ref) async => const []),
        swissBathyClearProvider.overrideWithValue(() async {
          throw Exception('disk full');
        }),
      ],
    );

    await tester.tap(find.text('Delete data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete data').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('disk full'), findsOneWidget);
  });
}
