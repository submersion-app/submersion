import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/reassign_tank_picker.dart';

import '../../../../../helpers/test_app.dart';

final _dive = Dive(
  id: 'd1',
  dateTime: DateTime.utc(2026, 7, 1, 10),
  tanks: const [
    DiveTank(
      id: 'a',
      name: 'O2',
      gasMix: GasMix(o2: 100, he: 0),
      order: 0,
      computerId: 'comp-1',
    ),
    DiveTank(
      id: 'b',
      name: 'Dil',
      gasMix: GasMix(o2: 21, he: 0),
      order: 1,
      computerId: 'comp-1',
    ),
    DiveTank(
      id: 'c',
      gasMix: GasMix(o2: 50, he: 0),
      order: 2,
      computerId: 'comp-2',
    ),
    DiveTank(id: 'd', gasMix: GasMix(o2: 32, he: 0), order: 3),
  ],
);

Widget _host({required String excludeTankId, required List<String?> picked}) =>
    testAppInShell(
      overrides: [diveProvider.overrideWith((ref, id) async => _dive)],
      child: Consumer(
        builder: (context, ref, _) => ElevatedButton(
          onPressed: () async {
            picked.add(
              await showReassignTankPicker(
                context,
                ref,
                diveId: 'd1',
                excludeTankId: excludeTankId,
              ),
            );
          },
          child: const Text('OPEN'),
        ),
      ),
    );

void main() {
  testWidgets('offers only tanks attributed to the same computer', (
    tester,
  ) async {
    final picked = <String?>[];
    await tester.pumpWidget(_host(excludeTankId: 'a', picked: picked));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Dil'), findsOneWidget);
    // comp-2's tank and the unattributed manual tank are not stable targets.
    expect(find.text('Tank 3'), findsNothing);
    expect(find.text('Tank 4'), findsNothing);

    await tester.tap(find.text('Dil'));
    await tester.pumpAndSettle();
    expect(picked, ['b']);
  });

  testWidgets('returns null without a dialog when nothing qualifies', (
    tester,
  ) async {
    final picked = <String?>[];
    await tester.pumpWidget(_host(excludeTankId: 'c', picked: picked));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.byType(SimpleDialog), findsNothing);
    expect(picked, [null]);
  });
}
