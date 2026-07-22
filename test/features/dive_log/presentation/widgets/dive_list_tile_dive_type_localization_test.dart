import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dense_dive_list_tile.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// Issue #643: a Dive Type slot in the compact and dense list tiles used to
/// render `DiveField.diveTypeName` straight from the slug capitalization, so it
/// stayed English under every locale. Both tiles now resolve the slug through
/// the shared `diveTypeLabel` resolver, seeded from `diveTypesProvider`.
///
/// The pre-existing tile tests never assign a Dive Type slot, so none of them
/// exercise the resolver threading.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
    maxDepth: 20.0,
    bottomTime: const Duration(minutes: 30),
    diveTypeIds: ids,
    sortTimestamp: 0,
  );

  Widget harness({
    required Widget Function(DiveTypeLabelResolver resolve) builder,
    required Locale locale,
    List<DiveTypeEntity>? types,
  }) {
    return testApp(
      locale: locale,
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        diveTypesProvider.overrideWith((ref) async => types ?? loadedTypes),
      ],
      // The resolver is built through the production helper, so these cases
      // still cover the provider -> label seam the tiles no longer own.
      child: Consumer(
        builder: (context, ref, _) =>
            builder(watchDiveTypeLabelResolver(ref, context.l10n)),
      ),
    );
  }

  group('CompactDiveListTile dive-type slot', () {
    Widget tile({
      required Locale locale,
      required DiveSummary summary,
      DiveField stat1Field = DiveField.diveTypeName,
      DiveField titleField = DiveField.siteName,
      DiveField dateField = DiveField.dateTime,
      List<DiveTypeEntity>? types,
    }) => harness(
      locale: locale,
      types: types,
      builder: (resolve) => CompactDiveListTile(
        diveId: 'd1',
        diveNumber: 7,
        dateTime: DateTime(2026, 3, 15),
        siteName: 'Blue Hole',
        maxDepth: 20.0,
        duration: const Duration(minutes: 30),
        summary: summary,
        titleField: titleField,
        dateField: dateField,
        stat1Field: stat1Field,
        onTap: () {},
        diveTypeLabelResolver: resolve,
      ),
    );

    testWidgets('stat slot localizes a built-in type', (tester) async {
      await tester.pumpWidget(
        tile(locale: const Locale('de'), summary: summaryWith(['wreck'])),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Wracktauchen'), findsOneWidget);
      expect(find.textContaining('Wreck'), findsNothing);
    });

    testWidgets('stat slot joins multiple types in stored order', (
      tester,
    ) async {
      await tester.pumpWidget(
        tile(
          locale: const Locale('de'),
          summary: summaryWith(['night', 'wreck']),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nachttauchen, Wracktauchen'), findsOneWidget);
    });

    testWidgets('title slot localizes a built-in type', (tester) async {
      await tester.pumpWidget(
        tile(
          locale: const Locale('de'),
          summary: summaryWith(['night']),
          titleField: DiveField.diveTypeName,
          // Keep the dive type out of the stat slot so the match below is
          // unambiguously the title line.
          stat1Field: DiveField.maxDepth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nachttauchen'), findsOneWidget);
      expect(find.text('Blue Hole'), findsNothing);
    });

    testWidgets('date slot localizes a built-in type', (tester) async {
      await tester.pumpWidget(
        tile(
          locale: const Locale('de'),
          summary: summaryWith(['night']),
          dateField: DiveField.diveTypeName,
          stat1Field: DiveField.maxDepth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nachttauchen'), findsOneWidget);
      // The date line was replaced by the type, not rendered alongside it.
      expect(find.textContaining('2026'), findsNothing);
    });

    testWidgets('a custom type keeps its own name under German', (
      tester,
    ) async {
      await tester.pumpWidget(
        tile(locale: const Locale('de'), summary: summaryWith(['muck_x1'])),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Muck'), findsOneWidget);
    });

    testWidgets(
      'a custom type squatting a built-in slug keeps the diver label',
      (tester) async {
        // kSeedBuiltInDiveTypesSql uses INSERT OR IGNORE, so a diver-created
        // row on slug `wreck` suppresses the built-in seed and stays
        // isBuiltIn = false. The diver's label must win over the translation.
        await tester.pumpWidget(
          tile(
            locale: const Locale('de'),
            summary: summaryWith(['wreck']),
            types: [custom('wreck', 'Hausriff-Wrack')],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Hausriff-Wrack'), findsOneWidget);
        expect(find.textContaining('Wracktauchen'), findsNothing);
      },
    );

    testWidgets('falls back to the built-in table before the types load', (
      tester,
    ) async {
      // diveTypesProvider is still pending, so typesById is empty and tier 2
      // (the built-in localization table) has to carry the label.
      await tester.pumpWidget(
        harness(
          locale: const Locale('de'),
          types: const [],
          builder: (resolve) => CompactDiveListTile(
            diveId: 'd1',
            diveNumber: 7,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Blue Hole',
            summary: summaryWith(['wreck']),
            stat1Field: DiveField.diveTypeName,
            onTap: () {},
            diveTypeLabelResolver: resolve,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Wracktauchen'), findsOneWidget);
    });

    testWidgets('an unknown slug keeps the slug capitalization', (
      tester,
    ) async {
      await tester.pumpWidget(
        tile(locale: const Locale('de'), summary: summaryWith(['deep_wreck'])),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Deep wreck'), findsOneWidget);
    });

    testWidgets('English still shows the English built-in label', (
      tester,
    ) async {
      await tester.pumpWidget(
        tile(locale: const Locale('en'), summary: summaryWith(['wreck'])),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Wreck'), findsOneWidget);
      expect(find.textContaining('Wracktauchen'), findsNothing);
    });

    testWidgets('a summary-less tile still resolves a non-default stat slot', (
      tester,
    ) async {
      // Legacy callers pass the scalar fields without a DiveSummary. The
      // resolver is threaded through that branch too, and it must not throw
      // when there is nothing to extract from.
      await tester.pumpWidget(
        harness(
          locale: const Locale('de'),
          builder: (resolve) => CompactDiveListTile(
            diveId: 'd1',
            diveNumber: 7,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Blue Hole',
            maxDepth: 20.0,
            duration: const Duration(minutes: 30),
            stat1Field: DiveField.waterTemp,
            onTap: () {},
            diveTypeLabelResolver: resolve,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blue Hole'), findsOneWidget);
    });
  });

  group('DenseDiveListTile dive-type slot', () {
    Widget tile({
      required Locale locale,
      required DiveSummary summary,
      DiveField slot1Field = DiveField.siteName,
      DiveField slot2Field = DiveField.dateTime,
      DiveField slot3Field = DiveField.maxDepth,
      List<DiveTypeEntity>? types,
    }) => harness(
      locale: locale,
      types: types,
      builder: (resolve) => DenseDiveListTile(
        diveId: 'd1',
        diveNumber: 7,
        dateTime: DateTime(2026, 3, 15),
        siteName: 'Blue Hole',
        maxDepth: 20.0,
        duration: const Duration(minutes: 30),
        summary: summary,
        slot1Field: slot1Field,
        slot2Field: slot2Field,
        slot3Field: slot3Field,
        onTap: () {},
        diveTypeLabelResolver: resolve,
      ),
    );

    testWidgets('text slot localizes a built-in type', (tester) async {
      await tester.pumpWidget(
        tile(
          locale: const Locale('de'),
          summary: summaryWith(['wreck']),
          slot1Field: DiveField.diveTypeName,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wracktauchen'), findsOneWidget);
      expect(find.text('Wreck'), findsNothing);
    });

    testWidgets('second text slot localizes a built-in type', (tester) async {
      await tester.pumpWidget(
        tile(
          locale: const Locale('de'),
          summary: summaryWith(['night']),
          slot2Field: DiveField.diveTypeName,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nachttauchen'), findsWidgets);
    });

    testWidgets('stat slot localizes a built-in type', (tester) async {
      await tester.pumpWidget(
        tile(
          locale: const Locale('de'),
          summary: summaryWith(['wreck']),
          slot3Field: DiveField.diveTypeName,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Wracktauchen'), findsOneWidget);
    });

    testWidgets('a custom type keeps its own name under German', (
      tester,
    ) async {
      await tester.pumpWidget(
        tile(
          locale: const Locale('de'),
          summary: summaryWith(['muck_x1']),
          slot1Field: DiveField.diveTypeName,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Muck'), findsOneWidget);
    });

    testWidgets('English still shows the English built-in label', (
      tester,
    ) async {
      await tester.pumpWidget(
        tile(
          locale: const Locale('en'),
          summary: summaryWith(['wreck']),
          slot1Field: DiveField.diveTypeName,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wreck'), findsOneWidget);
    });

    testWidgets('a summary-less tile still resolves non-default slots', (
      tester,
    ) async {
      // Same legacy path as the compact tile: no DiveSummary, so both the text
      // slot and the stat slot fall through to the resolver-threaded tail.
      await tester.pumpWidget(
        harness(
          locale: const Locale('de'),
          builder: (resolve) => DenseDiveListTile(
            diveId: 'd1',
            diveNumber: 7,
            dateTime: DateTime(2026, 3, 15),
            siteName: 'Blue Hole',
            maxDepth: 20.0,
            duration: const Duration(minutes: 30),
            slot1Field: DiveField.diveTypeName,
            slot3Field: DiveField.waterTemp,
            onTap: () {},
            diveTypeLabelResolver: resolve,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Blue Hole'), findsNothing);
    });
  });

  group('resolver threading', () {
    testWidgets('a tile does not subscribe to the dive-type list', (
      tester,
    ) async {
      // The point of threading the resolver in as a parameter: a tile must not
      // watch diveTypesProvider itself, or every row rebuilds its own lookup
      // map and re-renders whenever the dive_types table is touched -- which a
      // sync does even when it re-applies unchanged rows.
      late ProviderContainer container;
      await tester.pumpWidget(
        testApp(
          locale: const Locale('de'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            diveTypesProvider.overrideWith((ref) async => loadedTypes),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return CompactDiveListTile(
                diveId: 'd1',
                diveNumber: 7,
                dateTime: DateTime(2026, 3, 15),
                siteName: 'Blue Hole',
                maxDepth: 20.0,
                duration: const Duration(minutes: 30),
                summary: summaryWith(['wreck']),
                stat1Field: DiveField.diveTypeName,
                onTap: () {},
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.exists(diveTypesProvider), isFalse);
    });

    testWidgets('watchDiveTypeLabelResolver resolves from the provider', (
      tester,
    ) async {
      late DiveTypeLabelResolver resolve;
      late ProviderContainer container;
      await tester.pumpWidget(
        testApp(
          locale: const Locale('de'),
          overrides: [
            settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
            diveTypesProvider.overrideWith((ref) async => loadedTypes),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              resolve = watchDiveTypeLabelResolver(ref, context.l10n);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The positive half of the probe above: a widget that does watch the
      // provider makes it exist in the container, so the isFalse assertion
      // there is testing something real.
      expect(container.exists(diveTypesProvider), isTrue);
      expect(resolve('wreck'), 'Wracktauchen');
      expect(resolve('muck_x1'), 'Muck');
      expect(resolve('deep_wreck'), 'Deep wreck');
    });
  });
}
