import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_cards.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_header_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import 'site_editor_harness.dart';

/// The site's header block edited in place: its name and its water (issue
/// #4527, phase 2, plan 2).
void main() {
  final l = AppLocalizationsEn();
  const site = DiveSite(id: 's1', name: 'Blue Hole', waterType: WaterType.salt);

  Future<SiteEditorHarness> pump(WidgetTester tester, [DiveSite s = site]) =>
      pumpSiteEditor(
        tester,
        s,
        (session) => SiteHeaderCardEditor(session: session),
      );

  testWidgets('typing the name writes it', (tester) async {
    final h = await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Great Blue Hole');
    await tester.pump();

    expect(h.session.valueOf(siteNameField), 'Great Blue Hole');
    expect(h.session.changedCardIds, {siteHeaderCardId});
  });

  testWidgets('a blank name refuses Save and shows the message', (
    tester,
  ) async {
    final h = await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, '  ');
    await tester.pumpAndSettle();

    expect(siteHeaderCard.isValid!(h.session), isFalse);
    expect(
      find.text(l.diveSites_edit_field_siteName_validation),
      findsOneWidget,
    );
  });

  testWidgets('a stored blank name does not block saving another card', (
    tester,
  ) async {
    final h = await pump(tester, site.copyWith(name: ''));

    expect(siteHeaderCard.isValid!(h.session), isTrue);
  });

  testWidgets('tapping the selected water type clears it', (tester) async {
    final h = await pump(tester);

    await tester.tap(find.text(WaterType.salt.localizedName(l)));
    await tester.pump();
    expect(h.session.valueOf(siteWaterTypeField), isNull);

    await tester.tap(find.text(WaterType.fresh.localizedName(l)));
    await tester.pump();
    expect(h.session.valueOf(siteWaterTypeField), WaterType.fresh);
  });
}
