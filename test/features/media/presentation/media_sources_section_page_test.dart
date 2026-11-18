import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/media_sources_section_page.dart';
import 'package:submersion/features/media/presentation/pages/media_sources_section_view.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_watcher_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../support/fake_app_settings_repository.dart';

/// The Sources screen as a page of its own, opened from the Media section's
/// Sources button (#4587). It closes with `true` when a source is browsed, so
/// the Media section can show the Library it just filtered.
void main() {
  const openKey = Key('open');

  /// A button that pushes the page and records what it closes with.
  Widget host(void Function(bool? result) onResult) {
    return ProviderScope(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(
          FakeAppSettingsRepository(),
        ),
        sourceCountsProvider.overrideWith(
          (ref) async => const {MediaSourceType.platformGallery: 7},
        ),
        watchedRootsProvider.overrideWith((ref) async => const <String>[]),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: openKey,
              onPressed: () async => onResult(
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const MediaSourcesSectionPage(),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the page titles itself Sources and shows the sources view', (
    tester,
  ) async {
    await tester.pumpWidget(host((_) {}));
    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Sources')),
      findsOneWidget,
    );
    expect(find.byType(MediaSourcesSectionView), findsOneWidget);
  });

  testWidgets('browsing a source closes the page with true', (tester) async {
    final results = <bool?>[];
    await tester.pumpWidget(host(results.add));
    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ListTile, '7'));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(find.byType(MediaSourcesSectionPage), findsNothing);
  });

  testWidgets('Back closes the page with no result', (tester) async {
    final results = <bool?>[];
    await tester.pumpWidget(host(results.add));
    await tester.tap(find.byKey(openKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(results, [null]);
    expect(find.byType(MediaSourcesSectionPage), findsNothing);
  });
}
