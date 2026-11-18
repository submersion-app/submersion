import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_controls.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _MockDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _MockDiveComputerNotifier() : super(const AsyncValue.data(<DiveComputer>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// A computer's page counts its raw data for re-parsing but no longer offers
/// to discard it: that moved to Settings > Data > Data tools > Raw dive
/// computer data (issue #4590).
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

  testWidgets('offers re-parsing but no raw data discard', (tester) async {
    await pump(tester, counts: (withRawData: 5, withoutRawData: 0));

    expect(find.text('5 dives with raw data'), findsOneWidget);
    expect(find.text('Re-parse all dives'), findsOneWidget);
    expect(find.byKey(const ValueKey('discard_raw_data_button')), findsNothing);
    expect(find.text('Discard raw data'), findsNothing);
  });
}
