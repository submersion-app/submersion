import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/catalogue_site_page.dart';

import 'catalogue_site_page_harness.dart';

const _addAction = ValueKey('catalogueAddAction');
const _addButton = ValueKey('catalogueAddButton');

/// The site an adoption of [record] makes.
DiveSite _adopted(CatalogueSite record) => DiveSite(
  id: 'new_site',
  name: record.name,
  location: record.location,
  catalogueId: record.id,
);

bool _enabled(WidgetTester tester, Key key) =>
    switch (tester.widget(find.byKey(key))) {
      final IconButton button => button.onPressed != null,
      final ButtonStyleButton button => button.onPressed != null,
      _ => throw StateError('not a button'),
    };

void main() {
  testWidgets('adding goes through the one adoption path, says so, and '
      'opens the diver\'s own new site', (tester) async {
    final adopted = <String>[];
    final rules = RecordingRuleEngine();
    await pumpCataloguePage(
      tester,
      id: saltPier.id,
      fromHome: true,
      rules: rules,
      adopter: (record) async {
        adopted.add(record.id);
        return CatalogueAdoption(site: _adopted(record), created: true);
      },
    );

    await tester.ensureVisible(find.byKey(_addButton));
    await tester.tap(find.byKey(_addButton));
    await settle(tester);

    expect(adopted, [saltPier.id]);
    expect(find.text('Added to your sites'), findsOneWidget);
    expect(find.text(ownPageText('new_site')), findsOneWidget);
    expect(find.byType(CatalogueSitePage), findsNothing);
    // A site made by this tap gets the diver's "after create" rules.
    expect(rules.runs, [
      {'new_site'},
    ]);

    // Back goes to where the page was opened from, not to the built-in page.
    await tester.pageBack();
    await settle(tester);
    expect(find.text(homeText), findsOneWidget);
    expect(find.byType(CatalogueSitePage), findsNothing);
  });

  testWidgets('the app bar action adds too', (tester) async {
    final adopted = <String>[];
    await pumpCataloguePage(
      tester,
      id: saltPier.id,
      adopter: (record) async {
        adopted.add(record.id);
        return CatalogueAdoption(site: _adopted(record), created: true);
      },
    );

    await tester.tap(find.byKey(_addAction));
    await settle(tester);

    expect(adopted, [saltPier.id]);
    expect(find.text(ownPageText('new_site')), findsOneWidget);
  });

  testWidgets('a second tap while the first is under way does nothing: '
      'both buttons wait', (tester) async {
    final gate = Completer<CatalogueAdoption>();
    var calls = 0;
    await pumpCataloguePage(
      tester,
      id: saltPier.id,
      adopter: (record) {
        calls++;
        return gate.future;
      },
    );

    await tester.tap(find.byKey(_addAction));
    await tester.pump();

    expect(_enabled(tester, _addAction), isFalse);
    expect(_enabled(tester, _addButton), isFalse);

    await tester.tap(find.byKey(_addAction), warnIfMissed: false);
    await tester.ensureVisible(find.byKey(_addButton));
    await tester.tap(find.byKey(_addButton), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);

    gate.complete(CatalogueAdoption(site: _adopted(saltPier), created: true));
    await settle(tester);
    expect(find.text(ownPageText('new_site')), findsOneWidget);
    expect(calls, 1);
  });

  testWidgets('a diver who leaves while the site is being added is still '
      'told it was', (tester) async {
    final gate = Completer<CatalogueAdoption>();
    final rules = RecordingRuleEngine();
    await pumpCataloguePage(
      tester,
      id: saltPier.id,
      fromHome: true,
      rules: rules,
      adopter: (record) => gate.future,
    );

    await tester.tap(find.byKey(_addAction));
    await tester.pump();
    await tester.pageBack();
    await settle(tester);
    expect(find.text(homeText), findsOneWidget);

    gate.complete(CatalogueAdoption(site: _adopted(saltPier), created: true));
    await settle(tester);

    expect(find.text('Added to your sites'), findsOneWidget);
    // Still where the diver went, and the new site still got its rules.
    expect(find.text(homeText), findsOneWidget);
    expect(rules.runs, [
      {'new_site'},
    ]);
  });

  testWidgets('a site the diver already had is opened without running '
      'their rules on it again', (tester) async {
    final rules = RecordingRuleEngine();
    await pumpCataloguePage(
      tester,
      id: saltPier.id,
      rules: rules,
      adopter: (record) async =>
          CatalogueAdoption(site: _adopted(record), created: false),
    );

    await tester.tap(find.byKey(_addAction));
    await settle(tester);

    expect(find.text(ownPageText('new_site')), findsOneWidget);
    expect(rules.runs, isEmpty);
  });

  testWidgets('when adding fails the page stays, says so, and can be '
      'tried again', (tester) async {
    var calls = 0;
    await pumpCataloguePage(
      tester,
      id: saltPier.id,
      adopter: (record) async {
        calls++;
        throw Exception('write failed');
      },
    );

    await tester.tap(find.byKey(_addAction));
    await settle(tester);

    expect(find.text("Couldn't add site. Please try again."), findsOneWidget);
    expect(find.byType(CatalogueSitePage), findsOneWidget);
    expect(find.text('Pillars covered in sponges.'), findsOneWidget);
    expect(_enabled(tester, _addAction), isTrue);

    await tester.tap(find.byKey(_addAction));
    await settle(tester);
    expect(calls, 2);
  });

  testWidgets('adding leaves one page in the built-in page\'s place, '
      'though the add and the diver\'s sites changing both ask to replace '
      'it', (tester) async {
    late final dynamic container;
    container = await pumpCataloguePage(
      tester,
      id: saltPier.id,
      fromHome: true,
      adopter: (record) async {
        // The adoption lands in the diver's sites, as the real one does,
        // which is the page's other reason to move on.
        container.read(mineProvider.notifier).state = [
          own('new_site', catalogueId: record.id),
        ];
        return CatalogueAdoption(site: _adopted(record), created: true);
      },
    );

    await tester.tap(find.byKey(_addAction));
    await settle(tester);

    expect(find.text(ownPageText('new_site')), findsOneWidget);

    // One page was put in the built-in page's place: one step back is home.
    await tester.pageBack();
    await settle(tester);
    expect(find.text(homeText), findsOneWidget);
    expect(find.text(ownPageText('new_site')), findsNothing);
  });
}
