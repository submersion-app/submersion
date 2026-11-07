import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/write_fill_to_tag.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';

CylinderFill fill(String id, String equipmentId) => CylinderFill(
  id: id,
  passportId: 'pp-$equipmentId',
  equipmentId: equipmentId,
  filledAt: DateTime(2026, 11, 2),
  o2Percent: 32,
  createdAt: DateTime(2026, 11, 2),
  updatedAt: DateTime(2026, 11, 2),
);

void main() {
  Future<List<(String, String)>> run(
    WidgetTester tester,
    LoggedFill logged,
  ) async {
    final offered = <(String, String)>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => offerWriteFillsToTags(
                context,
                ref,
                logged,
                equipmentId: 'A',
                offer:
                    (
                      context,
                      ref, {
                      required equipmentId,
                      required fill,
                    }) async => offered.add((equipmentId, fill.id)),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return offered;
  }

  testWidgets('a single fill offers its own tag', (tester) async {
    expect(await run(tester, LoggedFill(fill: fill('f1', 'A'))), [('A', 'f1')]);
  });

  testWidgets('a twin fill offers this tag, then the partner\'s', (
    tester,
  ) async {
    expect(
      await run(
        tester,
        LoggedFill(fill: fill('f1', 'A'), partnerFill: fill('f2', 'B')),
      ),
      [('A', 'f1'), ('B', 'f2')],
    );
  });
}
