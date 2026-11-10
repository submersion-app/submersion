import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/widgets/foldable_type_group_rows.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _bcd = EquipmentItem(id: 'b1', name: 'Zeagle', type: EquipmentType.bcd);
const _tank = EquipmentItem(id: 't1', name: 'Faber', type: EquipmentType.tank);
const _fins = EquipmentItem(id: 'f1', name: 'Jet', type: EquipmentType.fins);

/// A checkbox list whose open set is not worked out until [ready], as the
/// set editor waits for the set's members.
class _Harness extends StatefulWidget {
  const _Harness({required this.ready});

  final ValueNotifier<bool> ready;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness>
    with FoldableTypeGroupsState<_Harness> {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.ready,
    builder: (context, ready, _) {
      const groups = <EquipmentTypeGroupRows>[
        (EquipmentType.bcd, [_bcd]),
        (EquipmentType.tank, [_tank]),
        (EquipmentType.fins, [_fins]),
      ];
      ensureOpenTypeGroups(groups, const {'t1'}, ready: ready);
      return ListView(
        children: foldableTypeGroupRows(
          context,
          groups: groups,
          open: openTypeGroups,
          ticked: const {'t1'},
          onToggle: toggleTypeGroup,
          rowBuilder: (item) => Text(item.name),
        ),
      );
    },
  );
}

/// Folding a checkbox list of gear (issue #3364).
void main() {
  Future<ValueNotifier<bool>> pump(WidgetTester tester) async {
    final ready = ValueNotifier(false);
    addTearDown(ready.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: _Harness(ready: ready)),
      ),
    );
    await tester.pumpAndSettle();
    return ready;
  }

  testWidgets('every group shows open until the open set is worked out', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Zeagle'), findsOneWidget);
    expect(find.text('Faber'), findsOneWidget);
    expect(find.text('Jet'), findsOneWidget);
  });

  testWidgets('a tap before then folds only the tapped group', (tester) async {
    await pump(tester);
    await tester.tap(
      find.byKey(const ValueKey('equipment-type-fold-type:bcd')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Zeagle'), findsNothing);
    expect(find.text('Faber'), findsOneWidget);
    expect(find.text('Jet'), findsOneWidget);
  });

  testWidgets('once ready, only groups holding a tick start open', (
    tester,
  ) async {
    final ready = await pump(tester);
    ready.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Zeagle'), findsNothing);
    expect(find.text('Faber'), findsOneWidget);
    expect(find.text('Jet'), findsNothing);
  });
}
