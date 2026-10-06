import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/presentation/widgets/site_category_picker.dart';

import '../support/media_widget_harness.dart';

/// Issue #1039: the bulk Set category picker.
void main() {
  Future<({SiteAttachmentCategory? category})?> pick(
    WidgetTester tester,
    String? choose,
  ) async {
    ({SiteAttachmentCategory? category})? result;
    var done = false;
    await tester.pumpWidget(
      await mediaTestApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSiteCategoryPicker(context);
                done = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Set category'), findsOneWidget);
    if (choose == null) {
      await tester.tapAt(const Offset(5, 5));
    } else {
      await tester.tap(find.text(choose));
    }
    await tester.pumpAndSettle();
    expect(done, isTrue);
    return result;
  }

  testWidgets('choosing a category returns it', (tester) async {
    expect(
      (await pick(tester, 'Anchorage and mooring'))!.category,
      SiteAttachmentCategory.anchorage,
    );
  });

  testWidgets('Uncategorized is a choice distinct from dismissing', (
    tester,
  ) async {
    final chosen = await pick(tester, 'Uncategorized');
    expect(chosen, isNotNull);
    expect(chosen!.category, isNull);
  });

  testWidgets('dismissing returns null', (tester) async {
    expect(await pick(tester, null), isNull);
  });
}
