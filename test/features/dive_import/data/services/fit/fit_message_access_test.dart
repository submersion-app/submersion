import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_constants.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_message_access.dart';

/// Builds a synthetic [GenericMessage] (an unnamed FIT message, the way fit_tool
/// reconstructs any message it has no named profile for) with the given fields.
DataMessage buildGeneric(
  int globalId,
  List<({int id, BaseType type, int size, num value})> fields,
) {
  final def = DefinitionMessage(
    globalId: globalId,
    fieldDefinitions: fields
        .map((f) => FieldDefinition(id: f.id, size: f.size, type: f.type))
        .toList(),
  );
  final msg = GenericMessage(definitionMessage: def);
  for (final f in fields) {
    msg.getField(f.id)!.setValue(0, f.value, null);
  }
  return msg;
}

void main() {
  test(
    'rawNum reads a field by number from a GenericMessage (tank_update)',
    () {
      // tank_update (msg 319): field 0=sensor, 1=pressure(raw), 253=timestamp.
      final msg = buildGeneric(FitConstants.tankUpdateMsg, const [
        (id: 253, type: BaseType.UINT32, size: 4, value: 1126250405),
        (id: 0, type: BaseType.UINT32, size: 4, value: 2772884913),
        (id: 1, type: BaseType.UINT16, size: 2, value: 22125),
      ]);

      expect(msg.globalId, FitConstants.tankUpdateMsg);
      expect(FitMessageAccess.rawNum(msg, 1), 22125);
      expect(FitMessageAccess.rawNum(msg, 0), 2772884913);
      expect(FitMessageAccess.rawNum(msg, 99), isNull);
    },
  );

  test('messagesWithGlobalId filters by FIT global message number', () {
    final tank = buildGeneric(FitConstants.tankSummaryMsg, const [
      (id: 0, type: BaseType.UINT32, size: 4, value: 100),
    ]);
    final other = buildGeneric(999, const [
      (id: 0, type: BaseType.UINT16, size: 2, value: 1),
    ]);

    final result = FitMessageAccess.messagesWithGlobalId(<Message>[
      tank,
      other,
    ], FitConstants.tankSummaryMsg);

    expect(result, hasLength(1));
    expect(result.first.globalId, FitConstants.tankSummaryMsg);
  });
}
