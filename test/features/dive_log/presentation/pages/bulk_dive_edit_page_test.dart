import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/pages/bulk_dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';

void main() {
  testWidgets('BulkDiveEditPage builds DiveEditPage in bulk mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final inner =
                const BulkDiveEditPage(diveIds: ['a', 'b']).build(context)
                    as DiveEditPage;
            expect(inner.bulkDiveIds, ['a', 'b']);
            expect(inner.isBulk, isTrue);
            return const SizedBox();
          },
        ),
      ),
    );
  });
}
