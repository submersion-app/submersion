import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/media_store/media_store_policies.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/settings/data/set_up_card_prefs.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_photo_count_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_photos_step.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

AccountGroup _group(
  String id,
  AccountKind kind,
  String label, {
  AccountStatus status = AccountStatus.signedIn,
}) => groupAccounts(
  rows: [
    ConnectedAccount(
      id: id,
      kind: kind,
      label: label,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ],
  statusById: {id: status},
  localLocationById: const {},
  usagesOf: (_) => const [],
).single;

final _drive = _group('gd', AccountKind.googledrive, 'Google Drive');
final _dropbox = _group(
  'db',
  AccountKind.dropbox,
  'Dropbox',
  status: AccountStatus.needsSignIn,
);

PhotosCopies _announced(AccountGroup group) => (
  attached: false,
  store: (
    id: 'store-1',
    providerType: group.kind.name,
    displayHint: group.label,
    lastSweepAt: null,
    accountId: group.rows.first.id,
  ),
  group: group,
  label: group.label,
);

const PhotosCopies _none = (
  attached: false,
  store: null,
  group: null,
  label: null,
);

class _Flow extends SetUpFlowNotifier {
  @override
  AccountGroup? build() => _drive;
}

class _Actions extends SetUpPhotosActions {
  _Actions({this.signInAnswer = true, this.signInThrows = false});

  final bool signInAnswer;
  final bool signInThrows;
  final calls = <String>[];

  @override
  Future<bool> signIn(
    BuildContext context,
    WidgetRef ref,
    AccountGroup group,
  ) async {
    calls.add('signIn ${group.label}');
    if (signInThrows) throw StateError('oauth');
    return signInAnswer;
  }

  @override
  Future<bool> attach(
    BuildContext context,
    AccountGroup group,
    PhotosCopies copies,
  ) async {
    calls.add('attach ${group.label} ${copies.store?.id}');
    return true;
  }
}

/// Step 4, "Photos on every device" (issue #3482, Part B Task 12).
void main() {
  late _Actions actions;
  late List<String> nav;
  late SharedPreferences prefs;

  Future<void> pump(
    WidgetTester tester,
    PhotosCopies copies, {
    _Actions? withActions,
  }) async {
    actions = withActions ?? _Actions();
    nav = [];
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mediaStorePoliciesProvider.overrideWithValue(
            MediaStorePolicies(prefs: prefs),
          ),
          setUpFlowProvider.overrideWith(_Flow.new),
          accountGroupsProvider.overrideWith((ref) async => [_drive, _dropbox]),
          photosCopiesProvider.overrideWith((ref) async => copies),
          setUpPhotoCountProvider.overrideWith((ref) async => 12),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SetUpPhotosStep(
              navigation: SetUpStepNavigation(
                onNext: () => nav.add('next'),
                onBack: () => nav.add('back'),
                onNotNow: () => nav.add('notNow'),
                onSkip: () => nav.add('skip'),
              ),
              actions: actions,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchOn(WidgetTester tester, String title) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
      .value;

  group('a first device', () {
    testWidgets('the switch starts off, counting the photos here', (
      tester,
    ) async {
      await pump(tester, _none);

      expect(switchOn(tester, 'Keep photo copies in Google Drive'), isFalse);
      expect(find.text('12 photos and videos attached'), findsOneWidget);
      expect(find.text('Upload new photos automatically'), findsNothing);

      await tester.tap(find.text('Keep photo copies in Google Drive'));
      await tester.pumpAndSettle();

      expect(switchOn(tester, 'Upload new photos automatically'), isTrue);
      expect(switchOn(tester, 'Use cellular data'), isFalse);
    });

    testWidgets('Next with the switch on starts the copies, then applies '
        'the switches', (tester) async {
      await pump(tester, _none);

      await tester.tap(find.text('Keep photo copies in Google Drive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['attach Google Drive null']);
      expect(prefs.getBool(MediaStorePolicies.autoUploadKey), isTrue);
      expect(prefs.getBool(MediaStorePolicies.photosOnCellularKey), isFalse);
      expect(nav, ['next']);
    });

    testWidgets('Next with the switch off writes nothing', (tester) async {
      await pump(tester, _none);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(actions.calls, isEmpty);
      expect(prefs.getBool(MediaStorePolicies.autoUploadKey), isNull);
      expect(prefs.getBool(MediaStorePolicies.photosOnCellularKey), isNull);
      expect(nav, ['next']);
    });
  });

  group('a second device', () {
    testWidgets('copies in the same account need nothing typed', (
      tester,
    ) async {
      await pump(tester, _announced(_drive));

      expect(switchOn(tester, 'Use the photo copies in Google Drive'), isTrue);
      expect(find.text('Same account. Nothing to type.'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['attach Google Drive store-1']);
      expect(prefs.getBool(MediaStorePolicies.autoUploadKey), isTrue);
      expect(nav, ['next']);
    });

    testWidgets('copies in the same account that needs signing in say so', (
      tester,
    ) async {
      final lapsed = _group(
        'gd',
        AccountKind.googledrive,
        'Google Drive',
        status: AccountStatus.needsSignIn,
      );
      await pump(tester, _announced(lapsed));

      expect(find.text('Same account. Nothing to type.'), findsNothing);
      expect(find.text('Signs in to Google Drive first.'), findsOneWidget);
    });

    testWidgets('copies in another account sign in to it first', (
      tester,
    ) async {
      await pump(tester, _announced(_dropbox));
      expect(find.text('Signs in to Dropbox first.'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['signIn Dropbox', 'attach Dropbox store-1']);
      expect(nav, ['next']);
    });

    testWidgets('a sign-in that does not finish stays on the step', (
      tester,
    ) async {
      await pump(
        tester,
        _announced(_dropbox),
        withActions: _Actions(signInAnswer: false),
      );

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(actions.calls, ['signIn Dropbox']);
      expect(nav, isEmpty);
    });
  });

  testWidgets('a sign-in that throws leaves the step usable', (tester) async {
    await pump(
      tester,
      _announced(_dropbox),
      withActions: _Actions(signInThrows: true),
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(nav, isEmpty);

    await tester.tap(find.text('Back'));
    expect(nav, ['back']);
  });

  testWidgets('Skip settles the step', (tester) async {
    await pump(tester, _none);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(prefs.getBool(SetUpCardPrefs.photosSkippedKey), isTrue);
    expect(nav, ['skip']);
  });

  testWidgets('Back writes nothing', (tester) async {
    await pump(tester, _none);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(prefs.getBool(SetUpCardPrefs.photosSkippedKey), isNull);
    expect(actions.calls, isEmpty);
    expect(nav, ['back']);
  });
}
