import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';
import 'package:submersion/features/emergency_tag/domain/services/emergency_tag_codec.dart';
import 'package:submersion/features/emergency_tag/presentation/utils/emergency_tag_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every field has its own switch label', () {
    final names = {
      for (final f in EmergencyTagField.values) emergencyTagFieldName(l10n, f),
    };
    expect(names, hasLength(EmergencyTagField.values.length));
    expect(
      emergencyTagFieldName(l10n, EmergencyTagField.birthYear),
      'Year of birth',
    );
  });

  test('every droppable key reads as a field, an unknown key as itself', () {
    final labels = {
      for (final k in EmergencyTagCodec.dropOrder)
        emergencyTagDroppedLabel(l10n, k),
    };
    expect(labels, hasLength(EmergencyTagCodec.dropOrder.length));
    expect(labels, isNot(contains('mn')));
    expect(emergencyTagDroppedLabel(l10n, 'ip'), 'Policy number');
    expect(emergencyTagDroppedLabel(l10n, 'zz'), 'zz');
  });

  test('every call target has a menu label', () {
    expect(
      EmergencyCallTarget.values.map((t) => emergencyCallTargetName(l10n, t)),
      ['Emergency contact 1', 'Emergency contact 2', "Insurer's 24-hour line"],
    );
  });

  test('the text labels fill in the year, numbers and date', () {
    final labels = emergencyTagLabels(l10n, (d) => '${d.year}/${d.month}');
    expect(labels.born(1984), 'born 1984');
    expect(labels.policy('123'), 'policy 123');
    expect(labels.assistanceLine('+1 919'), '24h line +1 919');
    expect(
      labels.written(DateTime(2026, 11, 27)),
      'Written 2026/11 with Submersion',
    );
    expect(labels.header, 'EMERGENCY INFO');
    expect(labels.someLeftOff, isNotEmpty);
  });
}
