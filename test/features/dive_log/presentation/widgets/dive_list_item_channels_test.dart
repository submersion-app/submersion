import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

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
  Widget host({
    required bool isSelectionMode,
    required bool isChecked,
    required bool isHighlighted,
  }) {
    return testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: CompactDiveListTile(
        diveId: 'a',
        diveNumber: 412,
        dateTime: DateTime(2026, 3, 15, 9, 30),
        siteName: 'Blue Hole',
        maxDepth: 32.0,
        duration: const Duration(minutes: 44),
        isSelectionMode: isSelectionMode,
        isChecked: isChecked,
        isHighlighted: isHighlighted,
        onTap: () {},
      ),
    );
  }

  group('dive tile state channels', () {
    testWidgets(
      'checked and highlighted render together on separate channels',
      (tester) async {
        await tester.pumpWidget(
          host(isSelectionMode: true, isChecked: true, isHighlighted: true),
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<Checkbox>(find.byType(Checkbox)).value,
          isTrue,
          reason: 'checked renders as the leading checkbox',
        );
        expect(
          find.byKey(const ValueKey('dive_row_highlight')),
          findsOneWidget,
          reason: 'highlight renders on its own channel, not as the checkbox',
        );
      },
    );

    testWidgets('highlighted alone shows no checkbox outside selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(isSelectionMode: false, isChecked: false, isHighlighted: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsNothing);
      expect(find.byKey(const ValueKey('dive_row_highlight')), findsOneWidget);
      expect(
        find.text('#412'),
        findsOneWidget,
        reason: 'the dive number stays visible outside selection mode',
      );
    });

    testWidgets('checked alone shows no highlight stripe', (tester) async {
      await tester.pumpWidget(
        host(isSelectionMode: true, isChecked: true, isHighlighted: false),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(find.byKey(const ValueKey('dive_row_highlight')), findsNothing);
    });

    testWidgets('the checkbox replaces the dive number in selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(isSelectionMode: true, isChecked: false, isHighlighted: false),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);
      expect(
        find.text('#412'),
        findsNothing,
        reason:
            'the checkbox replaces the leading element, it does not badge it',
      );
    });
  });
}
