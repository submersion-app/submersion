import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_routes.dart';

/// The old document edit addresses open the page unlocked (issue #4527).
void main() {
  test('the edit address opens the page unlocked', () {
    expect(documentEditLocation('doc'), '/documents/doc?mode=edit');
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

  testWidgets('the pane opens the page unlocked', (tester) async {
    void deleted() {}
    late Widget on;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          on = documentEditPane(
            context,
            'doc',
            (_) {},
            () {},
            onDeleted: deleted,
          );
          return const SizedBox.shrink();
        },
      ),
    );

    expect(on, isA<DocumentDetailPage>());
    expect((on as DocumentDetailPage).openUnlocked, isTrue);
    expect((on as DocumentDetailPage).onDeleted, equals(deleted));
  });
}
