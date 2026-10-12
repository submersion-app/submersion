import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/models/equipment_default_view.dart';
import 'package:submersion/features/settings/presentation/pages/equipment_default_view_page.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The page choosing which statuses the Equipment list shows with no filter
/// set (issue #2628), and its Settings > Manage row.
void main() {
  Future<MockSettingsNotifier> pump(
    WidgetTester tester,
    Set<EquipmentStatus> statuses,
  ) async {
    // Tall enough for all nine rows and Reset: the list builds lazily.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final notifier = MockSettingsNotifier(
      AppSettings(equipmentDefaultStatuses: statuses),
    );
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const EquipmentDefaultViewPage(),
      ),
    );
    await tester.pumpAndSettle();
    return notifier;
  }

  CheckboxListTile box(WidgetTester tester, EquipmentStatus s) =>
      tester.widget(find.byKey(ValueKey('equipment_default_view_${s.name}')));

  testWidgets('every status is listed, ticked when in the default view', (
    tester,
  ) async {
    await pump(tester, factoryDefaultEquipmentStatuses);
    for (final s in EquipmentStatus.values) {
      expect(
        box(tester, s).value,
        factoryDefaultEquipmentStatuses.contains(s),
        reason: s.name,
      );
    }
    expect(find.text('Default equipment view'), findsOneWidget);
  });

  testWidgets('ticking and unticking edits the setting', (tester) async {
    final notifier = await pump(tester, {EquipmentStatus.active});
    final lost = find.byKey(const ValueKey('equipment_default_view_lost'));
    await tester.tap(lost);
    await tester.pumpAndSettle();
    expect(notifier.state.equipmentDefaultStatuses, {
      EquipmentStatus.active,
      EquipmentStatus.lost,
    });
    final active = find.byKey(const ValueKey('equipment_default_view_active'));
    await tester.tap(active);
    await tester.pumpAndSettle();
    expect(notifier.state.equipmentDefaultStatuses, {EquipmentStatus.lost});
  });

  testWidgets('the last ticked status cannot be unticked', (tester) async {
    await pump(tester, {EquipmentStatus.active});
    expect(box(tester, EquipmentStatus.active).onChanged, isNull);
    expect(box(tester, EquipmentStatus.spare).onChanged, isNotNull);
  });

  testWidgets('Reset restores the factory set, and is off when already there', (
    tester,
  ) async {
    final notifier = await pump(tester, {EquipmentStatus.active});
    final reset = find.byKey(const ValueKey('equipment_default_view_reset'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(
      notifier.state.equipmentDefaultStatuses,
      factoryDefaultEquipmentStatuses,
    );
    expect(tester.widget<TextButton>(reset).onPressed, isNull);
  });

  testWidgets('Manage lists the default view with its statuses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const SettingsSectionDetailPage(sectionId: 'manage'),
        ),
        GoRoute(
          path: kEquipmentDefaultViewRoute,
          builder: (context, state) => const EquipmentDefaultViewPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        // Riverpod refuses a second settingsProvider override, so the
        // notifier goes through getBaseOverrides' own parameter.
        overrides: await getBaseOverrides(
          settingsNotifier: MockSettingsNotifier(
            const AppSettings(
              hasAcceptedPlanningDisclaimer: true,
              equipmentDefaultStatuses: {
                EquipmentStatus.active,
                EquipmentStatus.spare,
              },
            ),
          ),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    final tile = find.byKey(
      const ValueKey('settings_manage_equipmentDefaultView'),
    );
    await tester.scrollUntilVisible(
      tile,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Active, Spare'), findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(EquipmentDefaultViewPage), findsOneWidget);
  });
}
