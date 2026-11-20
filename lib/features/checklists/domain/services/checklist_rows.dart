import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart';

/// One past the highest of [taken], or 0 when there is none: where a row
/// joins the end of a list. Not the count: a deleted row leaves a gap
/// rather than renumbering, so the count can equal an order in use.
int nextSortOrder(Iterable<int> taken) =>
    taken.fold<int>(-1, (highest, o) => o > highest ? o : highest) + 1;

/// The sort orders to hand rows laid out anew, by position: the values
/// [taken] already held, smallest first, so rows moved and moved back end
/// with the values they had (an editing sitting then holds no change,
/// issue #4527). Where two rows share a value (two devices added one
/// offline) the positions themselves are used, so the order stays plain.
List<int> reorderedSortOrders(Iterable<int> taken) {
  final sorted = [...taken]..sort();
  return sorted.toSet().length == sorted.length
      ? sorted
      : [for (var i = 0; i < sorted.length; i++) i];
}

/// The section of [known] titled [trimmedTitle], compared
/// case-insensitively, as the item editor's picker matches; null for no
/// title or no match.
String? matchSectionByTitle(
  String? trimmedTitle,
  List<TripChecklistSection> known,
) {
  if (trimmedTitle == null) return null;
  for (final section in known) {
    if (section.title.toLowerCase() == trimmedTitle.toLowerCase()) {
      return section.id;
    }
  }
  return null;
}

/// What applying a template to a checklist adds: the sections it needs and
/// its items, with how many it added and skipped.
typedef ChecklistTemplateRows = ({
  List<TripChecklistSection> sections,
  List<TripChecklistItem> items,
  int added,
  int skipped,
});

/// The rows a template's [templateItems] add to checklist [checklistId]
/// (copy on apply, issue #3356), given what it already holds
/// ([existingItems], [existingSections]).
///
/// Each item's section is bridged by title to a checklist section, matched
/// case-insensitively before one is made. An item whose title and resolved
/// section match an existing item is skipped, so applying twice adds
/// nothing; the match is looked up, not made, before that check, so a
/// fully skipped apply makes no section. Due offsets resolve against
/// [tripStart]'s calendar day. New sections and items take their ids from
/// [newId] and follow the highest sort order already used; [now] stamps
/// them.
ChecklistTemplateRows checklistRowsFromTemplate({
  required List<ChecklistTemplateItem> templateItems,
  required List<ChecklistTemplateSection> templateSections,
  required String checklistId,
  required DateTime tripStart,
  required List<TripChecklistItem> existingItems,
  required List<TripChecklistSection> existingSections,
  required String Function() newId,
  required DateTime now,
}) {
  final titleById = {for (final s in templateSections) s.id: s.title};
  final existingKeys = {for (final i in existingItems) (i.title, i.sectionId)};
  var sortOrder = nextSortOrder([for (final i in existingItems) i.sortOrder]);
  var known = [...existingSections];
  final sections = <TripChecklistSection>[];
  final items = <TripChecklistItem>[];
  var skipped = 0;
  for (final item in templateItems) {
    final title = item.sectionId == null
        ? null
        : titleById[item.sectionId]?.trim();
    final hasTitle = title != null && title.isNotEmpty;
    final matched = hasTitle ? matchSectionByTitle(title, known) : null;
    // A placeholder standing in for "no such section yet" cannot equal any
    // stored item's section (null or a real id), so it never skips wrongly.
    final comparison =
        matched ??
        (hasTitle ? '__pending_section__:${title.toLowerCase()}' : null);
    if (existingKeys.contains((item.title, comparison))) {
      skipped++;
      continue;
    }
    var sectionId = matched;
    if (sectionId == null && hasTitle) {
      final created = TripChecklistSection(
        id: newId(),
        checklistId: checklistId,
        title: title,
        sortOrder: nextSortOrder([for (final s in known) s.sortOrder]),
        createdAt: now,
        updatedAt: now,
      );
      known = [...known, created];
      sections.add(created);
      sectionId = created.id;
    }
    final offset = item.dueOffsetDays;
    items.add(
      TripChecklistItem(
        id: newId(),
        checklistId: checklistId,
        title: item.title,
        sectionId: sectionId,
        notes: item.notes,
        dueDate: offset == null
            ? null
            : DateTime(tripStart.year, tripStart.month, tripStart.day - offset),
        sortOrder: sortOrder++,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
  return (
    sections: sections,
    items: items,
    added: items.length,
    skipped: skipped,
  );
}
