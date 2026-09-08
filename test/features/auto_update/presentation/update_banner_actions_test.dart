import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/presentation/widgets/update_banner_actions.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget _host({String? upgradeCommand, String? downloadUrl}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(
    body: UpdateBannerActions(
      upgradeCommand: upgradeCommand,
      downloadUrl: downloadUrl,
      onDownload: (_) {},
      onDismiss: () {},
    ),
  ),
);

void main() {
  const url = 'https://example.invalid/Submersion-Linux.tar.gz';

  testWidgets('a tarball install offers a download button', (tester) async {
    await tester.pumpWidget(_host(downloadUrl: url));
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('a deb install shows the apt command, not a download', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(upgradeCommand: 'sudo apt upgrade submersion', downloadUrl: url),
    );
    expect(find.text('Download'), findsNothing);
    expect(find.textContaining('sudo apt upgrade submersion'), findsOneWidget);
  });

  testWidgets('a Fedora install shows the dnf command', (tester) async {
    await tester.pumpWidget(
      _host(upgradeCommand: 'sudo dnf upgrade submersion', downloadUrl: url),
    );
    expect(find.textContaining('sudo dnf upgrade submersion'), findsOneWidget);
  });

  testWidgets('an openSUSE install shows the zypper command', (tester) async {
    await tester.pumpWidget(
      _host(upgradeCommand: 'sudo zypper update submersion', downloadUrl: url),
    );
    expect(find.text('Download'), findsNothing);
    expect(
      find.textContaining('sudo zypper update submersion'),
      findsOneWidget,
    );
  });

  testWidgets('a packaged install shows no download even with a url', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(upgradeCommand: 'sudo apt upgrade submersion', downloadUrl: url),
    );
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('dismiss is always available', (tester) async {
    await tester.pumpWidget(
      _host(upgradeCommand: 'sudo apt upgrade submersion'),
    );
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('a tarball install with no url offers no download button', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.text('Download'), findsNothing);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
