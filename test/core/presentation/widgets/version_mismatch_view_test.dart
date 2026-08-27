import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/presentation/widgets/version_mismatch_view.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  // Pinned: flutter_test forwards the HOST machine's locale list, so an
  // unpinned MaterialApp resolves to a translated UI on a non-English dev
  // machine and every English assertion below finds nothing.
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

VersionMismatchView buildView(UpdateChannel channel) => VersionMismatchView(
  databaseVersion: 154,
  appVersion: 153,
  textColor: Colors.black,
  subtitleColor: Colors.black54,
  onDownloadLatest: () {},
  onClose: () {},
  channelOverride: channel,
);

void main() {
  testWidgets('store channel hides the GitHub download affordances', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.appstore)));

    // A store user cannot act on a GitHub link, so neither the button nor
    // the raw URL should be offered (issue #1089).
    expect(find.byType(FilledButton), findsNothing);
    expect(find.textContaining('github.com'), findsNothing);
    expect(find.textContaining('app store'), findsOneWidget);
  });

  testWidgets('github channel keeps the download button and URL', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.text(VersionMismatchView.latestReleaseUrl), findsOneWidget);
  });
}
