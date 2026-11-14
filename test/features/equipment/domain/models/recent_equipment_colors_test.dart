import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/models/recent_equipment_colors.dart';

/// The diver's remembered custom colours (issue #4537): a JSON list on the
/// settings row that any peer can write, so reading it never trusts it.
void main() {
  List<String> codes(int n) => [
    for (var i = 0; i < n; i++) '#0000${i.toString().padLeft(2, '0')}',
  ];

  group('decodeRecentEquipmentColors', () {
    test('reads nothing from null, empty or malformed values', () {
      expect(decodeRecentEquipmentColors(null), isEmpty);
      expect(decodeRecentEquipmentColors(''), isEmpty);
      expect(decodeRecentEquipmentColors('not json'), isEmpty);
      expect(decodeRecentEquipmentColors('{"a": 1}'), isEmpty);
    });

    test('keeps the valid part of a malformed list, normalised', () {
      expect(
        decodeRecentEquipmentColors(
          '["red", "#12345", 7, null, "#ff6a00", "#FF6A00", "#F97316"]',
        ),
        ['#FF6A00'],
      );
    });

    test('caps at $rememberedEquipmentColorCap', () {
      expect(
        decodeRecentEquipmentColors(encodeRecentEquipmentColors(codes(10))),
        codes(10).take(rememberedEquipmentColorCap).toList(),
      );
    });

    test('round trips through encode', () {
      final list = ['#FF6A00', '#0A3D91'];
      expect(
        decodeRecentEquipmentColors(encodeRecentEquipmentColors(list)),
        list,
      );
    });
  });

  group('rememberEquipmentColor', () {
    test('puts a new code first and drops the oldest past the cap', () {
      final eight = codes(8);
      expect(rememberEquipmentColor(eight, '#abcdef'), [
        '#ABCDEF',
        ...eight.take(7),
      ]);
    });

    test('moves a code already there to the front without repeating it', () {
      final eight = codes(8);
      final result = rememberEquipmentColor(eight, '#000003');
      expect(result.first, '#000003');
      expect(result, hasLength(8));
      expect(result.where((c) => c == '#000003'), hasLength(1));
    });

    test('never remembers a palette colour or an invalid code', () {
      expect(rememberEquipmentColor(const ['#123456'], '#f97316'), ['#123456']);
      expect(rememberEquipmentColor(const ['#123456'], 'red'), ['#123456']);
    });
  });

  group('recentEquipmentColorRow', () {
    test('orders the current colour, the remembered, then the gear', () {
      expect(
        recentEquipmentColorRow(
          current: '#abcdef',
          remembered: const ['#111111', '#ABCDEF'],
          gear: const ['#222222', '#111111', '#F97316'],
        ),
        ['#ABCDEF', '#111111', '#222222'],
      );
    });

    test('a palette or missing current colour adds nothing', () {
      for (final current in ['#F97316', null, 'Red']) {
        expect(
          recentEquipmentColorRow(
            current: current,
            remembered: const ['#111111'],
            gear: const [],
          ),
          ['#111111'],
          reason: '$current',
        );
      }
    });

    test('caps at $recentEquipmentColorRowCap', () {
      expect(
        recentEquipmentColorRow(remembered: codes(8), gear: codes(20)),
        codes(recentEquipmentColorRowCap),
      );
    });

    test('is empty with nothing to offer', () {
      expect(
        recentEquipmentColorRow(remembered: const [], gear: const []),
        isEmpty,
      );
    });
  });
}
