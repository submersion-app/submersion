import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';

import '../story/story_plan.dart';
import 'demo_images.dart';
import 'seed_context.dart';

/// Certifications (with generated card images), the courses behind them, a
/// custom agency, and certification currency. Requirement-to-dive links come
/// after the dives exist, in [TrainingLinksSeeder].
class TrainingSeeder implements DemoSeeder {
  @override
  String get name => 'certifications and courses';

  static const _agency = <CertLevel, String>{
    CertLevel.openWater: 'padi',
    CertLevel.advanced: 'padi',
    CertLevel.nitrox: 'padi',
    CertLevel.rescue: 'padi',
    CertLevel.deep: 'padi',
    CertLevel.decoProcedures: 'tdi',
    CertLevel.trimix: 'tdi',
    CertLevel.ccr: 'tdi',
  };

  static const _level = <CertLevel, String>{
    CertLevel.openWater: 'openWater',
    CertLevel.advanced: 'advancedOpenWater',
    CertLevel.nitrox: 'nitrox',
    CertLevel.rescue: 'rescue',
    CertLevel.deep: 'masterDiver',
    CertLevel.decoProcedures: 'decompression',
    CertLevel.trimix: 'trimix',
    CertLevel.ccr: 'rebreather',
  };

  static String _people(DemoSeedContext ctx, String? id) =>
      ctx.plan.people.firstWhere((p) => p.id == id).name;

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final certs = CertificationRepository();
    final courses = CourseRepository();
    final requirements = CourseRequirementRepository();
    final courseById = {for (final c in ctx.plan.courses) c.id: c};

    for (final c in ctx.plan.courses) {
      await courses.createCourse(
        Course(
          id: c.id,
          diverId: DemoSeedContext.diverId,
          name: c.name,
          agency: _agency[c.level]!.toUpperCase(),
          startDate: c.start,
          completionDate: c.end,
          instructorId: ctx.buddyId(c.instructorId),
          instructorName: _people(ctx, c.instructorId),
          certificationId: 'demo-cert-${c.level.name}',
          location: ctx.plan.dives
              .firstWhere((d) => d.courseId == c.id)
              .destination
              .label,
          createdAt: c.start,
          updatedAt: c.end,
        ),
      );
      final trainingDives = ctx.plan.dives
          .where((d) => d.courseId == c.id)
          .length;
      final diveReq = await requirements.createRequirement(
        courseId: c.id,
        name: 'Open water training dives',
        kind: RequirementKind.dive,
        targetCount: trainingDives,
      );
      ctx.courseDiveRequirements[c.id] = diveReq.id;
      final review = await requirements.createRequirement(
        courseId: c.id,
        name: 'Knowledge review',
        kind: RequirementKind.checklist,
      );
      await requirements.setChecklistComplete(review.id, true);
    }

    var n = 0;
    for (final cert in ctx.plan.certs) {
      final agency = _agency[cert.level]!;
      final number =
          '${agency.toUpperCase()}-${(240117 + n * 3911).toString()}';
      final issued =
          '${cert.issueDate.year}-${cert.issueDate.month.toString().padLeft(2, '0')}';
      final course = cert.courseId == null ? null : courseById[cert.courseId];
      await certs.createCertification(
        Certification(
          id: 'demo-cert-${cert.level.name}',
          diverId: DemoSeedContext.diverId,
          name: cert.level.title,
          agency: agency,
          level: _level[cert.level],
          cardNumber: number,
          issueDate: cert.issueDate,
          instructorName: course == null
              ? null
              : _people(ctx, course.instructorId),
          instructorId: course == null
              ? null
              : ctx.buddyId(course.instructorId),
          courseId: course?.id,
          photoFront: DemoImages.card(
            agency: agency.toUpperCase(),
            title: cert.level.title,
            holder: 'Alex Rivera',
            number: number,
            issued: issued,
            color: n.isEven ? 0x1565C0 : 0x00695C,
          ),
          photoBack: DemoImages.card(
            agency: agency.toUpperCase(),
            title: cert.level.title,
            holder: 'Alex Rivera',
            number: number,
            issued: issued,
            color: 0,
            back: true,
          ),
          createdAt: cert.issueDate,
          updatedAt: cert.issueDate,
        ),
      );
      n++;
    }

    // A local club's own rating, through the custom agency feature.
    final custom = CustomCertificationRepository();
    final club = await custom.createAgency(
      diverId: DemoSeedContext.diverId,
      name: 'Lake Club Academy',
      colorArgb: 0xFF2E7D32,
      isShared: false,
    );
    final ice = await custom.createLevel(
      diverId: DemoSeedContext.diverId,
      agencyId: club.id,
      name: 'Cold Water Diver',
      isProgression: false,
      isShared: false,
    );
    final coldIssued = ctx.plan.dives[40].start;
    await certs.createCertification(
      Certification(
        id: 'demo-cert-cold-water',
        diverId: DemoSeedContext.diverId,
        name: 'Cold Water Diver',
        agency: club.id,
        level: ice.id,
        cardNumber: 'LCA-0711',
        issueDate: coldIssued,
        createdAt: coldIssued,
        updatedAt: coldIssued,
      ),
    );

    // Currency: a refresher logged on the rebreather rating, and the deco
    // clock muted because the diver tracks it elsewhere.
    final currency = CertificationCurrencyRepository();
    final ccrIssued = ctx.plan.certs
        .firstWhere((c) => c.level == CertLevel.ccr)
        .issueDate;
    final refresher = DateTime(
      ccrIssued.year,
      ccrIssued.month,
      ccrIssued.day + 20,
    );
    await currency.createEvent(
      CurrencyEvent(
        id: 'demo-currency-ccr-refresher',
        certificationId: 'demo-cert-ccr',
        eventType: CurrencyEventType.refresher,
        eventDate: refresher,
        ruleId: 'rebreather_currency',
        provider: 'Lake Club Academy',
        createdAt: refresher,
        updatedAt: refresher,
      ),
    );
    await currency.upsertPref(
      CurrencyPref(
        id: 'demo-currency-pref-deco',
        certificationId: 'demo-cert-decoProcedures',
        ruleId: 'deco_currency',
        muted: true,
        createdAt: refresher,
        updatedAt: refresher,
      ),
    );
  }
}

/// Links each course's training dives to its dive requirement, once the
/// dives exist.
class TrainingLinksSeeder implements DemoSeeder {
  @override
  String get name => 'course requirement dives';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final requirements = CourseRequirementRepository();
    for (final c in ctx.plan.courses) {
      final requirementId = ctx.courseDiveRequirements[c.id]!;
      for (final d in ctx.plan.dives.where((d) => d.courseId == c.id)) {
        await requirements.linkDive(
          requirementId: requirementId,
          diveId: ctx.diveId(d.number),
        );
      }
    }
  }
}
