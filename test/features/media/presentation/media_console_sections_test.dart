import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/media/presentation/widgets/media_console_scaffold.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A browser can neither watch folders nor import files (issue #4121), so
/// the Media console shows only the library and the transfers there.
void main() {
  test('natively every section is offered', () {
    expect(
      mediaConsoleSectionsFor(currentDeviceCapabilities()),
      MediaConsoleSection.values,
    );
  });

  test('a browser offers the library, the gear and the transfers only', () {
    // The Gear gallery (issue #3355) only shows and removes, so a browser
    // has it too.
    expect(mediaConsoleSectionsFor(DeviceCapabilities.web), [
      MediaConsoleSection.library,
      MediaConsoleSection.gear,
      MediaConsoleSection.transfers,
    ]);
  });

  test('gear tab is offered right after the library', () {
    expect(MediaConsoleSection.values.indexOf(MediaConsoleSection.gear), 1);
  });

  testWidgets('the gear tab is labelled Equipment, like the app section', (
    tester,
  ) async {
    // Issue #3355: the app calls gear "Equipment" everywhere else.
    late String label;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            label = AppLocalizations.of(context).media_gearGallery_tab;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(label, 'Equipment');
  });
}
