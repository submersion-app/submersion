import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_detail_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
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

DiveComputer _computer({String? equipmentId}) => DiveComputer(
  id: 'comp-1',
  name: 'My Perdix',
  manufacturer: 'Shearwater',
  model: 'Perdix 2',
  equipmentId: equipmentId,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

EquipmentItem _gear() => const EquipmentItem(
  id: 'gear-1',
  name: 'Perdix 2 (wrist)',
  type: EquipmentType.computer,
);

Widget _buildTestWidget({required DiveComputer computer, EquipmentItem? gear}) {
  final router = GoRouter(
    initialLocation: '/dive-computers/comp-1',
    routes: [
      GoRoute(
        path: '/dive-computers/:id',
        builder: (context, state) =>
            DeviceDetailPage(computerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/equipment/:id',
        builder: (context, state) =>
            const Scaffold(body: Text('EQUIPMENT_DETAIL_PAGE')),
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
      equipmentItemProvider('gear-1').overrideWith((ref) async => gear),
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
  testWidgets('shows the linked gear item', (tester) async {
    await tester.pumpWidget(
      _buildTestWidget(
        computer: _computer(equipmentId: 'gear-1'),
        gear: _gear(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perdix 2 (wrist)'), findsOneWidget);
  });

  testWidgets('taps through to the equipment detail page', (tester) async {
    await tester.pumpWidget(
      _buildTestWidget(
        computer: _computer(equipmentId: 'gear-1'),
        gear: _gear(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perdix 2 (wrist)'));
    await tester.pumpAndSettle();

    expect(find.text('EQUIPMENT_DETAIL_PAGE'), findsOneWidget);
  });

  testWidgets('shows no gear row when the twin was deleted', (tester) async {
    // A null equipmentId is what deleting the gear item leaves behind, and it
    // is permanent: nothing re-mints outside a genuine registration.
    await tester.pumpWidget(_buildTestWidget(computer: _computer()));
    await tester.pumpAndSettle();

    expect(find.text('Perdix 2 (wrist)'), findsNothing);
  });

  testWidgets('shows no gear row when the equipment row is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestWidget(computer: _computer(equipmentId: 'gear-1'), gear: null),
    );
    await tester.pumpAndSettle();

    expect(find.text('Perdix 2 (wrist)'), findsNothing);
  });
}
