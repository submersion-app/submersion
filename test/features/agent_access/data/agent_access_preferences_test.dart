import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/agent_access/data/agent_access_preferences.dart';
import 'package:submersion/features/agent_access/domain/agent_access_settings.dart';

void main() {
  Future<AgentAccessPreferences> prefsWith(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    return AgentAccessPreferences(await SharedPreferences.getInstance());
  }

  group('AgentAccessPreferences', () {
    test('defaults are off, port 47831, confirm on', () async {
      final prefs = await prefsWith({});
      expect(prefs.read(), const AgentAccessSettings());
      expect(prefs.read().enabled, isFalse);
      expect(prefs.read().port, 47831);
      expect(prefs.read().confirmWrites, isTrue);
    });

    test('write then read round-trips every field', () async {
      final prefs = await prefsWith({});
      const changed = AgentAccessSettings(
        enabled: true,
        port: 50000,
        confirmWrites: false,
      );
      await prefs.write(changed);
      expect(prefs.read(), changed);
      expect(prefs.read().enabled, isTrue);
      expect(prefs.read().port, 50000);
      expect(prefs.read().confirmWrites, isFalse);
    });

    test('an invalid stored port falls back to the default', () async {
      final tooHigh = await prefsWith({AgentAccessPreferences.portKey: 70000});
      expect(tooHigh.read().port, kAgentAccessDefaultPort);
      final privileged = await prefsWith({AgentAccessPreferences.portKey: 80});
      expect(privileged.read().port, kAgentAccessDefaultPort);
    });

    test('a stored port of the wrong type falls back to the default', () async {
      final prefs = await prefsWith({AgentAccessPreferences.portKey: '47831'});
      expect(prefs.read().port, kAgentAccessDefaultPort);
    });

    test('copyWith changes only the named field', () {
      const base = AgentAccessSettings();
      final enabled = base.copyWith(enabled: true);
      expect(enabled.enabled, isTrue);
      expect(enabled.port, base.port);
      expect(enabled.confirmWrites, base.confirmWrites);
      expect(enabled, isNot(equals(base)));
      expect(enabled.hashCode, isNot(base.hashCode));
    });
  });
}
