import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart'
    hide DiscoveredDevice;

import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/dive_computer/presentation/providers/discovery_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/download_step_widget.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

@GenerateMocks([DiveComputerRepository, DiveComputerService])
import 'download_step_cutoff_prompt_test.mocks.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

DiscoveredDevice _testDevice() => DiscoveredDevice(
  id: 'test-device',
  name: 'Test Device',
  connectionType: DeviceConnectionType.usb,
  address: 'COM3',
  discoveredAt: DateTime(2026, 1, 1),
);

final _computerWithoutFingerprint = DiveComputer(
  id: 'computer-1',
  name: 'My Computer',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final _computerWithFingerprint = DiveComputer(
  id: 'computer-2',
  name: 'My Computer',
  lastDiveFingerprint: 'stored-fingerprint',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ProviderContainer _buildContainer(MockDiveComputerService mockService) {
  final container = ProviderContainer(
    overrides: [
      diveComputerServiceProvider.overrideWithValue(mockService),
      diveComputerRepositoryProvider.overrideWithValue(
        MockDiveComputerRepository(),
      ),
    ],
  );
  return container;
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  DiscoveredDevice? device,
  DiveComputer? computer,
  DateTime? firstSyncCutoffDefault,
  bool forceFullDownload = false,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DownloadStepWidget(
            device: device ?? _testDevice(),
            computer: computer,
            forceFullDownload: forceFullDownload,
            firstSyncCutoffDefault: firstSyncCutoffDefault,
            onComplete: () {},
            onError: (_) {},
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockDiveComputerService mockService;
  late ProviderContainer container;

  // DateFormat.yMMMd() resolves against the Intl.defaultLocale process
  // global (set from the app locale in production), not MaterialApp.locale.
  // Pin it so the formatted-date assertions state their real dependency.
  late String? previousLocale;

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';

    mockService = MockDiveComputerService();
    when(mockService.downloadEvents).thenAnswer((_) => const Stream.empty());
    when(
      mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
    ).thenAnswer((_) async {});

    container = _buildContainer(mockService);
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
    container.dispose();
  });

  group('DownloadStepWidget first-sync cutoff prompt', () {
    testWidgets(
      'shows prompt instead of auto-starting when no fingerprint and a '
      'cutoff default exists',
      (tester) async {
        await _pump(
          tester,
          container,
          computer: _computerWithoutFingerprint,
          firstSyncCutoffDefault: DateTime.utc(2026, 6, 12, 14, 30),
        );
        await tester.pump();

        expect(find.text('Download new dives'), findsOneWidget);
        expect(find.text('Download all dives'), findsOneWidget);
        verifyNever(
          mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
        );
      },
    );

    testWidgets('auto-starts when a fingerprint exists', (tester) async {
      await _pump(
        tester,
        container,
        computer: _computerWithFingerprint,
        firstSyncCutoffDefault: DateTime.utc(2026, 6, 12),
      );
      await tester.pump();

      verify(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      ).called(1);
      expect(find.text('Download new dives'), findsNothing);
      expect(find.text('Download all dives'), findsNothing);
    });

    testWidgets('auto-starts when cutoff default is null (empty log)', (
      tester,
    ) async {
      await _pump(
        tester,
        container,
        computer: _computerWithoutFingerprint,
        firstSyncCutoffDefault: null,
      );
      await tester.pump();

      verify(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      ).called(1);
      expect(find.text('Download new dives'), findsNothing);
    });

    testWidgets('auto-starts when forceFullDownload is set', (tester) async {
      await _pump(
        tester,
        container,
        computer: _computerWithoutFingerprint,
        firstSyncCutoffDefault: DateTime.utc(2026, 6, 12),
        forceFullDownload: true,
      );
      await tester.pump();

      verify(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      ).called(1);
      expect(find.text('Download new dives'), findsNothing);
    });

    testWidgets('"Download new dives" starts with the cutoff set', (
      tester,
    ) async {
      final cutoff = DateTime.utc(2026, 6, 12, 14, 30);
      await _pump(
        tester,
        container,
        computer: _computerWithoutFingerprint,
        firstSyncCutoffDefault: cutoff,
      );
      await tester.pump();

      await tester.tap(find.text('Download new dives'));
      await tester.pump();

      verify(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      ).called(1);
      expect(container.read(downloadNotifierProvider).sinceCutoff, cutoff);
    });

    testWidgets('"Download all dives" starts with no cutoff', (tester) async {
      final cutoff = DateTime.utc(2026, 6, 12, 14, 30);
      await _pump(
        tester,
        container,
        computer: _computerWithoutFingerprint,
        firstSyncCutoffDefault: cutoff,
      );
      await tester.pump();

      await tester.tap(find.text('Download all dives'));
      await tester.pump();

      verify(
        mockService.startDownload(any, fingerprint: anyNamed('fingerprint')),
      ).called(1);
      final state = container.read(downloadNotifierProvider);
      expect(state.sinceCutoff, isNull);
      // "Download all dives" must not touch newDivesOnly (unlike
      // forceFullDownload); the fingerprint bypass is a separate concern.
      expect(state.newDivesOnly, isTrue);
    });

    testWidgets(
      'tapping the date row opens a date picker and updates the label',
      (tester) async {
        final cutoff = DateTime.utc(2026, 6, 12, 14, 30);
        await _pump(
          tester,
          container,
          computer: _computerWithoutFingerprint,
          firstSyncCutoffDefault: cutoff,
        );
        await tester.pump();

        final initialLabel = DateFormat.yMMMd().format(cutoff);
        expect(find.textContaining(initialLabel), findsOneWidget);

        await tester.tap(find.byKey(const Key('cutoff-date-row')));
        await tester.pumpAndSettle();

        // Pick a different day within the displayed month (June 2026).
        await tester.tap(find.text('20').first);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        final pickedDayStartOfDay = DateTime.utc(2026, 6, 20);
        final newLabel = DateFormat.yMMMd().format(pickedDayStartOfDay);
        expect(find.textContaining(newLabel), findsOneWidget);
        expect(find.textContaining(initialLabel), findsNothing);

        await tester.tap(find.text('Download new dives'));
        await tester.pump();

        expect(
          container.read(downloadNotifierProvider).sinceCutoff,
          pickedDayStartOfDay,
        );
      },
    );

    testWidgets(
      'tapping the date row does not crash when the cutoff default is '
      'ahead of the local calendar day (timezone skew)',
      (tester) async {
        // The default cutoff comes from the newest dive's stored timestamp,
        // which can land after `DateTime.now()` on this device when the
        // dive was logged in a timezone ahead of it. showDatePicker asserts
        // `initialDate <= lastDate`; a naive `lastDate: DateTime.now()`
        // would fail that assertion here.
        final futureCutoff = DateTime.now().add(const Duration(days: 2));
        await _pump(
          tester,
          container,
          computer: _computerWithoutFingerprint,
          firstSyncCutoffDefault: futureCutoff,
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('cutoff-date-row')));
        await tester.pumpAndSettle();

        // No assertion/exception surfaced (tester would have thrown by
        // now) and the picker actually opened.
        expect(tester.takeException(), isNull);
        expect(find.byType(DatePickerDialog), findsOneWidget);
      },
    );
  });
}
