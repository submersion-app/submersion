import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every main notes or description field is Markdown (issue #3683): edited
/// with the shared notes editor, drawn with the shared notes view, and shown
/// as plain words wherever it is truncated or cannot draw formatting.
///
/// The fields were switched over all at once. Without a ratchet, a refactor
/// of one screen can quietly put a plain `TextFormField` or `Text` back, and
/// that field alone stops formatting. The lists below name each surface; the
/// scan at the end catches a new screen that draws one of these fields with
/// a raw `Text`.
///
/// Short log-entry fields (sighting notes, service records, fills, pre-dive
/// items and the like) stay plain text by design; see the spec,
/// docs/design/specs/2026-10-26-markdown-notes-design.md.
void main() {
  /// Editors of a Markdown field, each with the token proving it uses the
  /// shared editor: the editor itself, or a form row in Markdown mode.
  const editors = <String, String>{
    'lib/features/buddies/presentation/pages/buddy_edit_page.dart':
        'MarkdownNotesField(',
    'lib/features/certifications/presentation/pages/certification_edit_page.dart':
        'MarkdownNotesField(',
    'lib/features/courses/presentation/pages/course_edit_page.dart':
        'MarkdownNotesField(',
    'lib/features/dive_centers/presentation/pages/dive_center_edit_page.dart':
        'MarkdownNotesField(',
    // The bulk notes field and the save-as-set description.
    'lib/features/dive_log/presentation/pages/dive_edit_page.dart':
        'MarkdownNotesField(',
    'lib/features/dive_log/presentation/widgets/edit_sections/experience_section.dart':
        'markdown: true',
    'lib/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart':
        'markdown: true',
    'lib/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart':
        'markdown: true',
    'lib/features/dive_sites/presentation/widgets/edit_sections/life_notes_section.dart':
        'markdown: true',
    'lib/features/documents/presentation/pages/document_edit_page.dart':
        'MarkdownNotesField(',
    'lib/features/equipment/presentation/pages/equipment_edit_page.dart':
        'MarkdownNotesField(',
    'lib/features/equipment/presentation/pages/equipment_set_edit_page.dart':
        'MarkdownNotesField(',
    'lib/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart':
        'MarkdownNotesField(',
    'lib/features/marine_life/presentation/pages/species_edit_page.dart':
        'MarkdownNotesField(',
    'lib/features/rules/presentation/widgets/rule_action_editor.dart':
        'MarkdownNotesField(',
    'lib/features/settings/presentation/pages/medical_info_edit_page.dart':
        'MarkdownNotesField(',
    'lib/features/settings/presentation/pages/notes_edit_page.dart':
        'MarkdownNotesField(',
    'lib/features/shared_library/presentation/widgets/library_about_section.dart':
        'MarkdownNotesField(',
    'lib/features/site_scape/presentation/site_feature_sheet.dart':
        'MarkdownNotesField(',
    'lib/features/trips/presentation/pages/trip_edit_page.dart':
        'MarkdownNotesField(',
    'lib/features/trips/presentation/widgets/itinerary_day_edit_sheet.dart':
        'MarkdownNotesField(',
  };

  /// Files holding more than one Markdown surface, with how many times the
  /// shared editor or view must appear, so one of them going plain fails
  /// even while another still uses the shared widget.
  const atLeast = <String, int>{
    // The bulk notes field and the save-as-set description.
    'lib/features/dive_log/presentation/pages/dive_edit_page.dart': 2,
    // Description, notes and (through _buildAccessRow) access notes.
    'lib/features/dive_sites/presentation/pages/site_detail_page.dart': 3,
  };

  /// Screens that show a Markdown field in full.
  const views = <String>[
    'lib/features/buddies/presentation/pages/buddy_detail_page.dart',
    'lib/features/certifications/presentation/pages/certification_detail_page.dart',
    'lib/features/courses/presentation/pages/course_detail_page.dart',
    'lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart',
    'lib/features/dive_log/presentation/pages/dive_detail_page.dart',
    'lib/features/dive_sites/presentation/pages/site_detail_page.dart',
    'lib/features/documents/presentation/widgets/document_details_panel.dart',
    'lib/features/equipment/presentation/pages/equipment_detail_page.dart',
    'lib/features/equipment/presentation/pages/equipment_location_detail_page.dart',
    'lib/features/equipment/presentation/pages/equipment_set_detail_page.dart',
    'lib/features/marine_life/presentation/pages/species_detail_page.dart',
    'lib/features/safety/presentation/pages/emergency_card_page.dart',
    'lib/features/shared_library/presentation/pages/connect_shared_library_page.dart',
    'lib/features/site_scape/presentation/site_feature_info_sheet.dart',
    'lib/features/trips/presentation/widgets/overview/trip_prepare_overview.dart',
    'lib/features/trips/presentation/widgets/story/trip_story_day_plan.dart',
    'lib/features/trips/presentation/widgets/story/trip_story_view.dart',
  ];

  /// Truncated previews, table columns and exports that need plain words.
  const plainWords = <String>[
    'lib/core/constants/dive_field_extractor.dart',
    'lib/core/services/export/csv/csv_export_service.dart',
    'lib/core/services/export/excel/excel_export_service.dart',
    'lib/core/services/export/kml/kml_export_service.dart',
    'lib/features/buddies/domain/constants/buddy_field.dart',
    'lib/features/certifications/domain/constants/certification_field.dart',
    'lib/features/courses/domain/constants/course_field.dart',
    'lib/features/dive_centers/domain/constants/dive_center_field.dart',
    'lib/features/dive_sites/domain/constants/site_field.dart',
    'lib/features/documents/domain/document_manifest.dart',
    'lib/features/equipment/domain/constants/equipment_field.dart',
    'lib/features/equipment/presentation/pages/equipment_location_list_page.dart',
    'lib/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart',
    'lib/features/equipment/presentation/widgets/equipment_set_list_content.dart',
    'lib/features/settings/presentation/pages/diver_profile_hub_page.dart',
    'lib/features/shared_library/presentation/widgets/library_about_section.dart',
    'lib/features/trips/domain/constants/trip_field.dart',
    'lib/features/trips/presentation/widgets/itinerary/itinerary_day_card.dart',
  ];

  /// Raw `Text` of a notes-like field that is deliberately plain: the file
  /// and the exact expression, with the reason. Naming the expression (not
  /// the whole file) keeps a file that also shows a Markdown field checked.
  const plainAllowed = <String, String>{
    'lib/features/pre_dive/presentation/widgets/session_item_tile.dart '
            'item.notes':
        'pre-dive item notes are a one-line field',
    'lib/features/checklists/presentation/widgets/checklist_item_tile.dart '
            'item.notes':
        'checklist item notes are a one-line field',
    'lib/features/dive_log/presentation/widgets/dive_sighting_row.dart '
            'sighting.notes':
        'sighting notes are a short log entry',
    'lib/features/dive_log/presentation/pages/dive_edit_page.dart '
            'sighting.notes':
        'sighting notes are a short log entry',
    'lib/features/equipment/presentation/widgets/service_history_section.dart '
            'record.notes':
        'service record notes are a short log entry',
    'lib/features/dive_sites/presentation/pages/site_import_page.dart '
            'site.description':
        'a description from an external site database, before import',
    'lib/features/dive_sites/presentation/pages/site_match_review_page.dart '
            'c.description':
        'a description from an external site database, before import',
    'lib/features/dive_log/presentation/widgets/dive_numbering_dialog.dart '
            'gap.description':
        'a numbering gap description, not a notes field',
    'lib/features/universal_import/presentation/widgets/source_confirmation_step.dart '
            'detection.description':
        'an import format description, not a notes field',
  };

  /// The file's code with `//` comments removed.
  String codeOf(String path) => File(path)
      .readAsStringSync()
      .split('\n')
      .map((line) => line.split('//').first)
      .join('\n');

  int uses(String path, String token) => token.allMatches(codeOf(path)).length;

  test('every Markdown notes editor uses the shared editor', () {
    final offenders = [
      for (final MapEntry(key: path, value: token) in editors.entries)
        if (uses(path, token) < (atLeast[path] ?? 1))
          '$path (needs $token ${atLeast[path] ?? 1} time(s))',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('every full Markdown notes view uses the shared view', () {
    final offenders = [
      for (final path in views)
        if (uses(path, 'MarkdownNotesView(') < (atLeast[path] ?? 1)) path,
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('every preview, column and export of a Markdown field is plain '
      'words', () {
    final offenders = [
      for (final path in plainWords)
        if (!codeOf(path).contains('markdownToPlainText(')) path,
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no screen draws a notes field with a raw Text', () {
    final raw = RegExp(
      r'\b(?:Selectable)?Text\(\s*([A-Za-z_][\w.!?]*\.'
      r'(?:notes|description|medicalNotes|accessNotes))\b',
    );
    final offenders = <String>[];
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (!path.contains('/presentation/')) continue;
      for (final match in raw.allMatches(codeOf(path))) {
        final expression = match.group(1)!.replaceAll(RegExp(r'[!?]'), '');
        final key = '$path $expression';
        if (!plainAllowed.containsKey(key)) offenders.add(key);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Draw a Markdown notes field with MarkdownNotesView, or plain '
          'words via markdownToPlainText when truncated, or add the file and '
          'expression to plainAllowed with the reason the field is plain:\n'
          '${offenders.join('\n')}',
    );
  });
}
