import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.pumpWidget(host(const NewerSchemaPeerBanner(peers: [])));

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('names the held peer and, on the github channel, asks for an '
      'update', (tester) async {
    await tester.pumpWidget(
      host(
        const NewerSchemaPeerBanner(
          peers: [(name: 'Living Room Mac', shortId: 'abc12345')],
          channelOverride: UpdateChannel.github,
        ),
      ),
    );

    expect(find.textContaining('Living Room Mac'), findsOneWidget);
    expect(find.textContaining('Update this device'), findsOneWidget);
  });

  testWidgets('on a store channel it acknowledges the pending store update '
      'instead of demanding an impossible action', (tester) async {
    await tester.pumpWidget(
      host(
        const NewerSchemaPeerBanner(
          peers: [(name: null, shortId: 'abc12345')],
          channelOverride: UpdateChannel.appstore,
        ),
      ),
    );

    // Falls back to a short-id label when the peer published no name.
    expect(find.textContaining('abc12345'), findsOneWidget);
    expect(find.textContaining('Update this device'), findsNothing);
    expect(find.textContaining('app store update'), findsOneWidget);
  });

  testWidgets('joins multiple peers into one list', (tester) async {
    await tester.pumpWidget(
      host(
        const NewerSchemaPeerBanner(
          peers: [
            (name: 'Mac', shortId: 'aaa11111'),
            (name: 'iPad', shortId: 'bbb22222'),
          ],
          channelOverride: UpdateChannel.github,
        ),
      ),
    );

    expect(find.textContaining('Mac and iPad'), findsOneWidget);
  });
}
