import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/network_credentials_repository.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';
import 'package:submersion/features/media/presentation/widgets/network_thumbnail.dart';
import 'package:submersion/features/media/presentation/widgets/url_review_pane.dart';

import '../../../../support/fake_keychain_storage.dart';

const _publicUrl = 'https://public.example/a.jpg';
const _otherPublicUrl = 'https://other.example/b.jpg';

/// Answers from [headersByHost] and records every lookup it is asked for.
class _CountingCredentials extends Fake implements NetworkCredentialsService {
  _CountingCredentials([this.headersByHost = const {}]);

  final Map<String, Map<String, String>> headersByHost;
  final lookups = <Uri>[];

  @override
  Future<Map<String, String>?> headersFor(Uri uri) async {
    lookups.add(uri);
    return headersByHost[uri.host];
  }
}

class _FailingCredentials extends Fake implements NetworkCredentialsService {
  @override
  Future<Map<String, String>?> headersFor(Uri uri) async =>
      throw PlatformException(code: 'keychain-locked');
}

/// Counts the reads that would be a platform-channel call in the app.
class _CountingKeychain extends InMemoryKeychain {
  int reads = 0;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    reads += 1;
    return super.read(key: key);
  }
}

/// Just enough repository for the real service to save and delete rows.
class _FakeRepository extends Fake implements NetworkCredentialsRepository {
  final rows = <String, NetworkCredentialHost>{};

  @override
  Future<String> upsert({
    required String hostname,
    required String authType,
    String? displayName,
  }) async {
    rows[hostname] = NetworkCredentialHost(
      id: hostname,
      hostname: hostname,
      authType: authType,
      displayName: displayName,
      credentialsRef: hostname,
      addedAt: 0,
    );
    return hostname;
  }

  @override
  Future<NetworkCredentialHost?> findById(String id) async => rows[id];

  @override
  Future<NetworkCredentialHost?> findByHostname(String hostname) async =>
      rows[hostname];

  @override
  Future<void> touchLastUsed(String id) async {}

  @override
  Future<void> delete(String id) async => rows.remove(id);
}

/// Not const, like the rows that build one: a const widget would skip the
/// rebuild under test.
Widget _rebuiltThumbnail(String url) => NetworkThumbnail(url: url);

Widget _app(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(home: Scaffold(body: child)),
);

List<Override> _credentials(NetworkCredentialsService service) => [
  networkCredentialsServiceProvider.overrideWithValue(service),
];

/// The real service behind the real providers, so a save reaches the
/// thumbnails the way it does in the app.
List<Override> _realCredentials([FlutterSecureStorage? keychain]) => [
  networkCredentialsRepositoryProvider.overrideWithValue(_FakeRepository()),
  flutterSecureStorageProvider.overrideWithValue(
    keychain ?? InMemoryKeychain(),
  ),
];

CachedNetworkImage _image(WidgetTester tester, String url) =>
    tester.widget<CachedNetworkImage>(_imageFinder(url));

Finder _imageFinder(String url) => find.byWidgetPredicate(
  (widget) => widget is CachedNetworkImage && widget.imageUrl == url,
);

/// Lets the lookup finish and paints the frame that follows it.
Future<void> _settleLookups(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

NetworkCredentialsService _service(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(NetworkThumbnail).first),
    ).read(networkCredentialsServiceProvider);

