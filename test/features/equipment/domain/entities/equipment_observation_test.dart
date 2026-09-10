import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

void main() {
  test('status round-trips and unknown falls back to ok', () {
    expect(ObservationStatus.issue.dbValue, 'issue');
    expect(ObservationStatus.fromDbValue('issue'), ObservationStatus.issue);
    expect(ObservationStatus.fromDbValue('bogus'), ObservationStatus.ok);
  });

  test('tags round-trip and unknown names are dropped', () {
    expect(ObservationTag.freeFlow.dbValue, 'freeFlow');
    expect(ObservationTag.fromDbValue('leakZip'), ObservationTag.leakZip);
    expect(ObservationTag.fromDbValue('nope'), isNull);
    final json = encodeObservationTags([
      ObservationTag.freeFlow,
      ObservationTag.other,
    ]);
    expect(json, '["freeFlow","other"]');
    expect(decodeObservationTags(json), [
      ObservationTag.freeFlow,
      ObservationTag.other,
    ]);
    expect(decodeObservationTags('["freeFlow","nope"]'), [
      ObservationTag.freeFlow,
    ]);
    expect(decodeObservationTags('[]'), isEmpty);
    expect(decodeObservationTags(''), isEmpty);
    expect(decodeObservationTags('garbage'), isEmpty);
  });

  test('entity is a value object with clearDiveId', () {
    final a = EquipmentObservation(
      id: 'o1',
      equipmentId: 'e1',
      diveId: 'd1',
      observedAt: DateTime.utc(2026, 9, 9, 15),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.freeFlow],
      note: 'Free flow at 30 m',
      createdAt: DateTime.utc(2026, 9, 9, 16),
      updatedAt: DateTime.utc(2026, 9, 9, 16),
    );
    expect(a.isIssue, isTrue);
    expect(a.copyWith(clearDiveId: true).diveId, isNull);
    expect(a.copyWith(status: ObservationStatus.ok).isIssue, isFalse);
    expect(a, a.copyWith());
  });
}
