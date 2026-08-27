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

/// The dive open in the detail pane is filled, never striped.
///
/// Splitting `isSelected` into `isChecked` and `isHighlighted` made the
/// highlight channel reach the tiles for the first time, and the tiles rendered
/// it as a 3px leading edge stripe over a barely-there tint. That is not how
/// the dive list has ever looked, nor how the Sites and Buddies lists look --
/// they render a highlighted row with the same fill a checked row gets. These
/// tests pin the fill, and the absence of the stripe, on both card tiles.
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
  Widget compact({
    required bool isSelectionMode,
    required bool isChecked,
    required bool isHighlighted,
  }) => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: CompactDiveListTile(
      diveId: 'd1',
      diveNumber: 40,
      dateTime: DateTime(2026, 5, 7, 9),
      siteName: 'Unknown Site',
      maxDepth: 18.6,
      duration: const Duration(minutes: 59),
      isSelectionMode: isSelectionMode,
      isChecked: isChecked,
      isHighlighted: isHighlighted,
      onTap: () {},
    ),
  );

  Widget detailed({
    required bool isSelectionMode,
    required bool isChecked,
    required bool isHighlighted,
  }) => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      detailedCardConfigProvider.overrideWith(
        (ref) => _TestCardConfigNotifier(),
      ),
    ],
    child: DiveListTile(
      diveId: 'd1',
      diveNumber: 40,
      dateTime: DateTime(2026, 5, 7, 9),
      siteName: 'Unknown Site',
      maxDepth: 18.6,
      duration: const Duration(minutes: 59),
      isSelectionMode: isSelectionMode,
      isChecked: isChecked,
      isHighlighted: isHighlighted,
      onTap: () {},
    ),
  );

  /// The fill the dive list has always used for the active row.
  Color selectionFill(WidgetTester tester, Type tileType) {
    final context = tester.element(find.byType(tileType));
    return Theme.of(
      context,
    ).colorScheme.primaryContainer.withValues(alpha: 0.5);
  }

  Color? cardColor(WidgetTester tester, Type tileType) => tester
      .widget<Card>(
        find.descendant(of: find.byType(tileType), matching: find.byType(Card)),
      )
      .color;

  /// A highlighted row must be marked, and its marker must carry no leading
  /// edge stripe.
  ///
  /// The marker is asserted rather than tolerated: every caller passes
  /// `isHighlighted: true` with no coordinates, so the tile always takes the
  /// standard-card path that emits the key. Returning early on a missing
  /// marker would turn the stripe check into a vacuous pass if a regression
  /// ever stopped marking highlighted rows.
  void expectMarkedWithoutStripe(WidgetTester tester) {
    final marker = find.byKey(const ValueKey('dive_row_highlight'));
    expect(
      marker,
      findsOneWidget,
      reason: 'the highlighted row carries its marker',
    );
    final decoration = tester.widget<Container>(marker).decoration;
    expect(
      (decoration as BoxDecoration?)?.border,
      isNull,
      reason: 'a highlighted row is filled, not striped',
    );
  }

  void highlightRenderingTests(
    String name,
    Type type,
    Widget Function({
      required bool isSelectionMode,
      required bool isChecked,
      required bool isHighlighted,
    })
    build,
  ) {
    group('$name highlight rendering', () {
      testWidgets('highlighted row is filled like a selected row', (
        tester,
      ) async {
        await tester.pumpWidget(
          build(isSelectionMode: false, isChecked: false, isHighlighted: true),
        );
        await tester.pumpAndSettle();

        expect(cardColor(tester, type), selectionFill(tester, type));
        expectMarkedWithoutStripe(tester);
      });

      testWidgets('checked row uses the same fill', (tester) async {
        await tester.pumpWidget(
          build(isSelectionMode: true, isChecked: true, isHighlighted: false),
        );
        await tester.pumpAndSettle();

        expect(cardColor(tester, type), selectionFill(tester, type));
      });

      testWidgets('highlight does not fill a row in selection mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          build(isSelectionMode: true, isChecked: false, isHighlighted: true),
        );
        await tester.pumpAndSettle();

        expect(
          cardColor(tester, type),
          isNot(selectionFill(tester, type)),
          reason:
              'in selection mode the fill means checked; a highlighted but '
              'unchecked row must not read as selected',
        );
        expectMarkedWithoutStripe(tester);
      });
    });
  }

  highlightRenderingTests('CompactDiveListTile', CompactDiveListTile, compact);
  highlightRenderingTests('DiveListTile', DiveListTile, detailed);
}
