import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/domain/blending/equation_of_state.dart';
import 'package:submersion/features/gas_calculators/domain/blending/flush_fee.dart';

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
      expect(prefs.fillTempC, kReferenceTempC);
      expect(prefs.settledTempC, kReferenceTempC);
      expect(prefs.cylinderWaterLiters, 12);
      expect(prefs.model, BlendGasModel.zFactor);
    });

    test('matches the state providers hard-coded defaults', () {
      // gas_blender_providers.dart seeds blenderStartPressureProvider et al
      // with these exact values. A mismatch here means a first run and a
      // loaded-from-blob run would disagree on where the calculator starts.
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12);
      expect(prefs.startPressureBar, 0.0);
      expect(prefs.startMix, const GasMix(o2: 21));
      expect(prefs.targetPressureBar, 200.0);
      expect(prefs.targetMix, const GasMix(o2: 32));
      expect(prefs.topupO2Percent, 21.0);
      expect(prefs.fillOrder, kDefaultBlenderFillOrder);
    });

    test('the flush fee starts off, once per bill, unpriced', () {
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12);
      expect(prefs.flushFeeEnabled, isFalse);
      expect(prefs.flushFeeMode, FlushFeeMode.perInvoice);
      expect(prefs.flushFeeGases, hasLength(3));
      expect(prefs.gasPrices, everyElement(isNull));
    });
  });

  group('JSON', () {
    test('round-trips a fully populated value', () {
      final prefs = BlenderPreferences.defaults(cylinderWaterLiters: 12)
          .copyWith(
            templates: const [MixTemplate(o2: 21, he: 35)],
            gasPrices: const [2.55, 7.99, 0.01],
            fillTempC: 5,
            settledTempC: 25,
            cylinderWaterLiters: 3,
            model: BlendGasModel.vanDerWaals,
            startPressureBar: 40,
            startMix: const GasMix(o2: 14.5, he: 57.2),
            targetPressureBar: 220,
            targetMix: const GasMix(o2: 15, he: 55),
            topupO2Percent: 32,
            fillOrder: const [
              BlenderGasRole.he,
              BlenderGasRole.topup,
              BlenderGasRole.o2,
            ],
            flushFeeEnabled: true,
            flushFeeMode: FlushFeeMode.perFill,
            flushFeeGases: const [
              FlushFeeGasSetting(volumeLiters: 20),
              FlushFeeGasSetting(volumeLiters: 25),
              FlushFeeGasSetting(volumeLiters: 15),
            ],
          );
      final decoded = BlenderPreferences.fromJson(
        jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.templates, prefs.templates);
      expect(decoded.gasPrices, prefs.gasPrices);
      expect(decoded.fillTempC, 5);
      expect(decoded.settledTempC, 25);
      expect(decoded.cylinderWaterLiters, 3);
      expect(decoded.model, BlendGasModel.vanDerWaals);
      expect(decoded.startPressureBar, 40);
      expect(decoded.startMix, const GasMix(o2: 14.5, he: 57.2));
      expect(decoded.targetPressureBar, 220);
      expect(decoded.targetMix, const GasMix(o2: 15, he: 55));
      expect(decoded.topupO2Percent, 32);
      expect(decoded.fillOrder, [
        BlenderGasRole.he,
        BlenderGasRole.topup,
        BlenderGasRole.o2,
      ]);
      expect(decoded.flushFeeEnabled, isTrue);
      expect(decoded.flushFeeMode, FlushFeeMode.perFill);
      expect(decoded.flushFeeGases[0].volumeLiters, 20);
      expect(decoded.flushFeeGases[1].volumeLiters, 25);
      expect(decoded.flushFeeGases[2].volumeLiters, 15);
    });

    test('migrates a pre-issue-#42 blob: position becomes the default fill '
        'order, and the old bank-3 mix becomes the topup fraction', () {
      final decoded = BlenderPreferences.fromJson({
        'gasPrices': [2.55, 7.99, 0.01],
        'fillGas1': {'o2': 100, 'he': 0},
        'fillGas2': {'o2': 0, 'he': 100},
        'fillGas3': {'o2': 32, 'he': 0},
      });
      expect(decoded.fillOrder, kDefaultBlenderFillOrder);
      expect(decoded.topupO2Percent, 32);
      expect(decoded.gasPrices, [2.55, 7.99, 0.01]);
    });

    test('a corrupt fill order falls back to the default', () {
      final decoded = BlenderPreferences.fromJson({
        'fillOrder': ['o2', 'o2', 'topup'],
      });
      expect(decoded.fillOrder, kDefaultBlenderFillOrder);
    });

    test(
      'a fill order that is not even a list falls back, keeping the rest',
      () {
        // PR #1359 review: this was the one field read through an unguarded
        // cast, so a non-list value threw out of fromJson. The repository
        // catches that and returns null, the loader treats null as "nothing
        // stored", and the next settled edit writes the defaults back over the
        // diver's mixes, prices, bill and archive. Every other field falls back
        // on its own; so does this one now.
        final decoded = BlenderPreferences.fromJson({
          'fillOrder': 'o2,he,topup',
          'gasPrices': [2.55, 7.99, 0.01],
          'billedTo': 'Ada',
        });

        expect(decoded.fillOrder, kDefaultBlenderFillOrder);
        expect(decoded.gasPrices, [2.55, 7.99, 0.01]);
        expect(decoded.billedTo, 'Ada');
      },
    );

    test('a malformed mix falls back per field', () {
      final decoded = BlenderPreferences.fromJson({
        'startPressureBar': 'deep',
        'startMix': {'o2': 'bad'},
      });
      expect(decoded.startPressureBar, 0.0);
      expect(decoded.startMix, const GasMix(o2: 21));
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
        'fillTempC': 'cold',
        'model': 'newtonian',
      });
      expect(decoded.templates, isEmpty);
      expect(decoded.gasPrices, [2.55, null, null]);
      expect(decoded.fillTempC, kReferenceTempC);
      expect(decoded.model, BlendGasModel.zFactor);
      expect(decoded.flushFeeEnabled, isFalse);
      expect(decoded.flushFeeMode, FlushFeeMode.perInvoice);
      expect(decoded.flushFeeGases, hasLength(3));
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
