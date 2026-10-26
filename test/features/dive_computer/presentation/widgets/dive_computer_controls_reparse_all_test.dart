import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_controls.dart';
import 'package:submersion/features/dive_computer/presentation/providers/raw_dive_data_providers.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_raw_dive_data_service.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

class _MockDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _MockDiveComputerNotifier() : super(const AsyncValue.data(<DiveComputer>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Records the re-parse the button asks for, returning a fixed outcome.
class _FakeReparseService extends ReparseService {
  _FakeReparseService(this.outcome) : super(db: createTestDatabase());

  final ({int succeeded, int failed}) outcome;
  final reparsed = <String>[];

  @override
  Future<({int withRawData, int withoutRawData})> getRawDataCounts(
    String computerId,
  ) async => (withRawData: 3, withoutRawData: 0);

  @override
  Future<({int succeeded, int failed})> reparseAllForComputer(
    String computerId, {
    required Future<pigeon.ParsedDive> Function(
      String vendor,
      String product,
      int model,
      Uint8List rawData,
    )
    parseFn,
  }) async {
    reparsed.add(computerId);
    return outcome;
  }
}

/// "Re-parse all dives" on a computer's Equipment page (issue #3676 moved
/// it there from the old computer page).
void main() {
  final computer = DiveComputer(
    id: 'comp-1',
    name: 'My Perdix',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(
    WidgetTester tester, {
    required ({int withRawData, int withoutRawData}) counts,
    required _FakeReparseService service,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    addTearDown(service.db.close);
    final router = GoRouter(
      initialLocation: '/dive-computers/comp-1',
      routes: [
        GoRoute(
          path: '/dive-computers/:id',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: DiveComputerControls(
                computerId: state.pathParameters['id']!,
              ),
            ),
          ),
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
          rawDiveDataServiceProvider.overrideWithValue(
            FakeRawDiveDataService(),
          ),
          reparseServiceProvider.overrideWithValue(service),
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

  testWidgets('counts the dives without raw data beside the button', (
    tester,
  ) async {
    await pump(
      tester,
      counts: (withRawData: 3, withoutRawData: 2),
      service: _FakeReparseService((succeeded: 3, failed: 0)),
    );

    expect(find.text('Re-parse all dives'), findsOneWidget);
    expect(find.text('3 dives with raw data (2 without)'), findsOneWidget);
  });

  testWidgets('confirming re-parses this computer and reports success', (
    tester,
  ) async {
    final service = _FakeReparseService((succeeded: 3, failed: 0));
    await pump(
      tester,
      counts: (withRawData: 3, withoutRawData: 0),
      service: service,
    );

    await tester.tap(find.text('Re-parse all dives'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Re-parse'));
    await tester.pumpAndSettle();

    expect(service.reparsed, ['comp-1']);
    expect(find.text('Re-parsed 3 dives successfully'), findsOneWidget);
  });

  testWidgets('a partial re-parse says how many failed', (tester) async {
    final service = _FakeReparseService((succeeded: 2, failed: 1));
    await pump(
      tester,
      counts: (withRawData: 3, withoutRawData: 0),
      service: service,
    );

    await tester.tap(find.text('Re-parse all dives'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Re-parse'));
    await tester.pumpAndSettle();

    expect(find.text('Re-parsed 2 of 3 dives. 1 failed.'), findsOneWidget);
  });

  testWidgets('cancelling re-parses nothing', (tester) async {
    final service = _FakeReparseService((succeeded: 3, failed: 0));
    await pump(
      tester,
      counts: (withRawData: 3, withoutRawData: 0),
      service: service,
    );

    await tester.tap(find.text('Re-parse all dives'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.reparsed, isEmpty);
  });
}
