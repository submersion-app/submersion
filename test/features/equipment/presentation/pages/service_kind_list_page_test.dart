import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/presentation/pages/service_kind_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final t0 = DateTime(2025, 1, 1);

  ServiceKind builtIn(String id, String name) => ServiceKind(
    id: id,
    name: name,
    applicableTypes: const [EquipmentType.tank],
    defaultIntervalDays: 365,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );

  Widget buildPage(List<ServiceKind> kinds) {
    return ProviderScope(
      overrides: [serviceKindsProvider.overrideWith((ref) async => kinds)],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ServiceKindListPage(),
      ),
    );
  }

  testWidgets('built-ins render locked without delete action', (tester) async {
    await tester.pumpWidget(
      buildPage([
        builtIn('hydro', 'Hydrostatic test'),
        builtIn('vip', 'Visual inspection (VIP)'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hydrostatic test'), findsOneWidget);
    expect(find.text('Visual inspection (VIP)'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('No custom service types yet'), findsOneWidget);
  });

  testWidgets('custom kind renders in Custom section with delete action', (
    tester,
  ) async {
    final custom = ServiceKind(
      id: 'c1',
      name: 'Scrubber repack',
      defaultIntervalHours: 5.0,
      createdAt: t0,
      updatedAt: t0,
    );
    await tester.pumpWidget(
      buildPage([builtIn('hydro', 'Hydrostatic test'), custom]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scrubber repack'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.textContaining('every 5.0 hours'), findsOneWidget);
  });

  testWidgets('add dialog opens from FAB', (tester) async {
    await tester.pumpWidget(buildPage([builtIn('hydro', 'Hydrostatic test')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Add service type'), findsOneWidget);
    expect(find.text('Attach automatically to new gear'), findsOneWidget);
  });
}
