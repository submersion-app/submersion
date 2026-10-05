import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';

import '../../../helpers/two_device_media_harness.dart';

/// Issue #1039: category and size override travel with the media row to the
/// other device.
void main() {
  late TwoDeviceMediaHarness h;
  final bytes = List<int>.generate(512, (i) => (i * 7) % 251);

  setUp(() async => h = await TwoDeviceMediaHarness.create());
  tearDown(() => h.dispose());

  test('an edit on A arrives on B', () async {
    final dive = await h.a.createDive();
    final id = await h.a.linkFile(bytes, diveId: dive, name: 'map.jpg');
    await h.a.sync();
    await h.b.sync();

    await h.a.activate();
    await SiteAttachmentRepository().setAttachmentDetails(
      id,
      const AttachmentDetailsEdit(
        category: FieldChange(SiteAttachmentCategory.siteMap),
        displaySize: FieldChange(AttachmentDisplaySize.tile),
      ),
    );
    await h.a.sync();
    await h.b.sync();

    final onB = (await h.b.media(id))!;
    expect(onB.originalFilename, 'map.jpg');
    expect(onB.siteCategory, SiteAttachmentCategory.siteMap);
    expect(onB.displaySizeOverride, AttachmentDisplaySize.tile);
  });
}
