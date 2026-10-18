import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/media_store/network_status_service.dart';
import 'package:submersion/core/services/storage/gc/cloud_usage_measure.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_coordinator.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_store.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_gc_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/cloud_storage_group.dart';
import 'package:submersion/features/settings/presentation/widgets/storage_reclaim_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Records the triggers it is asked to run, and holds each run open until
/// [release] so a test can look at the page mid-run.
class _RecordingCoordinator extends StorageGcCoordinator {
  _RecordingCoordinator(StorageGcStore store)
    : super(
        deviceSweeps: const [],
        localCacheSweep: (_, {required force}) async {},
        network: () async => NetworkKind.unmetered,
        isSyncBusy: () => false,
        hasTransferringUploads: () async => false,
        mediaSweep: ({required dryRun}) async => null,
        deletesAllowed: () async => false,
        isStoreRegistered: () async => true,
        attachedStoreId: () async => null,
        fleetSweepDue: (_) async => false,
        stampFleetSweep: (_) async {},
        measureSync: () async => null,
        measureLibraries: () async => null,
        store: store,
      );

  final runs = <StorageGcTrigger>[];
  Completer<void>? hold;
  int reclaims = 0;
  CloudDeleteHold? cloudHold;

  @override
  CloudDeleteHold? get lastPassCloudHold => cloudHold;

  @override
  Future<int> run(StorageGcTrigger trigger) async {
    runs.add(trigger);
    await hold?.future;
    return reclaims;
  }
}

