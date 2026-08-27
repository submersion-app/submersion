import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_panel.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_sheet.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';

MediaItem _item() => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  platformAssetId: 'asset-1',
  originalFilename: 'reef.jpg',
  takenAt: DateTime(2026, 3, 12),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
);

void main() {
  late String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  testWidgets('the launcher opens a panel for the given item', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaStoreAttachedProvider.overrideWith((ref) async => false),
          mediaQueueFactsProvider.overrideWith((ref, id) => Stream.value(null)),
          mediaStoreIdentityProvider.overrideWith((ref) async => null),
          currentDeviceIdProvider.overrideWith((ref) async => 'dev-a'),
          mediaServingRecorderProvider.overrideWithValue(
            MediaServingRecorder(),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMediaInfoSheet(context, _item()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MediaInfoPanel), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(MediaInfoPanel), findsOneWidget);
    expect(find.text('reef.jpg'), findsOneWidget);
    // The panel is hosted in a draggable sheet, which owns the scrolling.
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
  });
}
