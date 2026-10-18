import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// A tap on a dive card plays its ink splash through to the end (issue #3474).
///
/// A tap highlights the dive straight away, in the same frame the splash
/// starts. The tiles used to mark a highlighted row with a key on their root,
/// and on the map-background card the highlight also swapped the root widget
/// type, so the highlight threw the whole card away and built a new one. The
/// splash lives in the old InkWell's state, so it vanished with it: the press
/// animation was cut short or only flashed. The Sites and Trips cards keep the
/// same tree shape across a selection change, which is why they never did.
/// The detailed tile reads its slot config through a provider chain that
/// reaches SharedPreferences, so the config is pinned to the default here.
class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier() : super.withMode(ListViewMode.detailed);
}

/// Highlights its tile on tap, the way the dive list does.
class _HighlightOnTapHost extends StatefulWidget {
  const _HighlightOnTapHost({required this.tileBuilder});

  final Widget Function({
    required bool isHighlighted,
    required VoidCallback onTap,
  })
  tileBuilder;

  @override
  State<_HighlightOnTapHost> createState() => _HighlightOnTapHostState();
}

class _HighlightOnTapHostState extends State<_HighlightOnTapHost> {
  bool _isHighlighted = false;

  @override
  Widget build(BuildContext context) => widget.tileBuilder(
    isHighlighted: _isHighlighted,
    onTap: () => setState(() => _isHighlighted = true),
  );
}

void main() {
  Widget compact({required bool isHighlighted, required VoidCallback onTap}) =>
      CompactDiveListTile(
        diveId: 'd1',
        diveNumber: 40,
        dateTime: DateTime(2026, 5, 7, 9),
        siteName: 'Blue Hole',
        maxDepth: 18.6,
        duration: const Duration(minutes: 59),
        isHighlighted: isHighlighted,
        onTap: onTap,
      );

  Widget detailed({
    required bool isHighlighted,
    required VoidCallback onTap,
    double? siteLatitude,
    double? siteLongitude,
  }) => DiveListTile(
    diveId: 'd1',
    diveNumber: 40,
    dateTime: DateTime(2026, 5, 7, 9),
    siteName: 'Blue Hole',
    maxDepth: 18.6,
    duration: const Duration(minutes: 59),
    siteLatitude: siteLatitude,
    siteLongitude: siteLongitude,
    isHighlighted: isHighlighted,
    onTap: onTap,
  );

  Future<void> pumpHost(
    WidgetTester tester,
    _HighlightOnTapHost host, {
    bool showMapBackground = false,
  }) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          detailedCardConfigProvider.overrideWith(
            (ref) => _TestCardConfigNotifier(),
          ),
          showMapBackgroundOnDiveCardsProvider.overrideWithValue(
            showMapBackground,
          ),
        ],
        child: host,
      ),
    );
    await tester.pump();
  }

  /// Taps the card, letting the tap highlight it, and checks the InkWell that
  /// received the press is the one still on screen afterwards.
  Future<void> expectTapKeepsInkWell(WidgetTester tester, Type tileType) async {
    final inkWell = find.descendant(
      of: find.byType(tileType),
      matching: find.byType(InkWell),
    );
    final pressed = tester.element(inkWell);

    await tester.tap(find.byType(tileType));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('dive_row_highlight')),
      findsOneWidget,
      reason: 'the tap highlighted the row',
    );
    expect(
      tester.element(inkWell),
      same(pressed),
      reason:
          'the highlight must not rebuild the card from scratch, or the '
          'splash the tap started is discarded with the old InkWell',
    );
  }

  testWidgets('compact card keeps its InkWell when a tap highlights it', (
    tester,
  ) async {
    await pumpHost(tester, _HighlightOnTapHost(tileBuilder: compact));
    await expectTapKeepsInkWell(tester, CompactDiveListTile);
  });

  testWidgets('detailed card keeps its InkWell when a tap highlights it', (
    tester,
  ) async {
    await pumpHost(tester, _HighlightOnTapHost(tileBuilder: detailed));
    await expectTapKeepsInkWell(tester, DiveListTile);
  });

  testWidgets(
    'map-background card keeps its InkWell when a tap highlights it',
    (tester) async {
      final themedCard = CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      );
      // A highlighted card drops its map for the selection fill, so this tap
      // also switches the card from its map layout to its plain one.
      await pumpHost(
        tester,
        _HighlightOnTapHost(
          // Card corners vary by theme (4 to 20); pin one that is not
          // Material's default 12 so the splash is seen to follow the theme.
          tileBuilder: ({required isHighlighted, required onTap}) => Builder(
            builder: (context) => Theme(
              data: Theme.of(context).copyWith(cardTheme: themedCard),
              child: detailed(
                isHighlighted: isHighlighted,
                onTap: onTap,
                siteLatitude: 24.46,
                siteLongitude: -77.93,
              ),
            ),
          ),
        ),
        showMapBackground: true,
      );
      expect(
        find.byType(CachedNetworkImage),
        findsOneWidget,
        reason: 'the card starts on its map layout',
      );
      expect(
        tester.widget<InkWell>(find.byType(InkWell)).customBorder,
        themedCard.shape,
        reason:
            'the splash keeps the shape it started with, and the plain '
            'layout the tap switches to does not clip it to the card, so it '
            'must carry the card shape itself',
      );

      await expectTapKeepsInkWell(tester, DiveListTile);
      expect(
        find.byType(CachedNetworkImage),
        findsNothing,
        reason: 'the highlighted card shows the fill, not the map',
      );
    },
  );
}
