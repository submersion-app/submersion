# PDF Templates & Reports Design

## Overview

Implement multiple PDF export templates for dive logbooks with template selection UI, page size options, and optional certification card inclusion.

## Requirements

From REMAINING_TASKS.md (10.3 Reports & Printing):
- Multiple PDF templates (Simple, Detailed, Professional, PADI-style, NAUI-style)
- Template selection in export dialog
- Professional template with space for signatures, stamps
- Include certification cards in PDF export

## Template Specifications

### 1. Simple Template
- **Density:** 15-20 dives per page
- **Format:** Table with columns: # | Date | Site | Depth | Time | Temp
- **Style:** Black/white, minimal spacing, no decorations
- **Includes:** Header (title, date range, diver), footer (page number)
- **Excludes:** Notes, signatures, ratings, certification cards

### 2. Detailed Template (enhanced current)
- **Density:** 3 dives per page
- **Format:** Card-style entries with all dive data
- **Includes:** All metrics, notes, gas info, tank data, rating stars, signatures
- **Certification cards:** Optional page after summary

### 3. Professional Template
- **Density:** 2 dives per page
- **Format:** Formal log entries with verification areas
- **Signature box:** 60x25mm labeled area
- **Stamp area:** 40x40mm box for official stamps
- **Additional:** Printed name line, certification number field, date field
- **Use case:** Instructors, divemasters, agency verification

### 4. PADI-style Template
- **Colors:** PADI blue (#003087) accents
- **Layout:** Mimics PADI paper logbook format
- **Sections:** Dive Data | Conditions | Equipment | Comments
- **Features:** Buddy sign-off row, "Training Dive" badge indicator
- **Cert cards:** PADI certifications highlighted

### 5. NAUI-style Template
- **Colors:** NAUI green (#006B5A) accents
- **Layout:** Emphasis on dive planning data
- **Sections:** Pre-dive planning, dive data, post-dive
- **Features:** Instructor verification box with NAUI number field
- **Cert cards:** NAUI certifications highlighted

## Page Sizes

- A4 (210 x 297 mm) - Default
- Letter (8.5 x 11 in / 216 x 279 mm)

## Data Model

### New Enums (lib/core/constants/pdf_templates.dart)

```dart
enum PdfTemplate {
  simple,
  detailed,
  professional,
  padiStyle,
  nauiStyle,
}

enum PdfPageSize {
  a4,
  letter,
}

class PdfExportOptions {
  final PdfTemplate template;
  final PdfPageSize pageSize;
  final bool includeCertificationCards;

  const PdfExportOptions({
    this.template = PdfTemplate.detailed,
    this.pageSize = PdfPageSize.a4,
    this.includeCertificationCards = false,
  });
}
```

### Template Builder Interface

```dart
abstract class PdfTemplateBuilder {
  PdfTemplate get templateType;
  String get displayName;
  String get description;

  Future<List<int>> buildPdf({
    required List<Dive> dives,
    required PdfPageSize pageSize,
    required String title,
    Map<String, List<Signature>>? diveSignatures,
    List<Certification>? certifications,
    Diver? diver,
  });
}
```

## File Structure

```
lib/
  core/
    constants/
      pdf_templates.dart              # Enums and PdfExportOptions
    services/
      pdf_templates/
        pdf_template_builder.dart     # Abstract base class
        pdf_template_factory.dart     # Factory for getting builders
        pdf_template_simple.dart      # Simple template
        pdf_template_detailed.dart    # Detailed template (extracted)
        pdf_template_professional.dart # Professional template
        pdf_template_padi.dart        # PADI-style template
        pdf_template_naui.dart        # NAUI-style template
        pdf_shared_components.dart    # Shared PDF widgets
  features/
    transfer/
      presentation/
        widgets/
          pdf_export_dialog.dart      # Template selection dialog
```

## UI Flow

1. User taps "PDF Logbook" in Transfer page
2. `PdfExportDialog` opens as bottom sheet
3. User selects:
   - Template (radio buttons with preview icons)
   - Page size (A4 / Letter toggle)
   - Include certification cards (checkbox)
4. User taps "Export"
5. `ExportService.exportDivesToPdf(options)` called
6. Template builder generates PDF
7. Share sheet opens with PDF file

## Implementation Plan

### Phase 1: Foundation
1. Create `pdf_templates.dart` with enums and options class
2. Create `PdfTemplateBuilder` abstract class
3. Create `PdfTemplateFactory`
4. Extract current PDF logic into `PdfTemplateDetailed`

### Phase 2: Templates
5. Implement `PdfTemplateSimple`
6. Implement `PdfTemplateProfessional`
7. Implement `PdfTemplatePadi`
8. Implement `PdfTemplateNaui`

### Phase 3: Certification Cards
9. Create shared `buildCertificationCardsPage()` component
10. Integrate cert cards into applicable templates
11. Load cert card images from BLOB storage

### Phase 4: UI
12. Create `PdfExportDialog` widget
13. Update Transfer page to show dialog before export
14. Update `ExportNotifier` to accept options

### Phase 5: Testing & Polish
15. Test all templates with various dive counts
16. Test page size rendering
17. Test certification card display
18. Update REMAINING_TASKS.md

## Dependencies

- Existing: `pdf` package, `pdf/widgets.dart`
- Existing: `SignatureStorageService` for signatures
- Existing: `Certification` entity with `photoFront`/`photoBack` BLOBs

## Notes

- Preserve all existing signature functionality
- Keep backward compatibility (default to Detailed template)
- Agency-style templates are approximations, not official reproductions
