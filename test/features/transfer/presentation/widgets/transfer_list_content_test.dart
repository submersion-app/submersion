import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/router/web_unavailable_routes.dart';
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

  test('every section a browser leaves out cannot be opened by URL '
      'either', () {
    final container = ProviderContainer(
      overrides: [
        deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
      ],
    );
    addTearDown(container.dispose);
    final offered = {
      for (final s in container.read(transferSectionsProvider)) s.id,
    };
    for (final section in transferSections) {
      if (offered.contains(section.id)) continue;
      expect(
        webUnavailableFeatureFor('/transfer?selected=${section.id}'),
        isNotNull,
        reason:
            '${section.id} is left out of the list but a link still opens it',
      );
    }
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
