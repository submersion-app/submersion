import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import 'record_editor_host_harness.dart';

/// An editor that holds Save back while its form is incomplete (issue
/// #4527, phase 4, plan 4: a rule with no name or no action).
void main() {
  late EditorProbe probe;

  setUp(() async {
    await setUpTestDatabase();
    probe = EditorProbe();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/edit'),
              child: const Text('open'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'edit',
              onExit: confirmLeaveRecordSitting,
              builder: (_, _) => FakeEditorPage(probe: probe),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => ref.watch(currentDiverIdProvider),
          ),
        ],
        child: RecordEditShortcuts(
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    );
    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('a');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  AppBarTextAction save(WidgetTester tester) => tester
      .widgetList<AppBarTextAction>(find.byType(AppBarTextAction))
      .firstWhere((a) => a.label == 'Save');

  Future<void> type(WidgetTester tester, String value) async {
    await tester.enterText(find.byKey(const ValueKey('field')), value);
    await tester.pumpAndSettle();
  }

  testWidgets('Save stays disabled while the editor says it cannot save', (
    tester,
  ) async {
    probe.canSave = (draft) => draft.isNotEmpty;
    await pump(tester);
    await type(tester, '');
    expect(save(tester).onPressed, isNull);
    await type(tester, 'b');
    expect(save(tester).onPressed, isNotNull);
  });

  testWidgets('Cmd+S does nothing while the editor says it cannot save', (
    tester,
  ) async {
    probe.canSave = (draft) => draft.isNotEmpty;
    await pump(tester);
    await type(tester, '');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(probe.writes, isEmpty);
    expect(find.byKey(const ValueKey('field')), findsOneWidget);
  });

  testWidgets('an editor that says nothing saves as before', (tester) async {
    await pump(tester);
    await type(tester, '');
    expect(save(tester).onPressed, isNotNull);
  });
}
