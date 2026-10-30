import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/checklists/data/repositories/checklist_template_repository.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template_section.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_session_repository.dart';
import 'package:submersion/features/pre_dive/data/repositories/pre_dive_template_repository.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template_section.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

import '../story/destination_life.dart';
import '../story/story_plan.dart';
import 'demo_images.dart';
import 'seed_context.dart';
import 'trip_seeder.dart';

/// Dive plans (an open-circuit deco plan, a rebreather plan and a scooter
/// mission), checklists before a dive and before a trip, and travel
/// documents.
class PlanningSeeder implements DemoSeeder {
  @override
  String get name => 'plans, checklists and documents';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    await _plans(ctx);
    await _checklists(ctx);
    await _documents(ctx);
  }

  Future<void> _plans(DemoSeedContext ctx) async {
    final plans = DivePlanRepository();
    // The deepest home wreck the diver has dived, planned again on trimix.
    final wreck = ctx.plan.dives
        .where((d) => d.destination.key == 'home')
        .reduce(
          (a, b) =>
              homeSiteDepthM[a.siteId]! >= homeSiteDepthM[b.siteId]! ? a : b,
        );
    final now = ctx.anchor;
    const back = DiveTank(
      id: 'demo-plan-tank-back',
      volume: 25.8,
      workingPressure: 237.3,
      startPressure: 227.5,
      gasMix: GasMix(o2: 21, he: 35),
      role: TankRole.backGas,
    );
    const deco = DiveTank(
      id: 'demo-plan-tank-deco',
      volume: 5.7,
      workingPressure: 207,
      startPressure: 200,
      gasMix: GasMix(o2: 50),
      role: TankRole.deco,
      order: 1,
    );
    await plans.savePlan(
      DivePlan(
        id: 'demo-plan-wreck',
        name: 'Home wreck at 45 m, trimix',
        siteId: ctx.siteId(wreck.siteId),
        gfLow: 30,
        gfHigh: 75,
        tanks: const [back, deco],
        segments: [
          PlanSegment(
            id: 'demo-seg-1',
            targetDepth: 45,
            durationSeconds: 180,
            tankId: back.id,
            gasMix: back.gasMix,
            order: 0,
          ),
          PlanSegment(
            id: 'demo-seg-2',
            targetDepth: 45,
            durationSeconds: 1200,
            tankId: back.id,
            gasMix: back.gasMix,
            order: 1,
          ),
        ],
        equipmentIds: [ctx.equipment['twin']!, ctx.equipment['stage-1']!],
        createdAt: now,
        updatedAt: now,
      ),
    );
    const dil = DiveTank(
      id: 'demo-plan-ccr-dil',
      volume: 3,
      workingPressure: 232,
      startPressure: 200,
      gasMix: GasMix(o2: 21, he: 35),
      role: TankRole.diluent,
    );
    await plans.savePlan(
      DivePlan(
        id: 'demo-plan-ccr',
        name: 'Rebreather reef wall, 45 m',
        mode: PlanMode.ccr,
        gfLow: 40,
        gfHigh: 80,
        tanks: const [dil],
        segments: [
          PlanSegment(
            id: 'demo-seg-ccr',
            targetDepth: 45,
            durationSeconds: 2400,
            tankId: dil.id,
            gasMix: dil.gasMix,
            setpointBar: 1.3,
          ),
        ],
        equipmentIds: [ctx.equipment['rebreather']!],
        createdAt: now,
        updatedAt: now,
      ),
    );
    const scooter = ScooterSpec(
      name: 'Seacraft Future',
      ratedSpeedMps: 1.4,
      burnTimeSeconds: 5400,
    );
    await plans.savePlan(
      DivePlan(
        id: 'demo-plan-scooter',
        name: 'Scooter run along the wall',
        tanks: const [back],
        segments: [
          PlanSegment(
            id: 'demo-seg-dpv',
            targetDepth: 30,
            durationSeconds: 2700,
            tankId: back.id,
            gasMix: back.gasMix,
          ),
        ],
        mission: DpvMission(
          legs: [
            for (var i = 0; i < 3; i++)
              MissionLeg(
                id: 'demo-leg-$i',
                order: i,
                label: [
                  'Out along the wall',
                  'Cross the sand',
                  'Back to the line',
                ][i],
                distanceM: [900.0, 400.0, 1100.0][i],
                depthM: 30,
                headingDeg: [40.0, 130.0, 220.0][i],
              ),
          ],
          team: [
            const MissionMember(
              id: 'demo-member-1',
              order: 0,
              displayName: 'Alex Rivera',
              diverId: DemoSeedContext.diverId,
              sacBottom: 14,
              scooter: scooter,
            ),
            MissionMember(
              id: 'demo-member-2',
              order: 1,
              displayName: 'Mara Lindqvist',
              buddyId: ctx.buddyId('p-mara'),
              sacBottom: 12,
              scooter: scooter,
            ),
          ],
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _checklists(DemoSeedContext ctx) async {
    final now = ctx.anchor;
    final templates = PreDiveTemplateRepository();
    final template = await templates.createTemplate(
      PreDiveChecklistTemplate(
        id: 'demo-predive-ccr',
        name: 'My rebreather build',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await templates.saveSections(template.id, [
      PreDiveChecklistTemplateSection(
        id: 'demo-predive-sec-1',
        templateId: template.id,
        title: 'Before the dive',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final titles = [
      'Scrubber packed and logged',
      'Cells calibrated',
      'Positive and negative checks',
      'Bailout analysed and labelled',
    ];
    // The gear the checklist names, each item checked over before the dive.
    const gear = [
      ('rebreather', 'Rebreather'),
      ('reg-stage-bailout', 'Bailout regulator'),
      ('computer-tech', 'Technical computer'),
    ];
    await templates.saveItems(template.id, [
      for (var i = 0; i < titles.length; i++)
        PreDiveChecklistTemplateItem(
          id: 'demo-predive-item-$i',
          templateId: template.id,
          sectionId: 'demo-predive-sec-1',
          title: titles[i],
          sortOrder: i,
          isRequired: true,
          createdAt: now,
          updatedAt: now,
        ),
      for (var i = 0; i < gear.length; i++)
        PreDiveChecklistTemplateItem(
          id: 'demo-predive-gear-$i',
          templateId: template.id,
          sectionId: 'demo-predive-sec-1',
          title: gear[i].$2,
          sortOrder: titles.length + i,
          itemType: PreDiveItemType.equipment,
          equipmentId: ctx.equipment[gear[i].$1],
          isRequired: true,
          createdAt: now,
          updatedAt: now,
        ),
    ]);
    final saved = (await templates.getTemplateById(template.id))!;
    final dive = ctx.plan.dives.lastWhere((d) => d.diveMode == 'ccr');
    const sessionId = 'demo-predive-session';
    await PreDiveSessionRepository().startSession(
      template: saved,
      items: [
        for (var i = 0; i < titles.length; i++)
          PreDiveSessionItem(
            id: 'demo-session-item-$i',
            sessionId: sessionId,
            sectionId: 'demo-session-section',
            createdAt: dive.start,
            updatedAt: dive.start,
            title: titles[i],
            sortOrder: i,
            isRequired: true,
            state: PreDiveItemState.done,
            completedAt: dive.start.subtract(const Duration(minutes: 40)),
          ),
        for (var i = 0; i < gear.length; i++)
          PreDiveSessionItem(
            id: 'demo-session-gear-$i',
            sessionId: sessionId,
            sectionId: 'demo-session-section',
            createdAt: dive.start,
            updatedAt: dive.start,
            title: gear[i].$2,
            sortOrder: titles.length + i,
            isRequired: true,
            itemType: PreDiveItemType.equipment,
            equipmentId: ctx.equipment[gear[i].$1],
            state: PreDiveItemState.done,
            completedAt: dive.start.subtract(const Duration(minutes: 35)),
          ),
      ],
      sections: [
        PreDiveSessionSection(
          id: 'demo-session-section',
          sessionId: sessionId,
          title: 'Before the dive',
          createdAt: dive.start,
          updatedAt: dive.start,
        ),
      ],
      diverId: DemoSeedContext.diverId,
      diveId: ctx.diveId(dive.number),
      equipmentSetId: ctx.equipmentSets['ccr'],
    );

    final packing = ChecklistTemplateRepository();
    final pack = await packing.createTemplate(
      ChecklistTemplate(
        id: 'demo-packing',
        name: 'Liveaboard packing list',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await packing.saveSections(pack.id, [
      ChecklistTemplateSection(
        id: 'demo-packing-sec',
        templateId: pack.id,
        title: 'Two weeks before',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    await packing.saveItems(pack.id, [
      for (final (i, title) in [
        'Book nitrox',
        'Service the regulator',
        'Spare mask strap',
        'Charge the lights',
      ].indexed)
        ChecklistTemplateItem(
          id: 'demo-packing-$i',
          templateId: pack.id,
          sectionId: 'demo-packing-sec',
          title: title,
          dueOffsetDays: -14 + i,
          sortOrder: i,
          createdAt: now,
          updatedAt: now,
        ),
    ]);
  }

  Future<void> _documents(DemoSeedContext ctx) async {
    final docs = DocumentRepository();
    final now = ctx.anchor;
    Future<void> save(
      String id,
      DocumentOwner owner,
      DocumentType type,
      String title,
      List<String> lines, {
      DateTime? expiry,
    }) async {
      final bytes = DemoImages.page(heading: title, lines: lines);
      await docs.save(
        Document(
          id: id,
          diverId: DemoSeedContext.diverId,
          owner: owner,
          type: type,
          title: title,
          issuer: 'Sample issuer',
          issueDate: now,
          expiryDate: expiry,
          createdAt: now,
          updatedAt: now,
        ),
        [
          DocumentPage(
            id: '$id-page',
            documentId: id,
            pageIndex: 0,
            fileName: '$id.png',
            mimeType: 'image/png',
            sizeBytes: bytes.length,
            bytes: bytes,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        tagIds: type == DocumentType.receipt ? [ctx.tags['Training']!] : null,
      );
    }

    const upcoming = DocumentOwner(
      DocumentOwnerKind.trip,
      TripSeeder.upcomingTripId,
    );
    await save(
      'demo-doc-booking',
      upcoming,
      DocumentType.booking,
      'Liveaboard booking',
      [
        'MV Coral Spirit, lower deck twin',
        '10 nights, full board',
        'Reference CS-2207',
      ],
    );
    await save(
      'demo-doc-permit',
      upcoming,
      DocumentType.permit,
      'Marine park permit',
      ['Valid for the trip dates', 'Keep a copy on board'],
      expiry: DateTime(now.year, now.month + 3, now.day),
    );
    final ccrCourse = ctx.plan.courses.firstWhere(
      (c) => c.level == CertLevel.ccr,
    );
    await save(
      'demo-doc-receipt',
      DocumentOwner(DocumentOwnerKind.course, ccrCourse.id),
      DocumentType.receipt,
      'Rebreather course receipt',
      ['CCR Diver course', 'Theory, pool and 5 open water dives'],
    );
    await save(
      'demo-doc-manual',
      DocumentOwner(DocumentOwnerKind.equipment, ctx.equipment['rebreather']!),
      DocumentType.manual,
      'Rebreather quick reference',
      ['Pre-dive checks', 'Cell calibration', 'Bailout procedure'],
    );
  }
}
