import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_contact_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import 'site_editor_harness.dart';

/// The Contact card edited in place (issue #5073).
void main() {
  final l = AppLocalizationsEn();
  const site = DiveSite(id: 's1', name: 'Stoney Cove');

  Future<SiteEditorHarness> pump(WidgetTester tester, {DiveSite s = site}) =>
      pumpSiteEditor(
        tester,
        s,
        (session) => SiteContactCardEditor(session: session),
      );

  Finder field(String label) => find.descendant(
    of: find.byKey(ValueKey('site_contact_edit_$label')),
    matching: find.byType(EditableText),
  );

  testWidgets('each field writes through, blank as none', (tester) async {
    final h = await pump(tester);

    await tester.enterText(field('address'), 'Stoney Cove\nLE9 4DW');
    await tester.enterText(field('phone'), '+44 1455 273089');
    await tester.enterText(field('email'), 'info@stoneycove.com');
    await tester.enterText(field('website'), 'stoneycove.com');
    await tester.pump();

    expect(h.session.valueOf(siteAddressField), 'Stoney Cove\nLE9 4DW');
    expect(h.session.valueOf(sitePhoneField), '+44 1455 273089');
    expect(h.session.valueOf(siteEmailField), 'info@stoneycove.com');
    expect(h.session.valueOf(siteWebsiteField), 'stoneycove.com');

    await tester.enterText(field('phone'), '   ');
    await tester.pump();
    expect(h.session.valueOf(sitePhoneField), isNull);
  });

  testWidgets('each field has the keyboard for its kind', (tester) async {
    await pump(tester);

    TextInputType? keyboard(String label) =>
        tester.widget<EditableText>(field(label)).keyboardType;
    expect(keyboard('phone'), TextInputType.phone);
    expect(keyboard('email'), TextInputType.emailAddress);
    expect(keyboard('website'), TextInputType.url);
    expect(tester.widget<EditableText>(field('address')).maxLines, 4);
    // The address spans lines, so Return starts a new one (review).
    expect(keyboard('address'), TextInputType.multiline);
    await tester.showKeyboard(field('address'));
    expect(
      tester.testTextInput.setClientArgs!['inputAction'],
      TextInputAction.newline.toString(),
    );
  });

  testWidgets('a bad email or website is refused, with the reason', (
    tester,
  ) async {
    final h = await pump(tester);

    await tester.enterText(field('email'), 'info@');
    await tester.pump();
    expect(siteContactIsValid(h.session), isFalse);
    expect(find.text(l.diveSites_edit_contact_emailInvalid), findsOneWidget);

    await tester.enterText(field('email'), 'info@stoneycove.com');
    await tester.enterText(field('website'), 'mailto:x@y.com');
    await tester.pump();
    expect(siteContactIsValid(h.session), isFalse);
    expect(find.text(l.diveSites_edit_contact_websiteInvalid), findsOneWidget);
    expect(find.text(l.diveSites_edit_contact_emailInvalid), findsNothing);

    await tester.enterText(field('website'), 'https://stoneycove.com/slots');
    await tester.pump();
    expect(siteContactIsValid(h.session), isTrue);
  });

  testWidgets('a bad value already stored does not block other edits', (
    tester,
  ) async {
    final h = await pump(tester, s: site.copyWith(website: 'not a link'));

    await tester.enterText(field('phone'), '123');
    await tester.pump();
    expect(siteContactIsValid(h.session), isTrue);
  });

  test('the validators', () {
    expect(isValidSiteEmail(''), isTrue);
    expect(isValidSiteEmail('a@b.co'), isTrue);
    expect(isValidSiteEmail('a@b'), isFalse);
    expect(isValidSiteEmail('a b@c.d'), isFalse);
    expect(isValidSiteWebsite(''), isTrue);
    expect(isValidSiteWebsite('stoneycove.com'), isTrue);
    expect(isValidSiteWebsite('javascript:alert(1)'), isFalse);
  });
}
