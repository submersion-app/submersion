import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_routes.dart';

/// The old certification edit addresses open the page unlocked once phase 3's
/// switch is on, and keep the form until then (issue #4527).
void main() {
  test('the edit address opens the page unlocked with the switch on', () {
    expect(
      certificationEditLocation('doc', unlockEditing: true),
      '/certifications/doc?mode=edit',
    );
    expect(certificationEditLocation('doc', unlockEditing: false), isNull);
  });

  test('a page moving into the pane keeps asking to unlock', () {
    expect(
      certificationPaneLocation('doc', openUnlocked: true),
      '/certifications?selected=doc&mode=edit',
    );
    expect(
      certificationPaneLocation('doc', openUnlocked: false),
      '/certifications?selected=doc',
    );
  });

  testWidgets('the pane opens the page unlocked with the switch on, and the '
      'form without it', (tester) async {
    void deleted() {}
    late Widget on;
    late Widget off;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          on = certificationEditPane(
            context,
            'doc',
            (_) {},
            () {},
            onDeleted: deleted,
            unlockEditing: true,
          );
          off = certificationEditPane(
            context,
            'doc',
            (_) {},
            () {},
            unlockEditing: false,
          );
          return const SizedBox.shrink();
        },
      ),
    );

    expect(on, isA<CertificationDetailPage>());
    expect((on as CertificationDetailPage).openUnlocked, isTrue);
    expect((on as CertificationDetailPage).onDeleted, equals(deleted));
    expect(off, isA<CertificationEditPage>());
  });
}
