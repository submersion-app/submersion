import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/widgets/read_failed_peer_banner.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host(Widget child, {Locale locale = const Locale('en')}) =>
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(body: child),
      );

  testWidgets('names a single read-failed peer', (tester) async {
    await tester.pumpWidget(
      host(
        const ReadFailedPeerBanner(
          peers: [(name: 'Erics-iPhone', shortId: 'a1b2c3d4')],
        ),
      ),
    );

    expect(find.textContaining('Erics-iPhone'), findsOneWidget);
    expect(find.textContaining('could not be read'), findsOneWidget);
  });

  testWidgets('falls back to a short id for an unnamed peer', (tester) async {
    await tester.pumpWidget(
      host(
        const ReadFailedPeerBanner(peers: [(name: null, shortId: 'a1b2c3d4')]),
      ),
    );

    expect(find.textContaining('device a1b2c3d4'), findsOneWidget);
  });

  testWidgets('joins several peers', (tester) async {
    await tester.pumpWidget(
      host(
        const ReadFailedPeerBanner(
          peers: [
            (name: 'Erics-iPhone', shortId: 'a1b2c3d4'),
            (name: null, shortId: 'e5f6a7b8'),
          ],
        ),
      ),
    );

    expect(
      find.textContaining('Erics-iPhone and device e5f6a7b8'),
      findsOneWidget,
    );
  });

  testWidgets('renders nothing when no peer read failed', (tester) async {
    await tester.pumpWidget(host(const ReadFailedPeerBanner(peers: [])));

    expect(find.byType(Card), findsNothing);
  });
}
