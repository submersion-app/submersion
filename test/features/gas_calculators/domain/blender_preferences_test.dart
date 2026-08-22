import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';

void main() {
  group('MixTemplate', () {
    test('labels a mix the way a blender says it', () {
      expect(const MixTemplate(o2: 10, he: 70).label, '10/70');
      expect(const MixTemplate(o2: 7.5, he: 75).label, '7.5/75');
    });

    test('round-trips through JSON', () {
      const t = MixTemplate(o2: 12, he: 60);
      expect(MixTemplate.fromJson(t.toJson()), t);
    });
  });

  group('BlenderPreferences.defaults', () {
    test('seeds the five templates named in issue #1100', () {
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12);
      expect(prefs.templates.map((t) => t.label).toList(), [
        '7/75',
        '10/70',
        '12/60',
        '15/55',
        '18/35',
      ]);
    });

    test('starts unpriced at the reference temperature', () {
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12);
      expect(prefs.gasPrices, [null, null, null]);
      expect(prefs.currencyCode, isNull);
      expect(prefs.fillTempC, kReferenceTempC);
      expect(prefs.settledTempC, kReferenceTempC);
      expect(prefs.cylinderWaterLiters, 12);
      expect(prefs.model, BlendGasModel.zFactor);
    });
  });

  group('JSON', () {
    test('round-trips a fully populated value', () {
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12)
          .copyWith(
            templates: const [MixTemplate(o2: 21, he: 35)],
            gasPrices: const [2.55, 7.99, 0.01],
            currencyCode: 'CHF',
            fillTempC: 5,
            settledTempC: 25,
            cylinderWaterLiters: 3,
            model: BlendGasModel.vanDerWaals,
          );
      final decoded = BlenderPreferences.fromJson(
        jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.templates, prefs.templates);
      expect(decoded.gasPrices, prefs.gasPrices);
      expect(decoded.currencyCode, 'CHF');
      expect(decoded.fillTempC, 5);
      expect(decoded.settledTempC, 25);
      expect(decoded.cylinderWaterLiters, 3);
      expect(decoded.model, BlendGasModel.vanDerWaals);
    });

    test('an emptied template list survives the round trip', () {
      final prefs = BlenderPreferences.defaults(
        cylinderWaterLiters: 12,
      ).copyWith(templates: const []);
      final decoded = BlenderPreferences.fromJson(prefs.toJson());
      expect(decoded.templates, isEmpty);
    });

    test('a malformed field falls back without discarding the rest', () {
      final decoded = BlenderPreferences.fromJson({
        'templates': 'not a list',
        'gasPrices': [2.55, 'nope', null],
        'currencyCode': 'CHF',
        'fillTempC': 'cold',
        'model': 'newtonian',
      });
      expect(decoded.templates, isEmpty);
      expect(decoded.gasPrices, [2.55, null, null]);
      expect(decoded.currencyCode, 'CHF');
      expect(decoded.fillTempC, kReferenceTempC);
      expect(decoded.model, BlendGasModel.zFactor);
    });

    test('an impossible template is dropped on read', () {
      final decoded = BlenderPreferences.fromJson({
        'templates': [
          {'o2': 10, 'he': 70},
          {'o2': 60, 'he': 70},
          {'o2': -1, 'he': 10},
        ],
      });
      expect(decoded.templates.map((t) => t.label).toList(), ['10/70']);
    });

    test('templates are capped', () {
      final many = List.generate(
        BlenderPreferences.maxTemplates + 10,
        (i) => MixTemplate(o2: 10 + i * 0.1, he: 50),
      );
      final capped = BlenderPreferences.defaults(
        cylinderWaterLiters: 12,
      ).copyWith(templates: many);
      expect(capped.templates, hasLength(BlenderPreferences.maxTemplates));
    });
  });
  group('copyWith', () {
    test('can clear the currency back to the diver default', () {
      // Raised in review on PR #1215. Null is meaningful here (inherit the
      // diver's setting), so a plain `?? this.currencyCode` could never
      // express it.
      final prefs = BlenderPreferences.defaults(
        cylinderWaterLiters: 12,
      ).copyWith(currencyCode: 'CHF');
      expect(prefs.currencyCode, 'CHF');
      expect(prefs.copyWith(clearCurrencyCode: true).currencyCode, isNull);
    });

    test('leaves the currency alone when it is not named', () {
      final prefs = BlenderPreferences.defaults(
        cylinderWaterLiters: 12,
      ).copyWith(currencyCode: 'CHF');
      expect(prefs.copyWith(fillTempC: 5).currencyCode, 'CHF');
    });
  });

  group('rejectionFor', () {
    test('accepts a fresh, valid mix', () {
      expect(rejectionFor(const [], const MixTemplate(o2: 18, he: 45)), isNull);
    });

    test('names an impossible mix', () {
      expect(
        rejectionFor(const [], const MixTemplate(o2: 60, he: 70)),
        MixTemplateRejection.invalid,
      );
    });

    test('names a duplicate', () {
      expect(
        rejectionFor(const [
          MixTemplate(o2: 10, he: 70),
        ], const MixTemplate(o2: 10, he: 70)),
        MixTemplateRejection.duplicate,
      );
    });

    test('names the cap', () {
      final full = List.generate(
        BlenderPreferences.maxTemplates,
        (i) => MixTemplate(o2: 10 + i * 0.1, he: 50),
      );
      expect(
        rejectionFor(full, const MixTemplate(o2: 18, he: 45)),
        MixTemplateRejection.limitReached,
      );
    });
  });
}