void main() {
  group('NetworkThumbnail keeps its lookup across builds (#3851)', () {
    testWidgets('a parent rebuild neither looks up nor shows the placeholder', (
      tester,
    ) async {
      final credentials = _CountingCredentials();
      final rebuilds = ValueNotifier(0);
      addTearDown(rebuilds.dispose);

      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<int>(
            valueListenable: rebuilds,
            builder: (_, count, _) => Column(
              children: [Text('$count'), _rebuiltThumbnail(_publicUrl)],
            ),
          ),
          _credentials(credentials),
        ),
      );
      await _settleLookups(tester);
      final painted = tester.element(_imageFinder(_publicUrl));

      for (var i = 1; i <= 3; i++) {
        rebuilds.value = i;
        await tester.pump();
        expect(find.text('$i'), findsOneWidget);
        expect(tester.element(_imageFinder(_publicUrl)), same(painted));
      }

      expect(credentials.lookups, hasLength(1));
    });

    testWidgets('thumbnails of one URL share a lookup', (tester) async {
      final credentials = _CountingCredentials();

      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              NetworkThumbnail(url: _publicUrl),
              NetworkThumbnail(url: _publicUrl),
            ],
          ),
          _credentials(credentials),
        ),
      );
      await _settleLookups(tester);

      expect(_imageFinder(_publicUrl), findsNWidgets(2));
      expect(credentials.lookups, hasLength(1));
    });

    testWidgets('a changed URL resolves again for its new host', (
      tester,
    ) async {
      final credentials = _CountingCredentials({
        'other.example': {'Authorization': 'Bearer o'},
      });
      final url = ValueNotifier(_publicUrl);
      addTearDown(url.dispose);

      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<String>(
            valueListenable: url,
            builder: (_, value, _) => NetworkThumbnail(url: value),
          ),
          _credentials(credentials),
        ),
      );
      await _settleLookups(tester);
      expect(_image(tester, _publicUrl).httpHeaders, isNull);

      url.value = _otherPublicUrl;
      await tester.pump();
      await _settleLookups(tester);

      expect(_image(tester, _otherPublicUrl).httpHeaders, {
        'Authorization': 'Bearer o',
      });
      expect(credentials.lookups.map((uri) => uri.host), [
        'public.example',
        'other.example',
      ]);
    });

    testWidgets('a malformed URL paints instead of failing the build', (
      tester,
    ) async {
      const malformed = 'http://[not-a-host/a.jpg';
      final credentials = _CountingCredentials();

      await tester.pumpWidget(
        _app(const NetworkThumbnail(url: malformed), _credentials(credentials)),
      );
      await _settleLookups(tester);

      expect(tester.takeException(), isNull);
      expect(_image(tester, malformed).httpHeaders, isNull);
      expect(credentials.lookups, isEmpty);
    });

    testWidgets('a failed lookup still paints, without headers or a retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const NetworkThumbnail(url: _publicUrl),
          _credentials(_FailingCredentials()),
        ),
      );
      await _settleLookups(tester);

      expect(_image(tester, _publicUrl).httpHeaders, isNull);
    });
  });

  group('NetworkThumbnail follows saved credentials (#3851)', () {
    testWidgets('saving reloads the image of a mounted thumbnail', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const NetworkThumbnail(url: _publicUrl), _realCredentials()),
      );
      await _settleLookups(tester);
      final unauthenticated = tester.element(_imageFinder(_publicUrl));
      expect(_image(tester, _publicUrl).httpHeaders, isNull);

      await _service(
        tester,
      ).save(hostname: 'public.example', authType: 'bearer', token: 't');
      await _settleLookups(tester);
      await _settleLookups(tester);

      expect(_image(tester, _publicUrl).httpHeaders, {
        'Authorization': 'Bearer t',
      });
      // The image provider's identity ignores headers, so only a new element
      // refetches an image that failed before the user signed in.
      expect(
        tester.element(_imageFinder(_publicUrl)),
        isNot(same(unauthenticated)),
      );
    });

    testWidgets('saving leaves another host\'s image alone', (tester) async {
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              NetworkThumbnail(url: _publicUrl),
              NetworkThumbnail(url: _otherPublicUrl),
            ],
          ),
          _realCredentials(),
        ),
      );
      await _settleLookups(tester);
      await _settleLookups(tester);
      final other = tester.element(_imageFinder(_otherPublicUrl));

      await _service(
        tester,
      ).save(hostname: 'public.example', authType: 'bearer', token: 't');
      await tester.pump();
      expect(tester.element(_imageFinder(_otherPublicUrl)), same(other));
      await _settleLookups(tester);
      await _settleLookups(tester);

      expect(tester.element(_imageFinder(_otherPublicUrl)), same(other));
    });

    testWidgets('deleting drops the header from a mounted thumbnail', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const NetworkThumbnail(url: _publicUrl), _realCredentials()),
      );
      await _settleLookups(tester);
      final service = _service(tester);
      await service.save(
        hostname: 'public.example',
        authType: 'bearer',
        token: 't',
      );
      await _settleLookups(tester);
      await _settleLookups(tester);

      expect(_image(tester, _publicUrl).httpHeaders, isNotNull);

      await service.delete('public.example');
      await _settleLookups(tester);
      await _settleLookups(tester);

      expect(_image(tester, _publicUrl).httpHeaders, isNull);
    });
  });

  group('UrlReviewPane reads the keychain once per host (#3851)', () {
    testWidgets('editing a draft of public URLs adds no reads', (tester) async {
      final keychain = _CountingKeychain();
      final lines = [
        for (var i = 0; i < 40; i++) 'https://public.example/$i.jpg',
      ];
      final draft = ValueNotifier(lines);
      addTearDown(draft.dispose);

      await tester.pumpWidget(
        _app(
          ValueListenableBuilder<List<String>>(
            valueListenable: draft,
            builder: (_, value, _) =>
                UrlReviewPane(state: UrlTabState(draftLines: value)),
          ),
          _realCredentials(keychain),
        ),
      );
      await _settleLookups(tester);
      await _settleLookups(tester);
      expect(keychain.reads, 1);

      for (var edit = 0; edit < 5; edit++) {
        draft.value = [...draft.value, 'https://public.example/new$edit.jpg'];
        await _settleLookups(tester);
      }

      expect(keychain.reads, 1);
    });
  });

  test('a service outliving its provider still saves', () async {
    final container = ProviderContainer(overrides: _realCredentials());
    final service = container.read(networkCredentialsServiceProvider);
    container.dispose();

    await expectLater(
      service.save(hostname: 'public.example', authType: 'bearer', token: 't'),
      completes,
    );
  });
}
