import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_routes.dart';

/// The old document edit addresses open the page unlocked once phase 3's
/// switch is on, and keep the form until then (issue #4527).
void main() {
  test('the edit address opens the page unlocked with the switch on', () {
    expect(
      documentEditLocation('doc', unlockEditing: true),
      '/documents/doc?mode=edit',
    );
    expect(documentEditLocation('doc', unlockEditing: false), isNull);
  });

  test('a page moving into the pane keeps asking to unlock', () {
    expect(
      documentPaneLocation('doc', openUnlocked: true),
      '/documents?selected=doc&mode=edit',
    );
    expect(
      documentPaneLocation('doc', openUnlocked: false),
      '/documents?selected=doc',
    );
  });

  testWidgets('the pane opens the page unlocked with the switch on, and the '
      'form without it', (tester) async {
    late Widget on;
    late Widget off;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          on = documentEditPane(
            context,
            'doc',
            (_) {},
            () {},
            unlockEditing: true,
          );
          off = documentEditPane(
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

    expect(on, isA<DocumentDetailPage>());
    expect((on as DocumentDetailPage).openUnlocked, isTrue);
    expect(off, isA<DocumentEditPage>());
  });
}
