import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

void main() {
  final now = DateTime(2024, 1, 1);

  Certification make() => Certification(
    id: 'cert-1',
    name: 'Rescue Diver',
    agency: CertificationAgency.padi,
    instructorName: 'Jane Instructor',
    instructorNumber: '12345',
    instructorId: 'buddy-1',
    createdAt: now,
    updatedAt: now,
  );

  test('clearPhotos preserves the instructor link and snapshot', () {
    final cleared = make().clearPhotos(clearFront: true, clearBack: true);
    expect(cleared.instructorId, 'buddy-1');
    expect(cleared.instructorName, 'Jane Instructor');
    expect(cleared.instructorNumber, '12345');
  });

  test('instructorId participates in value equality', () {
    expect(make(), make());
    expect(make().copyWith(instructorId: 'buddy-2'), isNot(make()));
  });
}
