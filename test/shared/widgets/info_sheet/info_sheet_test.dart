import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/info_sheet/info_content.dart';
import 'package:submersion/shared/widgets/info_sheet/info_sheet.dart';

import '../../../helpers/test_app.dart';

const _full = InfoContent(
  title: 'Oxygen Toxicity',
  summary: 'How much oxygen exposure this dive added.',
  terms: [
    InfoEntry(term: 'CNS', body: 'Percent of the single-dive oxygen limit.'),
    InfoEntry(term: 'OTU', body: 'Oxygen tolerance units for the whole body.'),
  ],
  background: 'CNS follows the NOAA ppO2 exposure table.',
  howToUse: 'Move the cursor on the profile to read a moment.',
);

double _top(WidgetTester tester, Finder finder) => tester.getTopLeft(finder).dy;

void main() {
  testWidgets('shows sections in order', (tester) async {
    await tester.pumpWidget(
      testApp(child: const InfoSheetBody(content: _full)),
    );

    final title = _top(tester, find.text('Oxygen Toxicity'));
    final summary = _top(
      tester,
      find.text('How much oxygen exposure this dive added.'),
    );
    final cns = _top(tester, find.textContaining('Percent of the single-dive'));
    final otu = _top(tester, find.textContaining('Oxygen tolerance units'));
    final background = _top(tester, find.text('BACKGROUND'));
    final backgroundBody = _top(
      tester,
      find.text('CNS follows the NOAA ppO2 exposure table.'),
    );
    final howTo = _top(tester, find.text('HOW TO USE'));
    final howToBody = _top(
      tester,
      find.text('Move the cursor on the profile to read a moment.'),
    );

    expect(title, lessThan(summary));
    expect(summary, lessThan(cns));
    expect(cns, lessThan(otu));
    expect(otu, lessThan(background));
    expect(background, lessThan(backgroundBody));
    expect(backgroundBody, lessThan(howTo));
    expect(howTo, lessThan(howToBody));
  });

  testWidgets('omits empty sections', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const InfoSheetBody(
          content: InfoContent(title: 'Deco Status', summary: 'Short.'),
        ),
      ),
    );

    expect(find.text('Deco Status'), findsOneWidget);
    expect(find.text('Short.'), findsOneWidget);
    expect(find.text('BACKGROUND'), findsNothing);
    expect(find.text('HOW TO USE'), findsNothing);
    expect(find.byKey(InfoSheetBody.termsKey), findsNothing);
  });

  testWidgets('scrolls at text scale 2', (tester) async {
    final many = InfoContent(
      title: 'Many terms',
      terms: [
        for (var i = 0; i < 40; i++)
          InfoEntry(term: 'Term $i', body: 'Body for term number $i.'),
      ],
    );
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: SingleChildScrollView(child: InfoSheetBody(content: many)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.textContaining('Body for term number 39.'),
      200,
    );
    expect(find.textContaining('Body for term number 39.'), findsOneWidget);
  });

  testWidgets('aligns right in Arabic', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('ar'),
        child: const InfoSheetBody(content: _full),
      ),
    );

    final summary = find.text('How much oxygen exposure this dive added.');
    expect(Directionality.of(tester.element(summary)), TextDirection.rtl);
    final box = tester.getRect(summary);
    final sheet = tester.getRect(find.byType(InfoSheetBody));
    expect(sheet.right - box.right, lessThan(box.left - sheet.left));
  });
}
