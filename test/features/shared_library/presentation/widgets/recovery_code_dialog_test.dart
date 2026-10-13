import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/shared_library/presentation/widgets/recovery_code_dialog.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('shows the code, copies it, and closes only once stored', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    var closed = false;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await showRecoveryCodeDialog(context, 'alpha-bravo-charlie');
              closed = true;
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('alpha-bravo-charlie'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, 'alpha-bravo-charlie');
    // Not dismissed by tapping outside.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    await tester.tap(find.text('I have stored it'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
  });
}
