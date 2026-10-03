import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_detail_page.dart';
import 'package:submersion/features/dive_computer/presentation/providers/raw_dive_data_providers.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_raw_dive_data_service.dart';
import '../../../../helpers/mock_providers.dart';

class _MockDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _MockDiveComputerNotifier() : super(const AsyncValue.data(<DiveComputer>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// The raw data counter on a computer's page offers to discard that
/// computer's raw bytes (issue #1376).
void main() {
  late FakeRawDiveDataService service;

  final computer = DiveComputer(
    id: 'comp-1',
    name: 'My Perdix',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(
    () => service = FakeRawDiveDataService()
      ..cleared = 4
      // 5 source rows on the counter, 4 dives: one dive holds two of this
      // computer's sources. The dialog and the snackbar speak in dives.
      ..usage = (diveCount: 4, storedBytes: 2048),
  );

  Future<void> pump(
    WidgetTester tester, {
    required ({int withRawData, int withoutRawData}) counts,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      initialLocation: '/dive-computers/comp-1',
      routes: [
        GoRoute(
          path: '/dive-computers/:id',
          builder: (context, state) =>
              DeviceDetailPage(computerId: state.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveComputerNotifierProvider.overrideWith(
            (ref) => _MockDiveComputerNotifier(),
          ),
          diveComputerByIdProvider(
            'comp-1',
          ).overrideWith((ref) async => computer),
          rawDataCountProvider('comp-1').overrideWith((ref) async => counts),
          rawDiveDataServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const button = ValueKey('discard_raw_data_button');

  testWidgets('is offered beside the raw data counter', (tester) async {
    await pump(tester, counts: (withRawData: 5, withoutRawData: 0));

    expect(find.text('5 dives with raw data'), findsOneWidget);
    expect(find.byKey(button), findsOneWidget);
  });

  testWidgets('is not offered when the computer keeps no raw data', (
    tester,
  ) async {
    await pump(tester, counts: (withRawData: 0, withoutRawData: 4));

    expect(find.byKey(button), findsNothing);
  });

  testWidgets('confirming discards only this computer\'s raw data', (
    tester,
  ) async {
    await pump(tester, counts: (withRawData: 5, withoutRawData: 0));

    await tester.ensureVisible(find.byKey(button));
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('kept for 4 dives from My Perdix?'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Discard'),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.usageRequests, ['comp-1']);
    expect(service.calls, ['comp-1']);
    expect(find.text('Discarded raw data for 4 dives'), findsOneWidget);
  });

  testWidgets('a failed count says so instead of opening the dialog', (
    tester,
  ) async {
    service.usageFailure = StateError('database is locked');
    await pump(tester, counts: (withRawData: 5, withoutRawData: 0));

    await tester.ensureVisible(find.byKey(button));
    await tester.tap(find.byKey(button));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(service.calls, isEmpty);
    expect(find.text('Could not discard raw data'), findsOneWidget);
  });
}
