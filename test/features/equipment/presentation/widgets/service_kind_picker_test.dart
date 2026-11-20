import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

import '../../../../helpers/mock_providers.dart';

/// No service records: the override dialog reads them to decide whether the
/// stored baseline is still the one the clock counts from.
class _NoServiceRecords extends ServiceRecordRepository {
  @override
  Future<List<ServiceRecord>> getRecordsForEquipment(
    String equipmentId,
  ) async => const [];
}

void main() {
  final t0 = DateTime(2025, 1, 1);
  final noDefault = ServiceKind(
    id: 'general-service',
    name: 'General service',
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );
  final withDefault = ServiceKind(
    id: 'regulator-service',
    name: 'Regulator service',
    applicableTypes: const [EquipmentType.regulator],
    defaultIntervalDays: 365,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );

  /// Opens the picker as the clocks editor does; [held] gets each clock
  /// it hands over.
  Future<void> pumpPicker(
    WidgetTester tester,
    List<ServiceSchedule> held, {
    MockSettingsNotifier? settings,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => settings ?? MockSettingsNotifier(),
          ),
          serviceKindsProvider.overrideWith(
            (ref) async => [noDefault, withDefault],
          ),
          serviceRecordRepositoryProvider.overrideWithValue(
            _NoServiceRecords(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showServiceKindPicker(
                    context,
                    ref,
                    equipmentId: 'e1',
                    equipmentType: EquipmentType.regulator,
                    attachedKindIds: const {},
                    onHold: held.add,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('no-default kind opens the interval dialog after it is held', (
    tester,
  ) async {
    final held = <ServiceSchedule>[];
    await pumpPicker(tester, held);
    await tester.tap(find.text('General service'));
    await tester.pumpAndSettle();
    expect(held, hasLength(1));
    // The interval-days field from the override dialog is present.
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('default-bearing kind is one-tap (no dialog)', (tester) async {
    final held = <ServiceSchedule>[];
    await pumpPicker(tester, held);
    await tester.tap(find.text('Regulator service'));
    await tester.pumpAndSettle();
    expect(held, hasLength(1));
    // No override dialog: no TextField on screen.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('hidden built-in kinds are not offered (issue #401)', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      <ServiceSchedule>[],
      settings: MockSettingsNotifier(
        const AppSettings(
          hiddenBuiltInIds: {
            'serviceKinds': {'general-service'},
          },
        ),
      ),
    );
    expect(find.text('General service'), findsNothing);
    expect(find.text('Regulator service'), findsOneWidget);
  });
}
