import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// Issue #643: the detailed card resolves its dive-type slug once per card and
/// shares the resolver across the title slot, the date slot, the stat slots and
/// the extra-field row. Each of those is a separate call site, so each gets its
/// own case here -- `dive_list_tile_slots_test.dart` covers the slot mechanics
/// but never assigns a Dive Type field.
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
  DiveTypeEntity builtIn(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    isBuiltIn: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  DiveTypeEntity custom(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  final loadedTypes = [
    builtIn('wreck', 'Wreck'),
    builtIn('night', 'Night'),
    custom('muck_x1', 'Muck'),
  ];

  DiveSummary summaryWith(List<String> ids) => DiveSummary(
    id: 'd1',
    diveNumber: 7,
    dateTime: DateTime(2026, 3, 15),
    siteName: 'Blue Hole',
    maxDepth: 30.0,
    bottomTime: const Duration(minutes: 40),
    runtime: const Duration(minutes: 45),
    diveTypeIds: ids,
    sortTimestamp: 0,
  );

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

  Widget buildTile({
    required CardViewConfig config,
    required DiveSummary summary,
    Locale locale = const Locale('de'),
    List<DiveTypeEntity>? types,
    Dive? fullDive,
  }) {
    return testApp(
      locale: locale,
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        detailedCardConfigProvider.overrideWith(
          (ref) => _TestCardConfigNotifier(config),
        ),
        diveTypesProvider.overrideWith((ref) async => types ?? loadedTypes),
      ],
      // The resolver is built through the production helper, so these cases
      // still cover the provider -> label seam the tile no longer owns.
      child: Consumer(
        builder: (context, ref, _) => DiveListTile(
          diveId: 'd1',
          diveNumber: 7,
          dateTime: DateTime(2026, 3, 15),
          siteName: summary.siteName,
          maxDepth: 30.0,
          duration: const Duration(minutes: 40),
          summary: summary,
          fullDive: fullDive,
          diveTypeLabelResolver: watchDiveTypeLabelResolver(ref, context.l10n),
        ),
      ),
    );
  }

  group('DiveListTile dive-type localization', () {
    testWidgets('title slot localizes a built-in type', (tester) async {
      await tester.pumpWidget(
        buildTile(
          config: configWithSlot('title', DiveField.diveTypeName),
          summary: summaryWith(['wreck']),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wracktauchen'), findsOneWidget);
      expect(find.text('Wreck'), findsNothing);
    });

    testWidgets('date slot localizes a built-in type', (tester) async {
      await tester.pumpWidget(
        buildTile(
          config: configWithSlot('date', DiveField.diveTypeName),
          summary: summaryWith(['night']),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nachttauchen'), findsWidgets);
      expect(find.textContaining('2026'), findsNothing);
    });

    testWidgets('stat slot localizes a built-in type', (tester) async {
      await tester.pumpWidget(
        buildTile(
          config: configWithSlot('stat1', DiveField.diveTypeName),
          summary: summaryWith(['wreck']),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Wracktauchen'), findsWidgets);
    });

    testWidgets('stat slot localizes from a full Dive when one is supplied', (
      tester,
    ) async {
      // With fullDive present the stat slot takes extractFromDive, a separate
      // branch from the summary path above.
      await tester.pumpWidget(
        buildTile(
          config: configWithSlot('stat1', DiveField.diveTypeName),
          summary: summaryWith(['wreck']),
          fullDive: Dive(
            id: 'd1',
            dateTime: DateTime(2026, 3, 15),
            diveTypeIds: const ['wreck'],
            maxDepth: 30.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Wracktauchen'), findsWidgets);
      expect(find.textContaining('Wreck,'), findsNothing);
    });

    testWidgets('extra-field row localizes from a summary', (tester) async {
      await tester.pumpWidget(
        buildTile(
          config: CardViewConfig.defaultDetailed().copyWith(
            extraFields: const [DiveField.diveTypeName],
          ),
          summary: summaryWith(['night']),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nachttauchen'), findsWidgets);
    });

    testWidgets('extra-field row localizes from a full Dive', (tester) async {
      await tester.pumpWidget(
        buildTile(
          config: CardViewConfig.defaultDetailed().copyWith(
            extraFields: const [DiveField.diveTypeName],
          ),
          summary: summaryWith(['night']),
          fullDive: Dive(
            id: 'd1',
            dateTime: DateTime(2026, 3, 15),
            diveTypeIds: const ['night'],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nachttauchen'), findsWidgets);
    });

    testWidgets('a custom type keeps its own name under German', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTile(
          config: configWithSlot('title', DiveField.diveTypeName),
          summary: summaryWith(['muck_x1']),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Muck'), findsOneWidget);
    });

    testWidgets(
      'a custom type squatting a built-in slug keeps the diver label',
      (tester) async {
        await tester.pumpWidget(
          buildTile(
            config: configWithSlot('title', DiveField.diveTypeName),
            summary: summaryWith(['wreck']),
            types: [custom('wreck', 'Hausriff-Wrack')],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hausriff-Wrack'), findsOneWidget);
        expect(find.text('Wracktauchen'), findsNothing);
      },
    );

    testWidgets('multiple types join in stored order', (tester) async {
      await tester.pumpWidget(
        buildTile(
          config: configWithSlot('title', DiveField.diveTypeName),
          summary: summaryWith(['night', 'wreck']),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nachttauchen, Wracktauchen'), findsOneWidget);
    });

    testWidgets('English still shows the English built-in label', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTile(
          config: configWithSlot('title', DiveField.diveTypeName),
          summary: summaryWith(['wreck']),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wreck'), findsOneWidget);
    });
  });
}
