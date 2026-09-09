import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_detail_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _MockDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _MockDiveComputerNotifier() : super(const AsyncValue.data(<DiveComputer>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _computer = DiveComputer(
  id: 'comp-1',
  name: 'My Perdix',
  manufacturer: 'Shearwater',
  model: 'Perdix 2',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

Widget _buildTestWidget({
  required DiveComputer computer,
  required ({int known, int unassigned}) summary,
}) {
  final router = GoRouter(
    initialLocation: '/dive-computers/comp-1',
    routes: [
      GoRoute(
        path: '/dive-computers/:id',
        builder: (context, state) =>
            DeviceDetailPage(computerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/transmitters',
        builder: (context, state) =>
            const Scaffold(body: Text('TRANSMITTERS_PAGE')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      diveComputerNotifierProvider.overrideWith(
        (ref) => _MockDiveComputerNotifier(),
      ),
      diveComputerByIdProvider('comp-1').overrideWith((ref) async => computer),
      transmitterComputerSummaryProvider(
        'comp-1',
      ).overrideWith((ref) async => summary),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
    ),
  );
}

void main() {
  testWidgets('shows known and unassigned counts and opens the registry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestWidget(computer: _computer, summary: (known: 3, unassigned: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Transmitters'), findsOneWidget);
    expect(find.text('3 known, 1 unassigned'), findsOneWidget);

    await tester.tap(find.text('3 known, 1 unassigned'));
    await tester.pumpAndSettle();
    expect(find.text('TRANSMITTERS_PAGE'), findsOneWidget);
  });

  testWidgets('hides the row when the computer has seen no serials', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestWidget(computer: _computer, summary: (known: 0, unassigned: 0)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Transmitters'), findsNothing);
  });
}
