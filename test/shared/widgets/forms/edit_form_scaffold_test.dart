import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets(
    'full-page save button uses AppBar foreground color, not primary',
    (tester) async {
      // Simulates themes like Tropical where AppBar bg == primary color,
      // which would make a default TextButton invisible.
      const appBarForeground = Color(0xFFFFFFFF);
      const primary = Color(0xFF00B4A0);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorScheme: const ColorScheme.light(primary: primary),
            appBarTheme: const AppBarTheme(
              backgroundColor: primary,
              foregroundColor: appBarForeground,
            ),
          ),
          home: EditFormScaffold(
            title: 'Edit',
            embedded: false,
            isSaving: false,
            hasUnsavedChanges: false,
            onSave: () {},
            child: const SizedBox(),
          ),
        ),
      );

      // The text style should resolve to the AppBar foreground, not primary.
      final renderParagraph = tester.renderObject<RenderParagraph>(
        find.text('Save'),
      );
      final paintedColor = renderParagraph.text.style?.color;
      expect(paintedColor, appBarForeground);
    },
  );

  testWidgets('does not impose a fixed content width', (tester) async {
    // Width handling moved to ResponsiveFormColumns; the scaffold passes the
    // body through so it can fill the available pane.
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
          child: const SizedBox(
            key: Key('body'),
            height: 10,
            width: double.infinity,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('editFormMaxWidth')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('body'))).width, 1600);
  });
}
