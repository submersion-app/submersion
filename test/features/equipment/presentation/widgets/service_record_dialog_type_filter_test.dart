import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const serviceTypeKey = Key('service-record-service-type');
const filterToggleKey = Key('service-record-filter-configured-types');

void main() {
  final t0 = DateTime(2026, 1, 1);

  ServiceKind kind(String id) =>
      ServiceKind(id: id, name: id, createdAt: t0, updatedAt: t0);

  ServiceSchedule schedule(
    String id,
    String serviceKindId, {
    bool enabled = true,
  }) => ServiceSchedule(
    id: id,
    equipmentId: 'e1',
    serviceKindId: serviceKindId,
    enabled: enabled,
    createdAt: t0,
    updatedAt: t0,
  );

  Future<void> pumpDialog(
    WidgetTester tester, {
    required List<ServiceKind> kinds,
    required List<ServiceSchedule> schedules,
    String? serviceKindId,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          serviceKindsProvider.overrideWith((ref) async => kinds),
          serviceSchedulesForEquipmentProvider(
            'e1',
          ).overrideWith((ref) async => schedules),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ServiceRecordDialog(
              equipmentId: 'e1',
              serviceKindId: serviceKindId,
              onSave: (record) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openServiceTypeDropdown(WidgetTester tester) async {
    await tester.tap(find.byKey(serviceTypeKey));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'by default the dropdown only lists kinds with a configured schedule',
    (tester) async {
      await pumpDialog(
        tester,
        kinds: [kind('hydro'), kind('o2-clean'), kind('disinfect')],
        schedules: [schedule('s1', 'hydro')],
      );
      await openServiceTypeDropdown(tester);

      expect(find.text('hydro').last, findsOneWidget);
      expect(find.text('o2-clean'), findsNothing);
      expect(find.text('disinfect'), findsNothing);
    },
  );

  testWidgets('the show-all toggle reveals every service type', (tester) async {
    await pumpDialog(
      tester,
      kinds: [kind('hydro'), kind('o2-clean'), kind('disinfect')],
      schedules: [schedule('s1', 'hydro')],
    );

    await tester.tap(find.byKey(filterToggleKey));
    await tester.pumpAndSettle();
    await openServiceTypeDropdown(tester);

    expect(find.text('hydro').last, findsOneWidget);
    expect(find.text('o2-clean').last, findsOneWidget);
    expect(find.text('disinfect').last, findsOneWidget);
  });

  testWidgets(
    'a paused schedule does not count as configured, so with nothing else '
    'configured the dialog falls back to showing every type',
    (tester) async {
      await pumpDialog(
        tester,
        kinds: [kind('hydro'), kind('o2-clean')],
        schedules: [schedule('s1', 'hydro', enabled: false)],
      );
      await openServiceTypeDropdown(tester);

      expect(find.text('hydro').last, findsOneWidget);
      expect(find.text('o2-clean').last, findsOneWidget);
    },
  );

  testWidgets(
    'a paused schedule does not count as configured when another kind is',
    (tester) async {
      await pumpDialog(
        tester,
        kinds: [kind('hydro'), kind('o2-clean'), kind('disinfect')],
        schedules: [
          schedule('s1', 'hydro', enabled: false),
          schedule('s2', 'o2-clean'),
        ],
      );
      await openServiceTypeDropdown(tester);

      expect(find.text('hydro'), findsNothing);
      expect(find.text('o2-clean').last, findsOneWidget);
      expect(find.text('disinfect'), findsNothing);
    },
  );

  testWidgets(
    'no configured schedule at all falls back to showing every type',
    (tester) async {
      await pumpDialog(
        tester,
        kinds: [kind('hydro'), kind('o2-clean')],
        schedules: const [],
      );
      await openServiceTypeDropdown(tester);

      expect(find.text('hydro').last, findsOneWidget);
      expect(find.text('o2-clean').last, findsOneWidget);
    },
  );

  testWidgets('the current selection stays offered after switching back to the '
      'narrowed list', (tester) async {
    await pumpDialog(
      tester,
      kinds: [kind('hydro'), kind('o2-clean')],
      schedules: [schedule('s1', 'hydro')],
      serviceKindId: 'hydro',
    );

    // Show all, pick the type with no configured schedule.
    await tester.tap(find.byKey(filterToggleKey));
    await tester.pumpAndSettle();
    await openServiceTypeDropdown(tester);
    await tester.tap(find.text('o2-clean').last);
    await tester.pumpAndSettle();

    // Switch back to the narrowed list.
    await tester.tap(find.byKey(filterToggleKey));
    await tester.pumpAndSettle();
    await openServiceTypeDropdown(tester);

    expect(find.text('o2-clean').last, findsOneWidget);
  });
}
