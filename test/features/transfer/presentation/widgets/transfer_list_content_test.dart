import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
