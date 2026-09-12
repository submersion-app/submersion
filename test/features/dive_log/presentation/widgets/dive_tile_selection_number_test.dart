import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// Issue #1717: selecting dives hid every dive number.
///
/// Both card tiles used to swap the `#N` badge for the selection checkbox, so
/// a diver picking dives for a bulk edit lost the one field they pick by. The
/// checkbox now slides in ahead of the badge. These tests pin the number, the
/// checkbox's position, and that the wider leading slot still fits a phone.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The detailed tile reads its slot config through a provider chain that
/// reaches SharedPreferences, so the config is pinned to the default here.
class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier() : super.withMode(ListViewMode.detailed);
}

void main() {
  Widget compact({required bool isSelectionMode, bool isChecked = false}) =>
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        ],
        child: CompactDiveListTile(
          diveId: 'd1',
          diveNumber: 125,
          dateTime: DateTime(2025, 7, 19, 12, 24),
          siteName: 'Centeen SCUBA park',
          maxDepth: 10.6,
          duration: const Duration(minutes: 28),
          isSelectionMode: isSelectionMode,
          isChecked: isChecked,
          onTap: () {},
        ),
      );

  Widget detailed({required bool isSelectionMode, bool isChecked = false}) =>
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          detailedCardConfigProvider.overrideWith(
            (ref) => _TestCardConfigNotifier(),
          ),
        ],
        child: DiveListTile(
          diveId: 'd1',
          diveNumber: 125,
          dateTime: DateTime(2025, 7, 19, 12, 24),
          siteName: 'Centeen SCUBA park',
          siteLocation: 'Ontario, Canada',
          maxDepth: 10.6,
          duration: const Duration(minutes: 28),
          isSelectionMode: isSelectionMode,
          isChecked: isChecked,
          onTap: () {},
        ),
      );

  /// Narrow phone width, matching the screenshots on issue #1717.
  Future<void> usePhoneWidth(WidgetTester tester) async {
    tester.view.physicalSize = const Size(353, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  void selectionNumberTests(
    String name,
    Widget Function({required bool isSelectionMode, bool isChecked}) build,
  ) {
    group('$name in selection mode', () {
      for (final checked in [false, true]) {
        testWidgets('keeps the dive number visible when '
            '${checked ? 'checked' : 'unchecked'}', (tester) async {
          await tester.pumpWidget(
            build(isSelectionMode: true, isChecked: checked),
          );
          await tester.pumpAndSettle();

          expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, checked);
          expect(
            find.text('#125'),
            findsOneWidget,
            reason: 'the checkbox must not replace the dive number',
          );
        });
      }

      testWidgets('places the checkbox ahead of the dive number', (
        tester,
      ) async {
        await tester.pumpWidget(build(isSelectionMode: true));
        await tester.pumpAndSettle();

        expect(
          tester.getTopRight(find.byType(Checkbox)).dx,
          lessThanOrEqualTo(tester.getTopLeft(find.text('#125')).dx),
        );
      });

      testWidgets('keeps the number where it was outside selection mode', (
        tester,
      ) async {
        await tester.pumpWidget(build(isSelectionMode: false));
        await tester.pumpAndSettle();

        expect(find.byType(Checkbox), findsNothing);
        expect(find.text('#125'), findsOneWidget);
      });

      for (final selecting in [false, true]) {
        testWidgets('keeps the stat line under the title when '
            '${selecting ? '' : 'not '}selecting', (tester) async {
          await tester.pumpWidget(build(isSelectionMode: selecting));
          await tester.pumpAndSettle();

          expect(
            tester.getTopLeft(find.byIcon(Icons.arrow_downward)).dx,
            tester.getTopLeft(find.text('Centeen SCUBA park')).dx,
            reason:
                'the lines below the title are indented to sit under it, so '
                'they must move with the checkbox column',
          );
        });
      }

      testWidgets('fits a phone-width row without overflowing', (tester) async {
        await usePhoneWidth(tester);
        await tester.pumpWidget(build(isSelectionMode: true));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('#125'), findsOneWidget);
      });
    });
  }

  selectionNumberTests('CompactDiveListTile', compact);
  selectionNumberTests('DiveListTile', detailed);
}
