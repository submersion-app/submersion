import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/data/services/plan_file_names.dart';

void main() {
  group('subplanFileName', () {
    test('is the plan name with the .subplan extension', () {
      expect(subplanFileName('Blue Hole Arch'), 'Blue_Hole_Arch.subplan');
    });

    test('keeps a plan name in any script', () {
      expect(subplanFileName('Cenote Ángelita'), 'Cenote_Ángelita.subplan');
      expect(subplanFileName('沖縄 洞窟'), '沖縄_洞窟.subplan');
      expect(subplanFileName('אילת'), 'אילת.subplan');
    });

    test('falls back to dive_plan when nothing usable is left', () {
      expect(subplanFileName(''), 'dive_plan.subplan');
      expect(subplanFileName('  ?! '), 'dive_plan.subplan');
    });
  });

  group('planSlateFileName', () {
    test('adds the slate suffix', () {
      expect(planSlateFileName('Thistlegorm 30m'), 'Thistlegorm_30m_slate.pdf');
      expect(planSlateFileName('Plongée Épave'), 'Plongée_Épave_slate.pdf');
    });

    test('falls back to dive_plan when nothing usable is left', () {
      expect(planSlateFileName(''), 'dive_plan_slate.pdf');
    });
  });
}
