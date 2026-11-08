import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/dive_consolidation_builder.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/consolidation_preview_cache.dart';

void main() {
  final t = DateTime.utc(2026, 7, 1, 9);
  Dive dive(String id, int minutes, String serial) => Dive(
    id: id,
    diverId: 'diver1',
    dateTime: t.add(Duration(minutes: minutes)),
    entryTime: t.add(Duration(minutes: minutes)),
    runtime: const Duration(minutes: 30),
    diveComputerSerial: serial,
  );

  group('ConsolidationPreviewCache', () {
    final cache = ConsolidationPreviewCache([
      dive('a', 0, 'A'),
      dive('b', 5, 'B'),
    ]);
    const fit = ConsolidationAlignment.bestFit;

    test('keeps the classification and plan while the inputs hold', () {
      final first = cache.classification(primaryId: null, alignment: fit);
      expect(
        cache.classification(primaryId: null, alignment: fit),
        same(first),
      );
      final plan = cache.plan(primaryId: null, alignment: fit);
      expect(cache.plan(primaryId: null, alignment: fit), same(plan));
    });

    test('rebuilds both when the primary or the alignment changes', () {
      final first = cache.classification(primaryId: null, alignment: fit);
      final fromB = cache.classification(primaryId: 'b', alignment: fit);
      expect(fromB, isNot(same(first)));
      expect((fromB as ConsolidationReady).primary.id, 'b');

      final plan = cache.plan(primaryId: 'b', alignment: fit);
      final starts = cache.plan(
        primaryId: 'b',
        alignment: ConsolidationAlignment.starts,
      );
      expect(starts, isNot(same(plan)));
    });
  });
}
