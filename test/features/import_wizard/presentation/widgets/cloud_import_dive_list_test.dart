import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/presentation/widgets/cloud_import_dive_list.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('CloudImportDiveList', () {
    /// Pumps a list whose summaries change on every call, so a row that
    /// formatted its title and subtitle separately would show two different
    /// strings.
    Future<void> pumpCountingList(WidgetTester tester, {int rows = 3}) async {
      var calls = 0;
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: CloudImportDiveList(
            itemCount: rows,
            selectedIndices: const {},
            summaryOf: (index) {
              calls++;
              return (title: 'call $calls', subtitle: 'call $calls');
            },
            onToggle: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('formats each row once for both title and subtitle', (
      tester,
    ) async {
      await pumpCountingList(tester);

      final tiles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(tiles, hasLength(3));

      for (final tile in tiles) {
        expect(
          (tile.subtitle! as Text).data,
          (tile.title! as Text).data,
          reason: 'title and subtitle must come from one summary computation',
        );
      }
    });

    testWidgets('toggling a row reports its index', (tester) async {
      final toggled = <int>[];
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: CloudImportDiveList(
            itemCount: 2,
            selectedIndices: const {0},
            summaryOf: (index) => (title: 'Dive $index', subtitle: 'sub'),
            onToggle: toggled.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dive 1'));

      expect(toggled, [1]);
    });
  });
}
