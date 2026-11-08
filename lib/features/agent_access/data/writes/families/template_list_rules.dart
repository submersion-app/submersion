import 'package:submersion/features/agent_access/data/writes/families/checklist_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

/// A template's sections, in order, written whole.
const templateSectionsCodec = ObjectListCodec({
  'title': FieldCodec.text(maxLength: 100, trim: true),
});

/// The section titles and items a change leaves on a template: those it
/// names, else those the template holds now.
({List<String> sections, List<Map<String, Object?>> items}) templateLists(
  WriteCheck check,
) {
  List<Map<String, Object?>> listOf(String key) => check.values.containsKey(key)
      ? ObjectListCodec.items(check.values[key])
      : [
          for (final item in check.document?[key] as List? ?? const [])
            (item as Map).cast<String, Object?>(),
        ];
  return (
    sections: [for (final s in listOf('sections')) s['title']! as String],
    items: listOf('items'),
  );
}

/// Why [items] name a section [sections] lacks, or the same section twice,
/// or null.
PlanBlock? templateSectionProblem(
  List<String> sections,
  List<Map<String, Object?>> items,
) {
  final keys = [for (final title in sections) sectionKey(title)];
  if (keys.toSet().length != keys.length) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'sections: each title once.',
    );
  }
  for (final (i, item) in items.indexed) {
    final section = item['section'] as String?;
    if (section != null && !keys.contains(sectionKey(section))) {
      return PlanBlock(
        BlockReason.invalidValue,
        'items: item $i names section "$section", which sections lacks.',
      );
    }
  }
  return null;
}

/// The id each of [titles] keeps: the stored section's of the same title,
/// or a blank for a new one.
List<String> keptSectionIds(
  Map<String, String> storedIdByTitle,
  List<String> titles,
) => [for (final title in titles) storedIdByTitle[sectionKey(title)] ?? ''];

/// The id each of [items] keeps: a stored item's with the same section and
/// title, each used once, or a blank for a new one. The editors give an
/// item its id back, so a save rewrites the rows it keeps rather than
/// deleting and re-adding every one.
List<String> keptItemIds(
  List<({String id, String? section, String title})> stored,
  List<Map<String, Object?>> items,
) {
  String key(Object? section, Object? title) =>
      '${sectionKey(section as String?) ?? ''}/'
      '${sectionKey(title as String?) ?? ''}';
  final storedKeys = [for (final s in stored) key(s.section, s.title)];
  final itemKeys = [for (final i in items) key(i['section'], i['title'])];
  // The nth item of a key takes the nth stored row of that key.
  return [
    for (final (i, k) in itemKeys.indexed)
      [
            for (final (j, s) in stored.indexed)
              if (storedKeys[j] == k) s.id,
          ].elementAtOrNull(itemKeys.take(i).where((o) => o == k).length) ??
          '',
  ];
}

/// The stored section id [title] names, by the titles saved.
String? sectionIdFor(Map<String?, String> idByKey, Object? title) =>
    title is String ? idByKey[sectionKey(title)] : null;
