import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/media/presentation/widgets/media_console_scaffold.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A browser can neither watch folders nor import files (issue #4121), so
/// the Media console offers only the Transfers button there.
void main() {
  test('natively every action is offered', () {
    expect(
      mediaConsoleActionsFor(currentDeviceCapabilities()),
      MediaConsoleAction.values,
    );
  });

  test('a browser offers only the Transfers button', () {
    // Both tabs show everywhere: the Gear gallery (issue #3355) only shows
    // and removes, so a browser has it too.
    expect(mediaConsoleActionsFor(DeviceCapabilities.web), [
      MediaConsoleAction.transfers,
    ]);
  });

  test('the buttons read Import, Transfers, Sources', () {
    expect(MediaConsoleAction.values, [
      MediaConsoleAction.importMedia,
      MediaConsoleAction.transfers,
      MediaConsoleAction.sources,
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
