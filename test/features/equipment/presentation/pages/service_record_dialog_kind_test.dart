import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);

  ServiceKind kind(String id, String name) => ServiceKind(
    id: id,
    name: name,
    defaultIntervalDays: 365,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );

  testWidgets('kind dropdown pre-selects and re-tags the saved record', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final saved = <ServiceRecord>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          serviceKindsProvider.overrideWith(
            (ref) async => [
              kind('hydro', 'Hydrostatic test'),
              kind('vip', 'Visual inspection (VIP)'),
            ],
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ServiceRecordDialog(
              equipmentId: 'e1',
              serviceKindId: 'hydro',
              onSave: (record) async => saved.add(record),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Pre-selected from the launching clock.
    expect(find.text('Hydrostatic test'), findsOneWidget);

    // Switch the clock this record fulfills.
    await tester.tap(find.text('Hydrostatic test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visual inspection (VIP)').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.serviceKindId, 'vip');
    expect(saved.single.equipmentId, 'e1');
  });

  // Since the service type unification a NEW record must name a service type,
  // so clearing it to "Not set" and saving is only reachable while editing.
  // That asymmetry is deliberate: attaching a type to an existing record moves
  // the clock anchor it is measured from, so editing must not be able to force
  // one. Creation is covered by service_record_dialog_category_test.dart.
  testWidgets('the no-type option saves a null serviceKindId when editing', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final saved = <ServiceRecord>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          serviceKindsProvider.overrideWith(
            (ref) async => [kind('hydro', 'Hydrostatic test')],
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ServiceRecordDialog(
              equipmentId: 'e1',
              existingRecord: ServiceRecord(
                id: 'r1',
                equipmentId: 'e1',
                serviceCategory: ServiceCategory.annual,
                serviceKindId: 'hydro',
                serviceDate: DateTime(2026, 6, 14),
                createdAt: DateTime(2026, 6, 14),
                updatedAt: DateTime(2026, 6, 14),
              ),
              onSave: (record) async => saved.add(record),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hydrostatic test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not set').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Update'));
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(saved.single.serviceKindId, isNull);
  });
}
