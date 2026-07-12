import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/lightroom_scan_service.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/lightroom_suggestions_row.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _RecordingScanService extends LightroomScanService {
  _RecordingScanService()
    : super(
        api: LightroomApiClient(auth: AdobeImsAuthManager()),
        mediaRepository: MediaRepository(),
        diveRepository: DiveRepository(),
        enqueueUpload: (_) {},
      );

  final confirmed = <domain.PendingPhotoSuggestion>[];

  @override
  Future<void> confirmSuggestion({
    required domain.ConnectedAccount account,
    required domain.PendingPhotoSuggestion suggestion,
  }) async {
    confirmed.add(suggestion);
  }
}

class _RecordingMediaRepository extends MediaRepository {
  final dismissed = <String>[];
  List<domain.PendingPhotoSuggestion> suggestions = [];

  @override
  Future<List<domain.PendingPhotoSuggestion>> getPendingSuggestionsForDive(
    String diveId,
  ) async => suggestions;

  @override
  Future<void> dismissPendingSuggestion(String id) async {
    dismissed.add(id);
    suggestions = [
      for (final s in suggestions)
        if (s.id != id) s,
    ];
  }
}

void main() {
  final account = domain.ConnectedAccount(
    id: 'acct1',
    kind: AccountKind.adobeLightroom,
    label: 'Eric',
    accountIdentifier: 'cat1',
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  domain.PendingPhotoSuggestion suggestion(String id) =>
      domain.PendingPhotoSuggestion(
        id: id,
        diveId: 'd1',
        platformAssetId: 'lr-$id',
        takenAt: DateTime.utc(2026, 7, 1, 12),
        createdAt: DateTime.utc(2026, 7, 2),
        connectorAccountId: 'acct1',
        remoteAssetId: 'lr-$id',
      );

  Future<(_RecordingScanService, _RecordingMediaRepository)> pump(
    WidgetTester tester, {
    required List<domain.PendingPhotoSuggestion> suggestions,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = _RecordingScanService();
    final repository = _RecordingMediaRepository()..suggestions = suggestions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          lightroomAccountProvider.overrideWith((ref) async => account),
          lightroomScanServiceProvider.overrideWithValue(service),
          mediaRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: LightroomSuggestionsRow(diveId: 'd1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (service, repository);
  }

  testWidgets('renders nothing with no suggestions', (tester) async {
    await pump(tester, suggestions: []);
    expect(find.text('Suggested from Lightroom'), findsNothing);
  });

  testWidgets('shows cards and confirms via the accept button', (tester) async {
    final (service, _) = await pump(
      tester,
      suggestions: [suggestion('s1'), suggestion('s2')],
    );
    expect(find.text('Suggested from Lightroom'), findsOneWidget);
    expect(find.byTooltip('Add to this dive'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Add to this dive').first);
    await tester.pumpAndSettle();
    expect(service.confirmed.single.id, 's1');
  });

  testWidgets('dismiss hides the card', (tester) async {
    final (_, repository) = await pump(tester, suggestions: [suggestion('s1')]);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    expect(repository.dismissed, ['s1']);
    expect(find.text('Suggested from Lightroom'), findsNothing);
  });
}
