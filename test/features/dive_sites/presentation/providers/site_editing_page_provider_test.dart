import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_editing_page_provider.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// A file dropped on a site whose page edits in place goes to the open
/// sitting, or is refused while the site is locked; anywhere else it is
/// imported as before (issue #4527, phase 2).
void main() {
  const site = DiveSite(id: 's1', name: 'Blue Hole');

  SiteEditingPage page({EditSession<DiveSite>? session, String id = 's1'}) =>
      SiteEditingPage(siteId: id, session: session, showMediaCard: () {});

  test('no page that edits in place: imported at once', () {
    expect(siteDropAnswer(page: null, siteId: 's1'), SiteDropAnswer.importNow);
  });

  test('the page edits another site: imported at once', () {
    expect(
      siteDropAnswer(
        page: page(id: 's2'),
        siteId: 's1',
      ),
      SiteDropAnswer.importNow,
    );
  });

  test('the site locked: refused', () {
    expect(siteDropAnswer(page: page(), siteId: 's1'), SiteDropAnswer.refuse);
  });

  test('the sitting being saved, or ended: refused', () {
    final frozen = EditSession<DiveSite>(site)..freeze();
    addTearDown(frozen.dispose);
    final ended = EditSession<DiveSite>(site)..dispose();

    expect(
      siteDropAnswer(
        page: page(session: frozen),
        siteId: 's1',
      ),
      SiteDropAnswer.refuse,
    );
    expect(
      siteDropAnswer(
        page: page(session: ended),
        siteId: 's1',
      ),
      SiteDropAnswer.refuse,
    );
  });

  test('the site unlocked: held in its sitting', () {
    final session = EditSession<DiveSite>(site);
    addTearDown(session.dispose);

    expect(
      siteDropAnswer(
        page: page(session: session),
        siteId: 's1',
      ),
      SiteDropAnswer.hold,
    );
  });
}
