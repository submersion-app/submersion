import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/clock_sync.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_detail_page.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _computerId = 'comp-1';
const _overrideKey = ValueKey('clock_sync_override');
const _checkAgainKey = ValueKey('clock_sync_check_again');

class _MockDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _MockDiveComputerNotifier() : super(const AsyncValue.data(<DiveComputer>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

DiveComputer _computer() {
  final now = DateTime(2026, 1, 1);
  return DiveComputer(
    id: _computerId,
    name: 'My Perdix',
    manufacturer: 'Shearwater',
    model: 'Perdix 2',
    serialNumber: 'SN-12345',
    connectionType: 'ble',
    createdAt: now,
    updatedAt: now,
  );
}

Widget _build() {
  final router = GoRouter(
    initialLocation: '/dive-computers/$_computerId',
    routes: [
      GoRoute(
        path: '/dive-computers/:id',
        builder: (context, state) =>
            DeviceDetailPage(computerId: state.pathParameters['id']!),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      diveComputerNotifierProvider.overrideWith(
        (ref) => _MockDiveComputerNotifier(),
      ),
      diveComputerByIdProvider(
        _computerId,
      ).overrideWith((ref) async => _computer()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DeviceDetailPage)));

void main() {
  testWidgets('shows the override control defaulting to the app setting', (
    tester,
  ) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_overrideKey), 200);

    expect(find.text('Clock sync'), findsOneWidget);
    final control = tester.widget<SegmentedButton<ClockSyncOverride>>(
      find.byKey(_overrideKey),
    );
    expect(control.selected, {ClockSyncOverride.inherit});
    expect(find.text('App setting: off'), findsOneWidget);
    expect(find.byKey(_checkAgainKey), findsNothing);
  });

  testWidgets('choosing Always stores the override', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_overrideKey), 200);

    await tester.tap(find.text('Always'));
    await tester.pumpAndSettle();

    expect(
      _containerOf(
        tester,
      ).read(clockSyncSettingsNotifierProvider).overrideFor(_computerId),
      ClockSyncOverride.always,
    );
  });

  testWidgets('names the app setting when it is on', (tester) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    await _containerOf(
      tester,
    ).read(clockSyncSettingsNotifierProvider.notifier).setGlobalEnabled(true);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_overrideKey), 200);

    expect(find.text('App setting: on'), findsOneWidget);
  });

  testWidgets('says so when the model is known to support sync', (
    tester,
  ) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    await _containerOf(tester)
        .read(clockSyncSettingsNotifierProvider.notifier)
        .recordSupport(_computerId, ClockSyncStatus.synced);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_overrideKey), 200);

    expect(find.text('Supported by this model'), findsOneWidget);
    expect(find.byKey(_overrideKey), findsOneWidget);
  });

  testWidgets('replaces the control with a note for an unsupported model', (
    tester,
  ) async {
    await tester.pumpWidget(_build());
    await tester.pumpAndSettle();
    await _containerOf(tester)
        .read(clockSyncSettingsNotifierProvider.notifier)
        .recordSupport(_computerId, ClockSyncStatus.unsupported);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(_checkAgainKey), 200);

    expect(find.text('This model does not support clock sync'), findsOneWidget);
    expect(find.byKey(_overrideKey), findsNothing);

    await tester.tap(find.byKey(_checkAgainKey));
    await tester.pumpAndSettle();

    expect(
      _containerOf(
        tester,
      ).read(clockSyncSettingsNotifierProvider).supportFor(_computerId),
      ClockSyncSupport.unknown,
    );
    expect(find.byKey(_overrideKey), findsOneWidget);
    expect(find.byKey(_checkAgainKey), findsNothing);
  });
}
