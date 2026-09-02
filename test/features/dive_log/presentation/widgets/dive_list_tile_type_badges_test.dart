import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge_row.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../../helpers/test_app.dart';

/// Issue #1269 follow-up: the dive list's compact and detailed cards show a
/// row of dive-type badges on the same line as the depth stat, right-aligned,
/// matching the badges already shown in the dive detail header.
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier() : super.withMode(ListViewMode.detailed) {
    state = CardViewConfig.defaultDetailed();
  }
}

void main() {
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
    required Widget Function(
      DiveTypeLabelResolver resolve,
      DiveTypeListVisibilityPredicate isVisible,
    )
    builder,
    List<DiveTypeEntity> diveTypes = const [],
  }) {
    return testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        diveTypesProvider.overrideWith((ref) async => diveTypes),
        detailedCardConfigProvider.overrideWith(
          (ref) => _TestCardConfigNotifier(),
        ),
      ],
      child: Consumer(
        builder: (context, ref, _) => builder(
          watchDiveTypeShortLabelResolver(ref, context.l10n),
          watchDiveTypeListVisibilityPredicate(ref),
        ),
      ),
    );
  }

  group('CompactDiveListTile type badges', () {
    Widget tile(
      List<String> diveTypeIds, {
      List<DiveTypeEntity> diveTypes = const [],
    }) => harness(
      diveTypes: diveTypes,
      builder: (resolve, isVisible) => CompactDiveListTile(
        diveId: 'd1',
        diveNumber: 7,
        dateTime: DateTime(2026, 3, 15),
        siteName: 'Blue Hole',
        maxDepth: 20.0,
        duration: const Duration(minutes: 30),
        summary: summaryWith(diveTypeIds),
        onTap: () {},
        diveTypeShortLabelResolver: resolve,
        diveTypeListVisibilityPredicate: isVisible,
      ),
    );

    testWidgets('shows a badge for each of the dive\'s types', (tester) async {
      await tester.pumpWidget(tile(['wreck', 'night']));
      await tester.pumpAndSettle();

      expect(find.byType(DiveTypeBadge), findsNWidgets(2));
      expect(find.text('Wreck'), findsOneWidget);
      expect(find.text('Night'), findsOneWidget);
    });

    testWidgets('shows no badges for a dive with no types', (tester) async {
      await tester.pumpWidget(tile([]));
      await tester.pumpAndSettle();

      expect(find.byType(DiveTypeBadge), findsNothing);
    });

    testWidgets('the badge row sits right of the stat row midpoint', (
      tester,
    ) async {
      await tester.pumpWidget(tile(['wreck']));
      await tester.pumpAndSettle();

      final cardRect = tester.getRect(find.byType(Card));
      final badgeRect = tester.getRect(find.byType(DiveTypeBadge));
      expect(badgeRect.center.dx, greaterThan(cardRect.center.dx));
    });

    testWidgets('renders at the same size as the dense OC/CCR badge', (
      tester,
    ) async {
      await tester.pumpWidget(tile(['wreck']));
      await tester.pumpAndSettle();

      final typeBadgeSize = tester.getSize(find.byType(DiveTypeBadge));
      final modeBadgeSize = tester.getSize(find.byType(DiveModeBadge));
      expect(typeBadgeSize.height, modeBadgeSize.height);
    });

    testWidgets('hides a type whose showInListView is false, keeps the rest', (
      tester,
    ) async {
      await tester.pumpWidget(
        tile(
          ['wreck', 'night'],
          diveTypes: [
            DiveTypeEntity(
              id: 'wreck',
              name: 'Wreck',
              isBuiltIn: true,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              showInListView: false,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveTypeBadge), findsNWidgets(1));
      expect(find.text('Night'), findsOneWidget);
      expect(find.text('Wreck'), findsNothing);
    });
  });

  group('DiveListTile detailed-view type badges', () {
    Widget tile(
      List<String> diveTypeIds, {
      List<DiveTypeEntity> diveTypes = const [],
    }) => harness(
      diveTypes: diveTypes,
      builder: (resolve, isVisible) => DiveListTile(
        diveId: 'd1',
        diveNumber: 7,
        dateTime: DateTime(2026, 3, 15),
        siteName: 'Blue Hole',
        maxDepth: 20.0,
        duration: const Duration(minutes: 30),
        summary: summaryWith(diveTypeIds),
        onTap: () {},
        diveTypeShortLabelResolver: resolve,
        diveTypeListVisibilityPredicate: isVisible,
      ),
    );

    testWidgets('shows a badge for each of the dive\'s types', (tester) async {
      await tester.pumpWidget(tile(['wreck', 'night']));
      await tester.pumpAndSettle();

      expect(find.byType(DiveTypeBadge), findsNWidgets(2));
      expect(find.text('Wreck'), findsOneWidget);
      expect(find.text('Night'), findsOneWidget);
    });

    testWidgets('shows no badges for a dive with no types', (tester) async {
      await tester.pumpWidget(tile([]));
      await tester.pumpAndSettle();

      expect(find.byType(DiveTypeBadge), findsNothing);
    });

    testWidgets('the badge row sits right of the stat row midpoint', (
      tester,
    ) async {
      await tester.pumpWidget(tile(['wreck']));
      await tester.pumpAndSettle();

      final cardRect = tester.getRect(find.byType(Card));
      final badgeRect = tester.getRect(find.byType(DiveTypeBadge));
      expect(badgeRect.center.dx, greaterThan(cardRect.center.dx));
    });

    testWidgets('renders at the same size as the dense OC/CCR badge', (
      tester,
    ) async {
      await tester.pumpWidget(tile(['wreck']));
      await tester.pumpAndSettle();

      final typeBadgeSize = tester.getSize(find.byType(DiveTypeBadge));
      final modeBadgeSize = tester.getSize(find.byType(DiveModeBadge));
      expect(typeBadgeSize.height, modeBadgeSize.height);
    });

    testWidgets('hides a type whose showInListView is false, keeps the rest', (
      tester,
    ) async {
      await tester.pumpWidget(
        tile(
          ['wreck', 'night'],
          diveTypes: [
            DiveTypeEntity(
              id: 'wreck',
              name: 'Wreck',
              isBuiltIn: true,
              createdAt: DateTime(2026),
              updatedAt: DateTime(2026),
              showInListView: false,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DiveTypeBadge), findsNWidgets(1));
      expect(find.text('Night'), findsOneWidget);
      expect(find.text('Wreck'), findsNothing);
    });

    testWidgets('does not overflow with several types and a long tag name', (
      tester,
    ) async {
      // Regression: a long tag (e.g. an import-source tag) used to render
      // unclipped in the stats/tags Wrap. Nothing there checked horizontal
      // overflow until the type-badge row added an enclosing Row, which
      // surfaced the pre-existing "tag too wide" case as a RenderFlex
      // overflow (issue #1269 follow-up).
      await tester.pumpWidget(
        harness(
          builder: (resolve, isVisible) => Align(
            alignment: Alignment.topLeft,
            // Matches the narrow list panel in the real master-detail
            // layout where this overflow was observed -- the default test
            // surface is wide enough to hide it.
            child: SizedBox(
              width: 380,
              child: DiveListTile(
                diveId: 'd1',
                diveNumber: 7,
                dateTime: DateTime(2026, 3, 15),
                siteName: 'Blue Hole',
                maxDepth: 20.0,
                duration: const Duration(minutes: 30),
                summary: summaryWith([
                  'wreck',
                  'night',
                  'drift',
                  'cave',
                  'ice',
                ]),
                tags: [
                  Tag(
                    id: 't1',
                    name:
                        '100_shearwater_cloud_export_with_one_ccr_dive.db.export',
                    createdAt: DateTime(2026),
                    updatedAt: DateTime(2026),
                  ),
                ],
                onTap: () {},
                diveTypeShortLabelResolver: resolve,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Tags render on their own line below the stat/badge row, so a long
      // tag name never competes with them for width.
      final badgeRect = tester.getRect(find.byType(DiveTypeBadgeRow));
      final tagRect = tester.getRect(find.byType(TagChips));
      expect(tagRect.top, greaterThanOrEqualTo(badgeRect.bottom));
    });
  });
}
