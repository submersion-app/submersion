import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('DiveSite.isShared', () {
    test('defaults to false', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      expect(site.isShared, isFalse);
    });

    test('copyWith sets isShared', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      final shared = site.copyWith(isShared: true);
      expect(shared.isShared, isTrue);
      expect(site.isShared, isFalse);
    });

    test('props include isShared', () {
      const site = DiveSite(id: 's1', name: 'Reef');
      expect(site == site.copyWith(isShared: true), isFalse);
    });
  });
}
