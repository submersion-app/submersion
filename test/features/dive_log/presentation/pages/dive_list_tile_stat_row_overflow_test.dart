import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// The detailed card's stat row shares one line with the dive-type badges.
/// The master pane can be dragged down to 280px, where the two stats alone
/// used to exceed the line and stripe the RenderFlex (it overflowed from
/// 240px up to 320px with three dive types).
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

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
  const typeIds = ['wreck', 'night', 'drift', 'technical'];

  final types = [
    for (final id in typeIds)
      DiveTypeEntity(
        id: id,
        name: id,
        isBuiltIn: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];

  final summary = DiveSummary(
    id: 'd1',
    diveNumber: 1234,
    dateTime: DateTime(2026, 3, 15),
    siteName: 'Blue Hole',
    maxDepth: 131.4,
    bottomTime: const Duration(minutes: 147),
    runtime: const Duration(minutes: 152),
    diveTypeIds: typeIds,
    sortTimestamp: 0,
  );

  Widget buildTile({required double width, required CardViewConfig config}) {
    return testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        detailedCardConfigProvider.overrideWith(
          (ref) => _TestCardConfigNotifier(config),
        ),
        diveTypesProvider.overrideWith((ref) async => types),
      ],
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: Consumer(
            builder: (context, ref, _) => DiveListTile(
              diveId: 'd1',
              diveNumber: 1234,
              dateTime: DateTime(2026, 3, 15),
              siteName: summary.siteName,
              maxDepth: summary.maxDepth,
              duration: summary.bottomTime,
              summary: summary,
              diveTypeLabelResolver: watchDiveTypeLabelResolver(
                ref,
                context.l10n,
              ),
              diveTypeShortLabelResolver: watchDiveTypeShortLabelResolver(
                ref,
                context.l10n,
              ),
            ),
          ),
        ),
      ),
    );
  }

  CardViewConfig configWithStat2(DiveField field) {
    final base = CardViewConfig.defaultDetailed();
    return base.copyWith(
      slots: [
        for (final slot in base.slots)
          if (slot.slotId == 'stat2')
            CardSlotConfig(slotId: 'stat2', field: field)
          else
            slot,
      ],
    );
  }

  final widths = [for (var w = 280.0; w <= 360.0; w += 10) w];

  group('DiveListTile stat row at narrow master-pane widths', () {
    for (final width in widths) {
      testWidgets('default stats with several dive types fit at ${width}px', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTile(width: width, config: CardViewConfig.defaultDetailed()),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    for (final width in widths) {
      testWidgets('a long stat value fits at ${width}px', (tester) async {
        // A joined dive-type list in a stat slot is far wider than any
        // numeric stat, so the stats must give way rather than overflow.
        await tester.pumpWidget(
          buildTile(
            width: width,
            config: configWithStat2(DiveField.diveTypeName),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }

    for (final width in widths) {
      testWidgets('a stat without an icon fits at ${width}px', (tester) async {
        // Icon-less fields render as "<short label>: <value>" instead.
        const field = DiveField.siteLatitude;
        final label = field.localizedShortLabel(
          lookupAppLocalizations(const Locale('en')),
        );

        await tester.pumpWidget(
          buildTile(width: width, config: configWithStat2(field)),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.textContaining('$label: '), findsOneWidget);
      });
    }
  });
}
