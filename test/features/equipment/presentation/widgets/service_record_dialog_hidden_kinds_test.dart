import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The service record type dropdown leaves out hidden built-in kinds
/// (issue #401) but keeps the one the record uses.
void main() {
  final t0 = DateTime(2026, 1, 1);
  ServiceKind builtIn(String id, String name) => ServiceKind(
    id: id,
    name: name,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );
  final kinds = [
    builtIn('hydro', 'Hydrostatic test'),
    builtIn('vip', 'Visual inspection (VIP)'),
  ];

  Future<void> pumpDialog(WidgetTester tester, {String? serviceKindId}) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(
        const AppSettings(
          hiddenBuiltInIds: {
            'serviceKinds': {'vip'},
          },
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          serviceKindsProvider.overrideWith((ref) async => kinds),
          serviceSchedulesForEquipmentProvider(
            'e1',
          ).overrideWith((ref) async => const []),
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
    await tester.tap(find.byKey(const Key('service-record-service-type')));
    await tester.pumpAndSettle();
  }

  testWidgets('a hidden kind is not offered', (tester) async {
    await pumpDialog(tester);
    expect(find.text('Hydrostatic test'), findsWidgets);
    expect(find.text('Visual inspection (VIP)'), findsNothing);
  });

  testWidgets('a hidden kind stays when the record already uses it', (
    tester,
  ) async {
    await pumpDialog(tester, serviceKindId: 'vip');
    expect(find.text('Visual inspection (VIP)'), findsWidgets);
  });

  testWidgets("the record's hidden kind stays offered after another pick", (
    tester,
  ) async {
    await pumpDialog(tester, serviceKindId: 'vip');
    await tester.tap(find.text('Hydrostatic test').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('service-record-service-type')));
    await tester.pumpAndSettle();
    expect(find.text('Visual inspection (VIP)'), findsWidgets);
  });
}
