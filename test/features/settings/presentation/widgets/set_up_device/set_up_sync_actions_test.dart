import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_sync_actions.dart';

/// A sync that ends in [after].
class _FakeSync extends StateNotifier<SyncState> implements SyncNotifier {
  _FakeSync(this.after) : super(const SyncState());

  final SyncState after;
  int runs = 0;

  @override
  Future<void> performSync({bool auto = false}) async {
    runs++;
    state = after;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Step 2's first sync (issue #3482): what it reports, and that it keeps
/// devices in step only once the sync has succeeded.
void main() {
  late _FakeSync sync;
  late WidgetRef ref;

  Future<void> pump(WidgetTester tester, SyncState after) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    sync = _FakeSync(after);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          syncStateProvider.overrideWith((ref) => sync),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, r, _) {
              ref = r;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }

  SyncBehaviorSettings behavior() => ref.read(syncBehaviorProvider);

  Future<SetUpFirstSync> firstSync({required bool keepInStep}) =>
      const SetUpSyncActions().firstSync(
        ref,
        keepInStep: keepInStep,
        realignDiver: false,
      );

  testWidgets('a sync that succeeds keeps devices in step', (tester) async {
    await pump(tester, const SyncState(status: SyncStatus.success));

    expect(await firstSync(keepInStep: true), SetUpFirstSync.synced);

    expect(sync.runs, 1);
    expect(behavior().autoSyncEnabled, isTrue);
    expect(behavior().syncOnLaunch, isTrue);
    expect(behavior().syncOnResume, isTrue);
  });

  testWidgets('with Keep devices in step off, automatic sync is untouched', (
    tester,
  ) async {
    await pump(tester, const SyncState(status: SyncStatus.success));
    final before = behavior();

    expect(await firstSync(keepInStep: false), SetUpFirstSync.synced);

    expect(behavior().autoSyncEnabled, before.autoSyncEnabled);
    expect(behavior().syncOnLaunch, before.syncOnLaunch);
    expect(behavior().syncOnResume, before.syncOnResume);
  });

  testWidgets('a locked or replaced library is blocked, and changes nothing', (
    tester,
  ) async {
    for (final after in const [
      SyncState(needsPassphrase: true),
      SyncState(replaceAwaitingAdoption: true),
    ]) {
      await pump(tester, after);
      final before = behavior();

      expect(await firstSync(keepInStep: true), SetUpFirstSync.blocked);
      expect(behavior().autoSyncEnabled, before.autoSyncEnabled);
    }
  });

  testWidgets('a sync that fails changes nothing', (tester) async {
    await pump(
      tester,
      const SyncState(status: SyncStatus.error, message: 'offline'),
    );
    final before = behavior();

    expect(await firstSync(keepInStep: true), SetUpFirstSync.failed);
    expect(behavior().autoSyncEnabled, before.autoSyncEnabled);
  });
}
