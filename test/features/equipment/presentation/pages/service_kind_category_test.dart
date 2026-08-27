import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/presentation/pages/service_kind_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

const categoryKey = Key('service-kind-default-category');

void main() {
  final t0 = DateTime(2026, 1, 1);

  ServiceKind kind(
    String id, {
    ServiceCategory? category,
    bool builtIn = false,
    int? days,
  }) => ServiceKind(
    id: id,
    name: id,
    defaultCategory: category,
    defaultIntervalDays: days,
    isBuiltIn: builtIn,
    createdAt: t0,
    updatedAt: t0,
  );

  Future<void> pumpPage(WidgetTester tester, List<ServiceKind> kinds) async {
    // The dialog body is a scroll view, so an assertion against an off-screen
    // child would false-pass. A tall surface materializes the whole form.
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          serviceKindsProvider.overrideWith((ref) async => kinds),
        ].cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ServiceKindListPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the edit dialog offers a default category', (tester) async {
    await pumpPage(tester, [kind('disinfect')]);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byKey(categoryKey), findsOneWidget);
    expect(find.text('Default category'), findsOneWidget);
  });

  testWidgets('an existing category is preselected when editing', (
    tester,
  ) async {
    await pumpPage(tester, [
      kind('disinfect', category: ServiceCategory.cleaning),
    ]);

    await tester.tap(find.text('disinfect'));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButtonFormField<ServiceCategory?>>(
      find.byKey(categoryKey),
    );
    expect(dropdown.initialValue, ServiceCategory.cleaning);
  });

  testWidgets('the row summary names the category beside the interval', (
    tester,
  ) async {
    await pumpPage(tester, [
      kind('disinfect', category: ServiceCategory.cleaning, days: 365),
    ]);

    expect(find.textContaining('Cleaning'), findsOneWidget);
  });

  testWidgets('a kind with no category shows only its interval', (
    tester,
  ) async {
    await pumpPage(tester, [kind('disinfect', days: 365)]);

    expect(find.textContaining('every 365 days'), findsOneWidget);
    expect(find.textContaining(' · '), findsNothing);
  });
}
