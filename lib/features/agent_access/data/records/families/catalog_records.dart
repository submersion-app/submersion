import 'package:submersion/features/agent_access/data/documents/catalog_documents.dart';
import 'package:submersion/features/agent_access/data/records/record_entity.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/records/record_scope.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

/// The lists a diver keeps to fill records from: tags, types, roles, presets
/// and templates. Tank presets are the stored rows; built-ins are constants
/// of the app, not records.
List<RecordEntry> catalogEntries(RecordRepositories r) => [
  RecordEntity<Tag>(
    name: 'tags',
    table: 'tags',
    scope: owned(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.tags.getTagById),
    document: tagDocument,
    summaryKeys: const ['name', 'scopes'],
  ),
  RecordEntity<DiveTypeEntity>(
    name: 'dive_types',
    table: 'dive_types',
    scope: ownedOrBuiltIn(),
    orderBy: 'r0.sort_order, r0.name',
    load: (ids, _) => loadEach(ids, r.diveTypes.getDiveTypeById),
    document: diveTypeDocument,
    summaryKeys: const ['name', 'is_built_in'],
  ),
  RecordEntity<DiveRole>(
    name: 'dive_roles',
    table: 'dive_roles',
    scope: ownedOrBuiltIn(),
    orderBy: 'r0.sort_order, r0.name',
    load: (ids, _) => loadEach(ids, r.diveRoles.getDiveRoleById),
    document: diveRoleDocument,
    summaryKeys: const ['name', 'is_built_in'],
  ),
  RecordEntity<TankPresetEntity>(
    name: 'tank_presets',
    table: 'tank_presets',
    scope: owned(),
    orderBy: 'r0.sort_order, r0.name',
    load: (ids, _) => loadEach(ids, r.tankPresets.getPresetById),
    document: tankPresetDocument,
    summaryKeys: const ['display_name', 'volume_l', 'working_pressure_bar'],
  ),
  RecordEntity<WeightPreset>(
    name: 'weight_presets',
    table: 'weight_presets',
    scope: owned(),
    orderBy: 'r0.sort_order, r0.display_name',
    load: (ids, _) => loadEach(ids, r.weightPresets.getPresetById),
    document: weightPresetDocument,
    summaryKeys: const ['display_name', 'notes'],
    blocks: {
      'entries': (preset, _) async => [
        for (final e in preset.entries) weightPresetEntryDocument(e),
      ],
    },
  ),
  RecordEntity<ChecklistTemplate>(
    name: 'checklist_templates',
    table: 'checklist_templates',
    scope: ownedOrNull(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.checklistTemplates.getTemplateById),
    document: checklistTemplateDocument,
    summaryKeys: const ['name', 'description'],
    blocks: {
      'items': (template, _) async => {
        'sections': [
          for (final s in await r.checklistTemplates.getSectionsForTemplate(
            template.id,
          ))
            checklistTemplateSectionDocument(s),
        ],
        'items': [
          for (final i in await r.checklistTemplates.getItemsForTemplate(
            template.id,
          ))
            checklistTemplateItemDocument(i),
        ],
      },
    },
  ),
  RecordEntity<PreDiveChecklistTemplate>(
    name: 'pre_dive_templates',
    table: 'pre_dive_checklist_templates',
    scope: ownedOrBuiltIn(),
    orderBy: 'r0.name COLLATE NOCASE',
    load: (ids, _) => loadEach(ids, r.preDiveTemplates.getTemplateById),
    document: preDiveTemplateDocument,
    summaryKeys: const ['name', 'category', 'is_built_in'],
    blocks: {
      'items': (template, _) async => {
        'sections': [
          for (final s in await r.preDiveTemplates.getSectionsForTemplate(
            template.id,
          ))
            preDiveTemplateSectionDocument(s),
        ],
        'items': [
          for (final i in await r.preDiveTemplates.getItemsForTemplate(
            template.id,
          ))
            preDiveTemplateItemDocument(i),
        ],
      },
    },
  ),
];
