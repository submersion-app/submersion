import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_field_gate.dart';

void main() {
  testWidgets('toggling the gate checkbox reports enabled changes', (
    tester,
  ) async {
    var enabled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BulkFieldGate(
              enabled: enabled,
              onChanged: (v) => setState(() => enabled = v),
              child: const Text('field'),
            ),
          ),
        ),
      ),
    );
    expect(enabled, isFalse);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(enabled, isTrue);
  });

  testWidgets('disabled gate blocks interaction with the child', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BulkFieldGate(
            enabled: false,
            onChanged: (_) {},
            child: ElevatedButton(
              onPressed: () => tapped = true,
              child: const Text('inner'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('inner'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tapped, isFalse); // IgnorePointer blocks it while gate is off
  });
}
