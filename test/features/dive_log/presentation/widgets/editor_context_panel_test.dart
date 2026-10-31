import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/editor_context_panel.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TrackingProfileEditorNotifier extends ProfileEditorNotifier {
  int trimEndZerosCallCount = 0;

  _TrackingProfileEditorNotifier()
    : super(
        originalProfile: const [
          DiveProfilePoint(timestamp: 0, depth: 10.0),
          DiveProfilePoint(timestamp: 60, depth: 0.0),
          DiveProfilePoint(timestamp: 120, depth: 0.0),
        ],
        editingService: ProfileEditingService(),
      );

  @override
  void trimEndZeros() {
    trimEndZerosCallCount += 1;
  }
}

void main() {
  testWidgets('trim mode renders controls and invokes trim action', (
    tester,
  ) async {
    final notifier = _TrackingProfileEditorNotifier();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: EditorContextPanel(mode: EditorMode.trim, notifier: notifier),
        ),
      ),
    );

    expect(find.text('Trim Mode'), findsOneWidget);
    expect(find.text('Trim profile endpoints'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Trim End'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Trim End'));

    expect(notifier.trimEndZerosCallCount, 1);
  });

  group('range operations the profile cannot take (issue #3909)', () {
    late ProfileEditorNotifier notifier;

    Future<void> pumpPanel(
      WidgetTester tester, {
      EditorMode mode = EditorMode.select,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: EditorContextPanel(
              mode: mode,
              notifier: notifier,
              selectedRange: notifier.state.selectedRange,
            ),
          ),
        ),
      );
    }

    setUp(() {
      notifier = ProfileEditorNotifier(
        originalProfile: List.generate(
          8,
          (i) => DiveProfilePoint(timestamp: i * 4, depth: 10),
        ),
        editingService: ProfileEditingService(),
      );
    });

    testWidgets('a time shift blocked by the next sample says so', (
      tester,
    ) async {
      notifier.setSelectedRange(start: 8, end: 16);
      await pumpPanel(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Time +5s'));
      await tester.pump();

      expect(
        find.text("Can't shift: the selection has no room to move that way"),
        findsOneWidget,
      );
      expect(notifier.state.hasChanges, isFalse);
    });

    testWidgets('a time shift with room says nothing', (tester) async {
      notifier.setSelectedRange(start: 8, end: 28);
      await pumpPanel(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Time +5s'));
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      expect(notifier.state.hasChanges, isTrue);
    });

    testWidgets('deleting every sample says so', (tester) async {
      notifier.setSelectedRange(start: 0, end: 28);
      await pumpPanel(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pump();

      expect(find.text("Can't delete the whole profile"), findsOneWidget);
      expect(notifier.state.hasChanges, isFalse);
    });

    testWidgets('a delete that leaves samples says nothing', (tester) async {
      notifier.setSelectedRange(start: 8, end: 16);
      await pumpPanel(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      expect(notifier.state.hasChanges, isTrue);
    });

    testWidgets('smoothing too few samples says so', (tester) async {
      notifier.setSelectedRange(start: 8, end: 12);
      await pumpPanel(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Smooth'));
      await tester.pump();

      expect(
        find.text("Can't smooth: select at least three samples"),
        findsOneWidget,
      );
      expect(notifier.state.hasChanges, isFalse);
    });

    testWidgets('smoothing enough samples says nothing', (tester) async {
      notifier.setSelectedRange(start: 8, end: 16);
      await pumpPanel(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Smooth'));
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
      expect(notifier.state.hasChanges, isTrue);
    });

    testWidgets('a time shift past the start of the dive says so', (
      tester,
    ) async {
      notifier.setSelectedRange(start: 0, end: 8);
      await pumpPanel(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Time -5s'));
      await tester.pump();

      expect(
        find.text("Can't shift: the selection has no room to move that way"),
        findsOneWidget,
      );
      expect(notifier.state.hasChanges, isFalse);
    });

    testWidgets('Apply to Selection smooths at the chosen strength', (
      tester,
    ) async {
      final points = List.generate(
        8,
        (i) => DiveProfilePoint(timestamp: i * 4, depth: i.isEven ? 10 : 20),
      );
      notifier = ProfileEditorNotifier(
        originalProfile: points,
        editingService: ProfileEditingService(),
      );
      notifier.setSelectedRange(start: 0, end: 28);
      await pumpPanel(tester, mode: EditorMode.smooth);

      await tester.tap(find.text('Heavy'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply to Selection'));
      await tester.pump();

      expect(
        notifier.state.editedProfile.map((p) => p.depth).toList(),
        ProfileEditingService()
            .smoothProfile(points, windowSize: 7)
            .map((p) => p.depth)
            .toList(),
      );
    });
  });
}
