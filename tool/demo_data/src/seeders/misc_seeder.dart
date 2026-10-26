import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/connections/data/repositories/connection_map_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';
import 'package:submersion/features/connections/domain/views/map_spec.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart';
import 'package:submersion/features/insights/data/repositories/observation_dismissals_repository.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/safety/data/repositories/emergency_chamber_repository.dart';
import 'package:submersion/features/safety/data/repositories/incident_repository.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

import '../story/story_plan.dart';
import 'seed_context.dart';

/// The smaller features: saved searches, rules and what they did, incidents
/// and the lessons from them, a chamber near home, a dismissed insight,
/// list layouts, a connection map and app settings.
class MiscSeeder implements DemoSeeder {
  @override
  String get name => 'queries, rules, safety and views';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    const diver = DemoSeedContext.diverId;
    final deep = ConditionNode(
      FieldPath(['depth']),
      QueryOp.gt,
      const NumberValue(40, null),
    );
    final queries = SavedQueryRepository();
    await queries.create(
      subject: QuerySubject.dives,
      name: 'Deeper than 40 m',
      node: deep,
      diverId: diver,
    );
    await queries.create(
      subject: QuerySubject.dives,
      name: 'Long dives',
      node: ConditionNode(
        FieldPath(['runtime']),
        QueryOp.gte,
        const NumberValue(60, null),
      ),
      diverId: diver,
    );

    final rules = RuleRepository();
    final ruleId = await rules.create(
      diverId: diver,
      subject: RuleSubject.dives,
      name: 'Tag deep dives',
      triggers: const {RuleTrigger.afterImport, RuleTrigger.afterManualCreate},
      condition: deep,
      actions: [
        const DiveMembershipAction(
          DiveCollection.diveTypes,
          MembershipMode.add,
          ['deep'],
        ),
      ],
    );
    final deepDives = ctx.plan.dives
        .where((d) => d.targetMaxDepth > 40)
        .take(3);
    await RuleRunRepository().insertRun(
      diverId: diver,
      trigger: RuleRunTrigger.onDemandAll,
      ranAt: ctx.anchor.subtract(const Duration(days: 30)),
      changes: [
        for (final d in deepDives)
          RuleChange(
            subject: RuleSubject.dives,
            targetId: ctx.diveId(d.number),
            ruleId: ruleId,
            ruleName: 'Tag deep dives',
            field: 'diveTypes',
            before: 'technical',
            after: 'technical, deep',
          ),
      ],
    );

    final incidents = IncidentRepository();
    final freeFlow = ctx.plan.dives.firstWhere(
      (d) => d.destination.key == 'home' && d.number > 60,
    );
    await incidents.createIncident(
      occurredAt: freeFlow.start.add(const Duration(minutes: 25)),
      category: IncidentCategory.equipment,
      severity: IncidentSeverity.moderate,
      narrative:
          'Second stage free-flowed at 22 m in 6 degree water. Switched to the octopus, buddy close, controlled ascent.',
      lessonsLearned:
          'Environmentally sealed first stage for cold water; breathe the reg before descending.',
      diveId: ctx.diveId(freeFlow.number),
      diverId: diver,
      equipmentId: ctx.equipment['reg'],
    );
    final current = ctx.plan.dives.firstWhere(
      (d) => d.destination.key == 'similan' || d.destination.key == 'maldives',
      orElse: () => ctx.plan.dives[150],
    );
    await incidents.createIncident(
      occurredAt: current.start.add(const Duration(minutes: 40)),
      category: IncidentCategory.buddySeparation,
      severity: IncidentSeverity.minor,
      narrative:
          'Lost the group in a down current on the corner. Surfaced after a minute, marker deployed, picked up by the boat.',
      lessonsLearned: 'Agree a lost-buddy procedure before every current dive.',
      diveId: ctx.diveId(current.number),
      diverId: diver,
    );

    final home = ctx.plan.sites.firstWhere(
      (s) => ctx.plan.dives.any(
        (d) => d.siteId == s.id && d.destination.key == 'home',
      ),
    );
    await EmergencyChamberRepository().createChamber(
      name: 'Regional hyperbaric unit (sample)',
      country: home.country ?? 'Deutschland',
      phone: '+49 000 0000000',
      city: home.region,
      latitude: home.latitude + 0.2,
      longitude: home.longitude + 0.2,
      notes: 'Call the dive emergency line first.',
      diverId: diver,
    );

    await ObservationDismissalsRepository().dismiss(
      diverId: diver,
      rule: ObservationRuleId.values.first,
      fingerprint: 'demo-dismissed',
    );

    final views = ViewConfigRepository(ctx.db);
    await views.ensureBuiltInPresets(diver);
    await views.saveTableConfig(diver, TableViewConfig.defaultConfig());

    await ConnectionMapRepository().create(
      diverId: diver,
      name: 'Who I dive with, and where',
      spec: MapSpec(
        kinds: const {
          ConnectionKind.buddy,
          ConnectionKind.site,
          ConnectionKind.trip,
        },
        links: {
          KindLink(ConnectionKind.buddy, ConnectionKind.site),
          KindLink(ConnectionKind.site, ConnectionKind.trip),
        },
      ),
    );

    await AppSettingsRepository().setRawSetting('demo_sample_logbook', 'true');
    if (ctx.plan.dives.any((d) => d.phase == StoryPhase.rebreather)) {
      await AppSettingsRepository().setRawSetting(
        'demo_story',
        'recreational, technical, rebreather',
      );
    }
  }
}
