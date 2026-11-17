import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_resync_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_overflow_menu.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

/// The dive menu on a page that offers editing (issue #4527): reading items
/// first, then the whole-record operations, disabled under one caption
/// until the page is unlocked with nothing to save.
void main() {
  final planned = Dive(
    id: 'p1',
    dateTime: DateTime.utc(2026, 7, 17, 10),
    isPlanned: true,
  );

  Future<List<String>> pumpMenu(
    WidgetTester tester, {
    required RecordOperationBlock operations,
    bool historyInBar = false,
  }) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...await getBaseOverrides(),
          diveHasRawDataProvider(planned.id).overrideWith((ref) async => false),
          diveHasImportedFileProvider(
            planned.id,
          ).overrideWith((ref) async => true),
          preDiveSessionForDiveProvider(
            planned.id,
          ).overrideWith((ref) async => null),
          mirrorCandidatesProvider(planned.id).overrideWith((ref) async => []),
        ],
        child: DiveDetailOverflowMenu(
          dive: planned,
          embedded: false,
          menuKey: GlobalKey(),
          displayOptions: MenuController(),
          onSelected: (_, _) {},
          operations: operations,
          historyInBar: historyInBar,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    return [
      for (final item in tester.widgetList<PopupMenuEntry<String>>(
        find.byWidgetPredicate((w) => w is PopupMenuEntry<String>),
      ))
        _label(tester, item),
    ];
  }

  bool enabled(WidgetTester tester, String label) => tester
      .widget<PopupMenuItem<String>>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is PopupMenuItem<String>),
        ),
      )
      .enabled;

  testWidgets('locked: reading items enabled, operations disabled under '
      'the caption', (tester) async {
    final items = await pumpMenu(
      tester,
      operations: RecordOperationBlock.locked,
    );

    expect(find.text('Unlock to use these'), findsOneWidget);
    expect(enabled(tester, 'Export'), isTrue);
    expect(enabled(tester, 'Log near-miss'), isTrue);
    for (final label in [
      'Mark as logged',
      'Resync from original file',
      'Delete',
      'Link pre-dive checklist',
      'Draw a profile',
    ]) {
      expect(enabled(tester, label), isFalse, reason: label);
    }
    // Reading items, the divider and caption, then the operations.
    expect(items.indexOf('Export'), lessThan(items.indexOf('|')));
    expect(items.indexOf('|'), lessThan(items.indexOf('caption')));
    expect(items.indexOf('caption'), lessThan(items.indexOf('Mark as logged')));
    expect(items.last, 'Delete');
    expect(items.first, 'History');
  });

  testWidgets('unlocked and clean: no caption, operations enabled', (
    tester,
  ) async {
    await pumpMenu(tester, operations: RecordOperationBlock.none);

    expect(find.byKey(const ValueKey('recordOperationCaption')), findsNothing);
    for (final label in [
      'Mark as logged',
      'Resync from original file',
      'Delete',
      'Link pre-dive checklist',
      'Draw a profile',
    ]) {
      expect(enabled(tester, label), isTrue, reason: label);
    }
  });

  testWidgets('unlocked with a change: "Save or cancel your changes first"', (
    tester,
  ) async {
    await pumpMenu(tester, operations: RecordOperationBlock.unsaved);

    expect(find.text('Save or cancel your changes first'), findsOneWidget);
    expect(enabled(tester, 'Delete'), isFalse);
  });

  testWidgets('History beside the lock leaves it out of the menu', (
    tester,
  ) async {
    final items = await pumpMenu(
      tester,
      operations: RecordOperationBlock.locked,
      historyInBar: true,
    );

    expect(items, isNot(contains('History')));
  });
}

/// What a menu entry reads: its first text, '|' for a divider, 'caption'
/// for the operations' caption.
String _label(WidgetTester tester, PopupMenuEntry<String> entry) {
  if (entry is PopupMenuDivider) return '|';
  if (entry.key == const ValueKey('recordOperationCaption')) return 'caption';
  final texts = find.descendant(
    of: find.byWidget(entry),
    matching: find.byType(Text),
  );
  return tester.widgetList<Text>(texts).first.data ?? '';
}
