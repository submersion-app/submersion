import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_import_link_page.dart';
import 'package:submersion/features/media/presentation/pages/media_import_view.dart';
import 'package:submersion/features/media/presentation/providers/media_inbox_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host({Future<List<String>> Function(BuildContext)? launchOverride}) {
    return ProviderScope(
      overrides: [
        // The pushed link page resolves these per id; keep them inert.
        for (final id in ['m1', 'm2']) ...[
          mediaByIdProvider(id).overrideWith((ref) async => null),
          inboxSuggestionProvider(id).overrideWith(
            (ref) async => const InboxSuggestion(
              match: TimestampMatch(kind: TimestampMatchKind.none),
            ),
          ),
        ],
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MediaImportView(launchOverride: launchOverride)),
      ),
    );
  }

  testWidgets('renders intro and launch button', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Imported media is kept in your library and can be linked to '
        'dives automatically.',
      ),
      findsOneWidget,
    );
    expect(find.text('Import media...'), findsOneWidget);
  });

  testWidgets('a non-empty import pushes the link page with the ids', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(launchOverride: (context) async => ['m1', 'm2']),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import media...'));
    await tester.pumpAndSettle();

    final page = tester.widget<MediaImportLinkPage>(
      find.byType(MediaImportLinkPage),
    );
    expect(page.mediaIds, ['m1', 'm2']);
  });

  test('the library import window has no effective lower bound', () {
    // A dive-less import must offer the whole gallery. The mobile picker
    // turns this bound into a hard photo_manager createTimeCond, so any
    // "recent enough" sentinel silently hides older assets -- scanned film
    // and slide libraries, which is exactly the media divers back-fill.
    expect(
      MediaImportView.libraryWindowStart.millisecondsSinceEpoch,
      lessThanOrEqualTo(0),
    );
  });

  testWidgets('an empty import stays on the view', (tester) async {
    await tester.pumpWidget(host(launchOverride: (context) async => []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import media...'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaImportLinkPage), findsNothing);
  });
}
