import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/widgets/skipped_peer_banner.dart';
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

  testWidgets('names a single skipped peer', (tester) async {
    await tester.pumpWidget(
      host(
        const SkippedPeerBanner(
          peers: [(name: 'Erics-iPhone', shortId: 'a1b2c3d4')],
        ),
      ),
    );

    expect(find.textContaining('Erics-iPhone still has'), findsOneWidget);
  });

  testWidgets('falls back to a short id for an unnamed peer', (tester) async {
    // A peer on a manifest written before the name field existed.
    await tester.pumpWidget(
      host(const SkippedPeerBanner(peers: [(name: null, shortId: 'a1b2c3d4')])),
    );

    expect(find.textContaining('device a1b2c3d4'), findsOneWidget);
  });

  testWidgets('joins several peers and uses the plural form', (tester) async {
    await tester.pumpWidget(
      host(
        const SkippedPeerBanner(
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
    expect(find.textContaining('still have'), findsOneWidget);
  });

  testWidgets('three peers use the comma separator before the last', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SkippedPeerBanner(
          peers: [
            (name: 'Alpha', shortId: 'a'),
            (name: 'Beta', shortId: 'b'),
            (name: 'Gamma', shortId: 'c'),
          ],
        ),
      ),
    );

    expect(find.textContaining('Alpha, Beta and Gamma'), findsOneWidget);
  });

  testWidgets('renders nothing when no peer was skipped', (tester) async {
    await tester.pumpWidget(host(const SkippedPeerBanner(peers: [])));

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('uses the locale separator, not a hardcoded English one', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SkippedPeerBanner(
          peers: [(name: 'Alpha', shortId: 'a'), (name: 'Beta', shortId: 'b')],
        ),
        locale: const Locale('fr'),
      ),
    );

    expect(find.textContaining('Alpha et Beta'), findsOneWidget);
  });
}
