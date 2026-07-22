import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_schedule_dialogs.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeScheduleRepo extends ServiceScheduleRepository {
  final created = <ServiceSchedule>[];
  @override
  Future<ServiceSchedule> createSchedule(ServiceSchedule schedule) async {
    final withId = schedule.copyWith(id: 'new-${created.length}');
    created.add(withId);
    return withId;
  }
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

  Future<void> pumpPicker(WidgetTester tester, _FakeScheduleRepo repo) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceKindsProvider.overrideWith(
            (ref) async => [noDefault, withDefault],
          ),
          serviceSchedulesForEquipmentProvider(
            'e1',
          ).overrideWith((ref) async => const []),
          serviceScheduleRepositoryProvider.overrideWithValue(repo),
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

  testWidgets('no-default kind opens the interval dialog after create', (
    tester,
  ) async {
    final repo = _FakeScheduleRepo();
    await pumpPicker(tester, repo);
    await tester.tap(find.text('General service'));
    await tester.pumpAndSettle();
    expect(repo.created, hasLength(1));
    // The interval-days field from the override dialog is present.
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('default-bearing kind is one-tap (no dialog)', (tester) async {
    final repo = _FakeScheduleRepo();
    await pumpPicker(tester, repo);
    await tester.tap(find.text('Regulator service'));
    await tester.pumpAndSettle();
    expect(repo.created, hasLength(1));
    // No override dialog: no TextField on screen.
    expect(find.byType(TextField), findsNothing);
  });
}
