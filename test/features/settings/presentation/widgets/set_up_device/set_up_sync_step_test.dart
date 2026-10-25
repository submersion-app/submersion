import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/settings/presentation/pages/replace_join_page.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_library_probe.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_sync_actions.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_sync_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _drive = groupAccounts(
  rows: [
    ConnectedAccount(
      id: 'gd',
      kind: AccountKind.googledrive,
      label: 'Google Drive',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ],
  statusById: const {'gd': AccountStatus.signedIn},
  localLocationById: const {},
  usagesOf: (_) => const [],
).single;

class _Flow extends SetUpFlowNotifier {
  @override
  AccountGroup? build() => _drive;
}

class _FakeSync extends StateNotifier<SyncState> implements SyncNotifier {
  _FakeSync() : super(const SyncState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Actions extends SetUpSyncActions {
  _Actions({
    this.firstSyncAnswer = SetUpFirstSync.synced,
    this.replaceEnd,
    this.connectAnswer = SetUpConnect.connected,
  });

  final SetUpFirstSync firstSyncAnswer;
  final ReplaceJoinEnd? replaceEnd;
  SetUpConnect connectAnswer;

  /// Holds connect open until completed, when set.
  Completer<void>? connectGate;
  final calls = <String>[];
  int? replacedCount;
  bool? replacedKeepInStep;
  ({bool keepInStep, bool realignDiver})? firstSyncArgs;

  @override
  Future<SetUpConnect> connect(
    BuildContext context,
    WidgetRef ref,
    AccountGroup account,
  ) async {
    calls.add('connect ${account.label}');
    await connectGate?.future;
    return connectAnswer;
  }

  @override
  Future<SetUpFirstSync> firstSync(
    WidgetRef ref, {
    required bool keepInStep,
    required bool realignDiver,
  }) async {
    firstSyncArgs = (keepInStep: keepInStep, realignDiver: realignDiver);
    return firstSyncAnswer;
  }

  @override
  Future<void> unlock(WidgetRef ref, String secret) async {
    calls.add('unlock');
    if (secret == 'offline') throw StateError('network');
    if (secret != 'right') throw const WrongPassphraseException();
  }

  @override
  Future<bool> adopt(
    BuildContext context,
    WidgetRef ref,
    LibraryEpochMarker marker,
  ) async {
    calls.add('adopt');
    return true;
  }

  @override
  Future<ReplaceJoinEnd?> replace(
    BuildContext context,
    WidgetRef ref, {
    required int diveCount,
    required String backupNote,
    required bool keepInStep,
  }) async {
    replacedCount = diveCount;
    replacedKeepInStep = keepInStep;
    return replaceEnd;
  }
}

/// Step 2, "Dives on every device" (issue #3482, Part B Task 10).
void main() {
  late _Actions actions;
  late List<String> nav;
  late int probes;

  Future<void> pump(
    WidgetTester tester,
    SetUpLibrary library, {
    _Actions? withActions,
    bool offerNewLogbook = false,
  }) async {
    actions = withActions ?? _Actions();
    nav = [];
    probes = 0;
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setUpFlowProvider.overrideWith(_Flow.new),
          accountGroupsProvider.overrideWith((ref) async => [_drive]),
          syncStateProvider.overrideWith((ref) => _FakeSync()),
          setUpLibraryProvider.overrideWith((ref) async {
            probes++;
            return library;
          }),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SetUpSyncStep(
              navigation: SetUpStepNavigation(
                onNext: () => nav.add('next'),
                onBack: () => nav.add('back'),
                onNotNow: () => nav.add('notNow'),
                onNoLibrary: offerNewLogbook
                    ? () => nav.add('newLogbook')
                    : null,
              ),
              actions: actions,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('points sync at the chosen account on entry', (tester) async {
    await pump(tester, const NoLibrary(4));
    expect(actions.calls, ['connect Google Drive']);
    expect(find.text('Signed in to Google Drive'), findsOneWidget);
  });

  testWidgets('a connect that does not finish offers to try again, and '
      'Check again connects again', (tester) async {
    await pump(
      tester,
      const NoLibrary(4),
      withActions: _Actions(connectAnswer: SetUpConnect.failed),
    );
    expect(
      find.text(
        'Could not read Google Drive. Check the connection and try again.',
      ),
      findsOneWidget,
    );
    expect(probes, 0);

    actions.connectAnswer = SetUpConnect.connected;
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();

    expect(actions.calls, ['connect Google Drive', 'connect Google Drive']);
    expect(find.text('Turn on sync'), findsOneWidget);
  });

  testWidgets('Check again connects once however often it is tapped', (
    tester,
  ) async {
    await pump(
      tester,
      const NoLibrary(4),
      withActions: _Actions(connectAnswer: SetUpConnect.failed),
    );
    actions
      ..connectAnswer = SetUpConnect.connected
      ..connectGate = Completer<void>();

    await tester.tap(find.text('Check again'));
    await tester.pump();
    // Busy: the button shows progress in place of its label.
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    actions.connectGate!.complete();
    await tester.pumpAndSettle();

    expect(actions.calls, ['connect Google Drive', 'connect Google Drive']);
  });

  testWidgets('a device already in step with the account says so, reads '
      'nothing, and Next moves on', (tester) async {
    await pump(
      tester,
      const NoLibrary(4),
      withActions: _Actions(connectAnswer: SetUpConnect.inStep),
    );

    expect(
      find.text(
        'The dives here are in step with your library in Google Drive.',
      ),
      findsOneWidget,
    );
    expect(probes, 0);

    await tester.tap(find.text('Next'));
    await tester.tap(find.text('Not now'));
    expect(nav, ['next', 'notNow']);
  });

  group('no library', () {
    testWidgets('a host that would rather start a new logbook offers it', (
      tester,
    ) async {
      await pump(tester, const NoLibrary(0), offerNewLogbook: true);

      expect(find.text('No library found'), findsOneWidget);
      expect(find.text('Turn on sync'), findsNothing);

      await tester.tap(find.text('Start a new logbook'));
      expect(nav, ['newLogbook']);
    });

    testWidgets('the dives here become the library, and sync stays on', (
      tester,
    ) async {
      await pump(tester, const NoLibrary(4));
      expect(
        find.text(
          'Google Drive has no Submersion library yet. The dives here will '
          'become the library all your devices share.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Turn on sync'));
      await tester.pumpAndSettle();

      expect(actions.firstSyncArgs, (keepInStep: true, realignDiver: false));
      expect(nav, ['next']);
    });

    testWidgets('with Keep devices in step off, automatic sync is left '
        'alone', (tester) async {
      await pump(tester, const NoLibrary(4));

      await tester.tap(find.text('Keep devices in step automatically'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Turn on sync'));
      await tester.pumpAndSettle();

      expect(actions.firstSyncArgs?.keepInStep, isFalse);
    });

    testWidgets('a sync that fails stays on the step', (tester) async {
      await pump(
        tester,
        const NoLibrary(4),
        withActions: _Actions(firstSyncAnswer: SetUpFirstSync.failed),
      );

      await tester.tap(find.text('Turn on sync'));
      await tester.pumpAndSettle();

      expect(nav, isEmpty);
    });
  });

  group('a library', () {
    testWidgets('names the device that changed it last', (tester) async {
      await pump(
        tester,
        LibraryFound(
          localDives: 0,
          deviceName: "Eric's iPhone",
          changedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      );
      expect(
        find.textContaining(
          "Found your library in Google Drive, last changed 3h ago on Eric's "
          'iPhone.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a device with no name gives the plain sentence', (
      tester,
    ) async {
      await pump(
        tester,
        LibraryFound(
          localDives: 0,
          deviceName: ' ',
          changedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      );
      expect(find.text('Found your library in Google Drive.'), findsOneWidget);
    });

    testWidgets('an empty device downloads it and realigns the diver', (
      tester,
    ) async {
      await pump(tester, const LibraryFound(localDives: 0));
      expect(
        find.text(
          'There are no dives here yet, so the library is simply downloaded.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Download library'));
      await tester.pumpAndSettle();

      expect(actions.firstSyncArgs, (keepInStep: true, realignDiver: true));
      expect(nav, ['next']);
    });

    testWidgets('a device with dives combines them by default', (tester) async {
      await pump(tester, const LibraryFound(localDives: 12));

      await tester.tap(find.text('Combine and download'));
      await tester.pumpAndSettle();

      expect(actions.firstSyncArgs, (keepInStep: true, realignDiver: false));
      expect(nav, ['next']);
    });

    testWidgets('Replace asks for the typed word, and cancelling replaces '
        'nothing', (tester) async {
      await pump(tester, const LibraryFound(localDives: 12));

      await tester.tap(find.text('Replace the dives here with the library'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace and download'));
      await tester.pumpAndSettle();

      expect(find.text('Replace the dives here?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(actions.replacedCount, isNull);
    });

    testWidgets('a refused replace says why and stays on the step', (
      tester,
    ) async {
      await pump(
        tester,
        const LibraryFound(localDives: 12),
        withActions: _Actions(
          replaceEnd: const ReplaceJoinRefused(
            ReplaceJoinResult(ReplaceJoinOutcome.photosBusy),
          ),
        ),
      );

      await tester.tap(find.text('Replace the dives here with the library'));
      await tester.pumpAndSettle();
      // Replacing still keeps the devices in step afterwards.
      expect(find.text('Keep devices in step automatically'), findsOneWidget);
      await tester.tap(find.text('Replace and download'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Replace');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
      await tester.pumpAndSettle();

      expect(actions.replacedCount, 12);
      expect(actions.replacedKeepInStep, isTrue);
      expect(
        find.text('Photo uploads are still finishing. Try again in a moment.'),
        findsOneWidget,
      );
      expect(nav, isEmpty);
    });
  });

  group('a locked library', () {
    testWidgets('a wrong secret says so; the right one reads the library '
        'again', (tester) async {
      await pump(tester, const LibraryLocked());
      expect(find.text('This library is encrypted'), findsOneWidget);
      final before = probes;

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(
        find.text('Incorrect passphrase or recovery code'),
        findsOneWidget,
      );
      expect(probes, before);

      await tester.enterText(find.byType(TextField), 'right');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(probes, before + 1);
    });

    testWidgets('an unlock that fails for another reason says the account '
        'could not be read', (tester) async {
      await pump(tester, const LibraryLocked());

      await tester.enterText(find.byType(TextField), 'offline');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not read Google Drive. Check the connection and try again.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('an unfinished upload offers to check again', (tester) async {
    await pump(tester, const LibraryIncomplete());
    expect(find.text('Library upload unfinished'), findsOneWidget);
    final before = probes;

    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();

    expect(probes, before + 1);
  });

  testWidgets('an account that cannot be read offers to check again', (
    tester,
  ) async {
    await pump(tester, const LibraryUnreachable());
    expect(
      find.text(
        'Could not read Google Drive. Check the connection and try again.',
      ),
      findsOneWidget,
    );
    final before = probes;

    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();

    expect(probes, before + 1);
  });

  testWidgets('a replaced library is adopted, then the step is done', (
    tester,
  ) async {
    await pump(
      tester,
      const LibraryAwaitingAdoption(
        LibraryEpochMarker(
          epochId: 'e2',
          replacedAt: 1700000000000,
          deviceId: 'peer',
          deviceName: "Eric's iPhone",
        ),
      ),
    );

    await tester.tap(find.text('Adopt Restored Library'));
    await tester.pumpAndSettle();

    expect(actions.calls, contains('adopt'));
    expect(nav, ['next']);
  });

  testWidgets('Back and Not now leave the step', (tester) async {
    await pump(tester, const NoLibrary(4));

    await tester.tap(find.text('Back'));
    await tester.tap(find.text('Not now'));

    expect(nav, ['back', 'notNow']);
  });
}
