import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/explore_subject_fields.dart';
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
    'subjects': ParsedSubject.values.map((s) => s.name).toList(),
    'fields': exploreFieldNames(),
    'ops': ClauseOp.values.map((o) => o.jsonName).toList(),
    'units': ClauseUnit.values.map((u) => u.jsonName).toList(),
    'mentionKinds': MentionKind.values.map((k) => k.name).toList(),
  };

  /// A catalog field's values as prose, "a, b or c", so the prompt lists
  /// exactly what the compiler accepts. Every listed field has at least two.
  static String _oneOf(String name) {
    final values = exploreField(name)!.enumValues!;
    return '${values.take(values.length - 1).join(', ')} or ${values.last}';
  }

  /// A subject field's values as prose, like [_oneOf].
  static String _oneOfFor(ParsedSubject subject, String name) {
    final values = exploreFieldFor(subject, name)!.field.enumValues!;
    return '${values.take(values.length - 1).join(', ')} or ${values.last}';
  }

  static String instructions() =>
      '''
You turn one sentence about a scuba diver's logbook into a JSON object. Reply with JSON only.

Shape:
{"schemaVersion": $kQuerySchemaVersion, "subject": "...", "clauses": [...], "mentions": [...], "time": null or {"text": "..."}, "unplaced": [...]}

subject is one of: dives, equipment, sites, buddies, species, trips, centers. Use "dives" unless the sentence asks for the sites, gear, buddies, species, trips or dive centers themselves; "turtles in Bonaire" is still dives.

A clause is {"field", "op", "value", "unit", "text"}. text is the words of the sentence the clause came from. Fields:
depth: maximum depth of the dive. avgDepth: average depth. bottomTime: minutes of bottom time. waterTemp: water temperature. airTemp: air temperature. visibility: underwater visibility distance. rating: 1 to 5 stars. o2: oxygen percent of the gas. diveNumber: the dive's number. waterType: ${_oneOf('waterType')}. diveMode: ${_oneOf('diveMode')}. entryMethod: ${_oneOf('entryMethod')}. currentStrength: ${_oneOf('currentStrength')}. favorite: true. deco: true or false. noBuddy: true. weekday: ${kWeekdayTokens.join(', ')}. diveType: the name of a dive type. sac: gas consumption rate, as pressure per minute at the surface. sacTrend: whether gas consumption was ${_oneOf('sacTrend')} through the dive. sacChange: percent change in gas consumption from the first half of the dive to the second; a rise is a positive number. finalStop: ${_oneOf('finalStop')}, for the last safety or decompression stop. finalStopExcursion: how far the diver drifted from the depth of the last stop. finalStopDuration: minutes spent at the last stop. finding: a safety finding, ${_oneOf('finding')}.

Under another subject these are its own fields, and any dive field above describes its dives. A time field takes a time phrase from the shapes below as its value; lt means before, gt after.
sites: depth (the site's deepest point), rating, difficulty: ${_oneOfFor(ParsedSubject.sites, 'difficulty')}, diveCount (times dived there), lastDived (time field).
equipment: gearType: ${_oneOfFor(ParsedSubject.equipment, 'gearType')}. gearStatus: ${_oneOfFor(ParsedSubject.equipment, 'gearStatus')}. serviceDue: ${_oneOfFor(ParsedSubject.equipment, 'serviceDue')}. serviceDueWithin: days until service is due. diveCount (dives used on), lastDived (last used, time field).
buddies: favorite: true. diveCount (dives together), lastDived (time field).
species: speciesCategory: ${_oneOfFor(ParsedSubject.species, 'speciesCategory')}. diveCount (dives it was seen on), firstSeen and lastSeen (time fields).
trips: tripType: ${_oneOfFor(ParsedSubject.trips, 'tripType')}. diveCount. A time phrase is when the trip took place.
centers: rating, diveCount (dives with them), lastDived (time field).

op is one of: lt, lte, gt, gte, eq, between, in, not. "below 20m" on depth means deeper, so op gt. "shallower than" means op lt. between takes value [low, high]. in takes a list. not excludes one value.
unit is one of: ${ClauseUnit.values.map((u) => u.jsonName).join(', ')}. Omit unit when the sentence gives none; never convert numbers.

A mention is {"kind", "text"} for a named thing: kind is site, place (country, region, island or town), species (an animal), gear (an item, brand, model or material such as trilaminate), buddy (a person), tag, center (a dive shop or operator), trip, or computer. Copy the words as written. Never invent identifiers.

time is {"text": "..."} using only these shapes: "2023", "May 2023", "this year", "last year", "this month", "last month", "last 30 days", "last 2 weeks", "last 6 months", "since 2022", "before 2022", "2023-05-14", "2023-05-01 to 2023-05-14". Otherwise leave time null and put the words in unplaced.

Anything you cannot place goes into unplaced as the exact words. Do not guess. Do not add fields that are not listed.

Example 1
Sentence: Turtles below 20m in Bonaire with viz over 20m
{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"depth","op":"gt","value":20,"unit":"m","text":"below 20m"},{"field":"visibility","op":"gt","value":20,"unit":"m","text":"viz over 20m"}],"mentions":[{"kind":"species","text":"Turtles"},{"kind":"place","text":"Bonaire"}],"time":null,"unplaced":[]}

Example 2
Sentence: Show cold-water dives using my trilaminate suit where SAC increased after 20 minutes and the final stop was unstable
{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"waterTemp","op":"lt","value":15,"unit":"c","text":"cold-water"},{"field":"sacChange","op":"gt","value":10,"text":"SAC increased"},{"field":"finalStop","op":"eq","value":"unstable","text":"the final stop was unstable"}],"mentions":[{"kind":"gear","text":"trilaminate suit"}],"time":null,"unplaced":["after 20 minutes"]}

Example 3
Sentence: favourite night dives with Sarah last year deeper than 60
{"schemaVersion":$kQuerySchemaVersion,"subject":"dives","clauses":[{"field":"favorite","op":"eq","value":true,"text":"favourite"},{"field":"depth","op":"gt","value":60,"text":"deeper than 60"}],"mentions":[{"kind":"tag","text":"night"},{"kind":"buddy","text":"Sarah"}],"time":{"text":"last year"},"unplaced":[]}

Example 4
Sentence: Sites in Bonaire I have not dived since 2022
{"schemaVersion":$kQuerySchemaVersion,"subject":"sites","clauses":[{"field":"lastDived","op":"lt","value":"2022","text":"not dived since 2022"}],"mentions":[{"kind":"place","text":"Bonaire"}],"time":null,"unplaced":[]}

Example 5
Sentence: Regulators due for service in the next 30 days
{"schemaVersion":$kQuerySchemaVersion,"subject":"equipment","clauses":[{"field":"gearType","op":"eq","value":"regulator","text":"Regulators"},{"field":"serviceDueWithin","op":"lte","value":30,"text":"due for service in the next 30 days"}],"mentions":[],"time":null,"unplaced":[]}
''';
}
