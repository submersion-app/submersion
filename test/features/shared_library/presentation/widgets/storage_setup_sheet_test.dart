import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/shared_library/presentation/widgets/storage_setup_sheet.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('shows both policies and copies the reader one', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showStorageSetupSheet(context, bucket: 'b', folder: 'reef'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('How to set up storage'), findsOneWidget);
    expect(find.textContaining('submersion-sites/reef/'), findsWidgets);
    await tester.tap(find.byKey(const Key('copy-reader-policy')));
    await tester.pumpAndSettle();
    expect(copied, contains('submersion-sites/reef/members/*'));
    expect(find.text('Policy copied'), findsOneWidget);
  });
}
