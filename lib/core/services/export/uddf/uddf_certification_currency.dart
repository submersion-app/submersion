import 'package:xml/xml.dart';

import 'package:submersion/core/services/export/models/currency_backup_data.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/entities/currency_scope.dart';

/// The rows the parser reads back, as the import pipeline's maps.
typedef UddfCurrencyRows = ({
  List<Map<String, dynamic>> rules,
  List<Map<String, dynamic>> prefs,
  List<Map<String, dynamic>> events,
});

/// Certification currency in the UDDF full backup (issue #2267).
///
/// UDDF has nothing for it, so the rows go in three private blocks beside
/// `<certifications>` inside `<applicationdata><submersion>`:
///
/// ```xml
/// <currencyrules>
///   <currencyrule id="UUID">
///     <name>Club refresher</name>
///     <clockkind>activity</clockkind>
///     <agencies>["bsac"]</agencies>
///     ...
///   </currencyrule>
/// </currencyrules>
/// <currencyprefs>
///   <currencypref id="UUID" certref="cert_ID" rule="padi_reactivate">
///     <divetypes>[]</divetypes>
///     <muted>true</muted>
///   </currencypref>
/// </currencyprefs>
/// <currencyevents>
///   <currencyevent id="UUID" certref="cert_ID" rule="padi_reactivate">
///     <type>refresher</type>
///     <date>2026-03-04T00:00:00.000</date>
///   </currencyevent>
/// </currencyevents>
/// ```
///
/// Built-in rules never travel: every device seeds them. On a pref an
/// ABSENT `<divetypes>` or `<divemodes>` means "inherit the rule's mapping"
/// while a present `[]` means "any dive counts"; the two must survive the
/// round trip as different answers. The `certref` matches the `id` the
/// `<cert>` element carries, so an importer can follow it to the
/// certification it created.
abstract final class UddfCertificationCurrency {
  static const rulesSection = 'currencyrules';
  static const prefsSection = 'currencyprefs';
  static const eventsSection = 'currencyevents';

  static String certRef(String certificationId) => 'cert_$certificationId';

  /// Writes the three blocks; writes nothing for an empty part.
  static void write(XmlBuilder builder, CurrencyBackupData data) {
    final rules = data.customRules;
    if (rules.isNotEmpty) {
      builder.element(
        rulesSection,
        nest: () {
          for (final rule in rules) {
            _writeRule(builder, rule);
          }
        },
      );
    }
    if (data.prefs.isNotEmpty) {
      builder.element(
        prefsSection,
        nest: () {
          for (final pref in data.prefs) {
            _writePref(builder, pref);
          }
        },
      );
    }
    if (data.events.isNotEmpty) {
      builder.element(
        eventsSection,
        nest: () {
          for (final event in data.events) {
            _writeEvent(builder, event);
          }
        },
      );
    }
  }

  static void _writeRule(XmlBuilder builder, CurrencyRule rule) {
    builder.element(
      'currencyrule',
      attributes: {'id': rule.id},
      nest: () {
        builder.element('name', nest: rule.name);
        builder.element('clockkind', nest: rule.clockKind.name);
        builder.element('agencies', nest: rule.agenciesJson);
        builder.element('levels', nest: rule.levelsJson);
        builder.element('lapsedays', nest: '${rule.lapseDays}');
        builder.element('leaddays', nest: '${rule.leadDays}');
        builder.element('divetypes', nest: rule.diveTypesJson);
        builder.element('divemodes', nest: rule.diveModesJson);
        if (rule.advisoryText != null) {
          builder.element('advisory', nest: rule.advisoryText);
        }
        if (rule.supersedesRuleId != null) {
          builder.element('supersedes', nest: rule.supersedesRuleId);
        }
      },
    );
  }

  static void _writePref(XmlBuilder builder, CurrencyPref pref) {
    builder.element(
      'currencypref',
      attributes: {
        'id': pref.id,
        'certref': certRef(pref.certificationId),
        'rule': pref.ruleId,
      },
      nest: () {
        if (pref.lapseDaysOverride != null) {
          builder.element('lapsedays', nest: '${pref.lapseDaysOverride}');
        }
        if (pref.leadDaysOverride != null) {
          builder.element('leaddays', nest: '${pref.leadDaysOverride}');
        }
        final types = pref.countedDiveTypeIds;
        if (types != null) {
          builder.element('divetypes', nest: CurrencyScopeCodec.encode(types));
        }
        final modes = pref.countedDiveModes;
        if (modes != null) {
          builder.element(
            'divemodes',
            nest: CurrencyScopeCodec.encode([for (final m in modes) m.name]),
          );
        }
        builder.element('muted', nest: '${pref.muted}');
      },
    );
  }

