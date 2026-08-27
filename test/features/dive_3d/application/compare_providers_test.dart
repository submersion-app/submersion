import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/compare_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';

DiveProfilePoint pt(int t, double d) =>
    DiveProfilePoint(timestamp: t, depth: d);

DiveDataSource source(
  String id, {
  required bool primary,
  required String model,
}) => DiveDataSource(
  id: id,
  diveId: 'd1',
  isPrimary: primary,
  computerModel: model,
  importedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
);

SourceProfile sp(String id, List<DiveProfilePoint> points) => SourceProfile(
  sourceId: id,
  computerId: null,
  isEdited: false,
  points: points,
);

void main() {
  test('builds one profile per source, primary as reference index 0', () async {
    final container = ProviderContainer(
      overrides: [
        diveDataSourcesProvider('d1').overrideWith(
          (ref) async => [
            source('srcSecondary', primary: false, model: 'Teric'),
            source('srcPrimary', primary: true, model: 'Perdix'),
          ],
        ),
        sourceProfilesProvider('d1').overrideWith(
          (ref) async => {
            'srcPrimary': sp('srcPrimary', [pt(0, 0), pt(60, 30), pt(120, 0)]),
            'srcSecondary': sp('srcSecondary', [
              pt(0, 0),
              pt(60, 31),
              pt(120, 0),
            ]),
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final profiles = await container.read(
      computerComparisonProfilesProvider('d1').future,
    );

    expect(profiles, hasLength(2));
    // Primary first -> reference index 0.
    expect(profiles.first.id, 'srcPrimary');
    expect(profiles.first.label, 'Perdix');
    expect(profiles.first.color, sourceColorAt(0));
    expect(profiles.first.times, [0, 60, 120]);
    expect(profiles.first.depths, [0, 30, 0]);
    expect(profiles[1].id, 'srcSecondary');
  });

  test('skips sources without a usable profile', () async {
    final container = ProviderContainer(
      overrides: [
        diveDataSourcesProvider('d1').overrideWith(
          (ref) async => [
            source('srcPrimary', primary: true, model: 'Perdix'),
            source('srcMeta', primary: false, model: 'MetaOnly'),
          ],
        ),
        sourceProfilesProvider('d1').overrideWith(
          (ref) async => {
            'srcPrimary': sp('srcPrimary', [pt(0, 0), pt(60, 30)]),
            'srcMeta': sp('srcMeta', [pt(0, 0)]), // < 2 points
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final profiles = await container.read(
      computerComparisonProfilesProvider('d1').future,
    );
    expect(profiles, hasLength(1));
    expect(profiles.single.id, 'srcPrimary');
  });

  test('DiveIdSet equality is by ordered contents', () {
    expect(DiveIdSet(['a', 'b']), DiveIdSet(['a', 'b']));
    expect(DiveIdSet(['a', 'b']).hashCode, DiveIdSet(['a', 'b']).hashCode);
    expect(DiveIdSet(['a', 'b']) == DiveIdSet(['b', 'a']), isFalse);
  });

  test(
    'dives adapter: first dive is reference; no-profile dives skipped',
    () async {
      final container = ProviderContainer(
        overrides: [
          sourceProfilesProvider('a').overrideWith(
            (ref) async => {
              's1': sp('s1', [pt(0, 0), pt(60, 20), pt(120, 0)]),
            },
          ),
          sourceProfilesProvider('b').overrideWith(
            (ref) async => {
              's2': sp('s2', [pt(0, 0), pt(60, 25), pt(120, 0)]),
            },
          ),
          sourceProfilesProvider('c').overrideWith(
            (ref) async => {
              's3': sp('s3', [pt(0, 0)]),
            }, // < 2 -> skipped
          ),
          diveProvider('a').overrideWith((ref) async => null),
          diveProvider('b').overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      final profiles = await container.read(
        diveComparisonProfilesProvider(DiveIdSet(['a', 'b', 'c'])).future,
      );
      expect(profiles, hasLength(2));
      expect(profiles.first.id, 'a'); // reference index 0
      expect(profiles[1].id, 'b');
      expect(profiles.first.color, sourceColorAt(0));
    },
  );
}
