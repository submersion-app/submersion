import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/widgets/older_schema_peer_banner.dart';
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

/// The newer device's side of #2619: a peer too old to read this device's
/// payloads is named, so a one-way sync no longer looks like a clean one.
void main() {
  testWidgets('renders nothing when no peer is behind', (tester) async {
    await tester.pumpWidget(host(const OlderSchemaPeerBanner(peers: [])));

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('names the peer and how it catches up', (tester) async {
    await tester.pumpWidget(
      host(
        const OlderSchemaPeerBanner(
          peers: [(name: 'Stable iPad', shortId: 'abc12345')],
        ),
      ),
    );

    expect(
      find.textContaining(
        'Stable iPad runs an older version of Submersion that cannot read '
        "this device's latest changes",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('by joining the beta'), findsOneWidget);
  });

  testWidgets('joins several peers and falls back to a short id', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const OlderSchemaPeerBanner(
          peers: [
            (name: 'Stable iPad', shortId: 'aaa11111'),
            (name: null, shortId: 'bbb22222'),
          ],
        ),
      ),
    );

    expect(
      find.textContaining('Stable iPad and device bbb22222 run an older'),
      findsOneWidget,
    );
  });

  testWidgets('text is paired with its container colour', (tester) async {
    await tester.pumpWidget(
      host(
        const OlderSchemaPeerBanner(
          peers: [(name: 'Stable iPad', shortId: 'abc12345')],
        ),
      ),
    );

    final finder = find.textContaining('older version of Submersion');
    final text = tester.widget<Text>(finder);
    final scheme = Theme.of(tester.element(finder)).colorScheme;
    expect(text.style?.color, scheme.onSecondaryContainer);
  });
}