  static void _writeEvent(XmlBuilder builder, CurrencyEvent event) {
    builder.element(
      'currencyevent',
      attributes: {
        'id': event.id,
        'certref': certRef(event.certificationId),
        'rule': ?event.ruleId,
      },
      nest: () {
        builder.element('type', nest: event.eventType.name);
        builder.element('date', nest: event.eventDate.toIso8601String());
        if (event.provider != null) {
          builder.element('provider', nest: event.provider);
        }
        if (event.notes.isNotEmpty) {
          builder.element('notes', nest: event.notes);
        }
      },
    );
  }

  /// Reads the three blocks out of the `<submersion>` element. A row
  /// missing what it cannot do without (an id, a name, a certref, a date)
  /// is dropped rather than failing the import.
  static UddfCurrencyRows parse(XmlElement submersion) => (
    rules: [
      for (final e in _rows(submersion, rulesSection, 'currencyrule'))
        ?_parseRule(e),
    ],
    prefs: [
      for (final e in _rows(submersion, prefsSection, 'currencypref'))
        ?_parsePref(e),
    ],
    events: [
      for (final e in _rows(submersion, eventsSection, 'currencyevent'))
        ?_parseEvent(e),
    ],
  );

  static Iterable<XmlElement> _rows(
    XmlElement submersion,
    String section,
    String element,
  ) =>
      submersion.findElements(section).firstOrNull?.findElements(element) ??
      const <XmlElement>[];

  static Map<String, dynamic>? _parseRule(XmlElement e) {
    final id = _attr(e, 'id');
    final name = _text(e, 'name');
    final lapse = int.tryParse(_text(e, 'lapsedays') ?? '');
    final lead = int.tryParse(_text(e, 'leaddays') ?? '');
    if (id == null || name == null || lapse == null || lead == null) {
      return null;
    }
    return {
      'id': id,
      'name': name,
      'clockKind': CurrencyClockKind.parse(_text(e, 'clockkind') ?? '').name,
      'applicableAgencies': _text(e, 'agencies') ?? '[]',
      'applicableLevels': _text(e, 'levels') ?? '[]',
      'lapseDays': lapse,
      'leadDays': lead,
      'countedDiveTypeIds': _text(e, 'divetypes') ?? '[]',
      'countedDiveModes': _text(e, 'divemodes') ?? '[]',
      'advisoryText': _text(e, 'advisory'),
      'supersedesRuleId': _text(e, 'supersedes'),
    };
  }

  static Map<String, dynamic>? _parsePref(XmlElement e) {
    final id = _attr(e, 'id');
    final certRef = _attr(e, 'certref');
    final rule = _attr(e, 'rule');
    if (id == null || certRef == null || rule == null) return null;
    return {
      'id': id,
      'certificationRef': certRef,
      'ruleId': rule,
      'lapseDaysOverride': int.tryParse(_text(e, 'lapsedays') ?? ''),
      'leadDaysOverride': int.tryParse(_text(e, 'leaddays') ?? ''),
      // Absent stays null: inherit, which is not the same as '[]'.
      'countedDiveTypeIds': _rawText(e, 'divetypes'),
      'countedDiveModes': _rawText(e, 'divemodes'),
      'muted': _text(e, 'muted') == 'true',
    };
  }

  static Map<String, dynamic>? _parseEvent(XmlElement e) {
    final id = _attr(e, 'id');
    final certRef = _attr(e, 'certref');
    final date = DateTime.tryParse(_text(e, 'date') ?? '');
    if (id == null || certRef == null || date == null) return null;
    return {
      'id': id,
      'certificationRef': certRef,
      'ruleId': _attr(e, 'rule'),
      'eventType': CurrencyEventType.parse(_text(e, 'type') ?? '').name,
      'eventDate': date,
      'provider': _text(e, 'provider'),
      'notes': _text(e, 'notes') ?? '',
    };
  }

  static String? _attr(XmlElement e, String name) {
    final value = e.getAttribute(name)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// The trimmed text of the first [name] child, or null when absent or
  /// blank.
  static String? _text(XmlElement e, String name) {
    final value = _rawText(e, name)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// The text of the first [name] child, or null only when the element is
  /// absent: an element present with `[]` is an answer.
  static String? _rawText(XmlElement e, String name) =>
      e.findElements(name).firstOrNull?.innerText;
}
