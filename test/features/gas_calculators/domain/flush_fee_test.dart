import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_gas_role.dart';
import 'package:submersion/features/gas_calculators/domain/blending/flush_fee.dart';

/// Stands in for the l10n label the invoice card supplies, so the domain
/// stays free of BuildContext.
String _label(BlenderGasRole role) => '${role.name} purge';

void main() {
  group('FlushFeeMode', () {
    test('round-trips its name', () {
      expect(FlushFeeMode.fromName('perFill'), FlushFeeMode.perFill);
      expect(FlushFeeMode.fromName('perInvoice'), FlushFeeMode.perInvoice);
    });

    test('falls back to perInvoice for anything unrecognised', () {
      expect(FlushFeeMode.fromName(null), FlushFeeMode.perInvoice);
      expect(FlushFeeMode.fromName('nonsense'), FlushFeeMode.perInvoice);
    });
  });

  group('flushFeeCost', () {
    test('is null when the gas is unpriced', () {
      expect(flushFeeCost(20, null), isNull);
    });

    test('scales with the configured volume, per 100 litres', () {
      expect(flushFeeCost(20, 7.5), closeTo(1.5, 1e-9));
      expect(flushFeeCost(100, 7.5), closeTo(7.5, 1e-9));
    });
  });

  group('FlushFeeGasSetting', () {
    test('round-trips through JSON', () {
      const setting = FlushFeeGasSetting(volumeLiters: 20);
      final decoded = FlushFeeGasSetting.fromJson(
        jsonDecode(jsonEncode(setting.toJson())),
        defaultVolumeLiters: 12,
      );
      expect(decoded.volumeLiters, 20);
    });

    test('falls back to the default volume when malformed', () {
      final decoded = FlushFeeGasSetting.fromJson(
        'not a map',
        defaultVolumeLiters: 15,
      );
      expect(decoded.volumeLiters, 15);
    });

    test('copyWith replaces the volume', () {
      const setting = FlushFeeGasSetting(volumeLiters: 20);
      expect(setting.copyWith(volumeLiters: 30).volumeLiters, 30);
    });
  });

  group('flushFeeFills', () {
    const gases = [
      FlushFeeGasSetting(volumeLiters: 20),
      FlushFeeGasSetting(volumeLiters: 30),
      FlushFeeGasSetting(volumeLiters: 40),
    ];

    List<BilledFill> fills({
      bool enabled = true,
      FlushFeeMode mode = FlushFeeMode.perInvoice,
      int fillCount = 0,
      List<double?> prices = const [7.5, 15.0, 1.0],
    }) => flushFeeFills(
      enabled: enabled,
      mode: mode,
      fillCount: fillCount,
      gases: gases,
      pricesPer100: prices,
      labelFor: _label,
    );

    test('charges nothing while the fee is off', () {
      expect(fills(enabled: false), isEmpty);
    });

    test('bills once per invoice, before anything has been filled', () {
      final lines = fills();

      expect(lines.map((f) => f.label), [
        'o2 purge',
        'he purge',
        'topup purge',
      ]);
      // 20 / 100 * 7.5, 30 / 100 * 15, 40 / 100 * 1.
      expect(lines[0].total, closeTo(1.5, 1e-9));
      expect(lines[1].total, closeTo(4.5, 1e-9));
      expect(lines[2].total, closeTo(0.4, 1e-9));
      // Nothing to itemise: the volume and price behind the amount are
      // settings, not gas drawn from a bank.
      expect(lines.every((f) => f.isManual), isTrue);
    });

    test('bills nothing per fill until a fill is saved', () {
      expect(fills(mode: FlushFeeMode.perFill), isEmpty);
    });

    test('multiplies per fill, and says so in the label', () {
      final lines = fills(mode: FlushFeeMode.perFill, fillCount: 3);

      expect(lines.first.label, 'o2 purge  \u00d73');
      expect(lines.first.total, closeTo(4.5, 1e-9));
    });

    test('an unpriced role still gets a line, with no amount', () {
      final lines = fills(prices: const [7.5, null, null]);

      expect(lines, hasLength(3));
      expect(lines[1].total, isNull);
      // Which is what makes the bill report itself incomplete rather than
      // quietly totalling less than it charges.
      expect(totalOf(lines).complete, isFalse);
    });

    test('totals with the saved fills, so a bill sums to what it lists', () {
      const saved = BilledFill(
        id: 'a',
        label: 'Tx 18/45',
        lines: [],
        total: 35,
      );
      final bill = [saved, ...fills()];

      // 35 + 1.5 + 4.5 + 0.4: every amount on the bill is a line on it.
      expect(totalOf(bill).amount, closeTo(41.4, 1e-9));
      expect(totalOf(bill).complete, isTrue);
    });

    test('tolerates a short settings list rather than throwing', () {
      final lines = flushFeeFills(
        enabled: true,
        mode: FlushFeeMode.perInvoice,
        fillCount: 0,
        gases: const [FlushFeeGasSetting(volumeLiters: 20)],
        pricesPer100: const [7.5],
        labelFor: _label,
      );

      expect(lines, hasLength(1));
      expect(lines.single.total, closeTo(1.5, 1e-9));
    });
  });
}
