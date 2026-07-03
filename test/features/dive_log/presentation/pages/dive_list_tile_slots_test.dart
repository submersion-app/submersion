import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
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
  _TestCardConfigNotifier(CardViewConfig config)
    : super.withMode(ListViewMode.detailed) {
    state = config;
  }
}

void main() {
  DiveSummary summary({String? name, String? siteName}) => DiveSummary(
    id: 'd1',
    diveNumber: 7,
    dateTime: DateTime(2024, 6, 1),
    name: name,
    siteName: siteName,
    maxDepth: 30.0,
    sortTimestamp: 0,
  );

  Widget buildTile({
    required CardViewConfig config,
    required DiveSummary diveSummary,
  }) {
    return testApp(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(const AppSettings()),
        ),
        detailedCardConfigProvider.overrideWith(
          (ref) => _TestCardConfigNotifier(config),
        ),
      ],
      child: DiveListTile(
        diveId: 'd1',
        diveNumber: 7,
        dateTime: DateTime(2024, 6, 1),
        siteName: diveSummary.siteName,
        summary: diveSummary,
      ),
    );
  }

  CardViewConfig configWithSlot(String slotId, DiveField field) {
    final base = CardViewConfig.defaultDetailed();
    return base.copyWith(
      slots: [
        for (final slot in base.slots)
          if (slot.slotId == slotId)
            CardSlotConfig(slotId: slotId, field: field)
          else
            slot,
      ],
    );
  }

  group('DiveListTile detailed slot assignments', () {
    testWidgets('title slot diveName shows the custom dive name', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTile(
          config: configWithSlot('title', DiveField.diveName),
          diveSummary: summary(
            name: 'Wreck penetration dive',
            siteName: 'Blue Hole',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wreck penetration dive'), findsOneWidget);
    });

    testWidgets('title slot diveName falls back to site name when unnamed', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTile(
          config: configWithSlot('title', DiveField.diveName),
          diveSummary: summary(siteName: 'Blue Hole'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blue Hole'), findsOneWidget);
    });

    testWidgets('default title slot renders the site name as before', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTile(
          config: CardViewConfig.defaultDetailed(),
          diveSummary: summary(
            name: 'Wreck penetration dive',
            siteName: 'Blue Hole',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default (siteName) slot keeps legacy behavior: the site, not the name.
      expect(find.text('Blue Hole'), findsOneWidget);
      expect(find.text('Wreck penetration dive'), findsNothing);
    });

    testWidgets('date slot honors a non-default field', (tester) async {
      await tester.pumpWidget(
        buildTile(
          config: configWithSlot('date', DiveField.maxDepth),
          diveSummary: summary(siteName: 'Blue Hole'),
        ),
      );
      await tester.pumpAndSettle();

      // The date line now shows the configured field (max depth, 30 m)
      // instead of the formatted date.
      expect(find.textContaining('30'), findsWidgets);
      expect(find.textContaining('2024'), findsNothing);
    });
  });
}
