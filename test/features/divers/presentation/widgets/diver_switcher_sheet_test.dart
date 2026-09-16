import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/widgets/diver_switcher_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _StubDiverListNotifier extends StateNotifier<AsyncValue<List<Diver>>>
    implements DiverListNotifier {
  _StubDiverListNotifier(List<Diver> divers) : super(AsyncValue.data(divers));

  @override
  Future<void> refresh() async {}
  @override
  Future<Diver> addDiver(Diver diver) async => diver;
  @override
  Future<void> updateDiver(Diver diver) async {}
  @override
  Future<DeleteDiverResult> deleteDiver(String id) async {
    return const DeleteDiverResult(
      reassignedTripsCount: 0,
      reassignedSitesCount: 0,
    );
  }

  @override
  Future<void> setAsDefault(String id) async {}
}

Diver _diver(String id, String name) => Diver(
  id: id,
  name: name,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

const _newDiverStub = 'new diver page stub';

void main() {
  late MockCurrentDiverIdNotifier currentDiver;

  Widget buildHost({List<Diver>? divers}) {
    currentDiver = MockCurrentDiverIdNotifier();
    currentDiver.setCurrentDiver('a');

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDiverSwitcherSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/settings/diver-profile/new',
          builder: (context, state) =>
              const Scaffold(body: Text(_newDiverStub)),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        currentDiverIdProvider.overrideWith((ref) => currentDiver),
        diverListNotifierProvider.overrideWith(
          (ref) => _StubDiverListNotifier(
            divers ?? [_diver('a', 'Alice Ng'), _diver('b', 'Bob Ray')],
          ),
        ),
      ],
      child: MaterialApp.router(
        locale: const Locale('en'),
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester, {List<Diver>? divers}) async {
    await tester.pumpWidget(buildHost(divers: divers));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every diver and checks only the active one', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Switch Diver'), findsOneWidget);
    expect(find.text('Alice Ng'), findsOneWidget);
    expect(find.text('Bob Ray'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Alice Ng'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping another diver switches, closes, and confirms', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Bob Ray'));
    await tester.pumpAndSettle();

    expect(currentDiver.state, 'b');
    expect(find.text('Switch Diver'), findsNothing);
    expect(find.text('Switched to Bob Ray'), findsOneWidget);
  });

  testWidgets('offers an Add New Diver row that opens the new diver page', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Add New Diver'));
    await tester.pumpAndSettle();

    expect(find.text('Switch Diver'), findsNothing);
    expect(find.text(_newDiverStub), findsOneWidget);
  });

  testWidgets('still offers Add New Diver when only one profile exists', (
    tester,
  ) async {
    await openSheet(tester, divers: [_diver('a', 'Alice Ng')]);

    expect(find.text('Alice Ng'), findsOneWidget);
    expect(find.text('Add New Diver'), findsOneWidget);

    await tester.tap(find.text('Add New Diver'));
    await tester.pumpAndSettle();

    expect(find.text(_newDiverStub), findsOneWidget);
  });
}
