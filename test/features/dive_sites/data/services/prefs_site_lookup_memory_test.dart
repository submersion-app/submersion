import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_sites/data/services/prefs_site_lookup_memory.dart';
import 'package:submersion/features/dive_sites/domain/services/site_lookup_memory.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const note = SiteLookupNote(
    latitude: 20.214,
    longitude: -87.429,
    blank: {SiteLocationField.bodyOfWater, SiteLocationField.city},
  );

  test('notes round-trip through preferences', () async {
    await PrefsSiteLookupMemory(prefs, diverId: 'd1').write({'s1': note});
    final read = await PrefsSiteLookupMemory(prefs, diverId: 'd1').read();
    expect(read, {'s1': note});
  });

  test('each diver has their own notes', () async {
    await PrefsSiteLookupMemory(prefs, diverId: 'd1').write({'s1': note});
    expect(await PrefsSiteLookupMemory(prefs, diverId: 'd2').read(), isEmpty);
    expect(await PrefsSiteLookupMemory(prefs).read(), isEmpty);
  });

  test('writing no notes removes the stored value', () async {
    final memory = PrefsSiteLookupMemory(prefs);
    await memory.write({'s1': note});
    await memory.write({});
    expect(prefs.containsKey(PrefsSiteLookupMemory.prefsKey), isFalse);
  });

  test('an entry it cannot read is dropped, the rest kept', () async {
    await prefs.setString(
      PrefsSiteLookupMemory.prefsKey,
      '{"ok": {"lat": 1, "lon": 2, "blank": ["city"]},'
      ' "unknown": {"lat": 1, "lon": 2, "blank": ["city", "reef"]},'
      ' "empty": {"lat": 1, "lon": 2, "blank": []},'
      ' "numbers": {"lat": 1, "lon": 2, "blank": ["city", 3, null, {}]},'
      ' "flat": {"lat": 1, "lon": 2, "blank": "city"},'
      ' "junk": 3}',
    );
    final read = await PrefsSiteLookupMemory(prefs).read();
    expect(read.keys, ['ok']);
    expect(read['ok']!.blank, {SiteLocationField.city});
  });

  test('a stored value that is not a map reads as no notes', () async {
    await prefs.setString(PrefsSiteLookupMemory.prefsKey, '[1, 2]');
    expect(await PrefsSiteLookupMemory(prefs).read(), isEmpty);
    await prefs.setString(PrefsSiteLookupMemory.prefsKey, '{not json');
    expect(await PrefsSiteLookupMemory(prefs).read(), isEmpty);
  });
}
