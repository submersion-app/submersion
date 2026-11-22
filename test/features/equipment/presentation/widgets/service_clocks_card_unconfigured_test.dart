import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);

  testWidgets('an enabled interval-less schedule says no interval is set', (
    tester,
  ) async {
    final schedule = ServiceSchedule(
      id: 'sch1',
      equipmentId: 'e1',
      serviceKindId: 'general-service',
      createdAt: t0,
      updatedAt: t0,
    );
    final kind = ServiceKind(
      id: 'general-service',
      name: 'General service',
      isBuiltIn: true,
      createdAt: t0,
      updatedAt: t0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // No evaluated statuses (interval-less => engine emits nothing).
          serviceClockStatusesProvider(
            'e1',
          ).overrideWith((ref) async => const []),
          serviceSchedulesForEquipmentProvider(
            'e1',
          ).overrideWith((ref) async => [schedule]),
          serviceKindsProvider.overrideWith((ref) async => [kind]),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ServiceClocksCard(equipmentId: 'e1')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('General service'), findsOneWidget);
    // The card is read-only, so the row only states the fact; clocks are
    // configured in the open card's editor.
    expect(find.text('No interval set'), findsOneWidget);
    expect(find.textContaining('tap to configure'), findsNothing);
    // Nothing on the row can be tapped, which is why it gives no instruction.
    final row = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('No interval set'),
        matching: find.byType(ListTile),
      ),
    );
    expect(row.onTap, isNull);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });
}
