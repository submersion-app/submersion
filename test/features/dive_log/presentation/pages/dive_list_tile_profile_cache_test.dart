import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier(super.initial);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier() : super.withMode(ListViewMode.detailed) {
    state = CardViewConfig.defaultDetailed();
  }
}

const _profile = [
  DiveProfilePoint(timestamp: 0, depth: 0),
  DiveProfilePoint(timestamp: 60, depth: 18),
  DiveProfilePoint(timestamp: 1800, depth: 0),
];

void main() {
  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => _TestSettingsNotifier(const AppSettings()),
          ),
          detailedCardConfigProvider.overrideWith(
            (ref) => _TestCardConfigNotifier(),
          ),
        ],
        child: DiveListTile(
          diveId: 'd1',
          diveNumber: 7,
          dateTime: DateTime(2024, 6, 1),
          siteName: 'Blue Hole',
          summary: DiveSummary(
            id: 'd1',
            diveNumber: 7,
            dateTime: DateTime(2024, 6, 1),
            siteName: 'Blue Hole',
            maxDepth: 18.0,
            sortTimestamp: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  StateController<Map<String, List<DiveProfilePoint>>> cache(
    WidgetTester tester,
  ) => ProviderScope.containerOf(
    tester.element(find.byType(DiveListTile)),
  ).read(batchProfileCacheProvider.notifier);

  Widget card(WidgetTester tester) => tester.widget(
    find.descendant(of: find.byType(DiveListTile), matching: find.byType(Card)),
  );

  group('DiveListTile and the batch profile cache (#3506)', () {
    testWidgets('a page of other dives landing in the cache leaves the card '
        'alone', (tester) async {
      await pumpTile(tester);
      final before = card(tester);

      cache(tester).state = {'d2': _profile, 'd3': _profile};
      await tester.pump();

      expect(
        identical(card(tester), before),
        isTrue,
        reason:
            'every page load writes the cache once; a card whose own entry '
            'did not change must not re-render for it',
      );
    });

    testWidgets('its own profile landing in the cache re-renders the card', (
      tester,
    ) async {
      await pumpTile(tester);
      final before = card(tester);

      cache(tester).state = {'d1': _profile};
      await tester.pump();

      expect(identical(card(tester), before), isFalse);
    });
  });
}
