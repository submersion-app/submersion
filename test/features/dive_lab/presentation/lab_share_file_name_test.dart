import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/presentation/lab_share.dart';

void main() {
  test('labSafeFileName keeps letters and digits of any script', () {
    expect(labSafeFileName('214_Lost deco'), '214_Lost_deco');
    expect(
      labSafeFileName('Verlust Dekogas über 30 m'),
      'Verlust_Dekogas_über_30_m',
    );
    expect(labSafeFileName('מה אם'), 'מה_אם');
    expect(labSafeFileName('如果当时'), '如果当时');
  });

  test('labSafeFileName replaces path and punctuation characters', () {
    expect(labSafeFileName('a/b:c*d?e'), 'a_b_c_d_e');
    expect(labSafeFileName('   '), 'scenario');
    expect(labSafeFileName(''), 'scenario');
  });
}
