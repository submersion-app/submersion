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

    // Issue: the OC/CCR mode badge used to crowd the title line. It now sits
    // on the stat/type-badge row below the mini profile chart, as the
    // right-most badge on that line.
    testWidgets('puts the mode badge on the type badge row, right-most', (
      tester,
    ) async {
      await tester.pumpWidget(tile(['wreck', 'night']));
      await tester.pumpAndSettle();

      final modeRect = tester.getRect(find.byType(DiveModeBadge));
      final typeRowRect = tester.getRect(find.byType(DiveTypeBadgeRow));

      expect(modeRect.center.dy, closeTo(typeRowRect.center.dy, 0.5));
      expect(modeRect.left, greaterThanOrEqualTo(typeRowRect.right));
    });

    testWidgets('keeps the mode badge off the title line', (tester) async {
      await tester.pumpWidget(tile(['wreck']));
      await tester.pumpAndSettle();

      final modeRect = tester.getRect(find.byType(DiveModeBadge));
      final titleRect = tester.getRect(find.text('Blue Hole'));
      expect(modeRect.top, greaterThan(titleRect.bottom));
    });

    testWidgets('right-aligns the mode badge when the dive has no types', (
      tester,
    ) async {
      await tester.pumpWidget(tile([]));
      await tester.pumpAndSettle();

      final cardRect = tester.getRect(find.byType(Card));
      final modeRect = tester.getRect(find.byType(DiveModeBadge));
      final titleRect = tester.getRect(find.text('Blue Hole'));
      expect(modeRect.center.dx, greaterThan(cardRect.center.dx));
      expect(modeRect.top, greaterThan(titleRect.bottom));
    });

    testWidgets('mirrors in RTL: the mode badge stays at the trailing edge', (
      tester,
    ) async {
      // The whole card mirrors in RTL (the badge cell aligns with
      // AlignmentDirectional.centerEnd), so "right-most" becomes left-most:
      // the mode badge keeps the card's outer edge rather than being pinned
      // physically right, which would strand it inside the cluster.
      await tester.pumpWidget(
        harness(
          builder: (resolve, isVisible) => Directionality(
            textDirection: TextDirection.rtl,
            child: DiveListTile(
              diveId: 'd1',
              diveNumber: 7,
              dateTime: DateTime(2026, 3, 15),
              siteName: 'Blue Hole',
              maxDepth: 20.0,
              duration: const Duration(minutes: 30),
              summary: summaryWith(['wreck', 'night']),
              onTap: () {},
              diveTypeShortLabelResolver: resolve,
              diveTypeListVisibilityPredicate: isVisible,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardRect = tester.getRect(find.byType(Card));
      final modeRect = tester.getRect(find.byType(DiveModeBadge));
      final typeRowRect = tester.getRect(find.byType(DiveTypeBadgeRow));
      expect(modeRect.center.dx, lessThan(cardRect.center.dx));
      expect(modeRect.right, lessThanOrEqualTo(typeRowRect.left));
      expect(modeRect.center.dy, closeTo(typeRowRect.center.dy, 0.5));
    });

    testWidgets('fits a phone-width row with types and the mode badge', (
      tester,
    ) async {
      // The mode badge moved onto this line, so the stat row, the type
      // badges and the badge now compete for one phone-width line. The
      // type badges must collapse rather than the row overflowing.
      tester.view.physicalSize = const Size(353, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(tile(['wreck', 'night', 'drift', 'cave']));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DiveModeBadge), findsOneWidget);
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
