import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/equipment/presentation/providers/gear_photo_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/check_in_photos_row.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

import '../../../media/presentation/support/media_widget_harness.dart';

class _RecordingUnlink extends MediaUnlinkService {
  _RecordingUnlink(this.calls)
    : super(repository: MediaRepository(), deleteMedia: (_) async {});

  final List<List<String>> calls;

  @override
  Future<EquipmentUnlinkOutcome> unlinkFromEquipment(
    List<String> mediaIds,
  ) async {
    calls.add(mediaIds);
    return EquipmentUnlinkOutcome(deleted: mediaIds.length, keptLinked: 0);
  }
}

/// The check-in editor's photos (issue #3355).
void main() {
  final photo = testMediaItem(
    id: 'm1',
  ).copyWith(equipmentId: 'reg-1', observationId: 'obs-1');

  Future<Widget> host({
    List<MediaItem> photos = const [],
    List<List<String>>? calls,
    DeviceCapabilities? capabilities,
  }) => mediaTestApp(
    overrides: [
      observationPhotosProvider('obs-1').overrideWith((ref) async => photos),
      if (calls != null)
        mediaUnlinkServiceProvider.overrideWithValue(_RecordingUnlink(calls)),
      if (capabilities != null)
        deviceCapabilitiesProvider.overrideWithValue(capabilities),
    ],
    home: const Scaffold(
      body: CheckInPhotosRow(equipmentId: 'reg-1', observationId: 'obs-1'),
    ),
  );

  testWidgets('the remove control is small, not most of the tile', (
    tester,
  ) async {
    await tester.pumpWidget(await host(photos: [photo]));
    await tester.pumpAndSettle();

    final size = tester.getSize(
      find.byKey(const ValueKey('remove_checkin_photo_m1')),
    );
    expect(size.width, lessThanOrEqualTo(28));
    expect(size.height, lessThanOrEqualTo(28));
  });

  testWidgets('remove asks first and unlinks only when confirmed', (
    tester,
  ) async {
    final calls = <List<String>>[];
    await tester.pumpWidget(await host(photos: [photo], calls: calls));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('remove_checkin_photo_m1')));
    await tester.pumpAndSettle();
    expect(find.text('Remove 1 photo?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('remove_checkin_photo_m1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(calls, [
      ['m1'],
    ]);
  });

  testWidgets('no photos and no attach shows nothing', (tester) async {
    await tester.pumpWidget(await host(capabilities: DeviceCapabilities.web));
    await tester.pumpAndSettle();

    expect(find.text('Photos'), findsNothing);
  });
}
