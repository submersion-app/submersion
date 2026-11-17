import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge_row.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/record_list_chevron.dart';

import '../../../../helpers/record_chevron_expectations.dart';
import '../../../../helpers/test_app.dart';

/// Issue #4639: the chevron sat in the dive cards' top row, so it ended at a
/// different place from the badges and tags below it, and the compact card
/// left a gap after it on a wide pane.
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

final _summary = DiveSummary(
  id: 'd1',
  diveNumber: 1137,
  dateTime: DateTime(2026, 3, 15),
  siteName: 'Valfiorita Wreck',
  maxDepth: 42.0,
  bottomTime: const Duration(minutes: 39),
  diveTypeIds: const ['wreck', 'deep'],
  sortTimestamp: 0,
);

Widget _harness(Widget child) => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    diveTypesProvider.overrideWith((ref) async => const []),
    detailedCardConfigProvider.overrideWith((ref) => _TestCardConfigNotifier()),
  ],
  child: child,
);

Future<void> _pumpAtWidth(
  WidgetTester tester,
  double width,
  Widget child,
) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_harness(child));
  await tester.pumpAndSettle();
}

void main() {
  final detailed = DiveListTile(
    diveId: 'd1',
    diveNumber: 1137,
    dateTime: DateTime(2026, 3, 15),
    siteName: 'Valfiorita Wreck',
    maxDepth: 42.0,
    duration: const Duration(minutes: 39),
    summary: _summary,
    onTap: () {},
  );
  final compact = CompactDiveListTile(
    diveId: 'd1',
    diveNumber: 1137,
    dateTime: DateTime(2026, 3, 15),
    siteName: 'Valfiorita Wreck',
    maxDepth: 42.0,
    duration: const Duration(minutes: 39),
    summary: _summary,
    onTap: () {},
  );

  group('detailed dive card', () {
    testWidgets('chevron ends one card padding from the edge, centred', (
      tester,
    ) async {
      await _pumpAtWidth(tester, 420, detailed);

      final card = recordCardBounds(tester);
      expectChevronAtEndPadding(
        tester,
        bounds: card,
        padding: kRecordCardDetailedPadding,
      );
      expect(
        tester.getRect(find.byType(RecordListChevron)).center.dy,
        closeTo(card.center.dy, 0.5),
      );
    });

    testWidgets('the mode badge ends where the chevron column starts', (
      tester,
    ) async {
      await _pumpAtWidth(tester, 420, detailed);

      expect(
        tester.getRect(find.byType(DiveModeBadge)).right,
        closeTo(tester.getRect(find.byType(RecordListChevron)).left, 0.5),
      );
    });
  });

  group('compact dive card', () {
    for (final width in [360.0, 1200.0]) {
      testWidgets('chevron ends one card padding from the edge at $width', (
        tester,
      ) async {
        await _pumpAtWidth(tester, width, compact);

        expect(tester.takeException(), isNull);
        expectChevronAtEndPadding(
          tester,
          bounds: recordCardBounds(tester),
          padding: kRecordCardCompactPadding,
        );
      });

      // The date slot was a loose Flexible beside an Expanded title, so it
      // was allotted half the free width whatever its text needed, and the
      // unused half sat between the mode badge and the card edge.
      testWidgets('the mode badge and the type badges share one end at '
          '$width', (tester) async {
        await _pumpAtWidth(tester, width, compact);

        final chevronStart = tester
            .getRect(find.byType(RecordListChevron))
            .left;
        expect(
          tester.getRect(find.byType(DiveModeBadge)).right,
          closeTo(chevronStart, 0.5),
        );
        expect(
          tester.getRect(find.byType(DiveTypeBadgeRow)).right,
          closeTo(chevronStart, 0.5),
        );
      });
    }
  });

  // The date cap must give way on a crowded narrow line rather than push the
  // row past the card: selection checkbox, a Planned chip and the mode badge
  // all sit on line 1 beside it.
  for (final width in [300.0, 340.0]) {
    testWidgets('a crowded compact line 1 fits at $width', (tester) async {
      final planned = DiveSummary(
        id: 'd1',
        diveNumber: null,
        dateTime: DateTime(2026, 3, 15, 14, 30),
        siteName: 'Valfiorita Wreck',
        maxDepth: 42.0,
        bottomTime: const Duration(minutes: 39),
        diveTypeIds: const ['wreck'],
        sortTimestamp: 0,
        isPlanned: true,
      );
      await _pumpAtWidth(
        tester,
        width,
        CompactDiveListTile(
          diveId: 'd1',
          diveNumber: 1,
          dateTime: DateTime(2026, 3, 15, 14, 30),
          siteName: 'Valfiorita Wreck',
          maxDepth: 42.0,
          duration: const Duration(minutes: 39),
          summary: planned,
          isSelectionMode: true,
          onTap: () {},
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }
}
