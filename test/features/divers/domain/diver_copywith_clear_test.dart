import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  Diver populated() => Diver(
    id: 'd1',
    name: 'Alice',
    email: 'a@b.com',
    phone: '+1',
    photoPath: '/p.png',
    bloodType: 'O+',
    allergies: 'none',
    medications: 'none',
    medicalClearanceExpiryDate: DateTime(2027),
    createdAt: now,
    updatedAt: now,
    priorDiveCount: 100,
    priorDiveTimeSeconds: 3600,
    divingSince: DateTime(2008),
  );

  group('copyWith omitting a nullable field preserves it', () {
    test('unrelated update keeps every nullable field', () {
      final d = populated().copyWith(name: 'Bob');
      expect(d.email, 'a@b.com');
      expect(d.phone, '+1');
      expect(d.photoPath, '/p.png');
      expect(d.bloodType, 'O+');
      expect(d.allergies, 'none');
      expect(d.medications, 'none');
      expect(d.medicalClearanceExpiryDate, DateTime(2027));
      expect(d.priorDiveCount, 100);
      expect(d.priorDiveTimeSeconds, 3600);
      expect(d.divingSince, DateTime(2008));
    });
  });

  group('copyWith passing null clears the field', () {
    test('clears contact + medical scalars', () {
      final d = populated().copyWith(
        email: null,
        phone: null,
        photoPath: null,
        bloodType: null,
        allergies: null,
        medications: null,
        medicalClearanceExpiryDate: null,
      );
      expect(d.email, isNull);
      expect(d.phone, isNull);
      expect(d.photoPath, isNull);
      expect(d.bloodType, isNull);
      expect(d.allergies, isNull);
      expect(d.medications, isNull);
      expect(d.medicalClearanceExpiryDate, isNull);
      // Untouched fields remain.
      expect(d.priorDiveCount, 100);
    });

    test('clears prior-experience fields', () {
      final d = populated().copyWith(
        priorDiveCount: null,
        priorDiveTimeSeconds: null,
        divingSince: null,
      );
      expect(d.priorDiveCount, isNull);
      expect(d.priorDiveTimeSeconds, isNull);
      expect(d.divingSince, isNull);
      // Untouched fields remain.
      expect(d.email, 'a@b.com');
      expect(d.bloodType, 'O+');
    });
  });

  group('copyWith passing a value sets the field', () {
    test('overwrites existing values', () {
      final d = populated().copyWith(
        email: 'new@x.com',
        priorDiveCount: 250,
        divingSince: DateTime(1999),
      );
      expect(d.email, 'new@x.com');
      expect(d.priorDiveCount, 250);
      expect(d.divingSince, DateTime(1999));
    });
  });

  group('copyWith asserts the runtime type of sentinel params (debug)', () {
    test('wrong type for a String? field throws AssertionError', () {
      // Object? params accept anything at compile time; the debug assert
      // catches a type mismatch that the old typed signature would have
      // rejected at compile time.
      expect(
        () => populated().copyWith(email: 123),
        throwsA(isA<AssertionError>()),
      );
    });

    test('wrong type for an int? field throws AssertionError', () {
      expect(
        () => populated().copyWith(priorDiveCount: 'lots'),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
