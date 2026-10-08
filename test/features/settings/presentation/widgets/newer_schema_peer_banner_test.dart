import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/domain/entities/release_channel.dart';
import 'package:submersion/features/auto_update/domain/entities/update_channel.dart';
import 'package:submersion/features/settings/presentation/widgets/newer_schema_peer_banner.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(Widget child) => MaterialApp(
  // Pinned: flutter_test forwards the HOST machine's locale list, so an
  // unpinned MaterialApp resolves to a translated UI on a non-English dev
  // machine and every English assertion below finds nothing.
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders nothing when no peer is held', (tester) async {
    await tester.pumpWidget(
      host(
        const NewerSchemaPeerBanner(
          peers: [],
          releaseChannel: ReleaseChannel.stable,
        ),
      ),
    );

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('names the held peer and, on the beta channel, asks for an '
      'update', (tester) async {
    await tester.pumpWidget(
      host(
        const NewerSchemaPeerBanner(
          peers: [(name: 'Living Room Mac', shortId: 'abc12345')],
          releaseChannel: ReleaseChannel.beta,
          channelOverride: UpdateChannel.github,
        ),
      ),
    );

    expect(find.textContaining('Living Room Mac'), findsOneWidget);
    expect(find.textContaining('Update this device'), findsOneWidget);
  });

  testWidgets('on the stable channel it names the beta case instead of '
      'promising an update stable may not have yet (#2619)', (tester) async {
    await tester.pumpWidget(
      host(
        const NewerSchemaPeerBanner(
          peers: [(name: 'Living Room Mac', shortId: 'abc12345')],
          releaseChannel: ReleaseChannel.stable,
          channelOverride: UpdateChannel.github,
        ),
      ),
    );

    expect(find.textContaining('Update this device'), findsNothing);
    expect(find.textContaining('beta update channel'), findsOneWidget);
    expect(find.textContaining('next stable release'), findsOneWidget);
  });

  testWidgets('on a store channel it acknowledges the pending store update '
      'and the beta case instead of demanding an impossible action', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const NewerSchemaPeerBanner(
          peers: [(name: null, shortId: 'abc12345')],
          // A store build has no in-app channel picker, so the stored
          // preference must not change the advice.
          releaseChannel: ReleaseChannel.beta,
          channelOverride: UpdateChannel.appstore,
        ),
      ),
    );

    // Falls back to a short-id label when the peer published no name.
    expect(find.textContaining('abc12345'), findsOneWidget);
    expect(find.textContaining('Update this device'), findsNothing);
    expect(find.textContaining('app store update'), findsOneWidget);
    expect(find.textContaining('join the same beta'), findsOneWidget);
  });

  testWidgets('joins multiple peers into one list', (tester) async {
    await tester.pumpWidget(
      host(
        const NewerSchemaPeerBanner(
          peers: [
            (name: 'Mac', shortId: 'aaa11111'),
            (name: 'iPad', shortId: 'bbb22222'),
          ],
          releaseChannel: ReleaseChannel.stable,
          channelOverride: UpdateChannel.github,
        ),
      ),
    );

    expect(find.textContaining('Mac and iPad'), findsOneWidget);
  });
}
