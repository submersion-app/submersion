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
}
