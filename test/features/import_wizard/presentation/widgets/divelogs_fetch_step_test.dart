import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_auth.dart';
import 'package:submersion/features/import_wizard/data/adapters/divelogs_import_adapter.dart';
import 'package:submersion/features/import_wizard/data/adapters/remote_photo_attacher.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/divelogs_import_steps.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/presentation/providers/universal_import_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Map<String, dynamic> _dive(int id, {String time = '14:42:00'}) => {
  'id': id,
  'date': '2022-09-03',
  'time': time,
  'duration': 2808,
  'maxdepth': 12,
  'divesite': 'Reef',
};

void main() {
  late ProviderContainer container;
  late List<Map<String, List<RemotePhoto>>> listed;
  late List<String> requested;
  late int expiredCalls;

  // Mutable server behaviour, read by every request.
  late Object dives;
  late int divesStatus;
  late int gearStatus;
  late Map<String, Object> pictures;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(const AppSettings()),
        ),
      ],
    );
    listed = [];
    requested = [];
    expiredCalls = 0;
    dives = [_dive(1), _dive(2, time: '16:00:00')];
    divesStatus = 200;
    gearStatus = 200;
    pictures = {
      '1': [
        {'id': 10, 'url': 'https://divelogs.de/pics/reef.jpg'},
      ],
    };
  });

  tearDown(() => container.dispose());

  DivelogsApiClient client({Future<String> Function()? token}) =>
      DivelogsApiClient(
        getBearerToken: token ?? () async => 't',
        onTokenRejected: () {},
        httpClient: MockClient((req) async {
          final path = req.url.path;
          requested.add(path);
          if (path.startsWith('/api/pictures/')) {
            return http.Response(
              jsonEncode(pictures[path.split('/').last] ?? []),
              200,
            );
          }
          return switch (path) {
            '/api/dives' => http.Response(jsonEncode(dives), divesStatus),
            '/api/gear' => http.Response('[]', gearStatus),
            _ => http.Response('[]', 200),
          };
        }),
      );

  Future<void> withPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpStep(WidgetTester tester, DivelogsApiClient api) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DivelogsFetchStep(
              client: api,
              onPhotosListed: listed.add,
              onSessionExpired: () => expiredCalls++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> fetch(WidgetTester tester) async {
    await tester.tap(find.text('Fetch Logbook'));
    await settle(tester);
  }

  testWidgets('fetches dives and lists photos', (tester) async {
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(tester, client());
      expect(find.text('Include photos'), findsOneWidget);

      await fetch(tester);

      expect(find.text('Found 2 dives'), findsOneWidget);
      expect(find.text('1 photo to import'), findsOneWidget);
      expect(container.read(divelogsFetchedProvider), isTrue);
      final state = container.read(universalImportNotifierProvider);
      expect(state.payload!.entitiesOf(ImportEntityType.dives), hasLength(2));
      expect(state.remotePhotoCount, 1);
      expect(listed.single.keys, ['divelogs-1']);
    });
  });

  testWidgets('skips photo listing when switched off', (tester) async {
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(tester, client());
      await tester.tap(find.text('Include photos'));
      await tester.pump();

      await fetch(tester);

      expect(requested.where((p) => p.startsWith('/api/pictures/')), isEmpty);
      expect(
        container.read(universalImportNotifierProvider).remotePhotoCount,
        0,
      );
    });
  });

  testWidgets('mobile hides the switch and lists no photos', (tester) async {
    await withPlatform(TargetPlatform.iOS, () async {
      await pumpStep(tester, client());
      expect(find.text('Include photos'), findsNothing);

      await fetch(tester);

      expect(requested.where((p) => p.startsWith('/api/pictures/')), isEmpty);
      expect(container.read(divelogsFetchedProvider), isTrue);
    });
  });

  testWidgets('a gear failure is reported and the fetch still succeeds', (
    tester,
  ) async {
    gearStatus = 500;
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(tester, client());
      await fetch(tester);

      expect(
        find.text(
          'Gear could not be fetched; dives will import without gear links.',
        ),
        findsOneWidget,
      );
      expect(container.read(divelogsFetchedProvider), isTrue);
    });
  });

  testWidgets('a /dives failure offers a retry', (tester) async {
    divesStatus = 503;
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(tester, client());
      await fetch(tester);

      expect(find.text('Could not fetch your logbook'), findsOneWidget);
      expect(container.read(divelogsFetchedProvider), isFalse);

      divesStatus = 200;
      await tester.tap(find.text('Try Again'));
      await settle(tester);

      expect(find.text('Found 2 dives'), findsOneWidget);
      expect(container.read(divelogsFetchedProvider), isTrue);
    });
  });

  testWidgets('an expired session sends the diver back to sign in', (
    tester,
  ) async {
    container.read(divelogsSignedInProvider.notifier).state = true;
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(
        tester,
        client(
          token: () async => throw const DivelogsSessionExpiredException(),
        ),
      );
      await fetch(tester);

      expect(
        find.text(
          'Your divelogs.de session expired. Go back and sign in again.',
        ),
        findsOneWidget,
      );
      expect(container.read(divelogsSignedInProvider), isFalse);
      expect(container.read(divelogsFetchedProvider), isFalse);
    });
  });

  testWidgets('an empty logbook says so and installs nothing', (tester) async {
    dives = [];
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(tester, client());
      await fetch(tester);

      expect(
        find.text('Your divelogs.de logbook has nothing to import.'),
        findsOneWidget,
      );
      expect(container.read(divelogsFetchedProvider), isFalse);
      expect(container.read(universalImportNotifierProvider).payload, isNull);
    });
  });

  testWidgets('a failed re-fetch does not leave an earlier fetch usable', (
    tester,
  ) async {
    container.read(divelogsFetchedProvider.notifier).state = true;
    divesStatus = 503;
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(tester, client());
      await fetch(tester);

      expect(find.text('Could not fetch your logbook'), findsOneWidget);
      expect(container.read(divelogsFetchedProvider), isFalse);
    });
  });

  testWidgets('a new fetch discards the payload of the previous one', (
    tester,
  ) async {
    final notifier = container.read(universalImportNotifierProvider.notifier);
    await withPlatform(TargetPlatform.macOS, () async {
      notifier.state = notifier.state.copyWith(
        payload: const ImportPayload(
          entities: {
            ImportEntityType.dives: [
              {'sourceUuid': 'divelogs-99'},
            ],
          },
        ),
      );
      dives = [];
      await pumpStep(tester, client());
      await fetch(tester);

      expect(container.read(universalImportNotifierProvider).payload, isNull);
    });
  });

  testWidgets('a refused session reads as expired, not as a retryable error', (
    tester,
  ) async {
    divesStatus = 401;
    container.read(divelogsSignedInProvider.notifier).state = true;
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(tester, client());
      await fetch(tester);

      expect(
        find.text(
          'Your divelogs.de session expired. Go back and sign in again.',
        ),
        findsOneWidget,
      );
      expect(container.read(divelogsSignedInProvider), isFalse);
    });
  });

  testWidgets('a fetch that finishes after the session changed is dropped', (
    tester,
  ) async {
    final gate = Completer<void>();
    final api = DivelogsApiClient(
      getBearerToken: () async => 't',
      onTokenRejected: () {},
      httpClient: MockClient((req) async {
        if (req.url.path == '/api/dives') {
          await gate.future;
          return http.Response(jsonEncode([_dive(1)]), 200);
        }
        return http.Response('[]', 200);
      }),
    );
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(tester, api);
      await tester.tap(find.text('Fetch Logbook'));
      await tester.pump();

      // The user signs out or switches accounts while /dives is in flight.
      container.read(divelogsSessionGenerationProvider.notifier).state++;
      gate.complete();
      await settle(tester);

      expect(container.read(universalImportNotifierProvider).payload, isNull);
      expect(container.read(divelogsFetchedProvider), isFalse);
      expect(listed, isEmpty);
    });
  });

  testWidgets('an expired session hands control back to sign in', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(
        tester,
        client(
          token: () async => throw const DivelogsSessionExpiredException(),
        ),
      );
      await fetch(tester);

      expect(expiredCalls, 1);
    });
  });

  testWidgets('a keychain failure during the fetch offers a retry', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(
        tester,
        client(
          token: () async =>
              throw PlatformException(code: 'keychain', message: 'denied'),
        ),
      );
      await fetch(tester);

      expect(find.text('Could not fetch your logbook'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  testWidgets('a renewal refused for bad credentials hands back to sign in', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(
        tester,
        client(
          token: () async => throw const DivelogsAuthException(
            DivelogsAuthFailure.badCredentials,
          ),
        ),
      );
      await fetch(tester);

      expect(expiredCalls, 1);
    });
  });

  testWidgets('a renewal that cannot reach divelogs.de offers a retry', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(
        tester,
        client(
          token: () async => throw const DivelogsAuthException(
            DivelogsAuthFailure.unreachable,
          ),
        ),
      );
      await fetch(tester);

      expect(expiredCalls, 0);
      expect(find.text('Try Again'), findsOneWidget);
    });
  });

  testWidgets('leaving the step while the payload installs is harmless', (
    tester,
  ) async {
    final gate = Completer<void>();
    container.dispose();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(const AppSettings()),
        ),
        universalImportNotifierProvider.overrideWith(
          (ref) => _GatedNotifier(ref, gate.future),
        ),
      ],
    );
    await withPlatform(TargetPlatform.macOS, () async {
      await pumpStep(tester, client());
      await tester.tap(find.text('Fetch Logbook'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }

      // The diver backs out while the duplicate check is still running.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SizedBox.shrink()),
        ),
      );
      gate.complete();
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
      // The install did run to the end, so the disposed-step path was hit.
      expect(
        container.read(universalImportNotifierProvider).payload,
        isNotNull,
      );
    });
  });
}

/// Holds the payload install until [_gate] completes, standing in for a
/// duplicate check that is still reading the library.
class _GatedNotifier extends UniversalImportNotifier {
  _GatedNotifier(super.ref, this._gate);

  final Future<void> _gate;

  @override
  Future<void> setExternalPayload(
    ImportPayload payload, {
    int remotePhotoCount = 0,
  }) async {
    await _gate;
    return super.setExternalPayload(
      payload,
      remotePhotoCount: remotePhotoCount,
    );
  }
}
