import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/features/media/data/media_cache_settings.dart';
import 'package:submersion/features/settings/presentation/pages/connected_accounts_page.dart';
import 'package:submersion/features/settings/presentation/pages/photos_media_hub_page.dart';
import 'package:submersion/features/settings/presentation/pages/photos_media_setup_page.dart';
import 'package:submersion/features/settings/presentation/providers/media_cache_settings_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/test_database.dart';

class _FixedStatusAdapter extends AccountProviderAdapter {
  _FixedStatusAdapter(this.kind, this.result);

  @override
  final AccountKind kind;
  final AccountStatus result;

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async => result;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {}
}

/// Records the automatic color correction switch (issue #3520); every other
/// SettingsNotifier member is unused here.
class _ColorSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _ColorSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> get initialLoad async {}

  @override
  Future<void> setAutoColorCorrection(bool value) async =>
      state = state.copyWith(autoColorCorrection: value);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  /// Memory sizes the hub asked the image cache to take, recorded instead
  /// of applied: the real cache is process-wide.
  late List<int> appliedMemoryBytes;

  /// How often the hub asked for the thumbnail cache to be emptied.
  late int emptied;

  /// What the stand-in clear does; a test swaps in one that fails.
  late Future<void> Function() emptyDiskCache;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    appliedMemoryBytes = [];
    emptied = 0;
    emptyDiskCache = () async => emptied++;
  });

  tearDown(() => tearDownTestDatabase());

  Widget app(Widget home) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      mediaCacheSettingsProvider.overrideWith(
        (ref) => MediaCacheSettingsNotifier(
          prefs,
          applyMemoryCap: appliedMemoryBytes.add,
          onEmptyDiskCache: () => emptyDiskCache(),
        ),
      ),
      accountProviderRegistryProvider.overrideWithValue(
        AccountProviderRegistry([
          _FixedStatusAdapter(AccountKind.s3, AccountStatus.needsSignIn),
        ]),
      ),
    ],
    child: MaterialApp(
      // Pinned: the assertions match English strings.
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  testWidgets('the automatic color correction switch is off and turns on', (
    tester,
  ) async {
    final notifier = _ColorSettingsNotifier();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => notifier),
          mediaCacheSettingsProvider.overrideWith(
            (ref) => MediaCacheSettingsNotifier(
              prefs,
              applyMemoryCap: appliedMemoryBytes.add,
              onEmptyDiskCache: () => emptyDiskCache(),
            ),
          ),
          accountProviderRegistryProvider.overrideWithValue(
            AccountProviderRegistry(const []),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PhotosMediaHubPage(),
        ),
      ),
    );
    await tester.pump();

    final tile = find.widgetWithText(
      SwitchListTile,
      'Automatic color correction',
    );
    await tester.scrollUntilVisible(tile, 200);
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    await tester.tap(tile);
    await tester.pump();
    expect(notifier.state.autoColorCorrection, isTrue);
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
  });

  testWidgets('hub shows the two layer groups', (tester) async {
    await tester.pumpWidget(app(const PhotosMediaHubPage()));
    await tester.pump();

    expect(find.text('Where photos come from'), findsOneWidget);
    expect(find.text('Where copies are kept'), findsOneWidget);
    // Issue #3460: connected accounts serve sync and shared libraries too,
    // so they are reached from Settings > Data, not from this hub.
    expect(find.text('Accounts'), findsNothing);
    expect(find.text('Connected Accounts'), findsNothing);
    // Lightroom and Network sources now live inside "Photo library &
    // sources", not at the hub level.
    expect(find.text('Adobe Lightroom'), findsNothing);
    expect(find.text('Network sources'), findsNothing);
    // Sentence-case page name from the vocabulary pass (#3482).
    expect(find.text('Photos & videos'), findsOneWidget);
  });

  testWidgets('setup guide renders three steps with live status', (
    tester,
  ) async {
    await tester.pumpWidget(app(const PhotosMediaSetupPage()));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('Photo sources'), findsOneWidget);
    expect(find.text('Media storage'), findsOneWidget);
    expect(find.text('Cloud sync'), findsOneWidget);
    expect(find.text('Not set up'), findsNWidgets(3));
  });

  testWidgets('connected accounts page lists an account with status', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      final repo = container.read(connectedAccountsRepositoryProvider);
      await repo.create(kind: AccountKind.s3, label: 'My MinIO');
    });

    await tester.pumpWidget(app(const ConnectedAccountsPage()));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('My MinIO'), findsOneWidget);
    expect(find.textContaining('Not signed in on this device'), findsOneWidget);
  });

  testWidgets('connected accounts page shows the empty state', (tester) async {
    await tester.pumpWidget(app(const ConnectedAccountsPage()));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('No accounts connected yet'), findsOneWidget);
  });

  // Issue #3337.
  group('cache sizes', () {
    Slider slider(WidgetTester tester, String key) =>
        tester.widget<Slider>(find.byKey(ValueKey(key)));

    /// Drags [key]'s slider to the stop for [mb] and lets go.
    void release(WidgetTester tester, String key, List<int> steps, int mb) {
      final value = steps.indexOf(mb).toDouble();
      slider(tester, key).onChanged!(value);
      slider(tester, key).onChangeEnd!(value);
    }

    Future<void> pumpHub(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const PhotosMediaHubPage()));
      await tester.pump();
    }

    testWidgets('both sliders show the defaults on their seven stops', (
      tester,
    ) async {
      await pumpHub(tester);

      final memory = slider(tester, 'media_memory_cache_slider');
      final disk = slider(tester, 'media_disk_cache_slider');
      expect(memory.divisions, kMemoryCacheStepsMb.length - 1);
      expect(disk.divisions, kDiskCacheStepsMb.length - 1);
      expect(memory.value, kMemoryCacheStepsMb.indexOf(128));
      expect(disk.value, kDiskCacheStepsMb.indexOf(512));
      expect(find.text('128 MB'), findsOneWidget);
      expect(find.text('512 MB'), findsOneWidget);
    });

    testWidgets('moving the memory slider stores the size and applies it', (
      tester,
    ) async {
      await pumpHub(tester);

      release(tester, 'media_memory_cache_slider', kMemoryCacheStepsMb, 1024);
      await tester.pump();

      expect(prefs.getInt(kMediaMemoryCacheMbKey), 1024);
      expect(appliedMemoryBytes, [1024 * 1024 * 1024]);
      expect(find.text('1 GB'), findsOneWidget);
    });

    testWidgets('moving the disk slider stores the size', (tester) async {
      await pumpHub(tester);

      release(tester, 'media_disk_cache_slider', kDiskCacheStepsMb, 16384);
      await tester.pump();

      expect(prefs.getInt(kMediaDiskCacheMbKey), 16384);
      expect(find.text('16 GB'), findsOneWidget);
    });

    testWidgets('a stop passed mid-drag is shown but not stored', (
      tester,
    ) async {
      await pumpHub(tester);

      slider(tester, 'media_disk_cache_slider').onChanged!(
        kDiskCacheStepsMb.indexOf(256).toDouble(),
      );
      await tester.pump();

      expect(find.text('256 MB'), findsOneWidget);
      expect(prefs.getInt(kMediaDiskCacheMbKey), isNull);

      release(tester, 'media_disk_cache_slider', kDiskCacheStepsMb, 2048);
      await tester.pump();

      expect(prefs.getInt(kMediaDiskCacheMbKey), 2048);
      expect(find.text('2 GB'), findsOneWidget);
    });
  });

  // Issue #3337 follow-up.
  group('empty cache button', () {
    final button = find.byKey(const ValueKey('media_disk_cache_empty_button'));

    Future<void> pumpHub(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(const PhotosMediaHubPage()));
      await tester.pump();
    }

    testWidgets('sits to the right of the disk cache slider', (tester) async {
      await pumpHub(tester);

      final slider = find.byKey(const ValueKey('media_disk_cache_slider'));
      expect(button, findsOneWidget);
      expect(
        tester.getTopLeft(button).dx,
        greaterThanOrEqualTo(tester.getTopRight(slider).dx),
      );
      expect(
        tester.getCenter(button).dy,
        moreOrLessEquals(tester.getCenter(slider).dy, epsilon: 1),
      );
    });

    testWidgets('is an outlined button with an icon and a label, like Test '
        'Connection on the network page', (tester) async {
      await pumpHub(tester);

      expect(tester.widget(button), isA<OutlinedButton>());
      expect(
        find.descendant(of: button, matching: find.text('Empty cache')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: button, matching: find.byType(Icon)),
        findsOneWidget,
      );
    });

    testWidgets('the memory slider is as wide as the disk slider, though it '
        'has no button', (tester) async {
      await pumpHub(tester);

      final memory = tester.getRect(
        find.byKey(const ValueKey('media_memory_cache_slider')),
      );
      final disk = tester.getRect(
        find.byKey(const ValueKey('media_disk_cache_slider')),
      );
      expect(memory.width, disk.width);
      expect(memory.left, disk.left);
      // Only one button can be pressed or read out.
      expect(find.bySubtype<OutlinedButton>().hitTestable(), findsOneWidget);
    });

    testWidgets('empties the cache and says so', (tester) async {
      await pumpHub(tester);

      await tester.tap(button);
      await tester.pump();

      expect(emptied, 1);
      expect(find.text('Thumbnail cache emptied'), findsOneWidget);
    });

    testWidgets('says when the cache could not be emptied', (tester) async {
      emptyDiskCache = () async => throw StateError('no cache database');
      await pumpHub(tester);

      await tester.tap(button);
      await tester.pump();

      expect(find.text('Could not empty the thumbnail cache'), findsOneWidget);
    });
  });
}
