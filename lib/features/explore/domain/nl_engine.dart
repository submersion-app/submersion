import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

enum NlAvailability {
  available,
  deviceNotEligible,
  notEnabled,
  modelNotReady,
  downloadable,
  downloading,
  unsupportedLocale,
  unsupportedPlatform,
}

enum NlError {
  unsupportedLocale,
  contextExceeded,
  guardrail,
  refusal,
  decodingFailure,
  modelNotReady,
  quotaExceeded,
  schemaMismatch,
  unknown,
}

class NlException implements Exception {
  final NlError error;
  final String? message;
  const NlException(this.error, [this.message]);
  @override
  String toString() =>
      'NlException(${error.name}${message == null ? '' : ': $message'})';
}

/// The only thing the app asks of an on-device model: availability, a warm
/// session, and one sentence in, one JSON string out. It never sees dive data.
abstract class NlEngine {
  Future<NlAvailability> availability(String localeTag);
  Future<void> prepare();
  Stream<double> download();
  Future<String> compile(String sentence, {required String localeTag});
}

/// The fixed prompt. Identical on every device and free of the diver's data,
/// so behaviour is reproducible and the 4K context is never at risk.
abstract final class NlPrompt {
  static Map<String, Object?> vocabulary() => {
    'schemaVersion': kQuerySchemaVersion,
    'subjects': QuerySubject.values.map((s) => s.name).toList(),
    'fields': DiveFieldCatalog.jsonNames,
    'ops': ClauseOp.values.map((o) => o.jsonName).toList(),
    'units': ClauseUnit.values.map((u) => u.jsonName).toList(),
    'mentionKinds': MentionKind.values.map((k) => k.name).toList(),
  };

  static String instructions() => '''
You turn one sentence about a scuba diver's logbook into a JSON object. Reply with JSON only.

Shape:
{"schemaVersion": 1, "subject": "dives", "clauses": [...], "mentions": [...], "time": null or {"text": "..."}, "unplaced": [...]}

subject is one of: dives, equipment, sites, buddies, species, trips, centers. Use "dives" unless the sentence clearly asks for another kind of thing.

A clause is {"field", "op", "value", "unit", "text"}. text is the words of the sentence the clause came from. Fields:
depth: maximum depth of the dive. avgDepth: average depth. bottomTime: minutes of bottom time. waterTemp: water temperature. airTemp: air temperature. visibility: underwater visibility distance. rating: 1 to 5 stars. o2: oxygen percent of the gas. diveNumber: the dive's number. waterType: salt, fresh or brackish. diveMode: oc, ccr, scr or gauge. entryMethod: shore, boat, backRoll, giantStride, seatedEntry, ladder, platform, jetty or other. currentStrength: none, light, moderate or strong. favorite: true. deco: true or false. noBuddy: true. weekday: mon, tue, wed, thu, fri, sat, sun. diveType: the name of a dive type.

op is one of: lt, lte, gt, gte, eq, between, in, not. "below 20m" on depth means deeper, so op gt. "shallower than" means op lt. between takes value [low, high]. in takes a list. not excludes one value.
unit is one of: m, ft, c, f, bar, psi, min, l_min, cuft_min. Omit unit when the sentence gives none; never convert numbers.

A mention is {"kind", "text"} for a named thing: kind is site, place (country, region, island or town), species (an animal), gear (an item, brand, model or material such as trilaminate), buddy (a person), tag, center (a dive shop or operator), trip, or computer. Copy the words as written. Never invent identifiers.

time is {"text": "..."} using only these shapes: "2023", "May 2023", "this year", "last year", "this month", "last month", "last 30 days", "last 2 weeks", "last 6 months", "since 2022", "before 2022", "2023-05-14", "2023-05-01 to 2023-05-14". Otherwise leave time null and put the words in unplaced.

Anything you cannot place goes into unplaced as the exact words. Do not guess. Do not add fields that are not listed.

Example 1
Sentence: Turtles below 20m in Bonaire with viz over 20m
{"schemaVersion":1,"subject":"dives","clauses":[{"field":"depth","op":"gt","value":20,"unit":"m","text":"below 20m"},{"field":"visibility","op":"gt","value":20,"unit":"m","text":"viz over 20m"}],"mentions":[{"kind":"species","text":"Turtles"},{"kind":"place","text":"Bonaire"}],"time":null,"unplaced":[]}

Example 2
Sentence: Show cold-water dives using my trilaminate suit where SAC increased after 20 minutes and the final stop was unstable
{"schemaVersion":1,"subject":"dives","clauses":[{"field":"waterTemp","op":"lt","value":15,"unit":"c","text":"cold-water"}],"mentions":[{"kind":"gear","text":"trilaminate suit"}],"time":null,"unplaced":["SAC increased after 20 minutes","the final stop was unstable"]}

Example 3
Sentence: favourite night dives with Sarah last year deeper than 60
{"schemaVersion":1,"subject":"dives","clauses":[{"field":"favorite","op":"eq","value":true,"text":"favourite"},{"field":"depth","op":"gt","value":60,"text":"deeper than 60"}],"mentions":[{"kind":"tag","text":"night"},{"kind":"buddy","text":"Sarah"}],"time":{"text":"last year"},"unplaced":[]}
''';
}
