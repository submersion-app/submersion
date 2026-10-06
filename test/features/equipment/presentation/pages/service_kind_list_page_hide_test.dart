import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/presentation/pages/service_kind_list_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/built_in_show_column.dart';

import '../../../../helpers/mock_providers.dart';

/// Settings > Service Types hide switches (issue #401).
void main() {
  final t0 = DateTime(2025, 1, 1);

  ServiceKind kind(String id, String name, {required bool builtIn}) =>
      ServiceKind(
        id: id,
        name: name,
        applicableTypes: const [EquipmentType.tank],
        defaultIntervalDays: 365,
        isBuiltIn: builtIn,
        createdAt: t0,
        updatedAt: t0,
      );

  final kinds = [
    kind('hydro', 'Hydrostatic test', builtIn: true),
    kind('vip', 'Visual inspection (VIP)', builtIn: true),
    kind('c1', 'My custom', builtIn: false),
  ];

  late MockSettingsNotifier settings;

  setUp(() => settings = MockSettingsNotifier());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceKindsProvider.overrideWith((ref) async => kinds),
          settingsProvider.overrideWith((ref) => settings),
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

  final vipKey = builtInShowSwitchKey(BuiltInCatalog.serviceKinds, 'vip');

  testWidgets('built-in rows have a labeled switch, custom rows none', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Show'), findsOneWidget);
    expect(find.byKey(vipKey), findsOneWidget);
    expect(
      find.byKey(builtInShowSwitchKey(BuiltInCatalog.serviceKinds, 'c1')),
      findsNothing,
    );
  });

  testWidgets('switching a kind off hides it and dims its row', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(vipKey));
    await tester.pumpAndSettle();

    expect(settings.state.hiddenBuiltIns(BuiltInCatalog.serviceKinds), {'vip'});
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.byKey(vipKey), matching: find.byType(ListTile)),
    );
    final context = tester.element(find.byKey(vipKey));
    expect(tile.textColor, Theme.of(context).disabledColor);
  });

  testWidgets('the switches give way in selection mode', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('the Show label gives way in selection mode too', (tester) async {
    await pump(tester);
    expect(find.text('Show'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('enter_selection')));
    await tester.pumpAndSettle();
    expect(find.text('Show'), findsNothing);
    expect(find.text('Built-in'), findsOneWidget);
  });
}