void main() {
  late SharedPreferences prefs;
  late _RecordingCoordinator coordinator;
  final at = DateTime(2026, 10, 14, 9, 30);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    coordinator = _RecordingCoordinator(StorageGcStore(prefs));
  });

  Widget harness(
    Widget child, {
    StorageGcView view = const StorageGcView(running: false),
    int deviceReclaimable = 0,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        storageGcCoordinatorProvider.overrideWithValue(coordinator),
        storageGcStateProvider.overrideWith((ref) => Stream.value(view)),
        deviceReclaimableBytesProvider.overrideWith(
          (ref) async => deviceReclaimable,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ListView(children: [child])),
      ),
    );
  }

  group('StorageReclaimCard', () {
    testWidgets('reclaim card shows reclaimable and last reclaimed', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const StorageReclaimCard(),
          deviceReclaimable: 600 * 1024 * 1024,
          view: StorageGcView(
            running: false,
            cloudUsage: CloudUsage(
              scannedAt: at,
              mediaBytes: 1,
              mediaReclaimableBytes: 40 * 1024 * 1024,
            ),
            lastDeviceResult: AreaResult(
              bytes: 210 * 1024 * 1024,
              items: 3,
              at: at,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('About 640 MB can be reclaimed'), findsOneWidget);
      expect(find.textContaining('Last reclaimed 210 MB'), findsOneWidget);
      expect(find.text('Reclaim storage'), findsOneWidget);
    });

    testWidgets('reclaim card says nothing to reclaim at zero', (tester) async {
      await tester.pumpWidget(harness(const StorageReclaimCard()));
      await tester.pumpAndSettle();

      expect(find.text('Nothing to reclaim right now'), findsOneWidget);
      expect(find.textContaining('Last reclaimed'), findsNothing);
    });

    testWidgets('waiting bytes line appears above zero', (tester) async {
      await tester.pumpWidget(
        harness(
          const StorageReclaimCard(),
          view: StorageGcView(
            running: false,
            cloudUsage: CloudUsage(
              scannedAt: at,
              mediaBytes: 1,
              mediaWaitingBytes: 7 * 1024 * 1024,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('7.0 MB more will be reclaimable after the safety wait'),
        findsOneWidget,
      );
    });

    testWidgets('a waiting line held back by sync says so', (tester) async {
      // Deletes deferred until this device catches up wait on a sync, not on
      // the safety wait; saying the latter would send the diver nowhere.
      await tester.pumpWidget(
        harness(
          const StorageReclaimCard(),
          view: StorageGcView(
            running: false,
            cloudUsage: CloudUsage(
              scannedAt: at,
              mediaBytes: 1,
              mediaWaitingBytes: 7 * 1024 * 1024,
              mediaHold: CloudDeleteHold.sync,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          '7.0 MB more will be reclaimable once this device has finished syncing',
        ),
        findsOneWidget,
      );
    });

    // Not every hold clears with a sync: naming the wrong one sends the
    // diver to wait for something that will never come.
    for (final (hold, text) in [
      (
        CloudDeleteHold.unregistered,
        '7.0 MB more will be reclaimable after you reconnect the media store',
      ),
      (
        CloudDeleteHold.uploads,
        '7.0 MB more will be reclaimable once uploads finish',
      ),
    ]) {
      testWidgets('a waiting line held back by ${hold.name} says so', (
        tester,
      ) async {
        await tester.pumpWidget(
          harness(
            const StorageReclaimCard(),
            view: StorageGcView(
              running: false,
              cloudUsage: CloudUsage(
                scannedAt: at,
                mediaBytes: 1,
                mediaWaitingBytes: 7 * 1024 * 1024,
                mediaHold: hold,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets('no waiting line at zero', (tester) async {
      await tester.pumpWidget(harness(const StorageReclaimCard()));
      await tester.pumpAndSettle();
      expect(find.textContaining('after the safety wait'), findsNothing);
    });

    testWidgets(
      'reclaim button runs a manual pass and disables while running',
      (tester) async {
        coordinator.hold = Completer<void>();
        await tester.pumpWidget(harness(const StorageReclaimCard()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reclaim storage'));
        await tester.pump();

        expect(coordinator.runs, [StorageGcTrigger.manual]);
        final button = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(button.onPressed, isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        coordinator.hold!.complete();
        await tester.pumpAndSettle();
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
      },
    );
  });

  testWidgets('the snackbar reports what the pass reclaimed', (tester) async {
    coordinator.reclaims = 600 * 1024 * 1024;
    await tester.pumpWidget(harness(const StorageReclaimCard()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reclaim storage'));
    await tester.pumpAndSettle();

    expect(find.text('Reclaimed 600 MB'), findsOneWidget);
  });

  testWidgets('the snackbar says when cloud deletes were held back', (
    tester,
  ) async {
    coordinator.reclaims = 5 * 1024 * 1024;
    coordinator.cloudHold = CloudDeleteHold.sync;
    await tester.pumpWidget(harness(const StorageReclaimCard()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reclaim storage'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Reclaimed 5.0 MB. The cloud cleanup waits until this device has '
        'finished syncing.',
      ),
      findsOneWidget,
    );
  });

  for (final (hold, text) in [
    (
      CloudDeleteHold.unregistered,
      'Reclaimed 5.0 MB. Reconnect the media store to clean up the cloud.',
    ),
    (
      CloudDeleteHold.uploads,
      'Reclaimed 5.0 MB. The cloud cleanup waits until uploads finish.',
    ),
  ]) {
    testWidgets('the snackbar names a ${hold.name} hold', (tester) async {
      coordinator.reclaims = 5 * 1024 * 1024;
      coordinator.cloudHold = hold;
      await tester.pumpWidget(harness(const StorageReclaimCard()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reclaim storage'));
      await tester.pumpAndSettle();

      expect(find.text(text), findsOneWidget);
    });
  }

  group('CloudStorageGroup', () {
    testWidgets('cloud group shows only areas that are set up', (tester) async {
      await tester.pumpWidget(
        harness(
          const CloudStorageGroup(),
          view: StorageGcView(
            running: false,
            cloudUsage: CloudUsage(
              scannedAt: at,
              mediaBytes: 10 * 1024 * 1024,
              mediaReclaimableBytes: 2 * 1024 * 1024,
              syncBytes: 3 * 1024 * 1024,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('In the Cloud'), findsOneWidget);
      expect(find.text('Media store'), findsOneWidget);
      expect(find.text('10 MB'), findsOneWidget);
      expect(find.text('2.0 MB reclaimable'), findsOneWidget);
      expect(find.text('Database sync'), findsOneWidget);
      expect(find.text('Shared site libraries'), findsNothing);
      expect(find.textContaining('Scanned'), findsOneWidget);
    });

    testWidgets('rescan runs a rescan pass', (tester) async {
      await tester.pumpWidget(
        harness(
          const CloudStorageGroup(),
          view: StorageGcView(
            running: false,
            cloudUsage: CloudUsage(scannedAt: at, syncBytes: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rescan'));
      await tester.pump();

      expect(coordinator.runs, [StorageGcTrigger.rescan]);
    });

    testWidgets('not scanned yet still offers a rescan', (tester) async {
      await tester.pumpWidget(harness(const CloudStorageGroup()));
      await tester.pumpAndSettle();

      expect(find.text('In the Cloud'), findsOneWidget);
      expect(find.text('Not scanned yet'), findsOneWidget);
      expect(find.text('Rescan'), findsOneWidget);
    });

    testWidgets('cloud group stays with Rescan when nothing is set up', (
      tester,
    ) async {
      // A diver who connects sync or a media store later must be able to
      // scan it straight away rather than wait for the weekly measurement.
      await tester.pumpWidget(
        harness(
          const CloudStorageGroup(),
          view: StorageGcView(
            running: false,
            cloudUsage: CloudUsage(scannedAt: at),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('In the Cloud'), findsOneWidget);
      expect(find.text('Media store'), findsNothing);
      expect(find.text('Database sync'), findsNothing);
      expect(find.text('Shared site libraries'), findsNothing);
      expect(find.textContaining('Scanned'), findsOneWidget);

      await tester.tap(find.text('Rescan'));
      await tester.pump();
      expect(coordinator.runs, [StorageGcTrigger.rescan]);
    });
  });
}
