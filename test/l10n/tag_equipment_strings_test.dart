import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Equipment tags on Manage Tags (#1942) in every locale. Each new or
/// reworded string names equipment in the locale's own word, so a key left
/// in English (gen-l10n falls back to it silently) or a reworded one still on
/// its old dives-and-sites translation fails here. arb_parity_test only
/// checks that the key exists.
void main() {
  /// The word, or stem, each locale already uses for equipment.
  const equipmentWord = {
    'ar': 'معدات',
    'de': 'ausrüstung',
    'es': 'equipo',
    'fr': 'équipement',
    'he': 'ציוד',
    'hu': 'felszerel',
    'it': 'attrezzatur',
    'nl': 'uitrusting',
    'pt': 'equipament',
    'zh': '装备',
  };

  List<String> equipmentStrings(AppLocalizations l) => [
    l.tags_manage_scope_equipment,
    l.tags_manage_useForEquipment,
    l.tags_manage_scopeRequired,
    l.tags_manage_equipmentCount(5),
    l.tags_manage_narrowDialog_equipment(5),
    l.tags_manage_deleteMessage_equipment('X', 5),
    l.tags_manage_deleteMessage_divesAndEquipment('X', 2, 5),
    l.tags_manage_deleteMessage_sitesAndEquipment('X', 2, 5),
    l.tags_manage_deleteMessage_all('X', 2, 3, 5),
    l.tags_manage_deleteMessage_unused('X'),
    l.tags_manage_bulkDeleteMessage_equipment(5),
    l.tags_manage_bulkDeleteMessage_divesAndEquipment(2, 5),
    l.tags_manage_bulkDeleteMessage_sitesAndEquipment(2, 5),
    l.tags_manage_bulkDeleteMessage_all(2, 3, 5),
    l.tags_manage_bulkDeleteMessage_unused,
    l.tags_manage_mergeAffected_equipment(5),
    l.tags_manage_mergeAffected_divesAndEquipment(2, 5),
    l.tags_manage_mergeAffected_sitesAndEquipment(2, 5),
    l.tags_manage_mergeAffected_all(2, 3, 5),
    l.tags_manage_mergeAffected_unused,
  ];

  for (final MapEntry(key: code, value: word) in equipmentWord.entries) {
    test('$code names equipment in every equipment tag string', () {
      final strings = equipmentStrings(lookupAppLocalizations(Locale(code)));
      final missing = [
        for (final s in strings)
          if (!s.toLowerCase().contains(word)) s,
      ];
      expect(missing, isEmpty);
    });
  }

  test('Arabic counts equipment items in every plural category', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    expect(ar.tags_manage_equipmentCount(1), 'قطعة معدات واحدة');
    expect(ar.tags_manage_equipmentCount(2), 'قطعتا معدات');
    expect(ar.tags_manage_equipmentCount(3), '3 قطع معدات');
    expect(ar.tags_manage_equipmentCount(11), '11 قطعة معدات');
    expect(ar.tags_manage_equipmentCount(100), '100 قطعة معدات');
  });
}
