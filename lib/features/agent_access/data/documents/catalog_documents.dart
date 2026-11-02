import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template_section.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

Map<String, Object?> tagDocument(Tag t) => {
  'id': t.id,
  'diver_id': t.diverId,
  'name': t.name,
  'color_hex': t.colorHex,
  'scopes': [for (final s in t.scopes) s.name],
};

Map<String, Object?> diveTypeDocument(DiveTypeEntity t) => {
  'id': t.id,
  'diver_id': t.diverId,
  'name': t.name,
  'short_name': t.shortName,
  'is_built_in': t.isBuiltIn,
  'sort_order': t.sortOrder,
  'show_in_detail_header': t.showInDetailHeader,
  'show_in_list_view': t.showInListView,
};

Map<String, Object?> diveRoleDocument(DiveRole r) => {
  'id': r.id,
  'diver_id': r.diverId,
  'name': r.name,
  'is_built_in': r.isBuiltIn,
  'sort_order': r.sortOrder,
};

Map<String, Object?> tankPresetDocument(TankPresetEntity p) => {
  'id': p.id,
  'diver_id': p.diverId,
  'name': p.name,
  'display_name': p.displayName,
  'volume_l': p.volumeLiters,
  'working_pressure_bar': p.workingPressureBar,
  'rated_capacity_cuft': p.ratedCapacityCuft,
  'material': p.material.name,
  'description': p.description,
  'sort_order': p.sortOrder,
};

Map<String, Object?> weightPresetDocument(WeightPreset p) => {
  'id': p.id,
  'diver_id': p.diverId,
  'display_name': p.displayName,
  'notes': p.notes,
  'sort_order': p.sortOrder,
};

Map<String, Object?> weightPresetEntryDocument(WeightPresetEntry e) => {
  'id': e.id,
  'preset_id': e.presetId,
  'type': e.weightType.name,
  'amount_kg': e.amountKg,
  'label': e.label,
  'notes': e.notes,
  'sort_order': e.sortOrder,
};

Map<String, Object?> checklistTemplateDocument(ChecklistTemplate t) => {
  'id': t.id,
  'diver_id': t.diverId,
  'name': t.name,
  'description': t.description,
};

Map<String, Object?> checklistTemplateSectionDocument(
  ChecklistTemplateSection s,
) => {
  'id': s.id,
  'template_id': s.templateId,
  'title': s.title,
  'sort_order': s.sortOrder,
};

Map<String, Object?> checklistTemplateItemDocument(ChecklistTemplateItem i) => {
  'id': i.id,
  'template_id': i.templateId,
  'section_id': i.sectionId,
  'title': i.title,
  'notes': i.notes,
  'due_offset_days': i.dueOffsetDays,
  'sort_order': i.sortOrder,
};

Map<String, Object?> preDiveTemplateDocument(PreDiveChecklistTemplate t) => {
  'id': t.id,
  'diver_id': t.diverId,
  'name': t.name,
  'description': t.description,
  'category': t.category,
  'strict_order': t.strictOrder,
  'is_built_in': t.isBuiltIn,
  'builtin_key': t.builtinKey,
};

Map<String, Object?> preDiveTemplateSectionDocument(
  PreDiveChecklistTemplateSection s,
) => {
  'id': s.id,
  'template_id': s.templateId,
  'title': s.title,
  'sort_order': s.sortOrder,
};

/// Item values stay bare because the unit is stored with them, in
/// `value_unit`.
Map<String, Object?> preDiveTemplateItemDocument(
  PreDiveChecklistTemplateItem i,
) => {
  'id': i.id,
  'template_id': i.templateId,
  'section_id': i.sectionId,
  'title': i.title,
  'notes': i.notes,
  'sort_order': i.sortOrder,
  'item_type': i.itemType.name,
  'value_label': i.valueLabel,
  'value_unit': i.valueUnit,
  'value_min': i.valueMin,
  'value_max': i.valueMax,
  'is_required': i.isRequired,
  'equipment_id': i.equipmentId,
};
