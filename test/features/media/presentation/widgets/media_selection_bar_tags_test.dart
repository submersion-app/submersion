import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/widgets/media_selection_bar.dart';
import 'package:submersion/features/tags/presentation/widgets/bulk_tag_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The library selection bar offers Edit tags (issue #1970), ahead of the
/// destructive Unlink.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('Edit tags sits before Unlink and opens the bulk tag sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final item = MediaItem(
      id: 'm1',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime(2026),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final controller = SelectionController()
      ..enterExplicit()
      ..toggle('m1');
    addTearDown(controller.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: MediaSelectionBar(
                controller: controller,
                selectableIds: const ['m1'],
                selectedItems: [item],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('selection_overflow')));
    await tester.pumpAndSettle();

    final editTags = find.byKey(const ValueKey('selection_menu_edit_tags'));
    final unlink = find.byKey(const ValueKey('selection_menu_unlink'));
    expect(editTags, findsOneWidget);
    expect(
      tester.getTopLeft(editTags).dy,
      lessThan(tester.getTopLeft(unlink).dy),
    );

    await tester.tap(editTags);
    await tester.pumpAndSettle();
    expect(find.byType(BulkTagSheet), findsOneWidget);
  });
}
