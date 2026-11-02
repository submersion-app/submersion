import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/transfer/presentation/widgets/transfer_list_content.dart';

import '../../../../helpers/keyboard_navigation_contract.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('satisfies the master-list keyboard contract', (tester) async {
    await verifyKeyboardNavigationContract(
      tester,
      build: (onItemSelected) => testApp(
        locale: const Locale('en'),
        child: TransferListContent(
          showAppBar: false,
          onItemSelected: onItemSelected,
        ),
      ),
      firstRow: find.text('File Import'),
    );
  });

  testWidgets('natively the dive computers section is listed', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: TransferListContent(showAppBar: false, onItemSelected: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dive Computers'), findsOneWidget);
  });

  testWidgets('a browser offers no dive computers section', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        ],
        child: TransferListContent(showAppBar: false, onItemSelected: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('File Import'), findsOneWidget);
    expect(find.text('Dive Computers'), findsNothing);
  });
}
