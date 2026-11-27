// The fake editor the editor host's tests drive (issue #4527, phase 4):
// not a test file of its own.
import 'dart:async';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';

/// What the fake editor was asked to do, and how it should answer.
class EditorProbe {
  final writes = <String>[];
  final operationLabels = <String?>[];
  int afterSaved = 0;
  bool valid = true;
  bool failWrite = false;
  bool failAfterSaved = false;

  /// The diver the write was handed ([RecordEditorHost.editorDiverId]).
  final diversSeen = <String?>[];

  /// The change log operation in force each time the validated diver was
  /// read: null outside any sitting's transaction.
  final diverReadInScope = <String?>[];

  /// Runs inside the write, before it answers.
  Future<void> Function()? duringWrite;

  /// While set, the validated diver waits for it: a Save resolving the
  /// diver is held there.
  Completer<String?>? diverGate;

  /// While set, the fake record "loads" until it completes, then opens.
  Completer<void>? loadGate;

  /// How the validated diver resolves the active diver's id: the app maps
  /// an id whose diver is gone to the default diver.
  String? Function(String? id)? resolveDiver;

  /// While set, working out the diver fails (the database read throws).
  bool diverFails = false;

  /// The text the field starts with, in place of the stored or empty one:
  /// a seed when [seedFrom] is set.
  String? initialText;

  /// The draft the sitting opens on, the record before its seed
  /// (`openEditor(from:)`); null opens on the form as filled.
  String? seedFrom;

  /// The bar menu's one operation, when set. It answers whether it wrote.
  Future<bool> Function()? operation;

  /// What a committed Save pops with.
  Object? savedResult;

  /// Whether the editor shows a failed write itself.
  bool handlesFailure = false;

  /// Each failure the editor was told of.
  final failures = <Object>[];

  /// The record cannot be opened: the page leaves as it starts, while its
  /// route is still being pushed, in place of opening.
  bool leaveAtStart = false;

  /// Whether the form may be saved at all, given the draft; null always.
  bool Function(String draft)? canSave;
}

/// An editor with no read page, as small as one can be: one text field
/// whose text is the draft.
class FakeEditorPage extends ConsumerStatefulWidget {
  const FakeEditorPage({
    super.key,
    required this.probe,
    this.storedId = 'rec-1',
    this.leaveLocation,
  });

  final EditorProbe probe;
  final String? storedId;
  final String? leaveLocation;

  @override
  ConsumerState<FakeEditorPage> createState() => FakeEditorState();
}

class FakeEditorState extends ConsumerState<FakeEditorPage>
    with RecordEditorHost<FakeEditorPage, String> {
  late final TextEditingController text;

  @override
  void initState() {
    super.initState();
    final probe = widget.probe;
    text = TextEditingController(
      text: probe.initialText ?? (widget.storedId == null ? '' : 'stored'),
    )..addListener(editorChanged);
    if (probe.leaveAtStart) {
      // As a load that finds nothing answers: while the page's route is
      // still being pushed.
      scheduleMicrotask(leaveEditor);
      return;
    }
    void open() => openEditor(from: probe.seedFrom);
    final loading = probe.loadGate;
    if (loading != null) {
      loading.future.then((_) => open());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => open());
    }
  }

  @override
  void dispose() {
    disposeEditor();
    text.dispose();
    super.dispose();
  }

  @override
  String get editorTable => 'fake';

  @override
  String? get editorLeaveLocation => widget.leaveLocation;

  @override
  String? get editorStoredId => widget.storedId;

  @override
  String editorTitle(BuildContext context) => 'Fake editor';

  @override
  String readEditorDraft() => text.text;

  @override
  bool validateEditor() => widget.probe.valid;

  @override
  bool get editorCanSave => widget.probe.canSave?.call(text.text) ?? true;

  @override
  Future<void> writeEditor(String recordId) async {
    final probe = widget.probe;
    probe.diversSeen.add(editorDiverId);
    await probe.duringWrite?.call();
    if (probe.failWrite) throw StateError('write refused');
    probe.writes.add(recordId);
    final operationId = ChangeLogScope.currentOperationId;
    final row = operationId == null
        ? null
        : await DatabaseService.instance.database
              .customSelect(
                'SELECT label FROM change_log_operations WHERE id = ?',
                variables: [Variable(operationId)],
              )
              .getSingleOrNull();
    probe.operationLabels.add(row?.read<String?>('label'));
  }

  @override
  void afterEditorSaved(ScaffoldMessengerState messenger) {
    widget.probe.afterSaved++;
    if (widget.probe.failAfterSaved) throw StateError('refresh failed');
  }

  @override
  List<RecordEditorOperation> editorOperations(BuildContext context) {
    final operation = widget.probe.operation;
    return [
      if (operation != null)
        RecordEditorOperation(
          key: const ValueKey('fakeOperation'),
          icon: Icons.delete_outline,
          label: 'Fake operation',
          run: operation,
          destructive: true,
        ),
    ];
  }

  @override
  Object? get editorSavedResult => widget.probe.savedResult;

  @override
  bool editorSaveFailed(Object error) {
    widget.probe.failures.add(error);
    return widget.probe.handlesFailure;
  }

  @override
  Widget build(BuildContext context) => editorScaffold(
    context,
    body: TextField(key: const ValueKey('field'), controller: text),
  );
}
