import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const serviceTypeKey = Key('service-record-service-type');
const categoryKey = Key('service-record-category');

/// A firmware update logged in the service dialog names the version it
/// installed (issue #5104).
void main() {
  final t0 = DateTime(2026, 1, 1);

  ServiceKind kind(String id, ServiceCategory? category) => ServiceKind(
    id: id,
    name: id,
    defaultCategory: category,
    createdAt: t0,
    updatedAt: t0,
  );

  ServiceCategory categoryValue(WidgetTester tester) => tester
      .widget<DropdownButtonFormField<ServiceCategory>>(find.byKey(categoryKey))
      .initialValue!;

  Future<void> pumpDialog(
    WidgetTester tester, {
    String? serviceKindId,
    ServiceRecord? existingRecord,
    Future<void> Function(ServiceRecord)? onSave,
  }) async {
    // The dialog body is a scroll view; a tall surface materializes it all.
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          serviceKindsProvider.overrideWith(
            (ref) async => [
              kind('hydro', ServiceCategory.inspection),
              kind('o2-clean', ServiceCategory.cleaning),
              kind('disinfect', null),
            ],
          ),
          serviceSchedulesForEquipmentProvider(
            'e1',
          ).overrideWith((ref) async => []),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ServiceRecordDialog(
              equipmentId: 'e1',
              serviceKindId: serviceKindId,
              existingRecord: existingRecord,
              onSave: onSave ?? (record) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pickServiceType(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(serviceTypeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(id).last);
    await tester.pumpAndSettle();
  }

  const versionKey = Key('service-record-firmware-version');

  Future<void> pickCategory(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(categoryKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('the version field shows only for a firmware update', (
    tester,
  ) async {
    await pumpDialog(tester);
    expect(find.byKey(versionKey), findsNothing);

    await pickCategory(tester, 'Firmware update');
    expect(find.byKey(versionKey), findsOneWidget);
  });

  testWidgets('a firmware update needs its version', (tester) async {
    final saved = <ServiceRecord>[];
    await pumpDialog(tester, onSave: (r) async => saved.add(r));
    await pickServiceType(tester, 'disinfect');
    await pickCategory(tester, 'Firmware update');

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the version'), findsOneWidget);
    expect(saved, isEmpty);

    await tester.enterText(find.byKey(versionKey), ' V95 ');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(saved.single.firmwareVersion, 'V95');
    expect(saved.single.serviceCategory, ServiceCategory.firmwareUpdate);
  });

  testWidgets('another category saves no version', (tester) async {
    final saved = <ServiceRecord>[];
    await pumpDialog(tester, onSave: (r) async => saved.add(r));
    await pickServiceType(tester, 'disinfect');
    await pickCategory(tester, 'Firmware update');
    await tester.enterText(find.byKey(versionKey), 'V95');
    await pickCategory(tester, 'Repair');

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(saved.single.firmwareVersion, isNull);
  });

  testWidgets('editing a firmware record shows its version', (tester) async {
    await pumpDialog(
      tester,
      existingRecord: ServiceRecord(
        id: 'f1',
        equipmentId: 'e1',
        serviceCategory: ServiceCategory.firmwareUpdate,
        serviceDate: t0,
        firmwareVersion: 'V94',
        createdAt: t0,
        updatedAt: t0,
      ),
    );
    expect(
      tester.widget<TextFormField>(find.byKey(versionKey)).controller!.text,
      'V94',
    );
  });
}
