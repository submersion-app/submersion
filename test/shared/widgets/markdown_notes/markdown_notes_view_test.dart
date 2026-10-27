import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

import '../../../helpers/test_app.dart';

/// Every leaf span in [span], depth first.
Iterable<TextSpan> _leaves(InlineSpan span) sync* {
  if (span is TextSpan) {
    if (span.text != null) yield span;
    for (final child in span.children ?? const <InlineSpan>[]) {
      yield* _leaves(child);
    }
  }
}

/// The leaf span whose text is exactly [text], across every rich text.
TextSpan _span(WidgetTester tester, String text) {
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    for (final leaf in _leaves(rich.text)) {
      if (leaf.text == text) return leaf;
    }
  }
  throw StateError('no span "$text"');
}

/// All visible text, joined.
String _allText(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join('\n');

void main() {
  Future<List<Uri>> pump(
    WidgetTester tester,
    String source, {
    bool launchResult = true,
    ThemeData? theme,
  }) async {
    final launched = <Uri>[];
    final view = MarkdownNotesView(
      source,
      launch: (uri) async {
        launched.add(uri);
        return launchResult;
      },
    );
    await tester.pumpWidget(
      theme == null
          ? testApp(child: view)
          : MaterialApp(
              theme: theme,
              home: Scaffold(body: view),
            ),
    );
    await tester.pumpAndSettle();
    return launched;
  }

  testWidgets('draws bold and italic as styled spans', (tester) async {
    await pump(tester, 'Viz was **great**, *maybe* 25 m');
    expect(_span(tester, 'great').style?.fontWeight, FontWeight.bold);
    expect(_span(tester, 'maybe').style?.fontStyle, FontStyle.italic);
    expect(_allText(tester), isNot(contains('**')));
  });

  testWidgets('keeps single line breaks', (tester) async {
    await pump(tester, 'Saw turtle\nSaw shark');
    expect(_allText(tester), contains('Saw turtle\nSaw shark'));
  });

  testWidgets('draws headings without their marks', (tester) async {
    await pump(tester, '# On the wreck\nbody');
    expect(_allText(tester), contains('On the wreck'));
    expect(_allText(tester), isNot(contains('#')));
    expect(_span(tester, 'On the wreck').style?.fontWeight, FontWeight.w600);
  });

  testWidgets('draws bullet and numbered lists with markers', (tester) async {
    await pump(tester, '- a\n- b\n\n3. c\n4. d');
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('3.'), findsOneWidget);
    expect(find.text('4.'), findsOneWidget);
  });

  testWidgets('draws task boxes that cannot be ticked', (tester) async {
    await pump(tester, '- [ ] fins\n- [x] mask');
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('draws a table, a quote, code and a rule', (tester) async {
    await pump(
      tester,
      '| a | b |\n|---|---|\n| 1 | 2 |\n\n> said\n\n```\nx = 1\n```\n\n---',
    );
    expect(find.byType(Table), findsOneWidget);
    expect(_allText(tester), contains('said'));
    expect(_allText(tester), contains('x = 1'));
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('tapping an https link launches it', (tester) async {
    final launched = await pump(tester, 'Shop: [shop](https://s.test)');
    await tester.tapOnText(find.textRange.ofSubstring('shop'));
    await tester.pumpAndSettle();
    expect(launched, [Uri.parse('https://s.test')]);
  });

  testWidgets('a bare address is a link', (tester) async {
    final launched = await pump(tester, 'see https://s.test today');
    await tester.tapOnText(find.textRange.ofSubstring('https://s.test'));
    await tester.pumpAndSettle();
    expect(launched, [Uri.parse('https://s.test')]);
  });

  testWidgets('a javascript link is plain text', (tester) async {
    final launched = await pump(tester, '[xss](javascript:alert(1))');
    await tester.tapOnText(find.textRange.ofSubstring('xss'));
    await tester.pumpAndSettle();
    expect(launched, isEmpty);
    expect(_span(tester, 'xss').recognizer, isNull);
  });

  testWidgets('an image draws as a link labelled by its alt text', (
    tester,
  ) async {
    final launched = await pump(tester, '![reef](https://x.test/a.png)');
    expect(find.byType(Image), findsNothing);
    await tester.tapOnText(find.textRange.ofSubstring('reef'));
    await tester.pumpAndSettle();
    expect(launched, [Uri.parse('https://x.test/a.png')]);
  });

  testWidgets('a failed launch says the link could not be opened', (
    tester,
  ) async {
    await pump(tester, '[shop](https://s.test)', launchResult: false);
    await tester.tapOnText(find.textRange.ofSubstring('shop'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open the link'), findsOneWidget);
  });

  testWidgets('links use the dark theme primary colour', (tester) async {
    final theme = ThemeData.dark();
    await pump(tester, '[shop](https://s.test)', theme: theme);
    expect(_span(tester, 'shop').style?.color, theme.colorScheme.primary);
  });

  testWidgets('HTML shows as typed', (tester) async {
    await pump(tester, '<u>x</u>');
    expect(_allText(tester), contains('<u>x</u>'));
  });

  testWidgets('the could-not-open snackbar copies the link', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester, '[shop](https://s.test)', launchResult: false);
    await tester.tapOnText(find.textRange.ofSubstring('shop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, 'https://s.test');
  });

  testWidgets('a launch that throws counts as a failed open', (tester) async {
    final view = MarkdownNotesView(
      '[shop](https://s.test)',
      launch: (_) async => throw Exception('no handler'),
    );
    await tester.pumpWidget(testApp(child: view));
    await tester.tapOnText(find.textRange.ofSubstring('shop'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open the link'), findsOneWidget);
  });

  testWidgets('draws every heading level, strikethrough and hard breaks', (
    tester,
  ) async {
    await pump(tester, '## Two\n\n#### Four\n\n~~old~~ line  \nbreak');
    expect(_span(tester, 'Two').style?.fontWeight, FontWeight.w600);
    expect(_span(tester, 'Four').style?.fontWeight, FontWeight.w600);
    expect(_span(tester, 'old').style?.decoration, TextDecoration.lineThrough);
    expect(_allText(tester), contains('line\nbreak'));
  });

  testWidgets('draws nested and loose list items', (tester) async {
    await pump(tester, '- outer\n  - inner\n\n- loose');
    expect(find.text('•'), findsNWidgets(3));
    expect(_allText(tester), contains('inner'));
    expect(_allText(tester), contains('loose'));
  });

  testWidgets('a task in a loose list keeps its box', (tester) async {
    await pump(tester, '- loose\n\n- [x] done');
    expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
  });

  testWidgets('a rebuild with the same note keeps its link recognizers', (
    tester,
  ) async {
    late StateSetter rebuild;
    await tester.pumpWidget(
      testApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            // Not const, so the rebuild reaches the view.
            return MarkdownNotesView(
              '[shop](https://s.test)',
              style: Theme.of(context).textTheme.bodyMedium,
            );
          },
        ),
      ),
    );
    final before = _span(tester, 'shop').recognizer;
    rebuild(() {});
    await tester.pump();
    expect(_span(tester, 'shop').recognizer, same(before));
  });

  testWidgets('a three-digit list number stays on one line', (tester) async {
    await pump(tester, '100. c');
    expect(
      tester.getSize(find.text('100.')).height,
      tester.getSize(find.text('c')).height,
    );
  });
}
