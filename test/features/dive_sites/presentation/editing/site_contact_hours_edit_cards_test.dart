import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_contact_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_cards.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_opening_hours_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import 'site_editor_harness.dart';

/// The Contact and Opening hours cards as the page builds them (issue #5073).
void main() {
  final l = AppLocalizationsEn();
  const site = DiveSite(id: 's1', name: 'Stoney Cove');
  final contact = siteEditCards[SiteDetailSectionId.contact]!;
  final hours = siteEditCards[SiteDetailSectionId.openingHours]!;

  Widget build(
    BuildContext context,
    EditCard<DiveSite> card,
    EditSession<DiveSite> session,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(card.title(context)),
      card.leading!(context),
      card.editorBuilder(context, session),
    ],
  );

  testWidgets('the Contact card titles itself and edits contact', (
    tester,
  ) async {
    final h = await pumpSiteEditor(
      tester,
      site,
      (session) =>
          Builder(builder: (context) => build(context, contact, session)),
    );

    expect(find.text(l.diveSites_detail_section_contact), findsOneWidget);
    expect(find.byIcon(Icons.contact_phone_outlined), findsOneWidget);
    expect(find.byType(SiteContactCardEditor), findsOneWidget);
    expect(contact.isValid!(h.session), isTrue);
  });

  testWidgets('the Opening hours card titles itself and edits hours', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    final h = await pumpSiteEditor(
      tester,
      site,
      (session) => SingleChildScrollView(
        child: Builder(builder: (context) => build(context, hours, session)),
      ),
    );

    expect(find.text(l.diveSites_detail_section_openingHours), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.byType(SiteOpeningHoursCardEditor), findsOneWidget);
    expect(hours.isValid!(h.session), isTrue);
    expect(h.session.valueOf(siteOpeningHoursField), isNull);
  });

  test('each card is empty until the site has its data', () {
    expect(contact.isEmpty(site), isTrue);
    expect(contact.isEmpty(site.copyWith(phone: '+44 1455 273089')), isFalse);
    expect(hours.isEmpty(site), isTrue);
    expect(
      hours.isEmpty(
        site.copyWith(openingHours: OpeningHours(alwaysOpen: true)),
      ),
      isFalse,
    );
    // Hours from a newer version with nothing this one reads (review).
    expect(
      hours.isEmpty(site.copyWith(openingHours: OpeningHours.empty)),
      isTrue,
    );
  });
}
