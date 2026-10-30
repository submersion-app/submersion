import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/media_store/data/media_backfill_service.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_upload_progress_provider.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/data_row_status_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_row_status_text.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_done_view.dart';
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

class _FakeBackfill implements MediaBackfillService {
  int calls = 0;

  @override
  Future<int> enqueueAll() async {
    calls++;
    return 7;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _accounts = DataRowStatus(
  DataRowStatusKind.accountsListed,
  name: 'Google Drive',
  count: 1,
);
const _sync = DataRowStatus(DataRowStatusKind.syncFolder);
const _backups = DataRowStatus(
  DataRowStatusKind.backupsCloud,
  name: 'Google Drive',
);
const _photosOn = DataRowStatus(
  DataRowStatusKind.photosOn,
  name: 'Google Drive',
);
const _photosOff = DataRowStatus(
  DataRowStatusKind.photosOff,
  offersSetUp: true,
);

/// The screen after the last step (issue #3482, Part B Task 13).
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  late _FakeBackfill backfill;
  late int done;

  Future<void> pump(
    WidgetTester tester, {
    DataRowStatus photos = _photosOn,
    bool attached = true,
    ({int copied, int total}) progress = (copied: 3, total: 10),
  }) async {
    backfill = _FakeBackfill();
    done = 0;
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          setUpFlowProvider.overrideWith(_Flow.new),
          accountGroupsProvider.overrideWith((ref) async => [_drive]),
          accountsRowStatusProvider.overrideWithValue(_accounts),
          syncRowStatusProvider.overrideWithValue(_sync),
          backupsRowStatusProvider.overrideWithValue(_backups),
          photosRowStatusProvider.overrideWithValue(photos),
          mediaStoreAttachedProvider.overrideWith((ref) async => attached),
          mediaUploadProgressProvider.overrideWith((ref) async => progress),
          mediaBackfillServiceProvider.overrideWithValue(backfill),
          mediaStoreRuntimeProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SetUpDoneView(onDone: () => done++)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String text(DataRowStatus status) =>
      dataRowStatusText(l10n, status, DateTime.now());

  testWidgets('a device set up says so, one line per outcome, in the Data '
      "page's words", (tester) async {
    await pump(tester);

    expect(find.textContaining('is set up'), findsOneWidget);
    for (final status in [_accounts, _sync, _backups, _photosOn]) {
      expect(find.text(text(status)), findsOneWidget);
    }
    expect(
      find.text(
        'On your other devices, open Submersion, choose Google Drive, and '
        'the same library appears.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('with photos skipped, the photos line says no copies are kept, '
      'and nothing offers to upload', (tester) async {
    await pump(tester, photos: _photosOff, attached: false);

    expect(find.text(text(_photosOff)), findsOneWidget);
    expect(find.text('Upload everything already attached'), findsNothing);
  });

  testWidgets('everything copied already offers no upload', (tester) async {
    await pump(tester, progress: (copied: 10, total: 10));

    expect(find.text('Upload everything already attached'), findsNothing);
  });

  testWidgets('Upload everything queues once', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Upload everything already attached'));
    await tester.pumpAndSettle();

    expect(backfill.calls, 1);
    expect(find.text('Upload everything already attached'), findsNothing);
    expect(
      find.text(l10n.settings_mediaStorage_backfill_enqueued(7)),
      findsOneWidget,
    );
  });

  testWidgets('Done leaves', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Done'));

    expect(done, 1);
  });
}
