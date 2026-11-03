import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/swap_with_buddy_button.dart';

import '../../../../../helpers/test_app.dart';

/// The buddy card swap runs over the nearby radios (with NFC and a QR code
/// beside them), none of which a browser has (issue #4121).
void main() {
  testWidgets('natively offers the swap', (tester) async {
    await tester.pumpWidget(
      testApp(locale: const Locale('en'), child: const SwapWithBuddyButton()),
    );
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
  });

  testWidgets('a browser has no radios to swap over', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
        ],
        child: const SwapWithBuddyButton(),
      ),
    );
    expect(find.byIcon(Icons.swap_horiz), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
}
