import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<void> pumpHeader(WidgetTester tester, EquipmentType type) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: EquipmentGroupHeader(type: type)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the localized type name', (tester) async {
    await pumpHeader(tester, EquipmentType.regulator);

    expect(find.text('Regulator'), findsOneWidget);
  });

  testWidgets('is a semantic header, so screen readers can navigate groups', (
    tester,
  ) async {
    // A grouped gear list is a list of sections. Without the header flag,
    // assistive tech sees a flat run of text and the diver cannot jump
    // between gear types.
    // Disposed inline, not via addTearDown: the framework verifies no handle
    // is outstanding BEFORE teardowns run, so a teardown-based dispose fails
    // the test even when the assertion itself passes.
    final handle = tester.ensureSemantics();

    await pumpHeader(tester, EquipmentType.tank);

    expect(
      tester.getSemantics(find.text('Tank')),
      isSemantics(label: 'Tank', isHeader: true),
    );

    handle.dispose();
  });

  testWidgets('keys are distinct per type, since headers are siblings', (
    tester,
  ) async {
    // Several headers sit in one Column and Flutter rejects duplicate keys
    // among siblings.
    final a = EquipmentGroupHeader(type: EquipmentType.tank);
    final b = EquipmentGroupHeader(type: EquipmentType.regulator);

    expect(a.key, isNot(b.key));
  });
}
