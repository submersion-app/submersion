import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/core/theme/contrast_ratio.dart';
import 'package:submersion/core/theme/record_pencil_colors.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

Widget _host({
  bool canSave = true,
  bool isSaving = false,
  VoidCallback? onCancel,
  VoidCallback? onSave,
  ThemeData? theme,
  List<Widget> actions = const [],
  String? saveLabel,
  double textScale = 1,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      appBar: RecordEditBar(
        title: 'Editing dive 214',
        canSave: canSave,
        isSaving: isSaving,
        onCancel: onCancel ?? () {},
        onSave: onSave ?? () {},
        actions: actions,
        saveLabel: saveLabel,
      ),
    ),
  );
}

RecordEditAction _action(WidgetTester tester, String label) =>
    tester.widget<RecordEditAction>(
      find.byWidgetPredicate((w) => w is RecordEditAction && w.label == label),
    );

void main() {
  testWidgets('actions sit between the title and Save; none by default', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.byIcon(Icons.sell_outlined), findsNothing);

    await tester.pumpWidget(
      _host(
        actions: [
          IconButton(icon: const Icon(Icons.sell_outlined), onPressed: () {}),
        ],
      ),
    );

    final action = tester.getCenter(find.byIcon(Icons.sell_outlined)).dx;
    expect(
      action,
      greaterThan(tester.getCenter(find.text('Editing dive 214')).dx),
    );
    expect(action, lessThan(tester.getCenter(find.text('Save')).dx));
  });

  testWidgets('shows Cancel, the title and Save', (tester) async {
    await tester.pumpWidget(_host());

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Editing dive 214'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('Save and Cancel call back', (tester) async {
    var saved = 0;
    var cancelled = 0;
    await tester.pumpWidget(
      _host(onSave: () => saved++, onCancel: () => cancelled++),
    );

    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Cancel'));

    expect(saved, 1);
    expect(cancelled, 1);
  });

  testWidgets('Save is disabled when there is nothing to save', (tester) async {
    var saved = 0;
    await tester.pumpWidget(_host(canSave: false, onSave: () => saved++));

    await tester.tap(find.text('Save'));

    expect(saved, 0);
    expect(_action(tester, 'Save').onPressed, isNull);
    expect(_action(tester, 'Cancel').onPressed, isNotNull);
  });

  testWidgets('both actions are inert, and Save busy, while saving', (
    tester,
  ) async {
    await tester.pumpWidget(_host(isSaving: true));

    expect(_action(tester, 'Save').busy, isTrue);
    expect(_action(tester, 'Save').onPressed, isNull);
    expect(_action(tester, 'Cancel').onPressed, isNull);
  });

  testWidgets('there is no back arrow, even on a pushed page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: RecordEditBar(
                    title: 'Editing dive 214',
                    canSave: false,
                    isSaving: false,
                    onCancel: () {},
                    onSave: () {},
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Editing dive 214'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  for (final theme in [ThemeData.light(), ThemeData.dark()]) {
    testWidgets('the bar background is opaque (${theme.brightness.name})', (
      tester,
    ) async {
      await tester.pumpWidget(_host(theme: theme));

      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.backgroundColor, isNotNull);
      expect(bar.backgroundColor!.a, 1.0);
      expect(bar.backgroundColor, isNot(theme.colorScheme.surface));
    });
  }

  // Cancel and Save wear the pencil's amber so they stand out (issue
  // #5034): Save filled, the more prominent; Cancel a ring.
  testWidgets('Cancel is a ring and Save is filled', (tester) async {
    await tester.pumpWidget(_host());

    expect(_action(tester, 'Cancel').style, RecordEditActionStyle.ring);
    expect(_action(tester, 'Save').style, RecordEditActionStyle.filled);

    await tester.pumpWidget(_host(saveLabel: 'Send'));

    expect(_action(tester, 'Send').style, RecordEditActionStyle.filled);
  });

  // Several presets give the app bar a coloured background with a light
  // foreground. This bar brings its own pale background, so its title must
  // bring a foreground that reads on it too (#736, #1231). Cancel's label
  // and ring sit on the bar; Save's label sits on its own amber fill.
  for (final preset in AppThemeRegistry.presets) {
    for (final theme in [preset.lightTheme, preset.darkTheme]) {
      final mode = '${preset.id}, ${theme.brightness.name}';

      testWidgets('the bar text reads on its ground ($mode)', (tester) async {
        await tester.pumpWidget(_host(theme: theme));

        final background = tester
            .widget<AppBar>(find.byType(AppBar))
            .backgroundColor!;
        final fill = RecordPencilColors.of(
          tester.element(find.byType(AppBar)),
        ).fill;
        Color label(String text) => tester
            .renderObject<RenderParagraph>(find.text(text))
            .text
            .style!
            .color!;
        final cancelRing =
            (tester
                        .widget<Material>(
                          find
                              .descendant(
                                of: find.byType(RecordEditAction).first,
                                matching: find.byType(Material),
                              )
                              .first,
                        )
                        .shape!
                    as OutlinedBorder)
                .side
                .color;

        expect(
          contrastRatio(label('Editing dive 214'), background),
          greaterThanOrEqualTo(4.5),
          reason: 'the title on the bar',
        );
        expect(
          contrastRatio(label('Cancel'), background),
          greaterThanOrEqualTo(4.5),
          reason: "Cancel's label on the bar",
        );
        expect(
          contrastRatio(cancelRing, background),
          greaterThanOrEqualTo(3),
          reason: "Cancel's ring against the bar",
        );
        expect(
          contrastRatio(label('Save'), fill),
          greaterThanOrEqualTo(4.5),
          reason: "Save's label on its fill",
        );
      });

      testWidgets('the saving spinner reads on the fill ($mode)', (
        tester,
      ) async {
        await tester.pumpWidget(_host(theme: theme, isSaving: true));

        final fill = RecordPencilColors.of(
          tester.element(find.byType(AppBar)),
        ).fill;
        final spinner = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );

        expect(contrastRatio(spinner.color!, fill), greaterThanOrEqualTo(3));
      });
    }
  }

  // Dutch has the longest Cancel (Annuleren) of the app's languages. The
  // test font draws every glyph as a full square, about twice a real
  // font's width, so this is a harder fit than any real phone.
  testWidgets('long labels fit a phone-width bar', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(locale: const Locale('nl')));

    expect(tester.takeException(), isNull);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('Editing dive 214'))
          .didExceedMaxLines,
      isTrue,
      reason: 'the title gives way before the actions do',
    );
  });

  testWidgets('the bar fits at 200% text', (tester) async {
    await tester.pumpWidget(_host(textScale: 2));

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(AppBar)).height,
      kToolbarHeight,
      reason: 'the bar keeps its height',
    );
  });

  // A sitting that ends otherwise (a reader's Send, issue #4527) names its
  // own Save.
  testWidgets('a save label replaces Save', (tester) async {
    var saved = 0;
    await tester.pumpWidget(_host(saveLabel: 'Send', onSave: () => saved++));

    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    await tester.tap(find.text('Send'));
    expect(saved, 1);
  });
}
