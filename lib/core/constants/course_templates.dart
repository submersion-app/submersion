import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

/// One requirement row a template will copy into course_requirements.
class CourseTemplateRequirement {
  final String name;
  final RequirementKind kind;
  final int targetCount;

  const CourseTemplateRequirement(this.name, this.kind, [this.targetCount = 1]);
}

/// A starter set of requirements for a common course. Templates are a copy
/// source only: picking one inserts ordinary editable rows and the template
/// carries no identity into the database. Requirement names are data (they
/// become user-owned rows), so they are deliberately not localized --
/// mirroring built-in reference data seeds.
class CourseTemplate {
  final String id;
  final String name;
  final List<CourseTemplateRequirement> requirements;

  const CourseTemplate({
    required this.id,
    required this.name,
    required this.requirements,
  });
}

/// Agency-neutral starter templates (PADI-shaped counts, editable after
/// instantiation). Deliberately NOT authoritative curricula: agencies revise
/// standards and vary by region, so these are conveniences, never truth.
abstract final class CourseTemplateCatalog {
  static const List<CourseTemplate> templates = [
    CourseTemplate(
      id: 'advanced-open-water',
      name: 'Advanced Open Water',
      requirements: [
        CourseTemplateRequirement('Deep adventure dive', RequirementKind.dive),
        CourseTemplateRequirement(
          'Navigation adventure dive',
          RequirementKind.dive,
        ),
        CourseTemplateRequirement(
          'Elective adventure dives',
          RequirementKind.dive,
          3,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'rescue-diver',
      name: 'Rescue Diver',
      requirements: [
        CourseTemplateRequirement(
          'EFR / CPR certification current',
          RequirementKind.checklist,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
        CourseTemplateRequirement(
          'Self-rescue review',
          RequirementKind.checklist,
        ),
        CourseTemplateRequirement(
          'Rescue exercise dives',
          RequirementKind.dive,
          2,
        ),
        CourseTemplateRequirement(
          'Rescue scenario dives',
          RequirementKind.dive,
          2,
        ),
      ],
    ),
    CourseTemplate(
      id: 'deep-specialty',
      name: 'Deep Diver',
      requirements: [
        CourseTemplateRequirement(
          'Deep training dives',
          RequirementKind.dive,
          4,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'night-specialty',
      name: 'Night Diver',
      requirements: [
        CourseTemplateRequirement(
          'Night training dives',
          RequirementKind.dive,
          3,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'navigation-specialty',
      name: 'Underwater Navigator',
      requirements: [
        CourseTemplateRequirement(
          'Navigation training dives',
          RequirementKind.dive,
          3,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'nitrox',
      name: 'Enriched Air Nitrox',
      requirements: [
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
        CourseTemplateRequirement(
          'Practical application session',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'cavern-intro',
      name: 'Cavern / Intro to Cave',
      requirements: [
        CourseTemplateRequirement(
          'Cavern training dives',
          RequirementKind.dive,
          4,
        ),
        CourseTemplateRequirement(
          'Line and reel drills',
          RequirementKind.checklist,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
    CourseTemplate(
      id: 'wreck-specialty',
      name: 'Wreck Diver',
      requirements: [
        CourseTemplateRequirement(
          'Wreck training dives',
          RequirementKind.dive,
          4,
        ),
        CourseTemplateRequirement(
          'Knowledge development',
          RequirementKind.checklist,
        ),
      ],
    ),
  ];
}
