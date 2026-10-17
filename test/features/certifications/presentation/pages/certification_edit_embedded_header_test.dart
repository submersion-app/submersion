import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The embedded editor's header: the title beside Cancel and Save. With the
/// title in Expanded, the buttons took their width first and a narrow pane
/// broke the title one character per line (#3358).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('a narrow pane moves Cancel and Save below the title', (
    tester,
  ) async {
    // The test font draws every glyph a full em wide: at 400 the title
    // (17 glyphs) and the two buttons cannot share a line, and the old
    // Expanded title was left about 110 wide, too narrow for one word.
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          certificationRepositoryProvider.overrideWithValue(
            CertificationRepository(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CertificationEditPage(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.getRect(
      // The page shows this text twice; the header's is first in the tree.
      find.text('Add Certification').first,
    );
    final save = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
    // One line for the title, and the buttons on the line below it.
    expect(title.width, greaterThan(200));
    expect(save.top, greaterThanOrEqualTo(title.bottom));
  });
}
