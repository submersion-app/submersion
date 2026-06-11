import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/edit_form_scaffold.dart';

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  testWidgets('full-page mode: AppBar title and save action', (tester) async {
    var saved = 0;
    await tester.pumpWidget(
      _app(
        EditFormScaffold(
          title: 'Edit Dive',
          embedded: false,
          isSaving: false,
          hasUnsavedChanges: false,
          onSave: () => saved++,
          child: const Text('BODY'),
        ),
      ),
    );
    expect(find.text('Edit Dive'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    await tester.tap(find.text('Save'));
    expect(saved, 1);
  });

  testWidgets('embedded mode: compact header with cancel + save', (
    tester,
  ) async {
    var cancelled = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: EditFormScaffold(
            title: 'New Dive',
            embedded: true,
            isSaving: false,
            hasUnsavedChanges: false,
            onSave: () {},
            onCancel: () => cancelled++,
            child: const Text('BODY'),
          ),
        ),
      ),
    );
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('New Dive'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    expect(cancelled, 1);
  });

  testWidgets('saving state shows spinner instead of save button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        EditFormScaffold(
          title: 'Edit Dive',
          embedded: false,
          isSaving: true,
          hasUnsavedChanges: false,
          onSave: () {},
          child: const Text('BODY'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('back with unsaved changes shows discard dialog; discard pops', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditFormScaffold(
                      title: 'Edit Dive',
                      embedded: false,
                      isSaving: false,
                      hasUnsavedChanges: true,
                      onSave: () {},
                      child: const Text('BODY'),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // System back attempt.
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsOneWidget);

    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('BODY'), findsNothing);
  });

  testWidgets('content is width-constrained', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        EditFormScaffold(
          title: 'Edit Dive',
          embedded: false,
          isSaving: false,
          hasUnsavedChanges: false,
          onSave: () {},
          child: const SizedBox(height: 10, width: double.infinity),
        ),
      ),
    );
    final constrained = tester.widget<ConstrainedBox>(
      find.byKey(const Key('editFormMaxWidth')),
    );
    expect(constrained.constraints.maxWidth, 640);
  });
}
