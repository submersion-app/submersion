import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/widgets/media_selection_bar.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Media is read-only in a browser (issue #4121): the library's selection
/// bar keeps Share and drops every action that changes a link or a tag.
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  final en = lookupAppLocalizations(const Locale('en'));

  Future<void> pump(WidgetTester tester, {bool browser = false}) async {
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
        overrides: [
          ...overrides,
          if (browser)
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
        ],
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
  }

  testWidgets('natively the bar carries the write actions', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('selection_overflow')), findsOneWidget);
  });

  testWidgets('a browser keeps Share and nothing that writes', (tester) async {
    await pump(tester, browser: true);
    expect(find.byTooltip(en.common_action_share), findsOneWidget);
    expect(find.byKey(const ValueKey('selection_overflow')), findsNothing);
    expect(find.text(en.media_library_unlinkSelected), findsNothing);
    expect(find.text(en.tags_action_edit), findsNothing);
    expect(find.text(en.media_library_moveToDive), findsNothing);
  });
}
