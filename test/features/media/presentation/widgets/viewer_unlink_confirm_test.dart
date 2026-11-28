import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/presentation/editing/photo_viewer_unlink.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/viewer_unlink_confirm.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// Answers what an unlink would lose from fixed sets, or fails.
class _Repo extends MediaRepository {
  _Repo(this.atRisk, {this.fails = false});
  final Set<String> atRisk;
  final bool fails;

  @override
  Future<Set<String>> idsWithUserMetadata(List<String> mediaIds) async {
    if (fails) throw StateError('database is locked');
    return atRisk;
  }
}

class _Unlink extends MediaUnlinkService {
  _Unlink(this.atRisk)
    : super(repository: MediaRepository(), deleteMedia: (_) async {});
  final Set<String> atRisk;

  @override
  Future<Set<String>> idsWithUserMetadataAtRisk(List<String> ids) async =>
      atRisk;

  @override
  Future<Set<String>> idsWithUserMetadataAtRiskForSite(
    List<String> ids,
  ) async => atRisk;
}

/// The question the media viewer asks before it holds an Unlink (#5126).
void main() {
  final l10n = AppLocalizationsEn();

  /// Pumps a button that asks for [scope]; the answer lands in the list.
  Future<List<bool>> pump(
    WidgetTester tester,
    ViewerUnlinkScope scope, {
    Set<String> atRisk = const {},
    bool readFails = false,
  }) async {
    final answers = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaUnlinkServiceProvider.overrideWithValue(_Unlink(atRisk)),
          mediaRepositoryProvider.overrideWithValue(
            _Repo(atRisk, fails: readFails),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async => answers.add(
                  await confirmViewerUnlink(context, ref, scope, 'm1'),
                ),
                child: const Text('ask'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();
    return answers;
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('viewer_unlink_confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('a dive speaks of one item, and confirming says yes', (
    tester,
  ) async {
    final answers = await pump(tester, ViewerUnlinkScope.dive);

    expect(find.text(l10n.media_viewer_unlinkConfirmDiveBody), findsOneWidget);
    await confirm(tester);
    expect(answers, [true]);
  });

  testWidgets('a dive names a caption or favorite that would be lost', (
    tester,
  ) async {
    await pump(tester, ViewerUnlinkScope.dive, atRisk: {'m1'});

    expect(
      find.textContaining(l10n.media_library_unlinkMetadataNote(1)),
      findsOneWidget,
    );
  });

  testWidgets('a site speaks of the dive that keeps it', (tester) async {
    await pump(tester, ViewerUnlinkScope.site, atRisk: {'m1'});

    expect(
      find.textContaining(l10n.media_viewer_unlinkConfirmSiteBody),
      findsOneWidget,
    );
    expect(
      find.textContaining(l10n.media_library_unlinkMetadataNote(1)),
      findsOneWidget,
    );
  });

  testWidgets('the library asks as its own Unlink does', (tester) async {
    await pump(tester, ViewerUnlinkScope.library, atRisk: {'m1'});

    expect(find.text(l10n.media_library_unlinkConfirmTitle(1)), findsOneWidget);
    expect(
      find.textContaining(l10n.media_library_unlinkConfirmBody),
      findsOneWidget,
    );
    expect(
      find.textContaining(l10n.media_library_unlinkMetadataNote(1)),
      findsOneWidget,
    );
  });

  testWidgets('gear asks as its Remove does', (tester) async {
    await pump(tester, ViewerUnlinkScope.gear);

    expect(
      find.text(l10n.equipment_photos_removeConfirmTitle(1)),
      findsOneWidget,
    );
    // One item, and what keeps it: a dive or a dive site.
    expect(find.text(l10n.media_viewer_unlinkConfirmGearBody), findsOneWidget);
    expect(find.text(l10n.equipment_photos_remove), findsOneWidget);
  });

  testWidgets('a failed read still asks, without the note', (tester) async {
    final answers = await pump(
      tester,
      ViewerUnlinkScope.library,
      readFails: true,
    );

    expect(find.text(l10n.media_library_unlinkConfirmBody), findsOneWidget);
    await confirm(tester);
    expect(answers, [true]);
  });

  testWidgets('cancelling says no', (tester) async {
    final answers = await pump(tester, ViewerUnlinkScope.dive);

    await tester.tap(find.text(l10n.common_action_cancel));
    await tester.pumpAndSettle();

    expect(answers, [false]);
  });
}
