import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
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

  testWidgets('no-clock option saves a null serviceKindId', (tester) async {
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
              serviceKindId: 'hydro',
              onSave: (record) async => saved.add(record),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hydrostatic test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not tied to a clock').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(saved.single.serviceKindId, isNull);
  });
}
