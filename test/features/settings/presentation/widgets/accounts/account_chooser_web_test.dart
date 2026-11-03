import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_chooser.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The connect step's account chooser in a browser (issue #4121): iCloud
/// and Git appear as unavailable with a reason instead of being offered,
/// and Google Drive says that each visit signs in again.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  Future<void> pump(WidgetTester tester, {bool browser = false}) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (browser)
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
          accountGroupsProvider.overrideWith((ref) async => const []),
          offerableAccountKindsProvider.overrideWithValue(const [
            AccountKindOffer.icloud,
            AccountKindOffer.googleDrive,
            AccountKindOffer.dropbox,
            AccountKindOffer.ownServer,
            AccountKindOffer.git,
          ]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AccountChooser(
              embedded: true,
              offerHints: true,
              onChosen: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ListTile tileTitled(WidgetTester tester, String title) =>
      tester.widget<ListTile>(find.widgetWithText(ListTile, title));

  testWidgets('natively every kind is offered, enabled', (tester) async {
    await pump(tester);
    expect(
      tileTitled(tester, en.settings_cloudSync_provider_icloud).enabled,
      isTrue,
    );
    expect(
      tileTitled(tester, en.settings_cloudSync_provider_git_title).enabled,
      isTrue,
    );
    expect(
      find.text(en.settings_setUpDevice_offer_googleDrive),
      findsOneWidget,
    );
    expect(find.text(en.web_unavailable_offer_icloud), findsNothing);
  });

  testWidgets('a browser shows iCloud and Git as unavailable, with reasons', (
    tester,
  ) async {
    await pump(tester, browser: true);
    final icloud = tileTitled(tester, en.settings_cloudSync_provider_icloud);
    expect(icloud.enabled, isFalse);
    expect(icloud.onTap, isNull);
    expect(find.text(en.web_unavailable_offer_icloud), findsOneWidget);
    final git = tileTitled(tester, en.settings_cloudSync_provider_git_title);
    expect(git.enabled, isFalse);
    expect(find.text(en.web_unavailable_offer_git), findsOneWidget);
    // Offered once each, as unavailable: no second, enabled tile.
    expect(find.text(en.settings_cloudSync_provider_icloud), findsOneWidget);
    expect(find.text(en.settings_cloudSync_provider_git_title), findsOneWidget);
    // The unavailable kinds sit after the ones that can be added.
    expect(
      tester.getTopLeft(find.text(en.settings_cloudSync_provider_icloud)).dy,
      greaterThan(
        tester.getTopLeft(find.text(en.settings_accounts_ownServer_title)).dy,
      ),
    );
  });

  testWidgets('a browser\'s Google Drive tile says it signs in each visit', (
    tester,
  ) async {
    await pump(tester, browser: true);
    expect(
      find.text(en.settings_setUpDevice_offer_googleDrive_browser),
      findsOneWidget,
    );
    expect(find.text(en.settings_setUpDevice_offer_googleDrive), findsNothing);
  });
}
