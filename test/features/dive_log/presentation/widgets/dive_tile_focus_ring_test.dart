import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/master_detail/keyboard_list_navigator.dart';

import '../../../../helpers/keyboard_navigation_contract.dart';
import '../../../../helpers/test_app.dart';

/// The keyboard cursor's ring on a dive row traces the dive's card, inside the
/// margin that separates it from its neighbours, not that margin (#3224).
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier() : super.withMode(ListViewMode.detailed);
}

Future<void> _pumpRingedTile(WidgetTester tester, Widget tile) async {
  useDesktopFocusHighlighting();
  await tester.pumpWidget(
    testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        detailedCardConfigProvider.overrideWith(
          (ref) => _TestCardConfigNotifier(),
        ),
      ],
      child: KeyboardListNavigator(
        keys: const ['d1'],
        currentKey: null,
        onMove: (_) {},
        child: ListView(
          children: [KeyboardListItem(navigationKey: 'd1', child: tile)],
        ),
      ),
    ),
  );
  await clickThenUseKeyboard(tester, find.byType(Card));
}

/// The ring traced on the tile's card: a 2px border on the card's own edge
/// with the theme's card corners.
void _expectRingOnCard(WidgetTester tester) {
  final row = find.byType(KeyboardListItem);
  final card = find.descendant(of: row, matching: find.byType(Card));
  final cardRect = tester.getRect(card).shift(-tester.getTopLeft(row));
  final shape =
      Theme.of(tester.element(card)).cardTheme.shape
          as RoundedRectangleBorder? ??
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      );
  final ring = shape.borderRadius.resolve(TextDirection.ltr).toRRect(cardRect);

  expect(
    tester.renderObject(row),
    paints..something(
      (method, arguments) =>
          method == #drawDRRect &&
          arguments[0] == ring &&
          arguments[1] == ring.deflate(2),
    ),
  );
}

void main() {
  testWidgets('the detailed dive card is ringed on its own edge', (
    tester,
  ) async {
    await _pumpRingedTile(
      tester,
      DiveListTile(
        diveId: 'd1',
        diveNumber: 20,
        dateTime: DateTime(2025, 12, 27, 11, 26),
        siteName: 'Tortuga',
        maxDepth: 22.8,
        duration: const Duration(minutes: 43),
        isHighlighted: true,
        onTap: () {},
      ),
    );

    _expectRingOnCard(tester);
  });

  testWidgets('the compact dive card is ringed on its own edge', (
    tester,
  ) async {
    await _pumpRingedTile(
      tester,
      CompactDiveListTile(
        diveId: 'd1',
        diveNumber: 20,
        dateTime: DateTime(2025, 12, 27, 11, 26),
        siteName: 'Tortuga',
        maxDepth: 22.8,
        duration: const Duration(minutes: 43),
        isSelectionMode: false,
        isChecked: false,
        isHighlighted: true,
        onTap: () {},
      ),
    );

    _expectRingOnCard(tester);
  });
}
