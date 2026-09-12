import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/observation_status_chip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
    createdAt: DateTime.utc(2026),
  );
  final dive = Dive(id: 'd1', dateTime: DateTime.utc(2026));

  EquipmentObservation obs(ObservationStatus status, {String item = 'reg'}) =>
      EquipmentObservation(
        id: 'o-${status.name}-$item',
        equipmentId: item,
        diveId: 'd1',
        observedAt: DateTime.utc(2026),
        status: status,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

  Future<void> pump(
    WidgetTester tester,
    List<EquipmentObservation> observations,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          observationsForDiveProvider(
            'd1',
          ).overrideWith((ref) async => observations),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ObservationStatusChip(equipment: reg, dive: dive),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no observation shows the check-in affordance', (tester) async {
    await pump(tester, const []);
    expect(find.byIcon(Icons.add_task), findsOneWidget);
    expect(find.byTooltip('Check in'), findsOneWidget);
  });

  testWidgets('all OK shows a check', (tester) async {
    await pump(tester, [obs(ObservationStatus.ok)]);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('any issue shows a warning', (tester) async {
    await pump(tester, [
      obs(ObservationStatus.ok),
      obs(ObservationStatus.issue),
    ]);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets('another item\'s issue does not count', (tester) async {
    await pump(tester, [obs(ObservationStatus.issue, item: 'fins')]);
    expect(find.byIcon(Icons.add_task), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });
}
