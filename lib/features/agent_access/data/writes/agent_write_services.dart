import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/currency_writes.dart'
    show AppStrings;
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/write_applier.dart';
import 'package:submersion/features/agent_access/data/writes/write_catalog.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan_store.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';

/// What the write tools need. Built per request on the stateless protocol,
/// so it only holds things: [plans] and [confirmer] outlive it, and nothing
/// here touches the database until a tool runs.
class AgentWriteServices {
  AgentWriteServices({
    required RecordRepositories records,
    required this.plans,
    required WriteConfirmer confirmer,
    required bool Function() confirmEnabled,
    void Function(Iterable<String>) afterDiveWrites = refreshAfterRuleWrites,
    this.rearmDocuments,
    GearReminderRefresh? refreshGearReminders,
    AppStrings? strings,
  }) : catalog = WriteCatalog(
         records,
         refreshReminders: refreshGearReminders,
         rearmDocuments: rearmDocuments,
         strings: strings,
       ),
       _confirmer = confirmer,
       _confirmEnabled = confirmEnabled,
       _afterDiveWrites = afterDiveWrites;

  final WriteCatalog catalog;
  final WritePlanStore plans;
  final WriteConfirmer _confirmer;
  final bool Function() _confirmEnabled;
  final void Function(Iterable<String>) _afterDiveWrites;

  /// Arms the reminders of documents a failed or reverted delete brought back.
  final Future<void> Function(Iterable<Document>)? rearmDocuments;

  late final changeLog = ChangeLogRepository();

  late final revert = ChangeLogRevertService(
    repository: changeLog,
    afterDiveWrites: _afterDiveWrites,
  );

  late final applier = WriteApplier(
    catalog: catalog,
    changeLog: changeLog,
    confirmer: _confirmer,
    confirmEnabled: _confirmEnabled,
    afterDiveWrites: _afterDiveWrites,
    rearmDocuments: rearmDocuments,
  );
}
