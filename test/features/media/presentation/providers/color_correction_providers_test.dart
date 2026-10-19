import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/color_correction_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

MediaItem item({ColorAdjustment? adjustment}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026, 7, 1),
  colorAdjustment: adjustment,
);

void main() {
  test('a draft wins over the stored adjustment until it is cleared', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    const draft = ColorAdjustment(warmth: 0.5);

    expect(container.read(colorAdjustmentDraftNotifierProvider('m1')), isNull);
    container
        .read(colorAdjustmentDraftNotifierProvider('m1').notifier)
        .set(draft);
    expect(container.read(colorAdjustmentDraftNotifierProvider('m1')), draft);
    expect(container.read(colorAdjustmentDraftNotifierProvider('m2')), isNull);
    container.read(colorAdjustmentDraftNotifierProvider('m1').notifier).clear();
    expect(container.read(colorAdjustmentDraftNotifierProvider('m1')), isNull);
  });

  test('peek holds one item and releases it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(colorPeekOriginalNotifierProvider.notifier).peek('m1');
    expect(container.read(colorPeekOriginalNotifierProvider), 'm1');
    container.read(colorPeekOriginalNotifierProvider.notifier).release();
    expect(container.read(colorPeekOriginalNotifierProvider), isNull);
  });

  test('the diver switch follows the settings', () {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(
            const AppSettings(autoColorCorrection: true),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(diverAutoColorCorrectionProvider), isTrue);
  });

  test('colorStatsKey survives an edit but not a relink', () {
    final a = item();
    // Saving an adjustment bumps updatedAt; the pixels are the same.
    expect(
      colorStatsKey(a),
      colorStatsKey(
        a.copyWith(
          updatedAt: DateTime.utc(2026, 8),
          colorAdjustment: const ColorAdjustment(warmth: 1),
        ),
      ),
    );
    expect(
      colorStatsKey(a),
      isNot(colorStatsKey(a.copyWith(localPath: '/elsewhere/reef.jpg'))),
    );
    expect(
      colorStatsKey(a),
      isNot(colorStatsKey(a.copyWith(platformAssetId: 'asset-2'))),
    );
    // A repair or re-upload can replace the pixels at the same path.
    expect(
      colorStatsKey(a.copyWith(contentHash: 'sha-1')),
      isNot(colorStatsKey(a.copyWith(contentHash: 'sha-2'))),
    );
    // A feed pointing the same row at a new image.
    expect(
      colorStatsKey(a.copyWith(url: 'https://example.invalid/a.jpg')),
      isNot(colorStatsKey(a.copyWith(url: 'https://example.invalid/b.jpg'))),
    );
  });

  testWidgets('effectiveAdjustment prefers the draft', (tester) async {
    const stored = ColorAdjustment(tint: 0.2);
    const draft = ColorAdjustment(warmth: 0.6);
    final seen = <ColorAdjustment?>[];
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            seen.add(effectiveAdjustment(ref, item(adjustment: stored)));
            return const SizedBox();
          },
        ),
      ),
    );
    expect(seen.last, stored);
    widgetRef
        .read(colorAdjustmentDraftNotifierProvider('m1').notifier)
        .set(draft);
    await tester.pump();
    expect(seen.last, draft);
  });
}
