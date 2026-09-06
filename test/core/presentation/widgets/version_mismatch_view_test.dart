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
  // Mirrors StartupWrapper's terminal-screen host exactly: a bare
  // SafeArea > Center with no scrollable of its own. The view has to
  // survive that on its own, or the links overflow off the bottom.
  home: Scaffold(
    body: SafeArea(child: Center(child: child)),
  ),
);

VersionMismatchView buildView(
  UpdateChannel channel, {
  VoidCallback? onDownloadLatest,
  VoidCallback? onOpenBetaBuilds,
}) => VersionMismatchView(
  databaseVersion: 154,
  appVersion: 153,
  textColor: Colors.black,
  subtitleColor: Colors.black54,
  onDownloadLatest: onDownloadLatest ?? () {},
  onOpenBetaBuilds: onOpenBetaBuilds ?? () {},
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
    expect(find.byType(OutlinedButton), findsNothing);
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

  testWidgets('does not claim an update is required (issue #1588)', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    // The screen fires most often because a BETA build upgraded the file, in
    // which case no stable update exists to install. Titling it "Update
    // Required" sent the #1568 reporter to reinstall the same build twice.
    expect(find.text('Update Required'), findsNothing);
    expect(find.text('Your Data Is Newer Than This App'), findsOneWidget);
  });

  testWidgets('names the realistic causes rather than assuming staleness', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    expect(find.textContaining('beta build'), findsWidgets);
    expect(find.textContaining('restored'), findsWidgets);
  });

  testWidgets('offers the beta-builds page alongside the stable link', (
    tester,
  ) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    // Alongside, not instead of: a newer stable genuinely may exist, and this
    // build has no way to tell which case it is in.
    expect(find.text(VersionMismatchView.latestReleaseUrl), findsOneWidget);
    expect(find.text(VersionMismatchView.betaReleasesUrl), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });

  testWidgets('the beta action invokes its own callback', (tester) async {
    var betaOpened = false;
    var stableOpened = false;
    await tester.pumpWidget(
      host(
        buildView(
          UpdateChannel.github,
          onDownloadLatest: () => stableOpened = true,
          onOpenBetaBuilds: () => betaOpened = true,
        ),
      ),
    );

    await tester.tap(find.byType(OutlinedButton));
    expect(betaOpened, isTrue);
    expect(stableOpened, isFalse);
  });

  testWidgets('warns that beta builds are pre-release', (tester) async {
    await tester.pumpWidget(host(buildView(UpdateChannel.github)));

    // This screen must not become a second unguarded door onto beta: that
    // unguarded door is what produced #1568 in the first place.
    expect(find.textContaining('pre-release'), findsOneWidget);
  });

  testWidgets('the stable action stays the primary button', (tester) async {
    var stableOpened = false;
    await tester.pumpWidget(
      host(
        buildView(
          UpdateChannel.github,
          onDownloadLatest: () => stableOpened = true,
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));
    expect(stableOpened, isTrue);
  });
}
