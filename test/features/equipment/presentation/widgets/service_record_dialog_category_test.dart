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

  testWidgets('picking a service type prefills its default category', (
    tester,
  ) async {
    await pumpDialog(tester);
    await pickServiceType(tester, 'hydro');

    expect(categoryValue(tester), ServiceCategory.inspection);
    // Also pin what the diver actually sees: initialValue is the widget
    // parameter, so on its own it would pass even if the rendered selection
    // had drifted from the state behind it.
    expect(
      find.descendant(
        of: find.byKey(categoryKey),
        matching: find.text('Inspection'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a service type with no default leaves the category alone', (
    tester,
  ) async {
    await pumpDialog(tester);
    await pickServiceType(tester, 'disinfect');

    expect(categoryValue(tester), ServiceCategory.annual);
    expect(
      find.descendant(
        of: find.byKey(categoryKey),
        matching: find.text('Annual Service'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a category the diver chose survives changing the type', (
    tester,
  ) async {
    await pumpDialog(tester, serviceKindId: 'hydro');

    await tester.tap(find.byKey(categoryKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overhaul').last);
    await tester.pumpAndSettle();

    await pickServiceType(tester, 'o2-clean');

    expect(
      categoryValue(tester),
      ServiceCategory.overhaul,
      reason: 'the touched flag must block the o2-clean default',
    );
    // The same check after a manual tap and a later rebuild, which is where
    // a parameter-only assertion would be most likely to false-pass.
    expect(
      find.descendant(
        of: find.byKey(categoryKey),
        matching: find.text('Overhaul'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('creating a record requires a service type', (tester) async {
    var saved = false;
    await pumpDialog(
      tester,
      serviceKindId: null,
      onSave: (_) async => saved = true,
    );

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a service type'), findsOneWidget);
    expect(saved, isFalse);
  });

  testWidgets('editing a record with no service type can still be saved', (
    tester,
  ) async {
    var saved = false;
    await pumpDialog(
      tester,
      existingRecord: ServiceRecord(
        id: 'r1',
        equipmentId: 'e1',
        serviceCategory: ServiceCategory.repair,
        serviceDate: t0,
        createdAt: t0,
        updatedAt: t0,
      ),
      onSave: (_) async => saved = true,
    );

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(
      saved,
      isTrue,
      reason: 'forcing a pick on an old record would move a clock anchor',
    );
  });

  testWidgets('the dialog offers a route to the catalog', (tester) async {
    await pumpDialog(tester);

    expect(find.text('Manage service types'), findsOneWidget);
  });
}
