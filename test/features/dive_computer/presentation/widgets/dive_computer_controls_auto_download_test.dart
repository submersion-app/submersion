import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_controls.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const _computerId = 'comp-1';
const _optOutKey = ValueKey('dive_computer_auto_download_disabled');

class _MockDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _MockDiveComputerNotifier() : super(const AsyncValue.data(<DiveComputer>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

DiveComputer _computer({String? connectionType, String? model = 'Perdix 2'}) {
  final now = DateTime(2026, 1, 1);
  return DiveComputer(
    id: _computerId,
    name: 'My computer',
    manufacturer: 'Shearwater',
    model: model,
    connectionType: connectionType,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _build(DiveComputer computer) {
  final router = GoRouter(
    initialLocation: '/dive-computers/$_computerId',
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
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      diveComputerNotifierProvider.overrideWith(
        (ref) => _MockDiveComputerNotifier(),
      ),
      diveComputerByIdProvider(
        _computerId,
      ).overrideWith((ref) async => computer),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// The opt-out from the passive auto-connect scan (issue #3361) is offered
/// only for a computer that scan can find, where it does something.
void main() {
  testWidgets('a Bluetooth computer offers the opt-out', (tester) async {
    await tester.pumpWidget(_build(_computer(connectionType: 'ble')));
    await tester.pumpAndSettle();

    expect(find.byKey(_optOutKey), findsOneWidget);
  });

  testWidgets('a USB computer does not', (tester) async {
    await tester.pumpWidget(_build(_computer(connectionType: 'usb')));
    await tester.pumpAndSettle();

    expect(find.byKey(_optOutKey), findsNothing);
  });

  testWidgets('nor does a record imported from a file', (tester) async {
    // No transport and no address: nothing a scan could look for.
    await tester.pumpWidget(_build(_computer()));
    await tester.pumpAndSettle();

    expect(find.byKey(_optOutKey), findsNothing);
  });
}
