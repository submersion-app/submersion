import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/dive_computer/presentation/providers/reparse_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_resync_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_overflow_menu.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

/// Re-parsing a dive's raw download runs the native parser, which a browser
/// does not have (issue #4121): the entry is not offered there, even for a
/// dive that kept its raw data.
void main() {
  Future<void> pumpMenu(WidgetTester tester, {bool browser = false}) async {
    final dive = createTestDiveWithBottomTime();
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          if (browser)
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
          diveHasRawDataProvider(dive.id).overrideWith((ref) async => true),
          diveHasImportedFileProvider(
            dive.id,
          ).overrideWith((ref) async => false),
          preDiveSessionForDiveProvider(
            dive.id,
          ).overrideWith((ref) async => null),
          mirrorCandidatesProvider(dive.id).overrideWith((ref) async => []),
        ],
        child: DiveDetailOverflowMenu(
          dive: dive,
          embedded: false,
          menuKey: GlobalKey(),
          displayOptions: MenuController(),
          onSelected: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  testWidgets('natively offers to re-parse a dive with raw data', (
    tester,
  ) async {
    await pumpMenu(tester);
    expect(find.text('Re-parse raw data'), findsOneWidget);
  });

  testWidgets('a browser has no parser to re-parse with', (tester) async {
    await pumpMenu(tester, browser: true);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Re-parse raw data'), findsNothing);
  });
}
