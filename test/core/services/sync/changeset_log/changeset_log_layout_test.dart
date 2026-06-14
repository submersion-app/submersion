import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';

void main() {
  const dev = '550e8400-e29b-41d4-a716-446655440000';

  test('names carry the prefix and the device id', () {
    expect(ChangesetLogLayout.manifestName(dev), 'ssv1.$dev.manifest.json');
    expect(
      ChangesetLogLayout.isOurs(ChangesetLogLayout.manifestName(dev)),
      isTrue,
    );
    expect(ChangesetLogLayout.isOurs('submersion_sync_$dev.json'), isFalse);
  });

  test('changeset names are zero-padded and sort by seq', () {
    final a = ChangesetLogLayout.changesetName(dev, 9);
    final b = ChangesetLogLayout.changesetName(dev, 10);
    expect(
      a.compareTo(b) < 0,
      isTrue,
      reason: 'lexical order must match seq order',
    );
    expect(ChangesetLogLayout.changesetSeqOf(a), 9);
    expect(ChangesetLogLayout.changesetSeqOf(b), 10);
  });

  test('base part names parse back to (baseSeq, part)', () {
    final n = ChangesetLogLayout.basePartName(dev, 12, 3);
    final parsed = ChangesetLogLayout.basePartOf(n);
    expect(parsed, isNotNull);
    expect(parsed!.baseSeq, 12);
    expect(parsed.part, 3);
  });

  test('classifiers distinguish file kinds', () {
    expect(
      ChangesetLogLayout.isManifest(ChangesetLogLayout.manifestName(dev)),
      isTrue,
    );
    expect(
      ChangesetLogLayout.changesetSeqOf(ChangesetLogLayout.manifestName(dev)),
      isNull,
    );
    expect(
      ChangesetLogLayout.basePartOf(ChangesetLogLayout.changesetName(dev, 1)),
      isNull,
    );
  });

  test('deviceIdOf extracts the uuid; non-ours returns null', () {
    expect(
      ChangesetLogLayout.deviceIdOf(ChangesetLogLayout.changesetName(dev, 5)),
      dev,
    );
    expect(ChangesetLogLayout.deviceIdOf('random.txt'), isNull);
  });

  test('peerDeviceIds dedupes and excludes self', () {
    const other = '11111111-1111-1111-1111-111111111111';
    final names = [
      ChangesetLogLayout.manifestName(dev),
      ChangesetLogLayout.changesetName(dev, 1),
      ChangesetLogLayout.manifestName(other),
      'unrelated.json',
    ];
    expect(ChangesetLogLayout.peerDeviceIds(names, dev), {other});
  });
}
