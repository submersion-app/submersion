import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/nearby_divers_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Divers seen nearby on the swap screen (issue #3728).
void main() {
  testWidgets('a diver without a photo shows the same initials as their '
      'buddy page will', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NearbyDiversList(
            peers: const [
              NearbyCardPeer(swapId: 's', name: 'Sam de la Rivera'),
            ],
            waitingFor: const {},
            onTap: (_) {},
          ),
        ),
      ),
    );
    // First and last name, as Buddy.initials gives.
    expect(find.text('SR'), findsOneWidget);
  });
}
